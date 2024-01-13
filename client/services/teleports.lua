---- Variables -----
local autoTpm = false

---- Local Functions ----
local function teleportToWaypoint()
    local player = PlayerPedId()
    local GetGroundZAndNormalFor_3dCoord = GetGroundZAndNormalFor_3dCoord
    local waypoint = IsWaypointActive()
    local coords = GetWaypointCoords()

    if waypoint then
        local x, y, z = coords.x, coords.y, coords.z
        local groundCheck, ground = nil, nil
        for height = 1, 1000 do
            groundCheck, ground = GetGroundZAndNormalFor_3dCoord(x, y, height + 0.0)
            if groundCheck then
                break
            end
        end

        if ground > 0.0 then
            z = ground
        end

        SetEntityCoords(player, x, y, z)
        Citizen.InvokeNative(0x9587913B9E772D29, player, 0)
    end
end

local function autoTpmFunct()
    while autoTpm do
        Wait(5)
        teleportToWaypoint()
    end
end

----- Menus -----
function teleportsMenu()
    FeatherAdminMenu:Close({})

    local teleportPage = FeatherAdminMenu:RegisterPage("feather-admin:teleportPage")
    teleportPage:RegisterElement("header", {
        value = "Teleport Menu",
        slot = 'header',
        style = {}
    })
    teleportPage:RegisterElement("button", {
        label = "Teleport to Waypoint",
        style = {}
    }, function()
        teleportToWaypoint()
    end)
    teleportPage:RegisterElement("button", {
        label = "Auto Teleport to Waypoint",
        style = {}
    }, function()
        if not autoTpm then
            autoTpm = true
            autoTpmFunct()
        else
            autoTpm = false
        end
    end)

    FeatherAdminMenu:Open({
        startupPage = teleportPage
    })
end