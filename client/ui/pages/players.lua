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

    if AdminUI.CanUseOnTarget('staff.role.assign') then
        AdminUI.AddButton(page, AdminTranslate('staff_role'), function()
            AdminStaff.Request(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUseOnTarget('player.go_to') or AdminUI.CanUseOnTarget('player.bring')
        or AdminUI.CanUseOnTarget('player.send_back') or AdminUI.CanUseOnTarget('player.spectate') then
        AdminUI.AddButton(page, AdminTranslate('teleportation'), AdminUI.OpenPlayerManagement)
    end

    if AdminUI.CanUseOnTarget('economy.dollars.add') or AdminUI.CanUseOnTarget('economy.dollars.remove')
        or AdminUI.CanUseOnTarget('economy.gold.add') or AdminUI.CanUseOnTarget('economy.gold.remove')
        or AdminUI.CanUseOnTarget('economy.tokens.add') or AdminUI.CanUseOnTarget('economy.tokens.remove')
        or AdminUI.CanUseOnTarget('economy.xp.add') or AdminUI.CanUseOnTarget('economy.xp.remove')
        or AdminUI.CanUseOnTarget('character.restore_model') or AdminUI.CanUseOnTarget('inventory.give') then
        AdminUI.AddButton(page, AdminTranslate('character_management'), AdminUI.OpenCharacterManagement)
    end


    if AdminUI.CanUsePlayerStatus(false) or AdminUI.CanUseOnTarget('ped.change')
        or AdminUI.CanUseOnTarget('troll.make_ped_giant') or AdminUI.CanUseSpecialEffects() then
        AdminUI.AddButton(page, AdminTranslate('player_tools'), AdminUI.OpenSelectedPlayerTools)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        if AdminUI.playerParent == 'player_search_results' then
            AdminUI.OpenPlayerSearchResults()
        else
            AdminUI.OpenPlayers()
        end
    end)

    AdminUI.OpenPage('selected_player')
end

function AdminUI.OpenPlayers()
    if not AdminUI.CanUse('players.view') then return end
    local page = AdminUI.RegisterPage('players')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('players_header'))

    if AdminUI.CanUse('moderation.search') then
        local query = AdminPlayerDirectory.query or ''
        AdminUI.AddInput(page, AdminTranslate('player_search'), AdminTranslate('required'), function(data)
            query = data.value
        end, query)
        local roleOptions = { { display = AdminTranslate('all_roles'), value = false } }
        local selectedRole = 0
        for _, role in ipairs(AdminPlayerDirectory.roles) do
            local roleId = tonumber(role.id)
            roleOptions[#roleOptions + 1] = {
                display = ('%s (%s)'):format(tostring(role.name), tostring(role.level)),
                value = roleId
            }
            if tonumber(AdminPlayerDirectory.roleFilterId) == roleId then selectedRole = #roleOptions - 1 end
        end
        AdminUI.AddArrows(page, AdminTranslate('role_filter'), roleOptions, selectedRole, function(data)
            AdminPlayerDirectory.roleFilterId = data.value.value or nil
        end)
        AdminUI.AddButton(page, AdminTranslate('search'), function()
            if not AdminModeration.SearchPlayers(query) then
                Feather.Notify.RightNotify(AdminTranslate('invalid_player_search'), 3000)
            end
        end)
        AdminUI.AddText(page, AdminTranslate('player_search_help'))
        AdminUI.AddLine(page)
    end

    table.sort(ClientAllPlayers, function(left, right)
        local leftName = tostring(left.characterName or ''):lower()
        local rightName = tostring(right.characterName or ''):lower()
        if leftName == rightName then return left.serverId < right.serverId end
        return leftName < rightName
    end)
    for _, player in ipairs(ClientAllPlayers) do
        local target = player.serverId
        local name = player.characterName or AdminTranslate('not_available')
        local safeName = tostring(name):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
            :gsub('"', '&quot;'):gsub("'", '&#39;')
        local html = ([=[
            <div style="font-size:1.65vmin;line-height:1.25;">%s</div>
            <div style="font-size:1.2vmin;line-height:1.25;color:#c0c0c0;">%s: %s</div>
        ]=]):format(safeName, ('%s | %s'):format(AdminTranslate('online'), AdminTranslate('server_id')), target)
        AdminUI.AddHtmlButton(page, html, function()
            AdminUI.playerParent = 'players'
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

local function directoryButton(target)
    local name = target.characterName or target.playerName or AdminTranslate('not_available')
    local status = AdminTranslate(target.isOnline and 'online' or 'offline')
    local detail = target.isOnline
        and ('%s | %s: %s'):format(status, AdminTranslate('server_id'), tostring(target.serverId))
        or ('%s | %s: %s'):format(status, AdminTranslate('character_id'), tostring(target.characterId))
    local safeName = tostring(name):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
        :gsub('"', '&quot;'):gsub("'", '&#39;')
    return ([=[
        <div style="font-size:1.65vmin;line-height:1.25;">%s</div>
        <div style="font-size:1.15vmin;line-height:1.25;color:#c0c0c0;">%s</div>
    ]=]):format(safeName, detail)
end

function AdminUI.OpenPlayerSearchResults()
    local page = AdminUI.RegisterPage('player_search_results')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_search_results'))
    if #AdminPlayerDirectory.results == 0 then
        AdminUI.AddText(page, AdminTranslate('no_search_results'))
    else
        for _, entry in ipairs(AdminPlayerDirectory.results) do
            local target = entry
            AdminUI.AddHtmlButton(page, directoryButton(target), function()
                if target.isOnline then
                    AdminUI.playerParent = 'player_search_results'
                    AdminUI.SetTarget(target.serverId)
                    AdminUI.OpenSelectedPlayer()
                else
                    AdminUI.OpenOfflinePlayer(target)
                end
            end)
        end
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPlayers)
    AdminUI.OpenPage('player_search_results')
