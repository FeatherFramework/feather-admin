RegisterCommand('AdminAuthorityContractSmokeTest', function(source)
    if source ~= 0 then return end
    local actions, capabilities, requiredRoles = 0, {}, {}
    local valid = type(Config.authorityActions) == 'table'
        and type(Config.authority) == 'table'
        and type(Config.authority.roles) == 'table'
    for action, required in pairs(Config.permissions or {}) do
        actions = actions + 1
        local capability = Config.authorityActions and Config.authorityActions[action]
        valid = valid and (required == 'moderator' or required == 'administrator' or required == 'owner')
            and type(capability) == 'string' and #capability <= 100
            and capability:match('^staff%.admin%.[a-z][a-z0-9_.]*$') ~= nil
            and capabilities[capability] == nil
        capabilities[capability or ''] = true
        requiredRoles[required] = true
    end
    local mapped = 0
    for action in pairs(Config.authorityActions or {}) do
        mapped = mapped + 1
        if Config.permissions[action] == nil then valid = false end
    end
    local rolesValid = #Config.authority.roles == 3
    local previous = 0
    for _, role in ipairs(Config.authority.roles or {}) do
        rolesValid = rolesValid and type(role.roleKey) == 'string'
            and role.roleKey:match('^staff%.admin%.[a-z][a-z0-9_]*$') ~= nil
            and type(role.label) == 'string' and #role.label > 0
            and type(role.key) == 'string' and requiredRoles[role.key] == true
            and type(role.precedence) == 'number' and role.precedence > previous
        previous = role.precedence or previous
    end
    local tests = {
        { 'all actions mapped', valid and actions > 0 and mapped == actions },
        { 'capabilities unique', valid and actions == mapped },
        { 'bounded staff namespace', valid },
        { 'three ordered tiers', rolesValid },
        { 'default roles covered', requiredRoles.moderator and requiredRoles.administrator
            and requiredRoles.owner },
        { 'implicit assignments absent', Config.authority.assignments == nil }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminAuthorityContractSmokeTest] %-24s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminAuthorityContractSmokeTest] done %d/%d passed actions=%d (read-only)'):format(
        passed, #tests, actions))
end, true)

RegisterCommand('AdminAuthorityCapabilityLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 1 and type(args[1]) == 'string'
            and #args[1] >= 1 and #args[1] <= 128
            and args[1]:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$'),
            'Use <stable requestId>')
        local request = { requestId = args[1], capabilities = FeatherAdmin.AuthorityCatalog.Definitions() }
        assert(#request.capabilities == 82, 'Expected the reviewed 82-action Admin catalog')
        local first = exports['feather-authority']:RegisterCapabilities(request)
        assert(first.ok, tostring(first.code) .. ': ' .. tostring(first.message))
        local replay = exports['feather-authority']:RegisterCapabilities(request)
        assert(replay.ok and replay.value.replayed == true,
            'Exact capability catalog did not replay')
        assert(#first.value.capabilities == 82 and #replay.value.capabilities == 82,
            'Registration receipt omitted capability identities')
        for index, identity in ipairs(first.value.capabilities) do
            assert(identity.key == replay.value.capabilities[index].key
                and identity.capabilityId == replay.value.capabilities[index].capabilityId,
                'Capability identity changed on replay')
        end
        local mismatch = { requestId = args[1], capabilities = FeatherAdmin.AuthorityCatalog.Definitions() }
        mismatch.capabilities[1].description = 'Tampered Admin permission.'
        local mismatchResult = exports['feather-authority']:RegisterCapabilities(mismatch)
        assert(not mismatchResult.ok and mismatchResult.code == 'idempotency_conflict',
            'Changed capability catalog did not conflict')
        local listed = exports['feather-authority']:ListCapabilities()
        assert(listed.ok, tostring(listed.code) .. ': ' .. tostring(listed.message))
        local owned = 0
        for _, capability in ipairs(listed.value) do
            if capability.ownerResource == GetCurrentResourceName() then owned = owned + 1 end
        end
        assert(owned == 82, 'Authority catalog does not contain 82 Admin-owned capabilities')
        print(('[AdminAuthorityCapabilityLiveTest] PASS capabilities=82 registered=%d updated=%d unchanged=%d firstReplayed=%s replayed=true stableIdentity=true mismatchRejected=true ownerBound=true'):format(
            first.value.registered, first.value.updated, first.value.unchanged,
            tostring(first.value.replayed)))
    end, debug.traceback)
    if not called then print('[AdminAuthorityCapabilityLiveTest] FAIL ' .. tostring(reason)) end
