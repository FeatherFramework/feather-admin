AdminAuditLogs = {
    rows = {},
    page = 1,
    hasNext = false,
    actions = {},
    selected = nil,
    filters = { admin = '', target = '', action = '', status = 'all', date = '' }
}

function AdminAuditLogs.Request(page)
    if not AdminUI.CanUse('audit.view') then return false end

    Feather.RPC.Notify('feather-admin:audit:list', {
        page = math.max(1, math.floor(tonumber(page) or 1)),
        filters = AdminAuditLogs.filters
    })
    return true
end

function AdminAuditLogs.ClearFilters()
    AdminAuditLogs.filters = { admin = '', target = '', action = '', status = 'all', date = '' }
    AdminAuditLogs.Request(1)
end

RegisterNetEvent('feather-admin:audit:result', function(rows, page, hasNext, errorKey, actions)
    if errorKey then
        Feather.Notify.RightNotify(AdminTranslate(errorKey), 3000)
        return
    end

    AdminAuditLogs.rows = type(rows) == 'table' and rows or {}
    AdminAuditLogs.page = tonumber(page) or 1
    AdminAuditLogs.hasNext = hasNext == true
    AdminAuditLogs.actions = type(actions) == 'table' and actions or AdminAuditLogs.actions
    AdminUI.OpenAuditLogs()
end)
