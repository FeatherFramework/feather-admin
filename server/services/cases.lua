local function settings()
    return type(Config.cases) == 'table' and Config.cases or {}
end

local function clean(value, maximum)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if value == '' or #value > maximum then return nil end
    return value
end

local function identity(src)
    local resolved = FeatherAdmin.Identity.Resolve(src)
    local license = FeatherAdmin.Core.User.GetLicense(src)
    if not resolved or not resolved.accountId or not resolved.characterId or not license then return nil end
    return {
        accountId = resolved.accountId,
        license = license,
        name = resolved.accountName or resolved.serverName,
        characterId = resolved.characterId,
        characterName = resolved.characterName
    }
end

local function allowedPriority(value)
    if type(value) ~= 'string' then return nil end
    for _, priority in ipairs(type(settings().priorities) == 'table' and settings().priorities or {}) do
        if priority.value == value then return value end
    end
end

local function actionResult(src, succeeded, messageKey, caseId)
    TriggerClientEvent('feather-admin:cases:action:result', src, succeeded == true, messageKey, caseId)
end

local function caseRow(caseId)
    return MySQL.single.await([[
        SELECT id, source_report_id AS sourceReportId, target_account_id AS targetAccountId, target_license,
               target_name AS targetName, target_character_id AS targetCharacterId,
               target_character_name AS targetCharacterName, title, summary, priority, status,
               created_admin_account_id AS createdAdminAccountId, created_admin_name AS createdAdminName,
               created_admin_character_name AS createdAdminCharacterName,
               assigned_admin_account_id AS assignedAdminAccountId, assigned_admin_license,
               assigned_admin_name AS assignedAdminName,
               assigned_admin_character_name AS assignedAdminCharacterName,
               resolution, closed_admin_account_id AS closedAdminAccountId,
               closed_admin_name AS closedAdminName,
               closed_admin_character_name AS closedAdminCharacterName,
               DATE_FORMAT(claimed_at, '%m-%d-%Y %h:%i %p') AS claimedAt,
               DATE_FORMAT(closed_at, '%m-%d-%Y %h:%i %p') AS closedAt,
               DATE_FORMAT(created_at, '%m-%d-%Y %h:%i %p') AS createdAt
        FROM feather_admin_cases WHERE id = ?
    ]], { caseId })
end

local function targetForAudit(row)
    return {
        accountId = row.targetAccountId or row.target_account_id,
        license = row.target_license,
        name = row.targetName,
        characterId = row.targetCharacterId,
        characterName = row.targetCharacterName
    }
end

local function canManageCase(src, row, permission)
    if not row then return false end
    local actor = identity(src)
    return actor and row.assignedAdminAccountId == actor.accountId
        or FeatherAdmin.CanUse(src, permission or 'cases.manage')
end

