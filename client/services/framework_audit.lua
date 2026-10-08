AdminFrameworkAudit = { ticket = 0, rows = {}, history = {}, page = 1,
    filters = { hours = 24, sourceResource = '', eventType = '', correlationId = '',
        targetAccountId = '', targetCharacterId = '', adminAction = '' } }
local state = AdminFrameworkAudit

function state.Reset()
    state.ticket = state.ticket + 1
    state.pending, state.detail, state.error, state.query, state.nextCursor = nil, nil, nil, nil, nil
    state.rows, state.history, state.page = {}, {}, 1
end

function state.Read(mode, query, page)
    if not AdminUI.CanUse('audit.search') or state.pending then return end
    state.ticket = state.ticket + 1
    local ticket = state.ticket
    state.pending = { ticket = ticket, mode = mode, query = query, page = page or state.page,
        openSequence = AdminUI.openSequence }
    state.error = nil
    if mode == 'detail' then AdminUI.OpenFrameworkAuditDetail() else AdminUI.OpenFrameworkAudit() end
    state.pending.openSequence = AdminUI.openSequence
    Feather.RPC.Notify('feather-admin:framework-audit:read', { ticket = ticket, mode = mode, query = query })
    SetTimeout(15000, function()
        if state.pending and state.pending.ticket == ticket then
            state.pending = nil
            state.error = 'framework_audit_unavailable'
            if InMenu and AdminUI.currentPage == 'framework_audit' then AdminUI.OpenFrameworkAudit() end
            if InMenu and AdminUI.currentPage == 'framework_audit_detail' then AdminUI.OpenFrameworkAuditDetail() end
        end
    end)
end

function state.Search()
    state.Reset()
    local query = { hours = state.filters.hours, limit = 25 }
    for _, field in ipairs({ 'sourceResource', 'eventType', 'correlationId', 'targetAccountId', 'targetCharacterId', 'adminAction' }) do
        local value = (state.filters[field] or ''):match('^%s*(.-)%s*$')
        if value ~= '' then query[field] = value end
    end
    state.query = query
    state.mode = 'search'
    state.Read('search', query, 1)
end

function state.Page(number)
    if not state.query or state.pending then return end
    local query = {}
    for key, value in pairs(state.query) do query[key] = value end
    query.cursor = number > state.page and state.nextCursor or state.history[number]
    state.Read(state.mode, query, number)
end

function state.Detail(row)
    if not state.query then return end
    state.detail = nil
    state.Read('detail', { fromEpoch = state.query.fromEpoch, toEpoch = state.query.toEpoch,
        eventId = row.eventId })
end

function state.Correlation(row)
    if not state.query or not row.correlationId then return end
    local query = { fromEpoch = state.query.fromEpoch, toEpoch = state.query.toEpoch,
        correlationId = row.correlationId, limit = 25 }
    state.query, state.mode, state.history, state.page = query, 'correlation', {}, 1
    state.Read('correlation', query, 1)
end

RegisterNetEvent('feather-admin:framework-audit:result', function(ticket, mode, result)
    local pending = state.pending
    if not pending or ticket ~= pending.ticket or mode ~= pending.mode then return end
    state.pending = nil
    local expectedPage = mode == 'detail' and 'framework_audit_detail' or 'framework_audit'
    if not InMenu or AdminUI.currentPage ~= expectedPage
        or pending.openSequence ~= AdminUI.openSequence or not AdminUI.CanUse('audit.search') then
        state.Reset()
        return
    end
    if type(result) ~= 'table' or result.ok ~= true or type(result.value) ~= 'table' then
        state.rows, state.detail, state.nextCursor = {}, nil, nil
        state.error = type(result) == 'table' and result.code == 'forbidden' and 'framework_audit_denied' or 'framework_audit_unavailable'
    elseif mode == 'detail' then
        state.detail = result.value.event
    else
        if result.value.window and state.query then
            state.query.fromEpoch = result.value.window.fromEpoch
            state.query.toEpoch = result.value.window.toEpoch
            state.query.hours = nil
        end
        state.rows = result.value.events or {}
        state.nextCursor = result.value.nextCursor
        state.page = pending.page
        state.history[state.page] = pending.query.cursor
    end
    if mode == 'detail' then AdminUI.OpenFrameworkAuditDetail() else AdminUI.OpenFrameworkAudit() end
end)

AddEventHandler('Feather:Character:Logout', state.Reset)
RegisterNetEvent('feather-admin:access:permissions', function()
    state.Reset()
    if InMenu and (AdminUI.currentPage == 'framework_audit' or AdminUI.currentPage == 'framework_audit_detail') then
        AdminUI.Close()
    end
end)
