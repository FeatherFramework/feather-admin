AdminTeleports = {}

local state = {
    autoWaypoint = false,
    autoWaypointSession = 0
}

local mapAppHash = joaat('Map')

local function closeMapApp()
    if not IsUiappActiveByHash(mapAppHash) then return end

    CloseUiappByHash(mapAppHash)

    local deadline = GetGameTimer() + 1500
    Wait(0)

    while IsUiappTransitioningByHash(mapAppHash)
        and GetGameTimer() < deadline do
        Wait(0)
    end
end

local function sameWaypoint(first, second)
    if not first or not second then return false end
    return #(first - second) < 1.0
end

local function succeeded(result)
    local success = type(result) == 'table' and result.success == true
    if not success then
        print(('[feather-admin] teleport failed reason=%s resultType=%s'):format(
            tostring(type(result) == 'table' and result.reason or 'invalid_result'),
            type(result)))
    end
    return success
end

local function runAutoWaypoint(session)
    local lastWaypoint
    while state.autoWaypoint and state.autoWaypointSession == session do
        if IsWaypointActive() then
            local waypoint = GetWaypointCoords()
            if not sameWaypoint(waypoint, lastWaypoint) then
                -- Capture the waypoint first. Closing the Map app can leave
                -- its active flag set during the transition, so that flag
                -- must not decide whether teleporting is allowed.
                closeMapApp()
                local result = Feather.Teleport:ToCoords(waypoint, { mode = 'surface' })
                if succeeded(result) then lastWaypoint = waypoint end
            end
        else
            lastWaypoint = nil
        end
        Wait(250)
    end
end

function AdminTeleports.ToWaypoint()
    return succeeded(Feather.Teleport:ToWaypoint())
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

    return succeeded(Feather.Teleport:ToCoords(vector3(x, y, z), {
        heading = heading,
        mode = 'exact'
    }))
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
