AdminTrolls = {}

local state = {
    running = true,
    frozen = false,
    frozenPed = nil,
    freezeSession = 0,
    caged = false,
    cage = nil,
    cinematic = false,
    cinematicSession = 0,
    giant = false,
    handcuffed = false,
    lag = false,
    lagSession = 0,
    spawnedPeds = {}
}

local function isValidEntity(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function removeCage()
    if state.cage then exports['feather-toolkit']:RemoveEntity(state.cage.id) end
    state.cage = nil
    state.caged = false
end

local function trackPed(ped)
    if ped then
        state.spawnedPeds[#state.spawnedPeds + 1] = ped
    end
end

local function removeTrackedPed(ped)
    for index = #state.spawnedPeds, 1, -1 do
        if state.spawnedPeds[index] == ped then
            table.remove(state.spawnedPeds, index)
            break
        end
    end
    exports['feather-toolkit']:RemoveEntity(ped.id)
end

local function cleanupSpawnedPeds()
    for index = #state.spawnedPeds, 1, -1 do
        exports['feather-toolkit']:RemoveEntity(state.spawnedPeds[index].id)
    end
    state.spawnedPeds = {}
end

local function runFreeze(session)
    while state.frozen and state.freezeSession == session do
        local ped = PlayerPedId()
        if state.frozenPed ~= ped then
            if isValidEntity(state.frozenPed) then
                FreezeEntityPosition(state.frozenPed, false)
            end
            state.frozenPed = ped
            FreezeEntityPosition(ped, true)
        end
        Wait(250)
    end

    if isValidEntity(state.frozenPed) then
        FreezeEntityPosition(state.frozenPed, false)
    end
    state.frozenPed = nil
end

local function toggleFreeze()
    state.frozen = not state.frozen
    state.freezeSession = state.freezeSession + 1
    if state.frozen then
        local session = state.freezeSession
        state.frozenPed = PlayerPedId()
        FreezeEntityPosition(state.frozenPed, true)
        CreateThread(function() runFreeze(session) end)
    end
end

local function toggleCage()
    if state.caged then
        removeCage()
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local created = exports['feather-toolkit']:CreateObject({ model = 'p_prisoncage02x',
        x = coords.x, y = coords.y, z = coords.z, heading = 0.0, networked = true })
    if type(created) ~= 'table' or created.ok ~= true or type(created.value) ~= 'table' then return end
    local cage = created.value

    state.cage = cage
    state.caged = true
    Citizen.InvokeNative(0x9587913B9E772D29, cage.entity, true) -- PlaceEntityOnGroundProperly
end

local function runCinematic(session)
    while state.cinematic and state.cinematicSession == session do
        SetCinematicModeActive(true)
        Wait(0)
    end
    SetCinematicModeActive(false)
end

local function toggleCinematic()
    state.cinematic = not state.cinematic
    state.cinematicSession = state.cinematicSession + 1
    if state.cinematic then
        local session = state.cinematicSession
        CreateThread(function() runCinematic(session) end)
    else
        SetCinematicModeActive(false)
    end
end

local function monitorHostilePed(ped)
    while state.running do
        local entity = ped.entity
        if not isValidEntity(entity) or IsEntityDead(entity) or IsEntityDead(PlayerPedId()) then break end
        Wait(500)
    end
    removeTrackedPed(ped)
end

local function createHostilePed(model, x, y, z, heading)
    local created = exports['feather-toolkit']:CreatePed({ model = model, x = x, y = y, z = z,
        heading = heading, networked = true })
    if type(created) ~= 'table' or created.ok ~= true or type(created.value) ~= 'table' then return end
    local ped = created.value

    trackPed(ped)
    Citizen.InvokeNative(0x58A850EAEE20FAA3, ped.entity)
    Citizen.InvokeNative(0xBD75500141E4725C, ped.entity, GetHashKey('LAW'))
    Citizen.InvokeNative(0xF166E48407BAC484, ped.entity, PlayerPedId(), 0, 16)
    CreateThread(function() monitorHostilePed(ped) end)
end

local function spawnHostileArmy()
    local coords = GetEntityCoords(PlayerPedId())
    for index = 1, 10 do
        if not state.running then return end

        local angle = math.rad((index - 1) * 36)
        createHostilePed('casp_hunting02_males_01', coords.x + math.cos(angle) * 4.0,
            coords.y + math.sin(angle) * 4.0, coords.z, math.deg(angle) + 180.0)
        Wait(50)
    end
end

local function spawnHostileBear()
    local playerPed = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 5.0, 0.0)
    createHostilePed('MP_A_C_BEAR_01', coords.x, coords.y, coords.z, GetEntityHeading(playerPed) + 180.0)
end

local function runLag(session, storedCoords)
    while state.lag and state.lagSession == session do
        local ped = PlayerPedId()
        local currentCoords = GetEntityCoords(ped)
        if #(storedCoords - currentCoords) >= 5.0 then
            storedCoords = currentCoords
            SetEntityCoordsNoOffset(ped, currentCoords.x - 1.0, currentCoords.y - 1.0, currentCoords.z,
                false, false, false)
            Citizen.InvokeNative(0x9587913B9E772D29, ped, true) -- PlaceEntityOnGroundProperly
        end
        Wait(100)
    end
end

local function toggleLag()
    state.lag = not state.lag
    state.lagSession = state.lagSession + 1
    if state.lag then
        local session = state.lagSession
        local coords = GetEntityCoords(PlayerPedId())
        CreateThread(function() runLag(session, coords) end)
    end
end

function AdminTrolls.Request(action, targetPlayer, requestId)
    if targetPlayer == nil then return end
    Feather.RPC.Notify('feather-admin:troll:request', {
        action = action, playerId = targetPlayer, requestId = requestId
    })
end

function AdminTrolls.RefreshPlayerState()
    local ped = PlayerPedId()
    if state.frozen then
        state.frozenPed = ped
        FreezeEntityPosition(ped, true)
    end

    SetPedScale(ped, state.giant and 3.0 or 1.0)
    SetEnableHandcuffs(ped, state.handcuffed)
end

local actionHandlers = {
    lightning_strike = function()
        local coords = GetEntityCoords(PlayerPedId())
        ForceLightningFlashAtCoords(coords.x, coords.y, coords.z, -1.0)
    end,

    freeze = toggleFreeze,

    teleport_to_heaven = function()
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 1000.0, false, false, false)
    end,

    cage = toggleCage,

    force_cinematic_camera = toggleCinematic,

    make_ped_giant = function()
        state.giant = not state.giant
        SetPedScale(PlayerPedId(), state.giant and 3.0 or 1.0)
    end,

    hostile_ped_army = function() CreateThread(spawnHostileArmy) end,

    kick_from_vehicle = function()
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then TaskLeaveAnyVehicle(ped, 0, 0) end
    end,

    handcuff = function()
        state.handcuffed = not state.handcuffed
        SetEnableHandcuffs(PlayerPedId(), state.handcuffed)
    end,

    hostile_bear = function() CreateThread(spawnHostileBear) end,

    lag = toggleLag
}

RegisterNetEvent('feather-admin:troll:apply', function(action)
    local handler = actionHandlers[action]
    if handler then handler() end
end)

RegisterNetEvent('feather-admin:troll:toggle:result', function(requestId, succeeded)
    AdminUI.ResolveServerToggle(requestId, succeeded)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    state.running = false
    state.frozen = false
    state.freezeSession = state.freezeSession + 1
    state.cinematic = false
    state.cinematicSession = state.cinematicSession + 1
    state.lag = false
    state.lagSession = state.lagSession + 1

    if isValidEntity(state.frozenPed) then
        FreezeEntityPosition(state.frozenPed, false)
    end

    SetCinematicModeActive(false)
    removeCage()
    cleanupSpawnedPeds()

    local ped = PlayerPedId()
    SetPedScale(ped, 1.0)
    SetEnableHandcuffs(ped, false)
end)
