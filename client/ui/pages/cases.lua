local function display(value)
    return value ~= nil and value ~= '' and tostring(value) or AdminTranslate('not_available')
end

local function statusLabel(status)
    return AdminTranslate(({ open = 'case_status_open', claimed = 'case_status_claimed', closed = 'case_status_closed' })[status]
        or 'not_available')
end

local function targetName(caseData)
    return caseData.targetCharacterName or caseData.targetName or AdminTranslate('not_available')
end

local function caseDetails(caseData)
    local assigned = caseData.assignedAdminCharacterName or caseData.assignedAdminName
    local createdBy = caseData.createdAdminCharacterName or caseData.createdAdminName
    local lines = {
        ('%s: #%s'):format(AdminTranslate('case_id'), display(caseData.id)),
        ('%s: %s'):format(AdminTranslate('case_title'), display(caseData.title)),
        ('%s: %s'):format(AdminTranslate('status'), statusLabel(caseData.status)),
        ('%s: %s'):format(AdminTranslate('case_priority'), AdminCases.PriorityLabel(caseData.priority)),
        ('%s: %s'):format(AdminTranslate('player'), targetName(caseData)),
        ('%s: %s'):format(AdminTranslate('case_summary'), display(caseData.summary)),
        ('%s: %s'):format(AdminTranslate('created_by'), display(createdBy)),
        ('%s: %s'):format(AdminTranslate('created_at'), display(caseData.createdAt))
    }
    if caseData.sourceReportId then
        lines[#lines + 1] = ('%s: #%s'):format(AdminTranslate('source_report'), caseData.sourceReportId)
    end
    if assigned then lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('assigned_to'), assigned) end
    if caseData.claimedAt then lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('claimed_at'), caseData.claimedAt) end
    if caseData.resolution then lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('resolution'), caseData.resolution) end
    if caseData.closedAt then lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('closed_at'), caseData.closedAt) end
    return table.concat(lines, '\n')
end

function AdminUI.OpenCaseCreateFromReport()
    local report = AdminReports.selected
    if type(report) ~= 'table' or not AdminUI.CanUse('cases.create') then return AdminUI.NotifyActionDenied() end
    local form = AdminCases.createForm
    if form.reportId ~= report.id then
        form = {
            reportId = report.id,
            title = ('Report #%s - %s'):format(report.id, AdminReports.CategoryLabel(report.category)),
            summary = report.message or '',
            priority = 'normal'
        }
        AdminCases.createForm = form
    end
    local priorities = {}
    local selected = 0
    for index, option in ipairs(Config.cases.priorities or {}) do
        priorities[#priorities + 1] = { display = AdminTranslate(option.labelKey), value = option.value }
        if option.value == form.priority then selected = index - 1 end
    end
    local page = AdminUI.RegisterPage('case_create_from_report')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('create_staff_case'))
    AdminUI.AddText(page, ('%s: #%s\n%s: %s'):format(AdminTranslate('source_report'), report.id,
        AdminTranslate('reporter'), report.reporterCharacterName or report.reporterName))
    AdminUI.AddInput(page, AdminTranslate('case_title'), AdminTranslate('required'), function(data)
        form.title = data.value
    end, form.title)
    AdminUI.AddInput(page, AdminTranslate('case_summary'), AdminTranslate('required'), function(data)
        form.summary = data.value
    end, form.summary)
    AdminUI.AddArrows(page, AdminTranslate('case_priority'), priorities, selected, function(data)
        form.priority = data.value.value
    end)
    AdminUI.AddButton(page, AdminTranslate('create_staff_case'), function()
        AdminCases.CreateFromReport(report.id, form.title, form.summary, form.priority)
    end)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenReportDetails)
    AdminUI.OpenPage('case_create_from_report')
end

function AdminUI.OpenCaseCloseConfirmation()
    local caseData = AdminCases.selected
    local resolution = tostring(AdminCases.resolution or ''):match('^%s*(.-)%s*$')
    local maximum = math.max(1, math.min(tonumber(Config.cases.maxResolutionLength) or 500, 500))
    if not caseData or resolution == '' or #resolution > maximum then
        return Feather.Notify.RightNotify(AdminTranslate('invalid_case_resolution'), 3000)
    end
    local page = AdminUI.RegisterPage('case_close_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_case_close'))
    AdminUI.AddText(page, caseDetails(caseData))
    AdminUI.AddLine(page)
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('resolution'), resolution))
    AdminUI.AddButton(page, AdminTranslate('confirm_close_case'), function()
        AdminCases.Close(caseData.id, resolution)
    end)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenCaseDetails)
    AdminUI.OpenPage('case_close_confirmation')
