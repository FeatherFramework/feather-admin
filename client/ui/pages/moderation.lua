local function targetLabel(target)
    if not target then return AdminTranslate('not_available') end
    local name = target.characterName or target.playerName or target.license
    if target.serverId then return ('%s (%s)'):format(name or 'Player', target.serverId) end
    return tostring(name or AdminTranslate('not_available'))
end

function AdminUI.OpenModeration()
    if not AdminUI.CanUse('moderation.view') then return end
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

function AdminUI.OpenModerationTarget()
    local target = AdminModeration.target
    if not target or not AdminUI.CanUse('moderation.view') then return end
    local warningReason, banReason, duration
    local page = AdminUI.RegisterPage('moderation_target')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('moderation_target_header'))
    AdminUI.AddText(page, targetLabel(target))

    if AdminUI.CanUse('moderation.warn') then
        AdminUI.AddInput(page, AdminTranslate('warning_reason'), AdminTranslate('moderation_reason_placeholder'), function(data)
            warningReason = data.value
        end)
        AdminUI.AddButton(page, AdminTranslate('warn_player'), function()
            if not AdminModeration.Warn(warningReason) then
                Feather.Notify.RightNotify(AdminTranslate('invalid_moderation_reason'), 3000)
            end
        end)
    end

    if AdminUI.CanUse('moderation.ban') then
        AdminUI.AddInput(page, AdminTranslate('ban_reason'), AdminTranslate('moderation_reason_placeholder'), function(data)
            banReason = data.value
        end)
        AdminUI.AddInput(page, AdminTranslate('ban_duration'), AdminTranslate('ban_duration_placeholder'), function(data)
            duration = data.value
        end)
        AdminUI.AddButton(page, AdminTranslate('ban_player'), function()
            local ok, problem = AdminModeration.Ban(banReason, duration)
            if not ok then
                Feather.Notify.RightNotify(AdminTranslate(problem == 'duration' and 'invalid_ban_duration' or 'invalid_moderation_reason'), 3000)
            end
        end, AdminUI.Styles.danger)
    end

    if AdminUI.CanUse('moderation.history') then
        AdminUI.AddButton(page, AdminTranslate('view_history'), AdminModeration.RequestHistory)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        if target.serverId then AdminUI.OpenSelectedPlayer() else AdminUI.OpenModerationSearchResults() end
    end)
    AdminUI.OpenPage('moderation_target')
end

function AdminUI.OpenModerationHistory(history)
    local page = AdminUI.RegisterPage('moderation_history')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('moderation_history_header'))
    if #history == 0 then
        AdminUI.AddText(page, AdminTranslate('no_moderation_history'))
    end
    for _, record in ipairs(history) do
        local entry = record
        local status = entry.kind == 'warning' and AdminTranslate('warning')
            or AdminTranslate(entry.status == 'active' and 'active_ban' or entry.status == 'revoked' and 'revoked_ban' or 'expired_ban')
        local lines = {
            ('%s #%s'):format(status, entry.id),
            ('%s: %s'):format(AdminTranslate('reason'), entry.reason),
            ('%s: %s'):format(AdminTranslate('issued_by'), entry.adminName or AdminTranslate('not_available')),
            ('%s: %s'):format(AdminTranslate('issued_at'), entry.createdAt or AdminTranslate('not_available'))
        }
        if entry.kind == 'ban' then
            lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('expires'), entry.expiresAt or AdminTranslate('permanent'))
            if entry.revokedBy then
                lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('revoked_by'), entry.revokedBy)
                lines[#lines + 1] = ('%s: %s'):format(AdminTranslate('revoked_at'), entry.revokedAt or AdminTranslate('not_available'))
            end
        end
        AdminUI.AddText(page, table.concat(lines, '\n'))
        if entry.kind == 'ban' and entry.status == 'active' and AdminUI.CanUse('moderation.unban') then
            AdminUI.AddButton(page, AdminTranslate('unban'), function()
                AdminModeration.Unban(entry.id)
            end, AdminUI.Styles.danger)
        end
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenModerationTarget)
    AdminUI.OpenPage('moderation_history')
end
