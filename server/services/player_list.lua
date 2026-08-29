local function getPlayerList()
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = math.tointeger(tonumber(playerId) or -1)
        if id and id >= 0 then
            local identity = FeatherAdmin.Identity.Resolve(id) or {}
            local staff = FeatherAdmin.Identity.GetStaff(identity) or {}
            local firstName = tostring(identity.firstName or '')
            local lastName = tostring(identity.lastName or '')
            players[#players + 1] = {
                serverId = id,
                serverName = GetPlayerName(id),
                accountId = identity.accountId,
                characterId = identity.characterId,
                firstName = firstName,
                lastName = lastName,
                characterName = identity.characterName,
                roleName = staff.roleName,
                roleLevel = staff.roleLevel or 0
            }
        end
    end

    return players
end

local function getRoles()
    if not AdminDatabase or not AdminDatabase.ready then return {} end
    return MySQL.query.await([[
        SELECT role_level AS id, role_name AS name, role_level AS level
        FROM feather_admin_staff_accounts
        WHERE active = 1
        GROUP BY role_level, role_name
        ORDER BY role_level ASC, role_name ASC
    ]]) or {}
end

local function syncPlayerList(src, roles)
    local playerId = math.tointeger(tonumber(src) or -1)
    if not playerId or playerId < 0 then return end

    if not FeatherAdmin.CanUse(playerId, 'players.view') then return end

    TriggerClientEvent('feather-admin:players:sync', playerId, getPlayerList(), roles or getRoles())
end

local function syncAllAdmins(excludedPlayer)
    local roles = getRoles()
    for _, playerId in ipairs(GetPlayers()) do
        local adminId = math.tointeger(tonumber(playerId) or -1)
        if adminId and adminId >= 0 and adminId ~= excludedPlayer then syncPlayerList(adminId, roles) end
    end
end

AdminDatabase.OnReady(function()
    syncAllAdmins()
end)

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

AddEventHandler('Feather:Server:Character:Spawned', function(_, src)
    syncAllAdmins(tonumber(src))
end)
