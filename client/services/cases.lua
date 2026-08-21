AdminCases = {
    rows = {},
    page = 1,
    hasNext = false,
    status = 'open',
    selected = nil,
    links = {},
    activity = {},
    createForm = { title = '', summary = '', priority = 'normal', reportId = nil },
    resolution = ''
}

function AdminCases.PriorityLabel(value)
    for _, priority in ipairs(type(Config.cases.priorities) == 'table' and Config.cases.priorities or {}) do
        if priority.value == value then return AdminTranslate(priority.labelKey) end
    end
    return tostring(value or AdminTranslate('not_available'))
end

function AdminCases.Request(page)
    if not AdminUI.CanUse('cases.view') then return AdminUI.NotifyActionDenied() end
    AdminCases.page = math.max(1, math.floor(tonumber(page) or 1))
    Feather.RPC.Notify('feather-admin:cases:list', { page = AdminCases.page, status = AdminCases.status })
end

function AdminCases.RequestDetail(caseId)
    if not AdminUI.CanUse('cases.view') then return AdminUI.NotifyActionDenied() end
    Feather.RPC.Notify('feather-admin:cases:detail', { caseId = caseId })
end

function AdminCases.CreateFromReport(reportId, title, summary, priority)
    Feather.RPC.Notify('feather-admin:cases:create-from-report', {
        reportId = reportId, title = title, summary = summary, priority = priority
    })
end

function AdminCases.Claim(caseId)
    Feather.RPC.Notify('feather-admin:cases:claim', { caseId = caseId })
end

function AdminCases.Release(caseId)
    Feather.RPC.Notify('feather-admin:cases:release', { caseId = caseId })
end

function AdminCases.Link(caseId, kind, recordId)
    Feather.RPC.Notify('feather-admin:cases:link', { caseId = caseId, kind = kind, recordId = recordId })
end

function AdminCases.Close(caseId, resolution)
    Feather.RPC.Notify('feather-admin:cases:close', { caseId = caseId, resolution = resolution })
end

RegisterNetEvent('feather-admin:cases:list:result', function(rows, page, hasNext, errorKey)
    if errorKey then return Feather.Notify.RightNotify(AdminTranslate(errorKey), 3000) end
    rows = type(rows) == 'table' and rows or {}
    page = tonumber(page) or 1
    if #rows == 0 and page > 1 then return AdminCases.Request(page - 1) end
    AdminCases.rows, AdminCases.page, AdminCases.hasNext = rows, page, hasNext == true
    AdminUI.OpenCases()
end)

RegisterNetEvent('feather-admin:cases:detail:result', function(caseData, links, activity)
    AdminCases.selected = type(caseData) == 'table' and caseData or nil
    AdminCases.links = type(links) == 'table' and links or {}
    AdminCases.activity = type(activity) == 'table' and activity or {}
    if AdminCases.selected then AdminUI.OpenCaseDetails() end
end)

RegisterNetEvent('feather-admin:cases:action:result', function(succeeded, messageKey, caseId)
    Feather.Notify.RightNotify(AdminTranslate(messageKey or 'case_action_failed'), 3500)
    if succeeded ~= true then return end
    AdminCases.resolution = ''
    if messageKey == 'case_created' then
        AdminCases.createForm = { title = '', summary = '', priority = 'normal', reportId = nil }
        return AdminCases.RequestDetail(caseId)
    end
    if caseId then return AdminCases.RequestDetail(caseId) end
    AdminCases.Request(AdminCases.page)
end)
