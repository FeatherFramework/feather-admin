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

local function openTarget(target, origin)
    AdminStaff.selectedTarget = target
    AdminStaff.origin = origin
    AdminUI.SetTarget(target.serverId)
    AdminUI.OpenStaffRole()
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
        AdminUI.AddButton(page, AdminTranslate('search_staff_characters'), function()
            if not AdminStaff.Search(query) then
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
            AdminUI.AddButton(page, ('%s - %s'):format(playerName(target), roleLabel(target)), function()
                openTarget(target, 'online')
            end)
        end
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage('staff_management')
end

function AdminUI.OpenStaffSearchResults()
    if not AdminUI.CanUse('staff.search') then return end
    local page = AdminUI.RegisterPage('staff_search_results')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('search_staff_characters'))

    if #AdminStaff.results == 0 then
        AdminUI.AddText(page, AdminTranslate('no_staff_search_results'))
    else
        for _, entry in ipairs(AdminStaff.results) do
            local target = entry
            local label = ('%s - %s - %s'):format(playerName(target), roleLabel(target), targetStatus(target))
            AdminUI.AddButton(page, label, function()
                openTarget(target, 'search')
            end)
        end
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
        if tonumber(role.id) == tonumber(target.roleId) then selectedIndex = #options - 1 end
    end
    if #options == 0 then
        AdminUI.AddText(page, AdminTranslate('no_assignable_roles'))
    else
        AdminStaff.selectedRole = options[selectedIndex + 1].value
        AdminUI.AddArrows(page, AdminTranslate('new_role'), options, selectedIndex, function(data)
            AdminStaff.selectedRole = data.value.value
        end)
        AdminUI.AddButton(page, AdminTranslate('continue'), AdminUI.OpenStaffRoleConfirmation)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        if AdminStaff.origin == 'search' then
            AdminUI.OpenStaffSearchResults()
        else
            AdminStaff.Request()
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
        ('%s: %s'):format(AdminTranslate('new_role'), roleLabel(role))
    }, '\n'))
    AdminUI.AddButton(page, AdminTranslate('confirm_action'), function()
        AdminStaff.Assign(target.characterId, role.id)
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenStaffRole)
    AdminUI.OpenPage('staff_role_confirmation')
end
