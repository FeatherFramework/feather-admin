local function targetLabel(target)
    if not target then return AdminChatTranslate('not_available') end

    local name = target.characterName or target.playerName or target.license
    if target.serverId then return ('%s (%s)'):format(name or 'Player', target.serverId) end

    return tostring(name or AdminChatTranslate('not_available'))
end

local function targetDetails(target)
    if not target then return AdminChatTranslate('not_available') end
    local details = {
        ('%s: %s'):format(AdminChatTranslate('status'),
            AdminChatTranslate(target.serverId and 'online' or 'offline')),
        ('%s: %s'):format(AdminChatTranslate('character_name'),
            tostring(target.characterName or AdminChatTranslate('not_available'))),
        ('%s: %s'):format(AdminChatTranslate('account_name'),
            tostring(target.serverName or target.playerName or AdminChatTranslate('not_available')))
    }
    if target.serverId then
        details[#details + 1] = ('%s: %s'):format(AdminChatTranslate('server_id'), tostring(target.serverId))
    end
    if target.characterId then
        details[#details + 1] = ('%s: %s'):format(AdminChatTranslate('character_id'), tostring(target.characterId))
    end
    if target.roleName then
        details[#details + 1] = ('%s: %s'):format(AdminChatTranslate('role_name'),
            tostring(target.roleName))
    end
    return table.concat(details, '\n')
end

local actionDefinitions = {
    warn = { permission = 'moderation.warn', label = 'warn_player' },
    kick = { permission = 'moderation.kick', label = 'kick_player', onlineOnly = true },
    ban = { permission = 'moderation.ban', label = 'ban_player' },
    mute = { permission = 'chat.mute.issue', label = 'mute_chat' }
}

local function availableActions(target)
    local actions = {}
    for _, name in ipairs({ 'warn', 'kick', 'ban', 'mute' }) do
        local definition = actionDefinitions[name]
        if AdminUI.CanUseOnTarget(definition.permission, target.serverId) and (not definition.onlineOnly or target.serverId) then
            actions[#actions + 1] = { display = AdminChatTranslate(definition.label), value = name }
        end
    end
    return actions
end

local function chatMuteOptions(name)
    local options = {}
    for _, entry in ipairs(Config.moderation[name] or {}) do
        if name == 'chatMuteDurations' then
            local minutes = tonumber(entry.minutes)
            if type(entry.label) == 'string' and minutes and minutes >= 0 and minutes % 1 == 0 then
                options[#options + 1] = { display=AdminChatOption(entry), value=minutes }
            end
        elseif type(entry.label) == 'string' and type(entry.scopeType) == 'string' then
            options[#options + 1] = {
                display = AdminChatOption(entry),
                value = ('%s:%s'):format(entry.scopeType, tostring(entry.scopeKey or '')),
                scopeType = entry.scopeType,
                scopeKey = entry.scopeKey
            }
        end
    end
    return options
end

local function banDurationOptions()
    local options = {}
    local maximum = tonumber(Config.moderation.maxBanMinutes) or 525600
    for _, entry in ipairs(Config.moderation.banDurations or {}) do
        local minutes = tonumber(entry.minutes)
        if type(entry.label) == 'string' and entry.label ~= '' and minutes
            and minutes >= 0 and minutes <= maximum and minutes % 1 == 0 then
            options[#options + 1] = { display = entry.label, value = minutes }
        end
    end
    return options
end

local function selectedDurationIndex(options, selectedValue)
    for index, option in ipairs(options) do
        if tonumber(option.value) == tonumber(selectedValue) then return index - 1 end
    end
    return 0
end

function AdminUI.OpenModerationConfirmation(action, reason, duration, scope)
    local definition = actionDefinitions[action]
    if not definition or not AdminUI.CanUseOnTarget(definition.permission,
            AdminModeration.target and AdminModeration.target.serverId) then
        AdminUI.NotifyActionDenied()
        return
    end

    local parsedDuration
    if action == 'ban' then
        if duration == nil or duration == '' then
            Feather.Notify.RightNotify(AdminChatTranslate('invalid_ban_duration'), 3000)
            return
        end
        local valid, problem
        valid, problem, parsedDuration = AdminModeration.ValidateBan(reason, duration)
        if not valid then
            Feather.Notify.RightNotify(AdminChatTranslate(problem == 'duration' and 'invalid_ban_duration' or 'invalid_moderation_reason'), 3000)
            return
        end
    elseif action == 'mute' then
        parsedDuration = tonumber(duration)
        if not AdminModeration.ValidateReason(reason) or not parsedDuration
            or parsedDuration < 0 or parsedDuration % 1 ~= 0 or type(scope) ~= 'table' then
            Feather.Notify.RightNotify(AdminChatTranslate('invalid_chat_mute'), 3000)
            return
        end
    elseif not AdminModeration.ValidateReason(reason) then
        Feather.Notify.RightNotify(AdminChatTranslate('invalid_moderation_reason'), 3000)
        return
    end

    local page = AdminUI.RegisterPage('moderation_confirmation')

    AdminUI.AddHeader(page, AdminChatTranslate('admin_header'), AdminChatTranslate('confirm_moderation_action'))

    local details = {
        ('%s: %s'):format(AdminChatTranslate('player'), targetLabel(AdminModeration.target)),
        ('%s: %s'):format(AdminChatTranslate('moderation_action'), AdminChatTranslate(definition.label)),
        ('%s: %s'):format(AdminChatTranslate('reason'), reason)
    }
    if action == 'mute' then
        details[#details + 1] = ('%s: %s'):format(AdminChatTranslate('chat_mute_duration'),
            AdminChatDuration(parsedDuration))
    elseif action == 'ban' then
        details[#details + 1] = ('%s: %s'):format(AdminChatTranslate('ban_duration'),
            parsedDuration == 0 and AdminChatTranslate('permanent')
                or ('%s %s'):format(parsedDuration, AdminChatTranslate('minutes')))
    end
    if action == 'mute' then
        details[#details + 1] = ('%s: %s'):format(AdminChatTranslate('chat_mute_scope'),
            AdminChatScope(scope.scopeType, scope.scopeKey, scope.label))
    end
    AdminUI.AddText(page, table.concat(details, '\n'))

    AdminUI.AddButton(page, AdminChatTranslate('confirm_action'), function()
        local succeeded = action == 'warn' and AdminModeration.Warn(reason)
            or action == 'kick' and AdminModeration.Kick(reason)
            or action == 'ban' and AdminModeration.Ban(reason, parsedDuration)
            or action == 'mute' and AdminModeration.Mute(reason, parsedDuration, scope)
        if succeeded then AdminUI.Close() end
    end, AdminUI.Styles.button)

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminChatTranslate('back'), AdminUI.OpenModerationTarget)

    AdminUI.OpenPage('moderation_confirmation')
end

function AdminUI.OpenModeration()
    if not AdminUI.CanUse('moderation.view') then return end

    AdminModeration.searchOrigin = 'moderation'
    local query
    local page = AdminUI.RegisterPage('moderation')

    AdminUI.AddHeader(page, AdminChatTranslate('admin_header'), AdminChatTranslate('moderation_header'))

    if AdminUI.CanUse('moderation.search') then
        AdminUI.AddInput(page, AdminChatTranslate('search_query'), AdminChatTranslate('search_query_placeholder'), function(data)
            query = data.value
        end)

        AdminUI.AddButton(page, AdminChatTranslate('search'), function()
            if not AdminModeration.Search(query) then
                Feather.Notify.RightNotify(AdminChatTranslate('search_query_placeholder'), 3000)
            end
        end)
    end

    AdminUI.AddLine(page)

    AdminUI.AddText(page, AdminChatTranslate('offline_search_help'))

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminChatTranslate('back'), AdminUI.OpenMain)

    AdminUI.OpenPage('moderation')
end

function AdminUI.OpenModerationSearchResults()
    local page = AdminUI.RegisterPage('moderation_search_results')

    AdminUI.AddHeader(page, AdminChatTranslate('admin_header'), AdminChatTranslate('moderation_header'))

    if #AdminModeration.results == 0 then
        AdminUI.AddText(page, AdminChatTranslate('no_search_results'))
    else
        for _, result in ipairs(AdminModeration.results) do
            local selected = result
            AdminUI.AddButton(page, targetLabel(selected), function()
                AdminModeration.SelectOffline(selected)
            end)
        end
    end

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminChatTranslate('back'), AdminUI.OpenModeration)

    AdminUI.OpenPage('moderation_search_results')
end

function AdminUI.OpenModerationHistory(history)
    local page = AdminUI.RegisterPage('moderation_history')

    AdminUI.AddHeader(page, AdminChatTranslate('admin_header'), AdminChatTranslate('moderation_history_header'))

    if #history == 0 then
        AdminUI.AddText(page, AdminChatTranslate('no_moderation_history'))
    end

    for _, record in ipairs(history) do
        local entry = record
        local issuedBy = entry.adminName or AdminChatTranslate('not_available')
        if entry.adminCharacterName then
            issuedBy = ('%s (%s)'):format(issuedBy, entry.adminCharacterName)
        end
        local status = entry.kind == 'warning' and AdminChatTranslate('warning')
            or entry.kind == 'kick' and AdminChatTranslate('kick')
            or AdminChatTranslate(entry.status == 'active' and 'active_ban'
                or entry.status == 'revoked' and 'revoked_ban'
                or entry.status == 'superseded' and 'superseded_ban'
                or 'expired_ban')
        local lines = {
            ('%s #%s'):format(status, entry.id),
            ('%s: %s'):format(AdminChatTranslate('reason'), entry.reason),
            ('%s: %s'):format(AdminChatTranslate('issued_by'), issuedBy),
            ('%s: %s'):format(AdminChatTranslate('issued_at'), entry.createdAt or AdminChatTranslate('not_available'))
        }
        if entry.kind == 'ban' then
            lines[#lines + 1] = ('%s: %s'):format(AdminChatTranslate('expires'), entry.expiresAt or AdminChatTranslate('permanent'))
            if entry.revokedBy then
                local revokedBy = entry.revokedBy
                if entry.revokedByCharacterName then
                    revokedBy = ('%s (%s)'):format(revokedBy, entry.revokedByCharacterName)
                end
                lines[#lines + 1] = ('%s: %s'):format(AdminChatTranslate('revoked_by'), revokedBy)
                lines[#lines + 1] = ('%s: %s'):format(AdminChatTranslate('revoked_at'), entry.revokedAt or AdminChatTranslate('not_available'))
            end
        end

        AdminUI.AddText(page, table.concat(lines, '\n'))

        if entry.kind == 'ban' and entry.status == 'active' and AdminUI.CanUse('moderation.unban') then
            AdminUI.AddButton(page, AdminChatTranslate('unban'), function()
                AdminModeration.Unban(entry.id)
            end, AdminUI.Styles.button)
        end
    end

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminChatTranslate('back'), AdminUI.OpenModerationTarget)

    AdminUI.OpenPage('moderation_history')
end

function AdminUI.OpenChatMutes(mutes)
    local page = AdminUI.RegisterPage('chat_mutes')
    AdminUI.AddHeader(page, AdminChatTranslate('admin_header'), AdminChatTranslate('chat_mutes'))
    if #mutes == 0 then AdminUI.AddText(page, AdminChatTranslate('no_active_chat_mutes')) end
    for _, value in ipairs(mutes) do
        local mute = value
        AdminUI.AddText(page, table.concat({
            ('%s: %s'):format(AdminChatTranslate('chat_mute_scope'), AdminChatScope(mute.scopeType, mute.scopeKey)),
            ('%s: %s'):format(AdminChatTranslate('reason'), tostring(mute.reason)),
            ('%s: %s'):format(AdminChatTranslate('issued_at'), tostring(mute.createdAt)),
            ('%s: %s'):format(AdminChatTranslate('expires'), tostring(mute.expiresAt or AdminChatTranslate('permanent')))
        }, '\n'))
        if AdminUI.CanUseOnTarget('chat.mute.revoke', AdminModeration.target and AdminModeration.target.serverId) then
            AdminUI.AddButton(page, AdminChatTranslate('revoke_chat_mute'), function()
                AdminModeration.RevokeMute(mute.muteId)
            end, AdminUI.Styles.button)
        end
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminChatTranslate('back'), AdminUI.OpenModerationTarget)
    AdminUI.OpenPage('chat_mutes')
end


function AdminUI.OpenModerationTarget()
    local target = AdminModeration.target
    if not target or not AdminUI.CanUse('moderation.view') then return end

    local form = AdminModeration.form
    local actions = availableActions(target)
    if #actions == 0 then
        AdminUI.NotifyActionDenied()
        return
    end

    local selectedIndex = 0
    for index, option in ipairs(actions) do
        if option.value == form.action then selectedIndex = index - 1 end
    end
    form.action = actions[selectedIndex + 1].value

    local page = AdminUI.RegisterPage('moderation_target')

    AdminUI.AddHeader(page, AdminChatTranslate('admin_header'), AdminChatTranslate('moderation_target_header'))

    AdminUI.AddText(page, targetDetails(target))

    AdminUI.AddLine(page)

    AdminUI.AddArrows(page, AdminChatTranslate('moderation_action'), actions, selectedIndex, function(data)
        form.action = data.value.value
        AdminUI.OpenModerationTarget()
    end)

    AdminUI.AddInput(page, AdminChatTranslate('reason'), AdminChatTranslate('moderation_reason_placeholder'), function(data)
        form.reason = data.value
    end, form.reason)

    if form.action == 'ban' then
        local durations = banDurationOptions()
        if #durations > 0 then
            local durationIndex = selectedDurationIndex(durations, form.duration)
            form.duration = durations[durationIndex + 1].value
            AdminUI.AddArrows(page, AdminChatTranslate('ban_duration'), durations, durationIndex, function(data)
                form.duration = data.value.value
            end)
        else
            AdminUI.AddText(page, AdminChatTranslate('invalid_ban_duration'))
        end
    elseif form.action == 'mute' then
        local durations, scopes = chatMuteOptions('chatMuteDurations'), chatMuteOptions('chatMuteScopes')
        if #durations == 0 or #scopes == 0 then
            AdminUI.AddText(page, AdminChatTranslate('invalid_chat_mute'))
        else
            local durationIndex = selectedDurationIndex(durations, form.duration)
            form.duration = durations[durationIndex + 1].value
            AdminUI.AddArrows(page, AdminChatTranslate('chat_mute_duration'), durations, durationIndex, function(data)
                form.duration = data.value.value
            end)
            local scopeIndex = 0
            for index, option in ipairs(scopes) do
                if form.scope and option.scopeType == form.scope.scopeType
                    and option.scopeKey == form.scope.scopeKey then scopeIndex = index - 1 end
            end
            local selectedScope = scopes[scopeIndex + 1]
            form.scope = {
                scopeType = selectedScope.scopeType,
                scopeKey = selectedScope.scopeKey,
                label = selectedScope.display
            }
            AdminUI.AddArrows(page, AdminChatTranslate('chat_mute_scope'), scopes, scopeIndex, function(data)
                form.scope = {
                    scopeType = data.value.scopeType,
                    scopeKey = data.value.scopeKey,
                    label = data.value.display
                }
            end)
        end
    end

    AdminUI.AddLine(page)

    if AdminUI.CanUseOnTarget('moderation.history', target.serverId) then
        AdminUI.AddButton(page, AdminChatTranslate('view_history'), AdminModeration.RequestHistory)
    end
    if AdminUI.CanUseOnTarget('chat.mute.inspect', target.serverId) then
        AdminUI.AddButton(page, AdminChatTranslate('view_chat_mutes'), AdminModeration.RequestMutes)
    end

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminChatTranslate('submit'), function()
        AdminUI.OpenModerationConfirmation(form.action, form.reason, form.duration, form.scope)
    end, AdminUI.Styles.button)

    AdminUI.AddFooterButton(page, AdminChatTranslate('back'), function()
        if target.serverId then
            AdminUI.OpenSelectedPlayer()
        elseif AdminModeration.searchOrigin == 'players' then
            AdminUI.OpenOfflinePlayer(AdminModeration.target)
        else
            AdminUI.OpenModerationSearchResults()
        end
    end)

    AdminUI.OpenPage('moderation_target')
end
