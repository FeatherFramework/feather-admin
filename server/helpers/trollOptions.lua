RegisterServerEvent("feather-admin:TrollCheck", function(event, playerId)
    local options = {
        ["LightningStrike"] = function()
            TriggerClientEvent("feather-troll:TrollHandler", playerId, event)
        end,
        ["Freeze"] = function()
            TriggerClientEvent("feather-troll:TrollHandler", playerId, event)
        end,
        ["TeleportToHeaven"] = function()
            TriggerClientEvent("feather-troll:TrollHandler", playerId, event)
        end,
        ["Kill"] = function()
            TriggerClientEvent("feather-troll:TrollHandler", playerId, event)
        end,
        ["Cage"] = function()
            TriggerClientEvent("feather-troll:TrollHandler", playerId, event)
        end
    }

    if options[event] then
        options[event]()
    end
end)