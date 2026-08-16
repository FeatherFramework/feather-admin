FeatherAdmin = {}

local Feather = exports['feather-core'].initiate()
FeatherAdmin.Core = Feather

function FeatherAdmin.GetRoleLevel(src)
    local character = Feather.Character.GetCharacter({ src = src })
    if character == nil or character.char == nil then return nil end
    return tonumber(character.char.level)
end

function FeatherAdmin.CanUse(src, action)
    local requiredLevel = tonumber(Config.permissions[action])
    local roleLevel = FeatherAdmin.GetRoleLevel(src)
    return requiredLevel ~= nil and roleLevel ~= nil and roleLevel >= requiredLevel
end

function FeatherAdmin.GetPermissions(src)
    local permissions = {}
    local roleLevel = FeatherAdmin.GetRoleLevel(src)
    if roleLevel == nil then return permissions end

    for action, configuredLevel in pairs(Config.permissions) do
        local requiredLevel = tonumber(configuredLevel)
        if requiredLevel ~= nil and roleLevel >= requiredLevel then permissions[action] = true end
    end
    return permissions
end

function FeatherAdmin.IsAuthorized(src)
    return FeatherAdmin.CanUse(src, 'menu.open')
end

function FeatherAdmin.Deny(src)
    Feather.Notify.RightNotify(src, 'You do not have permission to use Feather Admin.', 4000)
end

function FeatherAdmin.RequirePermission(src, action)
    if FeatherAdmin.CanUse(src, action) then return true end

    FeatherAdmin.Deny(src)

    return false
end

function FeatherAdmin.ValidTarget(playerId)
    local target = tonumber(playerId)
    if target == nil or GetPlayerName(target) == nil then return nil end

    return target
end

RegisterNetEvent('feather-admin:access:request', function()
    local src = source
    local authorized = FeatherAdmin.IsAuthorized(src)
    if not authorized then FeatherAdmin.Deny(src) end

    TriggerClientEvent('feather-admin:access:result', src, authorized, authorized and FeatherAdmin.GetPermissions(src) or {})
end)
