local schemaReady = false

local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function licenseForSource(src)
    return FeatherAdmin.Core.User.GetLicense(src)
end

local function runtimeLicense(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if type(identifier) == 'string' and identifier:sub(1, 8):lower() == 'license:' then
            return identifier:lower()
        end
    end
end

local function licenseForAccount(accountId)
    local row = MySQL.single.await([[
        SELECT identifier_type, identifier_value FROM core_account_identifiers
        WHERE account_id = ? AND identifier_type IN ('license', 'license2')
        ORDER BY identifier_type LIMIT 1
    ]], { accountId })
    return row and ('%s:%s'):format(row.identifier_type, row.identifier_value) or nil
end

local function onlineSource(accountId, characterId)
    for _, rawId in ipairs(GetPlayers()) do
        local src = tonumber(rawId)
        local identity = src and FeatherAdmin.Identity.Resolve(src) or nil
        if identity and identity.accountId == accountId
            and (not characterId or identity.characterId == characterId) then return src end
    end
end

local function snapshot(src)
    local identity = FeatherAdmin.Identity.Resolve(src)
    if not identity then return nil end
    return {
        serverId = tonumber(src), accountId = identity.accountId,
        license = licenseForSource(src) or licenseForAccount(identity.accountId),
        playerName = identity.accountName or identity.serverName,
        characterId = identity.characterId, characterName = identity.characterName
    }
end

local function resolveTarget(target)
    if type(target) ~= 'table' then return nil end
    local src = tonumber(target.serverId)
    if src and GetPlayerName(src) then return snapshot(src) end

    local accountId, characterId = trim(target.accountId), trim(target.characterId)
    if accountId == '' then
        local kind, value = trim(target.license):match('^([^:]+):(.+)$')
        if not kind or not value then return nil end
        accountId = MySQL.scalar.await([[SELECT account_id FROM core_account_identifiers
            WHERE identifier_type = ? AND identifier_value = ? LIMIT 1]], { kind:lower(), value:lower() })
    end
    if type(accountId) ~= 'string' or accountId == '' then return nil end
    local row
    if characterId ~= '' then
        row = MySQL.single.await([[SELECT a.id AS account_id, a.display_name, p.character_id,
            CONCAT(p.first_name, ' ', p.last_name) AS character_name
            FROM core_accounts a INNER JOIN character_profiles p
              ON p.account_id COLLATE utf8mb4_unicode_ci = a.id COLLATE utf8mb4_unicode_ci
            WHERE a.id = ? AND p.character_id = ? AND a.status = 'active' AND p.status = 'active' LIMIT 1]],
            { accountId, characterId })
    else
        row = MySQL.single.await([[SELECT id AS account_id, display_name, NULL AS character_id,
            NULL AS character_name FROM core_accounts WHERE id = ? AND status = 'active' LIMIT 1]], { accountId })
    end
    if not row then return nil end
    return { accountId = row.account_id, license = licenseForAccount(row.account_id),
        playerName = row.display_name, characterId = row.character_id, characterName = row.character_name,
        serverId = onlineSource(row.account_id, row.character_id) }
end

local function validReason(reason)
    reason = trim(reason)
    local maximum = math.min(tonumber(Config.moderation.maxReasonLength) or 200, 200)
    return reason ~= '' and #reason <= maximum and reason or nil
end

local function notify(src, key)
    TriggerClientEvent('feather-admin:moderation:result', src, key)
end

AdminDatabase.OnReady(function() schemaReady = true end)

local function checkConnectionBan(src, playerName)
    local license = runtimeLicense(src)
    if not license then
        print(('[feather-admin] ban gate source=%s result=no_license'):format(tostring(src)))
        return nil
    end
    local identifierValue = license:sub(9)
    local accountId = MySQL.scalar.await([[SELECT account_id FROM core_account_identifiers
        WHERE identifier_type = 'license' AND identifier_value = ? LIMIT 1]], { identifierValue })
    local deadline = GetGameTimer() + 10000
    while not schemaReady and GetGameTimer() < deadline do Wait(100) end
    if not schemaReady then return 'The moderation service is still starting. Please try again shortly.' end
    local ban
    if accountId then
        ban = MySQL.single.await([[SELECT reason, expires_at FROM feather_admin_bans
            WHERE account_id = ? AND active = 1 AND (expires_at IS NULL OR expires_at > NOW())
            ORDER BY id DESC LIMIT 1]], { accountId })
    else
        ban = MySQL.single.await([[SELECT reason, expires_at FROM feather_admin_bans
            WHERE license = ? AND active = 1 AND (expires_at IS NULL OR expires_at > NOW())
            ORDER BY id DESC LIMIT 1]], { license })
    end
    if not ban then
        print(('[feather-admin] ban gate source=%s account=%s result=allowed'):format(
            tostring(src), tostring(accountId or 'unresolved')))
        return nil
    end
    local message = ('%s\nReason: %s'):format(Config.moderation.banMessage or 'You are banned from this server.', ban.reason)
    if ban.expires_at then message = ('%s\nExpires: %s'):format(message, ban.expires_at) end
    print(('[feather-admin] Blocked banned account: player=%s account=%s reason=%s'):format(
        tostring(playerName), tostring(accountId or 'unresolved'), tostring(ban.reason)))
    return message
end

exports('checkConnectionBan', checkConnectionBan)
FeatherAdmin.Core.Connection.RegisterGate('feather-admin:moderation', {
    resource = GetCurrentResourceName(), export = 'checkConnectionBan'
}, { priority = 50, timeoutMs = 12000, failClosed = true, label = 'moderation status',
    failureMessage = 'The moderation service could not verify your account. Please try again shortly.' })

FeatherAdmin.RegisterRPC('feather-admin:moderation:search', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'moderation.search') or not schemaReady then return end
    local query = trim(params.query)
    local minimum = math.max(1, tonumber(Config.moderation.minSearchLength) or 2)
    if #query < minimum or #query > 100 then return end
    local limit = math.max(1, math.min(tonumber(Config.moderation.searchLimit) or 25, 100))
    local clause, values
    if query:sub(1, 8):lower() == 'license:' then
        if not FeatherAdmin.RequirePermission(src, 'moderation.search_identifiers') then return end
        local kind, value = query:match('^([^:]+):(.+)$')
        clause, values = [[EXISTS (SELECT 1 FROM core_account_identifiers i
            WHERE i.account_id COLLATE utf8mb4_unicode_ci = a.id COLLATE utf8mb4_unicode_ci
            AND i.identifier_type = ? AND i.identifier_value = ?)]], { kind:lower(), value:lower() }
    elseif #query == 36 and query:match('^[%x%-]+$') then
        clause, values = '(a.id = ? OR p.character_id = ?)', { query, query }
    else
        local prefix = query .. '%'
        clause, values = '(a.display_name LIKE ? OR p.first_name LIKE ? OR p.last_name LIKE ?)', { prefix, prefix, prefix }
    end
    local rows = MySQL.query.await(([[SELECT a.id AS accountId, a.display_name AS playerName,
        p.character_id AS characterId, CONCAT(p.first_name, ' ', p.last_name) AS characterName,
        s.role_name AS roleName, COALESCE(s.role_level, 0) AS roleLevel
        FROM core_accounts a LEFT JOIN character_profiles p
          ON p.account_id COLLATE utf8mb4_unicode_ci = a.id COLLATE utf8mb4_unicode_ci AND p.status = 'active'
        LEFT JOIN feather_admin_staff_accounts s
          ON s.account_id COLLATE utf8mb4_unicode_ci = a.id COLLATE utf8mb4_unicode_ci AND s.active = 1
        WHERE a.status = 'active' AND %s ORDER BY a.display_name, p.created_at LIMIT %d]]):format(clause, limit), values) or {}
    for _, row in ipairs(rows) do
        row.license = licenseForAccount(row.accountId)
        row.serverId = onlineSource(row.accountId, row.characterId)
        row.isOnline = row.serverId ~= nil
    end
    TriggerClientEvent('feather-admin:moderation:search:result', src, rows)
    AdminAudit.Record(src, 'moderation.search', nil, query)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 256 })

