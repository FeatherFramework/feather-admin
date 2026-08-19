local allowedActions = {
    invisibility = true,
    invincibility = true,
    infinite_stamina = true,
    heal = true,
    revive = true,
    disable_fow = true,
    kill = true
}

FeatherAdmin.RegisterRPC('feather-admin:booster:request', function(params, _, src)
    local action, playerId, requestId = params.action, params.playerId, tonumber(params.requestId)
    local function result(succeeded)
        if requestId then TriggerClientEvent('feather-admin:booster:toggle:result', src, requestId, succeeded) end
    end
    if allowedActions[action] ~= true then result(false) return end
    local permission = ('booster.%s'):format(action)
    local target = FeatherAdmin.RequireTarget(src, permission, playerId)
    if target == nil then result(false) return end

    AdminAudit.Record(src, permission, target)
    if action == 'revive' then
        TriggerClientEvent('Feather:Character:Revive', target)
        result(true)
        return
    end

    TriggerClientEvent('feather-admin:booster:apply', target, action)
    result(true)
end, { windowMs = 1000, maxCalls = 5, maxPayloadBytes = 256 })
