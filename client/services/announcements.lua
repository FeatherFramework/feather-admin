AdminAnnouncements = {
    form = {
        title = '',
        message = ''
    },
    pending = false,
    requestSession = 0
}

local function limits()
    local settings = type(Config.announcements) == 'table' and Config.announcements or {}
    return math.max(1, tonumber(settings.maxTitleLength) or 60),
        math.max(1, tonumber(settings.maxMessageLength) or 300)
end

function AdminAnnouncements.Validate(title, message)
    local maxTitle, maxMessage = limits()
    title = type(title) == 'string' and title:match('^%s*(.-)%s*$') or ''
    message = type(message) == 'string' and message:match('^%s*(.-)%s*$') or ''
    if #title > maxTitle or message == '' or #message > maxMessage then return false end
    return true, title, message
end

function AdminAnnouncements.Send(title, message)
    if AdminAnnouncements.pending or not AdminUI.CanUse('server.announce') then return false end
    local valid, cleanTitle, cleanMessage = AdminAnnouncements.Validate(title, message)
    if not valid then return false end

    AdminAnnouncements.pending = true
    AdminAnnouncements.requestSession = AdminAnnouncements.requestSession + 1
    local session = AdminAnnouncements.requestSession
    Feather.RPC.Notify('feather-admin:announcement:send', {
        title = cleanTitle,
        message = cleanMessage
    })
    CreateThread(function()
        Wait(10000)
        if AdminAnnouncements.requestSession == session then
            AdminAnnouncements.pending = false
        end
    end)
    return true
end

RegisterNetEvent('feather-admin:announcement:result', function(succeeded, messageKey)
    AdminAnnouncements.pending = false
    if succeeded == true then
        AdminAnnouncements.form = { title = '', message = '' }
        if InMenu then AdminUI.Close() end
        return
    end
    Feather.Notify.RightNotify(AdminTranslate(messageKey or 'announcement_failed'), 3500)
end)

RegisterNetEvent('feather-admin:announcement:broadcast', function(title, message, duration)
    title = type(title) == 'string' and title or ''
    message = type(message) == 'string' and message or ''
    if message == '' then return end

    duration = tonumber(duration) or 8000
    if title ~= '' then
        Feather.Notify.TopBanner(title, message, duration)
    else
        Feather.Notify.RightNotify(message, duration)
    end
end)
