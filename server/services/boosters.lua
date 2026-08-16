local allowedActions = {
    invisibility = true,
    invincibility = true,
    infinite_stamina = true,
    heal = true,
    revive = true,
    disable_fow = true,
    kill = true
}

RegisterNetEvent('feather-admin:booster:request', function(action, playerId)
    local src = source
    if allowedActions[action] ~= true then return end
    if not FeatherAdmin.RequirePermission(src, ('booster.%s'):format(action)) then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil then return end

    AdminAudit.Record(src, ('booster.%s'):format(action), target)
    if action == 'revive' then
        TriggerClientEvent('Feather:Character:Revive', target)
        return
    end

    TriggerClientEvent('feather-admin:booster:apply', target, action)
end)
