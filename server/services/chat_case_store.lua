-- Internal persistence primitives only: no client RPC or public export.
-- The future adapter must derive actor permissions and normalize text server-side.
AdminChatCaseStore = {}

local function lock(tx, id)
    return tx.one([[SELECT conversation_id AS conversationId,
        target_account_id AS targetAccountId, assigned_account_id AS assignedAccountId,
        status, target_character_name AS targetName, last_sequence AS lastSequence FROM feather_admin_chat_conversations
        WHERE conversation_id = ? FOR UPDATE]], id)
end

local function current(actor, revalidate)
    return type(actor) == 'table' and actor.sessionCurrent == true and type(revalidate) == 'function'
        and revalidate() == true
end

function AdminChatCaseStore.CreateIn(tx, id, targetAccountId, actor, revalidate, targetName)
    if not AdminChatCaseContract.IsUUID(id) then return { ok = false, code = 'invalid_input' } end
    local allowed = AdminChatCaseContract.AuthorizeCreation(targetAccountId, actor)
    if not allowed.ok then return allowed end
    if targetName ~= nil and (type(targetName) ~= 'string' or #targetName > 150) then
        return { ok = false, code = 'invalid_input' }
    end
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    tx.exec([[INSERT INTO feather_admin_chat_conversations
        (conversation_id, target_account_id, assigned_account_id, target_character_name) VALUES (?, ?, ?, ?)]],
        id, targetAccountId, actor.accountId, targetName)
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    return { ok = true, conversationId = id, targetName = targetName }
end

-- Explicit projection excludes internal cases, staff notes and moderation audit.
-- Ascending keyset pagination is bounded; revalidate after every yielding read.
function AdminChatCaseStore.HistoryIn(tx, id, actor, afterSequence, limit, revalidate)
    if not AdminChatCaseContract.IsUUID(id) or type(afterSequence) ~= 'number'
        or afterSequence < 0 or afterSequence > 9007199254740991 or afterSequence % 1 ~= 0
        or type(limit) ~= 'number' or limit < 1 or limit > 100 or limit % 1 ~= 0 then
        return { ok = false, code = 'invalid_input' }
    end
    local row = lock(tx, id)
    if not row then return { ok = false, code = 'not_found' } end
    local allowed = AdminChatCaseContract.Authorize(row, actor, 'read')
    if not allowed.ok then return allowed end
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    local rows = tx.query([[SELECT m.message_id AS messageId, m.sequence, m.body AS text,
        CASE WHEN m.author_account_id = c.target_account_id THEN 'player' ELSE 'staff' END AS authorRole,
        DATE_FORMAT(m.created_at, '%Y-%m-%dT%H:%i:%s') AS createdAt
        FROM feather_admin_chat_messages m JOIN feather_admin_chat_conversations c
        ON c.conversation_id = m.conversation_id
        WHERE m.conversation_id = ? AND m.sequence > ?
        ORDER BY m.sequence ASC LIMIT ?]], id, afterSequence, limit + 1)
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    local more = #rows > limit
    if more then rows[#rows] = nil end
    for _, message in ipairs(rows) do message.sequence = tonumber(message.sequence) end
    return { ok = true, conversationId = id, targetName = row.targetName, status = row.status, messages = rows,
        hasMore = more, nextSequence = #rows > 0 and rows[#rows].sequence or afterSequence }
end

function AdminChatCaseStore.AppendIn(tx, payload, actor, messageId, revalidate)
    local valid = AdminChatCaseContract.ValidateSubmission(payload, 4096)
    if not valid.ok then return valid end
    -- Validate server-generated IDs through the same UUID contract.
    if not AdminChatCaseContract.ValidateSubmission({ conversationId = payload.conversationId,
        submissionId = messageId, text = 'id' }, 4096).ok then
        return { ok = false, code = 'invalid_input' }
    end
    local row = lock(tx, payload.conversationId)
    if not row then return { ok = false, code = 'not_found' } end
    local allowed = AdminChatCaseContract.Authorize(row, actor, 'reply')
    if not allowed.ok then return allowed end
    local stored = tx.one([[SELECT message_id AS messageId, author_account_id AS accountId,
        conversation_id AS conversationId, body AS text, sequence
        FROM feather_admin_chat_messages WHERE conversation_id = ?
        AND author_account_id = ? AND submission_id = ?]],
        payload.conversationId, actor.accountId, payload.submissionId)
    local replay = AdminChatCaseContract.CheckReplay(stored, actor.accountId,
        payload.conversationId, payload.text)
    if not replay.ok then return replay end
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    if replay.replay then replay.sequence = tonumber(stored.sequence); return replay end
    local sequence = tonumber(row.lastSequence) + 1
    tx.exec([[INSERT INTO feather_admin_chat_messages
        (message_id, conversation_id, author_account_id, submission_id, sequence, body)
        VALUES (?, ?, ?, ?, ?, ?)]], messageId, payload.conversationId,
        actor.accountId, payload.submissionId, sequence, payload.text)
    tx.exec([[UPDATE feather_admin_chat_conversations SET last_sequence = ?
        WHERE conversation_id = ?]], sequence, payload.conversationId)
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    return { ok = true, messageId = messageId, sequence = sequence, replay = false }
end

function AdminChatCaseStore.TransitionIn(tx, id, actor, operation, revalidate)
    if operation ~= 'close' and operation ~= 'archive' then
        return { ok = false, code = 'invalid_operation' }
    end
    local row = lock(tx, id)
    if not row then return { ok = false, code = 'not_found' } end
    local allowed = AdminChatCaseContract.Authorize(row, actor, operation)
    if not allowed.ok then return allowed end
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    if operation == 'close' then
        tx.exec([[UPDATE feather_admin_chat_conversations SET status = 'closed',
            closed_by_account_id = ?, closed_at = CURRENT_TIMESTAMP WHERE conversation_id = ?]], actor.accountId, id)
    else
        tx.exec([[UPDATE feather_admin_chat_conversations SET status = 'archived',
            archived_at = CURRENT_TIMESTAMP WHERE conversation_id = ?]], id)
    end
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    return { ok = true }
end

-- Internal injection seam for fail-closed transaction-boundary tests. Never
-- exposed as an RPC/export and never replaces shared DB functions in a smoke.
function AdminChatCaseStore.RunTransaction(work, deps)
    if not deps.ready then return { ok = false, code = 'unavailable' } end
    local outcome
    local succeeded, committed = pcall(deps.transaction, function(tx)
        outcome = work(tx)
        return outcome.ok == true
    end)
    -- A success is never exposed before the transaction has committed.
    if not succeeded or (outcome and outcome.ok and committed ~= true) then
        return { ok = false, code = 'persistence_failed' }
    end
    return outcome or { ok = false, code = 'persistence_failed' }
end

local function transaction(work)
    return AdminChatCaseStore.RunTransaction(work, { ready = AdminDatabase.ready, transaction = DB.transaction })
end

function AdminChatCaseStore.Append(payload, actor, messageId, revalidate)
    return transaction(function(tx)
        return AdminChatCaseStore.AppendIn(tx, payload, actor, messageId, revalidate)
    end)
end

function AdminChatCaseStore.Transition(id, actor, operation, revalidate)
    return transaction(function(tx)
        return AdminChatCaseStore.TransitionIn(tx, id, actor, operation, revalidate)
    end)
end

function AdminChatCaseStore.Create(id, targetAccountId, actor, revalidate, targetName)
    return transaction(function(tx)
        return AdminChatCaseStore.CreateIn(tx, id, targetAccountId, actor, revalidate, targetName)
    end)
end

function AdminChatCaseStore.History(id, actor, afterSequence, limit, revalidate)
    return transaction(function(tx)
        return AdminChatCaseStore.HistoryIn(tx, id, actor, afterSequence, limit, revalidate)
    end)
end

function AdminChatCaseStore.LinkIn(tx, id, caseId, actor, revalidate)
    if not AdminChatCaseContract.IsUUID(id) or type(caseId) ~= 'number'
        or caseId < 1 or caseId > 9007199254740991 or caseId % 1 ~= 0 then
        return { ok = false, code = 'invalid_input' }
    end
    local conversation = lock(tx, id)
    if not conversation then return { ok = false, code = 'not_found' } end
    local allowed = AdminChatCaseContract.Authorize(conversation, actor, 'read')
    if not allowed.ok then return allowed end
    if actor.accountId == conversation.targetAccountId or actor.canLink ~= true then
        return { ok = false, code = 'forbidden' }
    end
    local case = tx.one([[SELECT target_account_id AS targetAccountId,
        assigned_admin_account_id AS assignedAccountId, status FROM feather_admin_cases
        WHERE id = ? FOR UPDATE]], caseId)
    if not case then return { ok = false, code = 'not_found' } end
    if case.targetAccountId ~= conversation.targetAccountId then return { ok = false, code = 'target_mismatch' } end
    if case.assignedAccountId ~= actor.accountId and not actor.canManage then
        return { ok = false, code = 'forbidden' }
    end
    local linked = tx.one('SELECT case_id AS caseId FROM feather_admin_chat_case_links WHERE conversation_id = ?', id)
    if linked and tonumber(linked.caseId) ~= caseId then return { ok = false, code = 'link_conflict' } end
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    if actor.canLink ~= true or (case.assignedAccountId ~= actor.accountId and not actor.canManage) then
        return { ok = false, code = 'forbidden' }
    end
    if not linked then
        tx.exec([[INSERT INTO feather_admin_chat_case_links
            (conversation_id, case_id, linked_by_account_id) VALUES (?, ?, ?)]], id, caseId, actor.accountId)
    end
    if not current(actor, revalidate) then return { ok = false, code = 'session_stale' } end
    if actor.canLink ~= true or (case.assignedAccountId ~= actor.accountId and not actor.canManage) then
        return { ok = false, code = 'forbidden' }
    end
    return { ok = true, replay = linked ~= nil }
end

function AdminChatCaseStore.Link(id, caseId, actor, revalidate)
    return transaction(function(tx) return AdminChatCaseStore.LinkIn(tx, id, caseId, actor, revalidate) end)
end
