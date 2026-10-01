-- Server-only adapter. No client identity, actor flags or permissions accepted.
-- Existing case capabilities govern this bounded conversation feature.
AdminChatCaseAdapter = {}

function AdminChatCaseAdapter.SessionIdentity(source)
    local result = exports['feather-core']:GetSessionContext(source)
    return type(result) == 'table' and result.ok == true and result.value or nil
end

local function dependencies()
    return {
        resolve = AdminChatCaseAdapter.SessionIdentity,
        current = function(src, session, character)
            return exports['feather-core']:IsSessionCurrent(src, session, character)
        end,
        permitted = FeatherAdmin.CanUse,
        grants = FeatherAdmin.GetPermissions,
        hierarchy = FeatherAdmin.CanActOnAccount
    }
end

-- Injectable only for internal contract testing, never a client argument.
function AdminChatCaseAdapter.Actor(source, targetAccountId, operation, injected)
    local deps = injected or dependencies()
    if not AdminChatCaseContract.IsUUID(targetAccountId) then return nil end
    local identity = deps.resolve(source)
    if not identity or not AdminChatCaseContract.IsUUID(identity.accountId)
        or type(identity.sessionId) ~= 'string' or type(identity.characterId) ~= 'string' then return nil end
    -- Snapshot scalar identity fields; never retain a mutable provider table.
    identity = { accountId = identity.accountId, sessionId = identity.sessionId,
        characterId = identity.characterId }
    local actor = { accountId = identity.accountId }
    local action = operation == 'create' and 'cases.create'
        or operation == 'close' and 'cases.close'
        or operation == 'archive' and 'cases.manage' or 'cases.view'
    local function refresh()
        if deps.current(source, identity.sessionId, identity.characterId) ~= true then
            actor.sessionCurrent = false; return false
        end
        local latest = deps.resolve(source)
        if not latest or latest.accountId ~= identity.accountId
            or latest.sessionId ~= identity.sessionId or latest.characterId ~= identity.characterId then
            actor.sessionCurrent = false; return false
        end
        -- Target participation needs no staff catalog/profile/hierarchy reads.
        if actor.accountId == targetAccountId then
            actor.sessionCurrent = true
            return operation == 'read' or operation == 'reply'
        end
        -- One current Authority capability snapshot instead of six separate
        -- CanUse calls (each resolved profile + policy independently).
        local grants = deps.grants and deps.grants(source)
        local function permitted(action)
            if grants then return grants[action] == true end
            return deps.permitted(source, action) == true
        end
        actor.canView = permitted('cases.view')
        actor.canCreate = permitted('cases.create')
        actor.canReply = permitted('cases.claim')
        actor.canClose = permitted('cases.close')
        actor.canArchive = permitted('cases.manage')
        actor.canLink = permitted('cases.link')
        actor.canManage = actor.canArchive
        actor.hierarchyAllowed = deps.hierarchy(source, targetAccountId, action) == true
        -- Permission/hierarchy calls may yield: check the session again last.
        actor.sessionCurrent = deps.current(source, identity.sessionId, identity.characterId) == true
        if not actor.sessionCurrent then return false end
        if operation ~= 'create' and actor.accountId == targetAccountId then return true end
        return actor.canView and actor.hierarchyAllowed
            and (operation == 'create' and actor.canCreate and actor.canReply
                or operation == 'close' and actor.canClose
                or operation == 'archive' and actor.canArchive
                or operation == 'reply' and actor.canReply
                or operation == 'link' and actor.canLink
                or operation == 'read')
    end
    if not refresh() then return nil end
    return actor, refresh
end

local existing

function AdminChatCaseAdapter.Reply(source, payload)
    local validated = AdminChatCaseContract.ValidateSubmission(payload, 4096)
    if not validated.ok then return validated end
    return existing(source, payload.conversationId, 'reply', function(actor, refresh)
        local prepared = exports['feather-chat']:PrepareStaffCaseText(source, payload.conversationId, payload.text)
        if type(prepared) ~= 'table' or not prepared.ok then
            return { ok = false, code = type(prepared) == 'table' and prepared.code or 'provider_failed' }
        end
        local messageId = DB.value('SELECT UUID()')
        return AdminChatCaseStore.Append({ conversationId = payload.conversationId,
            submissionId = payload.submissionId, text = prepared.text }, actor, messageId, refresh)
    end)
end

local function run(work)
    local ok, result = pcall(work)
    if not ok then return { ok = false, code = 'provider_failed' } end
    return result
end

