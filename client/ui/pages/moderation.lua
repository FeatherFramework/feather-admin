local function targetLabel(target)
    if not target then return AdminTranslate('not_available') end

    local name = target.characterName or target.playerName or target.license
    if target.serverId then return ('%s (%s)'):format(name or 'Player', target.serverId) end

    return tostring(name or AdminTranslate('not_available'))
end

local function targetDetails(target)
    if not target then return AdminTranslate('not_available') end
    local details = {
        ('%s: %s'):format(AdminTranslate('status'),
            AdminTranslate(target.serverId and 'online' or 'offline')),
        ('%s: %s'):format(AdminTranslate('character_name'),
            tostring(target.characterName or AdminTranslate('not_available'))),
        ('%s: %s'):format(AdminTranslate('account_name'),
            tostring(target.serverName or target.playerName or AdminTranslate('not_available')))
    }
    if target.serverId then
        details[#details + 1] = ('%s: %s'):format(AdminTranslate('server_id'), tostring(target.serverId))
    end
    if target.characterId then
        details[#details + 1] = ('%s: %s'):format(AdminTranslate('character_id'), tostring(target.characterId))
    end
    if target.roleName then
        details[#details + 1] = ('%s: %s (%s)'):format(AdminTranslate('role_name'),
            tostring(target.roleName), tostring(target.roleLevel or 0))
    end
    return table.concat(details, '\n')
end

local actionDefinitions = {
    warn = { permission = 'moderation.warn', label = 'warn_player' },
    kick = { permission = 'moderation.kick', label = 'kick_player', onlineOnly = true },
    ban = { permission = 'moderation.ban', label = 'ban_player' }
}

local function availableActions(target)
    local actions = {}
    for _, name in ipairs({ 'warn', 'kick', 'ban' }) do
        local definition = actionDefinitions[name]
        if AdminUI.CanUseOnTarget(definition.permission, target.serverId) and (not definition.onlineOnly or target.serverId) then
            actions[#actions + 1] = { display = AdminTranslate(definition.label), value = name }
        end
    end
    return actions
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

function AdminUI.OpenModerationConfirmation(action, reason, duration)
    local definition = actionDefinitions[action]
    if not definition or not AdminUI.CanUseOnTarget(definition.permission,
            AdminModeration.target and AdminModeration.target.serverId) then
        AdminUI.NotifyActionDenied()
        return
    end

    local parsedDuration
    if action == 'ban' then
        if duration == nil or duration == '' then
            Feather.Notify.RightNotify(AdminTranslate('invalid_ban_duration'), 3000)
            return
        end
        local valid, problem
        valid, problem, parsedDuration = AdminModeration.ValidateBan(reason, duration)
        if not valid then
            Feather.Notify.RightNotify(AdminTranslate(problem == 'duration' and 'invalid_ban_duration' or 'invalid_moderation_reason'), 3000)
            return
        end
    elseif not AdminModeration.ValidateReason(reason) then
        Feather.Notify.RightNotify(AdminTranslate('invalid_moderation_reason'), 3000)
        return
    end

    local page = AdminUI.RegisterPage('moderation_confirmation')

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_moderation_action'))

    local details = {
        ('%s: %s'):format(AdminTranslate('player'), targetLabel(AdminModeration.target)),
        ('%s: %s'):format(AdminTranslate('moderation_action'), AdminTranslate(definition.label)),
        ('%s: %s'):format(AdminTranslate('reason'), reason)
    }
    if action == 'ban' then
        details[#details + 1] = ('%s: %s'):format(AdminTranslate('ban_duration'),
            parsedDuration == 0 and AdminTranslate('permanent')
                or ('%s %s'):format(parsedDuration, AdminTranslate('minutes')))
    end
    AdminUI.AddText(page, table.concat(details, '\n'))

    AdminUI.AddButton(page, AdminTranslate('confirm_action'), function()
        local succeeded = action == 'warn' and AdminModeration.Warn(reason)
            or action == 'kick' and AdminModeration.Kick(reason)
            or action == 'ban' and AdminModeration.Ban(reason, parsedDuration)
        if succeeded then AdminUI.Close() end
    end, AdminUI.Styles.button)

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenModerationTarget)

    AdminUI.OpenPage('moderation_confirmation')
end

function AdminUI.OpenModeration()
    if not AdminUI.CanUse('moderation.view') then return end

    AdminModeration.searchOrigin = 'moderation'
    local query
    local page = AdminUI.RegisterPage('moderation')

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('moderation_header'))

    if AdminUI.CanUse('moderation.search') then
        AdminUI.AddInput(page, AdminTranslate('search_query'), AdminTranslate('search_query_placeholder'), function(data)
            query = data.value
        end)

        AdminUI.AddButton(page, AdminTranslate('search'), function()
            if not AdminModeration.Search(query) then
                Feather.Notify.RightNotify(AdminTranslate('search_query_placeholder'), 3000)
            end
        end)
    end

    AdminUI.AddLine(page)

    AdminUI.AddText(page, AdminTranslate('offline_search_help'))

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)

    AdminUI.OpenPage('moderation')
