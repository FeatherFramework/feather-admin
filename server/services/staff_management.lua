local function Trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function IsCallable(value)
    return type(value) == 'function'
        or (type(value) == 'table'
            and type(rawget(value, '__cfx_functionReference')) == 'string')
end

local function CatalogRole(roleKey)
    if roleKey == 'player' then return { key = 'player', name = 'Player', precedence = 0 } end
    for _, tier in ipairs(Config.authorityMigration.roles or {}) do
        if tier.roleKey == roleKey then
            local result = exports['feather-authority']:FindRoleByKey({ roleKey = tier.roleKey })
            if type(result) ~= 'table' or result.ok ~= true then return nil end
            return { key = tier.roleKey, name = tier.label, precedence = tier.precedence,
                roleId = result.value.roleId, revision = result.value.revision }
        end
    end
end

local function Roles(source)
    local actorPrecedence = FeatherAdmin.GetRolePrecedence(source)
    if not actorPrecedence then return {} end
    local output = { { key = 'player', name = 'Player', precedence = 0 } }
    for _, tier in ipairs(Config.authorityMigration.roles or {}) do
        if tier.precedence <= actorPrecedence then
            local role = CatalogRole(tier.roleKey)
            if role then output[#output + 1] = role end
        end
    end
    return output
end

local function Profile(characterId)
    if type(characterId) ~= 'string' then return nil end
    local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
    local implementation = type(provider) == 'table' and provider.ok == true
        and provider.value.implementation or nil
    if type(implementation) ~= 'table' or not IsCallable(implementation.GetProfile)
        or not IsCallable(implementation.GetIdentity) then return nil end
    local profile = implementation.GetProfile(characterId)
    local identity = implementation.GetIdentity(characterId)
    if type(profile) ~= 'table' or profile.ok ~= true or type(profile.value) ~= 'table'
        or type(identity) ~= 'table' or identity.ok ~= true or type(identity.value) ~= 'table'
        or identity.value.characterId ~= characterId or identity.value.status ~= 'active' then return nil end
    profile.value.accountId = identity.value.accountId
    return profile.value
end

local function StaffRole(characterId)
    local staff = FeatherAdmin.Identity.GetStaff({ characterId = characterId })
    return staff and { key = staff.roleKey, name = staff.roleName,
        precedence = staff.rolePrecedence, revision = staff.assignmentRevision }
        or { key = 'player', name = 'Player', precedence = 0, revision = 0 }
end

local function OnlineSource(characterId)
    for _, raw in ipairs(GetPlayers()) do
        local src = tonumber(raw)
        local identity = src and FeatherAdmin.Identity.Resolve(src) or nil
        if identity and identity.characterId == characterId then return src end
    end
end

local function Entry(profile, source)
    local role = StaffRole(profile.characterId)
    return {
        serverId = source, serverName = source and GetPlayerName(source) or nil,
        accountId = profile.accountId, characterId = profile.characterId,
        firstName = profile.firstName, lastName = profile.lastName,
        characterName = ('%s %s'):format(profile.firstName or '', profile.lastName or ''):gsub('%s+$', ''),
        roleKey = role.key, roleName = role.name, rolePrecedence = role.precedence,
        roleRevision = role.revision, isOnline = source ~= nil
    }
end

local function ActivePlayers(src)
    local rows = {}
    for _, raw in ipairs(GetPlayers()) do
        local target = tonumber(raw)
        local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
        if identity and identity.characterId and target ~= src then
            local allowed = FeatherAdmin.CanActOnAccount(src, identity.accountId, 'staff.role.assign')
            if allowed then rows[#rows + 1] = Entry(identity, target) end
        end
    end
    return rows
end

local function RefreshAccess(target, messageKey)
    if not target then return end
    local authorized = FeatherAdmin.IsAuthorized(target)
    TriggerClientEvent('feather-admin:access:permissions', target,
        authorized, authorized and FeatherAdmin.GetPermissions(target) or {})
    TriggerClientEvent('feather-admin:staff:role:updated', target, messageKey)
end

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
        local role = StaffRole(profile.characterId)
        local allowed = FeatherAdmin.CanActOnAccount(src, profile.accountId, 'staff.role.assign')
        if allowed and (not roleFilter or role.key == roleFilter) then
            rows[#rows + 1] = Entry(profile, OnlineSource(profile.characterId))
        end
    end
    TriggerClientEvent('feather-admin:staff:search:result', src, rows, page, result.value.hasNext)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 384 })

FeatherAdmin.RegisterRPC('feather-admin:staff:history', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.history') then return end
    local characterId, page = Trim(params.characterId), math.max(1, math.floor(tonumber(params.page) or 1))
    local profile = Profile(characterId)
    if not profile or not FeatherAdmin.CheckTargetAccountHierarchy(
        src, 'staff.history', profile.accountId, nil) then return end
    local limit = math.max(1, math.min(100, tonumber(Config.staff.historyLimit) or 20))
    local rows = MySQL.query.await([[SELECT `admin_name` AS `adminName`,
            `admin_character_name` AS `adminCharacterName`,`details`,
            DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS `createdAt`
        FROM `feather_admin_actions` WHERE `target_character_id`=? AND `action`='staff.role.assign'
        ORDER BY `id` DESC LIMIT ? OFFSET ?]], { characterId, limit + 1, (page - 1) * limit }) or {}
    local hasNext = #rows > limit
    if hasNext then table.remove(rows) end
    TriggerClientEvent('feather-admin:staff:history:result', src, rows, page, hasNext)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:staff:role:assign', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.role.assign') then return end
    local characterId, roleKey = Trim(params.characterId), Trim(params.roleKey)
    local profile, desiredRole = Profile(characterId), CatalogRole(roleKey)
    local actorIdentity = FeatherAdmin.Identity.Resolve(src)
    local actorStaff = FeatherAdmin.Identity.GetStaff(actorIdentity)
    if not profile or not desiredRole or not actorStaff
        or desiredRole.precedence > actorStaff.rolePrecedence
        or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'staff.role.assign',
            profile.accountId, OnlineSource(characterId)) then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_too_high')
    end
    local oldRole = StaffRole(profile.characterId)
    local idempotencyKey, reason = Trim(params.idempotencyKey), Trim(params.reason)
    local request = { requestId = idempotencyKey, subjectType = 'character', subjectId = profile.characterId,
        scopeType = 'server', reason = reason, reasonCode = 'feather_admin.staff_assignment' }
    if desiredRole.roleId then
        request.roleId = desiredRole.roleId
        request.expectedRoleRevision = desiredRole.revision
    end
    local result = exports['feather-authority']:ReplaceOwnedStaffAssignment(request)
    if type(result) ~= 'table' or result.ok ~= true then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false,
            type(result) == 'table' and result.code or 'authority_assignment_failed')
    end
    local direction = desiredRole.precedence > oldRole.precedence and 'promoted'
        or desiredRole.precedence < oldRole.precedence and 'demoted' or 'changed'
    local target = OnlineSource(characterId)
    RefreshAccess(target, 'your_staff_role_' .. direction)
    AdminAudit.RecordTarget(src, 'staff.role.assign', {
        accountId = profile.accountId, characterId = profile.characterId,
        license = target and FeatherAdmin.Core.User.GetLicense(target) or nil,
        name = target and GetPlayerName(target) or nil, characterName = ('%s %s'):format(
            profile.firstName or '', profile.lastName or ''):gsub('%s+$', '')
    }, ('old=%s new=%s authorityAssignment=%s replayed=%s reason=%s'):format(
        oldRole.name, desiredRole.name,
        tostring(result.value.assignmentId or 'cleared'), tostring(result.value.replayed), reason))
    TriggerClientEvent('feather-admin:staff:role:result', src, true, 'staff_role_' .. direction)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 384 })

