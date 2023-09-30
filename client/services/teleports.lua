---- Variables -----
local autoTpm = false

---- Local Functions ----
local function autoTpmFunct()
    while autoTpm do
        Wait(5)
        teleportToWaypoint()
    end
end

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
        SetEntityHeading(player, hospital.heading)
        Citizen.InvokeNative(0x9587913B9E772D29, player, 0)
    end
end

----- Menus -----
function teleportsMenu()
    MenuAPI.CloseAll()

    local elements = {}
    if not autoTpm then
        table.insert(elements, { label = "Enable Auto Tpm", value = 'autoTpm', desc = "Toggle auto Tpm which while active will teleport the player to any map marker they set." })
    else
        table.insert(elements, { label = "Disable Auto Tpm", value = 'autoTpm', desc = "Toggle auto Tpm which while active will teleport the player to any map marker they set." })
    end
    table.insert(elements,         { label = "Teleport To Waypoint", value = 'tpm', desc = "Teleport to waypoint." })

    MenuAPI.Open('default', GetCurrentResourceName(), 'menuapi',
        {
            title = "Teleport Menu",
            align = 'top-left',
            elements = elements
        },
        function(data, menu)
            if data.current == 'backup' then
                _G[data.trigger]()
            end
            local selectedOption = {
                ['autoTpm'] = function()
                    if not autoTpm then
                        MenuAPI.CloseAll()
                        autoTpm = true
                        teleportsMenu()
                        autoTpmFunct()
                    else
                        MenuAPI.CloseAll()
                        autoTpm = false
                        teleportsMenu()
                    end
                end,
                ['tpm'] = function()
                    teleportToWaypoint()
                end
            }

            if selectedOption[data.current.value] then
                selectedOption[data.current.value]()
            end
        end,
        function(data, menu)
            menu.close()
            mainAdminMenu()
        end)
end