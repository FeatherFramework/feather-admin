AdminDeveloperTools = {}

local state = {
    entityInspector = false,
    entityInspectorSession = 0,
    boneViewer = false,
    boneViewerSession = 0
}

local boneNames = {
    [21030] = 'skel_head',
    [55120] = 'skel_l_calf',
    [43312] = 'skel_r_calf',
    [14283] = 'skel_neck0',
    [14284] = 'skel_neck1',
    [14285] = 'skel_neck2',
    [30226] = 'skel_l_clavicle',
    [45454] = 'skel_l_foot',
    [33646] = 'skel_r_foot',
    [53675] = 'skel_l_forearm',
    [54187] = 'skel_r_forearm',
    [34606] = 'skel_l_hand',
    [22798] = 'skel_r_hand',
    [65478] = 'skel_l_thigh',
    [6884] = 'skel_r_thigh',
    [37873] = 'skel_l_upperarm',
    [56200] = 'skel_pelvis',
    [14410] = 'skel_spine0'
}

local textPosition = { x = 0.0, y = 0.5 }
local inspectorColor = { r = 255, g = 255, b = 255, a = 180 }
local boneColor = { r = 255, g = 255, b = 255, a = 215 }

local function runEntityInspector(session)
    while state.entityInspector and state.entityInspectorSession == session do
        local player = PlayerId()
        if IsPlayerFreeAiming(player) then
            local found, entity = GetEntityPlayerIsFreeAimingAt(player)
            if found and entity ~= 0 and DoesEntityExist(entity) then
                local coords = GetEntityCoords(entity)
                local text = ('Coords: %s\nHeading: %.2f\nModel: %s'):format(
                    tostring(coords),
                    GetEntityHeading(entity),
                    GetEntityModel(entity)
                )
                exports['feather-toolkit']:DrawText2D({ x = textPosition.x, y = textPosition.y,
                    text = text, color = inspectorColor, scale = 0.4, shadow = true })
            end
        end
        Wait(0)
    end
end

local function runBoneViewer(session)
    while state.boneViewer and state.boneViewerSession == session do
        local ped = PlayerPedId()
        if ped ~= 0 and DoesEntityExist(ped) then
            for boneId, boneName in pairs(boneNames) do
                local boneIndex = GetPedBoneIndex(ped, boneId)
                if boneIndex ~= -1 then
                    local coords = GetWorldPositionOfEntityBone(ped, boneIndex)
                    exports['feather-toolkit']:DrawText3D({ x = coords.x, y = coords.y, z = coords.z,
                        text = boneName, color = boneColor, scale = 0.3 })
                end
            end
        end
        Wait(0)
    end
end

function AdminDeveloperTools.ToggleDevGun()
    state.entityInspector = not state.entityInspector
    state.entityInspectorSession = state.entityInspectorSession + 1
    if state.entityInspector then
        local session = state.entityInspectorSession
        CreateThread(function()
            runEntityInspector(session)
        end)
    end
end

function AdminDeveloperTools.ToggleBoneDisplay()
    state.boneViewer = not state.boneViewer
    state.boneViewerSession = state.boneViewerSession + 1
    if state.boneViewer then
        local session = state.boneViewerSession
        CreateThread(function()
            runBoneViewer(session)
        end)
    end
end

function AdminDeveloperTools.CopyCoordinates(format)
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return false end

    local coords = GetEntityCoords(ped)
    local values = {
        vector3 = ('vector3(%.3f, %.3f, %.3f)'):format(coords.x, coords.y, coords.z),
        vector4 = ('vector4(%.3f, %.3f, %.3f, %.3f)'):format(
            coords.x, coords.y, coords.z, GetEntityHeading(ped)
        ),
        xyz = ('x = %.3f, y = %.3f, z = %.3f'):format(coords.x, coords.y, coords.z),
        heading = ('%.3f'):format(GetEntityHeading(ped))
    }

    local text = values[format]
    if not text then return false end
    local copied = exports['feather-toolkit']:CopyToClipboard(text)
    return type(copied) == 'table' and copied.ok == true
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    state.entityInspector = false
    state.boneViewer = false
    state.entityInspectorSession = state.entityInspectorSession + 1
    state.boneViewerSession = state.boneViewerSession + 1
end)
