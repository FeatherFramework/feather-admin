local providerInstalled = false

local function Decision(allowed, code, reason)
    return {
        ok = true,
        value = {
            allowed = allowed == true,
            code = code,
            reason = reason
        }
    }
end

local function Evaluate(action, context)
    if type(action) ~= 'string' or type(context) ~= 'table' then
        return Decision(false, 'invalid_input', 'Policy action and context are required.')
    end
    if not FeatherAdmin.IsActionEnabled(action) then
        return Decision(false, 'action_disabled', 'That action is disabled.')
    end

    local required = tonumber(Config.permissions[action])
    if required == nil then
        return Decision(false, 'unknown_action', 'That action has no configured policy.')
    end

    local identity = FeatherAdmin.Identity.Resolve(tonumber(context.source))
    local staff = FeatherAdmin.Identity.GetStaff(identity)
    local level = staff and tonumber(staff.roleLevel) or 0
    if level < required then
        return Decision(false, 'forbidden', 'The active character does not have permission for that action.')
    end
    return Decision(true, 'allowed', 'The action is permitted.')
end

local function InstallProvider()
    if providerInstalled then return end
    local result = exports['feather-core']:RegisterPolicyProvider('feather-admin', {
        Evaluate = Evaluate
    }, {
        contract = 1,
        default = true,
        capabilities = { characterRoles = 1, configuredActions = 1 }
    })
    if type(result) ~= 'table' or result.ok ~= true then
        error(('[feather-admin] policy provider registration failed: %s'):format(
            tostring(type(result) == 'table' and result.message or 'invalid result')))
    end
    providerInstalled = true
    print('[feather-admin] Contract 1 policy provider installed')
end

AdminDatabase.OnReady(InstallProvider)

RegisterCommand('AdminPolicySmokeTest', function(source, args)
    if source ~= 0 then return end
    local ownerSource = tonumber(args and args[1])
    local playerSource = tonumber(args and args[2])
    local provider = exports['feather-core']:GetProvider('policy', nil, 1)
    local ownerMenu = ownerSource and exports['feather-core']:Authorize('menu.open', { source = ownerSource }) or nil
    local ownerInventory = ownerSource
        and exports['feather-core']:Authorize('inventory.manage', { source = ownerSource }) or nil
    local unknown = ownerSource and exports['feather-core']:Authorize('smoke.unknown', { source = ownerSource }) or nil
    local playerMenu = playerSource and exports['feather-core']:Authorize('menu.open', { source = playerSource }) or nil

    local tests = {
        { name = 'provider available', passed = type(provider) == 'table' and provider.ok == true },
        { name = 'owner menu allowed', passed = ownerMenu and ownerMenu.ok == true and ownerMenu.value.allowed == true },
        { name = 'inventory manage allowed', passed = ownerInventory and ownerInventory.ok == true
            and ownerInventory.value.allowed == true },
        { name = 'unknown action denied', passed = unknown and unknown.ok == true and unknown.value.allowed == false
            and unknown.value.code == 'unknown_action' },
        { name = 'player menu denied', passed = playerMenu and playerMenu.ok == true and playerMenu.value.allowed == false }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test.passed then passed = passed + 1 end
        print(('[AdminPolicySmokeTest] %-27s %s'):format(test.name, test.passed and 'PASS' or 'FAIL'))
    end
    print(('[AdminPolicySmokeTest] done %d/%d passed owner=%s player=%s'):format(
        passed, #tests, tostring(ownerSource), tostring(playerSource)))
end, true)