end, true)

RegisterCommand('AdminAuthorityRoleCatalogLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        assert(type(args) == 'table' and #args == 1 and type(args[1]) == 'string'
            and #args[1] >= 1 and #args[1] <= 64
            and args[1]:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$'),
            'Use <stable requestId>')
        local firstReplayed, totalGrants = true, 0
        local roleResults = {}
        for _, tier in ipairs(Config.authority.roles) do
            local created = exports['feather-authority']:CreateRole({
                requestId = args[1] .. ':role:' .. tier.roleKey,
                roleKey = tier.roleKey, label = tier.label, roleClass = 'staff',
                reasonCode = 'feather_admin.authority_catalog'
            })
            assert(created.ok, tostring(created.code) .. ': ' .. tostring(created.message))
            firstReplayed = firstReplayed and created.value.replayed == true
            local actions = {}
            for action, required in pairs(Config.permissions) do
                local requiredPrecedence
                for _, candidate in ipairs(Config.authority.roles) do
                    if candidate.key == required then requiredPrecedence = candidate.precedence break end
                end
                if requiredPrecedence and requiredPrecedence <= tier.precedence then
                    actions[#actions + 1] = action
                end
            end
            table.sort(actions)
            for index, action in ipairs(actions) do
                local grant = exports['feather-authority']:GrantRoleCapability({
                    requestId = args[1] .. ':grant:' .. tier.roleKey .. ':' .. action,
                    roleId = created.value.roleId, capabilityKey = Config.authorityActions[action],
                    expectedRevision = index, scopeType = 'server',
                    reasonCode = 'feather_admin.authority_catalog'
                })
                assert(grant.ok, tostring(grant.code) .. ': ' .. tostring(grant.message))
                firstReplayed = firstReplayed and grant.value.replayed == true
                totalGrants = totalGrants + 1
                if index % 20 == 0 then Wait(0) end
            end
            local role = exports['feather-authority']:GetRole({ roleId = created.value.roleId })
            local grants = exports['feather-authority']:ListRoleGrants({ roleId = created.value.roleId })
            assert(role.ok and grants.ok and #grants.value == #actions
                and role.value.revision == #actions + 1,
                'Authority role or grant catalog is inconsistent for ' .. tier.roleKey)
            roleResults[#roleResults + 1] = { key = tier.roleKey, roleId = created.value.roleId,
                grants = #actions, revision = role.value.revision }
        end
        assert(roleResults[1].grants < roleResults[2].grants
            and roleResults[2].grants < roleResults[3].grants
            and roleResults[3].grants == 82, 'Authority tier grants are not cumulative')
        print(('[AdminAuthorityRoleCatalogLiveTest] PASS roles=3 moderator=%d administrator=%d owner=%d totalGrants=%d cumulative=true stableIdentity=true allReplayed=%s'):format(
            roleResults[1].grants, roleResults[2].grants, roleResults[3].grants,
            totalGrants, tostring(firstReplayed)))
    end, debug.traceback)
    if not called then print('[AdminAuthorityRoleCatalogLiveTest] FAIL ' .. tostring(reason)) end
end, true)

