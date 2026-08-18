function AdminUI.OpenAppearance(parentPage)
    if parentPage then AdminUI.appearanceParent = parentPage end
    if not AdminUI.CanUseOnTarget('ped.change') and not AdminUI.CanUseOnTarget('troll.make_ped_giant') then return end

    local page = AdminUI.RegisterPage('appearance')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('appearance_header'))

    if AdminUI.CanUseOnTarget('ped.change') then
        AdminUI.AddButton(page, AdminTranslate('change_ped_model'), AdminUI.OpenPedCategories)
    end

    if AdminUI.CanUseOnTarget('troll.make_ped_giant') then
        local label = AdminTranslate('toggle_giant_ped')
        AdminUI.AddButton(page, AdminUI.GetToggleLabel(label, 'make_ped_giant'), function(_, element)
            AdminUI.RunToggleAction(label, 'make_ped_giant', element, function()
                AdminTrolls.Request('make_ped_giant', AdminUI.GetTarget())
            end)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        if AdminUI.appearanceParent == 'self_tools' then
            AdminUI.OpenSelfTools()
        else
            AdminUI.OpenSelectedPlayer()
        end
    end)
    AdminUI.OpenPage('appearance')
end
