local schemaReady = false

local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function licenseForSource(src)
    return FeatherAdmin.Core.User.GetLicense(src)
end

local function onlineSourceForCharacter(license, characterId)
    characterId = tonumber(characterId)
    for _, rawId in ipairs(GetPlayers()) do
        local playerId = tonumber(rawId)
        local character = playerId and FeatherAdmin.Core.Character.GetCharacter({ src = playerId })
        local char = character and character.char
        if char and tonumber(char.id) == characterId and licenseForSource(playerId) == license then
            return playerId
        end
    end
    return nil
end

local function adminIdentity(src)
    local character = FeatherAdmin.Core.Character.GetCharacter({ src = src })
    local char = character and character.char or {}
    local characterName = char.first_name and (('%s %s'):format(char.first_name, char.last_name or '')) or nil
    return licenseForSource(src), GetPlayerName(src) or ('Source %s'):format(src),
        tonumber(char.id), characterName
end

local function resolveTarget(target)
    if type(target) ~= 'table' then return nil end

    local serverId = tonumber(target.serverId)
    if serverId and GetPlayerName(serverId) then
        local license = licenseForSource(serverId)
        if not license then return nil end
        local character = FeatherAdmin.Core.Character.GetCharacter({ src = serverId })
        local char = character and character.char or {}
        return {
            serverId = serverId,
            license = license,
            playerName = GetPlayerName(serverId),
            characterId = tonumber(char.id),
            characterName = char.first_name and (('%s %s'):format(char.first_name, char.last_name or '')) or nil
        }
    end

    local license = trim(target.license)
    if license == '' then return nil end

    local requestedCharacterId = target.characterId
    local row
    if requestedCharacterId ~= nil then
        requestedCharacterId = tonumber(requestedCharacterId)
        if not requestedCharacterId or requestedCharacterId < 1 or requestedCharacterId % 1 ~= 0 then return nil end

        -- Both values came from the client. The join proves that the chosen
        -- character actually belongs to the supplied account before its
        -- identity is written into moderation history.
        row = MySQL.single.await([[
            SELECT u.license, u.username, c.id AS character_id,
                   CONCAT(c.first_name, ' ', c.last_name) AS character_name
            FROM users u
            INNER JOIN characters c ON c.user_id = u.id
            WHERE u.license = ? AND c.id = ?
            LIMIT 1
        ]], { license, requestedCharacterId })
    else
        -- A license identifies the account, not one of its characters. When
        -- no character was selected, leave character attribution empty
        -- instead of guessing the oldest or newest character.
        row = MySQL.single.await([[
            SELECT u.license, u.username,
                   NULL AS character_id, NULL AS character_name
            FROM users u
            WHERE u.license = ?
            LIMIT 1
        ]], { license })
    end

    if not row then return nil end
    return {
        license = row.license,
        playerName = row.username,
        characterId = row.character_id,
        characterName = row.character_name
    }
end

local function validReason(reason)
    reason = trim(reason)
    local maximum = math.min(tonumber(Config.moderation.maxReasonLength) or 200, 200)
    if reason == '' or #reason > maximum then return nil end
    return reason
end

local function notify(src, key)
    TriggerClientEvent('feather-admin:moderation:result', src, key)
end

AdminDatabase.OnReady(function()
    schemaReady = true
end)

local function checkConnectionBan(src, playerName)
    local license = licenseForSource(src)
    if not license then return nil end

    local schemaDeadline = GetGameTimer() + 10000
    while not schemaReady and GetGameTimer() < schemaDeadline do Wait(100) end
    if not schemaReady then
        return 'The moderation service is still starting. Please try again shortly.'
    end

    local ban = MySQL.single.await([[
        SELECT reason, expires_at
        FROM feather_admin_bans
        WHERE license = ? AND active = 1
          AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY id DESC LIMIT 1
    ]], { license })
    if not ban then return nil end

    local message = tostring(Config.moderation.banMessage or 'You are banned from this server.')
    message = ('%s\nReason: %s'):format(message, ban.reason)
    if ban.expires_at then message = ('%s\nExpires: %s'):format(message, ban.expires_at) end

    print(('[feather-admin] Blocked banned player connection: player=%s license=%s reason=%s expires=%s'):format(
        tostring(playerName or 'unknown'):gsub('[%c]', ' '),
        tostring(license),
        tostring(ban.reason):gsub('[%c]', ' '),
        tostring(ban.expires_at or 'permanent')
    ))

    return message
