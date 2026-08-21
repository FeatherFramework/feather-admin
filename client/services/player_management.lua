AdminPlayerManagement = {}

local spectating = false
local spectateSession = 0
local spectateTarget

local function findPlayerByServerId(serverId)
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == serverId then return player end
    end
    return nil
end

local function teleportToPlayerCoords(coords)
    if type(coords) ~= 'table' then return end

    DoScreenFadeOut(500)
    local fadeTimeout = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < fadeTimeout do Wait(0) end

    local ped = PlayerPedId()
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 0.25, false, false, false)

    local collisionTimeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionTimeout do Wait(0) end
    DoScreenFadeIn(500)
end

function AdminPlayerManagement.RequestInfo(target)
    Feather.RPC.Notify('feather-admin:player:info:request', { playerId = target })
    return true
end

function AdminPlayerManagement.GoTo(target)
    Feather.RPC.Notify('feather-admin:player:go_to', { playerId = target })
    return true
end

function AdminPlayerManagement.ReturnToPreviousLocation()
    Feather.RPC.Notify('feather-admin:player:return', {})
    return true
end

function AdminPlayerManagement.Bring(target)
    Feather.RPC.Notify('feather-admin:player:bring', { playerId = target })
    return true
end

function AdminPlayerManagement.SendBack(target)
    Feather.RPC.Notify('feather-admin:player:send_back', { playerId = target })
    return true
end

function AdminPlayerManagement.Spectate(target, enabled)
    Feather.RPC.Notify('feather-admin:player:spectate', { playerId = target, enabled = enabled })
    return true
end

function AdminPlayerManagement.IsSpectating(target)
    return spectating and (target == nil or spectateTarget == tonumber(target))
end

function AdminPlayerManagement.StopSpectating()
    if not spectating then return false end
    Feather.RPC.Notify('feather-admin:player:spectate', { playerId = spectateTarget, enabled = false })
    return true
end

RegisterNetEvent('feather-admin:player:teleport', function(coords)
    CreateThread(function() teleportToPlayerCoords(coords) end)
end)

RegisterNetEvent('feather-admin:player:spectate', function(targetServerId, enabled, coords)
    spectateSession = spectateSession + 1
    local session = spectateSession

    if not enabled then
        NetworkSetInSpectatorMode(false, PlayerPedId())
        ClearFocus()
        spectating = false
        spectateTarget = nil
        return
    end

    spectating = true
    spectateTarget = tonumber(targetServerId)
    CreateThread(function()
        if type(coords) == 'table' then
            SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
        end

        local targetPlayer
        local timeoutAt = GetGameTimer() + 5000
        repeat
            targetPlayer = findPlayerByServerId(tonumber(targetServerId))
            if targetPlayer == nil then Wait(100) end
        until targetPlayer ~= nil or GetGameTimer() >= timeoutAt or session ~= spectateSession
        if targetPlayer == nil or session ~= spectateSession then
            if session == spectateSession then
                ClearFocus()
                spectating = false
                spectateTarget = nil
            end
            return
        end

        local targetPed = GetPlayerPed(targetPlayer)
        if targetPed == 0 or not DoesEntityExist(targetPed) then
            ClearFocus()
            spectating = false
            spectateTarget = nil
            return
        end

        NetworkSetInSpectatorMode(true, targetPed)
    end)
end)

RegisterNetEvent('feather-admin:player:info', function(info)
    if type(info) == 'table' then AdminUI.OpenPlayerInfo(info) end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or not spectating then return end
    spectateSession = spectateSession + 1
    NetworkSetInSpectatorMode(false, PlayerPedId())
    ClearFocus()
end)
