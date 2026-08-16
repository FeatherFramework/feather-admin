local returnLocations = {}
local spectateTargets = {}

local function notify(playerId, text)
    FeatherAdmin.Core.Notify.RightNotify(playerId, text, 2500)
end

local function getPlayerCoords(playerId)
    local ped = GetPlayerPed(playerId)
    if ped == 0 then return nil end

    local coords = GetEntityCoords(ped)
    if coords == nil then return nil end
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function movePlayer(adminId, movedPlayer, destinationPlayer, action)
    local oldCoords = getPlayerCoords(movedPlayer)
    local destination = getPlayerCoords(destinationPlayer)
    if oldCoords == nil or destination == nil then return false end

    returnLocations[movedPlayer] = oldCoords
    TriggerClientEvent('feather-admin:player:teleport', movedPlayer, destination)
    AdminAudit.Record(adminId, action, movedPlayer, ('destination=%s'):format(destinationPlayer))
    return true
end

RegisterNetEvent('feather-admin:player:info:request', function(playerId)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'player.info') then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil then return end

    local character = FeatherAdmin.Core.Character.GetCharacter({ src = target })
    local char = character and character.char or {}
    local identifiers = GetPlayerIdentifiers(target)
    local info = {
        serverId = target,
        serverName = GetPlayerName(target) or 'Unknown',
        characterId = char.id,
        firstName = char.first_name,
        lastName = char.last_name,
        roleName = char.name,
        roleLevel = char.level,
        dollars = char.dollars,
        gold = char.gold,
        tokens = char.tokens,
        xp = char.xp,
        identifiers = identifiers
    }

    TriggerClientEvent('feather-admin:player:info', src, info)
    AdminAudit.Record(src, 'player.info', target)
end)

RegisterNetEvent('feather-admin:player:go_to', function(playerId)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'player.go_to') then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil or target == src then return end
    if movePlayer(src, src, target, 'player.go_to') then
        notify(src, 'Teleported to player.')
    else
        notify(src, 'Unable to find the player location.')
    end
end)

RegisterNetEvent('feather-admin:player:bring', function(playerId)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'player.bring') then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil or target == src then return end
    if movePlayer(src, target, src, 'player.bring') then
        notify(src, 'Player brought to your location.')
    else
        notify(src, 'Unable to move the player.')
    end
end)

RegisterNetEvent('feather-admin:player:send_back', function(playerId)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'player.send_back') then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    local destination = target and returnLocations[target] or nil
    if destination == nil then
        notify(src, 'No return location is saved for this player.')
        return
    end

    returnLocations[target] = nil
    TriggerClientEvent('feather-admin:player:teleport', target, destination)
    AdminAudit.Record(src, 'player.send_back', target)
    notify(src, 'Player sent back.')
end)

RegisterNetEvent('feather-admin:player:spectate', function(playerId, enabled)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'player.spectate') then return end

    if enabled ~= true then
        spectateTargets[src] = nil
        TriggerClientEvent('feather-admin:player:spectate', src, nil, false)
        AdminAudit.Record(src, 'player.spectate.stop', playerId)
        return
    end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil or target == src then return end

    local targetCoords = getPlayerCoords(target)
    if targetCoords == nil then return end

    TriggerClientEvent('feather-admin:player:spectate', src, target, true, targetCoords)
    spectateTargets[src] = target
    AdminAudit.Record(src, 'player.spectate.start', target)
end)

RegisterNetEvent('feather-admin:player:kick', function(playerId, reason)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'player.kick') then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil or target == src or type(reason) ~= 'string' then return end

    reason = reason:match('^%s*(.-)%s*$')
    if reason == '' or #reason > 200 then return end

    AdminAudit.Record(src, 'player.kick', target, reason)
    DropPlayer(target, reason)
end)

AddEventHandler('playerDropped', function()
    local droppedPlayer = source
    returnLocations[droppedPlayer] = nil
    spectateTargets[droppedPlayer] = nil

    for adminId, targetId in pairs(spectateTargets) do
        if targetId == droppedPlayer then
            spectateTargets[adminId] = nil
            TriggerClientEvent('feather-admin:player:spectate', adminId, nil, false)
        end
    end
end)