end

exports('checkConnectionBan', checkConnectionBan)

FeatherAdmin.Core.Connection.RegisterGate('feather-admin:moderation', {
    resource = GetCurrentResourceName(),
    export = 'checkConnectionBan'
}, {
    priority = 50,
    timeoutMs = 12000,
    failClosed = true,
    label = 'moderation status',
    failureMessage = 'The moderation service could not verify your account. Please try again shortly.'
})

FeatherAdmin.RegisterRPC('feather-admin:moderation:search', function(params, _, src)
    local query = params.query
    if not FeatherAdmin.RequirePermission(src, 'moderation.search') or not schemaReady then return end
    query = trim(query)
    local roleId = tonumber(params.roleId)
    local minimum = math.max(1, tonumber(Config.moderation.minSearchLength) or 2)
    if #query < minimum or #query > 100 then return end
    if roleId and (roleId < 1 or roleId % 1 ~= 0
        or not MySQL.scalar.await('SELECT 1 FROM roles WHERE id = ? LIMIT 1', { roleId })) then return end

    local limit = math.max(1, math.min(tonumber(Config.moderation.searchLimit) or 25, 100))
    local roleClause = roleId and 'AND r.id = ?' or ''
    local function withRole(values)
        if roleId then values[#values + 1] = roleId end
        return values
    end
    local rows
    if query:sub(1, 8):lower() == 'license:' then
        if not FeatherAdmin.RequirePermission(src, 'moderation.search_identifiers') then return end
        rows = MySQL.query.await(([=[
            SELECT u.license, u.username AS playerName, c.id AS characterId,
                   CONCAT(c.first_name, ' ', c.last_name) AS characterName,
                   r.id AS roleId, r.name AS roleName, r.level AS roleLevel
            FROM users u
            LEFT JOIN characters c ON c.user_id = u.id
            LEFT JOIN roles r ON r.id = c.role_id
            WHERE u.license = ? %s
            ORDER BY u.username, c.id
            LIMIT %d
        ]=]):format(roleClause, limit), withRole({ query }))
    elseif query:match('^%d+$') then
        rows = MySQL.query.await(([=[
            SELECT u.license, u.username AS playerName, c.id AS characterId,
                   CONCAT(c.first_name, ' ', c.last_name) AS characterName,
                   r.id AS roleId, r.name AS roleName, r.level AS roleLevel
            FROM characters c
            INNER JOIN users u ON u.id = c.user_id
            LEFT JOIN roles r ON r.id = c.role_id
            WHERE c.id = ? %s LIMIT 1
        ]=]):format(roleClause), withRole({ tonumber(query) }))
    else
        local first, last = query:match('^(%S+)%s+(.+)$')
        local queryPrefix = query .. '%'
        if first and last then
            rows = MySQL.query.await(([=[
                SELECT u.license, u.username AS playerName, c.id AS characterId,
                       CONCAT(c.first_name, ' ', c.last_name) AS characterName,
                       r.id AS roleId, r.name AS roleName, r.level AS roleLevel
                FROM users u
                LEFT JOIN characters c ON c.user_id = u.id
                LEFT JOIN roles r ON r.id = c.role_id
                WHERE (u.username LIKE ?
                   OR (c.first_name LIKE ? AND c.last_name LIKE ?)) %s
                ORDER BY u.username, c.id
                LIMIT %d
            ]=]):format(roleClause, limit), withRole({ queryPrefix, first .. '%', last .. '%' }))
        else
            rows = MySQL.query.await(([=[
        SELECT u.license, u.username AS playerName, c.id AS characterId,
               CONCAT(c.first_name, ' ', c.last_name) AS characterName,
               r.id AS roleId, r.name AS roleName, r.level AS roleLevel
        FROM users u
        LEFT JOIN characters c ON c.user_id = u.id
        LEFT JOIN roles r ON r.id = c.role_id
        WHERE (u.username LIKE ? OR c.first_name LIKE ? OR c.last_name LIKE ?) %s
        ORDER BY u.username, c.id
        LIMIT %d
            ]=]):format(roleClause, limit), withRole({ queryPrefix, queryPrefix, queryPrefix }))
        end
    end
    for _, row in ipairs(rows or {}) do
        row.serverId = onlineSourceForCharacter(row.license, row.characterId)
        row.isOnline = row.serverId ~= nil
    end
    TriggerClientEvent('feather-admin:moderation:search:result', src, rows or {})
    AdminAudit.Record(src, 'moderation.search', nil, query)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 256 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:warn', function(params, _, src)
    local targetData, reason = params.target, params.reason
    if not FeatherAdmin.RequirePermission(src, 'moderation.warn') or not schemaReady then return end
    local target, cleanReason = resolveTarget(targetData), validReason(reason)
    if not target or not cleanReason then return end
    if not FeatherAdmin.CheckTargetHierarchy(src, 'moderation.warn', target.license, target.serverId) then return end
    local adminLicense, adminName, adminCharacterId, adminCharacterName = adminIdentity(src)

    MySQL.insert.await([[
        INSERT INTO feather_admin_warnings
            (license, player_name, character_id, character_name, reason, admin_license, admin_name,
             admin_character_id, admin_character_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { target.license, target.playerName, target.characterId, target.characterName, cleanReason,
        adminLicense, adminName, adminCharacterId, adminCharacterName })
    AdminAudit.Record(src, 'moderation.warn', target.serverId, ('license=%s reason=%s'):format(target.license, cleanReason))
    -- When an admin warns themselves, the admin result below is sufficient;
    -- sending the target warning too would notify the same client twice.
    if target.serverId and target.serverId ~= src then
        FeatherAdmin.Core.Notify.RightNotify(target.serverId, ('Warning: %s'):format(cleanReason), 5000)
    end
    notify(src, 'player_warned')
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 1024 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:kick', function(params, _, src)
    local playerId, reason = params.playerId, params.reason
    if not schemaReady then return end
    local targetId = FeatherAdmin.RequireTarget(src, 'moderation.kick', playerId)
    local cleanReason = validReason(reason)
    if not targetId or not cleanReason then return end

    local target = resolveTarget({ serverId = targetId })
    if not target then return end
    local adminLicense, adminName, adminCharacterId, adminCharacterName = adminIdentity(src)

    MySQL.insert.await([[
        INSERT INTO feather_admin_kicks
            (license, player_name, character_id, character_name, reason, admin_license, admin_name,
             admin_character_id, admin_character_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { target.license, target.playerName, target.characterId, target.characterName, cleanReason,
        adminLicense, adminName, adminCharacterId, adminCharacterName })
    AdminAudit.Record(src, 'moderation.kick', targetId, ('license=%s reason=%s'):format(target.license, cleanReason))
    notify(src, 'player_kicked')
    DropPlayer(targetId, cleanReason)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 512 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:ban', function(params, _, src)
    local targetData, reason, durationMinutes = params.target, params.reason, params.durationMinutes
    if not FeatherAdmin.RequirePermission(src, 'moderation.ban') or not schemaReady then return end
    local target, cleanReason = resolveTarget(targetData), validReason(reason)
    local duration = tonumber(durationMinutes)
    local maximumDuration = tonumber(Config.moderation.maxBanMinutes) or 525600
    if not target or not cleanReason or not duration or duration < 0
        or duration > maximumDuration or duration % 1 ~= 0 then return end
    local adminLicense, adminName, adminCharacterId, adminCharacterName = adminIdentity(src)
    if not FeatherAdmin.CheckTargetHierarchy(src, 'moderation.ban', target.license, target.serverId) then return end

    MySQL.update.await('UPDATE feather_admin_bans SET active = 0 WHERE license = ? AND active = 1', { target.license })
    MySQL.insert.await([[
        INSERT INTO feather_admin_bans
            (license, player_name, character_id, character_name, reason, expires_at, admin_license, admin_name,
             admin_character_id, admin_character_name)
        VALUES (?, ?, ?, ?, ?, IF(? > 0, DATE_ADD(NOW(), INTERVAL ? MINUTE), NULL), ?, ?, ?, ?)
    ]], { target.license, target.playerName, target.characterId, target.characterName, cleanReason,
        duration, duration, adminLicense, adminName, adminCharacterId, adminCharacterName })
    AdminAudit.Record(src, 'moderation.ban', target.serverId,
        ('license=%s duration=%s reason=%s'):format(target.license, duration == 0 and 'permanent' or duration, cleanReason))
    notify(src, 'player_banned')
    if target.serverId then DropPlayer(target.serverId, cleanReason) end
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 1024 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:history', function(params, _, src)
    local targetData = params.target
    if not FeatherAdmin.RequirePermission(src, 'moderation.history') or not schemaReady then return end
    local target = resolveTarget(targetData)
    if not target then
        if type(targetData) == 'table' and targetData.serverId ~= nil then
            notify(src, 'player_not_online')
        end
        return
    end
    if not FeatherAdmin.CheckTargetHierarchy(src, 'moderation.history', target.license, target.serverId) then return end
    local limit = math.max(1, math.min(tonumber(Config.moderation.historyLimit) or 50, 100))
    local bans = MySQL.query.await(([=[
        SELECT id, 'ban' AS kind, reason, admin_name AS adminName,
               admin_character_name AS adminCharacterName,
               DATE_FORMAT(expires_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS expiresAt,
               DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS createdAt,
               revoked_by AS revokedBy, revoked_by_character_name AS revokedByCharacterName,
               DATE_FORMAT(revoked_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS revokedAt,
               CASE WHEN active = 0 THEN 'revoked'
                    WHEN expires_at IS NOT NULL AND expires_at <= NOW() THEN 'expired'
                    ELSE 'active' END AS status
        FROM feather_admin_bans WHERE license = ? ORDER BY id DESC LIMIT %d
    ]=]):format(limit), { target.license }) or {}
    local warnings = MySQL.query.await(([=[
        SELECT id, 'warning' AS kind, reason, admin_name AS adminName,
               admin_character_name AS adminCharacterName,
               NULL AS expiresAt,
               DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS createdAt,
               NULL AS revokedBy, NULL AS revokedByCharacterName, NULL AS revokedAt,
               'warning' AS status
        FROM feather_admin_warnings WHERE license = ? ORDER BY id DESC LIMIT %d
    ]=]):format(limit), { target.license }) or {}
    local kicks = MySQL.query.await(([=[
        SELECT id, 'kick' AS kind, reason, admin_name AS adminName,
               admin_character_name AS adminCharacterName,
               NULL AS expiresAt,
               DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS createdAt,
               NULL AS revokedBy, NULL AS revokedByCharacterName, NULL AS revokedAt,
               'kick' AS status
        FROM feather_admin_kicks WHERE license = ? ORDER BY id DESC LIMIT %d
    ]=]):format(limit), { target.license }) or {}
    local records = bans
    for _, warning in ipairs(warnings) do records[#records + 1] = warning end
    for _, kick in ipairs(kicks) do records[#records + 1] = kick end
    table.sort(records, function(a, b) return tostring(a.createdAt) > tostring(b.createdAt) end)
    while #records > limit do table.remove(records) end
    TriggerClientEvent('feather-admin:moderation:history:result', src, records)
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 512 })

FeatherAdmin.RegisterRPC('feather-admin:moderation:unban', function(params, _, src)
    local banId = params.banId
    if not FeatherAdmin.RequirePermission(src, 'moderation.unban') or not schemaReady then return end
    banId = tonumber(banId)
    if not banId or banId % 1 ~= 0 then return end
    local ban = MySQL.single.await('SELECT license FROM feather_admin_bans WHERE id = ? AND active = 1', { banId })
    if not ban or not FeatherAdmin.CheckTargetHierarchy(src, 'moderation.unban', ban.license, nil) then return end
    local _, adminName, adminCharacterId, adminCharacterName = adminIdentity(src)
    local changed = MySQL.update.await([[
        UPDATE feather_admin_bans
        SET active = 0, revoked_by = ?, revoked_by_character_id = ?,
            revoked_by_character_name = ?, revoked_at = NOW()
        WHERE id = ? AND active = 1
    ]], { adminName, adminCharacterId, adminCharacterName, banId })
    if not changed or changed < 1 then return end
    AdminAudit.Record(src, 'moderation.unban', nil, ('ban_id=%s'):format(banId))
    notify(src, 'ban_revoked')
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 128 })
