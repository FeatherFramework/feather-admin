local function text(value) return value == nil and AdminTranslate('not_available') or tostring(value) end
local function finish(page, key, back)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), back)
    AdminUI.OpenPage(key)
end

function AdminUI.OpenFrameworkAudit()
    if not AdminUI.CanUse('audit.search') then return end
    local state = AdminFrameworkAudit
    local page = AdminUI.RegisterPage('framework_audit')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('framework_audit'))
    if state.mode == 'correlation' and state.query then
        AdminUI.AddText(page, AdminTranslate('framework_audit_correlationId') .. ': ' .. text(state.query.correlationId))
    end
    AdminUI.AddArrows(page, AdminTranslate('framework_audit_window'), {
        { label = AdminTranslate('framework_audit_hour'), value = 1 },
        { label = AdminTranslate('framework_audit_day'), value = 24 },
        { label = AdminTranslate('framework_audit_week'), value = 168 }
    }, state.filters.hours == 1 and 0 or state.filters.hours == 24 and 1 or 2, function(data)
        state.filters.hours = data.value.value
    end)
    for _, field in ipairs({ 'sourceResource', 'eventType', 'correlationId', 'adminAction', 'targetAccountId', 'targetCharacterId' }) do
        local key = field
        AdminUI.AddInput(page, AdminTranslate('framework_audit_' .. key), AdminTranslate('optional'), function(data)
            state.filters[key] = data.value
        end, state.filters[key] or '')
    end
    AdminUI.AddButton(page, AdminTranslate('search'), state.Search)
    AdminUI.AddButton(page, AdminTranslate('clear_filters'), function()
        state.filters = { hours = 24, sourceResource = '', eventType = '', correlationId = '' }
        state.Search()
    end)
    AdminUI.AddLine(page)
    if state.pending then AdminUI.AddText(page, AdminTranslate('framework_audit_loading'))
    elseif state.error then AdminUI.AddText(page, AdminTranslate(state.error))
    elseif #state.rows == 0 then AdminUI.AddText(page, AdminTranslate('framework_audit_empty'))
    else
        for _, entry in ipairs(state.rows) do
            local row = entry
            AdminUI.AddButton(page, ('%s | %s | %s'):format(text(row.occurredAt), text(row.eventType), text(row.result)),
                function() state.Detail(row) end)
        end
    end
    if not state.pending then
        AdminUI.AddText(page, ('%s: %d'):format(AdminTranslate('page'), state.page))
        if state.page > 1 then AdminUI.AddButton(page, AdminTranslate('previous_page'), function() state.Page(state.page - 1) end) end
        if state.nextCursor then AdminUI.AddButton(page, AdminTranslate('next_page'), function() state.Page(state.page + 1) end) end
    end
    finish(page, 'framework_audit', function() state.Reset(); AdminUI.OpenNavigationSection('staff_oversight') end)
end

function AdminUI.OpenFrameworkAuditDetail()
    if not AdminUI.CanUse('audit.search') then return end
    local state = AdminFrameworkAudit
    local page = AdminUI.RegisterPage('framework_audit_detail')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('framework_audit_details'))
    if state.pending then AdminUI.AddText(page, AdminTranslate('framework_audit_loading'))
    elseif state.error then AdminUI.AddText(page, AdminTranslate(state.error))
    elseif not state.detail then AdminUI.AddText(page, AdminTranslate('framework_audit_hidden'))
    else
        local row = state.detail
        for _, field in ipairs({ 'eventId', 'eventType', 'sourceResource', 'occurredAt', 'result',
            'reasonCode', 'sensitivityClass', 'correlationId' }) do
            AdminUI.AddText(page, AdminTranslate('framework_audit_' .. field) .. ': ' .. text(row[field]))
        end
        local context = row.content and row.content.context
        if not context or next(context) == nil then AdminUI.AddText(page, AdminTranslate('framework_audit_no_content'))
        else
            local keys = {}
            for key in pairs(context) do keys[#keys + 1] = key end
            table.sort(keys)
            for _, key in ipairs(keys) do AdminUI.AddText(page, key .. ': ' .. text(context[key])) end
        end
        if row.correlationId then
            AdminUI.AddButton(page, AdminTranslate('framework_audit_related'), function() state.Correlation(row) end)
        end
    end
    finish(page, 'framework_audit_detail', AdminUI.OpenFrameworkAudit)
end

AdminUI.RegisterNavigationItem('staff_oversight', { key = 'framework_audit', labelKey = 'framework_audit',
    order = 25, permission = 'audit.search', open = function()
        AdminFrameworkAudit.Reset()
        AdminUI.OpenFrameworkAudit()
        AdminFrameworkAudit.Search()
    end })
