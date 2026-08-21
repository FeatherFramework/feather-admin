local lastSubmission = {}

local function settings()
    return type(Config.reports) == 'table' and Config.reports or {}
end

local function clean(value, maximum)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if value == '' or #value > maximum then return nil end
    return value
end

local function categoryMap()
    local allowed = {}
    for _, category in ipairs(type(settings().categories) == 'table' and settings().categories or {}) do
        if type(category) == 'table' and type(category.value) == 'string' and category.value ~= '' then
            allowed[category.value:lower()] = true
        end
    end
    return allowed
end

local function characterIdentity(src)
    local character = FeatherAdmin.Core.Character.GetCharacter({ src = src })
    local char = character and character.char
    local license = FeatherAdmin.Core.User.GetLicense(src)
    if not char or not license then return nil end
    local characterName = ('%s %s'):format(char.first_name or '', char.last_name or ''):match('^%s*(.-)%s*$')
    return {
        license = license,
        name = GetPlayerName(src),
        characterId = tonumber(char.id),
        characterName = characterName ~= '' and characterName or nil
    }
end

local function onlineSource(license, characterId)
    characterId = tonumber(characterId)
    for _, rawId in ipairs(GetPlayers()) do
        local playerId = tonumber(rawId)
        local identity = playerId and characterIdentity(playerId)
        if identity and identity.license == license
            and (characterId == nil or identity.characterId == characterId) then return playerId end
    end
end

local function onlineReporters()
    local sources = {}
    for _, rawId in ipairs(GetPlayers()) do
        local playerId = tonumber(rawId)
        local identity = playerId and characterIdentity(playerId)
        if identity and identity.characterId then
            sources[('%s:%s'):format(identity.license, identity.characterId)] = playerId
        end
    end
    return sources
end

local function result(src, succeeded, messageKey)
    TriggerClientEvent('feather-admin:reports:action:result', src, succeeded == true, messageKey)
end

local function submissionResult(src, succeeded, messageKey, reportId)
    TriggerClientEvent('feather-admin:reports:submission:result', src,
        succeeded == true, messageKey, reportId)
end

local function reportTarget(row)
    return {
        license = row.reporter_license,
        name = row.reporter_name,
        characterId = tonumber(row.reporter_character_id),
        characterName = row.reporter_character_name
    }
end

local function notifyReporter(row, messageKey)
    local playerId = onlineSource(row.reporter_license, row.reporter_character_id)
    if playerId then TriggerClientEvent('feather-admin:reports:player:update', playerId, messageKey, row.id) end
end

FeatherAdmin.RegisterRPC('feather-admin:reports:submit', function(params, _, src)
    local config = settings()
    if config.enabled == false then return submissionResult(src, false, 'reports_disabled') end
    if not AdminDatabase.ready then return submissionResult(src, false, 'reports_unavailable') end

    local identity = characterIdentity(src)
    if not identity then return submissionResult(src, false, 'report_character_required') end
    local category = type(params.category) == 'string' and params.category:lower() or ''
    local message = clean(params.message, math.max(1, math.min(tonumber(config.maxMessageLength) or 500, 500)))
    if categoryMap()[category] ~= true or not message then
        return submissionResult(src, false, 'invalid_report')
    end

    local cooldown = math.max(0, math.min(tonumber(config.cooldownSeconds) or 120, 3600))
    local now = os.time()
    if now - (lastSubmission[src] or 0) < cooldown then
        return submissionResult(src, false, 'report_cooldown')
    end

    local maximumOpen = math.max(1, math.min(tonumber(config.maxOpenPerPlayer) or 3, 20))
    local openCount = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM feather_admin_reports
        WHERE reporter_license = ? AND status IN ('open', 'claimed')]], { identity.license })) or 0
    if openCount >= maximumOpen then return submissionResult(src, false, 'report_limit_reached') end

    local reportId = MySQL.insert.await([[INSERT INTO feather_admin_reports
        (reporter_license, reporter_name, reporter_character_id, reporter_character_name, category, message)
        VALUES (?, ?, ?, ?, ?, ?)]], {
        identity.license, identity.name, identity.characterId, identity.characterName, category, message
    })
    if not reportId then return submissionResult(src, false, 'report_submit_failed') end
    lastSubmission[src] = now
    submissionResult(src, true, 'report_submitted', reportId)

    for _, rawId in ipairs(GetPlayers()) do
        local staffId = tonumber(rawId)
        if staffId and FeatherAdmin.CanUse(staffId, 'reports.view') then
            TriggerClientEvent('feather-admin:reports:new', staffId, reportId,
                identity.characterName or identity.name, category)
        end
    end