FeatherAdmin.RegisterRPC('feather-admin:cases:list', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'cases.view') then return end
    local page = math.min(100000, math.max(1, math.floor(tonumber(params.page) or 1)))
    if not AdminDatabase.ready then
        return TriggerClientEvent('feather-admin:cases:list:result', src, {}, page, false, 'cases_unavailable')
    end

    local status = type(params.status) == 'string' and params.status or 'open'
    if status ~= 'open' and status ~= 'claimed' and status ~= 'closed' and status ~= 'all' then status = 'open' end
    local limit = math.max(1, math.min(tonumber(settings().pageLimit) or 20, 100))
    local where = status == 'all' and '' or 'WHERE status = ?'
    local values = status == 'all' and {} or { status }
    local rows = MySQL.query.await(([=[
        SELECT id, source_report_id AS sourceReportId, target_name AS targetName,
               target_character_name AS targetCharacterName, title, priority, status,
               assigned_admin_name AS assignedAdminName,
               assigned_admin_character_name AS assignedAdminCharacterName,
               DATE_FORMAT(created_at, '%%m-%%d-%%Y %%h:%%i %%p') AS createdAt
        FROM feather_admin_cases %s
        ORDER BY CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END,
                 created_at DESC, id DESC LIMIT %d OFFSET %d
    ]=]):format(where, limit + 1, (page - 1) * limit), values) or {}
    local hasNext = #rows > limit
    if hasNext then table.remove(rows) end
    TriggerClientEvent('feather-admin:cases:list:result', src, rows, page, hasNext)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:cases:create-from-report', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'cases.create') or not AdminDatabase.ready then return end
    local reportId = tonumber(params.reportId)
    local priority = allowedPriority(params.priority)
    local maximumTitle = math.max(1, math.min(tonumber(settings().maxTitleLength) or 100, 100))
    local maximumSummary = math.max(1, math.min(tonumber(settings().maxSummaryLength) or 500, 500))
    local title = clean(params.title, maximumTitle)
    local summary = clean(params.summary, maximumSummary)
    local admin = identity(src)
    if not reportId or reportId < 1 or reportId % 1 ~= 0 or not priority or not title or not summary or not admin then
        return actionResult(src, false, 'invalid_case')
    end
    local report = MySQL.single.await('SELECT * FROM feather_admin_reports WHERE id = ?', { reportId })
    if not report then return actionResult(src, false, 'report_not_found') end
    if type(report.reporter_account_id) ~= 'string'
        or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'cases.create', report.reporter_account_id, nil) then return end
    if MySQL.scalar.await('SELECT id FROM feather_admin_cases WHERE source_report_id = ? LIMIT 1', { reportId }) then
        return actionResult(src, false, 'report_case_exists')
    end
    local caseId = MySQL.insert.await([[
        INSERT INTO feather_admin_cases
            (source_report_id, target_account_id, target_license, target_name, target_character_id, target_character_name,
             title, summary, priority, created_admin_account_id, created_admin_license, created_admin_name,
             created_admin_character_id, created_admin_character_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { reportId, report.reporter_account_id, report.reporter_license, report.reporter_name,
        report.reporter_character_id, report.reporter_character_name, title, summary, priority,
        admin.accountId, admin.license, admin.name,
        admin.characterId, admin.characterName })
    if not caseId then return actionResult(src, false, 'case_create_failed') end
    MySQL.insert.await([[INSERT IGNORE INTO feather_admin_case_links
        (case_id, link_type, link_id, label, details, admin_account_id, admin_license, admin_name,
         admin_character_id, admin_character_name)
        VALUES (?, 'report', ?, ?, ?, ?, ?, ?, ?, ?)]], {
        caseId, reportId, ('Report #%s'):format(reportId), report.message,
        admin.accountId, admin.license, admin.name, admin.characterId, admin.characterName
    })
    AdminAudit.RecordTarget(src, 'cases.create', targetForAudit({
        target_account_id = report.reporter_account_id,
        target_license = report.reporter_license, targetName = report.reporter_name,
        targetCharacterId = report.reporter_character_id,
        targetCharacterName = report.reporter_character_name
    }), ('case_id=%s report_id=%s priority=%s'):format(caseId, reportId, priority))
    actionResult(src, true, 'case_created', caseId)
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 1280 })

FeatherAdmin.RegisterRPC('feather-admin:cases:detail', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'cases.view') or not AdminDatabase.ready then return end
    local caseId = tonumber(params.caseId)
    if not caseId or caseId < 1 or caseId % 1 ~= 0 then return end
    local row = caseRow(caseId)
    if not row then return actionResult(src, false, 'case_not_found') end
    local targetAccountId = row.targetAccountId
    local limit = math.max(1, math.min(tonumber(settings().activityLimit) or 20, 50))
    local activity = {}
    local sources = {
        { kind = 'warning', tableName = 'feather_admin_warnings', detailColumn = 'reason', accountColumn = 'account_id' },
        { kind = 'kick', tableName = 'feather_admin_kicks', detailColumn = 'reason', accountColumn = 'account_id' },
        { kind = 'ban', tableName = 'feather_admin_bans', detailColumn = 'reason', accountColumn = 'account_id' },
        { kind = 'note', tableName = 'feather_admin_player_notes', detailColumn = 'body',
          accountColumn = 'target_account_id' }
    }
    for _, source in ipairs(sources) do
        local records = MySQL.query.await(([=[SELECT id, '%s' AS kind, %s AS details,
            DATE_FORMAT(created_at, '%%m-%%d-%%Y %%h:%%i %%p') AS createdAt
            FROM %s WHERE %s = ? ORDER BY id DESC LIMIT %d]=]):format(
            source.kind, source.detailColumn, source.tableName, source.accountColumn, limit), { targetAccountId }) or {}
        for _, record in ipairs(records) do activity[#activity + 1] = record end
    end
    if FeatherAdmin.CanUse(src, 'audit.view') then
        local audits = MySQL.query.await(([=[SELECT id, 'audit' AS kind, action,
            COALESCE(details, '') AS details,
            DATE_FORMAT(created_at, '%%m-%%d-%%Y %%h:%%i %%p') AS createdAt
            FROM feather_admin_actions WHERE target_account_id = ? ORDER BY id DESC LIMIT %d]=]):format(limit),
            { targetAccountId }) or {}
        for _, record in ipairs(audits) do
            if not FeatherAdmin.CanUse(src, 'audit.sensitive') then
                if tostring(record.action):sub(1, 8) == 'economy.' then
                    record.details = 'Restricted'
                else
                    record.details = tostring(record.details):gsub('license=[^%s]+', 'license=restricted')
                end
            end
            record.details = ('%s: %s'):format(record.action, record.details)
            record.action = nil
            activity[#activity + 1] = record
        end
    end
    table.sort(activity, function(a, b) return tostring(a.createdAt) > tostring(b.createdAt) end)
    while #activity > limit do table.remove(activity) end
    local links = MySQL.query.await([[
        SELECT id, link_type AS kind, link_id AS recordId, label, details,
               admin_character_name AS adminCharacterName, admin_name AS adminName,
               DATE_FORMAT(created_at, '%m-%d-%Y %h:%i %p') AS createdAt
        FROM feather_admin_case_links WHERE case_id = ? ORDER BY id ASC
    ]], { caseId }) or {}
    local linked = {}
    for _, link in ipairs(links) do linked[('%s:%s'):format(link.kind, link.recordId)] = true end
    for _, record in ipairs(activity) do record.linked = linked[('%s:%s'):format(record.kind, record.id)] == true end
    local actor = identity(src)
    row.assignedToSelf = actor ~= nil and row.assignedAdminAccountId == actor.accountId
    row.target_license = nil
    row.assigned_admin_license = nil
    TriggerClientEvent('feather-admin:cases:detail:result', src, row, links, activity)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 96 })

FeatherAdmin.RegisterRPC('feather-admin:cases:claim', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'cases.claim') or not AdminDatabase.ready then return end
    local caseId = tonumber(params.caseId)
    local admin = identity(src)
    if not caseId or caseId % 1 ~= 0 or not admin then return end
    local row = caseRow(caseId)
    if not row or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'cases.claim', row.targetAccountId, nil) then return end
    local changed = MySQL.update.await([[UPDATE feather_admin_cases SET status = 'claimed',
        assigned_admin_account_id = ?, assigned_admin_license = ?, assigned_admin_name = ?, assigned_admin_character_id = ?,
        assigned_admin_character_name = ?, claimed_at = NOW() WHERE id = ? AND status = 'open']],
        { admin.accountId, admin.license, admin.name, admin.characterId, admin.characterName, caseId })
    if not changed or changed < 1 then return actionResult(src, false, 'case_claim_failed') end
    AdminAudit.RecordTarget(src, 'cases.claim', targetForAudit(row), ('case_id=%s'):format(caseId))
    actionResult(src, true, 'case_claimed', caseId)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 96 })

