AdminPedChanger = {}

local applyingModel = false

local function loadModel(model)
    if type(model) ~= 'number' or not IsModelValid(model) or not IsModelInCdimage(model) then
        return false
    end

    RequestModel(model)
    local timeout = math.max(1000, tonumber(Config.pedChanger.modelLoadTimeout) or 10000)
    local timeoutAt = GetGameTimer() + timeout

    while not HasModelLoaded(model) do
        if GetGameTimer() >= timeoutAt then
            SetModelAsNoLongerNeeded(model)
            return false
        end
        Wait(50)
    end

    return true
end

local function applyModel(model)
    if not loadModel(model) then
        Feather.Notify.RightNotify(AdminTranslate('ped_change_failed'), 4000)
        applyingModel = false
        return
    end

    local oldPed = PlayerPedId()
    local coords = GetEntityCoords(oldPed)
    local heading = GetEntityHeading(oldPed)
    local oldMaxHealth = math.max(1, GetEntityMaxHealth(oldPed))
    local healthRatio = math.max(0.0, GetEntityHealth(oldPed) / oldMaxHealth)

    SetPlayerModel(PlayerId(), model)
    Wait(0)

    local newPed = PlayerPedId()
    Citizen.InvokeNative(0x283978A15512B2FE, newPed, true)
    SetEntityCoordsNoOffset(newPed, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(newPed, heading)
    SetEntityHealth(newPed, math.floor(GetEntityMaxHealth(newPed) * healthRatio))
    SetModelAsNoLongerNeeded(model)

    if AdminBoosters and AdminBoosters.RefreshPlayerState then
        AdminBoosters.RefreshPlayerState()
    end
    if AdminTrolls and AdminTrolls.RefreshPlayerState then
        AdminTrolls.RefreshPlayerState()
    end

    applyingModel = false
    Feather.Notify.RightNotify(AdminTranslate('ped_change_success'), 3000)
end

function AdminPedChanger.Request(targetPlayer, modelName)
    if targetPlayer == nil or type(modelName) ~= 'string' then return end
    Feather.RPC.Notify('feather-admin:ped:request', { playerId = targetPlayer, modelName = modelName })
end

RegisterNetEvent('feather-admin:ped:apply', function(model)
    if applyingModel then
        Feather.Notify.RightNotify(AdminTranslate('ped_change_busy'), 3000)
        return
    end

    applyingModel = true
    CreateThread(function()
        applyModel(model)
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    applyingModel = false
end)
