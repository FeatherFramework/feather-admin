local function getPlayerIds()
    local playerIds = {}
    for _, playerId in ipairs(GetPlayers()) do
        table.insert(playerIds, tonumber(playerId))
    end
    return playerIds
end

local function syncPlayerList(src)
    if FeatherAdmin.IsAuthorized(src) then
        TriggerClientEvent('feather-admin:ClientAllPlayers', src, getPlayerIds())
    end
end

local function syncAllAdmins(excludedPlayer)
    for _, playerId in ipairs(GetPlayers()) do
        local adminId = tonumber(playerId)
        if adminId ~= excludedPlayer then syncPlayerList(adminId) end
    end
end

RegisterNetEvent('feather-admin:StorePlayersInfo', function()
    local src = source
    if not FeatherAdmin.RequireAuthorized(src) then return end
    syncPlayerList(src)
end)

RegisterNetEvent('feather-admin:RequestPlayerList', function()
    local src = source
    if not FeatherAdmin.RequireAuthorized(src) then return end
    syncPlayerList(src)
end)

AddEventHandler('playerDropped', function()
    syncAllAdmins(source)
end)

AddEventHandler('playerJoining', function()
    CreateThread(function()
        Wait(1000)
        syncAllAdmins()
    end)
end)
