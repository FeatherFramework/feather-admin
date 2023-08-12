function mainAdminMenu()
    VORPMenu.CloseAll()

    local elements = {
        { label = "Players", value = 'allPlayers', desc = "View all players." },
        { label = "Developer Tools", value = 'devTools', desc = "A set of developer tools." },
        { label = "Boosters", value = 'boosters', desc = "Booster options for your ped." },
        { label = "Teleport", value = 'teleports', desc = "Teleports Options" }
    }

    VORPMenu.Open('default', GetCurrentResourceName(), 'vorp_menu',
        {
            title = "Admin Menu",
            align = 'top-left',
            elements = elements
        },
        function(data, menu)
            if data.current == 'backup' then
                _G[data.trigger]()
            end
            local selectedOption = {
                ['devTools'] = function()
                    devToolsMenu()
                end,
                ['boosters'] = function()
                    boostersMenu()
                end,
                ['teleports'] = function()
                    teleportsMenu()
                end,
                ['allPlayers'] = function()
                    mainAllPlayersMenu()
                end
            }

            if selectedOption[data.current.value] then
                selectedOption[data.current.value]()
            end
        end,
        function(data, menu)
            Inmenu = false
            menu.close()
        end)
end