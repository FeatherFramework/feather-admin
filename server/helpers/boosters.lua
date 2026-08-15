RegisterNetEvent("feather-admin:BoosterCheck", function(event, playerId)
    local src = source
    if not FeatherAdmin.RequireAuthorized(src) then return end
    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil then return end

    local options = {
        ["Invisibility"] = function()
            TriggerClientEvent('feather-admin:BoosterHandler', target, event)
        end,
        ["Invincibility"] = function()
            TriggerClientEvent('feather-admin:BoosterHandler', target, event)
        end,
        ["InfStam"] = function()
            TriggerClientEvent('feather-admin:BoosterHandler', target, event)
        end,
        ["Heal"] = function()
            TriggerClientEvent('feather-admin:BoosterHandler', target, event)
        end,
        ["disableFOW"] = function()
            TriggerClientEvent("feather-admin:BoosterHandler", target, event)
        end,
        ["kill"] = function()
            TriggerClientEvent("feather-admin:BoosterHandler", target, event)
        end
    }

    if options[event] then
        options[event]()
    end
end)
