AdminReports = {
    rows = {},
    page = 1,
    hasNext = false,
    status = 'open',
    selected = nil,
    resolution = ''
}

function AdminReports.CategoryLabel(value)
    for _, category in ipairs(type(Config.reports.categories) == 'table' and Config.reports.categories or {}) do
        if category.value == value then return AdminTranslate(category.labelKey) end
    end
    return tostring(value or AdminTranslate('not_available'))
end

function AdminReports.Request(page)
    if not AdminUI.CanUse('reports.view') then
        AdminUI.NotifyActionDenied()
        return false
    end
    AdminReports.page = math.max(1, math.floor(tonumber(page) or 1))
    Feather.RPC.Notify('feather-admin:reports:list', {
        page = AdminReports.page,
        status = AdminReports.status
    })
    return true
end

function AdminReports.Claim(reportId)
    if not AdminUI.CanUse('reports.claim') then return false end
    Feather.RPC.Notify('feather-admin:reports:claim', { reportId = reportId })
    return true
end

function AdminReports.Release(reportId)
    if not AdminUI.CanUse('reports.claim') then return false end
    Feather.RPC.Notify('feather-admin:reports:release', { reportId = reportId })
    return true
end

function AdminReports.Close(reportId, resolution)
    if not AdminUI.CanUse('reports.close') then return false end
    Feather.RPC.Notify('feather-admin:reports:close', { reportId = reportId, resolution = resolution })
    return true
end

local function reportUsage()
    local categories = {}
    for _, category in ipairs(type(Config.reports.categories) == 'table' and Config.reports.categories or {}) do
        if type(category.value) == 'string' then categories[#categories + 1] = category.value end
    end
    return ('/%s <%s> <%s>. %s: %s'):format(
        tostring(Config.reports.command or 'report'),
        AdminTranslate('report_category'), AdminTranslate('report_message'),
        AdminTranslate('report_categories'), table.concat(categories, ', '))
end

CreateThread(function()
    if type(Config.reports) ~= 'table' or Config.reports.enabled == false then return end
    Feather.Command.Register(Config.reports.command or 'report', AdminTranslate('report_command_suggestion'),
        function(_, args)
            args = type(args) == 'table' and args or {}
            local category = tostring(args[1] or ''):lower()
            local message = table.concat(args, ' ', 2)
            if category == '' or message == '' then
                return Feather.Notify.RightNotify(reportUsage(), 5000)
            end
            Feather.RPC.Notify('feather-admin:reports:submit', { category = category, message = message })
        end, {
            { name = 'category', help = AdminTranslate('report_category_help') },
            { name = 'message', help = AdminTranslate('report_message_help') }
        })
end)

RegisterNetEvent('feather-admin:reports:submission:result', function(succeeded, messageKey, reportId)
    local message = AdminTranslate(messageKey or 'report_submit_failed')
    if succeeded == true and reportId then message = ('%s #%s'):format(message, tostring(reportId)) end
    Feather.Notify.RightNotify(message, 4000)
end)

RegisterNetEvent('feather-admin:reports:new', function(reportId, reporterName, category)
    Feather.Notify.RightNotify(('%s #%s - %s (%s)'):format(
        AdminTranslate('new_player_report'), tostring(reportId),
        tostring(reporterName or AdminTranslate('not_available')), AdminReports.CategoryLabel(category)), 5000)
end)

RegisterNetEvent('feather-admin:reports:player:update', function(messageKey, reportId)
    Feather.Notify.RightNotify(('%s #%s'):format(AdminTranslate(messageKey), tostring(reportId)), 5000)
end)

RegisterNetEvent('feather-admin:reports:list:result', function(rows, page, hasNext, errorKey)
    if errorKey then return Feather.Notify.RightNotify(AdminTranslate(errorKey), 3000) end
    rows = type(rows) == 'table' and rows or {}
    page = tonumber(page) or 1
    if #rows == 0 and page > 1 then return AdminReports.Request(page - 1) end
    AdminReports.rows = rows
    AdminReports.page = page
    AdminReports.hasNext = hasNext == true
    AdminUI.OpenReports()
end)

RegisterNetEvent('feather-admin:reports:action:result', function(succeeded, messageKey)
    Feather.Notify.RightNotify(AdminTranslate(messageKey or 'report_action_failed'), 3500)
    if succeeded ~= true then return end
    AdminReports.selected = nil
    AdminReports.resolution = ''
    AdminReports.Request(AdminReports.page)
end)
