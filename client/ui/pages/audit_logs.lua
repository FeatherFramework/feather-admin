local function valueOrUnavailable(value)
    if value == nil or value == '' then return AdminTranslate('not_available') end
    return tostring(value)
end

function AdminUI.OpenAuditLogDetails()
    local row = AdminAuditLogs.selected
    if not row or not AdminUI.CanUse('audit.view') then return end
    local page = AdminUI.RegisterPage('audit_log_details')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('admin_log_details'))
    AdminUI.AddText(page, table.concat({
        ('#%s - %s'):format(valueOrUnavailable(row.id), valueOrUnavailable(row.action)),
        ('%s: %s'):format(AdminTranslate('date'), valueOrUnavailable(row.createdAt)),
        ('%s: %s'):format(AdminTranslate('administrator'), valueOrUnavailable(row.adminCharacterName or row.adminName)),
        ('%s: %s'):format(AdminTranslate('player'), valueOrUnavailable(row.targetCharacterName or row.targetName)),
        ('%s: %s'):format(AdminTranslate('details'), valueOrUnavailable(row.details)),
        ('%s: %s'):format(AdminTranslate('admin_license'), valueOrUnavailable(row.adminLicense)),
        ('%s: %s'):format(AdminTranslate('target_license'), valueOrUnavailable(row.targetLicense))
    }, '\n'))
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenAuditLogs)
    AdminUI.OpenPage('audit_log_details')
end

function AdminUI.OpenAuditLogs()
    if not AdminUI.CanUse('audit.view') then return end
    local page = AdminUI.RegisterPage('audit_logs')
    local filters = AdminAuditLogs.filters
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('admin_logs_header'))

    AdminUI.AddInput(page, AdminTranslate('administrator'), AdminTranslate('optional'), function(data)
        filters.admin = data.value
    end, filters.admin)
    AdminUI.AddInput(page, AdminTranslate('player'), AdminTranslate('optional'), function(data)
        filters.target = data.value
    end, filters.target)
    AdminUI.AddInput(page, AdminTranslate('action'), AdminTranslate('optional'), function(data)
        filters.action = data.value
    end, filters.action)
    AdminUI.AddInput(page, AdminTranslate('date'), AdminTranslate('date_placeholder'), function(data)
        filters.date = data.value
    end, filters.date)
    AdminUI.AddButton(page, AdminTranslate('search'), function() AdminAuditLogs.Request(1) end)
    AdminUI.AddButton(page, AdminTranslate('clear_filters'), AdminAuditLogs.ClearFilters)
    AdminUI.AddLine(page)

    if #AdminAuditLogs.rows == 0 then
        AdminUI.AddText(page, AdminTranslate('no_admin_logs'))
    else
        for _, entry in ipairs(AdminAuditLogs.rows) do
            local row = entry
            local actor = row.adminCharacterName or row.adminName or AdminTranslate('not_available')
            AdminUI.AddButton(page, ('#%s %s - %s'):format(row.id, row.action, actor), function()
                AdminAuditLogs.selected = row
                AdminUI.OpenAuditLogDetails()
            end)
        end
    end

    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('page'), AdminAuditLogs.page))
    if AdminAuditLogs.page > 1 then
        AdminUI.AddButton(page, AdminTranslate('previous_page'), function()
            AdminAuditLogs.Request(AdminAuditLogs.page - 1)
        end)
    end
    if AdminAuditLogs.hasNext then
        AdminUI.AddButton(page, AdminTranslate('next_page'), function()
            AdminAuditLogs.Request(AdminAuditLogs.page + 1)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage('audit_logs')
end