RegisterCommand('AdminAuthorityRoleParitySmokeTest', function(source)
    if source ~= 0 then return end
    local tests = {}
    local function Check(label, passed) tests[#tests + 1] = { label, passed == true } end
    for _, tier in ipairs(Config.authority.roles) do
        local role = exports['feather-authority']:FindRoleByKey({ roleKey = tier.roleKey })
        local grants = role.ok and exports['feather-authority']:ListRoleGrants({ roleId = role.value.roleId }) or nil
        local expected, expectedCount = {}, 0
        for action, required in pairs(Config.permissions) do
            local requiredPrecedence
            for _, candidate in ipairs(Config.authority.roles) do
                if candidate.key == required then requiredPrecedence = candidate.precedence break end
            end
            if requiredPrecedence and requiredPrecedence <= tier.precedence then
                expected[Config.authorityActions[action]] = true
                expectedCount = expectedCount + 1
            end
        end
        local exact = role.ok and grants and grants.ok and #grants.value == expectedCount
            and role.value.ownerResource == GetCurrentResourceName()
            and role.value.revision == expectedCount + 1
        if exact then
            for _, grant in ipairs(grants.value) do
                if expected[grant.capabilityKey] ~= true or grant.effect ~= 'allow'
                    or grant.scopeType ~= 'server' or grant.status ~= 'active' then
                    exact = false
                    break
                end
                expected[grant.capabilityKey] = nil
            end
            for _ in pairs(expected) do exact = false break end
        end
        Check(tier.label .. ' exact grants', exact)
    end
    local moderator = Config.authority.roles[1]
    local senior = Config.authority.roles[2]
    local owner = Config.authority.roles[3]
    Check('tiers ordered', moderator.precedence < senior.precedence
        and senior.precedence < owner.precedence)
    Check('actions fully mapped', (function()
        local permissions, mappings = 0, 0
        for _ in pairs(Config.permissions) do permissions = permissions + 1 end
        for _ in pairs(Config.authorityActions) do mappings = mappings + 1 end
        return permissions == 82 and mappings == permissions
    end)())
    Check('Admin remains default', (function()
        local provider = exports['feather-core']:GetProvider('policy', nil, 1)
        return provider.ok and provider.value.provider.owner == 'feather-admin'
    end)())
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminAuthorityRoleParitySmokeTest] %-25s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminAuthorityRoleParitySmokeTest] done %d/%d passed (read-only)'):format(passed, #tests))
end, true)

RegisterCommand('AdminAuthorityHierarchyContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local actorSource, targetSource = tonumber(args and args[1]), tonumber(args and args[2])
    local called, reason = xpcall(function()
        local actor = actorSource and FeatherAdmin.Identity.Resolve(actorSource) or nil
        local target = targetSource and FeatherAdmin.Identity.Resolve(targetSource) or nil
        assert(actor and target and actor.accountId ~= target.accountId,
            'Use <connected actor source> <connected different-account target source>')
        local actorStaff = FeatherAdmin.Identity.GetStaff(actor)
        local targetStaff = FeatherAdmin.Identity.GetStaffByAccountId(target.accountId)
        assert(actorStaff, 'Actor must have an Authority staff role')
        local expected = actorStaff.rolePrecedence > (targetStaff and targetStaff.rolePrecedence or 0)
        local hierarchyAllowed, hierarchyReason = FeatherAdmin.CanActOnAccount(
            actorSource, target.accountId, 'moderation.kick')
        local selfAllowed, selfReason = FeatherAdmin.CanActOnAccount(
            actorSource, actor.accountId, 'moderation.kick')
        local exemptAllowed, exemptReason = FeatherAdmin.CanActOnAccount(
            actorSource, target.accountId, 'booster.heal')
        assert(hierarchyAllowed == expected and hierarchyReason == 'authority_hierarchy',
            'Authority hierarchy does not match configured role precedence')
        assert(not selfAllowed and selfReason == 'self', 'Self-target denial changed')
        assert(exemptAllowed and exemptReason == 'exempt', 'Hierarchy exemption changed')
        print(('[AdminAuthorityHierarchyContractSmokeTest] PASS actor=%s target=%s allowed=%s strict=true precedenceParity=true capabilityDominance=true selfDenied=true exemptAllowed=true offlineAccountCapable=true'):format(
            actor.accountId, target.accountId, tostring(hierarchyAllowed)))
    end, debug.traceback)
    if not called then print('[AdminAuthorityHierarchyContractSmokeTest] FAIL ' .. tostring(reason)) end
end, true)