function AdminChatCaseAdapter.Create(source, targetSource)
    return run(function()
        if not AdminDatabase.ready then return { ok = false, code = 'unavailable' } end
        local initiating = AdminChatCaseAdapter.SessionIdentity(source)
        if not initiating then return { ok = false, code = 'session_stale' } end
        local initiatingSession, initiatingCharacter = initiating.sessionId, initiating.characterId
        local target = FeatherAdmin.ValidTarget(targetSource)
        local identity = target and AdminChatCaseAdapter.SessionIdentity(target)
        if not identity then return { ok = false, code = 'not_found' } end
        local actor, refresh = AdminChatCaseAdapter.Actor(source, identity.accountId, 'create')
        if not actor then return { ok = false, code = 'forbidden' } end
        if not exports['feather-core']:IsSessionCurrent(source, initiatingSession, initiatingCharacter) then
            return { ok = false, code = 'session_stale' }
        end
        local id = DB.value('SELECT UUID()')
        local namedIdentity = FeatherAdmin.Identity.Resolve(target)
        -- Resolve again after yielding; source reuse must never select a new account.
        local latest = AdminChatCaseAdapter.SessionIdentity(target)
        if not latest or latest.accountId ~= identity.accountId or latest.sessionId ~= identity.sessionId then
            return { ok = false, code = 'session_stale' }
        end
        if not namedIdentity or namedIdentity.sessionId ~= identity.sessionId
            or type(namedIdentity.characterName) ~= 'string' then return { ok = false, code = 'identity_unavailable' } end
        return AdminChatCaseStore.Create(id, identity.accountId, actor, refresh, namedIdentity.characterName)
    end)
end

existing = function(source, id, operation, work)
    return run(function()
        if not AdminDatabase.ready then return { ok = false, code = 'unavailable' } end
        if not AdminChatCaseContract.IsUUID(id) then return { ok = false, code = 'invalid_input' } end
        local initiating = AdminChatCaseAdapter.SessionIdentity(source)
        if not initiating then return { ok = false, code = 'session_stale' } end
        local initiatingSession, initiatingCharacter = initiating.sessionId, initiating.characterId
        local row = DB.one('SELECT target_account_id AS targetAccountId FROM feather_admin_chat_conversations WHERE conversation_id = ?', id)
        if not row then return { ok = false, code = 'not_found' } end
        local actor, refresh = AdminChatCaseAdapter.Actor(source, row.targetAccountId, operation)
        if not actor then return { ok = false, code = 'forbidden' } end
        if not exports['feather-core']:IsSessionCurrent(source, initiatingSession, initiatingCharacter) then
            return { ok = false, code = 'session_stale' }
        end
        return work(actor, refresh)
    end)
end

function AdminChatCaseAdapter.List(source, offset)
    return run(function()
        if not AdminDatabase.ready then return { ok = false, code = 'unavailable' } end
        if type(offset) ~= 'number' or offset < 0 or offset > 10000 or offset % 1 ~= 0 then
            return { ok = false, code = 'invalid_input' }
        end
        local identity = AdminChatCaseAdapter.SessionIdentity(source)
        if not identity then return { ok = false, code = 'session_stale' } end
        local accountId, sessionId, characterId = identity.accountId, identity.sessionId, identity.characterId
        local manager = FeatherAdmin.CanUse(source, 'cases.manage')
        local candidates = DB.query([[SELECT conversation_id AS conversationId,
            target_account_id AS targetAccountId, assigned_account_id AS assignedAccountId,
            status, target_character_name AS targetName FROM feather_admin_chat_conversations
            WHERE (target_account_id = ? OR assigned_account_id = ? OR ? = 1)
            ORDER BY created_at DESC, conversation_id DESC LIMIT 21 OFFSET ?]],
            accountId, accountId, manager and 1 or 0, offset)
        local more = #candidates > 20
        if more then candidates[#candidates] = nil end
        local rows = {}
        for _, row in ipairs(candidates) do
            local actor, refresh = AdminChatCaseAdapter.Actor(source, row.targetAccountId, 'read')
            if actor and AdminChatCaseContract.Authorize(row, actor, 'read').ok and refresh() then
                rows[#rows + 1] = { conversationId = row.conversationId, status = row.status, targetName = row.targetName }
            end
        end
        if not exports['feather-core']:IsSessionCurrent(source, sessionId, characterId) then
            return { ok = false, code = 'session_stale' }
        end
        return { ok = true, conversations = rows, hasMore = more, nextOffset = offset + #candidates }
    end)
end

function AdminChatCaseAdapter.History(source, id, afterSequence, limit)
    return existing(source, id, 'read', function(actor, refresh)
        return AdminChatCaseStore.History(id, actor, afterSequence, limit, refresh)
    end)
end

function AdminChatCaseAdapter.Transition(source, id, operation)
    if operation == 'archive' and Config.chatConversations.manualArchiveEnabled ~= true then
        return { ok = false, code = 'archive_disabled' }
    end
    if operation ~= 'close' and operation ~= 'archive' then return { ok = false, code = 'invalid_operation' } end
    return existing(source, id, operation, function(actor, refresh)
        return AdminChatCaseStore.Transition(id, actor, operation, refresh)
    end)
end

function AdminChatCaseAdapter.Link(source, id, caseId)
    return existing(source, id, 'link', function(actor, refresh)
        return AdminChatCaseStore.Link(id, caseId, actor, refresh)
    end)
end
