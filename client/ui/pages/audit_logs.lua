local function valueOrUnavailable(value)
    if value == nil or value == '' then return AdminTranslate('not_available') end
    return tostring(value)
end

local function actionNameLabel(action)
    local category, name = tostring(action):match('^([^.]+)%.(.+)$')
    if not category then return tostring(action) end
    name = name:gsub('%.blocked$', ' (Blocked)'):gsub('_', ' '):gsub('^%l', string.upper)
    return name
end

local function actionLabel(action)
    local category = tostring(action):match('^([^.]+)%.')
    if not category then return tostring(action) end
    category = category:gsub('_', ' '):gsub('^%l', string.upper)
    return ('%s - %s'):format(actionNameLabel(action), category)
end

local function baseAction(action)
    return tostring(action):gsub('%.blocked$', '')
end

local function actionCategory(action)
    return baseAction(action):match('^([^.]+)%.') or 'other'
end

local function categoryLabel(category)
    return tostring(category):gsub('_', ' '):gsub('^%l', string.upper)
end

local function resultOptions()
    return {
        { display = AdminTranslate('all_results'), value = 'all' },
        { display = AdminTranslate('completed_actions'), value = 'completed' },
        { display = AdminTranslate('blocked_actions'), value = 'blocked' }
    }
end

function AdminUI.OpenAuditActionChoices(category)
    if not AdminUI.CanUse('audit.view') then return end
    local page = AdminUI.RegisterPage('audit_action_choices')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), categoryLabel(category))

    local actions = {}
    for _, storedAction in ipairs(AdminAuditLogs.actions) do
        local action = baseAction(storedAction)
        if actionCategory(action) == category then actions[action] = true end
    end
    local sorted = {}
    for action in pairs(actions) do sorted[#sorted + 1] = action end
    table.sort(sorted)
    for _, actionName in ipairs(sorted) do
        local action = actionName
        AdminUI.AddButton(page, actionNameLabel(action), function()
            AdminAuditLogs.filters.action = action
            AdminAuditLogs.Request(1)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenAuditActionCategories)
    AdminUI.OpenPage('audit_action_choices')
end

function AdminUI.OpenAuditActionCategories()
    if not AdminUI.CanUse('audit.view') then return end
    local page = AdminUI.RegisterPage('audit_action_categories')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('action_filter'))
    AdminUI.AddButton(page, AdminTranslate('all_actions'), function()
        AdminAuditLogs.filters.action = ''
        AdminAuditLogs.Request(1)
    end)

    local categories = {}
    for _, action in ipairs(AdminAuditLogs.actions) do categories[actionCategory(action)] = true end
    local sorted = {}
    for category in pairs(categories) do sorted[#sorted + 1] = category end
    table.sort(sorted)
    for _, categoryName in ipairs(sorted) do
        local category = categoryName
        AdminUI.AddButton(page, categoryLabel(category), function()
            AdminUI.OpenAuditActionChoices(category)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenAuditLogs)
    AdminUI.OpenPage('audit_action_categories')
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
    AdminUI.AddButton(page, ('%s: %s'):format(AdminTranslate('action'),
        filters.action ~= '' and actionLabel(filters.action) or AdminTranslate('all_actions')),
        AdminUI.OpenAuditActionCategories)
    local statuses = resultOptions()
    local statusIndex = 0
    for index, option in ipairs(statuses) do
        if option.value == filters.status then statusIndex = index - 1 break end
    end
    AdminUI.AddArrows(page, AdminTranslate('result'), statuses, statusIndex, function(data)
        filters.status = data.value.value
    end)
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
