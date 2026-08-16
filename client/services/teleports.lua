AdminTeleports = {}

local state = {
    autoWaypoint = false,
    autoWaypointSession = 0,
    teleporting = false
}

local function sameWaypoint(first, second)
    if not first or not second then return false end
    return Feather.Math.GetDistanceBetween(first, second) < 1.0
end

local function findGroundZ(x, y)
    RequestCollisionAtCoord(x, y, 1000.0)
    for height = 1000, 0, -25 do
        local found, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, height + 0.0)
        if found then return groundZ end
        Wait(0)
    end
    return nil
end

local function teleportToWaypoint()
    if state.teleporting or not IsWaypointActive() then return false end
    state.teleporting = true

    local waypoint = GetWaypointCoords()
    local groundZ = findGroundZ(waypoint.x, waypoint.y)
    local destinationZ = groundZ or waypoint.z
    local ped = PlayerPedId()

    SetEntityCoordsNoOffset(ped, waypoint.x, waypoint.y, destinationZ, false, false, false)
    if groundZ then
        Citizen.InvokeNative(0x9587913B9E772D29, ped, false)
    end

    state.teleporting = false
    return true
end

local function runAutoWaypoint(session)
    local lastWaypoint
    while state.autoWaypoint and state.autoWaypointSession == session do
        if IsWaypointActive() then
            local waypoint = GetWaypointCoords()
            if not sameWaypoint(waypoint, lastWaypoint) then
                teleportToWaypoint()
                lastWaypoint = waypoint
            end
        else
            lastWaypoint = nil
        end
        Wait(250)
    end
end

function AdminTeleports.ToWaypoint()
    CreateThread(teleportToWaypoint)
end

function AdminTeleports.ToggleAutoWaypoint()
    state.autoWaypoint = not state.autoWaypoint
    state.autoWaypointSession = state.autoWaypointSession + 1
    if state.autoWaypoint then
        local session = state.autoWaypointSession
        CreateThread(function()
            runAutoWaypoint(session)
        end)
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    state.autoWaypoint = false
    state.autoWaypointSession = state.autoWaypointSession + 1
end)
