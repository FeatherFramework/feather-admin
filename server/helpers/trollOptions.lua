RegisterServerEvent("feather-admin:TrollCheck", function(event, playerId)
    local options = {
        ["LightningStrike"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ["Freeze"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ["TeleportToHeaven"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ["Kill"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ["Cage"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ["makePedGiant"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ["forceCinematicCam"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ["hostilePedArmy"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ['kickFromVehicle'] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end
    }

    if options[event] then
        options[event]()
    end
end)