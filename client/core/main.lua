local AdminKeyListener = nil

RegisterNetEvent('feather-admin:players:sync', function(players, roles)
    ClientAllPlayers = players or {}
    AdminPlayerDirectory.roles = type(roles) == 'table' and roles or AdminPlayerDirectory.roles
    if InMenu and AdminUI.currentPage == 'players' then
        AdminUI.OpenPlayers()
    end
end)

CreateThread(function()
    if Config.controls.enabled then
        AdminKeyListener = Feather.Keys:RegisterListener(Config.controls.openMenu, function()
            if not InMenu then
                Feather.RPC.Notify('feather-admin:access:request', {})
            end
        end)
    end

    if Config.commands.enabled then
        local command = Config.commands.openMenu
        local suggestion = AdminTranslate(Config.commands.suggestionKey)
        Feather.Command.Register(command, suggestion, function()
            if not InMenu then
                Feather.RPC.Notify('feather-admin:access:request', {})
            end
        end)
    end
end)

RegisterNetEvent('feather-admin:access:result', function(authorized, permissions)
    AdminPermissions = type(permissions) == 'table' and permissions or {}
    if not authorized or InMenu then return end

    if AdminUI.CanUse('players.view') then
        Feather.RPC.Notify('feather-admin:players:request', {})
    end

    AdminUI.OpenMain()
end)

RegisterNetEvent('feather-admin:access:permissions', function(authorized, permissions)
    AdminPermissions = authorized and type(permissions) == 'table' and permissions or {}
    if not authorized and InMenu then AdminUI.Close() end
end)

AddEventHandler('Feather:Character:Spawned', function()
    Feather.RPC.Notify('feather-admin:access:refresh', {})
end)

AddEventHandler('Feather:Character:Logout', function()
    AdminPermissions = {}
    ClientAllPlayers = {}
    AdminPlayerDirectory.query = ''
    AdminPlayerDirectory.results = {}
    AdminPlayerDirectory.selected = nil
    AdminPlayerDirectory.roles = {}
    AdminPlayerDirectory.roleFilterId = nil
    AdminStaff.roles = {}
    AdminStaff.players = {}
    AdminStaff.results = {}
    AdminStaff.selectedTarget = nil
    AdminStaff.pendingTarget = nil
    AdminStaff.selectedRole = nil
    AdminStaff.roleFilterId = nil
    AdminStaff.reason = ''
    AdminStaff.searchQuery = nil
    AdminStaff.searchPage = 1
    AdminStaff.searchHasNext = false
    AdminStaff.history = {}
    AdminStaff.historyPage = 1
    AdminStaff.historyHasNext = false
    AdminStaff.origin = 'online'
    AdminServerOverview.snapshot = nil
    AdminAnnouncements.form = { title = '', message = '' }
    AdminAnnouncements.pending = false
    AdminAnnouncements.requestSession = AdminAnnouncements.requestSession + 1
    AdminUI.targetPlayer = nil
    AdminUI.toggleStates = {}
    AdminUI.pendingToggles = {}
    if InMenu then AdminUI.Close() end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if AdminKeyListener then AdminKeyListener:RemoveListener() end
    AdminKeyListener = nil
end)
