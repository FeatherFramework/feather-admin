function AdminUI.OpenSelectedPlayer()
    if not AdminUI.CanUse('players.view') then return end
    local page = AdminUI.RegisterPage('selected_player')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('selected_player_header'))

    if AdminUI.CanUseAny('player.') then
        AdminUI.AddButton(page, AdminTranslate('player_management'), function()
            AdminUI.OpenPlayerManagement()
        end)
    end

    if AdminUI.CanUseAny('moderation.') then
        AdminUI.AddButton(page, AdminTranslate('moderation'), function()
            AdminModeration.SelectOnline(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUseAny('economy.') or AdminUI.CanUse('character.restore_model') then
        AdminUI.AddButton(page, AdminTranslate('character_administration'), function()
            AdminUI.OpenCharacterAdministration()
        end)
    end

    if AdminUI.CanUseAny('booster.') or AdminUI.CanUse('ped.change') then
        AdminUI.AddButton(page, AdminTranslate('boosters'), function()
            AdminUI.OpenBoosters(false)
        end)
    end

    if AdminUI.CanUseAny('troll.') then
        AdminUI.AddButton(page, AdminTranslate('trolls'), function()
            AdminUI.OpenTrolls()
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenPlayers()
    end)

    AdminUI.OpenPage('selected_player')
end

function AdminUI.OpenPlayers()
    if not AdminUI.CanUse('players.view') then return end
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
