local trolls = {
    isFroze = false,
    isCaged = false,
    cageObj = nil
}

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
RegisterNetEvent("feather-troll:TrollHandler", function(event)
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
                local model = joaat('p_prisoncage02x')
                loadModel(model)
                local coords = GetEntityCoords(PlayerPedId())
                trolls.cageObj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
                Citizen.InvokeNative(0x9587913B9E772D29, trolls.cageObj, true)
                SetModelAsNoLongerNeeded(model)
                trolls.isCaged = true
            else
                DeleteEntity(trolls.cageObj)
                trolls.isCaged = false
            end
        end
    }

    if options[event] then
        options[event]()
    end
end)