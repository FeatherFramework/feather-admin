local function report(label, passed, detail)
    print(('[AdminModerationContractSmokeTest] %-28s %s%s'):format(
        label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
    return passed and 1 or 0
end

RegisterCommand('AdminModerationContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end

    local passed, total = 0, 9
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    passed = passed + report('target account identity', identity and type(identity.accountId) == 'string',
        target and ('source=' .. target) or 'no connected player')
    passed = passed + report('target character snapshot', identity and type(identity.characterId) == 'string')

    local requiredColumns = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND ((TABLE_NAME = 'feather_admin_bans' AND COLUMN_NAME IN
                ('account_id', 'admin_account_id', 'revoked_by_account_id'))
            OR (TABLE_NAME = 'feather_admin_warnings' AND COLUMN_NAME IN
                ('account_id', 'admin_account_id'))
            OR (TABLE_NAME = 'feather_admin_kicks' AND COLUMN_NAME IN
                ('account_id', 'admin_account_id')))
    ]])) or 0
    passed = passed + report('moderation account schema', requiredColumns == 7,
        ('%d/7'):format(requiredColumns))

    local identifier = identity and MySQL.single.await([[
        SELECT identifier_type, identifier_value FROM core_account_identifiers
        WHERE account_id = ? AND identifier_type IN ('license', 'license2')
        ORDER BY identifier_type LIMIT 1
    ]], { identity.accountId }) or nil
    passed = passed + report('connection identifier', identifier ~= nil,
        identifier and identifier.identifier_type or nil)

    local allowed, reason
    if identity then
        allowed, reason = FeatherAdmin.CanActOnAccount(target, identity.accountId, 'moderation.warn')
    end
    passed = passed + report('self moderation denied', allowed == false and reason == 'self', reason)

    local numericAllowed = FeatherAdmin.CanActOnAccount(target or 0, 1, 'moderation.warn')
    passed = passed + report('numeric account rejected', numericAllowed == false)

    local service = LoadResourceFile(GetCurrentResourceName(), 'server/services/moderation.lua') or ''
    local retiredJoinsAbsent = not service:find('FROM users', 1, true)
        and not service:find('FROM characters', 1, true)
        and not service:find('JOIN roles', 1, true)
        and not service:find('GetCharacter', 1, true)
    passed = passed + report('retired joins removed', retiredJoinsAbsent)
    local accountPathsPresent = service:find('core_accounts', 1, true)
        and service:find('character_profiles', 1, true)
        and service:find('CheckTargetAccountHierarchy', 1, true)
    passed = passed + report('account handlers installed', accountPathsPresent ~= nil)
    local gatesResult = exports['feather-core']:GetConnectionGates()
    local accountGate
    if type(gatesResult) == 'table' and gatesResult.ok == true then
        for _, gate in ipairs(gatesResult.value or {}) do
            if gate.name == 'feather-admin:moderation' then accountGate = gate break end
        end
    end
    passed = passed + report('account ban gate installed', accountGate
        and accountGate.owner == 'feather-admin' and accountGate.type == 'export'
        and accountGate.failClosed == true)

    print(('[AdminModerationContractSmokeTest] done %d/%d passed source=%s'):format(
        passed, total, tostring(target or 'none')))
end, true)

