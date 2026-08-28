local function display(value)
    if value == nil or value == '' then return AdminTranslate('not_available') end
    return tostring(value)
end

local function playerName(ban)
    return ban.characterName or ban.playerName or AdminTranslate('not_available')
end

local function banDetails(ban)
    local issuedBy = ban.adminCharacterName or ban.adminName or AdminTranslate('not_available')
    return table.concat({
        ('%s: #%s'):format(AdminTranslate('ban_id'), display(ban.id)),
        ('%s: %s'):format(AdminTranslate('account_id'), display(ban.accountId)),
        ('%s: %s'):format(AdminTranslate('character_name'), display(ban.characterName)),
        ('%s: %s'):format(AdminTranslate('account_name'), display(ban.playerName)),
        ('%s: %s'):format(AdminTranslate('reason'), display(ban.reason)),
        ('%s: %s'):format(AdminTranslate('issued_by'), display(issuedBy)),
        ('%s: %s'):format(AdminTranslate('issued_at'), display(ban.createdAt)),
        ('%s: %s'):format(AdminTranslate('expires'), ban.expiresAt or AdminTranslate('permanent'))
    }, '\n')
end

function AdminUI.OpenActiveBanRevokeConfirmation()
    local ban = AdminActiveBans.selected
    if type(ban) ~= 'table' or not AdminUI.CanUse('moderation.unban') then
        AdminUI.NotifyActionDenied()
        return
    end

    local page = AdminUI.RegisterPage('active_ban_revoke_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_unban'))
    AdminUI.AddText(page, banDetails(ban))
    AdminUI.AddButton(page, AdminTranslate('confirm_unban'), function()
        AdminModeration.Unban(ban.id, 'active_bans')
    end, AdminUI.Styles.button)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenActiveBanDetails)
    AdminUI.OpenPage('active_ban_revoke_confirmation')
end

function AdminUI.OpenActiveBanDetails()
    local ban = AdminActiveBans.selected
    if type(ban) ~= 'table' or not AdminUI.CanUse('moderation.bans.view') then return end

    local page = AdminUI.RegisterPage('active_ban_details')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('active_ban_details'))
    AdminUI.AddText(page, banDetails(ban))
    if AdminUI.CanUse('moderation.unban') then
        AdminUI.AddButton(page, AdminTranslate('unban'), AdminUI.OpenActiveBanRevokeConfirmation,
            AdminUI.Styles.button)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenActiveBans)
    AdminUI.OpenPage('active_ban_details')
end

function AdminUI.OpenActiveBans()
    if not AdminUI.CanUse('moderation.bans.view') then
        AdminUI.NotifyActionDenied()
        return
    end

    local query = AdminActiveBans.query
    local page = AdminUI.RegisterPage('active_bans')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('active_bans'))
    AdminUI.AddInput(page, AdminTranslate('player_search'), AdminTranslate('optional'), function(data)
        query = data.value
    end, query)
    AdminUI.AddButton(page, AdminTranslate('search'), function()
        if not AdminActiveBans.Search(query) then
            Feather.Notify.RightNotify(AdminTranslate('invalid_active_ban_search'), 3000)
        end
    end)
    if AdminActiveBans.query ~= '' then
        AdminUI.AddButton(page, AdminTranslate('clear_search'), AdminActiveBans.ClearSearch)
    end
    AdminUI.AddText(page, AdminTranslate('active_ban_search_help'))
    AdminUI.AddLine(page)

    if #AdminActiveBans.rows == 0 then
        AdminUI.AddText(page, AdminTranslate('no_active_bans'))
    else
        for _, entry in ipairs(AdminActiveBans.rows) do
            local ban = entry
            AdminUI.AddButton(page, ('#%s - %s'):format(tostring(ban.id), playerName(ban)), function()
                AdminActiveBans.selected = ban
                AdminUI.OpenActiveBanDetails()
            end)
        end
    end

    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('page'), AdminActiveBans.page))
    if AdminActiveBans.page > 1 then
        AdminUI.AddButton(page, AdminTranslate('previous_page'), function()
            AdminActiveBans.Request(AdminActiveBans.page - 1)
        end)
    end
    if AdminActiveBans.hasNext then
        AdminUI.AddButton(page, AdminTranslate('next_page'), function()
            AdminActiveBans.Request(AdminActiveBans.page + 1)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenNavigationSection('moderation_center')
    end)
    AdminUI.OpenPage('active_bans')
end

AdminUI.RegisterNavigationItem('moderation_center', {
    key = 'active_bans',
    labelKey = 'active_bans',
    order = 10,
    permission = 'moderation.bans.view',
    open = function() AdminActiveBans.Request(1) end
})
