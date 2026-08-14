-- (ADM-03) No authorization check existed -- any client could force any
-- other player's ped model. Now requires the caller to be an admin.
RegisterServerEvent('feather-admin:PedChangeSender', function(playerId, model)
    local _source = source
    if not IsAuthorizedAdmin(_source) then
        RejectUnauthorized(_source, 'feather-admin:PedChangeSender')
        return
    end
    TriggerClientEvent('feather-admin:PedChangeHandler', playerId, model)
end)

-- (ADM-01) No authorization check existed -- any client could godmode/
-- invis itself or KILL any other player by server id. Now requires the
-- caller to be an admin. This also closes ADM-07 (self-cheat) as a side
-- effect, since even self-targeted boosters now require the same gate.
RegisterServerEvent("feather-admin:BoosterCheck", function(event, playerId)
    local _source = source
    if not IsAuthorizedAdmin(_source) then
        RejectUnauthorized(_source, 'feather-admin:BoosterCheck')
        return
    end

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