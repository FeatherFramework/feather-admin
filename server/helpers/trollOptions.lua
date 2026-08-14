-- (ADM-02) No authorization check existed -- any client could freeze/cage/
-- teleport-kill/handcuff/lag any other player by server id. Now requires
-- the caller to be an admin.
RegisterServerEvent("feather-admin:TrollCheck", function(event, playerId)
    local _source = source
    if not IsAuthorizedAdmin(_source) then
        RejectUnauthorized(_source, 'feather-admin:TrollCheck')
        return
    end

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
        end,
        ["handcuffPlayer"] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ['hostileBear'] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end,
        ['lag'] = function()
            TriggerClientEvent("feather-admin:TrollHandler", playerId, event)
        end
    }

    if options[event] then
        options[event]()
    end
end)