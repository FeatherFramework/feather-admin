----- Variables -----
local godMode, visible, infStamina = false, false, false

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