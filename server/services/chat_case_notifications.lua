AdminChatCaseNotifications = {}

-- Called only after a store operation returns committed success. Hints contain
-- no message body, author identity or internal case metadata. Clients re-read
-- authorized history; missing/offline recipients recover through discovery.
function AdminChatCaseNotifications.Dispatch(result, operation, id, deps)
    if type(result) ~= 'table' or result.ok ~= true or result.replay == true then return 0 end
    if operation ~= 'create' and operation ~= 'reply' and operation ~= 'close' and operation ~= 'archive' then return 0 end
    if not AdminChatCaseContract.IsUUID(id) then return 0 end
    local sent = 0
    for _, recipient in ipairs(deps.recipients(id)) do
        if (operation == 'close' or recipient.source ~= deps.initiatingSource) and deps.current(recipient) then
            deps.send(recipient.source, { conversationId = id, operation = operation })
            sent = sent + 1
        end
    end
    return sent
end

function AdminChatCaseNotifications.Notify(result, operation, id, initiatingSource)
    return AdminChatCaseNotifications.Dispatch(result, operation, id, {
        initiatingSource = initiatingSource,
        recipients = function(conversationId)
            local row = DB.one([[SELECT target_account_id AS targetAccountId,
                assigned_account_id AS assignedAccountId, status FROM feather_admin_chat_conversations
                WHERE conversation_id = ?]], conversationId)
            if not row then return {} end
            local recipients = {}
            for _, player in ipairs(GetPlayers()) do
                local source = tonumber(player)
                local identity = AdminChatCaseAdapter.SessionIdentity(source)
                if identity and (identity.accountId == row.targetAccountId or identity.accountId == row.assignedAccountId
                    or (operation == 'close' and source == initiatingSource)) then
                    local sessionId, characterId, accountId = identity.sessionId, identity.characterId, identity.accountId
                    recipients[#recipients + 1] = { source = source, sessionId = sessionId,
                        characterId = characterId, accountId = accountId, conversation = row }
                end
            end
            return recipients
        end,
        current = function(recipient)
            local actor = AdminChatCaseAdapter.Actor(recipient.source, recipient.conversation.targetAccountId, 'read')
            return actor and actor.accountId == recipient.accountId
                and AdminChatCaseContract.Authorize(recipient.conversation, actor, 'read').ok
                and exports['feather-core']:IsSessionCurrent(recipient.source, recipient.sessionId, recipient.characterId) == true
        end,
        send = function(source, hint)
            TriggerClientEvent('feather-admin:conversation:updated', source, hint)
        end
    })
end

RegisterCommand('AdminChatCaseNotificationSmokeTest', function(source)
    if source ~= 0 then return end
    local id = '00000000-0000-4000-8000-000000000001'
    local sends, hint = 0, nil
    local deps = {
        recipients = function() return { { source = 1 }, { source = 2 } } end,
        current = function(recipient) return recipient.source == 1 end,
        send = function(_, value) sends = sends + 1; hint = value end
    }
    local tests = {}
    local function check(label, passed) tests[#tests + 1] = { label, passed == true } end
    check('failed persistence sends nothing', AdminChatCaseNotifications.Dispatch({ ok = false }, 'reply', id, deps) == 0 and sends == 0)
    check('duplicate replay sends nothing', AdminChatCaseNotifications.Dispatch({ ok = true, replay = true }, 'reply', id, deps) == 0 and sends == 0)
    check('invalid conversation sends nothing', AdminChatCaseNotifications.Dispatch({ ok = true }, 'reply', 'spoof', deps) == 0 and sends == 0)
    check('unknown operation sends nothing', AdminChatCaseNotifications.Dispatch({ ok = true }, 'spoof', id, deps) == 0 and sends == 0)
    check('stale recipient skipped', AdminChatCaseNotifications.Dispatch({ ok = true }, 'reply', id, deps) == 1 and sends == 1)
    local keys = 0; for _ in pairs(hint or {}) do keys = keys + 1 end
    check('hint contains no private content', keys == 2 and hint.conversationId == id and hint.operation == 'reply')
    deps.initiatingSource = 1
    deps.current = function() return true end
    sends = 0
    check('close notifies both participants', AdminChatCaseNotifications.Dispatch({ ok = true }, 'close', id, deps) == 2 and sends == 2)
    sends = 0
    check('reply still excludes its sender', AdminChatCaseNotifications.Dispatch({ ok = true }, 'reply', id, deps) == 1 and sends == 1)
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminChatCaseNotificationSmokeTest] %-38s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminChatCaseNotificationSmokeTest] done %d/%d passed (injected delivery; no database writes)'):format(passed, #tests))
end, true)
