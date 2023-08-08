--[[Credits
    vorp_admin for the teleportToWaypoint function code
]]

---- Variables -----
local autoTpm = false

----- Menus -----
function teleportsMenu()
    VORPMenu.CloseAll()

    local elements = {}
    if not autoTpm then
        table.insert(elements, { label = "Enable Auto Tpm", value = 'autoTpm', desc = "Toggle auto Tpm which while active will teleport the player to any map marker they set." })
    else
        table.insert(elements, { label = "Disable Auto Tpm", value = 'autoTpm', desc = "Toggle auto Tpm which while active will teleport the player to any map marker they set." })
    end
    table.insert(elements,         { label = "Teleport To Waypoint", value = 'tpm', desc = "Teleport to waypoint." })

    VORPMenu.Open('default', GetCurrentResourceName(), 'vorp_menu',
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
                        VORPMenu.CloseAll()
                        autoTpm = true
                        teleportsMenu()
                        autoTpmFunct()
                    else
                        VORPMenu.CloseAll()
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

function autoTpmFunct()
    while autoTpm do
        Wait(5)
        teleportToWaypoint()
    end
end

function teleportToWaypoint()
    local ped = PlayerPedId()
    local GetGroundZAndNormalFor_3dCoord = GetGroundZAndNormalFor_3dCoord
    local waypoint = IsWaypointActive()
    local coords = GetWaypointCoords()
    local x, y, groundZ, startingpoint = coords.x, coords.y, 650.0, 750.0
    local found = false
    if waypoint then
        for i = startingpoint, 0, -25.0 do
            local z = i
            if (i % 2) ~= 0 then
                z = startingpoint + i
            end
            SetEntityCoords(ped, x, y, z - 1000)
            Wait(500)
            found, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z)
            if found then
                SetEntityCoords(ped, x, y, groundZ)
            end break
        end
    end
end