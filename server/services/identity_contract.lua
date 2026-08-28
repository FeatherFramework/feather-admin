local function IsUuid(value)
    return type(value) == 'string' and value:match(
        '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'
    ) ~= nil
end

RegisterCommand('AdminGrantStaff', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    local level = tonumber(args and args[2])
    level = level and math.floor(level) or nil
    local roleName = args and #args >= 3 and table.concat(args, ' ', 3) or 'Administrator'
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    if not AdminDatabase.ready then
        print('[AdminGrantStaff] database is not ready')
        return
    end
    if not identity or not IsUuid(identity.accountId) or not level or level < 0 or level > 100 then
        print('[AdminGrantStaff] usage: AdminGrantStaff <serverId> <0-100> [role name]')
        return
    end
    MySQL.query.await([[
        INSERT INTO `feather_admin_staff_accounts`
            (`account_id`, `role_level`, `role_name`, `active`)
        VALUES (?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE `role_level` = VALUES(`role_level`),
            `role_name` = VALUES(`role_name`), `active` = 1
    ]], { identity.accountId, level, tostring(roleName):sub(1, 100) })
    FeatherAdmin.Identity.Invalidate(identity.accountId)
    print(('[AdminGrantStaff] account=%s source=%s level=%s role=%s'):format(
        identity.accountId, target, level, roleName))
    TriggerClientEvent('feather-admin:access:permissions', target,
        FeatherAdmin.IsAuthorized(target), FeatherAdmin.GetPermissions(target))
end, true)

RegisterCommand('AdminIdentitySmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    local staff = identity and FeatherAdmin.Identity.GetStaff(identity) or nil
    local characterColumnCount = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE()
          AND `TABLE_NAME` LIKE 'feather_admin_%'
          AND `COLUMN_NAME` LIKE '%character_id'
          AND `DATA_TYPE` = 'char' AND `CHARACTER_MAXIMUM_LENGTH` = 36
    ]])) or 0
    local allCharacterColumns = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE()
          AND `TABLE_NAME` LIKE 'feather_admin_%'
          AND `COLUMN_NAME` LIKE '%character_id'
    ]])) or 0
    local staffTable = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM `information_schema`.`TABLES`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'feather_admin_staff_accounts'
    ]])) or 0
    local auditAccountColumns = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'feather_admin_actions'
          AND `COLUMN_NAME` IN ('admin_account_id', 'target_account_id')
          AND `DATA_TYPE` = 'char' AND `CHARACTER_MAXIMUM_LENGTH` = 36
    ]])) or 0
    local tests = {
        { name = 'account identity', passed = identity ~= nil and IsUuid(identity.accountId) },
        { name = 'character identity', passed = identity ~= nil and IsUuid(identity.characterId) },
        { name = 'profile snapshot', passed = identity ~= nil and type(identity.characterName) == 'string' },
        { name = 'staff authority', passed = staff ~= nil and type(staff.roleLevel) == 'number' },
        { name = 'staff account schema', passed = staffTable == 1 },
        { name = 'audit account schema', passed = auditAccountColumns == 2 },
        { name = 'uuid schema columns', passed = allCharacterColumns > 0
            and characterColumnCount == allCharacterColumns,
            detail = ('%s/%s'):format(characterColumnCount, allCharacterColumns) }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test.passed then passed = passed + 1 end
        print(('[AdminIdentitySmokeTest] %-24s %s%s'):format(test.name,
            test.passed and 'PASS' or 'FAIL', test.detail and ('  -- ' .. test.detail) or ''))
    end
    print(('[AdminIdentitySmokeTest] done %d/%d passed source=%s'):format(passed, #tests, tostring(target)))
end, true)

RegisterCommand('AdminAuthorityInspect', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    local staff = identity and FeatherAdmin.Identity.GetStaff(identity) or nil
    if not identity then
        print(('[AdminAuthorityInspect] source=%s identity=unavailable'):format(tostring(target)))
        return
    end
    local identifiers = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM core_account_identifiers WHERE account_id = ?
    ]], { identity.accountId })) or 0
    print(('[AdminAuthorityInspect] source=%s account=%s character=%s level=%s role=%s authority=%s identifiers=%s'):format(
        tostring(target), tostring(identity.accountId), tostring(identity.characterId),
        tostring(staff and staff.roleLevel or 0), tostring(staff and staff.roleName or 'Player'),
        tostring(staff and staff.authoritySource or 'none'), tostring(identifiers)))
end, true)
