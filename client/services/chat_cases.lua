AdminChatCases = { selected = nil, status = 'open', messages = {}, nextSequence = 0, hasMore = false, pending = false, unread = {} }

local function resetConversations()
    AdminChatCases.selected, AdminChatCases.draft, AdminChatCases.retry = nil, '', nil
    AdminChatCases.messages, AdminChatCases.unread = {}, {}
    AdminChatCases.status, AdminChatCases.nextSequence = 'open', 0
    AdminChatCases.pending, AdminChatCases.hasMore = false, false
    if AdminUI.currentPage == 'chat_conversation' or AdminUI.currentPage == 'chat_conversations'
        or AdminUI.currentPage == 'chat_conversation_create' then AdminUI.Close() end
    TriggerEvent('feather-chat:conversation:reset')
end
RegisterNetEvent('feather-admin:conversation:reset', resetConversations)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'feather-core' or resource == GetCurrentResourceName() then resetConversations() end
end)

AddEventHandler('feather-admin:conversation:panel-request', function(operation, payload, requestId)
    if operation ~= 'list' and operation ~= 'history' and operation ~= 'reply' then return end
    if type(payload) ~= 'table' or type(requestId) ~= 'string' or #requestId ~= 36 then return end
    payload.panelRequestId = requestId
    Feather.RPC.Notify('feather-admin:conversation:' .. operation, payload)
end)

local function submissionId()
    return ('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', function(token)
        return ('%x'):format(token == 'x' and math.random(0, 15) or math.random(8, 11))
    end)
end

function AdminChatCases.RequestList(offset)
    if not AdminUI.CanUse('menu.open') or not AdminUI.CanUse('cases.view') then return AdminUI.NotifyActionDenied() end
    Feather.RPC.Notify('feather-admin:conversation:list', { offset = offset or 0 })
end


function AdminChatCases.RequestHistory(afterSequence)
    if not AdminUI.CanUse('menu.open') or not AdminUI.CanUse('cases.view') then return AdminUI.NotifyActionDenied() end
    if not AdminChatCases.selected then return end
    Feather.RPC.Notify('feather-admin:conversation:history', {
        conversationId = AdminChatCases.selected, afterSequence = afterSequence or 0, limit = 20
    })
end

function AdminUI.OpenChatConversation()
    if not AdminUI.CanUse('menu.open') or not AdminUI.CanUse('cases.view') then return AdminUI.NotifyActionDenied() end
    local page = AdminUI.RegisterPage('chat_conversation')
    AdminUI.AddHeader(page, AdminChatTranslate('admin_header'), AdminChatTranslate('chat_case_header'))
    AdminUI.AddText(page, AdminChatTranslate('chat_case_staged'))
    if AdminChatCases.unread[AdminChatCases.selected] then
        AdminUI.AddText(page, AdminChatTranslate('chat_case_updated'))
    end
    AdminUI.AddText(page, tostring(AdminChatCases.targetName or AdminChatTranslate('chat_case_legacy_name'))
        .. '\n' .. AdminChatStatus(AdminChatCases.status))
    for _, message in ipairs(AdminChatCases.messages) do
        AdminUI.AddText(page, AdminChatTranslate(message.authorRole == 'staff' and 'chat_case_staff' or 'chat_case_player')
            .. ' - ' .. tostring(message.createdAt or '') .. '\n' .. tostring(message.text or ''))
    end
    if AdminChatCases.hasMore then
        AdminUI.AddButton(page, AdminChatTranslate('chat_case_next'), function()
            AdminChatCases.RequestHistory(AdminChatCases.nextSequence)
        end)
    end
    if AdminChatCases.status == 'open' then
        local draft = AdminChatCases.draft or ''
        AdminUI.AddInput(page, AdminChatTranslate('chat_case_reply'), AdminChatTranslate('required'), function(data)
            AdminChatCases.draft = data.value
        end, draft)
        AdminUI.AddButton(page, AdminChatTranslate('chat_case_send'), function()
            local text = AdminChatCases.draft or ''
            if text == '' or AdminChatCases.pending then return end
            -- Keep the same submission ID for retries of the same draft.
            if not AdminChatCases.retry or AdminChatCases.retry.text ~= text
                or AdminChatCases.retry.conversationId ~= AdminChatCases.selected then
                AdminChatCases.retry = { conversationId = AdminChatCases.selected,
                    submissionId = submissionId(), text = text }
            end
            AdminChatCases.pending = true
            Feather.Notify.RightNotify(AdminChatTranslate('chat_case_sending'), 2000)
            Feather.RPC.Notify('feather-admin:conversation:reply', AdminChatCases.retry)
            SetTimeout(5000, function() AdminChatCases.pending = false end)
        end)
    end
    AdminUI.AddButton(page, AdminChatTranslate('refresh'), function() AdminChatCases.RequestHistory(0) end)
    if AdminChatCases.status == 'open' and AdminUI.CanUse('cases.close') then
        AdminUI.AddButton(page, AdminChatTranslate('chat_case_close'), function()
            Feather.RPC.Notify('feather-admin:conversation:close', { conversationId = AdminChatCases.selected })
        end)
    end
    if AdminChatCases.status == 'closed' and AdminUI.CanUse('cases.manage') and Config.chatConversations.manualArchiveEnabled then
        AdminUI.AddButton(page, AdminChatTranslate('chat_case_archive'), function()
            Feather.RPC.Notify('feather-admin:conversation:archive', { conversationId = AdminChatCases.selected })
        end)
    end
    if AdminUI.CanUse('cases.link') then
        local caseId = ''
        AdminUI.AddInput(page, AdminChatTranslate('chat_case_internal_id'), AdminChatTranslate('required'), function(data) caseId = data.value end, '')
        AdminUI.AddButton(page, AdminChatTranslate('chat_case_link'), function()
            Feather.RPC.Notify('feather-admin:conversation:link', { conversationId = AdminChatCases.selected, caseId = tonumber(caseId) })
        end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminChatTranslate('back'), function() AdminChatCases.RequestList(0) end)
    AdminUI.AddFooterButton(page, AdminChatTranslate('main_menu'), AdminUI.OpenMain)
    AdminUI.OpenPage('chat_conversation')
