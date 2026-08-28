local function author(note)
    return note.updatedAdminCharacterName or note.updatedAdminName or AdminTranslate('not_available')
end

local function backToTarget()
    local target = AdminPlayerNotes.target or {}
    if target.serverId then
        AdminUI.SetTarget(target.serverId)
        AdminUI.OpenSelectedPlayer()
    elseif AdminPlayerDirectory.selected then
        AdminUI.OpenOfflinePlayer(AdminPlayerDirectory.selected)
    else
        AdminUI.OpenPlayers()
    end
end

function AdminUI.OpenPlayerNotes()
    if not AdminUI.CanUse('notes.view') then return AdminUI.NotifyActionDenied() end
    local target = AdminPlayerNotes.target or {}
    local page = AdminUI.RegisterPage('player_notes')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_notes'))
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('player'),
        tostring(target.characterName or target.targetName or AdminTranslate('not_available'))))
    if AdminUI.CanUse('notes.create') then
        AdminUI.AddInput(page, AdminTranslate('player_note'), AdminTranslate('player_note_placeholder'), function(data)
            AdminPlayerNotes.draft = data.value
        end, AdminPlayerNotes.draft)
        AdminUI.AddButton(page, AdminTranslate('add_player_note'), function()
            AdminPlayerNotes.Create(AdminPlayerNotes.draft)
        end)
    end
    AdminUI.AddLine(page)
    if #AdminPlayerNotes.rows == 0 then
        AdminUI.AddText(page, AdminTranslate('no_player_notes'))
    else
        for _, entry in ipairs(AdminPlayerNotes.rows) do
            local note = entry
            AdminUI.AddButton(page, ('#%s - %s'):format(note.id, note.body), function()
                AdminPlayerNotes.selected = note
                AdminPlayerNotes.draft = note.body
                AdminUI.OpenPlayerNoteDetails()
            end)
        end
    end
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('page'), AdminPlayerNotes.page))
    if AdminPlayerNotes.page > 1 then
        AdminUI.AddButton(page, AdminTranslate('previous_page'), function()
            AdminPlayerNotes.Request(AdminPlayerNotes.page - 1)
        end)
    end
    if AdminPlayerNotes.hasNext then
        AdminUI.AddButton(page, AdminTranslate('next_page'), function()
            AdminPlayerNotes.Request(AdminPlayerNotes.page + 1)
        end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), backToTarget)
    AdminUI.OpenPage('player_notes')
end

function AdminUI.OpenPlayerNoteDetails()
    local note = AdminPlayerNotes.selected
    if not note then return end
    local page = AdminUI.RegisterPage('player_note_details')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_note_details'))
    AdminUI.AddText(page, table.concat({
        ('%s: #%s'):format(AdminTranslate('player_note_id'), note.id),
        ('%s: %s'):format(AdminTranslate('player_note'), note.body),
        ('%s: %s'):format(AdminTranslate('revision'), note.revision),
        ('%s: %s'):format(AdminTranslate('updated_by'), author(note)),
        ('%s: %s'):format(AdminTranslate('updated_at'), note.updatedAt or note.createdAt)
    }, '\n'))
    if AdminUI.CanUse('notes.edit') then
        AdminUI.AddInput(page, AdminTranslate('edit_player_note'), AdminTranslate('player_note_placeholder'), function(data)
            AdminPlayerNotes.draft = data.value
        end, AdminPlayerNotes.draft)
        AdminUI.AddButton(page, AdminTranslate('save_player_note'), function()
            AdminPlayerNotes.Edit(note.id, note.revision, AdminPlayerNotes.draft)
        end)
    end
    if AdminUI.CanUse('notes.history') then
        AdminUI.AddButton(page, AdminTranslate('player_note_history'), function()
            AdminPlayerNotes.RequestHistory(note.id)
        end)
    end
    if AdminUI.CanUse('notes.archive') then
        AdminUI.AddButton(page, AdminTranslate('archive_player_note'), AdminUI.OpenPlayerNoteArchiveConfirmation,
            AdminUI.Styles.button)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPlayerNotes)
    AdminUI.OpenPage('player_note_details')
end

function AdminUI.OpenPlayerNoteHistory()
    local note = AdminPlayerNotes.selected
    if not note then return end
    local page = AdminUI.RegisterPage('player_note_history')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_note_history'))
    for _, revision in ipairs(AdminPlayerNotes.history) do
        AdminUI.AddText(page, table.concat({
            ('%s: %s'):format(AdminTranslate('revision'), revision.revision),
            ('%s: %s'):format(AdminTranslate('change_type'), revision.changeType),
            ('%s: %s'):format(AdminTranslate('player_note'), revision.body),
            ('%s: %s'):format(AdminTranslate('updated_by'),
                revision.adminCharacterName or revision.adminName or AdminTranslate('not_available')),
            ('%s: %s'):format(AdminTranslate('updated_at'), revision.createdAt)
        }, '\n'))
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPlayerNoteDetails)
    AdminUI.OpenPage('player_note_history')
end

function AdminUI.OpenPlayerNoteArchiveConfirmation()
    local note = AdminPlayerNotes.selected
    if not note then return end
    local page = AdminUI.RegisterPage('player_note_archive_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_archive_player_note'))
    AdminUI.AddText(page, note.body)
    AdminUI.AddButton(page, AdminTranslate('confirm_archive'), function()
        AdminPlayerNotes.Archive(note.id)
    end, AdminUI.Styles.button)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPlayerNoteDetails)
    AdminUI.OpenPage('player_note_archive_confirmation')
end

AdminUI.RegisterNavigationItem('moderation_center', {
    key = 'player_notes', labelKey = 'player_notes', order = 40,
    permission = 'notes.view', open = AdminUI.OpenPlayers
})
