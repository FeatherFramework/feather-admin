----- Variables -----
local boosters = {
    godMode = false,
    visible = false,
    infStamina = false,
    noClip = false
}

----- Local Functions ----
local function infiniteStamina()
    while infStamina do
        Wait(5)
        RestorePlayerStamina(PlayerId(), 100.0)
    end
end

local function noClipHandler()
    local speed = 0.1
    local playerPed = PlayerPedId()
    local  PromptGroup = Feather.Prompt:SetupPromptGroup()
    local speedPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "changeSpeed"), Feather.Keys.SHIFT, 1, 1, true, 'click')
    local forwardPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "forward"), Feather.Keys.MOUSE1, 1, 1, true, 'click')
    local backwardPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "backward"), Feather.Keys.MOUSE2, 1, 1, true, 'click')
    local upPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "up"), Feather.Keys.CTRL, 1, 1, true, 'click')
    local downPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "down"), Feather.Keys.LALT, 1, 1, true, 'click')

    local function noClipAction(yoff, zoff, setSpeed) --Credit to vorp admin for this function modified it to make it work
        local newPos = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, yoff * (setSpeed + 0.3), zoff * (setSpeed + 0.3))
        SetEntityVelocity(playerPed, 0.0, 0.0, 0.0)
        SetEntityRotation(playerPed, 0.0, 0.0, 180.0, 0, false)
        SetEntityHeading(playerPed, GetGameplayCamRelativeHeading())
        SetEntityCoordsNoOffset(playerPed, newPos.x, newPos.y, newPos.z, false, false, false)
    end

    --SetEntityVisible(playerPed, false) --Left off for now as first person no clip is iffy still and youll want to know where your char will spawn when exiting noclip
    SetEntityCollision(playerPed, false, true)
    FreezeEntityPosition(playerPed, true)
    SetEveryoneIgnorePlayer(PlayerPedId(), true)
    while noClip do
        Wait(5)
		PromptGroup:ShowGroup("My first prompt group")
        if speedPrompt:HasCompleted() then
            speed = speed + 0.1
            if speed > 2 then speed = 0.1 end
        end

        if IsControlPressed(0, Feather.Keys.MOUSE1) then
            noClipAction(-0.2, 0.0, speed)
        elseif IsControlPressed(0, Feather.Keys.MOUSE2) then
            noClipAction(0.2, 0.0, speed)
        elseif IsControlPressed(0, Feather.Keys.CTRL) then
            noClipAction(0, 1, speed)
        elseif IsControlPressed(0, Feather.Keys.LALT) then
            noClipAction(0, -1, speed)
        end
    end
    SetEntityVisible(playerPed, true)
    SetEntityCollision(playerPed, true, true)
    FreezeEntityPosition(playerPed, false)
    SetEveryoneIgnorePlayer(PlayerPedId(), false)
end

----- Menus -----
function boostersMenu(playerId) --catching the player id so it can be used for either the admin using the menu or if we do pass an id it can be used to modify another player allowing admins to use booster options on other players not just themselves
    local isAdmin = true --is admin is used to hide options that only works on admin client
    if playerId == nil or false then
        playerId = GetPlayerServerId(PlayerId())
    else
        isAdmin = false
    end
    MenuAPI.CloseAll()

    local elements = {
        { label = Feather.Locale.translate(0, "toggleGodMode"), value = 'godMode', desc = Feather.Locale.translate(0, "toggleGodMode_desc") },
        { label = Feather.Locale.translate(0, "toggleInvis"), value = 'visible', desc = Feather.Locale.translate(0, "toggleInvis_desc") },
        { label = Feather.Locale.translate(0, "toggleInfStam"), value = 'infStamina', desc = Feather.Locale.translate(0, "toggleInfStam_desc") },
        { label = Feather.Locale.translate(0, "heal"), value = 'heal', desc = Feather.Locale.translate(0, "heal") },
        { label = Feather.Locale.translate(0, "changePed"), value = 'changePed', desc = Feather.Locale.translate(0, "changePed") },
        { label = Feather.Locale.translate(0, "disableFOW"), value = 'disableFOW', desc = Feather.Locale.translate(0, "disableFOW_desc") },
        { label = Feather.Locale.translate(0, "kill"), value = "kill", desc = Feather.Locale.translate(0, "kill") }
    }

    if isAdmin then
        table.insert(elements, { label = Feather.Locale.translate(0, "noClip"), value = 'noClip', desc = Feather.Locale.translate(0, "noClip_desc") })
    end

    MenuAPI.Open('default', GetCurrentResourceName(), 'menuapi',
        {
            title = "Boosters Menu",
            align = 'top-left',
            elements = elements
        },
        function(data, menu)
            if data.current == 'backup' then
                _G[data.trigger]()
            end
            local selectedOption = {
                ['godMode'] = function()
                    TriggerServerEvent('feather-admin:BoosterCheck', "Invincibility", playerId)
                end,
                ['visible'] = function()
                    TriggerServerEvent('feather-admin:BoosterCheck', "Invisibility", playerId)
                end,
                ['infStamina'] = function()
                    TriggerServerEvent('feather-admin:BoosterCheck', "InfStam", playerId)
                end,
                ['heal'] = function()
                    TriggerServerEvent('feather-admin:BoosterCheck', "Heal", playerId)
                end,
                ['noClip'] = function() --NoClip only works on the admin/users player no other clients
                    if not boosters.noClip then
                        boosters.noClip = true
                        MenuAPI.CloseAll()
                        boostersMenu()
                        noClipHandler()
                    else
                        boosters.noClip = false
                        MenuAPI.CloseAll()
                        boostersMenu()
                    end
                end,
                ['changePed'] = function()
                    MenuAPI.CloseAll()
                    if isAdmin then
                        pedChangeMenu(playerId)
                    else
                        pedChangeMenu(playerId, true)
                    end
                end,
                ["kill"] = function()
                    TriggerServerEvent('feather-admin:BoosterCheck', "kill", playerId)
                end,
                ["disableFOW"] = function()
                    TriggerServerEvent('feather-admin:BoosterCheck', "disableFOW", playerId)
                end
            }

            if selectedOption[data.current.value] then
                selectedOption[data.current.value]()
            end
        end,
        function(data, menu)
            menu.close()
            if not isAdmin then
                allPlayerSelectedPlayerMenu(playerId)
            else
                mainAdminMenu()
            end
        end)
end

----- Events ----
RegisterNetEvent("feather-admin:BoosterHandler", function(event)
    local options = {
        ["Invisibility"] = function()
            if not boosters.visible then
                SetEntityVisible(PlayerPedId(), false)
                boosters.visible = true
            else
                SetEntityVisible(PlayerPedId(), true)
                boosters.visible = false
            end
        end,
        ["Invincibility"] = function()
            if not boosters.godMode then
                SetEntityInvincible(PlayerPedId(), true)
                boosters.godMode = true
            else
                SetEntityInvincible(PlayerPedId(), false)
                boosters.godMode = false
            end
        end,
        ["InfStam"] = function()
            if not boosters.infStamina then
                boosters.infStamina = true
                infiniteStamina()
            else
                boosters.infStamina = false
            end
        end,
        ["Heal"] = function()
            SetEntityHealth(PlayerPedId(), 100.0)
        end,
        ["kill"] = function()
            SetEntityHealth(PlayerPedId(), 0)
        end,
        ["disableFOW"] = function()
            SetMinimapHideFow(true)
        end
    }

    if options[event] then
        options[event]()
    end
end)