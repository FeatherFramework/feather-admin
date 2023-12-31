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
            Feather.Render:Draw3DText(boneCoords.x,boneCoords.y,boneCoords.z,v.index,0.2)
        end
    end
end

----- Menus -----
function devToolsMenu()
    MenuAPI.CloseAll()

    local elements = {
        { label = Feather.Locale.translate(0, "boneDev"), value = 'boneDev', desc = Feather.Locale.translate(0, "boneDev_desc") },
        { label = Feather.Locale.translate(0, "devGun"), value = 'devGun', desc = Feather.Locale.translate(0, "devGun_desc") }
    }

    MenuAPI.Open('default', GetCurrentResourceName(), 'menuapi',
        {
            title = "Dev Tools Menu",
            align = 'top-left',
            elements = elements
        },
        function(data, menu)
            if data.current == 'backup' then
                _G[data.trigger]()
            end
            local selectedOption = {
                ['boneDev'] = function()
                    if not devTools.boneDev then
                        devTools.boneDev = true
                        showBones()
                    else
                        devTools.boneDev = false
                    end
                end,
                ['devGun'] = function()
                    if not devTools.devGun then
                        devTools.devGun = true
                        devGunFunct()
                    else
                        devTools.devGun = false
                    end
                end
            }

            if selectedOption[data.current.value] then
                selectedOption[data.current.value]()
            end
        end,
        function(data, menu)
            menu.close()
            mainAdminMenu()
        end)
end