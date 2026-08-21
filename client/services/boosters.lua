AdminBoosters = {}

local state = {
    invincible = false,
    invisible = false,
    infiniteStamina = false,
    noclip = false,
    noclipSession = 0,
    noclipPed = nil
}

local function setNoclipPed(ped, enabled)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    SetEntityCollision(ped, not enabled, true)
    FreezeEntityPosition(ped, enabled)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
end

local function showNoclipOverlay(visible, speed)
    SendNUIMessage({
        type = 'noclip',
        visible = visible,
        title = AdminTranslate('noclip_controls'),
        forward = ('W / S - %s / %s'):format(AdminTranslate('move_forward'), AdminTranslate('move_backward')),
        strafe = ('A / D - %s'):format(AdminTranslate('strafe')),
        vertical = ('Space / Ctrl - %s / %s'):format(AdminTranslate('move_up'), AdminTranslate('move_down')),
        speed = ('Shift - %s: %s m/s'):format(AdminTranslate('noclip_speed'), tostring(speed or '')),
        exit = ('Backspace - %s'):format(AdminTranslate('exit_noclip'))
    })
end

local function moveNoclipPed(ped, forwardAmount, strafeAmount, verticalAmount, speed)
    local rotation = GetGameplayCamRot(2)
    local pitch = math.rad(rotation.x)
    local yaw = math.rad(rotation.z)
    local cosPitch = math.cos(pitch)
    local x = -math.sin(yaw) * cosPitch * forwardAmount + math.cos(yaw) * strafeAmount
    local y = math.cos(yaw) * cosPitch * forwardAmount + math.sin(yaw) * strafeAmount
    local z = math.sin(pitch) * forwardAmount + verticalAmount
    local length = math.sqrt(x * x + y * y + z * z)
    if length <= 0.0 then return end

    local distance = speed * GetFrameTime()
    local coords = GetEntityCoords(ped, false, false)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    if forwardAmount ~= 0.0 then SetEntityHeading(ped, rotation.z) end

    SetEntityCoordsNoOffset(ped,
        coords.x + (x / length) * distance,
        coords.y + (y / length) * distance,
        coords.z + (z / length) * distance,
        false, false, false)
end

local function runInfiniteStamina()
    while state.infiniteStamina do
        RestorePlayerStamina(PlayerId(), 100.0)
        Wait(0)
    end
end

local function runNoclip(session)
    local keys = Feather.KeyCodes
    local speeds = { 2.0, 5.0, 10.0, 20.0 }
    local speedIndex = 2
    SetEveryoneIgnorePlayer(PlayerId(), true)
    showNoclipOverlay(true, speeds[speedIndex])

    while state.noclip and state.noclipSession == session do
        local ped = PlayerPedId()
        if state.noclipPed ~= ped then
            setNoclipPed(state.noclipPed, false)
            state.noclipPed = ped
            setNoclipPed(ped, true)
        end

        -- Suppress the gameplay actions assigned to the noclip controls.
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, keys.SHIFT, true)
        DisableControlAction(0, keys.W, true)
        DisableControlAction(0, keys.S, true)
        DisableControlAction(0, keys.A, true)
        DisableControlAction(0, keys.D, true)
        DisableControlAction(0, keys.SPACEBAR, true)
        DisableControlAction(0, keys.CTRL, true)
        DisableControlAction(0, keys.BACKSPACE, true)

        if IsDisabledControlJustPressed(0, keys.SHIFT) then
            speedIndex = speedIndex % #speeds + 1
            showNoclipOverlay(true, speeds[speedIndex])
        end

        if IsDisabledControlJustPressed(0, keys.BACKSPACE) then
            AdminBoosters.ToggleNoClip(false)
            AdminUI.SetToggleState('noclip', false)
            break
        end

        local forward = (IsDisabledControlPressed(0, keys.W) and 1.0 or 0.0)
            - (IsDisabledControlPressed(0, keys.S) and 1.0 or 0.0)
        local strafe = (IsDisabledControlPressed(0, keys.D) and 1.0 or 0.0)
            - (IsDisabledControlPressed(0, keys.A) and 1.0 or 0.0)
        local vertical = (IsDisabledControlPressed(0, keys.SPACEBAR) and 1.0 or 0.0)
            - (IsDisabledControlPressed(0, keys.CTRL) and 1.0 or 0.0)
        if forward ~= 0.0 or strafe ~= 0.0 or vertical ~= 0.0 then
            moveNoclipPed(ped, forward, strafe, vertical, speeds[speedIndex])
        end

        Wait(0)
    end

    setNoclipPed(state.noclipPed, false)
    SetEveryoneIgnorePlayer(PlayerId(), false)
    showNoclipOverlay(false)
    state.noclipPed = nil
end

function AdminBoosters.Request(action, targetPlayer, requestId)
    if targetPlayer == nil then return end
    Feather.RPC.Notify('feather-admin:booster:request', {
        action = action, playerId = targetPlayer, requestId = requestId
    })
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
        SetEntityHealth(ped, GetEntityMaxHealth(ped, false), 0)
    end,
    kill = function()
        SetEntityHealth(PlayerPedId(), 0, 0)
    end,
    disable_fow = function()
        Feather.Map.setFOW(true)
    end
}

RegisterNetEvent('feather-admin:booster:apply', function(action)
    local handler = actionHandlers[action]
    if handler then handler() end
end)

RegisterNetEvent('feather-admin:booster:death:request', function(requestId)
    Feather.RPC.Notify('feather-admin:booster:death:result', {
        requestId = requestId,
        dead = IsEntityDead(PlayerPedId())
    })
end)

RegisterNetEvent('feather-admin:booster:action:result', function(messageKey)
    Feather.Notify.RightNotify(AdminTranslate(messageKey), 3000)
end)

RegisterNetEvent('feather-admin:booster:toggle:result', function(requestId, succeeded)
    AdminUI.ResolveServerToggle(requestId, succeeded)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    state.infiniteStamina = false
    state.noclip = false
    state.noclipSession = state.noclipSession + 1
    setNoclipPed(state.noclipPed, false)
    SetEveryoneIgnorePlayer(PlayerId(), false)
    showNoclipOverlay(false)

    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true)
end)
