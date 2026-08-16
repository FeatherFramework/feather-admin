function AdminUI.OpenMain()
    local page = AdminUI.RegisterPage('main')
    AdminUI.SetTarget(GetPlayerServerId(PlayerId()))

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('main_menu'))

    if AdminUI.CanUse('players.view') then
        AdminUI.AddButton(page, AdminTranslate('players'), function()
            TriggerServerEvent('feather-admin:players:request')
            AdminUI.OpenPlayers()
        end)
    end

    if AdminUI.CanUseAny('moderation.') then
        AdminUI.AddButton(page, AdminTranslate('moderation'), function()
            AdminUI.OpenModeration()
        end)
    end

    if AdminUI.CanUseAny('developer.') then
        AdminUI.AddButton(page, AdminTranslate('developer_tools'), function()
            AdminUI.OpenDeveloperTools()
        end)
    end

    if AdminUI.CanUseAny('booster.') or AdminUI.CanUse('ped.change') then
        AdminUI.AddButton(page, AdminTranslate('boosters'), function()
            AdminUI.SetTarget(GetPlayerServerId(PlayerId()))
            AdminUI.OpenBoosters(true)
        end)
    end

    if AdminUI.CanUseAny('teleport.') then
        AdminUI.AddButton(page, AdminTranslate('teleport'), function()
            AdminUI.OpenTeleports()
        end)
    end

    if AdminUI.CanUse('player.spectate') and AdminPlayerManagement.IsSpectating() then
        local label = AdminTranslate('stop_spectating')
        AdminUI.AddButton(page, label, function()
            AdminUI.RunAction(label, AdminPlayerManagement.StopSpectating)
        end, AdminUI.Styles.danger)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('close'), function()
        AdminUI.Close()
    end, AdminUI.Styles.danger)

    AdminUI.OpenPage('main')
end