local function insertAction(tableName, target, reason, admin)
    return MySQL.insert.await(([[INSERT INTO %s
        (account_id, license, player_name, character_id, character_name, reason,
         admin_license, admin_account_id, admin_name, admin_character_id, admin_character_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]]):format(tableName),
        { target.accountId, target.license, target.playerName, target.characterId, target.characterName, reason,
          admin.license, admin.accountId, admin.playerName, admin.characterId, admin.characterName })
end

FeatherAdmin.RegisterRPC('feather-admin:moderation:warn', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'moderation.warn') or not schemaReady then return end
    local target, reason, admin = resolveTarget(params.target), validReason(params.reason), snapshot(src)
    if not target or not reason or not admin
        or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'moderation.warn', target.accountId, target.serverId) then return end
    insertAction('feather_admin_warnings', target, reason, admin)
    AdminAudit.Record(src, 'moderation.warn', target.serverId, ('account=%s reason=%s'):format(target.accountId, reason))
    if target.serverId and target.serverId ~= src then
        FeatherAdmin.Notify(target.serverId, ('Warning: %s'):format(reason), 5000)
    end
    notify(src, 'player_warned')
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 1024 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:kick', function(params, _, src)
    if not schemaReady then return end
    local targetId, reason = FeatherAdmin.RequireTarget(src, 'moderation.kick', params.playerId), validReason(params.reason)
    local target, admin = targetId and snapshot(targetId) or nil, snapshot(src)
    if not target or not reason or not admin then return end
    insertAction('feather_admin_kicks', target, reason, admin)
    AdminAudit.Record(src, 'moderation.kick', targetId, ('account=%s reason=%s'):format(target.accountId, reason))
    notify(src, 'player_kicked')
    DropPlayer(targetId, reason)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 512 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:ban', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'moderation.ban') or not schemaReady then return end
    local target, reason, admin = resolveTarget(params.target), validReason(params.reason), snapshot(src)
    local duration, maximum = tonumber(params.durationMinutes), tonumber(Config.moderation.maxBanMinutes) or 525600
    if not target or not target.license or not reason or not admin or not duration or duration < 0
        or duration > maximum or duration % 1 ~= 0
        or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'moderation.ban', target.accountId, target.serverId) then return end
    MySQL.update.await('UPDATE feather_admin_bans SET active = 0 WHERE account_id = ? AND active = 1', { target.accountId })
    MySQL.insert.await([[INSERT INTO feather_admin_bans
        (account_id, license, player_name, character_id, character_name, reason, expires_at,
         admin_license, admin_account_id, admin_name, admin_character_id, admin_character_name)
        VALUES (?, ?, ?, ?, ?, ?, IF(? > 0, DATE_ADD(NOW(), INTERVAL ? MINUTE), NULL), ?, ?, ?, ?, ?)]],
        { target.accountId, target.license, target.playerName, target.characterId, target.characterName, reason,
          duration, duration, admin.license, admin.accountId, admin.playerName, admin.characterId, admin.characterName })
    AdminAudit.Record(src, 'moderation.ban', target.serverId, ('account=%s duration=%s reason=%s'):format(target.accountId, duration, reason))
    notify(src, 'player_banned')
    if target.serverId then DropPlayer(target.serverId, reason) end
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 1024 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:history', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'moderation.history') or not schemaReady then return end
    local target = resolveTarget(params.target)
    if not target or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'moderation.history', target.accountId, target.serverId) then return end
    local limit = math.max(1, math.min(tonumber(Config.moderation.historyLimit) or 50, 100))
    local records = MySQL.query.await(([[SELECT id, 'ban' AS kind, reason,
        admin_name AS adminName, admin_character_name AS adminCharacterName,
        DATE_FORMAT(expires_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS expiresAt,
        DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS createdAt,
        revoked_by AS revokedBy, revoked_by_character_name AS revokedByCharacterName,
        DATE_FORMAT(revoked_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS revokedAt,
        CASE WHEN active = 0 AND revoked_at IS NOT NULL THEN 'revoked'
             WHEN active = 0 THEN 'superseded'
             WHEN expires_at IS NOT NULL AND expires_at <= NOW() THEN 'expired'
             ELSE 'active' END AS status
        FROM feather_admin_bans WHERE account_id = ? ORDER BY id DESC LIMIT %d]]):format(limit),
        { target.accountId }) or {}
    local sets = { { 'warning', 'feather_admin_warnings' }, { 'kick', 'feather_admin_kicks' } }
    for _, set in ipairs(sets) do
        local rows = MySQL.query.await(([[SELECT id, '%s' AS kind, reason, admin_name AS adminName,
            admin_character_name AS adminCharacterName, DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS createdAt
            FROM %s WHERE account_id = ? ORDER BY id DESC LIMIT %d]]):format(set[1], set[2], limit), { target.accountId }) or {}
        for _, row in ipairs(rows) do records[#records + 1] = row end
    end
    table.sort(records, function(a, b) return tostring(a.createdAt) > tostring(b.createdAt) end)
    while #records > limit do table.remove(records) end
    TriggerClientEvent('feather-admin:moderation:history:result', src, records)
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 512 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:unban', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'moderation.unban') or not schemaReady then return end
    local banId = tonumber(params.banId)
    if not banId or banId % 1 ~= 0 then return end
    local ban = MySQL.single.await('SELECT account_id FROM feather_admin_bans WHERE id = ? AND active = 1', { banId })
    if not ban or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'moderation.unban', ban.account_id, nil) then return end
    local admin = snapshot(src)
    if not admin then return end
    local changed = MySQL.update.await([[UPDATE feather_admin_bans SET active = 0, revoked_by = ?,
        revoked_by_account_id = ?, revoked_by_character_id = ?, revoked_by_character_name = ?, revoked_at = NOW()
        WHERE id = ? AND active = 1]], { admin.playerName, admin.accountId, admin.characterId, admin.characterName, banId })
    if changed and changed > 0 then
        AdminAudit.Record(src, 'moderation.unban', nil, ('ban_id=%s account=%s'):format(banId, ban.account_id))
        notify(src, 'ban_revoked')
    end
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 128 })
