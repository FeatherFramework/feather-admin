ClientAllPlayers = {}
local AdminKeyListener = nil

RegisterNetEvent('feather-admin:ClientAllPlayers', function(players)
    ClientAllPlayers = players or {}
end)

function AdminTranslate(key)
    return Feather.Locale.translate(0, key)
end

CreateThread(function()
    if Config.controls.enabled then
        local menuKey = Config.controls.openMenu
        AdminKeyListener = Feather.Keys:RegisterListener(menuKey, function ()
            if not InMenu then
                TriggerServerEvent('feather-admin:RequestAccess')
            end
        end)
    end

    if Config.commands.enabled then
        local command = Config.commands.openMenu
        local suggestion = Config.commands.suggestion
        Feather.Command.Register(command, suggestion, function()
            if not InMenu then
                TriggerServerEvent('feather-admin:RequestAccess')
            end
        end)
    end
end)

RegisterNetEvent('feather-admin:AccessResult', function(authorized)
    if not authorized or InMenu then return end
    TriggerServerEvent('feather-admin:RequestPlayerList')
    MainAdminMenu()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end

    if AdminKeyListener then
        AdminKeyListener:RemoveListener()
        AdminKeyListener = nil
    end
end)
