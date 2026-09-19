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

local function Callable(value)
    return type(value) == 'function' or (type(value) == 'table'
        and type(rawget(value, '__cfx_functionReference')) == 'string')
end

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
    -- Authority assignment reads are authoritative and uncached.
end

local function AuthorityStaff(characterId)
    if type(characterId) ~= 'string' then return nil end
    local result = exports['feather-authority']:ListSubjectAssignments({
        subjectType = 'character', subjectId = characterId, scopeType = 'server',
        ownerResource = GetCurrentResourceName(), status = 'active'
    })
    if type(result) ~= 'table' or result.ok ~= true then return nil end
    local selected, selectedPrecedence
    for _, assignment in ipairs(result.value or {}) do
        for _, tier in ipairs(Config.authorityMigration.roles or {}) do
            if assignment.roleKey == tier.roleKey
                and (selectedPrecedence == nil or tier.precedence > selectedPrecedence) then
                selected, selectedPrecedence = assignment, tier.precedence
            end
        end
    end
    return selected and { roleKey = selected.roleKey, rolePrecedence = selectedPrecedence,
        roleName = selected.roleLabel, assignmentId = selected.assignmentId,
        assignmentRevision = selected.revision, characterId = characterId,
        authoritySource = 'authority_character_assignment' } or nil
end

function FeatherAdmin.Identity.GetStaff(identity)
    return type(identity) == 'table' and AuthorityStaff(identity.characterId) or nil
end

function FeatherAdmin.Identity.GetStaffByAccountId(accountId)
    if type(accountId) ~= 'string' then return nil end
    local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
    local implementation = type(provider) == 'table' and provider.ok and provider.value.implementation or nil
    if type(implementation) ~= 'table' or not Callable(implementation.ListProfiles) then return nil end
    local profiles = implementation.ListProfiles(accountId)
    if type(profiles) ~= 'table' or not profiles.ok then return nil end
    local selected
    for _, profile in ipairs(profiles.value or {}) do
        local staff = AuthorityStaff(profile.characterId)
        if staff and (not selected or staff.rolePrecedence > selected.rolePrecedence) then
            selected = staff
        end
    end
    return selected
end

function FeatherAdmin.RegisterRPC(name, callback, options)
    return FeatherAdmin.Core.RPC.Register(name, function(params, respond, src)
        if type(params) ~= 'table' then return end
        return callback(params, respond, src)
    end, options)
end

function FeatherAdmin.GetRolePrecedence(src)
    local identity = FeatherAdmin.Identity.Resolve(src)
    local staff = FeatherAdmin.Identity.GetStaff(identity)
    return staff and staff.rolePrecedence or nil
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

local function AuthorityEntitled(src, action)
    local capability = type(Config.authorityActions) == 'table' and Config.authorityActions[action] or nil
    local identity = FeatherAdmin.Identity.Resolve(src)
    if type(capability) ~= 'string' or not identity or type(identity.accountId) ~= 'string' then return false end
    local provider = exports['feather-core']:GetProvider('policy', 'feather-authority', 1)
    if type(provider) ~= 'table' or not provider.ok or type(provider.value) ~= 'table'
        or type(provider.value.implementation) ~= 'table'
        or not Callable(provider.value.implementation.Evaluate) then return false end
    local called, decision = pcall(provider.value.implementation.Evaluate, capability, {
        source = tonumber(src), accountId = identity.accountId, characterId = identity.characterId,
        caller = GetCurrentResourceName(), subject = { resource = GetCurrentResourceName(),
            legacyAction = action }
    })
    return called and type(decision) == 'table' and decision.ok == true
        and type(decision.value) == 'table' and decision.value.allowed == true
end

function FeatherAdmin.CanUse(src, action)
    if not FeatherAdmin.IsActionEnabled(action) then return false end
    return AuthorityEntitled(src, action)
end

function FeatherAdmin.GetPermissions(src)
    local permissions = {}
    local identity = FeatherAdmin.Identity.Resolve(src)
    if not identity or type(identity.characterId) ~= 'string' then return permissions end
    local result = exports['feather-authority']:ListEffectiveCapabilities({
        subjectType = 'character', subjectId = identity.characterId, scopeType = 'server'
    })
    if type(result) ~= 'table' or not result.ok or type(result.value) ~= 'table'
        or type(result.value.capabilities) ~= 'table' then return permissions end
    local effective = {}
    for _, capability in ipairs(result.value.capabilities) do effective[capability] = true end
    for action, capability in pairs(Config.authorityActions or {}) do
        if effective[capability] == true and FeatherAdmin.IsActionEnabled(action) then
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

local function EffectiveCharacterCapabilities(characterId)
    if type(characterId) ~= 'string' then return nil end
    local result = exports['feather-authority']:ListEffectiveCapabilities({
        subjectType = 'character', subjectId = characterId, scopeType = 'server'
    })
    if type(result) ~= 'table' or result.ok ~= true or type(result.value) ~= 'table'
        or type(result.value.capabilities) ~= 'table' then return nil end
    local mapped, effective, count = {}, {}, 0
    for _, capability in pairs(Config.authorityActions or {}) do mapped[capability] = true end
    for _, capability in ipairs(result.value.capabilities) do
        if mapped[capability] and not effective[capability] then
            effective[capability], count = true, count + 1
        end
    end
    return effective, count
end

local function AuthorityDominates(actorCharacterId, targetAccountId, strict)
    local actor, actorCount = EffectiveCharacterCapabilities(actorCharacterId)
    local targetStaff = FeatherAdmin.Identity.GetStaffByAccountId(targetAccountId)
    local target, targetCount = {}, 0
    if targetStaff then
        target, targetCount = EffectiveCharacterCapabilities(targetStaff.characterId)
    end
    if not actor or (targetStaff and not target) then return false, 'authority_unavailable' end
    for capability in pairs(target) do
        if not actor[capability] then return false, 'authority_incomparable' end
    end
    return strict == false or actorCount > targetCount, 'authority_hierarchy'
end

function FeatherAdmin.CanActOnLicense(src, targetLicense, action)
    return false, 'account_required'
end

function FeatherAdmin.CanActOnAccount(src, targetAccountId, action)
    local actorIdentity = FeatherAdmin.Identity.Resolve(src)
    if not actorIdentity or type(targetAccountId) ~= 'string' or targetAccountId == '' then
        return false, 'unresolved_role'
    end

    local settings = hierarchyConfig()
    if actorIdentity.accountId == targetAccountId then
        local allowSelf = type(settings.allowSelf) == 'table' and settings.allowSelf or {}
        return allowSelf[action] == true, 'self'
    end

    local exempt = type(settings.exempt) == 'table' and settings.exempt or {}
    if exempt[action] == true then return true, 'exempt' end

    if type(Config.authorityMigration) == 'table'
        and Config.authorityMigration.enforcement == true
        and Config.authorityMigration.hierarchy == true then
        return AuthorityDominates(actorIdentity.characterId, targetAccountId, settings.strict)
    end

    return AuthorityDominates(actorIdentity.characterId, targetAccountId, settings.strict)
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
        local targetIdentity = FeatherAdmin.Identity.Resolve(targetId)
        if not targetIdentity then
            allowed, reason = false, 'unresolved_role'
        else
            allowed, reason = FeatherAdmin.CanActOnAccount(src, targetIdentity.accountId, action)
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
