RegisterCommand('AdminChatCaseStoreSmokeTest', function(source)
    if source ~= 0 then return end
    CreateThread(function()
        if not AdminDatabase.ready then
            print('[AdminChatCaseStoreSmokeTest] FAIL database not ready'); return
        end
        local id = DB.value('SELECT UUID()')
        local target = DB.value('SELECT UUID()')
        local staffId = DB.value('SELECT UUID()')
        local submission = DB.value('SELECT UUID()')
        local message = DB.value('SELECT UUID()')
        local tests = {}
        local function check(label, passed) tests[#tests + 1] = { label, passed == true } end
        local succeeded, committed = pcall(DB.transaction, function(tx)
            tests = {} -- Whole callbacks may be retried by feather-mysql.
            local actor = { accountId = target, sessionCurrent = true }
            local staff = { accountId = staffId, sessionCurrent = true, canView = true,
                canCreate = true, canReply = true, canClose = true, canArchive = true, canLink = true, hierarchyAllowed = true }
            local payload = { conversationId = id, submissionId = submission, text = 'Rollback fixture' }
            local function fresh() return true end
            check('player initiation rejected', not AdminChatCaseStore.CreateIn(tx, id, staffId, actor, fresh).ok)
            check('staff initiation accepted', AdminChatCaseStore.CreateIn(tx, id, target, staff, fresh, 'Smoke Target').ok)
            check('oversized snapshot name rejected', AdminChatCaseStore.CreateIn(tx, id, target, staff, fresh, string.rep('X', 151)).code == 'invalid_input')
            local caseId = tonumber(tx.insert([[INSERT INTO feather_admin_cases
                (target_account_id, target_license, title, summary, created_admin_account_id, assigned_admin_account_id)
                VALUES (?, 'smoke', 'Rollback case', 'Internal content must not leak', ?, ?)]], target, staffId, staffId))
            check('player case linking rejected', not AdminChatCaseStore.LinkIn(tx, id, caseId, actor, fresh).ok)
            check('assigned staff case linked', AdminChatCaseStore.LinkIn(tx, id, caseId, staff, fresh).ok)
            check('same case link replayed', AdminChatCaseStore.LinkIn(tx, id, caseId, staff, fresh).replay == true)
            check('link persisted once', tonumber(tx.value('SELECT COUNT(*) FROM feather_admin_chat_case_links WHERE conversation_id = ?', id)) == 1)
            tx.exec('UPDATE feather_admin_cases SET target_account_id = ? WHERE id = ?', submission, caseId)
            check('mismatched account link denied', AdminChatCaseStore.LinkIn(tx, id, caseId, staff, fresh).code == 'target_mismatch')
            tx.exec('UPDATE feather_admin_cases SET target_account_id = ? WHERE id = ?', target, caseId)
            local first = AdminChatCaseStore.AppendIn(tx, payload, actor, message, fresh)
            check('append sequence allocated', first.ok and first.sequence == 1)
            local replay = AdminChatCaseStore.AppendIn(tx, payload, actor, message, fresh)
            check('duplicate replays same row', replay.ok and replay.replay and replay.messageId == message)
            payload.text = 'Changed'
            check('changed duplicate rejected', AdminChatCaseStore.AppendIn(tx, payload, actor, message, fresh).code == 'idempotency_conflict')
            payload.text, payload.submissionId = 'Stale', tx.value('SELECT UUID()')
            check('stale session rejected', AdminChatCaseStore.AppendIn(tx, payload, actor,
                tx.value('SELECT UUID()'), function() return false end).code == 'session_stale')
            check('one message persisted', tonumber(tx.value('SELECT COUNT(*) FROM feather_admin_chat_messages WHERE conversation_id = ?', id)) == 1)
            local history = AdminChatCaseStore.HistoryIn(tx, id, actor, 0, 1, fresh)
            check('target history readable', history.ok and #history.messages == 1 and history.messages[1].text == 'Rollback fixture')
            check('target name snapshot persisted', history.ok and history.targetName == 'Smoke Target')
            check('history projection private', history.ok and history.messages[1].accountId == nil
                and history.messages[1].authorAccountId == nil and history.assignedAccountId == nil)
            local unrelated = { accountId = submission, sessionCurrent = true }
            check('unrelated history denied', AdminChatCaseStore.HistoryIn(tx, id, unrelated, 0, 1, fresh).code == 'forbidden')
            check('pagination cursor bounded', AdminChatCaseStore.HistoryIn(tx, id, actor, -1, 1, fresh).code == 'invalid_input')
            check('pagination end empty', #AdminChatCaseStore.HistoryIn(tx, id, actor, 1, 1, fresh).messages == 0)
            local reads = 0
            check('history in-flight stale denied', AdminChatCaseStore.HistoryIn(tx, id, actor, 0, 1, function()
                reads = reads + 1; return reads == 1
            end).code == 'session_stale')
            local second = AdminChatCaseStore.AppendIn(tx, { conversationId = id,
                submissionId = tx.value('SELECT UUID()'), text = 'Second page fixture' },
                staff, tx.value('SELECT UUID()'), fresh)
            check('second author sequence allocated', second.ok and second.sequence == 2)
            local firstPage = AdminChatCaseStore.HistoryIn(tx, id, actor, 0, 1, fresh)
            check('bounded first page reports more', firstPage.ok and #firstPage.messages == 1
                and firstPage.hasMore and firstPage.nextSequence == 1)
            local secondPage = AdminChatCaseStore.HistoryIn(tx, id, actor, firstPage.nextSequence, 1, fresh)
            check('next page excludes prior messages', secondPage.ok and #secondPage.messages == 1
                and secondPage.messages[1].sequence == 2 and not secondPage.hasMore)
            check('staff author label projected', secondPage.ok and secondPage.messages[1].authorRole == 'staff')
            check('linked internal case stays private', firstPage.caseId == nil and firstPage.summary == nil
                and firstPage.messages[1].summary == nil and firstPage.messages[1].caseId == nil)
            check('player close rejected', not AdminChatCaseStore.TransitionIn(tx, id, actor, 'close', fresh).ok)
            check('staff close persisted', AdminChatCaseStore.TransitionIn(tx, id, staff, 'close', fresh).ok)
            check('closed history readable', AdminChatCaseStore.HistoryIn(tx, id, actor, 0, 10, fresh).ok)
            check('closed append rejected', AdminChatCaseStore.AppendIn(tx, payload, actor,
                tx.value('SELECT UUID()'), fresh).code == 'conversation_closed')
            check('closed conversation archived', AdminChatCaseStore.TransitionIn(tx, id, staff, 'archive', fresh).ok)
            check('archive state persisted', tx.value('SELECT status FROM feather_admin_chat_conversations WHERE conversation_id = ?', id) == 'archived')
            tx.exec([[UPDATE feather_admin_chat_conversations SET status = 'closed',
                closed_at = TIMESTAMPADD(DAY, -60, CURRENT_TIMESTAMP) WHERE conversation_id = ?]], id)
            -- Restrict the real sweep SQL to this rollback fixture so the smoke
            -- never locks or changes unrelated conversations, even temporarily.
            local scoped = { exec = tx.exec }
            function scoped.query(sql, ...)
                local args = { ... }
                sql = sql:gsub("WHERE status = 'closed'", "WHERE conversation_id = ? AND status = 'closed'")
                return tx.query(sql, id, table.unpack(args))
            end
            check('aged closed conversation swept', AdminChatCaseRetention.SweepIn(scoped, { days = 30, batch = 1 }) == 1)
            check('sweep archive state persisted', tx.value('SELECT status FROM feather_admin_chat_conversations WHERE conversation_id = ?', id) == 'archived')
            check('sweep preserves message history', tonumber(tx.value('SELECT COUNT(*) FROM feather_admin_chat_messages WHERE conversation_id = ?', id)) == 2)
            return false -- No fixture or message survives this smoke.
        end)
        check('transaction rolled back', succeeded and committed == false)
        check('conversation fixture absent', tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_chat_conversations WHERE conversation_id = ?', id)) == 0)
        check('message fixture absent', tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_chat_messages WHERE conversation_id = ?', id)) == 0)
        check('case link fixture absent', tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_chat_case_links WHERE conversation_id = ?', id)) == 0)
        check('internal case fixture absent', tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_cases WHERE created_admin_account_id = ?', staffId)) == 0)
        -- Actual post-write invalidation must make the transaction wrapper roll back.
        -- The fixture creation is in the same transaction, so no committed cleanup is needed.
        local late, lateCommitted = pcall(DB.transaction, function(tx)
            local staff = { accountId = staffId, sessionCurrent = true, canCreate = true,
                canView = true, canReply = true, hierarchyAllowed = true }
            assert(AdminChatCaseStore.CreateIn(tx, id, target, staff, function() return true end).ok)
            local checks = 0
            local outcome = AdminChatCaseStore.AppendIn(tx,
                { conversationId = id, submissionId = submission, text = 'Late stale fixture' },
                { accountId = target, sessionCurrent = true }, message, function()
                    checks = checks + 1; return checks == 1
                end)
            assert(outcome.code == 'session_stale', 'post-write session invalidation was not rejected')
            return outcome.ok == true
        end)
        check('post-write stale rolled back', late and lateCommitted == false)
        check('post-write stale message absent', tonumber(DB.value('SELECT COUNT(*) FROM feather_admin_chat_messages WHERE conversation_id = ?', id)) == 0)
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[AdminChatCaseStoreSmokeTest] %-30s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        if not succeeded then print('[AdminChatCaseStoreSmokeTest] database operation failed; inspect feather-mysql diagnostics') end
        print(('[AdminChatCaseStoreSmokeTest] done %d/%d passed (rollback-only; no connected players required)'):format(passed, #tests))
    end)
end, true)
