local function escape(value)
    return tostring(value or ''):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
        :gsub('"', '&quot;'):gsub("'", '&#39;')
end

local function playerName(target)
    local name = tostring(target.characterName or '')
    if name == '' then name = tostring(target.serverName or target.playerName or AdminTranslate('not_available')) end
    return name
end

local function roleLabel(role)
    local name = role.name or role.roleName or AdminTranslate('not_available')
    local level = role.level or role.roleLevel or 0
    return ('%s (%s)'):format(tostring(name), tostring(level))
end

local function targetStatus(target)
    return AdminTranslate(target.isOnline and 'online' or 'offline')
end

local function targetButton(target)
    local account = target.playerName or target.serverName or AdminTranslate('not_available')
    local detail = ('%s: %s | %s: %s | %s | %s'):format(AdminTranslate('character_id'),
        tostring(target.characterId), AdminTranslate('account_name'), account, roleLabel(target), targetStatus(target))
    return ([=[
        <div style="font-size:1.65vmin;line-height:1.25;">%s</div>
        <div style="font-size:1.1vmin;line-height:1.25;color:#c0c0c0;">%s</div>
    ]=]):format(escape(playerName(target)), escape(detail))
end

local function openTarget(target, origin)
    AdminStaff.selectedTarget = target
    AdminStaff.origin = origin
    AdminStaff.reason = ''
    AdminUI.SetTarget(target.serverId)
    AdminUI.OpenStaffRole()
end

local function roleFilterOptions()
    local options = { { display = AdminTranslate('all_roles'), value = false } }
    local selected = 0
    for _, role in ipairs(AdminStaff.roles) do
        options[#options + 1] = { display = roleLabel(role), value = role.key }
        if AdminStaff.roleFilterId == role.key then selected = #options - 1 end
    end
    return options, selected
end

function AdminUI.OpenStaffManagement()
    if not AdminUI.CanUse('staff.view') then return end
    local page = AdminUI.RegisterPage('staff_management')
    local query = AdminStaff.searchQuery or ''
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('staff_management_header'))

    if AdminUI.CanUse('staff.search') then
        AdminUI.AddInput(page, AdminTranslate('staff_search'), AdminTranslate('required'), function(data)
            query = data.value
        end, query)
        local filters, selected = roleFilterOptions()
        AdminUI.AddArrows(page, AdminTranslate('role_filter'), filters, selected, function(data)
            AdminStaff.roleFilterId = data.value.value or nil
        end)
        AdminUI.AddButton(page, AdminTranslate('search_staff_characters'), function()
            if not AdminStaff.Search(query, 1) then
                Feather.Notify.RightNotify(AdminTranslate('invalid_staff_search'), 3000)
            end
        end)
        AdminUI.AddText(page, AdminTranslate('staff_search_help'))
        AdminUI.AddLine(page)
    end

    table.sort(AdminStaff.players, function(left, right)
        return playerName(left):lower() < playerName(right):lower()
    end)
    if #AdminStaff.players == 0 then
        AdminUI.AddText(page, AdminTranslate('no_staff_players'))
    else
        for _, entry in ipairs(AdminStaff.players) do
            local target = entry
            AdminUI.AddHtmlButton(page, targetButton(target), function()
                openTarget(target, 'staff_management')
            end)
        end
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenNavigationSection('staff_oversight')
    end)
    AdminUI.OpenPage('staff_management')
end

AdminUI.RegisterNavigationItem('staff_oversight', {
    key = 'staff_directory',
    labelKey = 'staff_directory',
    order = 10,
    permission = 'staff.view',
    open = function() AdminStaff.Request() end
})

function AdminUI.OpenStaffSearchResults()
    if not AdminUI.CanUse('staff.search') then return end
    local page = AdminUI.RegisterPage('staff_search_results')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('search_staff_characters'))
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('page'), AdminStaff.searchPage))

    if #AdminStaff.results == 0 then
        AdminUI.AddText(page, AdminTranslate('no_staff_search_results'))
    else
        for _, entry in ipairs(AdminStaff.results) do
            local target = entry
            AdminUI.AddHtmlButton(page, targetButton(target), function()
                openTarget(target, 'staff_search')
            end)
        end
    end

    if AdminStaff.searchPage > 1 then
        AdminUI.AddButton(page, AdminTranslate('previous_page'), function()
            AdminStaff.Search(AdminStaff.searchQuery, AdminStaff.searchPage - 1)
        end)
    end
    if AdminStaff.searchHasNext then
        AdminUI.AddButton(page, AdminTranslate('next_page'), function()
            AdminStaff.Search(AdminStaff.searchQuery, AdminStaff.searchPage + 1)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminStaff.Request()
    end)
    AdminUI.OpenPage('staff_search_results')
end