RegisterCommand('AdminBootstrapOwner', function(source, args)
    if source ~= 0 then return end
    local target, requestId = tonumber(args and args[1]), Trim(args and args[2])
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    local owner = CatalogRole('staff.admin.owner')
    if not identity or type(identity.accountId) ~= 'string' or not owner
        or requestId == '' or #requestId > 128
        or not requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') then
        return print('[AdminBootstrapOwner] FAIL use <connected source> <stable requestId>')
    end
    local result = exports['feather-authority']:ReplaceOwnedStaffAssignment({
        requestId = requestId, subjectType = 'character', subjectId = identity.characterId,
        roleId = owner.roleId, expectedRoleRevision = owner.revision, scopeType = 'server',
        reason = 'Bootstrap the initial Feather Admin owner.',
        reasonCode = 'feather_admin.owner_bootstrap'
    })
    if type(result) ~= 'table' or result.ok ~= true then
        return print(('[AdminBootstrapOwner] FAIL code=%s message=%s'):format(
            tostring(type(result) == 'table' and result.code or 'invalid_result'),
            tostring(type(result) == 'table' and result.message or 'invalid result')))
    end
    RefreshAccess(target, 'your_staff_role_promoted')
    AdminAudit.RecordTarget(0, 'staff.owner.bootstrap', {
        accountId = identity.accountId, characterId = identity.characterId,
        name = identity.accountName, characterName = identity.characterName
    }, ('authorityAssignment=%s replayed=%s request=%s'):format(
        tostring(result.value.assignmentId), tostring(result.value.replayed), requestId))
    print(('[AdminBootstrapOwner] PASS account=%s assignment=%s replayed=%s'):format(
        identity.accountId, tostring(result.value.assignmentId), tostring(result.value.replayed)))
end, true)

