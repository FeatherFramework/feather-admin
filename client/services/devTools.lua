--[[ Credits
    bonedev by HALALsnackbar for some code snippets and data
    https://github.com/outsider31000/public-scripts/tree/main/server-data/resources/%5Bdev%5D/devgun whomever wrote this script for some code snippets
]]

local DevTools = {
    boneDev = false,
    devGun = false
}

local BoneIndex = { --- https://github.com/femga/rdr3_discoveries/blob/master/boneNames/player_zero__boneNames.lua
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

local function devGunFunct()
    local player = PlayerId()
    local pos = { x = 0.0, y = 0.5 }
    local color = { r = 255, g = 255, b = 255, a = 150 }
    while DevTools.devGun do
        Wait(0)
        if IsPlayerFreeAiming(player) then
            local bool, entity = GetEntityPlayerIsFreeAimingAt(player)
            if bool then
                local text = ("Coords: " .. GetEntityCoords(entity) .. "\nHeading: " .. GetEntityHeading(entity) .. "\nHash: " .. GetEntityModel(entity))
                Feather.Render:DrawText(pos, text, color, 0.4, true)
            end
        end
    end
end

local function showBones()
    local color = { r = 255, g = 255, b = 255, a = 215 }
    while DevTools.boneDev do
        Wait(0)
        local playerPed = PlayerPedId()
        for boneId, bone in pairs(BoneIndex) do
            local index = GetPedBoneIndex(playerPed, boneId)
            if index ~= -1 then
                local coords = GetWorldPositionOfEntityBone(playerPed, index)
                Feather.Render:Draw3DText(coords, bone.index, 0.3, color, 1, 0)
            end
        end
    end
end

function devToolsMenu()
    AdminMenu:Close({})

    local devToolsPage = AdminMenu:RegisterPage("feather-admin:devToolsPage")
    devToolsPage:RegisterElement("header", {
        value = AdminTranslate("devToolsHeader"),
        slot = 'header',
        style = {}
    })
    devToolsPage:RegisterElement("button", {
        label = AdminTranslate("devGun"),
        style = {}
    }, function()
        DevTools.devGun = not DevTools.devGun
        if DevTools.devGun then
            CreateThread(devGunFunct)
        end
    end)
    devToolsPage:RegisterElement("button", {
        label = AdminTranslate("boneDev"),
        style = {}
    }, function()
        DevTools.boneDev = not DevTools.boneDev
        if DevTools.boneDev then
            CreateThread(showBones)
        end
    end)

    AdminMenu:Open({
        startupPage = devToolsPage
    })
end
