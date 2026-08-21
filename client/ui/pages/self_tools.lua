function AdminUI.OpenSelfTools()
    AdminUI.SetTarget(GetPlayerServerId(PlayerId()))
    local page = AdminUI.RegisterPage('self_tools')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('self_tools_header'))

    if AdminUI.CanUseAny('teleport.') then
        AdminUI.AddButton(page, AdminTranslate('travel'), AdminUI.OpenTeleports)
    end

    if AdminUI.CanUsePlayerStatus(true) then
        AdminUI.AddButton(page, AdminTranslate('player_status'), function()
            AdminUI.OpenBoosters(true)
        end)
    end

    if AdminUI.CanUse('ped.change') or AdminUI.CanUse('troll.make_ped_giant') then
        AdminUI.AddButton(page, AdminTranslate('appearance'), function()
            AdminUI.OpenAppearance('self_tools')
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage('self_tools')
end