end

function AdminUI.OpenModerationSearchResults()
    local page = AdminUI.RegisterPage('moderation_search_results')

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('moderation_header'))

    if #AdminModeration.results == 0 then
        AdminUI.AddText(page, AdminTranslate('no_search_results'))
    else
        for _, result in ipairs(AdminModeration.results) do
            local selected = result
            AdminUI.AddButton(page, targetLabel(selected), function()
                AdminModeration.SelectOffline(selected)
            end)
        end
    end

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenModeration)

    AdminUI.OpenPage('moderation_search_results')
end

function AdminUI.OpenModerationHistory(history)
    local page = AdminUI.RegisterPage('moderation_history')

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('moderation_history_header'))

    if #history == 0 then
        AdminUI.AddText(page, AdminTranslate('no_moderation_history'))
    end

    for _, record in ipairs(history) do
        local entry = record
        local issuedBy = entry.adminName or AdminTranslate('not_available')
        if entry.adminCharacterName then
            issuedBy = ('%s (%s)'):format(issuedBy, entry.adminCharacterName)
        end
        local status = entry.kind == 'warning' and AdminTranslate('warning')
            or entry.kind == 'kick' and AdminTranslate('kick')
            or AdminTranslate(entry.status == 'active' and 'active_ban'
                or entry.status == 'revoked' and 'revoked_ban'
                or entry.status == 'superseded' and 'superseded_ban'
                or 'expired_ban')
        local lines = {
            ('%s #%s'):format(status, entry.id),
            ('%s: %s'):format(AdminTranslate('reason'), entry.reason),
            ('%s: %s'):format(AdminTranslate('issued_by'), issuedBy),
            ('%s: %s'):format(AdminTranslate('issued_at'), entry.createdAt or AdminTranslate('not_available'))
        }
        if entry.kind == 'ban' then
            lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('expires'), entry.expiresAt or AdminTranslate('permanent'))
            if entry.revokedBy then
                local revokedBy = entry.revokedBy
                if entry.revokedByCharacterName then
                    revokedBy = ('%s (%s)'):format(revokedBy, entry.revokedByCharacterName)
                end
                lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('revoked_by'), revokedBy)
                lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('revoked_at'), entry.revokedAt or AdminTranslate('not_available'))
            end
        end

        AdminUI.AddText(page, table.concat(lines, '\n'))

        if entry.kind == 'ban' and entry.status == 'active' and AdminUI.CanUse('moderation.unban') then
            AdminUI.AddButton(page, AdminTranslate('unban'), function()
                AdminModeration.Unban(entry.id)
            end, AdminUI.Styles.button)
        end
    end

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenModerationTarget)

    AdminUI.OpenPage('moderation_history')
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

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('moderation_target_header'))

    AdminUI.AddText(page, targetDetails(target))

    AdminUI.AddLine(page)

    AdminUI.AddArrows(page, AdminTranslate('moderation_action'), actions, selectedIndex, function(data)
        form.action = data.value.value
        AdminUI.OpenModerationTarget()
    end)

    AdminUI.AddInput(page, AdminTranslate('reason'), AdminTranslate('moderation_reason_placeholder'), function(data)
        form.reason = data.value
    end, form.reason)

    if form.action == 'ban' then
        local durations = banDurationOptions()
        if #durations > 0 then
            local durationIndex = selectedDurationIndex(durations, form.duration)
            form.duration = durations[durationIndex + 1].value
            AdminUI.AddArrows(page, AdminTranslate('ban_duration'), durations, durationIndex, function(data)
                form.duration = data.value.value
            end)
        else
            AdminUI.AddText(page, AdminTranslate('invalid_ban_duration'))
        end
    end

    AdminUI.AddButton(page, AdminTranslate('submit'), function()
        AdminUI.OpenModerationConfirmation(form.action, form.reason, form.duration)
    end, (form.action == 'kick' or form.action == 'ban') and AdminUI.Styles.button or nil)

    AdminUI.AddLine(page)

    if AdminUI.CanUseOnTarget('moderation.history', target.serverId) then
        AdminUI.AddButton(page, AdminTranslate('view_history'), AdminModeration.RequestHistory)
    end

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
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
