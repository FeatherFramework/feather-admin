AdminAudit = {}
local schemaReady = false
local pendingRecords = {}
local knownActions = {}

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

AdminDatabase.OnReady(function()
    for _, row in ipairs(MySQL.query.await('SELECT DISTINCT action FROM feather_admin_actions ORDER BY action ASC') or {}) do
        if type(row.action) == 'string' then knownActions[row.action] = true end
    end
    schemaReady = true
    for _, record in ipairs(pendingRecords) do persist(record) end
    pendingRecords = {}
end)

function AdminAudit.RecordTarget(adminId, action, target, details)
    details = tostring(details or 'none'):gsub('[%c]', ' '):sub(1, 500)
    local admin = playerIdentity(adminId)
    target = type(target) == 'table' and target or { label = 'none' }
    target.label = target.label or ('%s, character=%s (%s)'):format(
        tostring(target.name or 'unknown'), tostring(target.characterName or 'none'),
        tostring(target.characterId or 'none'))
    action = tostring(action):sub(1, 100)
    knownActions[action] = true
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

function AdminAudit.Record(adminId, action, targetId, details)
    return AdminAudit.RecordTarget(adminId, action, playerIdentity(targetId), details)
end

local function cleanFilter(value, maximum)
    if type(value) ~= 'string' then return nil end
    value = value:match('^%s*(.-)%s*$')
    if value == '' then return nil end
    return value:sub(1, maximum)
end

local function databaseDate(value)
    if value == nil then return nil end
    local month, day, year = value:match('^(%d%d)%-(%d%d)%-(%d%d%d%d)$')
    month, day, year = tonumber(month), tonumber(day), tonumber(year)
    if not month or month < 1 or month > 12 or not day or not year or year < 1000 then return false end
    local days = { 31, (year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0)) and 29 or 28,
        31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if day < 1 or day > days[month] then return false end
    return ('%04d-%02d-%02d'):format(year, month, day)
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
    local status = cleanFilter(filters.status, 10) or 'all'
    if status ~= 'completed' and status ~= 'blocked' then status = 'all' end
    local date = cleanFilter(filters.date, 10)
    if date then
        date = databaseDate(date)
        if date == false then
            return TriggerClientEvent('feather-admin:audit:result', src, {}, page, false, 'invalid_audit_date')
        end
    end

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
        if status == 'blocked' then
            clauses[#clauses + 1] = 'action = ?'
            values[#values + 1] = action .. '.blocked'
        elseif status == 'completed' then
            clauses[#clauses + 1] = 'action = ?'
            values[#values + 1] = action
        else
            clauses[#clauses + 1] = '(action = ? OR action = ?)'
            values[#values + 1] = action
            values[#values + 1] = action .. '.blocked'
        end
    elseif status == 'blocked' then
        clauses[#clauses + 1] = "action LIKE '%.blocked'"
    elseif status == 'completed' then
        clauses[#clauses + 1] = "action NOT LIKE '%.blocked'"
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
               DATE_FORMAT(created_at, '%%m-%%d-%%Y %%H:%%i:%%s') AS createdAt
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

    local actions = {}
    for name in pairs(knownActions) do actions[#actions + 1] = name end
    table.sort(actions)
    TriggerClientEvent('feather-admin:audit:result', src, rows, page, hasNext, nil, actions)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 1024 })
