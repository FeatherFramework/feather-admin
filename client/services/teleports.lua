AdminTeleports = {}

local state = {
    autoWaypoint = false,
    autoWaypointSession = 0
}

local function sameWaypoint(first, second)
    if not first or not second then return false end
    return Feather.Math.GetDistanceBetween(first, second) < 1.0
end

local failureKeys = {
    busy = 'teleport_busy',
    invalid_coordinates = 'invalid_coordinates',
    invalid_entity = 'teleport_invalid_entity',
    fade_failed = 'teleport_fade_failed',
    stream_timeout = 'teleport_stream_failed',
    exact_surface_not_found = 'teleport_surface_failed',
    surface_not_found = 'teleport_surface_failed',
    settle_timeout = 'teleport_settle_failed',
    no_waypoint = 'teleport_no_waypoint',
    frontend_close_failed = 'teleport_map_close_failed'
}

function AdminTeleports.NotifyResult(result, successKey)
    local succeeded = type(result) == 'table' and result.success == true
    local messageKey = succeeded and successKey
        or failureKeys[type(result) == 'table' and result.reason or nil]
        or 'teleport_failed'
    Feather.Notify.RightNotify(AdminTranslate(messageKey), 3000)
    return succeeded
end

local function closeMapFrontend()
    local started = GetGameTimer()
    local minimumCloseTime = 500
    local deadline = GetGameTimer() + 2000
    repeat
        -- SET_FRONTEND_ACTIVE(false): closes RedM's map/pause frontend.
        Citizen.InvokeNative(0xCE47C21C0687EBC2, false)
        Wait(0)
    until (GetGameTimer() - started >= minimumCloseTime and not IsPauseMenuActive())
        or GetGameTimer() >= deadline

    if IsPauseMenuActive() then return false end
    return true
end

local function runAutoWaypoint(session)
    local lastWaypoint
    local attemptWaypoint
    local nextAttempt = 0
    local failureNotified = false
    while state.autoWaypoint and state.autoWaypointSession == session do
        if IsWaypointActive() then
            local waypoint = GetWaypointCoords()
            if not sameWaypoint(waypoint, attemptWaypoint) then
                attemptWaypoint = waypoint
                nextAttempt = 0
                failureNotified = false
            end
            if not sameWaypoint(waypoint, lastWaypoint) and GetGameTimer() >= nextAttempt then
                local result = closeMapFrontend()
                    and Feather.Teleport:ToCoords(waypoint, { mode = 'surface' })
                    or { success = false, reason = 'frontend_close_failed' }
                if result.success then
                    lastWaypoint = waypoint
                    failureNotified = false
                    AdminTeleports.NotifyResult(result, 'teleport_auto_success')
                else
                    nextAttempt = GetGameTimer() + 2000
                    if not failureNotified then
                        AdminTeleports.NotifyResult(result)
                        failureNotified = true
                    end
                end
            end
        else
            lastWaypoint = nil
            attemptWaypoint = nil
            nextAttempt = 0
            failureNotified = false
        end
        Wait(250)
    end
end

function AdminTeleports.ToWaypoint()
    return Feather.Teleport:ToWaypoint()
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
    if not x or not y or not z then return { success = false, reason = 'invalid_coordinates' } end

    return Feather.Teleport:ToCoords(vector3(x, y, z), {
        heading = heading,
        mode = 'exact'
    })
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
