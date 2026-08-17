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
    local action, playerId = params.action, params.playerId
    if allowedActions[action] ~= true then return end
    local permission = ('booster.%s'):format(action)
    local target = FeatherAdmin.RequireTarget(src, permission, playerId)
    if target == nil then return end

    AdminAudit.Record(src, permission, target)
    if action == 'revive' then
        TriggerClientEvent('Feather:Character:Revive', target)
        return
    end

    TriggerClientEvent('feather-admin:booster:apply', target, action)
end, { windowMs = 1000, maxCalls = 5, maxPayloadBytes = 256 })
