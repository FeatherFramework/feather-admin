AdminBoosters = {}

local state = {
    invincible = false,
    invisible = false,
    infiniteStamina = false,
    noclip = false,
    noclipSession = 0,
    noclipPed = nil,
    noclipPrompts = nil
}

local function setNoclipPed(ped, enabled)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    SetEntityCollision(ped, not enabled, true)
    FreezeEntityPosition(ped, enabled)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
end

local function deletePrompts(prompts)
    if not prompts then return end

    for _, prompt in ipairs(prompts) do
        prompt:DeletePrompt()
    end
end

local function createNoclipPrompts()
    local keys = Feather.KeyCodes
    local group = Feather.Prompt:SetupPromptGroup()
    local prompts = {
        group:RegisterPrompt(AdminTranslate('change_speed'), keys.SHIFT, 1, 1, false, 'click'),
        group:RegisterPrompt(AdminTranslate('move_forward'), keys.MOUSE1, 1, 1, false, 'click'),
        group:RegisterPrompt(AdminTranslate('move_backward'), keys.MOUSE2, 1, 1, false, 'click'),
        group:RegisterPrompt(AdminTranslate('move_up'), keys.CTRL, 1, 1, false, 'click'),
        group:RegisterPrompt(AdminTranslate('move_down'), keys.LALT, 1, 1, false, 'click')
    }
    return group, prompts
end

local function moveNoclipPed(ped, forwardOffset, verticalOffset, speed)
    local coords = GetOffsetFromEntityInWorldCoords(
        ped,
        0.0,
        forwardOffset * (speed + 0.3),
        verticalOffset * (speed + 0.3)
    )
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    SetEntityHeading(ped, GetGameplayCamRelativeHeading())
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
end

local function runInfiniteStamina()
    while state.infiniteStamina do
        RestorePlayerStamina(PlayerId(), 100.0)
        Wait(0)
    end
end

local function runNoclip(session)
    local keys = Feather.KeyCodes
    local speed = 0.1
    local promptGroup, prompts = createNoclipPrompts()
    state.noclipPrompts = prompts
    SetEveryoneIgnorePlayer(PlayerId(), true)

    while state.noclip and state.noclipSession == session do
        local ped = PlayerPedId()
        if state.noclipPed ~= ped then
            setNoclipPed(state.noclipPed, false)
            state.noclipPed = ped
            setNoclipPed(ped, true)
        end

        -- Prompt groups compete with menu/pause frontends for the active UI
        -- context. Only activate noclip prompts while gameplay has focus.
        if not InMenu and not IsPauseMenuActive() then
            promptGroup:ShowGroup(AdminTranslate('noclip_controls'))
        end
        -- Poll the control directly so this frame-critical loop never enters
        -- a prompt completion helper that may perform a blocking wait.
        if IsControlJustPressed(0, keys.SHIFT) then
            speed = speed + 0.1
            if speed > 2.0 then speed = 0.1 end
        end

        if IsControlPressed(0, keys.MOUSE1) then
            moveNoclipPed(ped, -0.2, 0.0, speed)
        elseif IsControlPressed(0, keys.MOUSE2) then
            moveNoclipPed(ped, 0.2, 0.0, speed)
        elseif IsControlPressed(0, keys.CTRL) then
            moveNoclipPed(ped, 0.0, 1.0, speed)
        elseif IsControlPressed(0, keys.LALT) then
            moveNoclipPed(ped, 0.0, -1.0, speed)
        end

        Wait(0)
    end

    setNoclipPed(state.noclipPed, false)
    SetEveryoneIgnorePlayer(PlayerId(), false)
    deletePrompts(prompts)
    state.noclipPed = nil
    state.noclipPrompts = nil
end

function AdminBoosters.Request(action, targetPlayer)
    if targetPlayer == nil then return end
    TriggerServerEvent('feather-admin:booster:request', action, targetPlayer)
end

function AdminBoosters.ToggleNoClip(enabled)
    if type(enabled) == 'boolean' then
        state.noclip = enabled
    else
        state.noclip = not state.noclip
    end
    state.noclipSession = state.noclipSession + 1
    if state.noclip then
        local session = state.noclipSession
        CreateThread(function()
            runNoclip(session)
        end)
    end
    return state.noclip
end

function AdminBoosters.RefreshPlayerState()
    local ped = PlayerPedId()
    SetEntityInvincible(ped, state.invincible)
    SetEntityVisible(ped, not state.invisible)
    if state.noclip then
        state.noclipPed = ped
        setNoclipPed(ped, true)
    end
end

local actionHandlers = {
    invisibility = function()
        state.invisible = not state.invisible
        SetEntityVisible(PlayerPedId(), not state.invisible)
    end,
    invincibility = function()
        state.invincible = not state.invincible
        SetEntityInvincible(PlayerPedId(), state.invincible)
    end,
    infinite_stamina = function()
        state.infiniteStamina = not state.infiniteStamina
        if state.infiniteStamina then CreateThread(runInfiniteStamina) end
    end,
    heal = function()
        local ped = PlayerPedId()
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    end,
    kill = function()
        SetEntityHealth(PlayerPedId(), 0)
    end,
    disable_fow = function()
        Feather.Map.setFOW(true)
    end
}

RegisterNetEvent('feather-admin:booster:apply', function(action)
    local handler = actionHandlers[action]
    if handler then handler() end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    state.infiniteStamina = false
    state.noclip = false
    state.noclipSession = state.noclipSession + 1
    setNoclipPed(state.noclipPed, false)
    SetEveryoneIgnorePlayer(PlayerId(), false)
    deletePrompts(state.noclipPrompts)

    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true)
end)
