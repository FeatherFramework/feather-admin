local function displayValue(value)
    if value == nil or value == '' then return AdminTranslate('not_available') end
    return tostring(value)
end

function AdminUI.OpenPlayerInfo(info)
    if not AdminUI.CanUse('player.info') then return end

    local page = AdminUI.RegisterPage('player_info')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_info_header'))

    local identityText = table.concat({
        ('%s: %s'):format(AdminTranslate('player_id'), displayValue(info.serverId)),
        ('%s: %s'):format(AdminTranslate('server_name'), displayValue(info.serverName)),
        ('%s: %s'):format(AdminTranslate('character_id'), displayValue(info.characterId)),
        ('%s: %s %s'):format(AdminTranslate('character_name'), displayValue(info.firstName), displayValue(info.lastName))
    }, '\n')
    local roleText = table.concat({
        ('%s: %s'):format(AdminTranslate('role_name'), displayValue(info.roleName)),
        ('%s: %s'):format(AdminTranslate('role_level'), displayValue(info.roleLevel))
    }, '\n')
    local economyText = table.concat({
        ('%s: %s'):format(AdminTranslate('dollars'), displayValue(info.dollars)),
        ('%s: %s'):format(AdminTranslate('gold'), displayValue(info.gold)),
        ('%s: %s'):format(AdminTranslate('tokens'), displayValue(info.tokens)),
        ('%s: %s'):format(AdminTranslate('xp'), displayValue(info.xp))
    }, '\n')

    AdminUI.AddText(page, identityText)
    AdminUI.AddLine(page)
    AdminUI.AddText(page, roleText)
    AdminUI.AddLine(page)
    AdminUI.AddText(page, economyText)
    AdminUI.AddLine(page)
    local identifiers = type(info.identifiers) == 'table' and info.identifiers or {}
    if #identifiers == 0 then
        AdminUI.AddText(page, AdminTranslate('identifiers'))
        AdminUI.AddText(page, AdminTranslate('not_available'))
    else
        local identifierOptions = {}
        for _, identifier in ipairs(identifiers) do
            local value = tostring(identifier)
            local identifierType = value:match('^([^:]+):') or AdminTranslate('identifier')
            identifierOptions[#identifierOptions + 1] = {
                display = identifierType,
                value = value
            }
        end

        local selectedIdentifier = identifierOptions[1].value
        local identifierDisplay
        AdminUI.AddArrows(page, AdminTranslate('identifiers'), identifierOptions, 0, function(data)
            selectedIdentifier = data.value.value
            if identifierDisplay then identifierDisplay:update({ value = selectedIdentifier }) end
        end)
        identifierDisplay = AdminUI.AddText(page, selectedIdentifier)
        AdminUI.AddButton(page, AdminTranslate('copy_identifier'), function()
            local copied = Feather.Clip.CopyToClipboard(selectedIdentifier)
            if copied ~= false then
                Feather.Notify.RightNotify(AdminTranslate('identifier_copied'), 2000)
            end
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenSelectedPlayer)
    AdminUI.OpenPage('player_info')
end

function AdminUI.OpenPlayerManagement()
    if not AdminUI.CanUseAny('player.') then return end

    local page = AdminUI.RegisterPage('player_management')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('movement_header'))

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

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenSelectedPlayer)
    AdminUI.OpenPage('player_management')
end
