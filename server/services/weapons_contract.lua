local function report(label, passed, detail)
    print(('[AdminWeaponsContractSmokeTest] %-28s %s%s'):format(
        label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
    return passed and 1 or 0
end

RegisterCommand('AdminWeaponsContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local passed, total = 0, 10
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    passed = passed + report('target account identity', identity and type(identity.accountId) == 'string')
    passed = passed + report('target character identity', identity and type(identity.characterId) == 'string')

    local weapons = exports['feather-weapons'].initiate()
    local capabilities = weapons.GetCapabilities and weapons.GetCapabilities() or nil
    passed = passed + report('weapons ready', type(capabilities) == 'table'
        and tonumber(capabilities.contractVersion) >= 1 and capabilities.ready == true)
    passed = passed + report('issuance capability', type(capabilities) == 'table'
        and type(capabilities.features) == 'table' and capabilities.features.issuance == true)
    local issuanceAvailable, issuanceProbe = pcall(function()
        return exports['feather-weapons']:IssueWeapon({ characterId = 1, definitionId = '' },
            { reason = 'contract_probe', resource = 'feather-admin' })
    end)
    passed = passed + report('issuance export', issuanceAvailable
        and type(issuanceProbe) == 'table' and issuanceProbe.ok == false)

    local weaponDefinitions = weapons.Definitions and weapons.Definitions.List
        and weapons.Definitions.List('weapon') or nil
    passed = passed + report('weapon definitions', type(weaponDefinitions) == 'table'
        and weaponDefinitions.ok == true and #weaponDefinitions.value > 0,
        type(weaponDefinitions) == 'table' and weaponDefinitions.ok == true
            and ('count=%d'):format(#weaponDefinitions.value) or nil)
    local ammoDefinitions = weapons.Definitions and weapons.Definitions.List
        and weapons.Definitions.List('ammunition') or nil
    passed = passed + report('ammunition definitions', type(ammoDefinitions) == 'table'
        and ammoDefinitions.ok == true and #ammoDefinitions.value > 0,
        type(ammoDefinitions) == 'table' and ammoDefinitions.ok == true
            and ('count=%d'):format(#ammoDefinitions.value) or nil)
    local mappings = true
    if type(ammoDefinitions) ~= 'table' or ammoDefinitions.ok ~= true then mappings = false end
    for _, definition in ipairs(mappings and ammoDefinitions.value or {}) do
        if type(definition.id) ~= 'string' or type(definition.itemName) ~= 'string' then mappings = false end
    end
    passed = passed + report('ammo item mappings', mappings)
    local inventoryCapabilities = exports['feather-inventory'].initiate().GetCapabilities()
    local characterGrant = type(inventoryCapabilities) == 'table' and inventoryCapabilities.ok == true
        and type(inventoryCapabilities.value.features) == 'table'
        and inventoryCapabilities.value.features.characterItemGrant == true
    passed = passed + report('character grant capability', characterGrant)
    local grantAvailable = pcall(function()
        return exports['feather-inventory']:GrantCharacterItem(1, '', 0, 'contract_probe')
    end)
    passed = passed + report('character grant export', grantAvailable)
    print(('[AdminWeaponsContractSmokeTest] done %d/%d passed source=%s'):format(
        passed, total, tostring(target or 'none')))
end, true)