end

function AdminUI.OpenChatConversationCreate()
    if not AdminUI.CanUse('menu.open') or not AdminUI.CanUse('cases.create') then return AdminUI.NotifyActionDenied() end
    local page = AdminUI.RegisterPage('chat_conversation_create')
    AdminUI.AddHeader(page, AdminChatTranslate('admin_header'), AdminChatTranslate('chat_case_header'))
    AdminUI.AddText(page, AdminChatTranslate('chat_case_staged'))
    local target = AdminUI.GetTarget()
    for _, player in ipairs(ClientAllPlayers or {}) do
        if player.serverId == target then
            AdminUI.AddText(page, tostring(player.characterName or AdminChatTranslate('not_available')))
            break
        end
    end
    AdminUI.AddButton(page, AdminChatTranslate('chat_case_create'), function()
        if AdminChatCases.pending then return end
        AdminChatCases.pending = true
        Feather.Notify.RightNotify(AdminChatTranslate('chat_case_creating'), 2000)
        Feather.RPC.Notify('feather-admin:conversation:create', { targetSource = target })
        SetTimeout(5000, function() AdminChatCases.pending = false end)
    end)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminChatTranslate('back'), AdminUI.OpenSelectedPlayer)
    AdminUI.OpenPage('chat_conversation_create')
end

RegisterNetEvent('feather-admin:conversation:result', function(operation, result, requestId)
    if type(result) ~= 'table' then return end
    if requestId then
        TriggerEvent('feather-chat:conversation:panel-result', operation, result, requestId)
        return
    end
    if not AdminUI.CanUse('menu.open') or not AdminUI.CanUse('cases.view') then return end
    if operation == 'create' or operation == 'reply' then AdminChatCases.pending = false end
    if not result.ok then
        return Feather.Notify.RightNotify(AdminChatTranslate('chat_case_failed') .. ' (' .. tostring(result.code or 'unknown') .. ')', 4000)
    end
    if operation == 'list' then
        local page = AdminUI.RegisterPage('chat_conversations')
        AdminUI.AddHeader(page, AdminChatTranslate('chat_case_header'), AdminChatTranslate('chat_case_list'))
        for _, row in ipairs(result.conversations or {}) do
            local id = row.conversationId
            AdminUI.AddButton(page, tostring(row.targetName or AdminChatTranslate('chat_case_legacy_name')) .. ' - ' .. AdminChatStatus(row.status), function()
                AdminChatCases.selected, AdminChatCases.draft, AdminChatCases.retry = id, '', nil
                AdminChatCases.targetName = row.targetName
                AdminChatCases.RequestHistory(0)
            end)
        end
        if result.hasMore then
            AdminUI.AddButton(page, AdminChatTranslate('chat_case_next'), function() AdminChatCases.RequestList(result.nextOffset) end)
        end
        AdminUI.AddFooter(page)
        AdminUI.AddFooterButton(page, AdminChatTranslate('main_menu'), AdminUI.OpenMain)
        AdminUI.AddFooterButton(page, AdminChatTranslate('back'), AdminUI.OpenMain)
        AdminUI.OpenPage('chat_conversations')
    elseif operation == 'create' then
        AdminChatCases.selected = result.conversationId
        AdminChatCases.targetName = result.targetName
        AdminChatCases.RequestHistory(0)
    elseif operation == 'history' then
        if result.conversationId ~= AdminChatCases.selected then return end
        AdminChatCases.unread[result.conversationId] = nil
        AdminChatCases.status, AdminChatCases.messages = result.status, result.messages or {}
        AdminChatCases.targetName = result.targetName
        AdminChatCases.nextSequence, AdminChatCases.hasMore = result.nextSequence or 0, result.hasMore == true
        AdminUI.OpenChatConversation()
    elseif operation == 'reply' then
        AdminChatCases.draft, AdminChatCases.retry = '', nil
        AdminChatCases.RequestHistory(0)
    elseif operation == 'close' or operation == 'archive' or operation == 'link' then
        AdminChatCases.RequestHistory(0)
    end
end)

RegisterNetEvent('feather-admin:conversation:updated', function(hint)
    if type(hint) ~= 'table' or type(hint.conversationId) ~= 'string' then return end
    local key = ({ create = 'chat_case_opened_notice', reply = 'chat_case_reply_notice',
        close = 'chat_case_closed_notice', archive = 'chat_case_archived_notice' })[hint.operation]
    if not key then return end
    AdminChatCases.unread[hint.conversationId] = true
    TriggerEvent('feather-chat:conversation:updated', hint)
    Feather.Notify.RightNotify(AdminChatTranslate(key), 4000)
    if AdminUI.currentPage == 'chat_conversation' and AdminChatCases.selected == hint.conversationId
        and not AdminChatCases.pending and (AdminChatCases.draft or '') == '' then
        AdminChatCases.RequestHistory(0)
    end
    -- Never open a closed menu or rebuild a menu containing an edited draft.
end)
