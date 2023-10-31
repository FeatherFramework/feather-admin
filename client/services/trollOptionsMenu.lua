local trolls = {
    isFroze = false,
    isCaged = false,
    cageObj = nil,
    isCinematic = false,
    pedGiant = false
}

function trollMenu(playerId) --Main all players menu (Menu starts here)
    MenuAPI.CloseAll()

    local elements = {
        { label = 'Lightning Strike', value = 'lightningStrike', desc = 'Summon a lightning bolt to strike this player?' },
        { label = 'Toggle Freeze Player', value = 'freeze', desc = 'Toggle Freezing this player in place.' },
        { label = 'Send To Heaven', value = 'heaven', desc = 'Send this player to heaven?' },
        { label = 'Toggle Cage Player', value = 'cage', desc = 'Toggle locking this player in a cage?' },
        { label = 'Kill Player', value = 'kill', desc = 'Kill this player?' },
        { label = "Toggle Make Ped Giant.", value = 'makePedGiant', desc = "Toggle Make Ped Giant." },
        { label = "Toggle Force Cinematic Cam", value = "forceCinematicCam", desc = "Toggle force player into cinematic camera." },
        { label = "Spawn Hostile Ped Army", value = "hostilePedArmy", desc = "Spawns a lot of peds to attack the player until they die or the player dies." },
        { label = "Kick From Vehicle", value = "kickFromVehicle", desc = "If player is in a vehicle/wagon this will kick them out of it." }
    }

    MenuAPI.Open('default', GetCurrentResourceName(), 'menuapi',
        {
            title = "Troll Options",
            align = 'top-left',
            elements = elements
        },
        function(data, menu)
            if data.current == 'backup' then
                _G[data.trigger]()
            end
            local selectedOption = {
                ['lightningStrike'] = function()
                    TriggerServerEvent("feather-admin:TrollCheck", "LightningStrike", playerId)
                end,
                ['freeze'] = function()
                    TriggerServerEvent("feather-admin:TrollCheck", "Freeze", playerId)
                end,
                ['heaven'] = function()
                    TriggerServerEvent("feather-admin:TrollCheck", "TeleportToHeaven", playerId)
                end,
                ['kill'] = function()
                    TriggerServerEvent("feather-admin:TrollCheck", "Kill", playerId)
                end,
                ['cage'] = function()
                    TriggerServerEvent("feather-admin:TrollCheck", "Cage", playerId)
                end,
                ["forceCinematicCam"] = function()
                    TriggerServerEvent("feather-admin:TrollCheck", "forceCinematicCam", playerId)
                end,
                ["makePedGiant"] = function()
                    TriggerServerEvent('feather-admin:TrollCheck', "makePedGiant", playerId)
                end,
                ["hostilePedArmy"] = function()
                    TriggerServerEvent("feather-admin:TrollCheck", "hostilePedArmy", playerId)
                end,
                ["kickFromVehicle"] = function()
                    TriggerServerEvent("feather-admin:TrollCheck", "kickFromVehicle", playerId)
                end
            }

            if selectedOption[data.current.value] then
                selectedOption[data.current.value]()
            end
        end,
        function(data, menu)
            menu.close()
            allPlayerSelectedPlayerMenu(playerId)
        end)
end

----- Events -----
RegisterNetEvent("feather-admin:TrollHandler", function(event)
    local options = {
        ["LightningStrike"] = function()
            local coords = GetEntityCoords(PlayerPedId())
            ForceLightningFlashAtCoords(coords.x, coords.y, coords.z, -1.0)
        end,
        ["Freeze"] = function()
            if not trolls.isFroze then
                FreezeEntityPosition(PlayerPedId(), true)
                trolls.isFroze = true
            else
                FreezeEntityPosition(PlayerPedId(), false)
                trolls.isFroze = false
            end
        end,
        ["TeleportToHeaven"] = function()
            local coords = GetEntityCoords(PlayerPedId())
            SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z + 1000)
        end,
        ["Kill"] = function()
            SetEntityHealth(PlayerPedId(), 0)
        end,
        ["Cage"] = function()
            if not trolls.isCaged then
                local coords = GetEntityCoords(PlayerPedId())
                trolls.cageObj = Feather.Object:Create('p_prisoncage02x', coords.x, coords.y, coords.z, 0, true, 'standard')
                Citizen.InvokeNative(0x9587913B9E772D29, trolls.cageObj:GetObj(), true) --Using this instead of featheres api for it as the api does not work properly all the time
                trolls.isCaged = true
            else
                trolls.cageObj:Remove()
                trolls.isCaged = false
            end
        end,
        ['forceCinematicCam'] = function()
            if not trolls.isCinematic then
                trolls.isCinematic = true
                while true do
                    Wait(5)
                    if not trolls.isCinematic then
                        SetCinematicModeActive(false)
                        break
                    end
                    SetCinematicModeActive(true)
                end
            else
                trolls.isCinematic = false
            end
        end,
        ["makePedGiant"] = function()
            if not trolls.pedGiant then
                SetPedScale(PlayerPedId(), 3.0)
                trolls.pedGiant = true
            else
                SetPedScale(PlayerPedId(), 1.0)
                trolls.pedGiant = false
            end
        end,
        ["hostilePedArmy"] = function()
            local spawnCountLimit = 0
            local spawnedPeds = {}
            local playerCoords = GetEntityCoords(PlayerPedId())
            repeat
                spawnCountLimit = spawnCountLimit + 1
                local ped = Feather.Ped:Create("casp_hunting02_males_01", playerCoords.x, playerCoords.y, playerCoords.z, 0, 'world', false, true)
                ped:AttackTarget(PlayerPedId(), "LAW")
                table.insert(spawnedPeds, ped)
            until spawnCountLimit >= 10
            while true do
                Wait(0)
                local isAnyPedAlive = false
                for k, v in pairs(spawnedPeds) do
                    if not IsEntityDead(v:GetPed()) then
                        isAnyPedAlive = true
                    end
                    if IsEntityDead(PlayerPedId()) then
                        isAnyPedAlive = false
                    end
                end
                if not isAnyPedAlive then
                    for k, v in pairs(spawnedPeds) do
                        v:Remove()
                    end
                    break
                end
            end
        end,
        ["kickFromVehicle"] = function()
            if IsPedInAnyVehicle(PlayerPedId()) then
                TaskLeaveAnyVehicle(PlayerPedId(), 0, 0)
            end
        end
    }

    if options[event] then
        options[event]()
    end
end)