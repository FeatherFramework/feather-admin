----- Variables -----
local godMode, visible, infStamina, noClip = false, false, false, false

----- Menus -----
function boostersMenu()
    VORPMenu.CloseAll()

    local elements = {}
    if not godMode then
        table.insert(elements, { label = "Enable God Mode", value = 'godMode', desc = "Toggle God Mode." })
    else
        table.insert(elements, { label = "Disable God Mode", value = 'godMode', desc = "Toggle God Mode." })
    end

    if not visible then
        table.insert(elements, { label = "Enable Invisibility", value = 'visible', desc = "Toggle Invisibility." })
    else
        table.insert(elements, { label = "Disable Invisibility", value = 'visible', desc = "Toggle Invisibility." })
    end

    if not infStamina then
        table.insert(elements, { label = "Enable Infinite Stamina", value = 'infStamina', desc = "Toggle Infinite Stamina." })
    else
        table.insert(elements, { label = "Disable Infinite Stamina", value = 'infStamina', desc = "Toggle Infinite Stamina." })
    end

    if not noClip then
        table.insert(elements, { label = "Enable No Clip", value = 'noClip', desc = "Enable No Clip." })
    else
        table.insert(elements, { label = "Disable No Clip", value = 'noClip', desc = "Disable No Clip." })
    end

    table.insert(elements, { label = "Heal Self", value = 'heal', desc = "Heal Self." })

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
                    if not godMode then
                        VORPMenu.CloseAll()
                        godMode = true
                        SetEntityInvincible(PlayerPedId(), true)
                        boostersMenu()
                    else
                        VORPMenu.CloseAll()
                        godMode = false
                        SetEntityInvincible(PlayerPedId(), false)
                        boostersMenu()
                    end
                end,
                ['visible'] = function()
                    if not visible then
                        VORPMenu.CloseAll()
                        visible = true
                        SetEntityVisible(PlayerPedId(), false)
                        boostersMenu()
                    else
                        VORPMenu.CloseAll()
                        visible = false
                        SetEntityVisible(PlayerPedId(), true)
                        boostersMenu()
                    end
                end,
                ['infStamina'] = function()
                    if not infStamina then
                        infStamina = true
                        VORPMenu.CloseAll()
                        boostersMenu()
                        infiniteStamina()
                    else
                        VORPMenu.CloseAll()
                        infStamina = false
                        boostersMenu()
                    end
                end,
                ['heal'] = function()
                    SetEntityHealth(PlayerPedId(), 100.0)
                end,
                ['noClip'] = function()
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