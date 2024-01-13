local function mainPedChangeMenu(playerId, recTable, allPlayers) --Set as local as its only ever called in this file (more optimal?)
    FeatherAdminMenu:Close({})

    local mainPedChangePage = FeatherAdminMenu:RegisterPage("feather-admin:mainPedChangePage")
    mainPedChangePage:RegisterElement("header", {
        value = "Ped Change Menu",
        slot = 'header',
        style = {}
    })
    for k, v in pairs(recTable) do
        mainPedChangePage:RegisterElement("button", {
            label = v.model,
            style = {}
        }, function()
            TriggerServerEvent('feather-admin:PedChangeSender', playerId, joaat(v.model))
        end)
    end

    FeatherAdminMenu:Open({
        startupPage = mainPedChangePage
    })
end

function pedChangeMenu(playerId, allPlayers) --Main ped change menu cannot be local as its needed more than just this file
    if playerId == nil or false then
        playerId = PlayerId()
    end

    FeatherAdminMenu:Close({})
    local pedChangePage = FeatherAdminMenu:RegisterPage("feather-admin:pedChangePage")
    pedChangePage:RegisterElement("header", {
        value = "Ped Change Menu",
        slot = 'header',
        style = {}
    })
    pedChangePage:RegisterElement("button", {
        label = "Human Peds",
        style = {}
    }, function()
        FeatherAdminMenu:Close({})
        if allPlayers then
            mainPedChangeMenu(playerId, Config.Setup.PedChangingMenu.HumanPeds, true)
        else
            mainPedChangeMenu(playerId, Config.Setup.PedChangingMenu.HumanPeds)
        end
    end)
    pedChangePage:RegisterElement("button", {
        label = "Animal Peds",
        style = {}
    }, function()
        FeatherAdminMenu:Close({})
        if allPlayers then
            mainPedChangeMenu(playerId, Config.Setup.PedChangingMenu.AnimalPeds, true)
        else
            mainPedChangeMenu(playerId, Config.Setup.PedChangingMenu.AnimalPeds)
        end
    end)

    FeatherAdminMenu:Open({
        startupPage = pedChangePage
    })
end

RegisterNetEvent('feather-admin:PedChangeHandler', function(model)
    loadModel(model)
    SetPlayerModel(PlayerId(), model) --Native only works with playerid aka source (Player ped Id will change after this runs so you have to get the player ped id again for the outfit variation)
    Citizen.InvokeNative(0x283978A15512B2FE, PlayerPedId(), true) --Setting random outfit variation
    SetModelAsNoLongerNeeded(model) --Setting model as no longer needed for optimization purposes first time I have used this native
end)