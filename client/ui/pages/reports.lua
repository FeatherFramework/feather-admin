local function display(value)
    if value == nil or value == '' then return AdminTranslate('not_available') end
    return tostring(value)
end

local function statusLabel(status)
    local keys = { open = 'report_status_open', claimed = 'report_status_claimed', closed = 'report_status_closed' }
    return AdminTranslate(keys[status] or 'not_available')
end

local function reporterName(report)
    return report.reporterCharacterName or report.reporterName or AdminTranslate('not_available')
end

local function reportDetails(report)
    local assigned = report.assignedAdminCharacterName or report.assignedAdminName
    local lines = {
        ('%s: #%s'):format(AdminTranslate('report_id'), display(report.id)),
        ('%s: %s'):format(AdminTranslate('status'), statusLabel(report.status)),
        ('%s: %s'):format(AdminTranslate('reporter'), reporterName(report)),
        ('%s: %s'):format(AdminTranslate('reporter_status'),
            AdminTranslate(report.reporterOnline and 'online' or 'offline')),
        ('%s: %s'):format(AdminTranslate('report_category'), AdminReports.CategoryLabel(report.category)),
        ('%s: %s'):format(AdminTranslate('report_message'), display(report.message)),
        ('%s: %s'):format(AdminTranslate('created_at'), display(report.createdAt))
    }
    if assigned then lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('assigned_to'), assigned) end
    if report.claimedAt then
        lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('claimed_at'), report.claimedAt)
    end
    if report.resolution then
        lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('resolution'), report.resolution)
    end
    local closedBy = report.closedAdminCharacterName or report.closedAdminName
    if closedBy then lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('closed_by'), closedBy) end
    if report.closedAt then lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('closed_at'), report.closedAt) end
    return table.concat(lines, '\n')
end

function AdminUI.OpenReportCloseConfirmation()
    local report = AdminReports.selected
    local resolution = tostring(AdminReports.resolution or ''):match('^%s*(.-)%s*$')
    local maximum = math.max(1, tonumber(Config.reports.maxResolutionLength) or 500)
    if type(report) ~= 'table' or not AdminUI.CanUse('reports.close') then
        AdminUI.NotifyActionDenied()
        return
    end
    if resolution == '' or #resolution > maximum then
        Feather.Notify.RightNotify(AdminTranslate('invalid_report_resolution'), 3000)
        return
    end

    local page = AdminUI.RegisterPage('report_close_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_report_close'))
    AdminUI.AddText(page, reportDetails(report))
    AdminUI.AddLine(page)
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('resolution'), resolution))
    AdminUI.AddButton(page, AdminTranslate('confirm_close_report'), function()
        AdminReports.Close(report.id, resolution)
    end, AdminUI.Styles.button)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenReportDetails)
    AdminUI.OpenPage('report_close_confirmation')
end

function AdminUI.OpenReportDetails()
    local report = AdminReports.selected
    if type(report) ~= 'table' or not AdminUI.CanUse('reports.view') then return end
    local page = AdminUI.RegisterPage('report_details')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('report_details'))
    AdminUI.AddText(page, reportDetails(report))

    if report.status == 'open' and AdminUI.CanUse('reports.claim') then
        AdminUI.AddButton(page, AdminTranslate('claim_report'), function() AdminReports.Claim(report.id) end)
    elseif report.status == 'claimed' then
        if AdminUI.CanUse('reports.claim') and (report.assignedToSelf or AdminUI.CanUse('reports.manage')) then
            AdminUI.AddButton(page, AdminTranslate('release_report'), function() AdminReports.Release(report.id) end)
        end
        if AdminUI.CanUse('reports.close') and (report.assignedToSelf or AdminUI.CanUse('reports.manage')) then
            AdminUI.AddInput(page, AdminTranslate('resolution'), AdminTranslate('required'), function(data)
                AdminReports.resolution = data.value
            end, AdminReports.resolution)
            AdminUI.AddButton(page, AdminTranslate('close_report'), AdminUI.OpenReportCloseConfirmation)
        end
    end

    if report.reporterOnline and report.reporterServerId and AdminUI.CanUseOnTarget('player.go_to', report.reporterServerId) then
        AdminUI.AddButton(page, AdminTranslate('go_to_player'), function()
            AdminPlayerManagement.GoTo(report.reporterServerId)
            AdminUI.Close()
        end)
    end

    if report.caseId and AdminUI.CanUse('cases.view') then
        AdminUI.AddButton(page, AdminTranslate('open_staff_case'), function()
            AdminCases.RequestDetail(report.caseId)
        end)
    elseif AdminUI.CanUse('cases.create') then
        AdminUI.AddButton(page, AdminTranslate('create_staff_case'), AdminUI.OpenCaseCreateFromReport)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenReports)
    AdminUI.OpenPage('report_details')
end

function AdminUI.OpenReports()
    if not AdminUI.CanUse('reports.view') then
        AdminUI.NotifyActionDenied()
        return
    end

    local statuses = {
        { display = AdminTranslate('report_status_open'), value = 'open' },
        { display = AdminTranslate('report_status_claimed'), value = 'claimed' },
        { display = AdminTranslate('report_status_closed'), value = 'closed' },
        { display = AdminTranslate('all_results'), value = 'all' }
    }
    local selected = 0
    for index, option in ipairs(statuses) do
        if option.value == AdminReports.status then selected = index - 1 end
    end

    local page = AdminUI.RegisterPage('reports')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_reports'))
    AdminUI.AddArrows(page, AdminTranslate('status'), statuses, selected, function(data)
        AdminReports.status = data.value.value
        AdminReports.Request(1)
    end)
    AdminUI.AddButton(page, AdminTranslate('refresh'), function() AdminReports.Request(AdminReports.page) end)
    AdminUI.AddLine(page)

    if #AdminReports.rows == 0 then
        AdminUI.AddText(page, AdminTranslate('no_reports'))
    else
        for _, entry in ipairs(AdminReports.rows) do
            local report = entry
            AdminUI.AddButton(page, ('#%s - %s - %s'):format(tostring(report.id),
                reporterName(report), statusLabel(report.status)), function()
                AdminReports.selected = report
                AdminReports.resolution = ''
                AdminUI.OpenReportDetails()
            end)
        end
    end

    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('page'), AdminReports.page))
    if AdminReports.page > 1 then
        AdminUI.AddButton(page, AdminTranslate('previous_page'), function()
            AdminReports.Request(AdminReports.page - 1)
        end)
    end
    if AdminReports.hasNext then
        AdminUI.AddButton(page, AdminTranslate('next_page'), function()
            AdminReports.Request(AdminReports.page + 1)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenNavigationSection('moderation_center')
    end)
    AdminUI.OpenPage('reports')
end

AdminUI.RegisterNavigationItem('moderation_center', {
    key = 'player_reports',
    labelKey = 'player_reports',
    order = 20,
    permission = 'reports.view',
    open = function() AdminReports.Request(1) end
})
