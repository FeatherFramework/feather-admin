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

FeatherAdmin.RegisterRPC('feather-admin:player:info:request', function(params, _, src)
    local playerId = params.playerId
    local target = FeatherAdmin.RequireTarget(src, 'player.info', playerId)
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
        roleName = char.role_name,
        roleLevel = char.role_level,
        dollars = char.dollars,
        gold = char.gold,
        tokens = char.tokens,
        xp = char.xp,
        identifiers = identifiers
    }

    TriggerClientEvent('feather-admin:player:info', src, info)
    AdminAudit.Record(src, 'player.info', target)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:player:go_to', function(params, _, src)
    local playerId = params.playerId
    local target = FeatherAdmin.RequireTarget(src, 'player.go_to', playerId)
    if target == nil then return end
    if movePlayer(src, src, target, 'player.go_to') then
        notify(src, 'Teleported to player.')
    else
        notify(src, 'Unable to find the player location.')
    end
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:player:return', function(_, _, src)
    if not FeatherAdmin.RequirePermission(src, 'player.go_to') then return end
    local destination = returnLocations[src]
    if destination == nil then
        notify(src, 'No previous location is saved.')
        return
    end

    returnLocations[src] = nil
    TriggerClientEvent('feather-admin:player:teleport', src, destination)
    AdminAudit.Record(src, 'player.return', src)
    notify(src, 'Returned to your previous location.')
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 64 })

FeatherAdmin.RegisterRPC('feather-admin:player:bring', function(params, _, src)
    local playerId = params.playerId
    local target = FeatherAdmin.RequireTarget(src, 'player.bring', playerId)
    if target == nil then return end
    if movePlayer(src, target, src, 'player.bring') then
        notify(src, 'Player brought to your location.')
    else
        notify(src, 'Unable to move the player.')
    end
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:player:send_back', function(params, _, src)
    local playerId = params.playerId
    local target = FeatherAdmin.RequireTarget(src, 'player.send_back', playerId)
    local destination = target and returnLocations[target] or nil
    if destination == nil then
        notify(src, 'No return location is saved for this player.')
        return
    end

    returnLocations[target] = nil
    TriggerClientEvent('feather-admin:player:teleport', target, destination)
    AdminAudit.Record(src, 'player.send_back', target)
    notify(src, 'Player sent back.')
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 128 })

FeatherAdmin.RegisterRPC('feather-admin:player:spectate', function(params, _, src)
    local playerId, enabled = params.playerId, params.enabled

    if enabled ~= true then
        if not FeatherAdmin.RequirePermission(src, 'player.spectate') then return end
        spectateTargets[src] = nil
        TriggerClientEvent('feather-admin:player:spectate', src, nil, false)
        AdminAudit.Record(src, 'player.spectate.stop', playerId)
        return
    end

    local target = FeatherAdmin.RequireTarget(src, 'player.spectate', playerId)
    if target == nil then return end

    local targetCoords = getPlayerCoords(target)
    if targetCoords == nil then return end

    TriggerClientEvent('feather-admin:player:spectate', src, target, true, targetCoords)
    spectateTargets[src] = target
    AdminAudit.Record(src, 'player.spectate.start', target)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 128 })

local function clearPlayerState(playerId)
    if spectateTargets[playerId] ~= nil then
        TriggerClientEvent('feather-admin:player:spectate', playerId, nil, false)
    end
    returnLocations[playerId] = nil
    spectateTargets[playerId] = nil

    for adminId, targetId in pairs(spectateTargets) do
        if targetId == playerId then
            spectateTargets[adminId] = nil
            TriggerClientEvent('feather-admin:player:spectate', adminId, nil, false)
        end
    end
end

AddEventHandler('Feather:Character:Logout', function(playerId)
    playerId = tonumber(playerId)
    if playerId then clearPlayerState(playerId) end
end)

AddEventHandler('playerDropped', function()
    clearPlayerState(source)
end)
