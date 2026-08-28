-- Admin-owned client gameplay helpers. Keep this surface narrow: these are
-- implementation details for Admin tools, not framework-wide Core contracts.

Feather.KeyCodes = {
    A = 0x7065027D, B = 0x4CC0E2FE, C = 0x9959A6F0, D = 0xB4E465B4,
    E = 0xCEFD9220, F = 0xB2F377E8, G = 0x760A9C6F, H = 0x24978A28,
    I = 0xC1989F95, J = 0xF3830D8E, L = 0x80F28E95, M = 0xE31C6A41,
    N = 0x4BC9DABB, O = 0xF1301666, P = 0xD82E0BD2, Q = 0xDE794E3E,
    R = 0xE30CD707, S = 0xD27782E3, U = 0xD8F73058, V = 0x7F8D09B8,
    W = 0x8FD015D8, X = 0x8CC9CD42, Z = 0x26E9DC00,
    RIGHTBRACKET = 0xA5BDCD3C, LEFTBRACKET = 0x430593AA,
    MOUSE1 = 0x07CE1E61, MOUSE2 = 0xF84FA74F, MOUSE3 = 0xCEE12B50,
    MWUP = 0x3076E97C, CTRL = 0xDB096B85, TAB = 0xB238FE0B,
    SHIFT = 0x8FFC75D6, SPACEBAR = 0xD9D0E1C0, ENTER = 0xC7B5340A,
    BACKSPACE = 0x156F7119, LALT = 0x8AAA0AD4, DEL = 0x4AF4D473,
    PGUP = 0x446258B6, PGDN = 0x3C3DD371, F1 = 0xA8E3F467,
    F4 = 0x1F6D95E5, F6 = 0x3C0A40F2, ['1'] = 0xE6F612E4,
    ['2'] = 0x1CE6D9EB, ['3'] = 0x4F49CC4C, ['4'] = 0x8F9F9E58,
    ['5'] = 0xAB62E997, ['6'] = 0xA1FDE2A6, ['7'] = 0xB03A913B,
    ['8'] = 0x42385422, DOWN = 0x05CA7C52, UP = 0x6319DB71,
    LEFT = 0xA65EBAB4, RIGHT = 0xDEB34313
}

local keyListeners = {}
local keyThreadStarted = false
Feather.Keys = {}

function Feather.Keys:RegisterListener(keyName, callback)
    local keyHash = Feather.KeyCodes[keyName]
    if keyHash == nil or type(callback) ~= 'function' then return nil end
    keyListeners[keyName] = keyListeners[keyName] or {}
    local listeners = keyListeners[keyName]
    listeners[#listeners + 1] = callback
    local index = #listeners

    if not keyThreadStarted then
        keyThreadStarted = true
        CreateThread(function()
            while true do
                Wait(4)
                for registeredName, callbacks in pairs(keyListeners) do
                    local hash = Feather.KeyCodes[registeredName]
                    local pressed = Citizen.InvokeNative(0x580417101DDB492F, 0, hash)
                        or Citizen.InvokeNative(0x91AEF906BCA88877, 0, hash)
                    if pressed then
                        for _, registeredCallback in pairs(callbacks) do
                            local ok, err = pcall(registeredCallback)
                            if not ok then
                                print(('[feather-admin] key listener failed key=%s error=%s'):format(
                                    tostring(registeredName), tostring(err)))
                            end
                        end
                    end
                end
            end
        end)
    end

    return {
        RemoveListener = function()
            if listeners[index] == nil then return false end
            listeners[index] = nil
            return true
        end
    }
end

Feather.Command = {}
function Feather.Command.Register(command, suggestion, callback, params)
    if type(command) ~= 'string' or command == '' or type(callback) ~= 'function' then return false end
    RegisterCommand(command, callback)
    TriggerEvent('chat:addSuggestion', '/' .. command, suggestion, params)
    return true
end

Feather.Map = {
    setFOW = function(toggle) SetMinimapHideFow(toggle == true) end
}

Feather.Math = {
    GetDistanceBetween = function(first, second) return #(first - second) end
}

Feather.Clip = {
    CopyToClipboard = function(text)
        text = tostring(text or '')
        if text == '' then return false end
        SendNUIMessage({ type = 'clipboard', text = text })
        return true
    end
}

Feather.Render = {}
function Feather.Render:DrawText(position, text, color, scale, enableShadow)
    local value = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', tostring(text), Citizen.ResultAsLong())
    SetTextScale(scale, scale)
    SetTextColor(math.floor(color.r), math.floor(color.g), math.floor(color.b), math.floor(color.a))
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
    DisplayText(value, position.x, position.y)
end

function Feather.Render:Draw3DText(position, text, scale, color, font)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(position.x, position.y, position.z)
    if not onScreen then return end
    SetTextColor(math.floor(color.r), math.floor(color.g), math.floor(color.b), math.floor(color.a))
    SetTextScale(scale or 1, scale or 1)
    SetTextFontForCurrentCommand(font or 1)
    SetTextCentre(true)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), x, y)
end

Feather.Object = {}
function Feather.Object:Create(modelName, x, y, z, heading, networked)
    local hash = type(modelName) == 'number' and modelName or GetHashKey(modelName)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
    local entity = CreateObject(hash, x, y, z, networked ~= false)
    SetEntityHeading(entity, heading or 0.0)
    PlaceObjectOnGroundProperly(entity, true)
    FreezeEntityPosition(entity, true)
    SetModelAsNoLongerNeeded(hash)
    return {
        GetObj = function() return entity end,
        Remove = function() DeleteObject(entity) end
    }
end

Feather.Ped = {}
function Feather.Ped:Create(modelName, x, y, z, heading, location, safeGround, options, outfit, networked)
    local hash = type(modelName) == 'number' and modelName or joaat(modelName)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
    local entity = CreatePed(hash, x, y, z, heading or 0.0, networked ~= false, true, false, false)
    Citizen.InvokeNative(0x58A850EAEE20FAA3, entity)
    Citizen.InvokeNative(0x283978A15512B2FE, entity, true)
    SetModelAsNoLongerNeeded(hash)
    return {
        GetPed = function() return entity end,
        AttackTarget = function(_, target, style)
            Citizen.InvokeNative(0xBD75500141E4725C, entity, GetHashKey(style or 'LAW'))
            Citizen.InvokeNative(0xF166E48407BAC484, entity, target or PlayerPedId(), 0, 16)
        end,
        Remove = function()
            DeletePed(entity)
            DeleteEntity(entity)
            Citizen.InvokeNative(0x5E94EA09E7207C16, entity)
        end
    }
end
