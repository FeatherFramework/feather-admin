local function settings()
    return type(Config.notes) == 'table' and Config.notes or {}
end

local function clean(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    local maximum = math.max(1, math.min(tonumber(settings().maxBodyLength) or 1000, 1000))
    return value ~= '' and #value <= maximum and value or nil
end

local function actor(src)
    local identity = FeatherAdmin.Identity.Resolve(src)
    if not identity or not identity.accountId or not identity.characterId then return nil end
    return { accountId = identity.accountId, name = identity.accountName or identity.serverName,
        characterId = identity.characterId, characterName = identity.characterName }
end

local function target(accountId, characterId, serverId)
    serverId = tonumber(serverId)
    if serverId and GetPlayerName(serverId) then
        local identity = FeatherAdmin.Identity.Resolve(serverId)
        if identity and identity.accountId and identity.characterId then
            return { accountId = identity.accountId,
                targetName = identity.accountName or identity.serverName,
                characterId = identity.characterId, characterName = identity.characterName,
                serverId = serverId }
        end
    end
    if type(accountId) ~= 'string' or accountId == '' then return nil end
    local row
    if type(characterId) == 'string' and characterId ~= '' then
        row = MySQL.single.await([[SELECT a.id AS accountId, a.display_name AS targetName,
            p.character_id AS characterId, CONCAT(p.first_name, ' ', p.last_name) AS characterName
            FROM core_accounts a INNER JOIN character_profiles p
              ON p.account_id COLLATE utf8mb4_unicode_ci = a.id COLLATE utf8mb4_unicode_ci
            WHERE a.id = ? AND p.character_id = ? AND a.status = 'active' AND p.status = 'active' LIMIT 1]],
            { accountId, characterId })
    else
        row = MySQL.single.await([[SELECT id AS accountId, display_name AS targetName,
            NULL AS characterId, NULL AS characterName FROM core_accounts
            WHERE id = ? AND status = 'active' LIMIT 1]], { accountId })
    end
    return row
end

local function auditTarget(row)
    return { accountId = row.accountId, name = row.targetName,
        characterId = row.characterId, characterName = row.characterName }
end

local function result(src, succeeded, messageKey, noteId)
    TriggerClientEvent('feather-admin:notes:action:result', src, succeeded == true, messageKey, noteId)
end

FeatherAdmin.RegisterRPC('feather-admin:notes:list', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'notes.view') or not AdminDatabase.ready then return end
    local accountId, characterId = params.accountId, params.characterId
    local subject = target(accountId, characterId, params.serverId)
    if not subject or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'notes.view', subject.accountId, nil) then return end
    local page = math.min(100000, math.max(1, math.floor(tonumber(params.page) or 1)))
    local limit = math.max(1, math.min(tonumber(settings().pageLimit) or 20, 100))
    local rows = MySQL.query.await(([=[SELECT id, body, revision,
        created_admin_name AS createdAdminName, created_admin_character_name AS createdAdminCharacterName,
        updated_admin_name AS updatedAdminName, updated_admin_character_name AS updatedAdminCharacterName,
        DATE_FORMAT(created_at, '%%m-%%d-%%Y %%h:%%i %%p') AS createdAt,
        DATE_FORMAT(updated_at, '%%m-%%d-%%Y %%h:%%i %%p') AS updatedAt
        FROM feather_admin_player_notes WHERE target_account_id = ? AND archived = 0
        ORDER BY created_at DESC, id DESC LIMIT %d OFFSET %d]=]):format(
        limit + 1, (page - 1) * limit), { subject.accountId }) or {}
    local hasNext = #rows > limit
    if hasNext then table.remove(rows) end
    TriggerClientEvent('feather-admin:notes:list:result', src, subject, rows, page, hasNext)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 192 })

