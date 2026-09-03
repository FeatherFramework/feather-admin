Feather = {}
Feather.RPC = {
    Notify = function(name, params, source)
        return exports['feather-core']:NotifyRPC(name, params, source)
    end
}
Feather.Locale = {
    register = function(locale, translations)
        return exports['feather-core']:RegisterLocale(locale, translations)
    end,
    translate = function(source, key, ...)
        local result = exports['feather-core']:TranslateLocale(source, key, ...)
        return type(result) == 'table' and result.ok == true and result.value
            or ('Translation [%s] is unavailable'):format(tostring(key))
    end
}

local function ShowNotification(request)
    local called, result = pcall(function()
        return exports['feather-notify']:ShowNotification(request)
    end)
    if not called then result = { ok = false, code = 'provider_unavailable' } end
    if type(result) ~= 'table' or result.ok ~= true then
        print(('[feather-admin] client notification failed code=%s'):format(
            tostring(type(result) == 'table' and result.code or 'invalid_result')))
    end
    return result
end

Feather.Notify = {
    RightNotify = function(message, duration)
        return ShowNotification({ style = 'right', message = message, duration = duration })
    end,
    TopBanner = function(title, message, duration)
        return ShowNotification({ style = 'top_banner', title = title, message = message, duration = duration })
    end
}
InMenu = false
ClientAllPlayers = {}
AdminPermissions = {}
AdminPlayerDirectory = {
    query = '',
    results = {},
    selected = nil,
    roles = {},
    roleFilterId = nil
}

AdminStaff = {
    roles = {},
    players = {},
    results = {},
    selectedTarget = nil,
    pendingTarget = nil,
    selectedRole = nil,
    roleFilterId = nil,
    reason = '',
    searchQuery = nil,
    searchPage = 1,
    searchHasNext = false,
    history = {},
    historyPage = 1,
    historyHasNext = false,
    origin = 'online'
}

function AdminTranslate(key)
    return Feather.Locale.translate(0, key)
end
