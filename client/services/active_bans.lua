AdminActiveBans = {
    rows = {},
    query = '',
    page = 1,
    hasNext = false,
    selected = nil
}

function AdminActiveBans.Request(page)
    if not AdminUI.CanUse('moderation.bans.view') then
        AdminUI.NotifyActionDenied()
        return false
    end

    AdminActiveBans.page = math.max(1, math.floor(tonumber(page) or 1))
    Feather.RPC.Notify('feather-admin:active-bans:list', {
        query = AdminActiveBans.query,
        page = AdminActiveBans.page
    })
    return true
end

function AdminActiveBans.Search(query)
    query = type(query) == 'string' and query:match('^%s*(.-)%s*$') or ''
    local minimum = math.max(1, tonumber(Config.moderation.minSearchLength) or 2)
    if query ~= '' and (#query < minimum or #query > 100) then return false end
    AdminActiveBans.query = query
    return AdminActiveBans.Request(1)
end

function AdminActiveBans.ClearSearch()
    AdminActiveBans.query = ''
    return AdminActiveBans.Request(1)
end

RegisterNetEvent('feather-admin:active-bans:result', function(rows, page, hasNext, errorKey)
    if errorKey then
        Feather.Notify.RightNotify(AdminTranslate(errorKey), 3000)
        return
    end
    rows = type(rows) == 'table' and rows or {}
    page = tonumber(page) or 1
    if #rows == 0 and page > 1 then
        return AdminActiveBans.Request(page - 1)
    end
    AdminActiveBans.rows = rows
    AdminActiveBans.page = page
    AdminActiveBans.hasNext = hasNext == true
    AdminUI.OpenActiveBans()
end)
