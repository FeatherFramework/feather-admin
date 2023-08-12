local function mainPedChangeMenu(playerId, recTable, allPlayers) --Set as local as its only ever called in this file (more optimal?)
    VORPMenu.CloseAll()

    local elements = {}
    for k, v in pairs(recTable) do
        elements[#elements+1] = {
            label = v.model,
            value = 'ped' .. k,
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
                TriggerServerEvent('feather-admin:PedChangeSender', playerId, joaat(data.current.info.model))
            end
        end,
        function(data, menu)
            menu.close()
            if allPlayers then
                pedChangeMenu(playerId, true)
            else
                pedChangeMenu(playerId)
            end
        end)
end

function pedChangeMenu(playerId, allPlayers) --Main ped change menu cannot be local as its needed more than just this file
    VORPMenu.CloseAll()
    if playerId == nil or false then
        playerId = PlayerId()
    end
    local elements = {
        { label = "Human Peds", value = 'humans', desc = "Human Peds." },
        { label = "Animal Peds", value = 'animals', desc = "Animal Peds." },
    }

    VORPMenu.Open('default', GetCurrentResourceName(), 'vorp_menu',
        {
            title = "Ped Change Menu",
            align = 'top-left',
            elements = elements
        },
        function(data, menu)
            if data.current == 'backup' then
                _G[data.trigger]()
            end
            if data.current.value == 'humans' then
                if allPlayers then
                    mainPedChangeMenu(playerId, Config.Setup.PedChangingMenu.HumanPeds, true)
                else
                    mainPedChangeMenu(playerId, Config.Setup.PedChangingMenu.HumanPeds)
                end
            elseif data.current.value == 'animals' then
                if allPlayers then
                    mainPedChangeMenu(playerId, Config.Setup.PedChangingMenu.AnimalPeds, true)
                else
                    mainPedChangeMenu(playerId, Config.Setup.PedChangingMenu.AnimalPeds)
                end
            end
        end,
        function(data, menu)
            menu.close()
            if allPlayers then
                allPlayerSelectedPlayerMenu(playerId)
            else
                mainAdminMenu()
            end
        end)
end

RegisterNetEvent('feather-admin:PedChangeHandler', function(model)
    loadModel(model)
    SetPlayerModel(PlayerId(), model) --Native only works with playerid aka source (Player ped Id will change after this runs so you have to get the player ped id again for the outfit variation)
    Citizen.InvokeNative(0x283978A15512B2FE, PlayerPedId(), true) --Setting random outfit variation
    SetModelAsNoLongerNeeded(model) --Setting model as no longer needed for optimization purposes first time I have used this native
end)