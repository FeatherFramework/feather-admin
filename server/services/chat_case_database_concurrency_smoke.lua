-- Uses two real transaction connections. Fixtures are committed, then deleted
-- by exact UUID. Run on a test server; stopping the resource may leave fixtures.
local running = false

RegisterCommand('AdminChatCaseDatabaseConcurrencySmokeTest', function(source)
    if source ~= 0 or running then return end
    running = true
    CreateThread(function()
        local fixtures, tests, workers = {}, {}, {}
        local function check(label, passed) tests[#tests + 1] = { label, passed == true } end
        local function fresh() return true end
        local function uuid() return DB.value('SELECT UUID()') end
        local function await(predicate)
            local deadline = GetGameTimer() + 15000
            while not predicate() and GetGameTimer() < deadline do Wait(10) end
            assert(predicate(), 'database smoke barrier timed out')
        end
        local succeeded, problem = pcall(function()
            assert(AdminDatabase.ready, 'database not ready')
            for _, mode in ipairs({ 'duplicate', 'close' }) do
                local id, target, staffId, submission, message = uuid(), uuid(), uuid(), uuid(), uuid()
                fixtures[#fixtures + 1] = id
                local staff = { accountId = staffId, sessionCurrent = true, canCreate = true,
                    canView = true, canReply = true, canClose = true, hierarchyAllowed = true }
                local actor = { accountId = target, sessionCurrent = true }
                assert(AdminChatCaseStore.Create(id, target, staff, fresh).ok, 'fixture creation failed')
                local payload = { conversationId = id, submissionId = submission, text = 'Synthetic database lock fixture' }
                local barrier = { locked = false, attempted = false, release = false }
                local first, second = { done = false }, { done = false }
                workers[#workers + 1], workers[#workers + 2] = first, second
                CreateThread(function()
                    first.success, first.committed = pcall(DB.transaction, function(tx)
                        tx.one('SELECT conversation_id FROM feather_admin_chat_conversations WHERE conversation_id = ? FOR UPDATE', id)
                        barrier.locked = true
                        -- Always release on timeout, including failure in the coordinator.
                        local deadline = GetGameTimer() + 10000
                        while not barrier.release and GetGameTimer() < deadline do Wait(10) end
                        if not barrier.release then return false end
                        first.outcome = mode == 'close'
                            and AdminChatCaseStore.TransitionIn(tx, id, staff, 'close', fresh)
                            or AdminChatCaseStore.AppendIn(tx, payload, actor, message, fresh)
                        return first.outcome.ok == true
                    end)
                    first.done = true
                end)
                await(function() return barrier.locked or first.done end)
                assert(barrier.locked, 'first transaction failed before lock')
                CreateThread(function()
                    second.success, second.committed = pcall(DB.transaction, function(tx)
                        -- Signal immediately before the real locking query; no mocked lock.
                        local wrapped = { exec = tx.exec }
                        function wrapped.one(sql, ...)
                            if sql:find('FOR UPDATE', 1, true) then barrier.attempted = true end
                            return tx.one(sql, ...)
                        end
                        second.outcome = AdminChatCaseStore.AppendIn(wrapped, payload, actor, message, fresh)
                        return second.outcome.ok == true
                    end)
                    second.done = true
                end)
                await(function() return barrier.attempted or second.done end)
                Wait(250)
                check(mode .. ' competing writer waits', barrier.attempted and not second.done)
                barrier.release = true
                await(function() return first.done and second.done end)
                check(mode .. ' first transaction commits', first.success and first.committed == true)
                if mode == 'duplicate' then
                    check('database duplicate replays', second.success and second.committed == true
                        and second.outcome.replay == true and second.outcome.messageId == message)
                    check('database duplicate one row', tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_chat_messages WHERE conversation_id = ?', id)) == 1)
                    check('database duplicate one sequence', tonumber(DB.value('SELECT last_sequence FROM feather_admin_chat_conversations WHERE conversation_id = ?', id)) == 1)
                else
                    check('database close denies waiting append', second.success and second.committed == false
                        and second.outcome.code == 'conversation_closed')
                    check('database closed append no rows', tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_chat_messages WHERE conversation_id = ?', id)) == 0)
                    check('database close state durable', DB.value('SELECT status FROM feather_admin_chat_conversations WHERE conversation_id = ?', id) == 'closed')
                end
            end
        end)
        if not succeeded then
            check('database scenarios completed', false)
            print('[AdminChatCaseDatabaseConcurrencySmokeTest] ' .. tostring(problem))
        end
        -- Let timeout-released workers finish before cleanup; never delete a
        -- fixture while a test transaction could still be operating on it.
        local settled = pcall(function()
            await(function()
                for _, worker in ipairs(workers) do if not worker.done then return false end end
                return true
            end)
        end)
        local cleaned = settled and pcall(function()
            for _, id in ipairs(fixtures) do
                assert(DB.transaction(function(tx)
                    tx.exec('DELETE FROM feather_admin_chat_messages WHERE conversation_id = ?', id)
                    tx.exec('DELETE FROM feather_admin_chat_conversations WHERE conversation_id = ?', id)
                    return true
                end))
                assert(tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_chat_conversations WHERE conversation_id = ?', id)) == 0)
                assert(tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_chat_messages WHERE conversation_id = ?', id)) == 0)
            end
        end)
        check('committed fixtures cleaned up', cleaned)
        if not cleaned then
            for _, id in ipairs(fixtures) do print('[AdminChatCaseDatabaseConcurrencySmokeTest] inspect leftover fixture conversationId=' .. id) end
        end
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[AdminChatCaseDatabaseConcurrencySmokeTest] %-40s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[AdminChatCaseDatabaseConcurrencySmokeTest] done %d/%d passed (real database; synthetic fixtures)'):format(passed, #tests))
        running = false
    end)
end, true)
