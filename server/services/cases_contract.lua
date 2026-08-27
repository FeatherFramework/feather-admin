local function report(label, passed, detail)
    print(('[AdminCasesContractSmokeTest] %-28s %s%s'):format(
        label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
    return passed and 1 or 0
end

RegisterCommand('AdminCasesContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local passed, total = 0, 7
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    passed = passed + report('staff account identity', identity and type(identity.accountId) == 'string')
    passed = passed + report('staff character snapshot', identity and type(identity.characterId) == 'string')
    local columns = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND ((TABLE_NAME = 'feather_admin_cases' AND COLUMN_NAME IN
            ('target_account_id', 'created_admin_account_id', 'assigned_admin_account_id', 'closed_admin_account_id'))
            OR (TABLE_NAME = 'feather_admin_case_links' AND COLUMN_NAME = 'admin_account_id'))
          AND DATA_TYPE = 'char' AND CHARACTER_MAXIMUM_LENGTH = 36]])) or 0
    passed = passed + report('case account schema', columns == 5, ('%d/5'):format(columns))
    local service = LoadResourceFile(GetCurrentResourceName(), 'server/services/cases.lua') or ''
    local retired = not service:find('GetCharacter', 1, true)
        and not service:find("WHERE license = ?", 1, true)
        and not service:find("WHERE target_license = ?", 1, true)
        and not service:find('CheckTargetHierarchy', 1, true)
    passed = passed + report('retired identity removed', retired)
    local accountPaths = service:find('target_account_id', 1, true)
        and service:find('created_admin_account_id', 1, true)
        and service:find('assigned_admin_account_id', 1, true)
        and service:find('closed_admin_account_id', 1, true)
        and service:find('admin_account_id', 1, true)
    passed = passed + report('account handlers installed', accountPaths ~= nil)
    local noteLinks = service:find("kind = 'note'", 1, true)
        and service:find("note = 'feather_admin_player_notes'", 1, true)
    passed = passed + report('player note links installed', noteLinks ~= nil)
    passed = passed + report('numeric account rejected',
        FeatherAdmin.CanActOnAccount(target or 0, 1, 'cases.create') == false)
    print(('[AdminCasesContractSmokeTest] done %d/%d passed source=%s'):format(
        passed, total, tostring(target or 'none')))
end, true)

RegisterCommand('AdminCasesPersistenceSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    local license = target and FeatherAdmin.Core.User.GetLicense(target) or nil
    if not identity or not identity.characterId or not license then
        print('[AdminCasesPersistenceSmokeTest] setup                        FAIL  -- connected Character required')
        return
    end

    local marker = ('case-contract-smoke-%s-%s'):format(target, GetGameTimer())
    local verified = {}
    local executed, committed = pcall(MySQL.startTransaction, function(query)
        query([[INSERT INTO feather_admin_cases
            (target_account_id, target_license, target_name, target_character_id, target_character_name,
             title, summary, created_admin_account_id, created_admin_license, created_admin_name,
             created_admin_character_id, created_admin_character_name)
            VALUES (?, ?, ?, ?, ?, ?, 'contract smoke test', ?, ?, ?, ?, ?)]],
            { identity.accountId, license, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName, marker, identity.accountId, license,
              identity.accountName or identity.serverName, identity.characterId, identity.characterName })
        local row = (query([[SELECT id, target_account_id, created_admin_account_id
            FROM feather_admin_cases WHERE title = ? FOR UPDATE]], { marker }) or {})[1]
        verified.created = row and row.target_account_id == identity.accountId
            and row.created_admin_account_id == identity.accountId
        if not row then return false end

        query([[UPDATE feather_admin_cases SET status = 'claimed', assigned_admin_account_id = ?,
            assigned_admin_license = ?, assigned_admin_name = ?, assigned_admin_character_id = ?,
            assigned_admin_character_name = ?, claimed_at = NOW() WHERE id = ? AND status = 'open']],
            { identity.accountId, license, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName, row.id })
        local claimed = (query([[SELECT assigned_admin_account_id FROM feather_admin_cases
            WHERE id = ?]], { row.id }) or {})[1]
        verified.claimed = claimed and claimed.assigned_admin_account_id == identity.accountId

        query([[INSERT INTO feather_admin_case_links
            (case_id, link_type, link_id, label, admin_account_id, admin_license, admin_name,
             admin_character_id, admin_character_name)
            VALUES (?, 'audit', 0, 'contract smoke', ?, ?, ?, ?, ?)]],
            { row.id, identity.accountId, license, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName })
        local linked = (query([[SELECT admin_account_id FROM feather_admin_case_links
            WHERE case_id = ?]], { row.id }) or {})[1]
        verified.linked = linked and linked.admin_account_id == identity.accountId

        query([[UPDATE feather_admin_cases SET status = 'closed', resolution = 'smoke complete',
            closed_admin_account_id = ?, closed_admin_license = ?, closed_admin_name = ?,
            closed_admin_character_id = ?, closed_admin_character_name = ?, closed_at = NOW()
            WHERE id = ? AND status = 'claimed']],
            { identity.accountId, license, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName, row.id })
        local closed = (query([[SELECT closed_admin_account_id, status FROM feather_admin_cases
            WHERE id = ?]], { row.id }) or {})[1]
        verified.closed = closed and closed.closed_admin_account_id == identity.accountId
            and closed.status == 'closed'
        return false
    end)

    local remainingCases = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM feather_admin_cases WHERE title = ?', { marker })) or -1
    local remainingLinks = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM feather_admin_case_links l
        JOIN feather_admin_cases c ON c.id = l.case_id WHERE c.title = ?]], { marker })) or -1
    local function output(label, passed, detail)
        print(('[AdminCasesPersistenceSmokeTest] %-28s %s%s'):format(
            label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
        return passed and 1 or 0
    end
    local passed = 0
    passed = passed + output('transaction executed', executed == true)
    passed = passed + output('creation account snapshots', verified.created == true)
    passed = passed + output('claim account ownership', verified.claimed == true)
    passed = passed + output('link actor account', verified.linked == true)
    passed = passed + output('close account ownership', verified.closed == true)
    passed = passed + output('rollback left no records', committed == false
        and remainingCases == 0 and remainingLinks == 0,
        ('cases=%s links=%s'):format(remainingCases, remainingLinks))
    print(('[AdminCasesPersistenceSmokeTest] done %d/6 passed source=%s'):format(passed, tostring(target)))
end, true)