FeatherAdmin.RegisterRPC('feather-admin:notes:create', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'notes.create') or not AdminDatabase.ready then return end
    local admin, subject, body = actor(src), target(params.accountId, params.characterId, params.serverId), clean(params.body)
    if not admin or not subject or not body then return result(src, false, 'invalid_player_note') end
    if not FeatherAdmin.CheckTargetAccountHierarchy(src, 'notes.create', subject.accountId, nil) then return end
    local noteId
    local executed, committed = pcall(MySQL.startTransaction, function(query)
        local insert = query([[INSERT INTO feather_admin_player_notes
            (target_account_id, target_name, target_character_id, target_character_name, body,
             created_admin_account_id, created_admin_name, created_admin_character_id, created_admin_character_name,
             updated_admin_account_id, updated_admin_name, updated_admin_character_id, updated_admin_character_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
            { subject.accountId, subject.targetName, subject.characterId, subject.characterName, body,
              admin.accountId, admin.name, admin.characterId, admin.characterName,
              admin.accountId, admin.name, admin.characterId, admin.characterName })
        noteId = insert and (insert.insertId or insert[1] and insert[1].insertId)
        if not noteId then return false end
        query([[INSERT INTO feather_admin_player_note_revisions
            (note_id, revision, body, change_type, admin_account_id, admin_name,
             admin_character_id, admin_character_name) VALUES (?, 1, ?, 'created', ?, ?, ?, ?)]],
            { noteId, body, admin.accountId, admin.name, admin.characterId, admin.characterName })
        return true
    end)
    if not executed or committed ~= true or not noteId then return result(src, false, 'player_note_create_failed') end
    AdminAudit.RecordTarget(src, 'notes.create', auditTarget(subject), ('note_id=%s'):format(noteId))
    result(src, true, 'player_note_created', noteId)
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 1400 })

FeatherAdmin.RegisterRPC('feather-admin:notes:edit', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'notes.edit') or not AdminDatabase.ready then return end
    local noteId, expectedRevision = tonumber(params.noteId), tonumber(params.revision)
    local admin, body = actor(src), clean(params.body)
    if not noteId or noteId % 1 ~= 0 or not expectedRevision or expectedRevision % 1 ~= 0 or not admin or not body then
        return result(src, false, 'invalid_player_note')
    end
    local subject
    local verified = false
    local executed, committed = pcall(MySQL.startTransaction, function(query)
        local row = (query([[SELECT id, target_account_id AS accountId, target_name AS targetName,
            target_character_id AS characterId, target_character_name AS characterName, revision
            FROM feather_admin_player_notes WHERE id = ? AND archived = 0 FOR UPDATE]], { noteId }) or {})[1]
        if not row or tonumber(row.revision) ~= expectedRevision
            or not FeatherAdmin.CanActOnAccount(src, row.accountId, 'notes.edit') then return false end
        subject = row
        local nextRevision = expectedRevision + 1
        query([[UPDATE feather_admin_player_notes SET body = ?, revision = ?, updated_admin_account_id = ?,
            updated_admin_name = ?, updated_admin_character_id = ?, updated_admin_character_name = ?
            WHERE id = ? AND revision = ? AND archived = 0]],
            { body, nextRevision, admin.accountId, admin.name, admin.characterId, admin.characterName,
              noteId, expectedRevision })
        query([[INSERT INTO feather_admin_player_note_revisions
            (note_id, revision, body, change_type, admin_account_id, admin_name,
             admin_character_id, admin_character_name) VALUES (?, ?, ?, 'edited', ?, ?, ?, ?)]],
            { noteId, nextRevision, body, admin.accountId, admin.name, admin.characterId, admin.characterName })
        verified = true
        return true
    end)
    if not executed or committed ~= true or not verified then return result(src, false, 'player_note_conflict') end
    AdminAudit.RecordTarget(src, 'notes.edit', auditTarget(subject),
        ('note_id=%s revision=%s'):format(noteId, expectedRevision + 1))
    result(src, true, 'player_note_updated', noteId)
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 1400 })

FeatherAdmin.RegisterRPC('feather-admin:notes:archive', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'notes.archive') or not AdminDatabase.ready then return end
    local noteId, admin = tonumber(params.noteId), actor(src)
    if not noteId or noteId % 1 ~= 0 or not admin then return result(src, false, 'player_note_archive_failed') end
    local row, verified
    local executed, committed = pcall(MySQL.startTransaction, function(query)
        row = (query([[SELECT target_account_id AS accountId, target_name AS targetName,
            target_character_id AS characterId, target_character_name AS characterName, body, revision
            FROM feather_admin_player_notes WHERE id = ? AND archived = 0 FOR UPDATE]], { noteId }) or {})[1]
        if not row or not FeatherAdmin.CanActOnAccount(src, row.accountId, 'notes.archive') then return false end
        local nextRevision = tonumber(row.revision) + 1
        query([[UPDATE feather_admin_player_notes SET archived = 1, revision = ?,
            updated_admin_account_id = ?, updated_admin_name = ?, updated_admin_character_id = ?,
            updated_admin_character_name = ? WHERE id = ? AND archived = 0]],
            { nextRevision, admin.accountId, admin.name, admin.characterId, admin.characterName, noteId })
        query([[INSERT INTO feather_admin_player_note_revisions
            (note_id, revision, body, change_type, admin_account_id, admin_name,
             admin_character_id, admin_character_name) VALUES (?, ?, ?, 'archived', ?, ?, ?, ?)]],
            { noteId, nextRevision, row.body, admin.accountId, admin.name,
              admin.characterId, admin.characterName })
        verified = true
        return true
    end)
    if not executed or committed ~= true or not verified then return result(src, false, 'player_note_archive_failed') end
    AdminAudit.RecordTarget(src, 'notes.archive', auditTarget(row), ('note_id=%s'):format(noteId))
    result(src, true, 'player_note_archived', noteId)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 96 })

FeatherAdmin.RegisterRPC('feather-admin:notes:history', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'notes.history') or not AdminDatabase.ready then return end
    local noteId = tonumber(params.noteId)
    local row = noteId and MySQL.single.await(
        'SELECT target_account_id AS accountId FROM feather_admin_player_notes WHERE id = ?', { noteId }) or nil
    if not row or not FeatherAdmin.CheckTargetAccountHierarchy(src, 'notes.history', row.accountId, nil) then return end
    local limit = math.max(1, math.min(tonumber(settings().historyLimit) or 20, 100))
    local rows = MySQL.query.await(([=[SELECT revision, body, change_type AS changeType,
        admin_name AS adminName, admin_character_name AS adminCharacterName,
        DATE_FORMAT(created_at, '%%m-%%d-%%Y %%h:%%i %%p') AS createdAt
        FROM feather_admin_player_note_revisions WHERE note_id = ?
        ORDER BY revision DESC LIMIT %d]=]):format(limit), { noteId }) or {}
    TriggerClientEvent('feather-admin:notes:history:result', src, noteId, rows)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 96 })