end, { windowMs = 5000, maxCalls = 2, maxPayloadBytes = 768 })

FeatherAdmin.RegisterRPC('feather-admin:reports:list', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'reports.view') then return end
    local page = math.min(100000, math.max(1, math.floor(tonumber(params.page) or 1)))
    if not AdminDatabase.ready then
        return TriggerClientEvent('feather-admin:reports:list:result', src, {}, page, false, 'reports_unavailable')
    end

    local status = type(params.status) == 'string' and params.status or 'open'
    if status ~= 'open' and status ~= 'claimed' and status ~= 'closed' and status ~= 'all' then status = 'open' end
    local limit = math.max(1, math.min(tonumber(settings().pageLimit) or 20, 100))
    local offset = (page - 1) * limit
    local statusClause = status == 'all' and '' or 'WHERE status = ?'
    local values = status == 'all' and {} or { status }
    local rows = MySQL.query.await(([=[
        SELECT id, reporter_license, reporter_name AS reporterName,
               reporter_character_id AS reporterCharacterId,
               reporter_character_name AS reporterCharacterName,
               category, message, status, assigned_admin_license,
               assigned_admin_name AS assignedAdminName,
               assigned_admin_character_name AS assignedAdminCharacterName,
               (SELECT id FROM feather_admin_cases WHERE source_report_id = feather_admin_reports.id LIMIT 1) AS caseId,
               resolution, closed_admin_name AS closedAdminName,
               closed_admin_character_name AS closedAdminCharacterName,
               DATE_FORMAT(created_at, '%%m-%%d-%%Y %%h:%%i %%p') AS createdAt,
               DATE_FORMAT(claimed_at, '%%m-%%d-%%Y %%h:%%i %%p') AS claimedAt,
               DATE_FORMAT(closed_at, '%%m-%%d-%%Y %%h:%%i %%p') AS closedAt
        FROM feather_admin_reports %s
        ORDER BY CASE status WHEN 'open' THEN 0 WHEN 'claimed' THEN 1 ELSE 2 END,
                 created_at DESC, id DESC
        LIMIT %d OFFSET %d
    ]=]):format(statusClause, limit + 1, offset), values) or {}

    local actorLicense = FeatherAdmin.Core.User.GetLicense(src)
    local reporters = onlineReporters()
    local hasNext = #rows > limit
    if hasNext then table.remove(rows) end
    for _, row in ipairs(rows) do
        row.reporterServerId = reporters[('%s:%s'):format(row.reporter_license, row.reporterCharacterId)]
        row.reporterOnline = row.reporterServerId ~= nil
        row.assignedToSelf = row.assigned_admin_license ~= nil and row.assigned_admin_license == actorLicense
        row.reporter_license = nil
        row.assigned_admin_license = nil
    end
    TriggerClientEvent('feather-admin:reports:list:result', src, rows, page, hasNext)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:reports:claim', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'reports.claim') or not AdminDatabase.ready then return end
    local reportId = tonumber(params.reportId)
    local admin = characterIdentity(src)
    if not reportId or reportId < 1 or reportId % 1 ~= 0 or not admin then return end

    local changed = MySQL.update.await([[UPDATE feather_admin_reports
        SET status = 'claimed', assigned_admin_license = ?, assigned_admin_name = ?,
            assigned_admin_character_id = ?, assigned_admin_character_name = ?, claimed_at = NOW()
        WHERE id = ? AND status = 'open']], {
        admin.license, admin.name, admin.characterId, admin.characterName, reportId
    })
    if not changed or changed < 1 then return result(src, false, 'report_claim_failed') end
    local row = MySQL.single.await('SELECT * FROM feather_admin_reports WHERE id = ?', { reportId })
    if not row then return result(src, false, 'report_claim_failed') end
    AdminAudit.RecordTarget(src, 'reports.claim', reportTarget(row), ('report_id=%s'):format(reportId))
    notifyReporter(row, 'report_claimed')
    result(src, true, 'report_claimed_staff')
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 96 })

