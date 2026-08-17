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
