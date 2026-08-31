local function Trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function Roles(source)
    local result = exports['feather-roles']:GetCatalog(false)
    local actorLevel = FeatherAdmin.GetRoleLevel(source)
    local output = {}
    if type(result) == 'table' and result.ok == true and actorLevel then
        for _, role in ipairs(result.value) do
            if role.level <= actorLevel then output[#output + 1] = role end
        end
    end
    return output
end

local function RoleFor(characterId)
    local result = exports['feather-roles']:GetCharacterRole(characterId)
    return type(result) == 'table' and result.ok == true and result.value.role or nil
end

local function RoleState(characterId)
    local result = exports['feather-roles']:GetCharacterRole(characterId)
    return type(result) == 'table' and result.ok == true and result.value or nil
end

local function OnlineSource(characterId)
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        local identity = src and FeatherAdmin.Identity.Resolve(src) or nil
        if identity and identity.characterId == characterId then return src end
    end
end

local function Entry(profile, source)
    local state = RoleState(profile.characterId)
    local role = state and state.role or { key = 'player', name = 'Player', level = 0 }
    return {
        serverId = source,
        serverName = source and GetPlayerName(source) or nil,
        accountId = profile.accountId,
        characterId = profile.characterId,
        firstName = profile.firstName,
        lastName = profile.lastName,
        characterName = ('%s %s'):format(profile.firstName or '', profile.lastName or ''):gsub('%s+$', ''),
        roleKey = role.key, roleName = role.name, roleLevel = role.level,
        roleRevision = state and state.revision or 0,
        isOnline = source ~= nil
    }
end

local function ActivePlayers(src)
    local rows = {}
    for _, raw in ipairs(GetPlayers()) do
        local target = tonumber(raw)
        local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
        if identity and identity.characterId and target ~= src then
            local allowed = FeatherAdmin.CanActOnAccount(src, identity.accountId, 'staff.role.assign')
            if allowed then
                rows[#rows + 1] = Entry(identity, target)
            end
        end
    end
    return rows
end

local roleSubscription
local function RefreshRoleAccess(payload)
    local target = type(payload) == 'table' and OnlineSource(payload.characterId) or nil
    if not target then return end
    local authorized = FeatherAdmin.IsAuthorized(target)
    TriggerClientEvent('feather-admin:access:permissions', target,
        authorized, authorized and FeatherAdmin.GetPermissions(target) or {})
end

local function SubscribeRoleChanges()
    if roleSubscription then return end
    local ready = exports['feather-roles']:AwaitReady(10000)
    if type(ready) ~= 'table' or ready.ok ~= true then return end
    local result = exports['feather-core']:SubscribeEvent('roles.assignment.changed.v1', RefreshRoleAccess)
    if type(result) == 'table' and result.ok == true then roleSubscription = result.value.token end
end

CreateThread(function()
    while GetResourceState('feather-roles') ~= 'started' do Wait(0) end
    Wait(0)
    SubscribeRoleChanges()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-roles' then roleSubscription = nil end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'feather-roles' then return end
    CreateThread(function()
        while GetResourceState('feather-roles') ~= 'started' do Wait(0) end
        Wait(0)
        SubscribeRoleChanges()
    end)
end)

FeatherAdmin.RegisterRPC('feather-admin:staff:list', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.view') then return end
    if params.playerId then
        local target = FeatherAdmin.ValidTarget(params.playerId)
        local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
        if not identity or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'staff.role.assign',
            identity.accountId, target) then return end
    end
    TriggerClientEvent('feather-admin:staff:list:result', src, Roles(src), ActivePlayers(src))
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 96 })

FeatherAdmin.RegisterRPC('feather-admin:staff:search', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.search') then return end
    local query, page = Trim(params.query), math.max(1, math.floor(tonumber(params.page) or 1))
    local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
    local implementation = provider and provider.ok and provider.value.implementation or nil
    local result = implementation and implementation.SearchProfiles(query, page,
        math.max(1, math.min(100, tonumber(Config.staff.searchLimit) or 20))) or nil
    if type(result) ~= 'table' or result.ok ~= true then
        return TriggerClientEvent('feather-admin:staff:search:result', src, {}, page, false,
            'invalid_staff_search')
    end
    local rows, roleFilter = {}, Trim(params.roleKey)
    if roleFilter == '' then roleFilter = nil end
    for _, profile in ipairs(result.value.profiles or {}) do
        local role = RoleFor(profile.characterId)
        local allowed = FeatherAdmin.CanActOnAccount(src, profile.accountId, 'staff.role.assign')
        if allowed and role and (not roleFilter or role.key == roleFilter) then
            rows[#rows + 1] = Entry(profile, OnlineSource(profile.characterId))
        end
    end
    TriggerClientEvent('feather-admin:staff:search:result', src, rows, page, result.value.hasNext)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 384 })

FeatherAdmin.RegisterRPC('feather-admin:staff:history', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.history') then return end
    local characterId, page = Trim(params.characterId), math.max(1, math.floor(tonumber(params.page) or 1))
    local role = exports['feather-roles']:GetCharacterRole(characterId)
    if type(role) ~= 'table' or role.ok ~= true
        or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'staff.history', role.value.accountId,
            OnlineSource(characterId)) then return end
    local history = exports['feather-roles']:GetHistory(characterId, page,
        math.max(1, math.min(100, tonumber(Config.staff.historyLimit) or 20)))
    if type(history) ~= 'table' or history.ok ~= true then
        return TriggerClientEvent('feather-admin:staff:history:result', src, {}, page, false,
            'staff_history_failed')
    end
    TriggerClientEvent('feather-admin:staff:history:result', src, history.value.rows,
        history.value.page, history.value.hasNext)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:staff:role:assign', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.role.assign') then return end
    local session = exports['feather-core']:GetSessionContext(src)
    local correlationId = ('admin-role:%s'):format(Trim(params.idempotencyKey))
    local result = exports['feather-roles']:AssignCharacterRole({
        characterId = Trim(params.characterId), roleKey = Trim(params.roleKey),
        reasonCode = 'feather-admin.staff_assignment', reason = Trim(params.reason),
        idempotencyKey = Trim(params.idempotencyKey), correlationId = correlationId,
        actorSource = src,
        expectedSessionId = type(session) == 'table' and session.ok == true and session.value.sessionId or nil,
        expectedRevision = tonumber(params.expectedRevision)
    })
    if type(result) ~= 'table' or result.ok ~= true then
        local key = result and result.code == 'unchanged' and 'staff_role_unchanged'
            or result and result.code == 'hierarchy_denied' and 'staff_role_too_high'
            or 'staff_role_update_failed'
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, key)
    end
    local direction = result.value.role.level > result.value.oldRole.level and 'promoted'
        or result.value.role.level < result.value.oldRole.level and 'demoted' or 'changed'
    local target = OnlineSource(result.value.characterId)
    if target then
        TriggerClientEvent('feather-admin:staff:role:updated', target, 'your_staff_role_' .. direction)
    end
    AdminAudit.Record(src, 'staff.role.assign', target,
        ('character=%s old=%s(%s) new=%s(%s) reason=%s'):format(result.value.characterId,
            result.value.oldRole.name, result.value.oldRole.level, result.value.role.name,
            result.value.role.level, Trim(params.reason)))
    TriggerClientEvent('feather-admin:staff:role:result', src, true, 'staff_role_' .. direction)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 384 })
