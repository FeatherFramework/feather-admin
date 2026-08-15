local applyingModel = false

local function requestModel(model)
    if not IsModelValid(model) or not IsModelInCdimage(model) then return false end

    RequestModel(model)
    local timeoutAt = GetGameTimer() + Config.pedChanger.modelLoadTimeout
    while not HasModelLoaded(model) do
        if GetGameTimer() >= timeoutAt then
            SetModelAsNoLongerNeeded(model)
            return false
        end
        Wait(50)
    end

    return true
end

local selectedTarget
local categoryPage = AdminMenu:RegisterPage('feather-admin:pedCategories')
local modelPages = {}

categoryPage:RegisterElement('header', {
    value = AdminTranslate('pedChangeHeader'),
    slot = 'header',
    style = {}
})

for categoryIndex, category in ipairs(Config.pedChanger.categories) do
    local pageIndex = categoryIndex
    local categoryEntry = category
    local modelPage = AdminMenu:RegisterPage(('feather-admin:pedModels:%d'):format(categoryIndex))
    modelPages[categoryIndex] = modelPage

    modelPage:RegisterElement('header', {
        value = categoryEntry.label,
        slot = 'header',
        style = {}
    })

    for _, ped in ipairs(categoryEntry.models) do
        local pedEntry = ped
        modelPage:RegisterElement('button', {
            label = pedEntry.label,
            style = {}
        }, function()
            if selectedTarget ~= nil then
                TriggerServerEvent('feather-admin:ped:request', selectedTarget, pedEntry.model)
            end
        end)
    end

    categoryPage:RegisterElement('button', {
        label = categoryEntry.label,
        style = {}
    }, function()
        modelPages[pageIndex]:RouteTo()
    end)
end

function OpenPedChanger(targetPlayer)
    selectedTarget = targetPlayer
    AdminMenu:Close({})
    AdminMenu:Open({ startupPage = categoryPage })
end

RegisterNetEvent('feather-admin:ped:apply', function(model)
    if applyingModel then
        Feather.Notify.Notify(AdminTranslate('pedChangeBusy'), 3000)
        return
    end
    applyingModel = true

    CreateThread(function()
        if not requestModel(model) then
            Feather.Notify.Notify(AdminTranslate('pedChangeFailed'), 4000)
            applyingModel = false
            return
        end

        local oldPed = PlayerPedId()
        local coords = GetEntityCoords(oldPed)
        local heading = GetEntityHeading(oldPed)
        local health = GetEntityHealth(oldPed)

        SetPlayerModel(PlayerId(), model)

        local newPed = PlayerPedId()
        Citizen.InvokeNative(0x283978A15512B2FE, newPed, true)
        SetEntityCoordsNoOffset(newPed, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(newPed, heading)
        SetEntityHealth(newPed, math.min(health, GetEntityMaxHealth(newPed)))
        SetModelAsNoLongerNeeded(model)
        Feather.Notify.Notify(AdminTranslate('pedChangeSuccess'), 3000)

        applyingModel = false
    end)
end)
