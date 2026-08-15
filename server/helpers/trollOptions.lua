RegisterServerEvent("feather-admin:TrollCheck", function(event, playerId)
    local src = source
    if not FeatherAdmin.RequireAuthorized(src) then return end
    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil then return end

    local options = {
        ["LightningStrike"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ["Freeze"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ["TeleportToHeaven"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ["Cage"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ["makePedGiant"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ["forceCinematicCam"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ["hostilePedArmy"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ['kickFromVehicle'] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ["handcuffPlayer"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ['hostileBear'] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end,
        ['lag'] = function()
            TriggerClientEvent("feather-admin:TrollHandler", target, event)
        end
    }

    if options[event] then
        options[event]()
    end
end)