end


function AdminUI.OpenOfflinePlayer(target)
    if type(target) == 'table' then AdminPlayerDirectory.selected = target end
    target = AdminPlayerDirectory.selected
    if type(target) ~= 'table' then return end
    local page = AdminUI.RegisterPage('offline_player')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_profile'))
    AdminUI.AddText(page, table.concat({
        ('%s: %s'):format(AdminTranslate('status'), AdminTranslate('offline')),
        ('%s: %s'):format(AdminTranslate('account_name'), tostring(target.playerName or AdminTranslate('not_available'))),
        ('%s: %s'):format(AdminTranslate('character_name'), tostring(target.characterName or AdminTranslate('not_available'))),
        ('%s: %s'):format(AdminTranslate('character_id'), tostring(target.characterId or AdminTranslate('not_available'))),
        ('%s: %s (%s)'):format(AdminTranslate('role_name'),
            tostring(target.roleName or AdminTranslate('not_available')), tostring(target.roleLevel or 0))
    }, '\n'))
    if AdminUI.CanUse('moderation.view') then
        AdminUI.AddButton(page, AdminTranslate('moderation'), function()
            AdminModeration.SelectOffline(target)
        end)
    end
    if AdminUI.CanUse('staff.role.assign') and target.characterId then
        AdminUI.AddButton(page, AdminTranslate('staff_role'), function()
            AdminStaff.OpenCharacter(target)
        end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPlayerSearchResults)
    AdminUI.OpenPage('offline_player')
end

function AdminUI.OpenCharacterManagement()
    local page = AdminUI.RegisterPage('character_management')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('character_management'))
    local canManageBalances = AdminUI.CanUseOnTarget('economy.dollars.add')
        or AdminUI.CanUseOnTarget('economy.dollars.remove') or AdminUI.CanUseOnTarget('economy.gold.add')
        or AdminUI.CanUseOnTarget('economy.gold.remove') or AdminUI.CanUseOnTarget('economy.tokens.add')
        or AdminUI.CanUseOnTarget('economy.tokens.remove') or AdminUI.CanUseOnTarget('economy.xp.add')
        or AdminUI.CanUseOnTarget('economy.xp.remove')
    if canManageBalances then
        AdminUI.AddButton(page, AdminTranslate('balances_and_economy'), function()
            AdminCharacter.RequestEconomySummary(AdminUI.GetTarget())
        end)
    end
    if AdminUI.CanUseOnTarget('inventory.give') then
        AdminUI.AddButton(page, AdminTranslate('inventory'), AdminInventory.RequestCatalog)
    end
    if AdminUI.CanUseOnTarget('character.restore_model') then
        AdminUI.AddButton(page, AdminTranslate('restore_character_appearance'), function()
            -- The server sends the authoritative success/failure message.
            AdminCharacter.RestoreAppearance(AdminUI.GetTarget())
        end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenSelectedPlayer)
    AdminUI.OpenPage('character_management')
end

function AdminUI.OpenSelectedPlayerTools()
    local target = AdminUI.GetTarget()
    if not target then return end
    local page = AdminUI.RegisterPage('selected_player_tools')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_tools'))
    if AdminUI.CanUsePlayerStatus(false) then
        AdminUI.AddButton(page, AdminTranslate('player_status'), function()
            AdminUI.SetTarget(target)
            AdminUI.OpenBoosters(false)
        end)
    end
    if AdminUI.CanUseOnTarget('ped.change') or AdminUI.CanUseOnTarget('troll.make_ped_giant') then
        AdminUI.AddButton(page, AdminTranslate('appearance'), function()
            AdminUI.SetTarget(target)
            AdminUI.OpenAppearance('selected_player_tools', target)
        end)
    end
    if AdminUI.CanUseSpecialEffects() then
        AdminUI.AddLine(page)
        AdminUI.AddButton(page, AdminTranslate('special_effects'), function()
            AdminUI.SetTarget(target)
            AdminUI.OpenTrolls()
        end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.SetTarget(target)
        AdminUI.OpenSelectedPlayer()
    end)
    AdminUI.OpenPage('selected_player_tools')
end
