local AdminKeyListener = nil

RegisterNetEvent('feather-admin:players:sync', function(players)
    ClientAllPlayers = players or {}
    if InMenu and AdminUI.currentPage == 'players' then
        AdminUI.OpenPlayers()
    end
end)

CreateThread(function()
    if Config.controls.enabled then
        local menuKey = Config.controls.openMenu
        AdminKeyListener = Feather.Keys:RegisterListener(menuKey, function ()
            if not InMenu then
                TriggerServerEvent('feather-admin:access:request')
            end
        end)
    end

    if Config.commands.enabled then
        local command = Config.commands.openMenu
        local suggestion = AdminTranslate(Config.commands.suggestionKey)
        Feather.Command.Register(command, suggestion, function()
            if not InMenu then
                TriggerServerEvent('feather-admin:access:request')
            end
        end)
    end
end)

RegisterNetEvent('feather-admin:access:result', function(authorized)
    if not authorized or InMenu then return end
    TriggerServerEvent('feather-admin:players:request')
    AdminUI.OpenMain()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end

    if AdminKeyListener then
        AdminKeyListener:RemoveListener()
        AdminKeyListener = nil
    end
end)
