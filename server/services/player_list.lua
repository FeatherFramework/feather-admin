local function getPlayerList()
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = math.tointeger(tonumber(playerId) or -1)
        if id and id >= 0 then
            local character = FeatherAdmin.Core.Character.GetCharacter({ src = id })
            local char = character and character.char or {}
            local firstName = tostring(char.first_name or '')
            local lastName = tostring(char.last_name or '')
            local characterName = ('%s %s'):format(firstName, lastName):match('^%s*(.-)%s*$')
            players[#players + 1] = {
                serverId = id,
                serverName = GetPlayerName(id),
                characterId = tonumber(char.id),
                firstName = firstName,
                lastName = lastName,
                characterName = characterName ~= '' and characterName or nil,
                roleName = char.role_name,
                roleLevel = tonumber(char.role_level) or 0
            }
        end
    end

    return players
end

local function getRoles()
    return MySQL.query.await('SELECT id, name, level FROM roles ORDER BY level ASC, name ASC') or {}
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
