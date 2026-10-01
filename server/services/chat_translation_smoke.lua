RegisterCommand('AdminChatTranslationContractSmokeTest', function(source)
    if source ~= 0 then return end
    local function read(path) return LoadResourceFile(GetCurrentResourceName(), path) or '' end
    local function keys(text)
        local result = {}
        for key in text:gmatch('([%w_]+)%s*=') do result[key] = true end
        return result
    end
    local english = keys(read('translations/en_us.lua'))
    local function complete(locale)
        local translations = keys(read('translations/' .. locale .. '.lua'))
        for key in pairs(english) do
            if (key:match('^chat_') or key == 'mute_chat') and not translations[key] then return false end
        end
        return true
    end
    local configKeysValid = true
    for _, group in ipairs({ Config.moderation.chatMuteScopes, Config.moderation.chatMuteDurations }) do
        for _, option in ipairs(group or {}) do
            if option.translationKey and not english[option.translationKey] then configKeysValid = false end
        end
    end
    local server = read('server/services/moderation.lua')
    local client = read('client/services/chat_translation.lua')
    local tests = {
        { 'English Chat keys available', english.chat_mute_notice and english.chat_case_status_open },
        { 'Romanian Chat keys complete', complete('ro') },
        { 'Spanish Chat keys complete', complete('es') },
        { 'configured option keys valid', configKeysValid },
        { 'mute notice sends semantic data', server:find("TriggerClientEvent('feather-admin:chat-moderation:notice'", 1, true) ~= nil
            and server:find('chatMuteNotice', 1, true) == nil },
        { 'recipient uses standard locale', client:find('Feather.Locale.translate', 1, true) ~= nil
            and client:find("AdminChatTranslate('chat_mute_notice'", 1, true) ~= nil }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminChatTranslationContractSmokeTest] %-36s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminChatTranslationContractSmokeTest] done %d/%d passed (static contract; no database writes)'):format(passed, #tests))
end, true)
