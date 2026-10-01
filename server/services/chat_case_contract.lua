-- C7 policy primitives. Callers must derive actor identity and permission facts
-- on the server; these facts must never be accepted from a client payload.
AdminChatCaseContract = {}

local function uuid(value)
    return type(value) == 'string' and #value == 36
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

local function result(ok, code)
    return { ok = ok, code = not ok and code or nil }
end

function AdminChatCaseContract.IsUUID(value)
    return uuid(value)
end

function AdminChatCaseContract.AuthorizeCreation(targetAccountId, actor)
    if not uuid(targetAccountId) or type(actor) ~= 'table' or not uuid(actor.accountId) then
        return result(false, 'invalid_input')
    end
    if actor.sessionCurrent ~= true then return result(false, 'session_stale') end
    return result(actor.canCreate == true and actor.canView == true
        and actor.canReply == true and actor.hierarchyAllowed == true
        and targetAccountId ~= actor.accountId, 'forbidden')
end

function AdminChatCaseContract.ValidateSubmission(payload, maximumBytes)
    if type(payload) ~= 'table' or type(maximumBytes) ~= 'number'
        or maximumBytes < 1 or maximumBytes > 4096 or maximumBytes % 1 ~= 0 then
        return result(false, 'invalid_input')
    end
    for key in pairs(payload) do
        if key ~= 'conversationId' and key ~= 'submissionId' and key ~= 'text' then
            return result(false, 'invalid_input')
        end
    end
    if not uuid(payload.conversationId) or not uuid(payload.submissionId)
        or type(payload.text) ~= 'string' or #payload.text == 0
        or #payload.text > maximumBytes then return result(false, 'invalid_input') end
    return result(true)
end

function AdminChatCaseContract.Authorize(conversation, actor, operation)
    if type(conversation) ~= 'table' or type(actor) ~= 'table'
        or not uuid(conversation.targetAccountId) or not uuid(actor.accountId)
        or actor.sessionCurrent ~= true then return result(false, 'session_stale') end
    if operation ~= 'read' and operation ~= 'reply' and operation ~= 'close'
        and operation ~= 'archive' then return result(false, 'invalid_operation') end
    if conversation.status ~= 'open' and conversation.status ~= 'closed'
        and conversation.status ~= 'archived' then return result(false, 'invalid_state') end

    local player = actor.accountId == conversation.targetAccountId
    local staff = actor.canView == true and actor.hierarchyAllowed == true
        and (actor.accountId == conversation.assignedAccountId or actor.canManage == true)
    if not player and not staff then return result(false, 'forbidden') end
    if operation == 'read' then return result(true) end
    if operation == 'archive' then
        return result(staff and actor.canArchive == true and conversation.status == 'closed', 'forbidden')
    end
    if conversation.status ~= 'open' then return result(false, 'conversation_closed') end
    if operation == 'close' then return result(staff and actor.canClose == true, 'forbidden') end
    return result(player or (staff and actor.canReply == true), 'forbidden')
end

-- Persisted duplicate keys are scoped to conversation + account, never source
-- or character. A retry may replay only the exact same normalized content.
function AdminChatCaseContract.CheckReplay(stored, actorAccountId, conversationId, text)
    if not stored then return result(true) end
    if stored.accountId ~= actorAccountId or stored.conversationId ~= conversationId
        or stored.text ~= text then return result(false, 'idempotency_conflict') end
    return { ok = true, replay = true, messageId = stored.messageId }
end

function AdminChatCaseContract.Smoke()
    local target = '00000000-0000-4000-8000-000000000001'
    local assigned = '00000000-0000-4000-8000-000000000002'
    local other = '00000000-0000-4000-8000-000000000003'
    local conversation = { targetAccountId = target, assignedAccountId = assigned, status = 'open' }
    local player = { accountId = target, sessionCurrent = true }
    local staff = { accountId = assigned, sessionCurrent = true, canView = true,
        canReply = true, canClose = true, canArchive = true, hierarchyAllowed = true }
    local stranger = { accountId = other, sessionCurrent = true }
    local stored = { accountId = target, conversationId = other, text = 'Hello', messageId = assigned }
    local tests = {
        { 'target account may reply', AdminChatCaseContract.Authorize(conversation, player, 'reply').ok },
        { 'assigned staff may reply', AdminChatCaseContract.Authorize(conversation, staff, 'reply').ok },
        { 'unrelated account denied', not AdminChatCaseContract.Authorize(conversation, stranger, 'read').ok },
        { 'player cannot close', not AdminChatCaseContract.Authorize(conversation, player, 'close').ok },
        { 'assigned staff may close', AdminChatCaseContract.Authorize(conversation, staff, 'close').ok },
        { 'exact duplicate replayed', AdminChatCaseContract.CheckReplay(stored, target, other, 'Hello').replay == true },
        { 'changed duplicate rejected', not AdminChatCaseContract.CheckReplay(stored, target, other, 'Changed').ok },
        { 'cross account replay denied', not AdminChatCaseContract.CheckReplay(stored, assigned, other, 'Hello').ok },
        { 'identity spoof rejected', not AdminChatCaseContract.ValidateSubmission({ conversationId = other,
            submissionId = assigned, text = 'Hello', accountId = target }, 500).ok }
    }
    player.sessionCurrent = false
    tests[#tests + 1] = { 'stale session denied', not AdminChatCaseContract.Authorize(conversation, player, 'reply').ok }
    player.sessionCurrent = true
    staff.hierarchyAllowed = false
    tests[#tests + 1] = { 'staff hierarchy denied', not AdminChatCaseContract.Authorize(conversation, staff, 'reply').ok }
    staff.hierarchyAllowed = true
    staff.canReply = false
    tests[#tests + 1] = { 'revoked reply grant denied', not AdminChatCaseContract.Authorize(conversation, staff, 'reply').ok }
    staff.canReply = true
    staff.accountId = other
    tests[#tests + 1] = { 'unassigned staff denied', not AdminChatCaseContract.Authorize(conversation, staff, 'read').ok }
    staff.canManage = true
    tests[#tests + 1] = { 'authorized manager may read', AdminChatCaseContract.Authorize(conversation, staff, 'read').ok }
    staff.accountId, staff.canManage = assigned, false
    conversation.status = 'closed'
    tests[#tests + 1] = { 'closed history readable', AdminChatCaseContract.Authorize(conversation, player, 'read').ok }
    tests[#tests + 1] = { 'closed replies rejected', not AdminChatCaseContract.Authorize(conversation, player, 'reply').ok }
    tests[#tests + 1] = { 'closed case can archive', AdminChatCaseContract.Authorize(conversation, staff, 'archive').ok }
    conversation.status = 'archived'
    tests[#tests + 1] = { 'archived replies rejected', not AdminChatCaseContract.Authorize(conversation, staff, 'reply').ok }
    return tests
end

RegisterCommand('AdminChatCaseContractSmokeTest', function(source)
    if source ~= 0 then return end
    local passed, tests = 0, AdminChatCaseContract.Smoke()
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminChatCaseContractSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminChatCaseContractSmokeTest] done %d/%d passed (no database writes)'):format(passed, #tests))
end, true)
