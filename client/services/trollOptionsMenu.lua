local trolls = {
    isFroze = false,
    isCaged = false,
    cageObj = nil,
    isCinematic = false,
    pedGiant = false,
    handcuffed = false,
    lag = false
}

function trollMenu(playerId) --Main all players menu (Menu starts here)
    FeatherAdminMenu:Close({})

    local mainTrollpage = FeatherAdminMenu:RegisterPage("feather-admin:mainTrollpage")

    mainTrollpage:RegisterElement("header", {
        value = "Troll Menu",
        slot = 'header',
        style = {}
    })
    mainTrollpage:RegisterElement('button', {
        label = "Lightning Strike",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "LightningStrike", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Freeze",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "Freeze", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Teleport To Heaven",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "TeleportToHeaven", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Cage",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "Cage", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Force Cinematic Cam",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "forceCinematicCam", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Make Ped Giant",
        style = {}
    }, function()
        TriggerServerEvent('feather-admin:TrollCheck', "makePedGiant", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Spawn Hostile Ped Army",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "hostilePedArmy", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Handcuff Player",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "handcuffPlayer", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Kick From Vehicle",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "kickFromVehicle", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Spawn Hostile Bear",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "hostileBear", playerId)
    end)
    mainTrollpage:RegisterElement('button', {
        label = "Lag",
        style = {}
    }, function()
        TriggerServerEvent("feather-admin:TrollCheck", "lag", playerId)
    end)

    FeatherAdminMenu:Open({
        startupPage = mainTrollpage
    })
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
                while trolls.isCinematic do
                    Wait(5)
                    SetCinematicModeActive(true)
                end
                SetCinematicModeActive(false)
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
                Wait(100)
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
                    end break
                end
            end
        end,
        ["kickFromVehicle"] = function()
            if IsPedInAnyVehicle(PlayerPedId()) then
                TaskLeaveAnyVehicle(PlayerPedId(), 0, 0)
            end
        end,
        ["handcuffPlayer"] = function()
            if not trolls.handcuffed then
                SetEnableHandcuffs(PlayerPedId(), true)
                trolls.handcuffed = true
            else
                SetEnableHandcuffs(PlayerPedId(), false)
                trolls.handcuffed = false
            end
        end,
        ['hostileBear'] = function()
            local playerCoords = GetEntityCoords(PlayerPedId())
            local ped = Feather.Ped:Create("MP_A_C_BEAR_01", playerCoords.x, playerCoords.y, playerCoords.z, 0, 'world', false, true)
            ped:AttackTarget(PlayerPedId(), "LAW")
            while true do
                Wait(100)
                if IsEntityDead(PlayerPedId()) or IsEntityDead(ped:GetPed()) then
                    ped:Remove() break
                end
            end
        end,
        ['lag'] = function()
            if not trolls.lag then
                trolls.lag = true
                local storedPlayerCoords = GetEntityCoords(PlayerPedId())
                while trolls.lag do
                    Wait(5)
                    local currPlayerCoords = GetEntityCoords(PlayerPedId())
                    if Feather.Math.GetDistanceBetween(storedPlayerCoords, currPlayerCoords) >= 5 then
                        storedPlayerCoords = currPlayerCoords
                        local x,y,z = table.unpack(storedPlayerCoords)
                        SetEntityCoords(PlayerPedId(), x - 1, y - 1, z)
                        Citizen.InvokeNative(0x9587913B9E772D29, PlayerPedId(), true)
                    end
                end
            else
                trolls.lag = false
            end
        end
    }

    if options[event] then
        options[event]()
    end
end)