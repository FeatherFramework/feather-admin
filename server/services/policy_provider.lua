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

local function EvaluateService(action,context)
    if type(context)~='table' or context.source~=0 or context.system~=true
        or context.accountId~=nil or context.characterId~=nil or context.sessionId~=nil
        or type(context.caller)~='string' or type(context.subject)~='table'
        or type(context.subject.resource)~='string' then
        return Decision(false,'invalid_service_context','Authenticated service context is required.')
    end
    if not FeatherAdmin.IsActionEnabled(action) then return Decision(false,'action_disabled','That action is disabled.') end
    local callers=type(Config.servicePolicy)=='table' and Config.servicePolicy[context.caller]
    local actions=type(callers)=='table' and callers[context.subject.resource]
    if type(actions)~='table' or actions[action]~=true then
        return Decision(false,'service_forbidden','No explicit service action grant exists.')
    end
    return Decision(true,'allowed','The configured service action is permitted.')
end

local function Evaluate(action, context)
    if type(action) ~= 'string' or type(context) ~= 'table' then
        return Decision(false, 'invalid_input', 'Policy action and context are required.')
    end
    if not FeatherAdmin.IsActionEnabled(action) then
        return Decision(false, 'action_disabled', 'That action is disabled.')
    end
    if context.source==0 then return EvaluateService(action,context) end

    if tonumber(Config.permissions[action]) == nil then
        return Decision(false, 'unknown_action', 'That action has no configured policy.')
    end
    if not FeatherAdmin.CanUse(tonumber(context.source), action) then
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
        capabilities = { characterRoles = 1, configuredActions = 1, servicePrincipals = 1 }
    })
    if type(result) ~= 'table' or result.ok ~= true then
        error(('[feather-admin] policy provider registration failed: %s'):format(
            tostring(type(result) == 'table' and result.message or 'invalid result')))
    end
    providerInstalled = true
    print('[feather-admin] Contract 1 policy provider installed')
end

AdminDatabase.OnReady(InstallProvider)

RegisterCommand('AdminReleaseContractSmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        local registered={}
        for _,command in ipairs(GetRegisteredCommands() or {}) do registered[command.name]=true end
        local actions={
            'organizations.organization.create',
            'organizations.organization.update',
            'organizations.organization.suspend',
            'organizations.organization.dissolve',
            'organizations.relationship.manage',
            'organizations.interest.manage'
        }
        local policy=type(Config.servicePolicy)=='table' and Config.servicePolicy['feather-organizations'] or nil
        local shops=type(policy)=='table' and policy['feather-shops'] or nil
        local organizations=type(policy)=='table' and policy['feather-organizations'] or nil
        local admin=type(policy)=='table' and policy['feather-admin'] or nil
        local function HasEvery(grants)
            if type(grants)~='table' then return false end
            for _,action in ipairs(actions) do if grants[action]~=true then return false end end
            return true
        end
        local provider=exports['feather-core']:GetProvider('policy',nil,1)
        local authorityProvider=exports['feather-core']:GetProvider('policy','feather-authority',1)
        local providerValue=type(provider)=='table' and provider.ok==true and type(provider.value)=='table'
            and type(provider.value.provider)=='table' and provider.value.provider or nil
        local tests={
            {'provider installed',providerInstalled and providerValue~=nil
                and providerValue.owner=='feather-admin'},
            {'service principals enabled',providerValue~=nil and type(providerValue.capabilities)=='table'
                and providerValue.capabilities.servicePrincipals==1},
            {'Authority enforcement enabled',type(Config.authorityMigration)=='table'
                and Config.authorityMigration.enforcement==true},
            {'Authority hierarchy enabled',type(Config.authorityMigration)=='table'
                and Config.authorityMigration.hierarchy==true},
            {'Authority provider available',authorityProvider.ok==true
                and authorityProvider.value.provider.owner=='feather-authority'},
            {'shop test controls absent',not registered.ShopBusinessLifecycleControl
                and not registered.ShopOrganizationLifecycleLiveTest},
            {'shops create and update',type(shops)=='table'
                and shops['organizations.organization.create']==true
                and shops['organizations.organization.update']==true},
            {'shops elevated grants absent',type(shops)=='table'
                and shops['organizations.organization.suspend']~=true
                and shops['organizations.organization.dissolve']~=true
                and shops['organizations.relationship.manage']~=true
                and shops['organizations.interest.manage']~=true},
            {'organizations grants complete',HasEvery(organizations)},
            {'admin grants complete',HasEvery(admin)},
            {'foreign grants absent',type(policy)=='table' and policy.foreign==nil}
        }
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[AdminReleaseContractSmokeTest] %-28s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AdminReleaseContractSmokeTest] done %d/%d passed (read-only)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[AdminReleaseContractSmokeTest] FAIL '..tostring(reason)) end
end,true)

RegisterCommand('AdminServicePolicySmokeTest',function(source)
    if source~=0 then return end
    local called,reason=xpcall(function()
        local tests={}
        local function Check(label,good) tests[#tests+1]={label,good==true} end
        local action='organizations.interest.manage'
        local base={caller='feather-organizations',source=0,system=true,subject={resource='feather-organizations'}}
        Check('explicit service grant',EvaluateService(action,base).value.allowed==true)
        for _,case in ipairs({
            {'untrusted caller',{caller='foreign',source=0,system=true,subject={resource='feather-organizations'}}},
            {'untrusted principal',{caller='feather-organizations',source=0,system=true,subject={resource='foreign'}}},
            {'player not service',{caller='feather-organizations',source=1,system=true,subject={resource='feather-organizations'}}},
            {'system flag required',{caller='feather-organizations',source=0,subject={resource='feather-organizations'}}},
            {'subject required',{caller='feather-organizations',source=0,system=true}},
            {'actor claims rejected',{caller='feather-organizations',source=0,system=true,characterId='forged',subject={resource='feather-organizations'}}},
            {'delegation required',{caller='feather-admin',source=0,system=true,subject={resource='feather-organizations'}}}
        }) do Check(case[1],EvaluateService(action,case[2]).value.allowed==false) end
        Check('unknown action denied',EvaluateService('organizations.unknown',base).value.allowed==false)
        local provider=exports['feather-core']:GetProvider('policy',nil,1)
        Check('service provider installed',provider.ok and provider.value.provider.owner=='feather-admin'
            and provider.value.provider.capabilities.servicePrincipals==1)
        local actual=exports['feather-core']:Authorize(action,{subject={resource='feather-organizations'}})
        Check('Core caller not spoofable',actual.ok and actual.value.allowed==false and actual.value.code=='service_forbidden')
        local passed=0
        for _,test in ipairs(tests) do
            if test[2] then passed=passed+1 end
            print(('[AdminServicePolicySmokeTest] %-29s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AdminServicePolicySmokeTest] done %d/%d passed (read-only)'):format(passed,#tests))
    end,debug.traceback)
    if not called then print('[AdminServicePolicySmokeTest] FAIL '..tostring(reason)) end
end,true)

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
