AdminAudit = {}

local webhook
local webhookUrl = tostring(Config.logging.webhook or '')
if webhookUrl ~= '' then
    webhook = FeatherAdmin.Core.Discord.Webhook.setup(
        webhookUrl,
        Config.logging.webhookName,
        Config.logging.webhookAvatar
    )
end

local function playerLabel(playerId)
    if playerId == nil then return 'none' end
    local name = tostring(GetPlayerName(playerId) or 'unknown'):gsub('[%c]', ' ')
    return ('%s (%s)'):format(name, tostring(playerId))
end

function AdminAudit.Record(adminId, action, targetId, details)
    details = tostring(details or 'none'):gsub('[%c]', ' '):sub(1, 500)
    local message = ('admin=%s action=%s target=%s details=%s'):format(
        playerLabel(adminId),
        tostring(action),
        playerLabel(targetId),
        details
    )

    print(('[feather-admin] %s'):format(message))
    if webhook then webhook:sendMessage('Admin Action', message) end
end
