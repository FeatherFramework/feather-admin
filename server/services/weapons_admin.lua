local function IsCallable(value)
    return type(value) == 'function'
        or (type(value) == 'table'
            and type(rawget(value, '__cfx_functionReference')) == 'string')
end

local function weaponsApi()
    if GetResourceState('feather-weapons') ~= 'started' then return nil end
    local ok, api = pcall(function()
        return exports['feather-weapons'].initiate()
    end)
    if not ok or type(api) ~= 'table' then return nil end
    return api
end

local function printSlots(command, source, result)
    if type(result) ~= 'table' or result.ok ~= true then
        local failure = result and result.error or nil
        print(('[%s] FAIL source=%s code=%s message=%s'):format(command,
            tostring(source), tostring(failure and failure.code),
            tostring(failure and failure.message)))
        return
    end
    for _, slot in ipairs({ 'primary', 'offhand' }) do
        local item = result.value.slots and result.value.slots[slot] or nil
        local total = item and (tonumber(item.ammo)
            or ((tonumber(item.loaded) or 0) + (tonumber(item.reserve) or 0))) or nil
        local runtimeMatch = item and item.runtimeMatches
        if runtimeMatch == nil then runtimeMatch = 'n/a' end
        print(('[%s] PASS source=%s slot=%s equipped=%s item=%s definition=%s generation=%s total=%s loaded=%s reserve=%s condition=%s runtimeMatch=%s'):format(
            command, tostring(source), slot, tostring(item ~= nil),
            tostring(item and item.itemInstanceId), tostring(item and item.definitionId),
            tostring(item and item.generation), tostring(total),
            tostring(item and item.loaded), tostring(item and item.reserve),
            tostring(item and item.condition), tostring(runtimeMatch)))
    end
end

RegisterCommand('AdminWeaponInspect', function(source, args)
    if source ~= 0 then return end
    local targetSource = tonumber(args and args[1])
    if not targetSource then
        return print('[AdminWeaponInspect] usage: AdminWeaponInspect <serverId>')
    end
    printSlots('AdminWeaponInspect', targetSource,
        exports['feather-weapons']:InspectEquippedWeapons(targetSource))
end, true)

RegisterCommand('AdminWeaponReconcile', function(source, args)
    if source ~= 0 then return end
    local targetSource = tonumber(args and args[1])
    if not targetSource then
        return print('[AdminWeaponReconcile] usage: AdminWeaponReconcile <serverId>')
    end
    printSlots('AdminWeaponReconcile', targetSource,
        exports['feather-weapons']:ReconcileEquippedWeapons(targetSource))
end, true)

local function target(params)
    local serverId = tonumber(params and params.serverId)
    if serverId and GetPlayerName(serverId) then
        local identity = FeatherAdmin.Identity.Resolve(serverId)
        if identity and identity.accountId and identity.characterId then
            return { serverId = serverId, accountId = identity.accountId,
                accountName = identity.accountName or identity.serverName,
                characterId = identity.characterId, characterName = identity.characterName }
        end
    end
    local accountId = type(params and params.accountId) == 'string' and params.accountId or nil
    local characterId = type(params and params.characterId) == 'string' and params.characterId or nil
    if not accountId or not characterId then return nil end
    return MySQL.single.await([[SELECT a.id AS accountId, a.display_name AS accountName,
        p.character_id AS characterId, CONCAT(p.first_name, ' ', p.last_name) AS characterName
        FROM core_accounts a INNER JOIN character_profiles p
          ON p.account_id COLLATE utf8mb4_unicode_ci = a.id COLLATE utf8mb4_unicode_ci
        WHERE a.id = ? AND p.character_id = ? AND a.status = 'active' AND p.status = 'active' LIMIT 1]],
        { accountId, characterId })
end

local function auditTarget(row)
    return { accountId = row.accountId, name = row.accountName,
        characterId = row.characterId, characterName = row.characterName }
end

local function failed(result)
    return type(result) ~= 'table' or result.ok ~= true
end

