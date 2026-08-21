local function monitoredResources()
    local configured = type(Config.serverOverview) == 'table' and Config.serverOverview.resources or {}
    local resources, included = {}, {}
    for _, resourceName in ipairs(type(configured) == 'table' and configured or {}) do
        if type(resourceName) == 'string' and resourceName ~= '' and not included[resourceName]
            and #resources < 25 then
            included[resourceName] = true
            resources[#resources + 1] = {
                name = resourceName,
                state = GetResourceState(resourceName)
            }
        end
    end
    return resources
end

FeatherAdmin.RegisterRPC('feather-admin:server:overview', function(_, _, src)
    if not FeatherAdmin.RequirePermission(src, 'server.overview') then return end

    TriggerClientEvent('feather-admin:server:overview', src, {
        serverName = GetConvar('sv_hostname', 'RedM Server'),
        playerCount = #GetPlayers(),
        maxPlayers = math.max(0, GetConvarInt('sv_maxclients', 0)),
        uptimeSeconds = math.max(0, math.floor((tonumber(GetGameTimer()) or 0) / 1000)),
        oneSync = GetConvar('onesync', 'off'),
        resources = monitoredResources()
    })
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 64 })
