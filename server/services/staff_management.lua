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

local function CatalogRole(roleKey)
    local result = exports['feather-roles']:GetCatalog(false)
    if type(result) ~= 'table' or result.ok ~= true then return nil end
    for _, role in ipairs(result.value or {}) do
        if role.key == roleKey then return role end
    end
end

local function AuthorityRoleForLegacy(role)
    if type(role) ~= 'table' or type(role.level) ~= 'number' then return nil, 'invalid_role' end
    local roles = type(Config.authorityMigration) == 'table' and Config.authorityMigration.roles or {}
    for _, tier in ipairs(roles or {}) do
        if tier.legacyLevel == role.level then
            local result = exports['feather-authority']:FindRoleByKey({ roleKey = tier.roleKey })
            if type(result) ~= 'table' or result.ok ~= true then return nil, 'authority_role_unavailable' end
            return result.value
        end
    end
    local minimum = roles and roles[1] and tonumber(roles[1].legacyLevel) or 50
    if role.level < minimum then return false end
    return nil, 'unmapped_staff_role'
end

local function AssignLegacyRole(request)
    local result
    for attempt = 1, 2 do
        result = exports['feather-roles']:AssignCharacterRole(request)
        if type(result) == 'table' and result.ok == true then return result end
        local code = type(result) == 'table' and result.code or 'invalid_result'
        if code ~= 'conflict' and code ~= 'transaction_failed' then break end
        print(('[feather-admin] event=staff.assignment.retry attempt=%d code=%s request=%s'):format(
            attempt, tostring(code), tostring(request.idempotencyKey)))
        Wait(100)
    end
    return result
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
    local characterId, roleKey = Trim(params.characterId), Trim(params.roleKey)
    local targetState, desiredRole = RoleState(characterId), CatalogRole(roleKey)
    local actorIdentity = FeatherAdmin.Identity.Resolve(src)
    local actorStaff = FeatherAdmin.Identity.GetStaff(actorIdentity)
    if not targetState or not desiredRole or not actorStaff
        or desiredRole.level > actorStaff.roleLevel
        or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'staff.role.assign',
            targetState.accountId, OnlineSource(characterId)) then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_too_high')
    end
    local authorityRole, authorityError = AuthorityRoleForLegacy(desiredRole)
    if authorityError then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, authorityError)
    end
    local idempotencyKey, reason = Trim(params.idempotencyKey), Trim(params.reason)
    local replacementRequest = { requestId = idempotencyKey, subjectType = 'account',
        subjectId = targetState.accountId, scopeType = 'server', reason = reason,
        reasonCode = 'feather_admin.staff_assignment' }
    if authorityRole then
        replacementRequest.roleId = authorityRole.roleId
        replacementRequest.expectedRoleRevision = authorityRole.revision
    end
    local authorityResult = exports['feather-authority']:ReplaceOwnedStaffAssignment(replacementRequest)
    if type(authorityResult) ~= 'table' or authorityResult.ok ~= true then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false,
            authorityResult and authorityResult.code or 'authority_assignment_failed')
    end
    local session = exports['feather-core']:GetSessionContext(src)
    local correlationId = ('admin-role:%s'):format(idempotencyKey)
    local result = AssignLegacyRole({
        characterId = characterId, roleKey = roleKey,
        reasonCode = 'feather-admin.staff_assignment', reason = reason,
        idempotencyKey = idempotencyKey, correlationId = correlationId,
        actorSource = src,
        expectedSessionId = type(session) == 'table' and session.ok == true and session.value.sessionId or nil,
        expectedRevision = tonumber(params.expectedRevision)
    })
    if type(result) ~= 'table' or result.ok ~= true then
        print(('[feather-admin] event=staff.assignment.reconciliation_required code=%s request=%s character=%s authorityAssignment=%s'):format(
            tostring(type(result) == 'table' and result.code or 'invalid_result'), idempotencyKey,
            characterId, tostring(authorityResult.value.assignmentId or 'cleared')))
        local key = result and result.code == 'unchanged' and 'staff_role_unchanged'
            or result and result.code == 'hierarchy_denied' and 'staff_role_too_high'
            or result and (result.code == 'conflict' or result.code == 'transaction_failed')
                and 'staff_role_retry_required'
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
        ('character=%s old=%s(%s) new=%s(%s) authorityAssignment=%s authorityReplayed=%s reason=%s'):format(result.value.characterId,
            result.value.oldRole.name, result.value.oldRole.level, result.value.role.name,
            result.value.role.level, tostring(authorityResult.value.assignmentId or 'cleared'),
            tostring(authorityResult.value.replayed), reason))
    TriggerClientEvent('feather-admin:staff:role:result', src, true, 'staff_role_' .. direction)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 384 })