FeatherAdmin.RegisterRPC('feather-admin:weapons:catalog', function(_, _, src)
    if not FeatherAdmin.CanUse(src, 'weapons.issue') and not FeatherAdmin.CanUse(src, 'weapons.ammo.grant') then
        return FeatherAdmin.DenyAction(src)
    end
    local Weapons = weaponsApi()
    if not Weapons then
        return TriggerClientEvent('feather-admin:weapons:result', src, false, 'weapons_unavailable')
    end
    local capabilities = Weapons.GetCapabilities and Weapons.GetCapabilities() or nil
    if type(capabilities) ~= 'table' or capabilities.ready ~= true then
        return TriggerClientEvent('feather-admin:weapons:result', src, false, 'weapons_unavailable')
    end
    local weaponResult = Weapons.Definitions.List('weapon')
    local ammoResult = Weapons.Definitions.List('ammunition')
    if failed(weaponResult) or failed(ammoResult) then
        return TriggerClientEvent('feather-admin:weapons:result', src, false, 'weapons_unavailable')
    end
    TriggerClientEvent('feather-admin:weapons:catalog:result', src,
        FeatherAdmin.CanUse(src, 'weapons.issue') and weaponResult.value or {},
        FeatherAdmin.CanUse(src, 'weapons.ammo.grant') and ammoResult.value or {})
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 64 })

FeatherAdmin.RegisterRPC('feather-admin:weapons:issue', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'weapons.issue') then return end
    local subject = target(params)
    local definitionId = type(params.definitionId) == 'string' and params.definitionId or nil
    if not subject or not definitionId or not FeatherAdmin.CheckTargetAccountHierarchy(
            src, 'weapons.issue', subject.accountId, subject.serverId) then return end
    local actor = FeatherAdmin.Identity.Resolve(src)
    local issued = exports['feather-weapons']:IssueWeapon({
        characterId = subject.characterId,
        definitionId = definitionId,
        condition = tonumber(Config.weapons.issuedCondition) or 100,
        provenance = { type = 'admin_grant', reference = subject.accountId }
    }, {
        actorSource = subject.serverId == src and src or nil,
        actorCharacterId = actor and actor.characterId,
        characterId = subject.characterId,
        reason = 'admin_weapon_grant',
        resource = 'feather-admin'
    })
    if failed(issued) then
        local code = issued and issued.error and issued.error.code or 'internal'
        AdminAudit.RecordTarget(src, 'weapons.issue.failed', auditTarget(subject),
            ('definition=%s reason=%s'):format(definitionId, tostring(code)))
        return TriggerClientEvent('feather-admin:weapons:result', src, false, 'weapon_issue_failed')
    end
    AdminAudit.RecordTarget(src, 'weapons.issue', auditTarget(subject),
        ('definition=%s instance=%s serial=%s'):format(definitionId,
            issued.value.itemInstanceId, issued.value.serialNumber))
    TriggerClientEvent('feather-admin:weapons:result', src, true, 'weapon_issued',
        issued.value.definitionId, issued.value.serialNumber)
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 256 })

FeatherAdmin.RegisterRPC('feather-admin:weapons:grant-ammo', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'weapons.ammo.grant') then return end
    local subject = target(params)
    local definitionId = type(params.definitionId) == 'string' and params.definitionId or nil
    local quantity = math.floor(tonumber(params.quantity) or 0)
    local maximum = math.max(1, math.min(tonumber(Config.weapons.maxAmmoGrantQuantity) or 500, 10000))
    if not subject or not definitionId or quantity < 1 or quantity > maximum
        or not FeatherAdmin.CheckTargetAccountHierarchy(
            src, 'weapons.ammo.grant', subject.accountId, subject.serverId) then return end
    local Weapons = weaponsApi()
    if not Weapons then
        return TriggerClientEvent('feather-admin:weapons:result', src, false, 'weapons_unavailable')
    end
    local definition = Weapons.Definitions.Get('ammunition', definitionId)
    if failed(definition) or type(definition.value.itemName) ~= 'string' then
        return TriggerClientEvent('feather-admin:weapons:result', src, false, 'ammo_definition_invalid')
    end
    local granted = exports['feather-inventory']:GrantCharacterItem(
        subject.characterId, definition.value.itemName, quantity, 'admin_ammo_grant')
    if failed(granted) then
        local code = granted and granted.error and granted.error.code or 'internal'
        AdminAudit.RecordTarget(src, 'weapons.ammo.grant.failed', auditTarget(subject),
            ('definition=%s quantity=%s reason=%s'):format(definitionId, quantity, tostring(code)))
        return TriggerClientEvent('feather-admin:weapons:result', src, false, 'ammo_grant_failed')
    end
    AdminAudit.RecordTarget(src, 'weapons.ammo.grant', auditTarget(subject),
        ('definition=%s quantity=%s'):format(definitionId, quantity))
    TriggerClientEvent('feather-admin:weapons:result', src, true, 'ammo_granted',
        definition.value.label or definitionId, quantity)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 256 })
