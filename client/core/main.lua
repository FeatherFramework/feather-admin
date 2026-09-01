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
        local registered = exports['feather-toolkit']:RegisterKeyListener(Config.controls.openMenu, function()
            if not InMenu then
                Feather.RPC.Notify('feather-admin:access:request', {})
            end
        end)
        local registeredValue = type(registered) == 'table' and registered.value or nil
        AdminKeyListener = type(registeredValue) == 'table' and registered.ok == true
            and registeredValue.id or nil
    end

    if Config.commands.enabled then
        local command = Config.commands.openMenu
        local suggestion = AdminTranslate(Config.commands.suggestionKey)
        RegisterCommand(command, function()
            if not InMenu then
                Feather.RPC.Notify('feather-admin:access:request', {})
            end
        end, false)
        TriggerEvent('chat:addSuggestion', '/' .. command, suggestion)
    end
end)

RegisterCommand('AdminToolkitContractSmokeTest', function()
    local capabilities = exports['feather-toolkit']:GetCapabilities()
    local control = exports['feather-toolkit']:ResolveControl('PGDN')
    local listener = exports['feather-toolkit']:RegisterKeyListener('PGDN', function() end)
    local listenerValue = type(listener) == 'table' and listener.value or nil
    local removed = type(listenerValue) == 'table' and listener.ok == true
        and exports['feather-toolkit']:RemoveKeyListener(listenerValue.id) or nil
    local tests = {
        { 'toolkit available', type(capabilities) == 'table' and capabilities.ok == true },
        { 'named control', type(control) == 'table' and control.ok == true },
        { 'cross-resource callback', type(listener) == 'table' and listener.ok == true },
        { 'owned listener removed', type(removed) == 'table' and removed.ok == true }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminToolkitContractSmokeTest] %-24s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminToolkitContractSmokeTest] done %d/%d passed'):format(passed, #tests))
end, false)

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
    AdminActiveBans.rows = {}
    AdminActiveBans.query = ''
    AdminActiveBans.page = 1
    AdminActiveBans.hasNext = false
    AdminActiveBans.selected = nil
    AdminModeration.unbanOrigin = nil
    AdminReports.rows = {}
    AdminReports.page = 1
    AdminReports.hasNext = false
    AdminReports.status = 'open'
    AdminReports.selected = nil
    AdminReports.resolution = ''
    AdminCases.rows = {}
    AdminCases.page = 1
    AdminCases.hasNext = false
    AdminCases.status = 'open'
    AdminCases.selected = nil
    AdminCases.links = {}
    AdminCases.activity = {}
    AdminCases.createForm = { title = '', summary = '', priority = 'normal', reportId = nil }
    AdminCases.resolution = ''
    AdminPlayerNotes.target = nil
    AdminPlayerNotes.rows = {}
    AdminPlayerNotes.selected = nil
    AdminPlayerNotes.history = {}
    AdminInventory.target = nil
    AdminInventory.inspected = {}
    AdminInventory.inspection = nil
    AdminWeapons.target = nil
    AdminWeapons.weapons = {}
    AdminWeapons.ammunition = {}
    AdminWeapons.selected = nil
    AdminWeapons.action = nil
    AdminWeapons.quantity = ''
    AdminUI.targetPlayer = nil
    AdminUI.toggleStates = {}
    AdminUI.pendingToggles = {}
    if InMenu then AdminUI.Close() end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if AdminKeyListener then exports['feather-toolkit']:RemoveKeyListener(AdminKeyListener) end
    AdminKeyListener = nil
end)
