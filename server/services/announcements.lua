local lastAnnouncement = {}

local function limits()
    local settings = type(Config.announcements) == 'table' and Config.announcements or {}
    return math.max(1, math.min(tonumber(settings.maxTitleLength) or 60, 100)),
        math.max(1, math.min(tonumber(settings.maxMessageLength) or 300, 500)),
        math.max(0, math.min(tonumber(settings.cooldownSeconds) or 30, 3600)),
        math.max(1000, math.min(tonumber(settings.duration) or 8000, 30000))
end

local function clean(value, maximum, required)
    if type(value) ~= 'string' then return required and nil or '' end
    value = value:gsub('[%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if value == '' then return required and nil or '' end
    if #value > maximum then return nil end
    return value
end

local function result(src, succeeded, messageKey)
    TriggerClientEvent('feather-admin:announcement:result', src, succeeded == true, messageKey)
end

FeatherAdmin.RegisterRPC('feather-admin:announcement:send', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'server.announce') then return end

    local maxTitle, maxMessage, cooldown, duration = limits()
    local title = clean(params.title, maxTitle, false)
    local message = clean(params.message, maxMessage, true)
    if title == nil or message == nil then
        return result(src, false, 'invalid_announcement')
    end

    local now = os.time()
    if now - (lastAnnouncement[src] or 0) < cooldown then
        return result(src, false, 'announcement_cooldown')
    end
    lastAnnouncement[src] = now

    AdminAudit.Record(src, 'server.announce', nil,
        ('title=%s message=%s'):format(title ~= '' and title or 'none', message))
    TriggerClientEvent('feather-admin:announcement:broadcast', -1, title, message, duration)
    result(src, true)
end, { windowMs = 5000, maxCalls = 2, maxPayloadBytes = 768 })

AddEventHandler('playerDropped', function()
    lastAnnouncement[source] = nil
end)
