FeatherAdmin.AuthorityCatalog = {
    ready = false,
    result = nil
}

local CAPABILITY_REQUEST_ID = 'admin-authority-capabilities-001'
local ROLE_REQUEST_ID = 'admin-authority-roles-001'
-- This value is part of the durable idempotency fingerprint for the catalog request IDs.
local REASON_CODE = 'feather_admin.authority_migration'

function FeatherAdmin.AuthorityCatalog.Definitions()
    local catalog = {}
    for action, capability in pairs(Config.authorityActions or {}) do
        local required = Config.permissions[action]
        local precedence = required == 'moderator' and 1 or required == 'administrator' and 2 or 3
        catalog[#catalog + 1] = {
            key = capability,
            description = 'Admin permission: ' .. action .. '.',
            riskClass = precedence == 1 and 'moderate' or precedence == 2 and 'high' or 'critical'
        }
    end
    table.sort(catalog, function(left, right) return left.key < right.key end)
    return catalog
end

local function Provision()
    local ready = exports['feather-authority']:AwaitReady(10000)
    assert(type(ready) == 'table' and ready.ok == true, 'Authority did not become ready')

    local definitions = FeatherAdmin.AuthorityCatalog.Definitions()
    assert(#definitions == 82, 'Expected the reviewed 82-action Admin catalog')
    local capabilities = exports['feather-authority']:RegisterCapabilities({
        requestId = CAPABILITY_REQUEST_ID,
        capabilities = definitions
    })
    assert(type(capabilities) == 'table' and capabilities.ok == true,
        tostring(type(capabilities) == 'table' and capabilities.code or 'invalid_result')
            .. ': ' .. tostring(type(capabilities) == 'table' and capabilities.message or 'invalid result'))

    local roleResults, totalGrants, allReplayed = {}, 0, capabilities.value.replayed == true
    for _, tier in ipairs(Config.authority.roles or {}) do
        local created = exports['feather-authority']:CreateRole({
            requestId = ROLE_REQUEST_ID .. ':role:' .. tier.roleKey,
            roleKey = tier.roleKey,
            label = tier.label,
            roleClass = 'staff',
            reasonCode = REASON_CODE
        })
        assert(type(created) == 'table' and created.ok == true,
            tostring(type(created) == 'table' and created.code or 'invalid_result')
                .. ': ' .. tostring(type(created) == 'table' and created.message or 'invalid result'))
        allReplayed = allReplayed and created.value.replayed == true

        local actions = {}
        for action, required in pairs(Config.permissions or {}) do
            local requiredPrecedence
            for _, candidate in ipairs(Config.authority.roles or {}) do
                if candidate.key == required then requiredPrecedence = candidate.precedence break end
            end
            if requiredPrecedence and requiredPrecedence <= tier.precedence then
                actions[#actions + 1] = action
            end
        end
        table.sort(actions)
        for index, action in ipairs(actions) do
            local grant = exports['feather-authority']:GrantRoleCapability({
                requestId = ROLE_REQUEST_ID .. ':grant:' .. tier.roleKey .. ':' .. action,
                roleId = created.value.roleId,
                capabilityKey = Config.authorityActions[action],
                expectedRevision = index,
                scopeType = 'server',
                reasonCode = REASON_CODE
            })
            assert(type(grant) == 'table' and grant.ok == true,
                tostring(type(grant) == 'table' and grant.code or 'invalid_result')
                    .. ': ' .. tostring(type(grant) == 'table' and grant.message or 'invalid result'))
            allReplayed = allReplayed and grant.value.replayed == true
            totalGrants = totalGrants + 1
            if index % 20 == 0 then Wait(0) end
        end

        local role = exports['feather-authority']:GetRole({ roleId = created.value.roleId })
        local grants = exports['feather-authority']:ListRoleGrants({ roleId = created.value.roleId })
        assert(type(role) == 'table' and role.ok == true and type(grants) == 'table'
            and grants.ok == true and #grants.value == #actions
            and role.value.revision == #actions + 1,
            'Authority role or grant catalog is inconsistent for ' .. tier.roleKey)
        roleResults[#roleResults + 1] = {
            key = tier.roleKey,
            roleId = created.value.roleId,
            grants = #actions,
            revision = role.value.revision
        }
    end

    assert(#roleResults == 3 and roleResults[1].grants < roleResults[2].grants
        and roleResults[2].grants < roleResults[3].grants
        and roleResults[3].grants == 82,
        'Authority tier grants are not the reviewed cumulative catalog')
    return {
        capabilities = #definitions,
        roles = #roleResults,
        totalGrants = totalGrants,
        moderator = roleResults[1].grants,
        administrator = roleResults[2].grants,
        owner = roleResults[3].grants,
        replayed = allReplayed
    }
end

function FeatherAdmin.AuthorityCatalog.State()
    return {
        ready = FeatherAdmin.AuthorityCatalog.ready,
        result = FeatherAdmin.AuthorityCatalog.result
    }
end

AdminDatabase.OnReady(function()
    local called, result = xpcall(Provision, debug.traceback)
    if not called then
        FeatherAdmin.AuthorityCatalog.ready = false
        FeatherAdmin.AuthorityCatalog.result = { error = tostring(result) }
        error('[feather-admin] Authority catalog provisioning failed: ' .. tostring(result))
    end
    FeatherAdmin.AuthorityCatalog.ready = true
    FeatherAdmin.AuthorityCatalog.result = result
    print(('[feather-admin] event=authority.catalog.ready capabilities=%d roles=%d grants=%d replayed=%s'):format(
        result.capabilities, result.roles, result.totalGrants, tostring(result.replayed)))
end)
