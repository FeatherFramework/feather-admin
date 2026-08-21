local resourceStateKeys = {
    started = 'resource_started',
    starting = 'resource_starting',
    stopped = 'resource_stopped',
    stopping = 'resource_stopping',
    missing = 'resource_missing',
    uninitialized = 'resource_uninitialized',
    unknown = 'resource_unknown'
}

local function formatUptime(value)
    local remaining = math.max(0, math.floor(tonumber(value) or 0))
    local days = math.floor(remaining / 86400)
    remaining = remaining % 86400
    local hours = math.floor(remaining / 3600)
    remaining = remaining % 3600
    local minutes = math.floor(remaining / 60)

    if days > 0 then return ('%sd %sh %sm'):format(days, hours, minutes) end
    if hours > 0 then return ('%sh %sm'):format(hours, minutes) end
    return ('%sm'):format(minutes)
end

local function resourceState(value)
    local state = tostring(value or 'unknown'):lower()
    return AdminTranslate(resourceStateKeys[state] or 'resource_unknown')
end

function AdminUI.OpenServerOverview()
    if not AdminUI.CanUse('server.overview') then
        AdminUI.NotifyActionDenied()
        return
    end

    local snapshot = AdminServerOverview.snapshot
    if type(snapshot) ~= 'table' then
        AdminServerOverview.Request()
        return
    end

    local page = AdminUI.RegisterPage('server_overview')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('server_overview'))
    AdminUI.AddText(page, table.concat({
        ('%s: %s'):format(AdminTranslate('server_name'), tostring(snapshot.serverName or AdminTranslate('not_available'))),
        ('%s: %s / %s'):format(AdminTranslate('players_online'), tostring(snapshot.playerCount or 0),
            tostring(snapshot.maxPlayers or 0)),
        ('%s: %s'):format(AdminTranslate('server_uptime'), formatUptime(snapshot.uptimeSeconds)),
        ('%s: %s'):format(AdminTranslate('onesync_mode'), tostring(snapshot.oneSync or 'off'))
    }, '\n'))

    AdminUI.AddLine(page)
    AdminUI.AddText(page, AdminTranslate('resource_health'))
    local resources = type(snapshot.resources) == 'table' and snapshot.resources or {}
    if #resources == 0 then
        AdminUI.AddText(page, AdminTranslate('no_monitored_resources'))
    else
        for _, resource in ipairs(resources) do
            AdminUI.AddText(page, ('%s: %s'):format(tostring(resource.name), resourceState(resource.state)))
        end
    end

    AdminUI.AddLine(page)
    AdminUI.AddButton(page, AdminTranslate('refresh'), AdminServerOverview.Request)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenNavigationSection('server_operations')
    end)
    AdminUI.OpenPage('server_overview')
end

AdminUI.RegisterNavigationItem('server_operations', {
    key = 'server_overview',
    labelKey = 'server_overview',
    order = 10,
    permission = 'server.overview',
    open = AdminServerOverview.Request
})
