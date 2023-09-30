local isFroze, isCaged, cageObj = false, false, nil
function trollMenu(playerId) --Main all players menu (Menu starts here)
    MenuAPI.CloseAll()

    local elements = {
        { label = 'Lightning Strike', value = 'lightningStrike', desc = 'Summon a lightning bolt to strike this player?' },
        { label = 'Toggle Freeze Player', value = 'freeze', desc = 'Toggle Freezing this player in place.' },
        { label = 'Send To Heaven', value = 'heaven', desc = 'Send this player to heaven?' },
        { label = 'Toggle Cage Player', value = 'cage', desc = 'Toggle locking this player in a cage?' },
        { label = 'Kill Player', value = 'kill', desc = 'Kill this player?' }
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
                    TriggerServerEvent('feather-admin:SendLightningStrike', playerId)
                end,
                ['freeze'] = function()
                    TriggerServerEvent('feather-admin:SendFreezePlayer', playerId)
                end,
                ['heaven'] = function()
                    TriggerServerEvent('feather-admin:SendTeleportToHeaven', playerId)
                end,
                ['kill'] = function()
                    TriggerServerEvent('feather-admin:SendKillPlayer', playerId)
                end,
                ['cage'] = function()
                    TriggerServerEvent('feather-admin:SendCagePlayer', playerId)
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
RegisterNetEvent('feather-admin:LightningStrikeHandler', function()
    local coords = GetEntityCoords(PlayerPedId())
    ForceLightningFlashAtCoords(coords.x, coords.y, coords.z, -1.0)
end)

RegisterNetEvent('feather-admin:FreezePlayerHandler', function()
    if not isFroze then
        FreezeEntityPosition(PlayerPedId(), true)
        isFroze = true
    else
        FreezeEntityPosition(PlayerPedId(), false)
        isFroze = false
    end
end)

RegisterNetEvent('feather-admin:SendToHeavenHandler', function()
    local coords = GetEntityCoords(PlayerPedId())
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z + 1000)
end)

RegisterNetEvent('feather-admin:KillplayerHandler', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('feather-admin:CagePlayerlayerHandler', function()
    if not isCaged then
        local model = joaat('p_prisoncage02x')
        loadModel(model)
        local coords = GetEntityCoords(PlayerPedId())
        cageObj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
        Citizen.InvokeNative(0x9587913B9E772D29, cageObj, true)
        SetModelAsNoLongerNeeded(model)
        isCaged = true
    else
        DeleteEntity(cageObj)
        isCaged = false
    end
end)