local function getPlayerIds()
    local playerIds = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = math.tointeger(tonumber(playerId) or -1)
        if id and id >= 0 then playerIds[#playerIds + 1] = id end
    end

    return playerIds
end

local function syncPlayerList(src)
    local playerId = math.tointeger(tonumber(src) or -1)
    if not playerId or playerId < 0 then return end

    if not FeatherAdmin.CanUse(playerId, 'players.view') then return end

    TriggerClientEvent('feather-admin:players:sync', playerId, getPlayerIds())
end

local function syncAllAdmins(excludedPlayer)
    for _, playerId in ipairs(GetPlayers()) do
        local adminId = math.tointeger(tonumber(playerId) or -1)
        if adminId and adminId >= 0 and adminId ~= excludedPlayer then syncPlayerList(adminId) end
    end
end

FeatherAdmin.RegisterRPC('feather-admin:players:request', function(_, _, src)
    if not FeatherAdmin.RequirePermission(src, 'players.view') then return end

    syncPlayerList(src)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 64 })

AddEventHandler('playerDropped', function()
    syncAllAdmins(source)
end)

AddEventHandler('playerJoining', function()
    CreateThread(function()
        Wait(1000)
        syncAllAdmins()
    end)
end)
