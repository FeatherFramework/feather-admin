function AdminUI.OpenSelectedPlayer()
    if not AdminUI.CanUse('players.view') then return end
    local page = AdminUI.RegisterPage('selected_player')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('selected_player_header'))

    if AdminUI.CanUseOnTarget('player.info') then
        AdminUI.AddButton(page, AdminTranslate('player_information'), function()
            AdminPlayerManagement.RequestInfo(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUse('moderation.view') then
        AdminUI.AddButton(page, AdminTranslate('moderation'), function()
            AdminModeration.SelectOnline(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUseOnTarget('player.go_to') or AdminUI.CanUseOnTarget('player.bring')
        or AdminUI.CanUseOnTarget('player.send_back') or AdminUI.CanUseOnTarget('player.spectate') then
        AdminUI.AddButton(page, AdminTranslate('movement'), AdminUI.OpenPlayerManagement)
    end

    if AdminUI.CanUseOnTarget('economy.dollars.add') or AdminUI.CanUseOnTarget('economy.dollars.remove')
        or AdminUI.CanUseOnTarget('economy.gold.add') or AdminUI.CanUseOnTarget('economy.gold.remove')
        or AdminUI.CanUseOnTarget('economy.tokens.add') or AdminUI.CanUseOnTarget('economy.tokens.remove')
        or AdminUI.CanUseOnTarget('economy.xp.add') or AdminUI.CanUseOnTarget('economy.xp.remove')
        or AdminUI.CanUseOnTarget('character.restore_model') then
        AdminUI.AddButton(page, AdminTranslate('character_and_economy'), function()
            AdminUI.OpenCharacterAdministration()
        end)
    end

    if AdminUI.CanUsePlayerStatus(false) then
        AdminUI.AddButton(page, AdminTranslate('player_status'), function()
            AdminUI.OpenBoosters(false)
        end)
    end

    if AdminUI.CanUseOnTarget('ped.change') or AdminUI.CanUseOnTarget('troll.make_ped_giant') then
        AdminUI.AddButton(page, AdminTranslate('appearance'), function()
            AdminUI.OpenAppearance('selected_player')
        end)
    end

    if AdminUI.CanUseSpecialEffects() then
        AdminUI.AddButton(page, AdminTranslate('special_effects'), function()
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
