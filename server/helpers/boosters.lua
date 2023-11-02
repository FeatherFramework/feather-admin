RegisterServerEvent('feather-admin:PedChangeSender', function(playerId, model)
    TriggerClientEvent('feather-admin:PedChangeHandler', playerId, model)
end)

RegisterServerEvent("feather-admin:BoosterCheck", function(event, playerId)
    local options = {
        ["Invisibility"] = function()
            TriggerClientEvent('feather-admin:BoosterHandler', playerId, event)
        end,
        ["Invincibility"] = function()
            TriggerClientEvent('feather-admin:BoosterHandler', playerId, event)
        end,
        ["InfStam"] = function()
            TriggerClientEvent('feather-admin:BoosterHandler', playerId, event)
        end,
        ["Heal"] = function()
            TriggerClientEvent('feather-admin:BoosterHandler', playerId, event)
        end,
        ["disableFOW"] = function()
            TriggerClientEvent("feather-admin:BoosterHandler", playerId, event)
        end,
        ["kill"] = function()
            TriggerClientEvent("feather-admin:BoosterHandler", playerId, event)
        end
    }

    if options[event] then
        options[event]()
    end
end)