FeatherAdmin.RegisterRPC('feather-admin:reports:release', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'reports.claim') or not AdminDatabase.ready then return end
    local reportId = tonumber(params.reportId)
    if not reportId or reportId < 1 or reportId % 1 ~= 0 then return end
    local row = MySQL.single.await('SELECT * FROM feather_admin_reports WHERE id = ?', { reportId })
    if not row or row.status ~= 'claimed' then return result(src, false, 'report_release_failed') end
    local actorLicense = FeatherAdmin.Core.User.GetLicense(src)
    if row.assigned_admin_license ~= actorLicense and not FeatherAdmin.CanUse(src, 'reports.manage') then
        return result(src, false, 'action_not_permitted')
    end

    local changed = MySQL.update.await([[UPDATE feather_admin_reports
        SET status = 'open', assigned_admin_license = NULL, assigned_admin_name = NULL,
            assigned_admin_character_id = NULL, assigned_admin_character_name = NULL, claimed_at = NULL
        WHERE id = ? AND status = 'claimed']], { reportId })
    if not changed or changed < 1 then return result(src, false, 'report_release_failed') end
    AdminAudit.RecordTarget(src, 'reports.release', reportTarget(row), ('report_id=%s'):format(reportId))
    result(src, true, 'report_released')
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 96 })

FeatherAdmin.RegisterRPC('feather-admin:reports:close', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'reports.close') or not AdminDatabase.ready then return end
    local reportId = tonumber(params.reportId)
    local resolution = clean(params.resolution,
        math.max(1, math.min(tonumber(settings().maxResolutionLength) or 500, 500)))
    if not reportId or reportId < 1 or reportId % 1 ~= 0 or not resolution then
        return result(src, false, 'invalid_report_resolution')
    end
    local row = MySQL.single.await('SELECT * FROM feather_admin_reports WHERE id = ?', { reportId })
    if not row or row.status ~= 'claimed' then return result(src, false, 'report_close_failed') end
    local admin = characterIdentity(src)
    if not admin then return result(src, false, 'report_close_failed') end
    if row.assigned_admin_license ~= admin.license and not FeatherAdmin.CanUse(src, 'reports.manage') then
        return result(src, false, 'action_not_permitted')
    end

    local changed = MySQL.update.await([[UPDATE feather_admin_reports
        SET status = 'closed', resolution = ?, closed_admin_license = ?, closed_admin_name = ?,
            closed_admin_character_id = ?, closed_admin_character_name = ?, closed_at = NOW()
        WHERE id = ? AND status = 'claimed']], {
        resolution, admin.license, admin.name, admin.characterId, admin.characterName, reportId
    })
    if not changed or changed < 1 then return result(src, false, 'report_close_failed') end
    row.resolution = resolution
    AdminAudit.RecordTarget(src, 'reports.close', reportTarget(row),
        ('report_id=%s resolution=%s'):format(reportId, resolution))
    notifyReporter(row, 'report_closed')
    result(src, true, 'report_closed_staff')
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 768 })

AddEventHandler('playerDropped', function()
    lastSubmission[source] = nil
end)
