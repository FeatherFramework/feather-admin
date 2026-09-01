FeatherAdmin = {}

local Feather = {}
Feather.RPC = {
    Register = function(name, callback, options)
        return exports['feather-core']:RegisterRPC(name, callback, options)
    end
}
Feather.User = {
    GetLicense = function(source)
        local result = exports['feather-core']:GetPrimaryIdentifier(source)
        return type(result) == 'table' and result.ok == true and result.value.identifier or nil
    end
}
Feather.Connection = {
    RegisterGate = function(name, callback, options)
        return exports['feather-core']:RegisterConnectionGate(name, callback, options)
    end
}
FeatherAdmin.Core = Feather
FeatherAdmin.Identity = {}

function FeatherAdmin.Notify(src, message, duration)
    local result = exports['feather-core']:SendNotification({
        source = src,
        style = 'right',
        message = message,
        duration = duration
    })
    if type(result) ~= 'table' or result.ok ~= true then
        print(('[feather-admin] notification failed source=%s code=%s'):format(
            tostring(src), tostring(type(result) == 'table' and result.code or 'invalid_result')))
    end
    return result
end

local function CharacterProfile(characterId)
    if type(characterId) ~= 'string' then return nil end
    local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
    if type(provider) ~= 'table' or provider.ok ~= true then return nil end
    local result = provider.value.implementation.GetProfile(characterId)
    return type(result) == 'table' and result.ok == true and result.value or nil
end

function FeatherAdmin.Identity.Resolve(src)
    src = tonumber(src)
    if not src then return nil end
    local account = exports['feather-core']:GetAccountContext(src)
    if type(account) ~= 'table' or account.ok ~= true then return nil end
    local session = exports['feather-core']:GetSessionContext(src)
    local sessionValue = type(session) == 'table' and session.ok == true and session.value or nil
    local profile = sessionValue and CharacterProfile(sessionValue.characterId) or nil
    local firstName = profile and profile.firstName or nil
    local lastName = profile and profile.lastName or nil
    local characterName = firstName and (('%s %s'):format(firstName, lastName or ''):gsub('%s+$', '')) or nil
    return {
        source = src,
        accountId = account.value.accountId,
        accountName = account.value.displayName,
        characterId = profile and profile.characterId or nil,
        firstName = firstName,
        lastName = lastName,
        characterName = characterName,
        sessionId = sessionValue and sessionValue.sessionId or nil,
        serverName = GetPlayerName(src)
    }
end

function FeatherAdmin.Identity.Invalidate(accountId)
    -- Role reads are authoritative and uncached in feather-roles.
end

function FeatherAdmin.Identity.GetStaff(identity)
    if type(identity) ~= 'table' or not identity.characterId then return nil end
    local result = exports['feather-roles']:GetCharacterRole(identity.characterId)
    local role = type(result) == 'table' and result.ok == true and result.value.role or nil
    return role and { roleKey = role.key, roleLevel = role.level,
        roleName = role.name, authoritySource = 'character_role' } or nil
end

function FeatherAdmin.Identity.GetStaffByAccountId(accountId)
    local result = exports['feather-roles']:GetHighestAccountRole(accountId)
    local role = type(result) == 'table' and result.ok == true and result.value.role or nil
    return role and { roleKey = role.key, roleLevel = role.level,
        roleName = role.name, authoritySource = 'account_character_max' } or nil
end

function FeatherAdmin.RegisterRPC(name, callback, options)
    return FeatherAdmin.Core.RPC.Register(name, function(params, respond, src)
        if type(params) ~= 'table' then return end
        return callback(params, respond, src)
    end, options)
end

function FeatherAdmin.GetRoleLevel(src)
    local identity = FeatherAdmin.Identity.Resolve(src)
    local staff = FeatherAdmin.Identity.GetStaff(identity)
    return staff and staff.roleLevel or nil
end