RegisterCommand('AdminAuthorityStaffAssignmentContractSmokeTest', function(source)
    if source ~= 0 then return end
    local authority = exports['feather-authority']:GetCapabilities()
    local catalog = exports['feather-roles']:GetCatalog(false)
    local tiers, exact, owned = 0, true, true
    for _, tier in ipairs(Config.authorityMigration.roles or {}) do
        local legacy
        for _, role in ipairs(type(catalog) == 'table' and catalog.ok and catalog.value or {}) do
            if role.level == tier.legacyLevel then legacy = role break end
        end
        local mapped, mappingError = legacy and AuthorityRoleForLegacy(legacy) or nil, nil
        if legacy then mapped, mappingError = AuthorityRoleForLegacy(legacy) end
        tiers = tiers + 1
        exact = exact and legacy ~= nil and mapped ~= nil and mappingError == nil
            and mapped.roleKey == tier.roleKey
        owned = owned and mapped ~= nil and mapped.ownerResource == GetCurrentResourceName()
    end
    local playerRole
    for _, role in ipairs(type(catalog) == 'table' and catalog.ok and catalog.value or {}) do
        if role.level < Config.authorityMigration.roles[1].legacyLevel then playerRole = role break end
    end
    local cleared, clearError = playerRole and AuthorityRoleForLegacy(playerRole) or nil, 'missing_player_role'
    if playerRole then cleared, clearError = AuthorityRoleForLegacy(playerRole) end
    local tests = {
        { 'replacement available', authority.ok
            and authority.value.features.assignmentReplacement == 1 },
        { 'three legacy tiers mapped', tiers == 3 and exact },
        { 'Authority roles owner-bound', owned },
        { 'nonstaff role clears access', playerRole ~= nil and cleared == false and clearError == nil },
        { 'enforcement enabled', Config.authorityMigration.enforcement == true },
        { 'hierarchy enabled', Config.authorityMigration.hierarchy == true }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminAuthorityStaffAssignmentContractSmokeTest] %-29s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminAuthorityStaffAssignmentContractSmokeTest] done %d/%d passed (no assignments changed)'):format(
        passed, #tests))
end, true)

RegisterCommand('AdminAuthorityStaffAssignmentState', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    if not identity or type(identity.accountId) ~= 'string' or type(identity.characterId) ~= 'string' then
        return print('[AdminAuthorityStaffAssignmentState] FAIL use <connected target source>')
    end
    local state = RoleState(identity.characterId)
    local effective = exports['feather-authority']:ListEffectiveCapabilities({
        subjectType = 'account', subjectId = identity.accountId, scopeType = 'server'
    })
    if not state or type(effective) ~= 'table' or effective.ok ~= true then
        return print('[AdminAuthorityStaffAssignmentState] FAIL role or Authority state unavailable')
    end
    local mapped, count = {}, 0
    for _, capability in pairs(Config.authorityActions or {}) do mapped[capability] = true end
    for _, capability in ipairs(effective.value.capabilities or {}) do
        if mapped[capability] then count = count + 1 end
    end
    local expected = 0
    for _, tier in ipairs(Config.authorityMigration.roles or {}) do
        if tier.legacyLevel == state.role.level then
            for _, required in pairs(Config.permissions or {}) do
                if tonumber(required) <= tier.legacyLevel then expected = expected + 1 end
            end
        end
    end
    print(('[AdminAuthorityStaffAssignmentState] %s account=%s character=%s legacyRole=%s legacyLevel=%d effectiveAdmin=%d expected=%d aligned=%s'):format(
        count == expected and 'PASS' or 'FAIL', identity.accountId, identity.characterId,
        state.role.key, state.role.level, count, expected, tostring(count == expected)))
end, true)
