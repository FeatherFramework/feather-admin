function mainAdminMenu()
    MenuAPI.CloseAll()

    local elements = {
        { label = Feather.Locale.translate(0, "players"), value = 'allPlayers', desc = Feather.Locale.translate(0, "players_desc") },
        { label = Feather.Locale.translate(0, "developerTools"), value = 'devTools', desc = Feather.Locale.translate(0, "developerTools_desc") },
        { label = Feather.Locale.translate(0, "boosters"), value = 'boosters', desc = Feather.Locale.translate(0, "boosters_desc") },
        { label = Feather.Locale.translate(0, "teleport"), value = 'teleports', desc = Feather.Locale.translate(0, "teleport_desc") }
    }

    MenuAPI.Open('default', GetCurrentResourceName(), 'menuapi',
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