end

function AdminUI.OpenCaseDetails()
    local caseData = AdminCases.selected
    if not caseData or not AdminUI.CanUse('cases.view') then return end
    local page = AdminUI.RegisterPage('case_details')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('case_details'))
    AdminUI.AddText(page, caseDetails(caseData))
    if caseData.status == 'open' and AdminUI.CanUse('cases.claim') then
        AdminUI.AddButton(page, AdminTranslate('claim_case'), function() AdminCases.Claim(caseData.id) end)
    elseif caseData.status == 'claimed' and (caseData.assignedToSelf or AdminUI.CanUse('cases.manage')) then
        if AdminUI.CanUse('cases.claim') then
            AdminUI.AddButton(page, AdminTranslate('release_case'), function() AdminCases.Release(caseData.id) end)
        end
        if AdminUI.CanUse('cases.close') then
            AdminUI.AddInput(page, AdminTranslate('resolution'), AdminTranslate('required'), function(data)
                AdminCases.resolution = data.value
            end, AdminCases.resolution)
            AdminUI.AddButton(page, AdminTranslate('close_case'), AdminUI.OpenCaseCloseConfirmation)
        end
    end
    AdminUI.AddLine(page)
    AdminUI.AddText(page, AdminTranslate('linked_records'))
    if #AdminCases.links == 0 then
        AdminUI.AddText(page, AdminTranslate('no_linked_records'))
    else
        for _, link in ipairs(AdminCases.links) do
            AdminUI.AddText(page, ('%s #%s - %s'):format(display(link.kind), display(link.recordId),
                display(link.details or link.label)))
        end
    end
    if caseData.status ~= 'closed' and (caseData.assignedToSelf or AdminUI.CanUse('cases.manage'))
        and AdminUI.CanUse('cases.link') then
        AdminUI.AddLine(page)
        AdminUI.AddText(page, AdminTranslate('recent_case_activity'))
        local available = false
        for _, entry in ipairs(AdminCases.activity) do
            if not entry.linked then
                available = true
                local record = entry
                AdminUI.AddButton(page, ('%s #%s - %s'):format(display(record.kind), record.id,
                    display(record.details)), function()
                    AdminCases.Link(caseData.id, record.kind, record.id)
                end)
            end
        end
        if not available then AdminUI.AddText(page, AdminTranslate('no_case_activity')) end
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenCases)
    AdminUI.OpenPage('case_details')
end

function AdminUI.OpenCases()
    if not AdminUI.CanUse('cases.view') then return AdminUI.NotifyActionDenied() end
    local statuses = {
        { display = AdminTranslate('case_status_open'), value = 'open' },
        { display = AdminTranslate('case_status_claimed'), value = 'claimed' },
        { display = AdminTranslate('case_status_closed'), value = 'closed' },
        { display = AdminTranslate('all_results'), value = 'all' }
    }
    local selected = 0
    for index, option in ipairs(statuses) do if option.value == AdminCases.status then selected = index - 1 end end
    local page = AdminUI.RegisterPage('cases')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('staff_cases'))
    AdminUI.AddArrows(page, AdminTranslate('status'), statuses, selected, function(data)
        AdminCases.status = data.value.value
        AdminCases.Request(1)
    end)
    AdminUI.AddButton(page, AdminTranslate('refresh'), function() AdminCases.Request(AdminCases.page) end)
    AdminUI.AddLine(page)
    if #AdminCases.rows == 0 then
        AdminUI.AddText(page, AdminTranslate('no_cases'))
    else
        for _, entry in ipairs(AdminCases.rows) do
            local caseData = entry
            AdminUI.AddButton(page, ('#%s - %s - %s'):format(caseData.id,
                AdminCases.PriorityLabel(caseData.priority), targetName(caseData)), function()
                AdminCases.RequestDetail(caseData.id)
            end)
        end
    end
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('page'), AdminCases.page))
    if AdminCases.page > 1 then
        AdminUI.AddButton(page, AdminTranslate('previous_page'), function() AdminCases.Request(AdminCases.page - 1) end)
    end
    if AdminCases.hasNext then
        AdminUI.AddButton(page, AdminTranslate('next_page'), function() AdminCases.Request(AdminCases.page + 1) end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function() AdminUI.OpenNavigationSection('moderation_center') end)
    AdminUI.OpenPage('cases')
end

AdminUI.RegisterNavigationItem('moderation_center', {
    key = 'staff_cases', labelKey = 'staff_cases', order = 30,
    permission = 'cases.view', open = function() AdminCases.Request(1) end
})
