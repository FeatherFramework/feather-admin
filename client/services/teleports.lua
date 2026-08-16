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

local function findSurfaceZ(x, y)
    local ray = StartShapeTestRay(x, y, 1000.0, x, y, -100.0, -1, PlayerPedId(), 7)
    local timeoutAt = GetGameTimer() + 1000

    while GetGameTimer() < timeoutAt do
        local status, hit, hitCoords = GetShapeTestResult(ray)
        if status == 2 then
            if hit then return hitCoords.z end
            return nil
        end
        Wait(0)
    end

    return nil
end

local function teleportToCoordinates(x, y, fallbackZ, heading)
    if state.teleporting then return false end
    state.teleporting = true

    DoScreenFadeOut(500)
    local fadeTimeout = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < fadeTimeout do Wait(0) end

    RequestCollisionAtCoord(x, y, 1000.0)
    local surfaceZ = findSurfaceZ(x, y)
    local groundZ = surfaceZ and nil or findGroundZ(x, y)
    local destinationZ = surfaceZ or groundZ or fallbackZ
    if not destinationZ then
        state.teleporting = false
        DoScreenFadeIn(500)
        return false
    end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, x, y, destinationZ + 0.1, false, false, false)
    if heading then SetEntityHeading(ped, heading) end

    RequestCollisionAtCoord(x, y, destinationZ)
    local collisionTimeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionTimeout do Wait(0) end

    state.teleporting = false
    DoScreenFadeIn(500)
    return true
end

local function teleportToWaypoint()
    if not IsWaypointActive() then return false end
    local waypoint = GetWaypointCoords()
    return teleportToCoordinates(waypoint.x, waypoint.y, waypoint.z)
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

function AdminTeleports.ParseCoordinates(value)
    if type(value) ~= 'string' then return nil end

    local normalized = value:lower()
    local x = normalized:match('x%s*=%s*([%+%-]?%d*%.?%d+)')
    local y = normalized:match('y%s*=%s*([%+%-]?%d*%.?%d+)')
    local z = normalized:match('z%s*=%s*([%+%-]?%d*%.?%d+)')
    local heading = normalized:match('[hw]%s*=%s*([%+%-]?%d*%.?%d+)')
    if x and y and z then return tonumber(x), tonumber(y), tonumber(z), tonumber(heading) end

    normalized = normalized:gsub('^%s*vector[34]%s*%(', ''):gsub('%)%s*$', '')
    local values = {}
    for number in normalized:gmatch('[%+%-]?%d*%.?%d+') do
        values[#values + 1] = tonumber(number)
    end
    if #values < 3 then return nil end
    return values[1], values[2], values[3], values[4]
end

function AdminTeleports.ToCoordinates(x, y, z, heading)
    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading)
    if not x or not y or not z then return false end

    CreateThread(function()
        teleportToCoordinates(x, y, z, heading)
    end)

    return true
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
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(0) end
end)
