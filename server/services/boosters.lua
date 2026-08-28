local allowedActions = {
    invisibility = true,
    invincibility = true,
    infinite_stamina = true,
    heal = true,
    revive = true,
    disable_fow = true,
    kill = true
}

local pendingRevives = {}
local pendingByAdmin = {}
local nextReviveRequest = 0

local function notify(adminId, key)
    TriggerClientEvent('feather-admin:booster:result', adminId, key)
end

local function clearRevive(requestId)
    local pending = pendingRevives[requestId]
    if not pending then return nil end
    pendingRevives[requestId] = nil
    if pendingByAdmin[pending.adminId] == requestId then pendingByAdmin[pending.adminId] = nil end
    return pending
end

FeatherAdmin.RegisterRPC('feather-admin:booster:request', function(params, _, src)
    local action, playerId, requestId = params.action, params.playerId, tonumber(params.requestId)
    local function result(succeeded)
        if requestId then TriggerClientEvent('feather-admin:booster:toggle:result', src, requestId, succeeded) end
    end
    if allowedActions[action] ~= true then result(false) return end
    local permission = ('booster.%s'):format(action)
    local target = FeatherAdmin.RequireTarget(src, permission, playerId)
    if target == nil then result(false) return end

    if action == 'revive' then
        if pendingByAdmin[src] then
            notify(src, 'death_check_pending')
            result(false)
            return
        end
        nextReviveRequest = nextReviveRequest + 1
        local deathRequestId = ('%s:%s:%s'):format(src, nextReviveRequest, GetGameTimer())
        pendingRevives[deathRequestId] = { adminId = src, targetId = target }
        pendingByAdmin[src] = deathRequestId
        TriggerClientEvent('feather-admin:booster:death:check', target, deathRequestId)
        CreateThread(function()
            Wait(5000)
            local pending = clearRevive(deathRequestId)
            if not pending then return end
            AdminAudit.Record(pending.adminId, 'booster.revive.blocked', pending.targetId,
                'reason=death_check_timeout')
            notify(pending.adminId, 'death_check_failed')
        end)
        return
    end

    AdminAudit.Record(src, permission, target)
    TriggerClientEvent('feather-admin:booster:apply', target, action)
    result(true)
end, { windowMs = 1000, maxCalls = 5, maxPayloadBytes = 256 })

FeatherAdmin.RegisterRPC('feather-admin:booster:death:result', function(params, _, src)
    local requestId = tostring(params.requestId or '')
    local pending = pendingRevives[requestId]
    if not pending or pending.targetId ~= src then return end
    pending = clearRevive(requestId)
    local target = FeatherAdmin.RequireTarget(pending.adminId, 'booster.revive', pending.targetId)
    if not target then
        notify(pending.adminId, 'death_check_failed')
        return
    end
    if params.isDead ~= true then
        AdminAudit.Record(pending.adminId, 'booster.revive.blocked', target, 'reason=player_not_dead')
        notify(pending.adminId, 'player_not_dead')
        return
    end
    TriggerClientEvent('feather-admin:booster:revive', target)
    AdminAudit.Record(pending.adminId, 'booster.revive', target, 'verified_dead=true')
    notify(pending.adminId, 'player_revived')
end, { windowMs = 3000, maxCalls = 3, maxPayloadBytes = 128 })

AddEventHandler('playerDropped', function()
    local dropped = source
    local ownRequest = pendingByAdmin[dropped]
    if ownRequest then clearRevive(ownRequest) end
    local targetRequests = {}
    for requestId, pending in pairs(pendingRevives) do
        if pending.targetId == dropped then targetRequests[#targetRequests + 1] = requestId end
    end
    for _, requestId in ipairs(targetRequests) do
        local pending = clearRevive(requestId)
        if pending then notify(pending.adminId, 'death_check_failed') end
    end
end)
