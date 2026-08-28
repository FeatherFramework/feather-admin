local function report(label, passed, detail)
    print(('[AdminPlayerNotesContractSmokeTest] %-28s %s%s'):format(
        label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
    return passed and 1 or 0
end

RegisterCommand('AdminPlayerNotesContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local passed, total = 0, 7
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    passed = passed + report('staff account identity', identity and type(identity.accountId) == 'string')
    passed = passed + report('staff character snapshot', identity and type(identity.characterId) == 'string')

    local tables = tonumber(MySQL.scalar.await([[SELECT COUNT(DISTINCT TABLE_NAME)
        FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME IN ('feather_admin_player_notes', 'feather_admin_player_note_revisions')]])) or 0
    passed = passed + report('note tables installed', tables == 2, ('%d/2'):format(tables))
    local columns = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND ((TABLE_NAME = 'feather_admin_player_notes' AND COLUMN_NAME IN
            ('target_account_id', 'created_admin_account_id', 'updated_admin_account_id'))
            OR (TABLE_NAME = 'feather_admin_player_note_revisions' AND COLUMN_NAME = 'admin_account_id'))
          AND DATA_TYPE = 'char' AND CHARACTER_MAXIMUM_LENGTH = 36]])) or 0
    passed = passed + report('note account schema', columns == 4, ('%d/4'):format(columns))
    local service = LoadResourceFile(GetCurrentResourceName(), 'server/services/player_notes.lua') or ''
    local accountPaths = service:find('target_account_id', 1, true)
        and service:find('created_admin_account_id', 1, true)
        and service:find('updated_admin_account_id', 1, true)
        and service:find('admin_account_id', 1, true)
        and service:find('CheckTargetAccountHierarchy', 1, true)
    passed = passed + report('account handlers installed', accountPaths ~= nil)
    local revisionPaths = service:find('FOR UPDATE', 1, true)
        and service:find('expectedRevision', 1, true)
        and service:find('player_note_conflict', 1, true)
        and service:find('player_note_revisions', 1, true)
    passed = passed + report('revision guards installed', revisionPaths ~= nil)
    passed = passed + report('numeric account rejected',
        FeatherAdmin.CanActOnAccount(target or 0, 1, 'notes.create') == false)
    print(('[AdminPlayerNotesContractSmokeTest] done %d/%d passed source=%s'):format(
        passed, total, tostring(target or 'none')))
end, true)

RegisterCommand('AdminPlayerNotesAccessInspect', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    print(('[AdminPlayerNotesAccessInspect] source=%s account=%s level=%s required=%s enabled=%s granted=%s'):format(
        tostring(target or 'none'), tostring(identity and identity.accountId or 'unavailable'),
        tostring(target and FeatherAdmin.GetRoleLevel(target) or 'unavailable'),
        tostring(Config.permissions['notes.view']), tostring(FeatherAdmin.IsActionEnabled('notes.view')),
        tostring(target and FeatherAdmin.CanUse(target, 'notes.view') == true)))
end, true)

RegisterCommand('AdminPlayerNotesPersistenceSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target then
        local players = GetPlayers()
        target = players[1] and tonumber(players[1]) or nil
    end
    local identity = target and FeatherAdmin.Identity.Resolve(target) or nil
    if not identity or not identity.characterId then
        print('[AdminPlayerNotesPersistenceSmokeTest] setup                        FAIL  -- connected Character required')
        return
    end

    local marker = ('note-contract-smoke-%s-%s'):format(target, GetGameTimer())
    local verified = {}
    local executed, committed = pcall(MySQL.startTransaction, function(query)
        query([[INSERT INTO feather_admin_player_notes
            (target_account_id, target_name, target_character_id, target_character_name, body,
             created_admin_account_id, created_admin_name, created_admin_character_id, created_admin_character_name,
             updated_admin_account_id, updated_admin_name, updated_admin_character_id, updated_admin_character_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
            { identity.accountId, identity.accountName or identity.serverName, identity.characterId,
              identity.characterName, marker, identity.accountId, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName, identity.accountId,
              identity.accountName or identity.serverName, identity.characterId, identity.characterName })
        local row = (query([[SELECT id, target_account_id, created_admin_account_id, revision
            FROM feather_admin_player_notes WHERE body = ? FOR UPDATE]], { marker }) or {})[1]
        verified.created = row and row.target_account_id == identity.accountId
            and row.created_admin_account_id == identity.accountId and tonumber(row.revision) == 1
        if not row then return false end

        query([[INSERT INTO feather_admin_player_note_revisions
            (note_id, revision, body, change_type, admin_account_id, admin_name,
             admin_character_id, admin_character_name) VALUES (?, 1, ?, 'created', ?, ?, ?, ?)]],
            { row.id, marker, identity.accountId, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName })
        local initial = (query([[SELECT admin_account_id FROM feather_admin_player_note_revisions
            WHERE note_id = ? AND revision = 1]], { row.id }) or {})[1]
        verified.initialRevision = initial and initial.admin_account_id == identity.accountId

        local editedBody = marker .. '-edited'
        query([[UPDATE feather_admin_player_notes SET body = ?, revision = 2,
            updated_admin_account_id = ? WHERE id = ? AND revision = 1]],
            { editedBody, identity.accountId, row.id })
        query([[INSERT INTO feather_admin_player_note_revisions
            (note_id, revision, body, change_type, admin_account_id, admin_name,
             admin_character_id, admin_character_name) VALUES (?, 2, ?, 'edited', ?, ?, ?, ?)]],
            { row.id, editedBody, identity.accountId, identity.accountName or identity.serverName,
              identity.characterId, identity.characterName })
        local edited = (query([[SELECT n.revision, r.body FROM feather_admin_player_notes n
            INNER JOIN feather_admin_player_note_revisions r ON r.note_id = n.id AND r.revision = n.revision
            WHERE n.id = ?]], { row.id }) or {})[1]
        verified.edited = edited and tonumber(edited.revision) == 2 and edited.body == editedBody

        query('UPDATE feather_admin_player_notes SET archived = 1 WHERE id = ?', { row.id })
        local archived = (query('SELECT archived FROM feather_admin_player_notes WHERE id = ?', { row.id }) or {})[1]
        verified.archived = archived and (archived.archived == true or tonumber(archived.archived) == 1)
        return false
    end)

    local remainingNotes = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM feather_admin_player_notes WHERE body LIKE ?', { marker .. '%' })) or -1
    local remainingRevisions = tonumber(MySQL.scalar.await([[SELECT COUNT(*)
        FROM feather_admin_player_note_revisions WHERE body LIKE ?]], { marker .. '%' })) or -1
    local function output(label, passed, detail)
        print(('[AdminPlayerNotesPersistenceSmokeTest] %-28s %s%s'):format(
            label, passed and 'PASS' or 'FAIL', detail and ('  -- ' .. detail) or ''))
        return passed and 1 or 0
    end
    local passed = 0
    passed = passed + output('transaction executed', executed == true)
    passed = passed + output('creation account snapshot', verified.created == true)
    passed = passed + output('initial immutable revision', verified.initialRevision == true)
    passed = passed + output('atomic revision update', verified.edited == true)
    passed = passed + output('archive state', verified.archived == true)
    passed = passed + output('rollback left no records', committed == false
        and remainingNotes == 0 and remainingRevisions == 0,
        ('notes=%s revisions=%s'):format(remainingNotes, remainingRevisions))
    print(('[AdminPlayerNotesPersistenceSmokeTest] done %d/6 passed source=%s'):format(passed, tostring(target)))
end, true)
