-- Deterministic transaction model, invoking the real store primitives.
-- This proves interleavings, NOT MariaDB lock behavior (covered separately live).
local function scenario(firstKind, secondKind, changed, stale)
    local id = '00000000-0000-4000-8000-000000000001'
    local target = '00000000-0000-4000-8000-000000000002'
    local staffId = '00000000-0000-4000-8000-000000000003'
    local submission = '00000000-0000-4000-8000-000000000004'
    local message = '00000000-0000-4000-8000-000000000005'
    local committed = { row = { conversationId = id, targetAccountId = target,
        assignedAccountId = staffId, status = 'open', lastSequence = 0 }, messages = {} }
    local owner, outcomes, waits = nil, {}, 0
    local function copy(value)
        if type(value) ~= 'table' then return value end
        local result = {}; for k, v in pairs(value) do result[k] = copy(v) end; return result
    end
    local function worker(number, kind)
        return coroutine.create(function()
            local localState
            local tx = {}
            function tx.one(sql, ...)
                local args = { ... }
                if sql:find('FOR UPDATE', 1, true) then
                    while owner and owner ~= number do
                        waits = waits + 1; coroutine.yield('waiting')
                    end
                    owner = number
                    localState = copy(committed)
                    coroutine.yield('locked')
                    return copy(localState.row)
                end
                assert(sql:find('feather_admin_chat_messages', 1, true), 'unexpected read')
                for _, stored in ipairs(localState.messages) do
                    if stored.conversationId == args[1] and stored.accountId == args[2]
                        and stored.submissionId == args[3] then return copy(stored) end
                end
            end
            function tx.exec(sql, ...)
                local args = { ... }
                if sql:find('INSERT INTO feather_admin_chat_messages', 1, true) then
                    localState.messages[#localState.messages + 1] = {
                        messageId = args[1], conversationId = args[2], accountId = args[3],
                        submissionId = args[4], sequence = args[5], text = args[6] }
                elseif sql:find('last_sequence =', 1, true) then
                    localState.row.lastSequence = args[1]
                elseif sql:find("status = 'closed'", 1, true) then
                    localState.row.status = 'closed'
                else error('unexpected write') end
                coroutine.yield('write')
            end
            local checks = 0
            local function fresh()
                checks = checks + 1
                return not (stale and number == 1 and checks > 1)
            end
            if kind == 'close' then
                outcomes[number] = AdminChatCaseStore.TransitionIn(tx, id,
                    { accountId = staffId, sessionCurrent = true, canView = true,
                        canClose = true, hierarchyAllowed = true }, 'close', fresh)
            else
                outcomes[number] = AdminChatCaseStore.AppendIn(tx,
                    { conversationId = id, submissionId = submission,
                        text = changed and number == 2 and 'Changed' or 'Hello' },
                    { accountId = target, sessionCurrent = true }, message, fresh)
            end
            if outcomes[number].ok then committed = localState end
            owner = nil
        end)
    end
    local first, second = worker(1, firstKind), worker(2, secondKind)
    local function resume(thread)
        local ok, problem = coroutine.resume(thread)
        assert(ok, problem)
    end
    -- First owns the row before second attempts it. Alternate through every
    -- query/write yield, forcing genuine overlap and a blocked second caller.
    resume(first); resume(second)
    for _ = 1, 32 do
        if coroutine.status(first) ~= 'dead' then resume(first) end
        if coroutine.status(second) ~= 'dead' then resume(second) end
        if coroutine.status(first) == 'dead' and coroutine.status(second) == 'dead' then break end
    end
    assert(coroutine.status(first) == 'dead' and coroutine.status(second) == 'dead', 'scheduler did not finish')
    assert(waits > 0, 'second transaction never overlapped first')
    return outcomes, committed
end

RegisterCommand('AdminChatCaseConcurrencySmokeTest', function(source)
    if source ~= 0 then return end
    local tests = {}
    local function check(label, passed) tests[#tests + 1] = { label, passed == true } end
    local ok, problem = pcall(function()
        local out, state = scenario('append', 'append')
        check('concurrent duplicate replayed', out[1].ok and out[2].ok and out[2].replay == true)
        check('duplicate creates one sequence', #state.messages == 1 and state.row.lastSequence == 1)
        out, state = scenario('append', 'append', true)
        check('changed concurrent retry denied', out[2].code == 'idempotency_conflict')
        check('changed retry preserves original', #state.messages == 1 and state.messages[1].text == 'Hello')
        out, state = scenario('append', 'close')
        check('append before close accepted', out[1].ok and out[2].ok)
        check('append retained after close', #state.messages == 1 and state.row.status == 'closed')
        out, state = scenario('close', 'append')
        check('close before append rejects', out[1].ok and out[2].code == 'conversation_closed')
        check('closed append writes nothing', #state.messages == 0 and state.row.lastSequence == 0)
        out, state = scenario('append', 'append', false, true)
        check('in-flight stale writer rejected', out[1].code == 'session_stale')
        check('waiting retry survives rollback', out[2].ok and not out[2].replay and #state.messages == 1 and state.row.lastSequence == 1)
        out, state = scenario('close', 'append', false, true)
        check('stale close rolled back', out[1].code == 'session_stale' and state.row.status == 'open')
        check('append after failed close allowed', out[2].ok and #state.messages == 1)
    end)
    if not ok then check('scheduler completed', false); print('[AdminChatCaseConcurrencySmokeTest] ' .. tostring(problem)) end
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminChatCaseConcurrencySmokeTest] %-36s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminChatCaseConcurrencySmokeTest] done %d/%d passed (deterministic model; no database writes)'):format(passed, #tests))
end, true)
