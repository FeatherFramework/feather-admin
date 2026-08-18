AdminAudit = {}
local schemaReady = false
local pendingRecords = {}

local webhook
local webhookUrl = tostring(Config.logging.webhook or '')
if webhookUrl ~= '' then
    webhook = FeatherAdmin.Core.Discord.Webhook.setup(
        webhookUrl,
        Config.logging.webhookName,
        Config.logging.webhookAvatar
    )
end

local function playerIdentity(playerId)
    if playerId == nil then return { label = 'none' } end
    local name = tostring(GetPlayerName(playerId) or 'unknown'):gsub('[%c]', ' ')
    local license = FeatherAdmin.Core.User.GetLicense(playerId)
    local character = FeatherAdmin.Core.Character.GetCharacter({ src = playerId })
    local char = character and character.char or {}
    local characterName
    if char.first_name then
        characterName = ('%s %s'):format(char.first_name, char.last_name or ''):gsub('%s+$', '')
    end
    if characterName then
        return {
            label = ('%s (%s), character=%s (%s)'):format(name, tostring(playerId), characterName, tostring(char.id)),
            license = license, name = name, characterId = tonumber(char.id), characterName = characterName
        }
    end
    return { label = ('%s (%s), character=none'):format(name, tostring(playerId)), license = license, name = name }
end

local function persist(record)
    MySQL.insert.await([[
        INSERT INTO feather_admin_actions
            (admin_license, admin_name, admin_character_id, admin_character_name,
             action, target_license, target_name, target_character_id, target_character_name, details)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        record.admin.license, record.admin.name, record.admin.characterId, record.admin.characterName,
        record.action, record.target.license, record.target.name, record.target.characterId,
        record.target.characterName, record.details
    })
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS feather_admin_actions (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            admin_license VARCHAR(100) NULL,
            admin_name VARCHAR(100) NULL,
            admin_character_id INT NULL,
            admin_character_name VARCHAR(150) NULL,
            action VARCHAR(100) NOT NULL,
            target_license VARCHAR(100) NULL,
            target_name VARCHAR(100) NULL,
            target_character_id INT NULL,
            target_character_name VARCHAR(150) NULL,
            details VARCHAR(500) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_fa_actions_admin_license (admin_license),
            INDEX idx_fa_actions_target_license (target_license),
            INDEX idx_fa_actions_action (action),
            INDEX idx_fa_actions_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    schemaReady = true
    for _, record in ipairs(pendingRecords) do persist(record) end
    pendingRecords = {}
end)

function AdminAudit.Record(adminId, action, targetId, details)
    details = tostring(details or 'none'):gsub('[%c]', ' '):sub(1, 500)
    local admin = playerIdentity(adminId)
    local target = playerIdentity(targetId)
    action = tostring(action):sub(1, 100)
    local record = { admin = admin, target = target, action = action, details = details }
    local message = ('admin=%s action=%s target=%s details=%s'):format(admin.label, action, target.label, details)

    print(('[feather-admin] %s'):format(message))
    if schemaReady then
        persist(record)
    elseif #pendingRecords < 1000 then
        pendingRecords[#pendingRecords + 1] = record
    else
        print('[feather-admin] Audit queue full; action could not be persisted.')
    end
    if webhook then webhook:sendMessage('Admin Action', message) end
end

local function cleanFilter(value, maximum)
    if type(value) ~= 'string' then return nil end
    value = value:match('^%s*(.-)%s*$')
    if value == '' then return nil end
    return value:sub(1, maximum)
end

FeatherAdmin.RegisterRPC('feather-admin:audit:list', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'audit.view') then return end
    if not schemaReady then
        return TriggerClientEvent('feather-admin:audit:result', src, {}, 1, false, 'audit_unavailable')
    end

    local page = math.min(100000, math.max(1, math.floor(tonumber(params.page) or 1)))
    local pageSize = 20
    local filters = type(params.filters) == 'table' and params.filters or {}
    local admin = cleanFilter(filters.admin, 100)
    local target = cleanFilter(filters.target, 100)
    local action = cleanFilter(filters.action, 100)
    local date = cleanFilter(filters.date, 10)
    if date and not date:match('^%d%d%d%d%-%d%d%-%d%d$') then date = nil end

    local clauses = {}
    local values = {}
    if admin then
        clauses[#clauses + 1] = '(admin_name LIKE ? OR admin_character_name LIKE ?)'
        values[#values + 1] = admin .. '%'
        values[#values + 1] = admin .. '%'
    end
    if target then
        clauses[#clauses + 1] = '(target_name LIKE ? OR target_character_name LIKE ?)'
        values[#values + 1] = target .. '%'
        values[#values + 1] = target .. '%'
    end
    if action then
        clauses[#clauses + 1] = 'action LIKE ?'
        values[#values + 1] = action .. '%'
    end
    if date then
        clauses[#clauses + 1] = 'created_at >= ? AND created_at < DATE_ADD(?, INTERVAL 1 DAY)'
        values[#values + 1] = date
        values[#values + 1] = date
    end

    local where = #clauses > 0 and (' WHERE ' .. table.concat(clauses, ' AND ')) or ''
    local offset = (page - 1) * pageSize
    local query = ([=[
        SELECT id, admin_license AS adminLicense, admin_name AS adminName,
               admin_character_name AS adminCharacterName, action,
               target_license AS targetLicense, target_name AS targetName,
               target_character_name AS targetCharacterName, details,
               DATE_FORMAT(created_at, '%%Y-%%m-%%d %%H:%%i:%%s') AS createdAt
        FROM feather_admin_actions%s
        ORDER BY id DESC
        LIMIT %d OFFSET %d
    ]=]):format(where, pageSize + 1, offset)
    local rows = MySQL.query.await(query, values) or {}
    local hasNext = #rows > pageSize
    if hasNext then rows[#rows] = nil end

    if not FeatherAdmin.CanUse(src, 'audit.sensitive') then
        for _, row in ipairs(rows) do
            row.adminLicense = nil
            row.targetLicense = nil
            if tostring(row.action):sub(1, 8) == 'economy.' then
                row.details = 'Restricted'
            else
                row.details = tostring(row.details or ''):gsub('license=[^%s]+', 'license=restricted')
            end
        end
    end

    TriggerClientEvent('feather-admin:audit:result', src, rows, page, hasNext)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 1024 })
