local function valid(params, fields)
    if type(params) ~= 'table' then return false end
    for key in pairs(params) do if not fields[key] then return false end end
    return true
end

local function route(name, fields, work, maximum)
    FeatherAdmin.RegisterRPC('feather-admin:conversation:' .. name, function(params, _, src)
        local started = GetGameTimer()
        local identity = AdminChatCaseAdapter.SessionIdentity(src)
        if not identity or not identity.sessionId or not identity.characterId then return end
        local requestId = params.panelRequestId
        if requestId ~= nil and not AdminChatCaseContract.IsUUID(requestId) then return end
        local payload = {}
        for key, value in pairs(params) do if key ~= 'panelRequestId' then payload[key] = value end end
        local result = { ok = false, code = 'invalid_input' }
        if not requestId and not FeatherAdmin.CanUse(src, 'menu.open') then
            result = { ok = false, code = 'forbidden' }
        elseif valid(payload, fields) then result = work(src, payload) end
        -- Never send a response to a reused source/new character session.
        if exports['feather-core']:IsSessionCurrent(src, identity.sessionId, identity.characterId) then
            TriggerClientEvent('feather-admin:conversation:result', src, name, result, requestId)
        end
        local elapsed = GetGameTimer() - started
        if elapsed > 1000 then
            print(('[feather-admin] conversation operation slow operation=%s durationMs=%d'):format(name, elapsed))
        end
        if result.ok and (name == 'create' or name == 'reply' or name == 'close' or name == 'archive') then
            local delivered = pcall(AdminChatCaseNotifications.Notify, result, name,
                name == 'create' and result.conversationId or params.conversationId, src)
            if not delivered then
                -- A failed hint cannot undo the committed operation; history is authoritative.
                print('[feather-admin] conversation update hint failed; recover using /staffchat')
            end
        end
    end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = maximum })
end

route('create', { targetSource = true }, function(src, params)
    if type(params.targetSource) ~= 'number' or params.targetSource < 1
        or params.targetSource % 1 ~= 0 then return { ok = false, code = 'invalid_input' } end
    return AdminChatCaseAdapter.Create(src, params.targetSource)
end, 128)

route('history', { conversationId = true, afterSequence = true, limit = true }, function(src, params)
    return AdminChatCaseAdapter.History(src, params.conversationId, params.afterSequence, params.limit)
end, 256)

route('close', { conversationId = true }, function(src, params)
    return AdminChatCaseAdapter.Transition(src, params.conversationId, 'close')
end, 128)

route('archive', { conversationId = true }, function(src, params)
    return AdminChatCaseAdapter.Transition(src, params.conversationId, 'archive')
end, 128)

route('list', { offset = true }, function(src, params)
    return AdminChatCaseAdapter.List(src, params.offset)
end, 128)

route('reply', { conversationId = true, submissionId = true, text = true }, function(src, params)
    return AdminChatCaseAdapter.Reply(src, params)
end, 4608)

route('link', { conversationId = true, caseId = true }, function(src, params)
    return AdminChatCaseAdapter.Link(src, params.conversationId, params.caseId)
end, 256)
