local selectedActions = {
    teleportation = { 'player.go_to', 'player.bring', 'player.send_back', 'player.spectate' },
    character = {
        'economy.dollars.add', 'economy.dollars.remove', 'economy.gold.add', 'economy.gold.remove',
        'economy.tokens.add', 'economy.tokens.remove', 'economy.xp.add', 'economy.xp.remove',
        'character.restore_model'
    },
    status = {
        'booster.invincibility', 'booster.invisibility', 'booster.infinite_stamina', 'booster.heal',
        'booster.revive', 'booster.kill', 'booster.disable_fow', 'troll.freeze', 'troll.handcuff'
    },
    appearance = { 'ped.change', 'troll.make_ped_giant' },
    effects = {
        'troll.lightning_strike', 'troll.teleport_to_heaven', 'troll.cage',
        'troll.force_cinematic_camera', 'troll.hostile_ped_army', 'troll.kick_from_vehicle',
        'troll.hostile_bear', 'troll.lag'
    }
}

function AdminUI.OpenSelectedPlayer()
    if not AdminUI.CanUse('players.view') then return end
    local page = AdminUI.RegisterPage('selected_player')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('selected_player_header'))
    local canInventory = AdminUI.CanUse('inventory.inspect') or AdminUI.CanUseOnTarget('inventory.give')
    local canWeapons = AdminUI.CanUse('weapons.issue') or AdminUI.CanUse('weapons.ammo.grant')
    if canInventory or canWeapons then AdminUI.BeginSection(page, AdminTranslate('inventory_and_equipment'), true) end
    if AdminUI.CanUse('inventory.inspect') or AdminUI.CanUseOnTarget('inventory.give') then
        AdminUI.AddButton(page, AdminTranslate('inventory'), function()
            AdminInventory.SetOnlineTarget(AdminUI.GetTarget())
            AdminUI.OpenInventoryActions()
        end)
    end
    if AdminUI.CanUse('weapons.issue') or AdminUI.CanUse('weapons.ammo.grant') then
        AdminUI.AddButton(page, AdminTranslate('weapons_and_ammo'), function()
            AdminWeapons.SetOnlineTarget(AdminUI.GetTarget())
            AdminWeapons.RequestCatalog()
        end)
    end

    AdminUI.EndSection(page)
    if AdminUI.CanUse('player.info') or AdminUI.CanUse('moderation.view') or AdminUI.CanUse('notes.view')
        or AdminUI.CanUse('cases.view') then AdminUI.BeginSection(page, AdminTranslate('player_overview'), true) end
    if AdminUI.CanUse('player.info') then
        AdminUI.AddButton(page, AdminTranslate('player_information'), function()
            if not AdminUI.RequireUseOnTarget('player.info') then return end
            AdminPlayerManagement.RequestInfo(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUse('moderation.view') then
        AdminUI.AddButton(page, AdminTranslate('moderation'), function()
            AdminModeration.SelectOnline(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUse('notes.view') then
        AdminUI.AddButton(page, AdminTranslate('player_notes'), function()
            AdminPlayerNotes.OpenOnline(AdminUI.GetTarget())
        end)
    end

    if AdminUI.CanUse('cases.create') and AdminUI.CanUse('cases.view') and AdminUI.CanUse('cases.claim') then
        AdminUI.AddButton(page, AdminChatTranslate('chat_case_header'), AdminUI.OpenChatConversationCreate)
    end
    if AdminUI.CanUse('cases.view') then
        AdminUI.AddButton(page, AdminChatTranslate('chat_case_list'), function() AdminChatCases.RequestList(0) end)
    end

    AdminUI.EndSection(page)
    if AdminUI.CanUse('staff.role.assign') then
        AdminUI.BeginSection(page, AdminTranslate('staff_oversight'), false)
        AdminUI.AddButton(page, AdminTranslate('staff_role'), function()
            if not AdminUI.RequireUseOnTarget('staff.role.assign') then return end
            AdminStaff.Request(AdminUI.GetTarget())
        end)
        AdminUI.EndSection(page)
    end

    if AdminUI.CanUseAnyAction(selectedActions.teleportation) or AdminUI.CanUseAnyAction(selectedActions.character)
        or AdminUI.CanUseAnyAction(selectedActions.status) or AdminUI.CanUseAnyAction(selectedActions.appearance) then
        AdminUI.BeginSection(page, AdminTranslate('player_tools'), true)
    end
    if AdminUI.CanUseAnyAction(selectedActions.teleportation) then
        AdminUI.AddButton(page, AdminTranslate('teleportation'), function()
            if AdminUI.RequireAnyUseOnTarget(selectedActions.teleportation) then AdminUI.OpenPlayerManagement() end
        end)
    end

    if AdminUI.CanUseAnyAction(selectedActions.character) then
        AdminUI.AddButton(page, AdminTranslate('character_management'), function()
            if AdminUI.RequireAnyUseOnTarget(selectedActions.character) then AdminUI.OpenCharacterManagement() end
        end)
    end

    if AdminUI.CanUseAnyAction(selectedActions.status) then
        AdminUI.AddButton(page, AdminTranslate('player_status'), function()
            if AdminUI.RequireAnyUseOnTarget(selectedActions.status) then AdminUI.OpenBoosters(false) end
        end)
    end
    if AdminUI.CanUseAnyAction(selectedActions.appearance) then
        AdminUI.AddButton(page, AdminTranslate('appearance'), function()
            if AdminUI.RequireAnyUseOnTarget(selectedActions.appearance) then AdminUI.OpenAppearance('selected_player') end
        end)
    end
    AdminUI.EndSection(page)
    if AdminUI.CanUseAnyAction(selectedActions.effects) then
        AdminUI.BeginSection(page, AdminTranslate('special_effects'), false)
        AdminUI.AddButton(page, AdminTranslate('special_effects'), function()
            if AdminUI.RequireAnyUseOnTarget(selectedActions.effects) then AdminUI.OpenTrolls() end
        end)
        AdminUI.EndSection(page)
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

function AdminUI.OpenPlayers(pageNumber)
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
            local roleKey = role.key
            roleOptions[#roleOptions + 1] = {
                display = tostring(role.name),
                value = roleKey
            }
            if AdminPlayerDirectory.roleFilterId == roleKey then selectedRole = #roleOptions - 1 end
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

    local filter = AdminUI.onlinePlayerFilter or ''
    AdminUI.AddInput(page, AdminTranslate('filter_online_players'), AdminTranslate('player_search'), function(data)
        filter = tostring(data.value or '')
    end, filter)
    AdminUI.AddButton(page, AdminTranslate('search'), function()
        AdminUI.onlinePlayerFilter = filter
        AdminUI.OpenPlayers(1)
    end)
    local players = {}
    for _, player in ipairs(ClientAllPlayers or {}) do
        if filter == '' or tostring(player.characterName or ''):lower():find(filter:lower(), 1, true)
            or tostring(player.serverId) == filter then players[#players + 1] = player end
    end
    table.sort(players, function(left, right)
        local leftName = tostring(left.characterName or ''):lower()
        local rightName = tostring(right.characterName or ''):lower()
        if leftName == rightName then return left.serverId < right.serverId end
        return leftName < rightName
    end)
    local total = math.max(1, math.ceil(#players / 15))
    local current = math.min(total, math.max(1, math.floor(tonumber(pageNumber) or AdminUI.onlinePlayerPage or 1)))
    AdminUI.onlinePlayerPage = current
    AdminUI.AddText(page, ('%s: %d / %d | %d'):format(AdminTranslate('page'), current, total, #players))
    if #players == 0 then AdminUI.AddText(page, AdminTranslate('no_matching_players')) end
    for index = (current - 1) * 15 + 1, math.min(current * 15, #players) do
        local player = players[index]
        local target = player.serverId
        local name = player.characterName or AdminTranslate('not_available')
        local label = ('%s | %s: %s'):format(name, AdminTranslate('server_id'), target)
        AdminUI.AddButton(page, label, function()
            AdminUI.playerParent = 'players'
            AdminUI.SetTarget(target)
            AdminUI.OpenSelectedPlayer()
        end)
    end

    AdminUI.AddPagination(page, current, total, AdminUI.OpenPlayers)
    AdminUI.AddButton(page, AdminTranslate('refresh'), function()
        Feather.RPC.Notify('feather-admin:players:request', {})
        AdminUI.OpenPlayers(current)
    end)

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
    return ('%s | %s'):format(name, detail)
end

function AdminUI.OpenPlayerSearchResults()
    local page = AdminUI.RegisterPage('player_search_results')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('player_search_results'))
    if #AdminPlayerDirectory.results == 0 then
        AdminUI.AddText(page, AdminTranslate('no_search_results'))
    else
        for _, entry in ipairs(AdminPlayerDirectory.results) do
            local target = entry
            AdminUI.AddButton(page, directoryButton(target), function()
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
        ('%s: %s'):format(AdminTranslate('role_name'),
            tostring(target.roleName or AdminTranslate('not_available')))
    }, '\n'))
    if AdminUI.CanUse('moderation.view') then
        AdminUI.AddButton(page, AdminTranslate('moderation'), function()
            AdminModeration.SelectOffline(target)
        end)
    end
    if AdminUI.CanUse('notes.view') and target.accountId then
        AdminUI.AddButton(page, AdminTranslate('player_notes'), function()
            AdminPlayerNotes.OpenTarget(target)
        end)
    end
    if AdminUI.CanUse('inventory.inspect') and target.accountId and target.characterId then
        AdminUI.AddButton(page, AdminTranslate('inventory'), function()
            AdminInventory.SetTarget(target)
            AdminUI.OpenInventoryActions()
        end)
    end
    if (AdminUI.CanUse('weapons.issue') or AdminUI.CanUse('weapons.ammo.grant'))
        and target.accountId and target.characterId then
        AdminUI.AddButton(page, AdminTranslate('weapons_and_ammo'), function()
            AdminWeapons.SetTarget(target)
            AdminWeapons.RequestCatalog()
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
    if AdminUI.CanUseAnyAction(selectedActions.status) then
        AdminUI.AddButton(page, AdminTranslate('player_status'), function()
            if not AdminUI.RequireAnyUseOnTarget(selectedActions.status, target) then return end
            AdminUI.SetTarget(target)
            AdminUI.OpenBoosters(false)
        end)
    end
    if AdminUI.CanUseAnyAction(selectedActions.appearance) then
        AdminUI.AddButton(page, AdminTranslate('appearance'), function()
            if not AdminUI.RequireAnyUseOnTarget(selectedActions.appearance, target) then return end
            AdminUI.SetTarget(target)
            AdminUI.OpenAppearance('selected_player_tools', target)
        end)
    end
    if AdminUI.CanUseAnyAction(selectedActions.effects) then
        AdminUI.AddLine(page)
        AdminUI.AddButton(page, AdminTranslate('special_effects'), function()
            if not AdminUI.RequireAnyUseOnTarget(selectedActions.effects, target) then return end
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
