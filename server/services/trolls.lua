local allowedActions = {
    lightning_strike = true,
    freeze = true,
    teleport_to_heaven = true,
    cage = true,
    make_ped_giant = true,
    force_cinematic_camera = true,
    hostile_ped_army = true,
    kick_from_vehicle = true,
    handcuff = true,
    hostile_bear = true,
    lag = true
}

RegisterNetEvent('feather-admin:troll:request', function(action, playerId)
    local src = source
    if allowedActions[action] ~= true then return end
    if not FeatherAdmin.RequirePermission(src, ('troll.%s'):format(action)) then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil then return end

    AdminAudit.Record(src, ('troll.%s'):format(action), target)
    TriggerClientEvent('feather-admin:troll:apply', target, action)
end)
