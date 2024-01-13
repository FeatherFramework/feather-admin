--[[ Credits
    bonedev by HALALsnackbar for some code snippets and data
    https://github.com/outsider31000/public-scripts/tree/main/server-data/resources/%5Bdev%5D/devgun whomever wrote this script for some code snippets
]]
----- Variables -----
local devTools = {
    boneDev = false,
    devGun = false
}

------ Data ------
local boneIndex = { --- https://github.com/femga/rdr3_discoveries/blob/master/boneNames/player_zero__boneNames.lua
    [21030] = {index = "skel_head"},
    [55120] = {index = "skel_l_calf"},
    [43312] = {index = "skel_r_calf"},
    [14283] = {index = "skel_neck0"},
    [14284] = {index = "skel_neck1"},
    [14285] = {index = "SKEL_Neck2"},
    [30226] = {index = "skel_l_clavicle"},
    [45454] = {index = "skel_l_foot"},
    [33646] = {index = "skel_r_foot"},
    [53675] = {index = "skel_l_forearm"},
    [54187] = {index = "skel_r_forearm"},
    [34606] = {index = "skel_l_hand"},
    [22798] = {index = "skel_r_hand"},
    [65478] = {index = "skel_l_thigh"},
    [6884] =  {index = "skel_r_thigh"},
    [37873] = {index = "skel_l_upperarm"},
    [56200] = {index = "skel_pelvis"},
    [14410] = {index = "skel_spine0"}
}

---- Local functions -----
local function devGunFunct()
    local playerId = PlayerId()
    while devTools.devGun do
        Wait(5)
        if IsPlayerFreeAiming(playerId) then
            local bool, entity = GetEntityPlayerIsFreeAimingAt(playerId)
            if bool then
                local _text = ("Coords: " .. GetEntityCoords(entity) .. "\nHeading: " .. GetEntityHeading(entity) .. "\nHash: " .. GetEntityModel(entity))
                DrawTxt(_text, 0.0, 0.5, 0.4, 0.4, true, 255, 255, 255, 150, false)
            end
        end
    end
end

local function showBones()
    while devTools.boneDev do
        Wait(5)
        --Player Ped Bones
        local playerPed = PlayerPedId()
        for k, v in pairs(boneIndex) do
            local boneCoords = GetWorldPositionOfEntityBone(playerPed,GetPedBoneIndex(playerPed, k))
            DrawText3D(boneCoords.x, boneCoords.y, boneCoords.z ,v.index)
        end
    end
end

----- Menus -----
function devToolsMenu()
    FeatherAdminMenu:Close({})

    local devToolsPage = FeatherAdminMenu:RegisterPage("feather-admin:devToolsPage")
    devToolsPage:RegisterElement("header", {
        value = "Dev Tools",
        slot = 'header',
        style = {}
    })
    devToolsPage:RegisterElement("button", {
        label = "Dev Gun",
        style = {}
    }, function()
        if not devTools.devGun then
            devTools.devGun = true
            devGunFunct()
        else
            devTools.devGun = false
        end
    end)
    devToolsPage:RegisterElement("button", {
        label = "Bone Dev",
        style = {}
    }, function()
        if not devTools.boneDev then
            devTools.boneDev = true
            showBones()
        else
            devTools.boneDev = false
        end
    end)

    FeatherAdminMenu:Open({
        startupPage = devToolsPage
    })
end