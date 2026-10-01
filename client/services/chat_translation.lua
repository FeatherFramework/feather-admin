-- Chat-only helper: standard Feather locale lookup, with English fallback for
-- partially translated player languages. Message bodies/names/reasons are data.
function AdminChatTranslate(key, variables, translator)
    local ok, text = pcall(translator or Feather.Locale.translate, 0, key)
    if not ok or type(text) ~= 'string' or text == ''
        or text:match('^Translation %[') or text:match('^Locale %[') then
        text = AdminEnglishTranslations[key] or key
    end
    return text:gsub('{([%w_]+)}', function(name)
        local value = variables and variables[name]
        return value ~= nil and tostring(value) or ('{' .. name .. '}')
    end)
end

function AdminChatStatus(status)
    local key = ({ open='chat_case_status_open', closed='chat_case_status_closed',
        archived='chat_case_status_archived' })[status] or 'chat_case_status_unknown'
    return AdminChatTranslate(key)
end

function AdminChatOption(option)
    return option.translationKey and AdminChatTranslate(option.translationKey)
        or option.label
end

function AdminChatScope(scopeType, scopeKey, fallback)
    for _, option in ipairs(Config.moderation.chatMuteScopes or {}) do
        if option.scopeType == scopeType and option.scopeKey == scopeKey then
            return AdminChatOption(option)
        end
    end
    local key = ({ all='chat_scope_all', ooc='chat_scope_ooc', channel='chat_scope_channel' })[scopeType]
    return fallback or AdminChatTranslate(key or 'chat_scope_default')
end

function AdminChatDuration(minutes)
    if minutes == 0 then return AdminChatTranslate('chat_duration_permanent') end
    for _, option in ipairs(Config.moderation.chatMuteDurations or {}) do
        if tonumber(option.minutes) == minutes then return AdminChatOption(option) end
    end
    return AdminChatTranslate('chat_duration_minutes', { count=minutes })
end

RegisterNetEvent('feather-admin:chat-moderation:notice', function(notice)
    if type(notice) ~= 'table' or type(notice.durationMinutes) ~= 'number'
        or notice.durationMinutes < 0 or notice.durationMinutes % 1 ~= 0
        or (notice.scopeType ~= 'all' and notice.scopeType ~= 'ooc' and notice.scopeType ~= 'channel') then return end
    Feather.Notify.RightNotify(AdminChatTranslate('chat_mute_notice', {
        scope=AdminChatScope(notice.scopeType, notice.scopeKey),
        duration=AdminChatDuration(notice.durationMinutes) }), 5000)
end)

RegisterCommand('AdminChatTranslationSmokeTest', function()
    local tests = {
        { 'Core-backed translation selected', AdminChatTranslate('chat_case_header', nil,
            function(source, key) return source == 0 and key == 'chat_case_header' and 'Translated' end) == 'Translated' },
        { 'missing key falls back to English', AdminChatTranslate('chat_case_header', nil,
            function() return 'Translation [missing] does not exist' end) == AdminEnglishTranslations.chat_case_header },
        { 'failed provider falls back', AdminChatTranslate('chat_case_header', nil,
            function() error('injected failure') end) == AdminEnglishTranslations.chat_case_header },
        { 'interpolation remains literal', AdminChatTranslate('chat_duration_minutes', {count='100% <text>'},
            function() return '{count} minutes' end) == '100% <text> minutes' },
        { 'owner custom label preserved', AdminChatOption({ label='Owner-defined' }) == 'Owner-defined' },
        { 'conversation status readable', AdminChatStatus('open') ~= 'open' and AdminChatStatus('unexpected') ~= 'unexpected' }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminChatTranslationSmokeTest] %-36s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminChatTranslationSmokeTest] done %d/%d passed (client-only; no database writes)'):format(passed, #tests))
end, false)
