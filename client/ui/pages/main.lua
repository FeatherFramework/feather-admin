function AdminUI.OpenMain()
    local page = AdminUI.RegisterPage('main')
    AdminUI.SetTarget(GetPlayerServerId(PlayerId()))

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('main_menu'))

    AdminUI.AddButton(page, AdminTranslate('players'), function()
        TriggerServerEvent('feather-admin:players:request')
        AdminUI.OpenPlayers()
    end)

    AdminUI.AddButton(page, AdminTranslate('developer_tools'), function()
        AdminUI.OpenDeveloperTools()
    end)

    AdminUI.AddButton(page, AdminTranslate('boosters'), function()
        AdminUI.SetTarget(GetPlayerServerId(PlayerId()))
        AdminUI.OpenBoosters(true)
    end)

    AdminUI.AddButton(page, AdminTranslate('teleport'), function()
        AdminUI.OpenTeleports()
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('close'), function()
        AdminUI.Close()
    end, AdminUI.Styles.danger)

    AdminUI.OpenPage('main')
end
