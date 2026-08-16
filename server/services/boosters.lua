local allowedActions = {
    invisibility = true,
    invincibility = true,
    infinite_stamina = true,
    heal = true,
    disable_fow = true,
    kill = true
}

RegisterNetEvent('feather-admin:booster:request', function(action, playerId)
    local src = source
    if not FeatherAdmin.RequireAuthorized(src) then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil or allowedActions[action] ~= true then return end

    TriggerClientEvent('feather-admin:booster:apply', target, action)
end)
