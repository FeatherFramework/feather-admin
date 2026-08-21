function AdminStaff.Request(playerId)
    if not AdminUI.CanUse('staff.view') then return false end
    AdminStaff.origin = 'online'
    AdminStaff.selectedTarget = tonumber(playerId)
    Feather.RPC.Notify('feather-admin:staff:list', { playerId = AdminStaff.selectedTarget })
    return true
end

function AdminStaff.Search(query, page)
    if not AdminUI.CanUse('staff.search') or type(query) ~= 'string' then return false end
    query = query:match('^%s*(.-)%s*$')
    local minimum = math.max(1, tonumber(Config.staff.minSearchLength) or 2)
    if #query < minimum or #query > 100 then return false end
    AdminStaff.searchQuery = query
    AdminStaff.searchPage = math.max(1, math.floor(tonumber(page) or 1))
    Feather.RPC.Notify('feather-admin:staff:search', {
        query = query, page = AdminStaff.searchPage, roleId = AdminStaff.roleFilterId
    })
    return true
end

function AdminStaff.Assign(characterId, roleId, reason)
    if not AdminUI.CanUse('staff.role.assign') then return false end
    Feather.RPC.Notify('feather-admin:staff:role:assign', {
        characterId = characterId, roleId = roleId, reason = reason
    })
    return true
end

function AdminStaff.RequestHistory(characterId, page)
    if not AdminUI.CanUse('staff.history') then return false end
    AdminStaff.historyPage = math.max(1, math.floor(tonumber(page) or 1))
    Feather.RPC.Notify('feather-admin:staff:history', {
        characterId = characterId, page = AdminStaff.historyPage
    })
    return true
end

RegisterNetEvent('feather-admin:staff:list:result', function(roles, players, messageKey)
    if messageKey then
        AdminStaff.selectedTarget = nil
        return Feather.Notify.RightNotify(AdminTranslate(messageKey), 3000)
    end
    AdminStaff.roles = type(roles) == 'table' and roles or {}
    AdminStaff.players = type(players) == 'table' and players or {}
    if AdminStaff.selectedTarget then
        local requestedId = AdminStaff.selectedTarget
        for _, player in ipairs(AdminStaff.players) do
            if tonumber(player.serverId) == requestedId then
                AdminStaff.selectedTarget = player
                AdminStaff.reason = ''
                return AdminUI.OpenStaffRole()
            end
        end
        AdminStaff.selectedTarget = nil
        return Feather.Notify.RightNotify(AdminTranslate('player_not_online'), 3000)
    end
    AdminUI.OpenStaffManagement()
end)

RegisterNetEvent('feather-admin:staff:search:result', function(results, page, hasNext, messageKey)
    if messageKey then return Feather.Notify.RightNotify(AdminTranslate(messageKey), 3000) end
    AdminStaff.results = type(results) == 'table' and results or {}
    AdminStaff.searchPage = tonumber(page) or 1
    AdminStaff.searchHasNext = hasNext == true
    AdminUI.OpenStaffSearchResults()
end)

RegisterNetEvent('feather-admin:staff:history:result', function(rows, page, hasNext, messageKey)
    if messageKey then return Feather.Notify.RightNotify(AdminTranslate(messageKey), 3000) end
    AdminStaff.history = type(rows) == 'table' and rows or {}
    AdminStaff.historyPage = tonumber(page) or 1
    AdminStaff.historyHasNext = hasNext == true
    AdminUI.OpenStaffRoleHistory()
end)

RegisterNetEvent('feather-admin:staff:role:result', function(succeeded, messageKey)
    Feather.Notify.RightNotify(AdminTranslate(messageKey or 'staff_role_update_failed'), 3500)
    if not succeeded then return end
    AdminStaff.reason = ''
    if AdminStaff.origin == 'search' and AdminStaff.searchQuery then
        AdminStaff.Search(AdminStaff.searchQuery, AdminStaff.searchPage)
    else
        AdminStaff.Request()
    end
end)

RegisterNetEvent('feather-admin:staff:role:updated', function(messageKey)
    Feather.Notify.RightNotify(AdminTranslate(messageKey or 'your_staff_role_changed'), 3500)
end)