RegisterCommand('AdminAuthorityStaffAssignmentContractSmokeTest', function(source)
    if source ~= 0 then return end
    local authority = exports['feather-authority']:GetCapabilities()
    local tiers, exact, owned = 0, true, true
    for _, tier in ipairs(Config.authorityMigration.roles or {}) do
        local role = CatalogRole(tier.roleKey)
        tiers = tiers + 1
        exact = exact and role ~= nil and role.key == tier.roleKey
            and role.precedence == tier.precedence
        local persisted = role and exports['feather-authority']:FindRoleByKey({ roleKey = role.key }) or nil
        owned = owned and type(persisted) == 'table' and persisted.ok == true
            and persisted.value.ownerResource == GetCurrentResourceName()
    end
    local player = CatalogRole('player')
    local tests = {
        { 'replacement available', authority.ok and authority.value.features.assignmentReplacement == 1 },
        { 'three Authority tiers mapped', tiers == 3 and exact },
        { 'Authority roles owner-bound', owned },
        { 'player clears assignment', player and player.precedence == 0 and player.roleId == nil },
        { 'Authority-native reads', authority.ok and authority.value.features.assignmentReads == 1 },
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
    if not identity or type(identity.accountId) ~= 'string' then
        return print('[AdminAuthorityStaffAssignmentState] FAIL use <connected target source>')
    end
    local staff = FeatherAdmin.Identity.GetStaff(identity)
    local effective = exports['feather-authority']:ListEffectiveCapabilities({
        subjectType = 'character', subjectId = identity.characterId, scopeType = 'server'
    })
    if type(effective) ~= 'table' or effective.ok ~= true then
        return print('[AdminAuthorityStaffAssignmentState] FAIL Authority state unavailable')
    end
    local mapped, count = {}, 0
    for _, capability in pairs(Config.authorityActions or {}) do mapped[capability] = true end
    for _, capability in ipairs(effective.value.capabilities or {}) do
        if mapped[capability] then count = count + 1 end
    end
    local expected, selectedTier = 0, nil
    if staff then
        for _, tier in ipairs(Config.authorityMigration.roles or {}) do
            if tier.roleKey == staff.roleKey then selectedTier = tier break end
        end
    end
    if selectedTier then
        for _, required in pairs(Config.permissions or {}) do
            for _, tier in ipairs(Config.authorityMigration.roles or {}) do
                if tier.key == required and tier.precedence <= selectedTier.precedence then
                    expected = expected + 1
                    break
                end
            end
        end
    end
    print(('[AdminAuthorityStaffAssignmentState] %s account=%s authorityRole=%s effectiveAdmin=%d expected=%d aligned=%s'):format(
        count == expected and 'PASS' or 'FAIL', identity.accountId, staff and staff.roleKey or 'player',
        count, expected, tostring(count == expected)))
end, true)

RegisterCommand('AdminCharacterIsolationHierarchyLiveTest', function(source, args)
    if source ~= 0 then return end
    local actorSource, targetSource = tonumber(args and args[1]), tonumber(args and args[2])
    local otherCharacterId = Trim(args and args[3])
    local called, reason = xpcall(function()
        local actor = actorSource and FeatherAdmin.Identity.Resolve(actorSource) or nil
        local target = targetSource and FeatherAdmin.Identity.Resolve(targetSource) or nil
        local other = Profile(otherCharacterId)
        assert(actor and target and other and actor.accountId ~= target.accountId
            and target.accountId == other.accountId and target.characterId ~= other.characterId,
            'Use <connected actor source> <connected different-account target source> <other target character UUID>')
        local activeRole = StaffRole(target.characterId)
        local otherRole = StaffRole(other.characterId)
        local highest = FeatherAdmin.Identity.GetStaffByAccountId(target.accountId)
        local expectedPrecedence = highest and highest.rolePrecedence or 0
        assert(expectedPrecedence >= activeRole.precedence and expectedPrecedence >= otherRole.precedence,
            'Target account highest character role did not dominate both character roles')
        local actorRole = StaffRole(actor.characterId)
        local allowed, hierarchyReason = FeatherAdmin.CanActOnAccount(
            actorSource, target.accountId, 'moderation.kick')
        assert(allowed == (actorRole.precedence > expectedPrecedence)
            and hierarchyReason == 'authority_hierarchy',
            'Hierarchy did not use the target account highest character role')
        local activeEffective = exports['feather-authority']:ListEffectiveCapabilities({
            subjectType = 'character', subjectId = target.characterId, scopeType = 'server'
        })
        local otherEffective = exports['feather-authority']:ListEffectiveCapabilities({
            subjectType = 'character', subjectId = other.characterId, scopeType = 'server'
        })
        assert(activeEffective.ok and otherEffective.ok,
            'Character-specific effective capability reads failed')
        print(('[AdminCharacterIsolationHierarchyLiveTest] PASS actorCharacter=%s targetAccount=%s activeCharacter=%s activeRole=%s otherCharacter=%s otherRole=%s highestRole=%s hierarchyAllowed=%s isolatedReads=true'):format(
            actor.characterId, target.accountId, target.characterId, activeRole.key,
            other.characterId, otherRole.key, highest and highest.roleKey or 'player', tostring(allowed)))
    end, debug.traceback)
    if not called then print('[AdminCharacterIsolationHierarchyLiveTest] FAIL ' .. tostring(reason)) end
end, true)
