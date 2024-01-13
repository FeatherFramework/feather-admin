----- Variables -----
local boosters = {
    godMode = false,
    visible = false,
    infStamina = false,
    noClip = false
}

----- Local Functions ----
local function infiniteStamina()
    while infStamina do
        Wait(5)
        RestorePlayerStamina(PlayerId(), 100.0)
    end
end

local function noClipHandler()
    local speed = 0.1
    local playerPed = PlayerPedId()
    local  PromptGroup = Feather.Prompt:SetupPromptGroup()
    local speedPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "changeSpeed"), Feather.Keys.SHIFT, 1, 1, true, 'click')
    local forwardPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "forward"), Feather.Keys.MOUSE1, 1, 1, true, 'click')
    local backwardPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "backward"), Feather.Keys.MOUSE2, 1, 1, true, 'click')
    local upPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "up"), Feather.Keys.CTRL, 1, 1, true, 'click')
    local downPrompt = PromptGroup:RegisterPrompt(Feather.Locale.translate(0, "down"), Feather.Keys.LALT, 1, 1, true, 'click')

    local function noClipAction(yoff, zoff, setSpeed) --Credit to vorp admin for this function modified it to make it work
        local newPos = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, yoff * (setSpeed + 0.3), zoff * (setSpeed + 0.3))
        SetEntityVelocity(playerPed, 0.0, 0.0, 0.0)
        SetEntityRotation(playerPed, 0.0, 0.0, 180.0, 0, false)
        SetEntityHeading(playerPed, GetGameplayCamRelativeHeading())
        SetEntityCoordsNoOffset(playerPed, newPos.x, newPos.y, newPos.z, false, false, false)
    end

    --SetEntityVisible(playerPed, false) --Left off for now as first person no clip is iffy still and youll want to know where your char will spawn when exiting noclip
    SetEntityCollision(playerPed, false, true)
    FreezeEntityPosition(playerPed, true)
    SetEveryoneIgnorePlayer(PlayerPedId(), true)
    while noClip do
        Wait(5)
		PromptGroup:ShowGroup("My first prompt group")
        if speedPrompt:HasCompleted() then
            speed = speed + 0.1
            if speed > 2 then speed = 0.1 end
        end

        if IsControlPressed(0, Feather.Keys.MOUSE1) then
            noClipAction(-0.2, 0.0, speed)
        elseif IsControlPressed(0, Feather.Keys.MOUSE2) then
            noClipAction(0.2, 0.0, speed)
        elseif IsControlPressed(0, Feather.Keys.CTRL) then
            noClipAction(0, 1, speed)
        elseif IsControlPressed(0, Feather.Keys.LALT) then
            noClipAction(0, -1, speed)
        end
    end
    SetEntityVisible(playerPed, true)
    SetEntityCollision(playerPed, true, true)
    FreezeEntityPosition(playerPed, false)
    SetEveryoneIgnorePlayer(PlayerPedId(), false)
end

----- Menus -----
function boostersMenu(playerId) --catching the player id so it can be used for either the admin using the menu or if we do pass an id it can be used to modify another player allowing admins to use booster options on other players not just themselves
    local isAdmin = true --is admin is used to hide options that only works on admin client
    if playerId == nil or false then
        playerId = GetPlayerServerId(PlayerId())
    else
        isAdmin = false
    end
    FeatherAdminMenu:Close({})

    local boostersPage = FeatherAdminMenu:RegisterPage("feather-admin:boostersPage")
    boostersPage:RegisterElement("header", {
        value = "Boosters",
        slot = 'header',
        style = {}
    })
    boostersPage:RegisterElement("button", {
        label = "Toggle God Mode",
        style = {}
    }, function()
        TriggerServerEvent('feather-admin:BoosterCheck', "Invincibility", playerId)
    end)
    boostersPage:RegisterElement("button", {
        label = "Toggle Invisibility",
        style = {}
    }, function()
        TriggerServerEvent('feather-admin:BoosterCheck', "Invisibility", playerId)
    end)
    boostersPage:RegisterElement("button", {
        label = "Toggle Infinite Stamina",
        style = {}
    }, function()
        TriggerServerEvent('feather-admin:BoosterCheck', "InfStam", playerId)
    end)
    boostersPage:RegisterElement("button", {
        label = "Heal",
        style = {}
    }, function()
        TriggerServerEvent('feather-admin:BoosterCheck', "Heal", playerId)
    end)
    boostersPage:RegisterElement("button", {
        label = "Kill",
        style = {}
    }, function()
        TriggerServerEvent('feather-admin:BoosterCheck', "kill", playerId)
    end)
    boostersPage:RegisterElement("button", {
        label = "Disable FOW",
        style = {}
    }, function()
        TriggerServerEvent('feather-admin:BoosterCheck', "disableFOW", playerId)
    end)
    boostersPage:RegisterElement("button", {
        label = "Change Ped",
        style = {}
    }, function()
        FeatherAdminMenu:Close({})
        if isAdmin then
            pedChangeMenu(playerId)
        else
            pedChangeMenu(playerId, true)
        end
    end)
    if isAdmin then
        boostersPage:RegisterElement("button", {
            label = "No Clip",
            style = {}
        }, function()
            if not boosters.noClip then
                boosters.noClip = true
                FeatherAdminMenu:Close({})
                boostersMenu()
                noClipHandler()
            else
                boosters.noClip = false
                FeatherAdminMenu:Close({})
                boostersMenu()
            end
        end)
    end

    FeatherAdminMenu:Open({
        startupPage = boostersPage
    })
end

----- Events ----
RegisterNetEvent("feather-admin:BoosterHandler", function(event)
    local options = {
        ["Invisibility"] = function()
            if not boosters.visible then
                SetEntityVisible(PlayerPedId(), false)
                boosters.visible = true
            else
                SetEntityVisible(PlayerPedId(), true)
                boosters.visible = false
            end
        end,
        ["Invincibility"] = function()
            if not boosters.godMode then
                SetEntityInvincible(PlayerPedId(), true)
                boosters.godMode = true
            else
                SetEntityInvincible(PlayerPedId(), false)
                boosters.godMode = false
            end
        end,
        ["InfStam"] = function()
            if not boosters.infStamina then
                boosters.infStamina = true
                infiniteStamina()
            else
                boosters.infStamina = false
            end
        end,
        ["Heal"] = function()
            SetEntityHealth(PlayerPedId(), 100.0)
        end,
        ["kill"] = function()
            SetEntityHealth(PlayerPedId(), 0)
        end,
        ["disableFOW"] = function()
            SetMinimapHideFow(true)
        end
    }

    if options[event] then
        options[event]()
    end
end)