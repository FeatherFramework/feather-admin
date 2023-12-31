function mainAllPlayersMenu() --Main all players menu (Menu starts here)
    MenuAPI.CloseAll()

    local elements = {}
    for k, v in pairs(ClientAllPlayers) do
        elements[#elements+1] = {
            label = 'Player Id: ' .. v,
            value = 'player' .. k,
            desc = '',
            info = v
        }
    end

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
            if data.current.value then
                allPlayerSelectedPlayerMenu(data.current.info)
            end
        end,
        function(data, menu)
            menu.close()
            mainAdminMenu()
        end)
end

function allPlayerSelectedPlayerMenu(playerId)
    MenuAPI.CloseAll()

    local elements = {
        { label = Feather.Locale.translate(0, "boosters"), value = 'boosters', desc = Feather.Locale.translate(0, "boosters_desc") },
        { label = Feather.Locale.translate(0, "troll"), value = 'trolls', desc = Feather.Locale.translate(0, "troll_desc") }
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
                ['boosters'] = function()
                    boostersMenu(playerId)
                end,
                ['trolls'] = function()
                    trollMenu(playerId)
                end
            }

            if selectedOption[data.current.value] then
                selectedOption[data.current.value]()
            end
        end,
        function(data, menu)
            menu.close()
            mainAllPlayersMenu()
        end)
end