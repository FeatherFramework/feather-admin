AdminPlayerNotes = {
    target = nil,
    rows = {},
    page = 1,
    hasNext = false,
    selected = nil,
    history = {},
    draft = ''
}

local function payload(extra)
    local target = AdminPlayerNotes.target or {}
    local data = { serverId = target.serverId, accountId = target.accountId,
        characterId = target.characterId }
    for key, value in pairs(extra or {}) do data[key] = value end
    return data
end

function AdminPlayerNotes.OpenTarget(target)
    if not AdminUI.CanUse('notes.view') then return AdminUI.NotifyActionDenied() end
    AdminPlayerNotes.target = type(target) == 'table' and target or nil
    AdminPlayerNotes.page, AdminPlayerNotes.selected, AdminPlayerNotes.draft = 1, nil, ''
    Feather.RPC.Notify('feather-admin:notes:list', payload({ page = 1 }))
end

function AdminPlayerNotes.OpenOnline(serverId)
    AdminPlayerNotes.OpenTarget({ serverId = serverId })
end

function AdminPlayerNotes.Request(page)
    AdminPlayerNotes.page = math.max(1, math.floor(tonumber(page) or 1))
    Feather.RPC.Notify('feather-admin:notes:list', payload({ page = AdminPlayerNotes.page }))
end

function AdminPlayerNotes.Create(body)
    Feather.RPC.Notify('feather-admin:notes:create', payload({ body = body }))
end

function AdminPlayerNotes.Edit(noteId, revision, body)
    Feather.RPC.Notify('feather-admin:notes:edit', { noteId = noteId, revision = revision, body = body })
end

function AdminPlayerNotes.Archive(noteId)
    Feather.RPC.Notify('feather-admin:notes:archive', { noteId = noteId })
end

function AdminPlayerNotes.RequestHistory(noteId)
    Feather.RPC.Notify('feather-admin:notes:history', { noteId = noteId })
end

RegisterNetEvent('feather-admin:notes:list:result', function(target, rows, page, hasNext)
    AdminPlayerNotes.target = type(target) == 'table' and target or AdminPlayerNotes.target
    AdminPlayerNotes.rows = type(rows) == 'table' and rows or {}
    AdminPlayerNotes.page = tonumber(page) or 1
    AdminPlayerNotes.hasNext = hasNext == true
    AdminUI.OpenPlayerNotes()
end)

RegisterNetEvent('feather-admin:notes:history:result', function(noteId, rows)
    if not AdminPlayerNotes.selected or tonumber(AdminPlayerNotes.selected.id) ~= tonumber(noteId) then return end
    AdminPlayerNotes.history = type(rows) == 'table' and rows or {}
    AdminUI.OpenPlayerNoteHistory()
end)

RegisterNetEvent('feather-admin:notes:action:result', function(succeeded, messageKey, noteId)
    Feather.Notify.RightNotify(AdminTranslate(messageKey or 'player_note_action_failed'), 3500)
    if succeeded ~= true then return end
    AdminPlayerNotes.selected, AdminPlayerNotes.draft = nil, ''
    AdminPlayerNotes.Request(AdminPlayerNotes.page)
end)
