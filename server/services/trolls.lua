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

FeatherAdmin.RegisterRPC('feather-admin:troll:request', function(params, _, src)
    local action, playerId, requestId = params.action, params.playerId, tonumber(params.requestId)
    local function result(succeeded)
        if requestId then TriggerClientEvent('feather-admin:troll:toggle:result', src, requestId, succeeded) end
    end
    if allowedActions[action] ~= true then result(false) return end
    local permission = ('troll.%s'):format(action)
    local target = FeatherAdmin.RequireTarget(src, permission, playerId)
    if target == nil then result(false) return end

    AdminAudit.Record(src, permission, target)
    TriggerClientEvent('feather-admin:troll:apply', target, action)
    result(true)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 256 })
