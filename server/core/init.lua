FeatherAdmin = {
    requiredRoleLevel = 99
}

local Feather = exports['feather-core'].initiate()

function FeatherAdmin.IsAuthorized(src)
    local character = Feather.Character.GetCharacter({ src = src })
    return character ~= nil
        and character.char ~= nil
        and tonumber(character.char.level) == FeatherAdmin.requiredRoleLevel
end

function FeatherAdmin.Deny(src)
    Feather.Notify.Notify(src, 'You do not have permission to use Feather Admin.', 4000)
end

function FeatherAdmin.RequireAuthorized(src)
    if FeatherAdmin.IsAuthorized(src) then return true end

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

    TriggerClientEvent('feather-admin:access:result', src, authorized)
end)
