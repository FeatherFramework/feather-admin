AdminAuditLogs = {
    rows = {},
    page = 1,
    hasNext = false,
    selected = nil,
    filters = { admin = '', target = '', action = '', date = '' }
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
    AdminAuditLogs.filters = { admin = '', target = '', action = '', date = '' }
    AdminAuditLogs.Request(1)
end

RegisterNetEvent('feather-admin:audit:result', function(rows, page, hasNext, errorKey)
    if errorKey then
        Feather.Notify.RightNotify(AdminTranslate(errorKey), 3000)
        return
    end
    AdminAuditLogs.rows = type(rows) == 'table' and rows or {}
    AdminAuditLogs.page = tonumber(page) or 1
    AdminAuditLogs.hasNext = hasNext == true
    AdminUI.OpenAuditLogs()
end)
