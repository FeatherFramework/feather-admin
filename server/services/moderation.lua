local schemaReady = false

local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function licenseForSource(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
end

local function adminIdentity(src)
    return licenseForSource(src), GetPlayerName(src) or ('Source %s'):format(src)
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
    local rows = MySQL.query.await([[
        SELECT u.license, u.username, c.id AS character_id,
               CONCAT(c.first_name, ' ', c.last_name) AS character_name
        FROM users u
        LEFT JOIN characters c ON c.user_id = u.id
        WHERE u.license = ?
        ORDER BY c.id ASC
        LIMIT 1
    ]], { license })
    local row = rows and rows[1]
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

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_bans (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            license VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NULL,
            character_id INT NULL,
            character_name VARCHAR(150) NULL,
            reason VARCHAR(200) NOT NULL,
            expires_at DATETIME NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NOT NULL,
            revoked_by VARCHAR(100) NULL,
            revoked_at DATETIME NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_bans_license_active (license, active),
            INDEX idx_fa_bans_expires (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_warnings (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            license VARCHAR(100) NOT NULL,
            player_name VARCHAR(100) NULL,
            character_id INT NULL,
            character_name VARCHAR(150) NULL,
            reason VARCHAR(200) NOT NULL,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_warnings_license (license)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    schemaReady = true
end)

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    local license = licenseForSource(src)
    if not license then return end

    deferrals.defer()
    Wait(0)
    deferrals.update('Checking moderation status...')

    local schemaDeadline = GetGameTimer() + 10000
    while not schemaReady and GetGameTimer() < schemaDeadline do Wait(100) end
    if not schemaReady then
        deferrals.done('The moderation service is still starting. Please try again shortly.')
        return
    end

    local ban = MySQL.single.await([[
        SELECT reason, expires_at
        FROM feather_admin_bans
        WHERE license = ? AND active = 1
          AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY id DESC LIMIT 1
    ]], { license })
    Wait(0)

    if not ban then
        deferrals.done()
        return
    end

    local message = tostring(Config.moderation.banMessage or 'You are banned from this server.')
    message = ('%s\nReason: %s'):format(message, ban.reason)
    if ban.expires_at then message = ('%s\nExpires: %s'):format(message, ban.expires_at) end
    deferrals.done(message)
end)

RegisterNetEvent('feather-admin:moderation:search', function(query)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'moderation.search') or not schemaReady then return end
    query = trim(query)
    if query == '' or #query > 100 then return end

    local pattern = ('%%%s%%'):format(query)
    local limit = math.max(1, math.min(tonumber(Config.moderation.searchLimit) or 25, 100))
    local rows = MySQL.query.await(([=[
        SELECT u.license, u.username AS playerName, c.id AS characterId,
               CONCAT(c.first_name, ' ', c.last_name) AS characterName
        FROM users u
        LEFT JOIN characters c ON c.user_id = u.id
        WHERE u.username LIKE ? OR u.license LIKE ?
           OR c.first_name LIKE ? OR c.last_name LIKE ?
           OR CONCAT(c.first_name, ' ', c.last_name) LIKE ?
        ORDER BY u.username, c.id
        LIMIT %d
    ]=]):format(limit), { pattern, pattern, pattern, pattern, pattern })
    TriggerClientEvent('feather-admin:moderation:search:result', src, rows or {})
    AdminAudit.Record(src, 'moderation.search', nil, query)
end)

RegisterNetEvent('feather-admin:moderation:warn', function(targetData, reason)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'moderation.warn') or not schemaReady then return end
    local target, cleanReason = resolveTarget(targetData), validReason(reason)
    if not target or not cleanReason then return end
    local adminLicense, adminName = adminIdentity(src)

    MySQL.insert.await([[
        INSERT INTO feather_admin_warnings
            (license, player_name, character_id, character_name, reason, admin_license, admin_name)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { target.license, target.playerName, target.characterId, target.characterName, cleanReason, adminLicense, adminName })
    AdminAudit.Record(src, 'moderation.warn', target.serverId, ('license=%s reason=%s'):format(target.license, cleanReason))
    if target.serverId then
        FeatherAdmin.Core.Notify.RightNotify(target.serverId, ('Warning: %s'):format(cleanReason), 5000)
    end
    notify(src, 'player_warned')
end)

RegisterNetEvent('feather-admin:moderation:ban', function(targetData, reason, durationMinutes)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'moderation.ban') or not schemaReady then return end
    local target, cleanReason = resolveTarget(targetData), validReason(reason)
    local duration = tonumber(durationMinutes)
    local maximumDuration = tonumber(Config.moderation.maxBanMinutes) or 525600
    if not target or not cleanReason or not duration or duration < 0
        or duration > maximumDuration or duration % 1 ~= 0 then return end
    local adminLicense, adminName = adminIdentity(src)
    if target.serverId == src or target.license == adminLicense then
        notify(src, 'cannot_ban_self')
        return
    end

    MySQL.update.await('UPDATE feather_admin_bans SET active = 0 WHERE license = ? AND active = 1', { target.license })
    MySQL.insert.await([[
        INSERT INTO feather_admin_bans
            (license, player_name, character_id, character_name, reason, expires_at, admin_license, admin_name)
        VALUES (?, ?, ?, ?, ?, IF(? > 0, DATE_ADD(NOW(), INTERVAL ? MINUTE), NULL), ?, ?)
    ]], { target.license, target.playerName, target.characterId, target.characterName, cleanReason,
        duration, duration, adminLicense, adminName })
    AdminAudit.Record(src, 'moderation.ban', target.serverId,
        ('license=%s duration=%s reason=%s'):format(target.license, duration == 0 and 'permanent' or duration, cleanReason))
    notify(src, 'player_banned')
    if target.serverId and target.serverId ~= src then DropPlayer(target.serverId, cleanReason) end
end)

RegisterNetEvent('feather-admin:moderation:history', function(targetData)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'moderation.history') or not schemaReady then return end
    local target = resolveTarget(targetData)
    if not target then return end
    local limit = math.max(1, math.min(tonumber(Config.moderation.historyLimit) or 50, 100))
    local bans = MySQL.query.await(([=[
        SELECT id, 'ban' AS kind, reason, admin_name AS adminName,
               DATE_FORMAT(expires_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS expiresAt,
               DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS createdAt,
               revoked_by AS revokedBy,
               DATE_FORMAT(revoked_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS revokedAt,
               CASE WHEN active = 0 THEN 'revoked'
                    WHEN expires_at IS NOT NULL AND expires_at <= NOW() THEN 'expired'
                    ELSE 'active' END AS status
        FROM feather_admin_bans WHERE license = ? ORDER BY id DESC LIMIT %d
    ]=]):format(limit), { target.license }) or {}
    local warnings = MySQL.query.await(([=[
        SELECT id, 'warning' AS kind, reason, admin_name AS adminName,
               NULL AS expiresAt,
               DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS createdAt,
               NULL AS revokedBy, NULL AS revokedAt,
               'warning' AS status
        FROM feather_admin_warnings WHERE license = ? ORDER BY id DESC LIMIT %d
    ]=]):format(limit), { target.license }) or {}
    for _, warning in ipairs(warnings) do bans[#bans + 1] = warning end
    table.sort(bans, function(a, b) return tostring(a.createdAt) > tostring(b.createdAt) end)
    while #bans > limit do table.remove(bans) end
    TriggerClientEvent('feather-admin:moderation:history:result', src, bans)
end)

RegisterNetEvent('feather-admin:moderation:unban', function(banId)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'moderation.unban') or not schemaReady then return end
    banId = tonumber(banId)
    if not banId or banId % 1 ~= 0 then return end
    local _, adminName = adminIdentity(src)
    local changed = MySQL.update.await([[
        UPDATE feather_admin_bans
        SET active = 0, revoked_by = ?, revoked_at = NOW()
        WHERE id = ? AND active = 1
    ]], { adminName, banId })
    if not changed or changed < 1 then return end
    AdminAudit.Record(src, 'moderation.unban', nil, ('ban_id=%s'):format(banId))
    notify(src, 'ban_revoked')
end)