RegisterCommand('AdminModerationPersistenceSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end

    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    local license = target and FeatherAdmin.Core.User.GetLicense(target) or nil
    local name = identity and (identity.accountName or identity.serverName) or nil
    if not identity or not identity.characterId or not license or not name then
        print('[AdminModerationPersistenceSmokeTest] setup                        FAIL  -- connected Character required')
        return
    end

    local marker = ('admin-contract-smoke-%s-%s'):format(target, GetGameTimer())
    local verifiedCounts = {}
    local executed, committed = pcall(MySQL.startTransaction, function(query)
        local common = { identity.accountId, license, name, identity.characterId, identity.characterName,
            marker, license, identity.accountId, name, identity.characterId, identity.characterName }
        query([[INSERT INTO feather_admin_warnings
            (account_id, license, player_name, character_id, character_name, reason,
             admin_license, admin_account_id, admin_name, admin_character_id, admin_character_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], common)
        query([[INSERT INTO feather_admin_kicks
            (account_id, license, player_name, character_id, character_name, reason,
             admin_license, admin_account_id, admin_name, admin_character_id, admin_character_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], common)
        query([[INSERT INTO feather_admin_bans
            (account_id, license, player_name, character_id, character_name, reason,
             admin_license, admin_account_id, admin_name, admin_character_id, admin_character_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], common)

        local verified = query([[
            SELECT
              (SELECT COUNT(*) FROM feather_admin_warnings WHERE reason = ? AND account_id = ? AND character_id = ?) AS warnings,
              (SELECT COUNT(*) FROM feather_admin_kicks WHERE reason = ? AND account_id = ? AND character_id = ?) AS kicks,
              (SELECT COUNT(*) FROM feather_admin_bans WHERE reason = ? AND account_id = ? AND character_id = ?) AS bans
        ]], { marker, identity.accountId, identity.characterId,
            marker, identity.accountId, identity.characterId,
            marker, identity.accountId, identity.characterId }) or {}
        local row = verified[1] or {}
        verifiedCounts = {
            warnings = tonumber(row.warnings) or 0,
            kicks = tonumber(row.kicks) or 0,
            bans = tonumber(row.bans) or 0
        }
        return false
    end)

    local remaining = tonumber(MySQL.scalar.await([[
        SELECT (SELECT COUNT(*) FROM feather_admin_warnings WHERE reason = ?)
             + (SELECT COUNT(*) FROM feather_admin_kicks WHERE reason = ?)
             + (SELECT COUNT(*) FROM feather_admin_bans WHERE reason = ?)
    ]], { marker, marker, marker })) or -1

    local function persistenceReport(label, succeeded, detail)
        print(('[AdminModerationPersistenceSmokeTest] %-28s %s%s'):format(
            label, succeeded and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
        return succeeded and 1 or 0
    end
    local passed = 0
    passed = passed + persistenceReport('transaction executed', executed == true)
    passed = passed + persistenceReport('warning snapshot', verifiedCounts.warnings == 1)
    passed = passed + persistenceReport('kick snapshot', verifiedCounts.kicks == 1)
    passed = passed + persistenceReport('ban snapshot', verifiedCounts.bans == 1)
    passed = passed + persistenceReport('rollback left no records', committed == false and remaining == 0,
        ('remaining=%s'):format(remaining))
    print(('[AdminModerationPersistenceSmokeTest] done %d/5 passed source=%s'):format(passed, tostring(target)))
end, true)

RegisterCommand('AdminBanInspect', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    local license = target and FeatherAdmin.Core.User.GetLicense(target) or nil
    if not identity or not license then
        local latest = MySQL.single.await([[SELECT id, account_id, active, expires_at,
            (expires_at IS NULL OR expires_at > NOW()) AS unexpired
            FROM feather_admin_bans ORDER BY id DESC LIMIT 1]])
        if latest then
            print(('[AdminBanInspect] source=%s offline=true latestBanId=%s account=%s active=%s unexpired=%s expires=%s'):format(
                tostring(target), tostring(latest.id), tostring(latest.account_id), tostring(latest.active),
                tostring(latest.unexpired), tostring(latest.expires_at or 'permanent')))
        else
            print(('[AdminBanInspect] source=%s offline=true ban=not_found'):format(tostring(target)))
        end
        return
    end
    local ban = MySQL.single.await([[SELECT id, account_id, license, active,
        expires_at, (expires_at IS NULL OR expires_at > NOW()) AS unexpired
        FROM feather_admin_bans WHERE account_id = ? OR license = ?
        ORDER BY id DESC LIMIT 1]], { identity.accountId, license })
    if not ban then
        print(('[AdminBanInspect] source=%s account=%s ban=not_found'):format(target, identity.accountId))
        return
    end
    print(('[AdminBanInspect] source=%s account=%s banId=%s accountMatch=%s licenseMatch=%s active=%s unexpired=%s expires=%s'):format(
        target, identity.accountId, tostring(ban.id), tostring(ban.account_id == identity.accountId),
        tostring(ban.license == license), tostring(ban.active), tostring(ban.unexpired),
        tostring(ban.expires_at or 'permanent')))
end, true)
