local function displayValue(value)
    if value == nil or value == '' then return AdminTranslate('not_available') end
    return tostring(value)
end

function AdminUI.OpenPlayerInfo(info)
    if not AdminUI.CanUse('player.info') then return end

    local page = AdminUI.RegisterPage('player_info')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_info_header'))

    local identifiers = type(info.identifiers) == 'table'
        and table.concat(info.identifiers, '\n')
        or AdminTranslate('not_available')
    local text = table.concat({
        ('%s: %s'):format(AdminTranslate('player_id'), displayValue(info.serverId)),
        ('%s: %s'):format(AdminTranslate('server_name'), displayValue(info.serverName)),
        ('%s: %s'):format(AdminTranslate('character_id'), displayValue(info.characterId)),
        ('%s: %s %s'):format(AdminTranslate('character_name'), displayValue(info.firstName), displayValue(info.lastName)),
        ('%s: %s'):format(AdminTranslate('role_name'), displayValue(info.roleName)),
        ('%s: %s'):format(AdminTranslate('role_level'), displayValue(info.roleLevel)),
        ('%s: %s'):format(AdminTranslate('dollars'), displayValue(info.dollars)),
        ('%s: %s'):format(AdminTranslate('gold'), displayValue(info.gold)),
        ('%s: %s'):format(AdminTranslate('tokens'), displayValue(info.tokens)),
        ('%s: %s'):format(AdminTranslate('xp'), displayValue(info.xp)),
        ('%s:\n%s'):format(AdminTranslate('identifiers'), identifiers)
    }, '\n')

    AdminUI.AddText(page, text)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPlayerManagement)
    AdminUI.OpenPage('player_info')
end

function AdminUI.OpenPlayerManagement()
    if not AdminUI.CanUseAny('player.') then return end

    local kickReason
    local page = AdminUI.RegisterPage('player_management')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_management_header'))

    if AdminUI.CanUse('player.info') then
        local label = AdminTranslate('view_player_info')
        AdminUI.AddButton(page, label, function()
            AdminUI.RunAction(label, function()
                return AdminPlayerManagement.RequestInfo(AdminUI.GetTarget())
            end)
        end)
    end

    if AdminUI.CanUse('player.go_to') then
        local label = AdminTranslate('go_to_player')
        AdminUI.AddButton(page, label, function()
            AdminPlayerManagement.GoTo(AdminUI.GetTarget())
            AdminUI.Close()
        end)
    end

    if AdminUI.CanUse('player.bring') then
        local label = AdminTranslate('bring_player')
        AdminUI.AddButton(page, label, function()
            AdminPlayerManagement.Bring(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUse('player.send_back') then
        local label = AdminTranslate('send_player_back')
        AdminUI.AddButton(page, label, function()
            AdminPlayerManagement.SendBack(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUse('player.spectate') then
        local label = AdminTranslate('spectate_player')
        local enabled = AdminPlayerManagement.IsSpectating(AdminUI.GetTarget())
        local buttonLabel = ('%s: %s'):format(label, AdminTranslate(enabled and 'status_on' or 'status_off'))
        AdminUI.AddButton(page, buttonLabel, function(_, element)
            enabled = not enabled
            AdminPlayerManagement.Spectate(AdminUI.GetTarget(), enabled)
            element:update({
                label = ('%s: %s'):format(label, AdminTranslate(enabled and 'status_on' or 'status_off'))
            })
            if enabled then AdminUI.Close() end
        end)
    end

    if AdminUI.CanUse('player.kick') then
        AdminUI.AddInput(page, AdminTranslate('kick_reason'), AdminTranslate('kick_reason_placeholder'), function(data)
            kickReason = data.value
        end)
        AdminUI.AddButton(page, AdminTranslate('kick_player'), function()
            if not AdminPlayerManagement.Kick(AdminUI.GetTarget(), kickReason) then
                Feather.Notify.RightNotify(AdminTranslate('invalid_kick_reason'), 3000)
                return
            end
            AdminUI.Close()
        end, AdminUI.Styles.danger)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenSelectedPlayer)
    AdminUI.OpenPage('player_management')
end
