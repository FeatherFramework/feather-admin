AdminChatCaseRetention = {}

function AdminChatCaseRetention.Settings(config)
    config = type(config) == 'table' and config or {}
    local days = config.autoArchiveClosedDays
    if type(days) ~= 'number' or days % 1 ~= 0 or days < 0 or days > 3650 then days = 0 end
    local batch = config.archiveBatchLimit
    if type(batch) ~= 'number' or batch % 1 ~= 0 or batch < 1 or batch > 100 then batch = 100 end
    local minutes = config.archiveSweepMinutes
    if type(minutes) ~= 'number' or minutes % 1 ~= 0 or minutes < 1 or minutes > 1440 then minutes = 60 end
    return { days = days, batch = batch, minutes = minutes }
end

function AdminChatCaseRetention.SweepIn(tx, settings)
    if settings.days == 0 then return 0 end
    local rows = tx.query([[SELECT conversation_id AS conversationId
        FROM feather_admin_chat_conversations
        WHERE status = 'closed' AND closed_at <= TIMESTAMPADD(DAY, ?, CURRENT_TIMESTAMP)
        ORDER BY closed_at, conversation_id LIMIT ? FOR UPDATE]], -settings.days, settings.batch)
    for _, row in ipairs(rows) do
        tx.exec([[UPDATE feather_admin_chat_conversations SET status = 'archived',
            archived_at = CURRENT_TIMESTAMP WHERE conversation_id = ? AND status = 'closed']], row.conversationId)
    end
    return #rows
end

CreateThread(function()
    while true do
        local settings = AdminChatCaseRetention.Settings(Config.chatConversations)
        Wait(settings.minutes * 60000)
        if AdminDatabase.ready and settings.days > 0 then
            local ok = pcall(DB.transaction, function(tx)
                AdminChatCaseRetention.SweepIn(tx, settings)
                return true
            end)
            if not ok then print(AdminServerTranslate('chat_archive_sweep_failed')) end
        end
    end
end)

RegisterCommand('AdminChatCaseRetentionSmokeTest', function(source)
    if source ~= 0 then return end
    local tests = {
        { 'default retains history', AdminChatCaseRetention.Settings({}).days == 0 },
        { 'configured archive age accepted', AdminChatCaseRetention.Settings({ autoArchiveClosedDays = 30 }).days == 30 },
        { 'invalid archive age disabled', AdminChatCaseRetention.Settings({ autoArchiveClosedDays = -1 }).days == 0 },
        { 'fractional archive age disabled', AdminChatCaseRetention.Settings({ autoArchiveClosedDays = 1.5 }).days == 0 },
        { 'batch limit bounded', AdminChatCaseRetention.Settings({ archiveBatchLimit = 1000 }).batch == 100 },
        { 'interval bounded', AdminChatCaseRetention.Settings({ archiveSweepMinutes = 0 }).minutes == 60 },
        { 'disabled sweep performs no queries', AdminChatCaseRetention.SweepIn({}, { days = 0 }) == 0 }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminChatCaseRetentionSmokeTest] %-38s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminChatCaseRetentionSmokeTest] done %d/%d passed (no database writes)'):format(passed, #tests))
end, true)
