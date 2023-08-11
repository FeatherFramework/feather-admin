function mainAllPlayersMenu()
    VORPMenu.CloseAll()

    local elements = {}
    for k, v in pairs(ClientAllPlayers) do
        elements[#elements+1] = {
            label = 'Player Id: ' .. v,
            value = 'player' .. k,
            desc = '',
            info = v
        }
    end

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
    VORPMenu.CloseAll()

    local elements = {
        { label = "Boosters", value = 'boosters', desc = "Booster options." },
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
                ['boosters'] = function()
                    boostersMenu(playerId)
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