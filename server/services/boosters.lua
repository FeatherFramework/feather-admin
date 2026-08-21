local allowedActions = {
    invisibility = true,
    invincibility = true,
    infinite_stamina = true,
    heal = true,
    revive = true,
    disable_fow = true,
    kill = true
}

local pendingDeathChecks = {}
local pendingByTarget = {}
local nextDeathCheck = 0

local function actionResult(adminId, messageKey)
    TriggerClientEvent('feather-admin:booster:action:result', adminId, messageKey)
end

local function clearDeathCheck(requestId)
    local pending = pendingDeathChecks[requestId]
    if not pending then return nil end
    pendingDeathChecks[requestId] = nil
    if pendingByTarget[pending.target] == requestId then pendingByTarget[pending.target] = nil end
    return pending
end

local function requestDeathCheck(adminId, target)
    if pendingByTarget[target] then
        actionResult(adminId, 'death_check_pending')
        return false
    end
    nextDeathCheck = nextDeathCheck + 1
    local requestId = nextDeathCheck
    pendingDeathChecks[requestId] = {
        adminId = adminId,
        target = target,
        expiresAt = GetGameTimer() + 3000
    }
    pendingByTarget[target] = requestId
    TriggerClientEvent('feather-admin:booster:death:request', target, requestId)

    CreateThread(function()
        Wait(3000)
        local pending = clearDeathCheck(requestId)
        if not pending then return end
        if GetPlayerName(pending.adminId) then actionResult(pending.adminId, 'death_check_failed') end
    end)
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
        requestDeathCheck(src, target)
        return
    end

    AdminAudit.Record(src, permission, target)
    TriggerClientEvent('feather-admin:booster:apply', target, action)
    result(true)
end, { windowMs = 1000, maxCalls = 5, maxPayloadBytes = 256 })

FeatherAdmin.RegisterRPC('feather-admin:booster:death:result', function(params, _, src)
    local requestId = math.tointeger(tonumber(params.requestId) or -1)
    local pending = pendingDeathChecks[requestId]
    if not pending or pending.target ~= src then return end
    clearDeathCheck(requestId)

    local adminId = pending.adminId
    if GetGameTimer() > pending.expiresAt or not GetPlayerName(adminId) then return end
    local target = FeatherAdmin.RequireTarget(adminId, 'booster.revive', src)
    if target == nil then return end

    if params.dead ~= true then
        AdminAudit.Record(adminId, 'booster.revive.blocked', target, 'reason=player_not_dead')
        actionResult(adminId, 'player_not_dead')
        return
    end

    AdminAudit.Record(adminId, 'booster.revive', target)
    TriggerClientEvent('Feather:Character:Revive', target)
    actionResult(adminId, 'player_revived')
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 128 })

AddEventHandler('playerDropped', function()
    local dropped = source
    for requestId, pending in pairs(pendingDeathChecks) do
        if pending.target == dropped or pending.adminId == dropped then
            clearDeathCheck(requestId)
            if pending.target == dropped and GetPlayerName(pending.adminId) then
                actionResult(pending.adminId, 'player_not_online')
            end
        end
    end
end)
