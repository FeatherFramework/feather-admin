--[[ Credits
    bonedev by HALALsnackbar for some code snippets and data
    https://github.com/outsider31000/public-scripts/tree/main/server-data/resources/%5Bdev%5D/devgun whomever wrote this script for some code snippets
]]
----- Variables -----
local boneDev, devGun = false, false

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

----- Menus -----
function devToolsMenu()
    VORPMenu.CloseAll()

    local elements = {}
    if not boneDev then
        table.insert(elements, { label = "Enable Bone Dev", value = 'boneDev', desc = "Toggle Bone Dev which shows all bones on the players ped." })
    else
        table.insert(elements, { label = "Disable Bone Dev", value = 'boneDev', desc = "Toggle Bone Dev which shows all bones on the players ped." })
    end

    if not devGun then
        table.insert(elements, { label = "Enable Dev Gun", value = 'devGun', desc = "Toggle Dev gun which will display information about an entity or object when you aim at it." })
    else
        table.insert(elements, { label = "Disable Dev Gun", value = 'devGun', desc = "Toggle Dev gun which will display information about an entity or object when you aim at it." })
    end

    VORPMenu.Open('default', GetCurrentResourceName(), 'vorp_menu',
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
                    if not boneDev then
                        VORPMenu.CloseAll()
                        boneDev = true
                        devToolsMenu()
                        showBones()
                    else
                        VORPMenu.CloseAll()
                        boneDev = false
                        devToolsMenu()
                    end
                end,
                ['devGun'] = function()
                    if not devGun then
                        devGun = true
                        VORPMenu.CloseAll()
                        devToolsMenu()
                        devGunFunct()
                    else
                        devGun = false
                        VORPMenu.CloseAll()
                        devToolsMenu()
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

----- Functions ----
function showBones()
    while boneDev do
        Wait(5)
        --Player Ped Bones
        local playerPed = PlayerPedId()
        for k, v in pairs(boneIndex) do
            local boneCoords = GetWorldPositionOfEntityBone(playerPed,GetPedBoneIndex(playerPed, k))
            Feather.Render:Draw3DText(boneCoords.x,boneCoords.y,boneCoords.z,v.index,0.2)
        end
    end
end

function devGunFunct()
    local playerId = PlayerId()
    while devGun do
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