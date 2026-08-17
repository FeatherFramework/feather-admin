function AdminUI.OpenMain()
    local page = AdminUI.RegisterPage('main')
    AdminUI.SetTarget(GetPlayerServerId(PlayerId()))

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('main_menu'))

    if AdminUI.CanUse('players.view') then
        AdminUI.AddButton(page, AdminTranslate('player_list'), function()
            Feather.RPC.Notify('feather-admin:players:request', {})
            AdminUI.OpenPlayers()
        end)
    end

    if AdminUI.CanUse('moderation.view') and AdminUI.CanUse('moderation.search') then
        AdminUI.AddButton(page, AdminTranslate('offline_players'), function()
            AdminUI.OpenModeration()
        end)
    end

    if AdminUI.CanUseAny('teleport.') then
        AdminUI.AddButton(page, AdminTranslate('travel'), function()
            AdminUI.OpenTeleports()
        end)
    end

    if AdminUI.CanUsePlayerStatus(true) or AdminUI.CanUse('ped.change')
        or AdminUI.CanUse('troll.make_ped_giant') then
        AdminUI.AddButton(page, AdminTranslate('self_tools'), function()
            AdminUI.SetTarget(GetPlayerServerId(PlayerId()))
            AdminUI.OpenSelfTools()
        end)
    end

    if AdminUI.CanUseAny('developer.') then
        AdminUI.AddButton(page, AdminTranslate('developer_tools'), function()
            AdminUI.OpenDeveloperTools()
        end)
    end

    if AdminUI.CanUse('player.spectate') and AdminPlayerManagement.IsSpectating() then
        local label = AdminTranslate('stop_spectating')
        AdminUI.AddButton(page, label, function()
            AdminUI.RunAction(label, AdminPlayerManagement.StopSpectating)
        end, AdminUI.Styles.button)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('close'), function()
        AdminUI.Close()
    end, AdminUI.Styles.button)

    AdminUI.OpenPage('main')
end
