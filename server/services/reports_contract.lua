local function report(label, passed, detail)
    print(('[AdminReportsContractSmokeTest] %-28s %s%s'):format(
        label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
    return passed and 1 or 0
end

RegisterCommand('AdminReportsContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local passed, total = 0, 6
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    passed = passed + report('reporter account identity', identity and type(identity.accountId) == 'string')
    passed = passed + report('reporter character snapshot', identity and type(identity.characterId) == 'string')

    local columns = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'feather_admin_reports'
          AND COLUMN_NAME IN ('reporter_account_id', 'assigned_admin_account_id', 'closed_admin_account_id')
          AND DATA_TYPE = 'char' AND CHARACTER_MAXIMUM_LENGTH = 36]])) or 0
    passed = passed + report('report account schema', columns == 3, ('%d/3'):format(columns))

    local service = LoadResourceFile(GetCurrentResourceName(), 'server/services/reports.lua') or ''
    local retired = not service:find('GetCharacter', 1, true)
        and not service:find('tonumber(row.reporter_character_id)', 1, true)
        and not service:find('assigned_admin_license ~=', 1, true)
    passed = passed + report('retired identity removed', retired)
    local accountPaths = service:find('reporter_account_id', 1, true)
        and service:find('assigned_admin_account_id', 1, true)
        and service:find('closed_admin_account_id', 1, true)
    passed = passed + report('account handlers installed', accountPaths ~= nil)
    local numericRejected = FeatherAdmin.CanActOnAccount(target or 0, 1, 'reports.manage') == false
    passed = passed + report('numeric account rejected', numericRejected)
    print(('[AdminReportsContractSmokeTest] done %d/%d passed source=%s'):format(
        passed, total, tostring(target or 'none')))
end, true)

RegisterCommand('AdminReportsPersistenceSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    local license = target and FeatherAdmin.Core.User.GetLicense(target) or nil
    if not identity or not identity.characterId or not license then
        print('[AdminReportsPersistenceSmokeTest] setup                        FAIL  -- connected Character required')
        return
    end

    local marker = ('report-contract-smoke-%s-%s'):format(target, GetGameTimer())
    local verified = {}
    local executed, committed = pcall(MySQL.startTransaction, function(query)
        query([[INSERT INTO feather_admin_reports
            (reporter_account_id, reporter_license, reporter_name, reporter_character_id,
             reporter_character_name, category, message)
            VALUES (?, ?, ?, ?, ?, 'other', ?)]],
            { identity.accountId, license, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName, marker })
        local rows = query([[SELECT id, reporter_account_id, reporter_character_id
            FROM feather_admin_reports WHERE message = ? FOR UPDATE]], { marker }) or {}
        local row = rows[1]
        verified.submitted = row and row.reporter_account_id == identity.accountId
            and row.reporter_character_id == identity.characterId
        if not row then return false end

        query([[UPDATE feather_admin_reports SET status = 'claimed',
            assigned_admin_account_id = ?, assigned_admin_license = ?, assigned_admin_name = ?,
            assigned_admin_character_id = ?, assigned_admin_character_name = ?, claimed_at = NOW()
            WHERE id = ? AND status = 'open']],
            { identity.accountId, license, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName, row.id })
        local claimed = (query([[SELECT assigned_admin_account_id FROM feather_admin_reports
            WHERE id = ?]], { row.id }) or {})[1]
        verified.claimed = claimed and claimed.assigned_admin_account_id == identity.accountId

        query([[UPDATE feather_admin_reports SET status = 'closed', resolution = 'smoke complete',
            closed_admin_account_id = ?, closed_admin_license = ?, closed_admin_name = ?,
            closed_admin_character_id = ?, closed_admin_character_name = ?, closed_at = NOW()
            WHERE id = ? AND status = 'claimed']],
            { identity.accountId, license, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName, row.id })
        local closed = (query([[SELECT closed_admin_account_id, status FROM feather_admin_reports
            WHERE id = ?]], { row.id }) or {})[1]
        verified.closed = closed and closed.closed_admin_account_id == identity.accountId
            and closed.status == 'closed'
        return false
    end)

    local remaining = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM feather_admin_reports WHERE message = ?', { marker })) or -1
    local function output(label, passed, detail)
        print(('[AdminReportsPersistenceSmokeTest] %-28s %s%s'):format(
            label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
        return passed and 1 or 0
    end
    local passed = 0
    passed = passed + output('transaction executed', executed == true)
    passed = passed + output('submission snapshot', verified.submitted == true)
    passed = passed + output('claim account ownership', verified.claimed == true)
    passed = passed + output('close account ownership', verified.closed == true)
    passed = passed + output('rollback left no report', committed == false and remaining == 0,
        ('remaining=%s'):format(remaining))
    print(('[AdminReportsPersistenceSmokeTest] done %d/5 passed source=%s'):format(passed, tostring(target)))
end, true)
