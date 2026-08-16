function AdminUI.OpenSelectedPlayer()
    local page = AdminUI.RegisterPage('selected_player')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('selected_player_header'))

    AdminUI.AddButton(page, AdminTranslate('boosters'), function()
        AdminUI.OpenBoosters(false)
    end)

    AdminUI.AddButton(page, AdminTranslate('trolls'), function()
        AdminUI.OpenTrolls()
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenPlayers()
    end)

    AdminUI.OpenPage('selected_player')
end

function AdminUI.OpenPlayers()
    local page = AdminUI.RegisterPage('players')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('players_header'))

    table.sort(ClientAllPlayers)
    for _, playerId in ipairs(ClientAllPlayers) do
        local target = playerId
        AdminUI.AddButton(page, ('%s: %s'):format(AdminTranslate('player_id'), target), function()
            AdminUI.SetTarget(target)
            AdminUI.OpenSelectedPlayer()
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenMain()
    end)

    AdminUI.OpenPage('players')
end