function FeatherAdmin.IsActionEnabled(action)
    local identityConfig = Config.identity or {}
    if type(identityConfig.disabledActions) == 'table' and identityConfig.disabledActions[action] then
        return false
    end
    for _, prefix in ipairs(identityConfig.disabledActionPrefixes or {}) do
        if type(prefix) == 'string' and action:sub(1, #prefix) == prefix then return false end
    end
    return true
end

function FeatherAdmin.CanUse(src, action)
    if not FeatherAdmin.IsActionEnabled(action) then return false end
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
        if requiredLevel ~= nil and roleLevel >= requiredLevel and FeatherAdmin.IsActionEnabled(action) then
            permissions[action] = true
        end
    end
    return permissions
end

function FeatherAdmin.IsAuthorized(src)
    return FeatherAdmin.CanUse(src, 'menu.open')
end

function FeatherAdmin.Deny(src)
    FeatherAdmin.Notify(src, 'You do not have permission to use Feather Admin.', 4000)
end

function FeatherAdmin.DenyAction(src)
    FeatherAdmin.Notify(src, 'You do not have permission for that action.', 3000)
end

function FeatherAdmin.RequirePermission(src, action)
    if FeatherAdmin.CanUse(src, action) then return true end

    FeatherAdmin.DenyAction(src)

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
    FeatherAdmin.Notify(src, 'You cannot target a player of equal or higher rank.', 4000)
    AdminAudit.Record(src, ('%s.blocked'):format(action), targetId,
        ('reason=%s license=%s'):format(reason, tostring(targetLicense or 'unknown')))
end

function FeatherAdmin.CanActOnLicense(src, targetLicense, action)
    return false, 'account_required'
end

function FeatherAdmin.CanActOnAccount(src, targetAccountId, action)
    local actorIdentity = FeatherAdmin.Identity.Resolve(src)
    local actorStaff = FeatherAdmin.Identity.GetStaff(actorIdentity)
    if not actorIdentity or not actorStaff or type(targetAccountId) ~= 'string' or targetAccountId == '' then
        return false, 'unresolved_role'
    end

    local settings = hierarchyConfig()
    if actorIdentity.accountId == targetAccountId then
        local allowSelf = type(settings.allowSelf) == 'table' and settings.allowSelf or {}
        return allowSelf[action] == true, 'self'
    end

    local exempt = type(settings.exempt) == 'table' and settings.exempt or {}
    if exempt[action] == true then return true, 'exempt' end

    local targetStaff = FeatherAdmin.Identity.GetStaffByAccountId(targetAccountId)
    local targetLevel = targetStaff and targetStaff.roleLevel or 0
    if settings.strict == false then return actorStaff.roleLevel >= targetLevel, 'rank' end
    return actorStaff.roleLevel > targetLevel, 'rank'
end

function FeatherAdmin.CheckTargetAccountHierarchy(src, action, targetAccountId, targetId)
    local allowed, reason = FeatherAdmin.CanActOnAccount(src, targetAccountId, action)
    if not allowed then
        targetDenied(src, action, targetId, targetAccountId, reason)
        return false
    end
    return true
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
    local allowed, reason
    if targetId ~= nil then
        local actorIdentity = FeatherAdmin.Identity.Resolve(src)
        local targetIdentity = FeatherAdmin.Identity.Resolve(targetId)
        local actorStaff = FeatherAdmin.Identity.GetStaff(actorIdentity)
        if not actorIdentity or not targetIdentity or not actorStaff then
            allowed, reason = false, 'unresolved_role'
        elseif actorIdentity.accountId == targetIdentity.accountId then
            local settings = hierarchyConfig()
            local allowSelf = type(settings.allowSelf) == 'table' and settings.allowSelf or {}
            allowed, reason = allowSelf[action] == true, 'self'
        else
            local settings = hierarchyConfig()
            local exempt = type(settings.exempt) == 'table' and settings.exempt or {}
            local targetStaff = FeatherAdmin.Identity.GetStaffByAccountId(targetIdentity.accountId)
            local targetLevel = targetStaff and targetStaff.roleLevel or 0
            allowed = exempt[action] == true or (settings.strict == false
                and actorStaff.roleLevel >= targetLevel or actorStaff.roleLevel > targetLevel)
            reason = 'rank'
        end
    else
        allowed, reason = FeatherAdmin.CanActOnLicense(src, targetLicense, action)
    end
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
