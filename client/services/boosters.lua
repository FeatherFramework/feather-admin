----- Variables -----
local godMode, visible, infStamina, noClip = false, false, false, false

----- Menus -----
function boostersMenu(playerId) --catching the player id so it can be used for either the admin using the menu or if we do pass an id it can be used to modify another player allowing admins to use booster options on other players not just themselves
    local isAdmin = true --is admin is used to hide options that only works on admin client
    if playerId == nil or false then
        playerId = GetPlayerServerId(PlayerId())
    else
        isAdmin = false
    end
    VORPMenu.CloseAll()

    local elements = {}
    table.insert(elements, { label = "Toggle God Mode", value = 'godMode', desc = "Toggle God Mode." })

    table.insert(elements, { label = "Toggle Invisibility", value = 'visible', desc = "Toggle Invisibility." })

    table.insert(elements, { label = "Toggle Infinite Stamina", value = 'infStamina', desc = "Toggle Infinite Stamina." })

    if isAdmin then
        table.insert(elements, { label = "Toggle No Clip", value = 'noClip', desc = "Enable No Clip." })
    end

    table.insert(elements, { label = "Heal", value = 'heal', desc = "Heal." })
    table.insert(elements, { label = "Change Ped", value = 'changePed', desc = "Change ped." })

    VORPMenu.Open('default', GetCurrentResourceName(), 'vorp_menu',
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
                    TriggerServerEvent('feather-admin:InvincibilitySender', playerId)
                end,
                ['visible'] = function()
                    TriggerServerEvent('feather-admin:InvisibilitySender', playerId)
                end,
                ['infStamina'] = function()
                    TriggerServerEvent('feather-admin:InfStaminaSender', playerId)
                end,
                ['heal'] = function()
                    TriggerServerEvent('feather-admin:HealSender', playerId)
                end,
                ['noClip'] = function() --NoClip only works on the admin/users player no other clients
                    if not noClip then
                        noClip = true
                        VORPMenu.CloseAll()
                        boostersMenu()
                        noClipHandler()
                    else
                        noClip = false
                        VORPMenu.CloseAll()
                        boostersMenu()
                    end
                end,
                ['changePed'] = function()
                    VORPMenu.CloseAll()
                    pedChangeMenu(playerId)
                end
            }

            if selectedOption[data.current.value] then
                selectedOption[data.current.value]()
            end
        end,
        function(data, menu)
            menu.close()
            mainAdminMenu()
        end)
end

---- Functions -----
function infiniteStamina()
    while infStamina do
        Wait(5)
        RestorePlayerStamina(PlayerId(), 100.0)
    end
end

function noClipHandler()
    local speed = 0.1
    local playerPed = PlayerPedId()
    local  PromptGroup = Feather.Prompt:SetupPromptGroup()
    local speedPrompt = PromptGroup:RegisterPrompt("Change Speed", Feather.Keys.SHIFT, 1, 1, true, 'click')
    local forwardPrompt = PromptGroup:RegisterPrompt("Forward", Feather.Keys.MOUSE1, 1, 1, true, 'click')
    local backwardPrompt = PromptGroup:RegisterPrompt("Backward", Feather.Keys.MOUSE2, 1, 1, true, 'click')
    local upPrompt = PromptGroup:RegisterPrompt("Up", Feather.Keys.CTRL, 1, 1, true, 'click')
    local downPrompt = PromptGroup:RegisterPrompt("Down", Feather.Keys.LALT, 1, 1, true, 'click')

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

RegisterNetEvent('feather-admin:SetPlayerInvincibleHandler', function()
    if not godMode then
        SetEntityInvincible(PlayerPedId(), true)
        godMode = true
    else
        SetEntityInvincible(PlayerPedId(), false)
        godMode = false
    end
end)

RegisterNetEvent('feather-admin:SetPlayerInvisibleHandler', function()
    if not visible then
        SetEntityVisible(PlayerPedId(), false)
        visible = true
    else
        SetEntityVisible(PlayerPedId(), true)
        visible = false
    end
end)

RegisterNetEvent('feather-admin:SetPlayerInfStaminaHandler', function()
    if not infStamina then
        infStamina = true
        infiniteStamina()
    else
        infStamina = false
    end
end)

RegisterNetEvent('feather-admin:HealPlayerHandler', function()
    SetEntityHealth(PlayerPedId(), 100.0)
end)