function AdminUI.OpenStaffRole()
    local target = AdminStaff.selectedTarget
    if type(target) ~= 'table' or not AdminUI.CanUse('staff.role.assign') then return end
    local page = AdminUI.RegisterPage('staff_role')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('staff_role'))
    local details = {
        ('%s: %s'):format(AdminTranslate('player'), playerName(target)),
        ('%s: %s'):format(AdminTranslate('account_name'), tostring(target.playerName or target.serverName
            or AdminTranslate('not_available'))),
        ('%s: %s'):format(AdminTranslate('character_id'), tostring(target.characterId)),
        ('%s: %s'):format(AdminTranslate('current_role'), roleLabel(target)),
        ('%s: %s'):format(AdminTranslate('status'), targetStatus(target))
    }
    if target.serverId then
        table.insert(details, 2, ('%s: %s'):format(AdminTranslate('server_id'), tostring(target.serverId)))
    end
    AdminUI.AddText(page, table.concat(details, '\n'))

    local options, selectedIndex = {}, 0
    for _, role in ipairs(AdminStaff.roles) do
        options[#options + 1] = { display = roleLabel(role), value = role }
        if role.key == target.roleKey then selectedIndex = #options - 1 end
    end
    if #options == 0 then
        AdminUI.AddText(page, AdminTranslate('no_assignable_roles'))
    else
        AdminStaff.selectedRole = options[selectedIndex + 1].value
        AdminUI.AddArrows(page, AdminTranslate('new_role'), options, selectedIndex, function(data)
            AdminStaff.selectedRole = data.value.value
        end)
        AdminUI.AddInput(page, AdminTranslate('role_change_reason'), AdminTranslate('required'), function(data)
            AdminStaff.reason = data.value
        end, AdminStaff.reason)
        AdminUI.AddButton(page, AdminTranslate('continue'), function()
            local reason = tostring(AdminStaff.reason or ''):match('^%s*(.-)%s*$')
            local maximum = math.min(tonumber(Config.staff.maxReasonLength) or 200, 200)
            if reason == '' or #reason > maximum then
                return Feather.Notify.RightNotify(AdminTranslate('invalid_staff_role_reason'), 3000)
            end
            AdminStaff.reason = reason
            AdminUI.OpenStaffRoleConfirmation()
        end)
    end
    if AdminUI.CanUse('staff.history') then
        AdminUI.AddButton(page, AdminTranslate('role_history'), function()
            AdminStaff.RequestHistory(target.characterId, 1)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        if AdminStaff.origin == 'directory' then
            AdminUI.OpenOfflinePlayer(AdminStaff.selectedTarget)
        elseif AdminStaff.origin == 'staff_management' then
            AdminUI.OpenStaffManagement()
        elseif AdminStaff.origin == 'staff_search' then
            AdminUI.OpenStaffSearchResults()
        else
            AdminUI.OpenSelectedPlayer()
        end
    end)
    AdminUI.OpenPage('staff_role')
end

function AdminUI.OpenStaffRoleConfirmation()
    local target, role = AdminStaff.selectedTarget, AdminStaff.selectedRole
    if type(target) ~= 'table' or type(role) ~= 'table'
        or not AdminUI.CanUse('staff.role.assign') then return end
    local page = AdminUI.RegisterPage('staff_role_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_role_assignment'))
    AdminUI.AddText(page, table.concat({
        ('%s: %s'):format(AdminTranslate('player'), playerName(target)),
        ('%s: %s'):format(AdminTranslate('character_id'), tostring(target.characterId)),
        ('%s: %s'):format(AdminTranslate('current_role'), roleLabel(target)),
        ('%s: %s'):format(AdminTranslate('new_role'), roleLabel(role)),
        ('%s: %s'):format(AdminTranslate('reason'), tostring(AdminStaff.reason))
    }, '\n'))
    AdminUI.AddButton(page, AdminTranslate('confirm_action'), function()
        AdminStaff.Assign(target.characterId, role.key, AdminStaff.reason, target.roleRevision)
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenStaffRole)
    AdminUI.OpenPage('staff_role_confirmation')
end


function AdminUI.OpenStaffRoleHistory()
    local target = AdminStaff.selectedTarget
    if type(target) ~= 'table' or not AdminUI.CanUse('staff.history') then return end
    local page = AdminUI.RegisterPage('staff_role_history')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('role_history'))
    AdminUI.AddText(page, ('%s\n%s: %s'):format(playerName(target), AdminTranslate('page'), AdminStaff.historyPage))
    if #AdminStaff.history == 0 then
        AdminUI.AddText(page, AdminTranslate('no_role_history'))
    else
        for _, row in ipairs(AdminStaff.history) do
            local administrator = row.adminCharacterName or row.adminName or AdminTranslate('not_available')
            AdminUI.AddText(page, table.concat({
                ('%s (%s) -> %s (%s)'):format(row.oldRoleName, row.oldRoleLevel,
                    row.newRoleName, row.newRoleLevel),
                ('%s: %s'):format(AdminTranslate('reason'), row.reason),
                ('%s: %s'):format(AdminTranslate('changed_by'), administrator),
                ('%s: %s'):format(AdminTranslate('changed_at'), row.createdAt)
            }, '\n'))
            AdminUI.AddLine(page)
        end
    end
    if AdminStaff.historyPage > 1 then
        AdminUI.AddButton(page, AdminTranslate('previous_page'), function()
            AdminStaff.RequestHistory(target.characterId, AdminStaff.historyPage - 1)
        end)
    end
    if AdminStaff.historyHasNext then
        AdminUI.AddButton(page, AdminTranslate('next_page'), function()
            AdminStaff.RequestHistory(target.characterId, AdminStaff.historyPage + 1)
        end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenStaffRole)
    AdminUI.OpenPage('staff_role_history')
end
