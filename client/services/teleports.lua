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
        SetEntityHeading(player, hospital.heading)
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
    MenuAPI.CloseAll()

    local elements = {
        { label = Feather.Locale.translate(0, "autoTPM"), value = 'autoTpm', desc = Feather.Locale.translate(0, "autoTPM_desc") },
        { label = Feather.Locale.translate(0, "TPM"), value = 'tpm', desc = Feather.Locale.translate(0, "TPM_desc") }
    }

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
                        autoTpm = true
                        autoTpmFunct()
                    else
                        autoTpm = false
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