FeatherAdmin = {}

local Feather = exports['feather-core'].initiate()
FeatherAdmin.Core = Feather

function FeatherAdmin.RegisterRPC(name, callback, options)
    return FeatherAdmin.Core.RPC.Register(name, function(params, respond, src)
        if type(params) ~= 'table' then return end
        return callback(params, respond, src)
    end, options)
end

function FeatherAdmin.GetRoleLevel(src)
    local character = Feather.Character.GetCharacter({ src = src })
    if character == nil or character.char == nil then return nil end
    return tonumber(character.char.role_level)
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

local function hierarchyConfig()
    return type(Config.hierarchy) == 'table' and Config.hierarchy or {}
end

local function targetDenied(src, action, targetId, targetLicense, reason)
    FeatherAdmin.Core.Notify.RightNotify(src, 'You cannot target a player of equal or higher rank.', 4000)
    AdminAudit.Record(src, ('%s.blocked'):format(action), targetId,
        ('reason=%s license=%s'):format(reason, tostring(targetLicense or 'unknown')))
end

function FeatherAdmin.CanActOnLicense(src, targetLicense, action)
    local actorLevel = FeatherAdmin.GetRoleLevel(src)
    local actorLicense = FeatherAdmin.Core.User.GetLicense(src)
    if actorLevel == nil or actorLicense == nil or type(targetLicense) ~= 'string' then
        return false, 'unresolved_role'
    end

    local settings = hierarchyConfig()
    local allowSelf = type(settings.allowSelf) == 'table' and settings.allowSelf or {}
    if actorLicense == targetLicense then
        return allowSelf[action] == true, 'self'
    end

    local exempt = type(settings.exempt) == 'table' and settings.exempt or {}
    if exempt[action] == true then return true end

    local targetLevel = FeatherAdmin.Core.User.GetHighestRoleLevel({ license = targetLicense })
    if targetLevel == nil then return false, 'unresolved_role' end

    if settings.strict == false then
        return actorLevel >= targetLevel, 'rank'
    end
    return actorLevel > targetLevel, 'rank'
end

function FeatherAdmin.RequireTarget(src, action, playerId)
    if not FeatherAdmin.RequirePermission(src, action) then return nil end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil then return nil end

    local license = FeatherAdmin.Core.User.GetLicense(target)
    if not FeatherAdmin.CheckTargetHierarchy(src, action, license, target) then return nil end
    return target
end

function FeatherAdmin.CheckTargetHierarchy(src, action, targetLicense, targetId)
    local allowed, reason = FeatherAdmin.CanActOnLicense(src, targetLicense, action)
    if not allowed then
        targetDenied(src, action, targetId, targetLicense, reason)
        return false
    end
    return true
end

FeatherAdmin.RegisterRPC('feather-admin:access:request', function(_, _, src)
    local authorized = FeatherAdmin.IsAuthorized(src)
    if not authorized then FeatherAdmin.Deny(src) end

    TriggerClientEvent('feather-admin:access:result', src, authorized, authorized and FeatherAdmin.GetPermissions(src) or {})
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 64 })

FeatherAdmin.RegisterRPC('feather-admin:access:refresh', function(_, _, src)
    local authorized = FeatherAdmin.IsAuthorized(src)
    TriggerClientEvent('feather-admin:access:permissions', src,
        authorized, authorized and FeatherAdmin.GetPermissions(src) or {})
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 64 })