FeatherAdmin.RegisterRPC('feather-admin:cases:release', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'cases.claim') or not AdminDatabase.ready then return end
    local caseId = tonumber(params.caseId)
    local row = caseId and caseRow(caseId)
    if not row or row.status ~= 'claimed' then return actionResult(src, false, 'case_release_failed') end
    if not FeatherAdmin.CheckTargetAccountHierarchy(src, 'cases.claim', row.targetAccountId, nil) then return end
    if not canManageCase(src, row) then return actionResult(src, false, 'action_not_permitted') end
    local changed = MySQL.update.await([[UPDATE feather_admin_cases SET status = 'open',
        assigned_admin_account_id = NULL, assigned_admin_license = NULL, assigned_admin_name = NULL,
        assigned_admin_character_id = NULL,
        assigned_admin_character_name = NULL, claimed_at = NULL WHERE id = ? AND status = 'claimed']], { caseId })
    if not changed or changed < 1 then return actionResult(src, false, 'case_release_failed') end
    AdminAudit.RecordTarget(src, 'cases.release', targetForAudit(row), ('case_id=%s'):format(caseId))
    actionResult(src, true, 'case_released', caseId)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 96 })

FeatherAdmin.RegisterRPC('feather-admin:cases:link', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'cases.link') or not AdminDatabase.ready then return end
    local caseId, recordId = tonumber(params.caseId), tonumber(params.recordId)
    local kind = type(params.kind) == 'string' and params.kind or ''
    local tables = { warning = 'feather_admin_warnings', kick = 'feather_admin_kicks',
        ban = 'feather_admin_bans', audit = 'feather_admin_actions',
        note = 'feather_admin_player_notes' }
    local tableName = tables[kind]
    local row = caseId and caseRow(caseId)
    if not row or row.status == 'closed' or not recordId or recordId % 1 ~= 0 or not tableName then
        return actionResult(src, false, 'case_link_failed')
    end
    if kind == 'audit' and not FeatherAdmin.CanUse(src, 'audit.view') then
        return actionResult(src, false, 'action_not_permitted')
    end
    if not FeatherAdmin.CheckTargetAccountHierarchy(src, 'cases.link', row.targetAccountId, nil) then return end
    if not canManageCase(src, row) then return actionResult(src, false, 'action_not_permitted') end
    local accountColumn = (kind == 'audit' or kind == 'note') and 'target_account_id' or 'account_id'
    local record = MySQL.single.await(('SELECT id FROM %s WHERE id = ? AND %s = ?'):format(tableName, accountColumn),
        { recordId, row.targetAccountId })
    if not record then return actionResult(src, false, 'case_link_failed') end
    local admin = identity(src)
    if not admin then return actionResult(src, false, 'case_link_failed') end
    MySQL.insert.await([[INSERT IGNORE INTO feather_admin_case_links
        (case_id, link_type, link_id, label, admin_account_id, admin_license, admin_name,
         admin_character_id, admin_character_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { caseId, kind, recordId,
        ('%s #%s'):format(kind, recordId), admin.accountId, admin.license, admin.name,
        admin.characterId, admin.characterName })
    AdminAudit.RecordTarget(src, 'cases.link', targetForAudit(row),
        ('case_id=%s link=%s:%s'):format(caseId, kind, recordId))
    actionResult(src, true, 'case_record_linked', caseId)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:cases:close', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'cases.close') or not AdminDatabase.ready then return end
    local caseId = tonumber(params.caseId)
    local resolution = clean(params.resolution,
        math.max(1, math.min(tonumber(settings().maxResolutionLength) or 500, 500)))
    local row = caseId and caseRow(caseId)
    local admin = identity(src)
    if not row or row.status == 'closed' or not resolution or not admin then
        return actionResult(src, false, 'case_close_failed')
    end
    if not FeatherAdmin.CheckTargetAccountHierarchy(src, 'cases.close', row.targetAccountId, nil) then return end
    if not canManageCase(src, row) then return actionResult(src, false, 'action_not_permitted') end
    local changed = MySQL.update.await([[UPDATE feather_admin_cases SET status = 'closed', resolution = ?,
        closed_admin_account_id = ?, closed_admin_license = ?, closed_admin_name = ?, closed_admin_character_id = ?,
        closed_admin_character_name = ?, closed_at = NOW() WHERE id = ? AND status <> 'closed']],
        { resolution, admin.accountId, admin.license, admin.name, admin.characterId, admin.characterName, caseId })
    if not changed or changed < 1 then return actionResult(src, false, 'case_close_failed') end
    AdminAudit.RecordTarget(src, 'cases.close', targetForAudit(row),
        ('case_id=%s resolution=%s'):format(caseId, resolution))
    actionResult(src, true, 'case_closed', caseId)
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 768 })
