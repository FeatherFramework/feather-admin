local function report(label, passed, detail)
    print(('[AdminInventoryInspectionContractSmokeTest] %-28s %s%s'):format(
        label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
    return passed and 1 or 0
end

RegisterCommand('AdminInventoryInspectionContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local passed, total = 0, 8
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    passed = passed + report('character identity', identity and type(identity.characterId) == 'string')

    local inventory = exports['feather-inventory'].initiate()
    local capabilities = inventory.GetCapabilities and inventory.GetCapabilities() or nil
    local capability = type(capabilities) == 'table' and capabilities.ok == true
        and type(capabilities.value) == 'table' and type(capabilities.value.features) == 'table'
        and capabilities.value.features.characterInventoryLookup == true
    passed = passed + report('lookup capability', capability)
    local resolver = function(characterId)
        return exports['feather-inventory']:GetCharacterInventory(characterId)
    end
    local exportAvailable = pcall(resolver, '__contract_probe__')
    passed = passed + report('lookup export', exportAvailable)

    local resolved = identity and exportAvailable and resolver(identity.characterId) or nil
    passed = passed + report('character inventory resolved',
        type(resolved) == 'table' and resolved.ok == true and tonumber(resolved.value.id) ~= nil)
    local listed = resolved and resolved.ok == true
        and inventory.Inventory.GetInventoryItems(resolved.value.id) or nil
    passed = passed + report('instance list envelope',
        type(listed) == 'table' and listed.ok == true and type(listed.value) == 'table',
        type(listed) == 'table' and listed.ok == true and ('items=%d'):format(#listed.value) or nil)
    local numeric = exportAvailable and resolver(tonumber(target) or 1) or nil
    passed = passed + report('numeric character rejected', type(numeric) == 'table' and numeric.ok == false)
    local removalCapability = type(capabilities) == 'table' and capabilities.ok == true
        and type(capabilities.value.features) == 'table'
        and capabilities.value.features.adminExactRemoval == true
    passed = passed + report('exact removal capability', removalCapability)
    local removalProbe = pcall(function()
        return exports['feather-inventory']:RemoveCharacterInventoryInstance(1, 1, 'contract_probe')
    end)
    passed = passed + report('exact removal export', removalProbe)
    print(('[AdminInventoryInspectionContractSmokeTest] done %d/%d passed source=%s'):format(
        passed, total, tostring(target or 'none')))
end, true)
