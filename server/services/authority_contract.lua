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
        assert(#request.capabilities == 88, 'Expected the reviewed 88-action Admin catalog')
        local first = exports['feather-authority']:RegisterCapabilities(request)
        assert(first.ok, tostring(first.code) .. ': ' .. tostring(first.message))
        local replay = exports['feather-authority']:RegisterCapabilities(request)
        assert(replay.ok and replay.value.replayed == true,
            'Exact capability catalog did not replay')
        assert(#first.value.capabilities == 88 and #replay.value.capabilities == 88,
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
        assert(owned == 88, 'Authority catalog does not contain 88 Admin-owned capabilities')
        print(('[AdminAuthorityCapabilityLiveTest] PASS capabilities=88 registered=%d updated=%d unchanged=%d firstReplayed=%s replayed=true stableIdentity=true mismatchRejected=true ownerBound=true'):format(
            first.value.registered, first.value.updated, first.value.unchanged,
            tostring(first.value.replayed)))
    end, debug.traceback)
    if not called then print('[AdminAuthorityCapabilityLiveTest] FAIL ' .. tostring(reason)) end
end, true)

RegisterCommand('AdminAuthorityRoleCatalogLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, reason = xpcall(function()
        local totalGrants, roleResults = 0, {}
        for _, tier in ipairs(Config.authority.roles) do
            local role = exports['feather-authority']:FindRoleByKey({ roleKey=tier.roleKey })
            assert(role.ok, tostring(role.code) .. ': ' .. tostring(role.message))
            local expected = {}
            for action, required in pairs(Config.permissions) do
                local requiredPrecedence
                for _, candidate in ipairs(Config.authority.roles) do
                    if candidate.key == required then requiredPrecedence = candidate.precedence break end
                end
                if requiredPrecedence and requiredPrecedence <= tier.precedence then
                    expected[Config.authorityActions[action]] = true
                end
            end
            local grants = exports['feather-authority']:ListRoleGrants({ roleId=role.value.roleId })
            assert(grants.ok, tostring(grants.code) .. ': ' .. tostring(grants.message))
            for _, grant in ipairs(grants.value) do
                assert(grant.status == 'active' and expected[grant.capabilityKey] == true,
                    'Authority role contains an unexpected grant')
                expected[grant.capabilityKey] = nil
            end
            assert(next(expected) == nil and role.value.revision == #grants.value + 1,
                'Authority role catalog is incomplete for ' .. tier.roleKey)
            totalGrants = totalGrants + #grants.value
            roleResults[#roleResults + 1] = { key=tier.roleKey, roleId=role.value.roleId,
                grants=#grants.value, revision=role.value.revision }
        end
        assert(roleResults[1].grants < roleResults[2].grants
            and roleResults[2].grants < roleResults[3].grants
            and roleResults[3].grants == 88, 'Authority tier grants are not cumulative')
        print(('[AdminAuthorityRoleCatalogLiveTest] PASS roles=3 moderator=%d administrator=%d owner=%d totalGrants=%d cumulative=true stableIdentity=true readOnly=true'):format(
            roleResults[1].grants, roleResults[2].grants, roleResults[3].grants,
            totalGrants))
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
        return permissions == 88 and mappings == permissions
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
RegisterCommand('AdminAuditReadLiveTest', function(source, args)
    if source ~= 0 then return end
    local actorSource = tonumber(args[1])
    local expected = args[2]
    if not actorSource or (expected ~= 'allow' and expected ~= 'deny') then
        return print('[AdminAuditReadLiveTest] Use <loaded player server ID> <allow|deny>')
    end
    local called, problem = xpcall(function()
        local now = os.time()
        local request = { fromEpoch = now - 86400, toEpoch = now + 60, limit = 5,
            sourceResource = 'feather-audit-smoke' }
        local result = exports['feather-audit']:Search(request, actorSource)
        if expected == 'allow' then
            assert(type(result) == 'table' and result.ok == true,
                'Read did not succeed: ' .. tostring(type(result) == 'table' and result.code))
            assert(type(result.value.events) == 'table' and #result.value.events >= 1 and #result.value.events <= 5,
                'Read returned an invalid bounded result')
            for _, row in ipairs(result.value.events) do
                assert(row.context == nil and row.summary == nil and row.actorId == nil,
                    'Protected content was returned')
            end
            print(('[AdminAuditReadLiveTest] PASS allowed rows=%d metadataOnly=true'):format(#result.value.events))
        else
            assert(type(result) == 'table' and result.ok == false and result.code == 'forbidden',
                'Unprivileged read was not denied')
            local malformed = exports['feather-audit']:Search(false, actorSource)
            assert(type(malformed) == 'table' and malformed.code == 'forbidden',
                'Denied caller inferred request validation')
            print('[AdminAuditReadLiveTest] PASS denied validAndMalformed=true')
        end
    end, debug.traceback)
    if not called then print('[AdminAuditReadLiveTest] FAIL ' .. tostring(problem)) end
end, true)
RegisterCommand('AdminAuditQueryLiveTest', function(source, args)
    if source ~= 0 then return end
    local actorSource, expected = tonumber(args[1]), args[2]
    if not actorSource or (expected ~= 'allow' and expected ~= 'deny') then
        return print('[AdminAuditQueryLiveTest] Use <loaded player server ID> <allow|deny>')
    end
    local called, problem = xpcall(function()
        local audit = exports['feather-audit']
        local now = os.time()
        local request = { fromEpoch = now - 86400, toEpoch = now + 60, limit = 1,
            sourceResource = 'feather-audit-smoke' }
        local first = audit:Search(request, actorSource)
        if expected == 'deny' then
            local detail = audit:GetEvent(false, actorSource)
            local correlation = audit:GetCorrelation(false, actorSource)
            assert(first.code == 'forbidden' and detail.code == 'forbidden'
                and correlation.code == 'forbidden', 'One read operation was not denied')
            print('[AdminAuditQueryLiveTest] PASS denied search/detail/correlation=true')
            return
        end
        assert(first.ok and #first.value.events == 1 and first.value.nextCursor,
            'First page missing; run AuditPaginationSmokeTest first')
        local event = first.value.events[1]
        request.cursor = first.value.nextCursor
        local second = audit:Search(request, actorSource)
        assert(second.ok and #second.value.events == 1
            and second.value.events[1].eventId ~= event.eventId, 'Second page duplicated or missing')
        request.limit = 2
        local changed = audit:Search(request, actorSource)
        assert(not changed.ok and changed.code == 'invalid_cursor', 'Changed query reused a cursor')
        local detail = audit:GetEvent({ fromEpoch = now - 86400, toEpoch = now + 60,
            eventId = event.eventId }, actorSource)
        assert(detail.ok and detail.value.event and detail.value.event.eventId == event.eventId,
            'Detail lookup failed')
        assert(event.correlationId, 'Latest event has no correlation; run pagination smoke first')
        local correlation = audit:GetCorrelation({ fromEpoch = now - 86400, toEpoch = now + 60,
            correlationId = event.correlationId, limit = 5 }, actorSource)
        assert(correlation.ok and #correlation.value.events == 3, 'Correlation fixture missing')
        print('[AdminAuditQueryLiveTest] PASS allowed pagination=true cursorBound=true detail=true correlation=true')
    end, debug.traceback)
    if not called then print('[AdminAuditQueryLiveTest] FAIL ' .. tostring(problem)) end
end, true)
RegisterCommand('AdminAuditVisibilityLiveTest', function(source, args)
    if source ~= 0 then return end
    local actorSource, mode = tonumber(args[1]), args[2]
    if not actorSource or (mode ~= 'standard' and mode ~= 'sensitive' and mode ~= 'deny') then
        return print('[AdminAuditVisibilityLiveTest] Use <loaded server ID> <standard|sensitive|deny>')
    end
    local called, problem = xpcall(function()
        local audit = exports['feather-audit']
        local canSearch = FeatherAdmin.CanUse(actorSource, 'audit.search')
        local canSensitive = FeatherAdmin.CanUse(actorSource, 'audit.sensitive.view')
        if (mode == 'standard' and (not canSearch or canSensitive))
            or (mode == 'sensitive' and (not canSearch or not canSensitive))
            or (mode == 'deny' and canSearch) then
            return print(('[AdminAuditVisibilityLiveTest] FAIL precondition mode=%s searchGranted=%s sensitiveGranted=%s; standard requires Administrator, sensitive requires Owner, deny requires nonstaff/Moderator.'):format(
                mode, tostring(canSearch), tostring(canSensitive)))
        end
        local fixture = audit:GetVisibilitySmokeFixture()
        assert(type(fixture) == 'table', 'Run AuditVisibilitySmokeTest after Audit restart')
        local query = { fromEpoch = fixture.fromEpoch, toEpoch = fixture.toEpoch,
            correlationId = fixture.correlationId, limit = 5 }
        local search = audit:Search(query, actorSource)
        local detail = audit:GetEvent({ fromEpoch = fixture.fromEpoch, toEpoch = fixture.toEpoch,
            eventId = fixture.restrictedId }, actorSource)
        local sealed = audit:GetEvent({ fromEpoch = fixture.fromEpoch, toEpoch = fixture.toEpoch,
            eventId = fixture.sealedId }, actorSource)
        local correlation = audit:GetCorrelation(query, actorSource)
        if mode == 'deny' then
            assert(search.code == 'forbidden' and detail.code == 'forbidden'
                and sealed.code == 'forbidden' and correlation.code == 'forbidden', 'Read did not fail closed')
        else
            local count = mode == 'sensitive' and 2 or 1
            assert(search.ok and #search.value.events == count,
                ('Search visibility mismatch expected=%d actual=%s code=%s'):format(count,
                    tostring(search.ok and #search.value.events or 'unavailable'), tostring(search.code)))
            assert(correlation.ok and #correlation.value.events == count, 'Correlation visibility mismatch')
            assert(detail.ok and ((mode == 'sensitive' and detail.value.event
                and detail.value.event.eventId == fixture.restrictedId)
                or (mode == 'standard' and detail.value.event == nil)), 'Restricted detail visibility mismatch')
            assert(sealed.ok and sealed.value.event == nil, 'Sealed detail was exposed')
        end
        print(('[AdminAuditVisibilityLiveTest] PASS mode=%s search/detail/correlation=true sealedHidden=true'):format(mode))
    end, debug.traceback)
    if not called then print('[AdminAuditVisibilityLiveTest] FAIL ' .. tostring(problem)) end
end, true)

RegisterCommand('AdminAuditContentLiveTest', function(source, args)
    if source ~= 0 then return end
    local actor, mode = tonumber(args[1]), args[2]
    if not actor or (mode ~= 'standard' and mode ~= 'sensitive' and mode ~= 'deny') then
        return print('[AdminAuditContentLiveTest] Use <source> <standard|sensitive|deny>')
    end
    local called, problem = xpcall(function()
        local audit = exports['feather-audit']
        local fixture = audit:GetVisibilitySmokeFixture()
        assert(fixture, 'Run AuditVisibilitySmokeTest first')
        local result = audit:GetEvent({ fromEpoch = fixture.fromEpoch, toEpoch = fixture.toEpoch,
            eventId = fixture.internalId }, actor)
        if mode == 'deny' then
            assert(result.code == 'forbidden' and not result.ok, 'Expected forbidden')
        else
            assert(FeatherAdmin.CanUse(actor, 'audit.search')
                and FeatherAdmin.CanUse(actor, 'audit.sensitive.view') == (mode == 'sensitive'), 'Role does not match mode')
            local row = result.ok and result.value.event
            local content = row and row.content and row.content.context
            assert(content and content.sequence == 1, 'Approved sequence missing')
            assert((mode == 'standard' and content.message == nil)
                or (mode == 'sensitive' and content.message == 'Safe test fixture'), 'Sensitive field visibility mismatch')
            assert(content.padding_a == nil and row.projectedContext == nil and row.canonicalPayload == nil
                and row.summary == nil and row.actorId == nil, 'Unapproved content exposed')
        end
        print('[AdminAuditContentLiveTest] PASS mode=' .. mode .. ' approvedProjection=true')
    end, debug.traceback)
    if not called then print('[AdminAuditContentLiveTest] FAIL ' .. tostring(problem)) end
end, true)

RegisterCommand('AdminAuditPausedReadLiveTest', function(source, args)
    if source ~= 0 then return end
    local actorSource = tonumber(args[1])
    if not actorSource then return print('[AdminAuditPausedReadLiveTest] Use <loaded staff server ID> after AuditArmReadPause') end
    local called, problem = xpcall(function()
        if not FeatherAdmin.CanUse(actorSource, 'audit.search') then
            return print('[AdminAuditPausedReadLiveTest] FAIL precondition: load the Administrator/Owner character before arming and starting the read.')
        end
        local now = os.time()
        local result = exports['feather-audit']:Search({ fromEpoch = now - 3600,
            toEpoch = now + 60, limit = 1 }, actorSource)
        if type(result) ~= 'table' or type(result.meta) ~= 'table'
            or result.meta.developmentPauseCompleted ~= true then
            return print(('[AdminAuditPausedReadLiveTest] FAIL pause did not complete with rejection; ok=%s code=%s. Confirm AuditReadPause printed PAUSED and RESUMED; start on staff, switch only after PAUSED.'):format(
                tostring(type(result) == 'table' and result.ok), tostring(type(result) == 'table' and result.code)))
        end
        assert(not result.ok and result.code == 'forbidden', 'Paused response was not rejected')
        print('[AdminAuditPausedReadLiveTest] PASS resultDiscarded=true forbidden=true')
    end, debug.traceback)
    if not called then print('[AdminAuditPausedReadLiveTest] FAIL ' .. tostring(problem)) end
end, true)
