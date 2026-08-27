local Inventory = exports['feather-inventory'].initiate()

-- Minimum feather-inventory API contract this file is written against.
local REQUIRED_INVENTORY_CONTRACT = 2

-- Set once the contract has been verified. Every RPC below refuses to run
-- while this is false, so a version mismatch degrades to "the inventory admin
-- tools are unavailable" rather than to silently misread results.
local ContractSatisfied = false
local InspectionContractSatisfied = false

---
-- Verify the inventory contract before serving any inventory RPC.
--
-- A key-existence check cannot detect a changed return shape -- contract 2
-- reshaped every return without renaming a single export, so the API looks
-- identical and answers differently. This is the only gate that catches that.
--
-- The version is read from what the PROVIDER reports, never copied from our
-- own required value: comparing a requirement against itself is a check that
-- can never fail.
CreateThread(function()
    if GetResourceState('feather-inventory') ~= 'started' then
        print('[feather-admin] feather-inventory is not started; inventory admin tools are disabled.')
        return
    end

    local reported = Inventory.GetCapabilities and Inventory.GetCapabilities() or nil
    if type(reported) ~= 'table' or reported.ok ~= true or type(reported.value) ~= 'table' then
        print('[feather-admin] feather-inventory capabilities are unavailable; inventory admin tools are disabled.')
        return
    end

    local contractVersion = tonumber(reported.value.contractVersion) or 0
    if contractVersion < REQUIRED_INVENTORY_CONTRACT then
        print(('[feather-admin] feather-inventory contract %d is too old (requires %d); inventory admin tools are disabled.')
            :format(contractVersion, REQUIRED_INVENTORY_CONTRACT))
        return
    end

    ContractSatisfied = true
    local features = type(reported.value.features) == 'table' and reported.value.features or {}
    InspectionContractSatisfied = features.characterInventoryLookup == true
        and features.adminExactRemoval == true
    if not InspectionContractSatisfied then
        print('[feather-admin] feather-inventory inspection capabilities are unavailable; inspection tools are disabled.')
    end
end)

-- feather-inventory contract 2 answers in result envelopes:
--   { ok = true,  value = <result> }
--   { ok = false, error = { code, message, details } }
--
-- Note the shape of a failed check: a SUCCESS envelope has no `error` key at
-- all, so `if result.error then` reads as false on success and true on
-- failure only by accident of nil-ness. Testing `result.ok` is the only
-- correct form -- the previous code tested `result.error` and therefore fell
-- through the failure branch on success, then read fields that had all moved
-- under `.value`.
local function failed(result)
    return type(result) ~= 'table' or result.ok ~= true
end

local function inventoryTarget(params)
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
    local row = MySQL.single.await([[SELECT a.id AS accountId, a.display_name AS accountName,
        p.character_id AS characterId, CONCAT(p.first_name, ' ', p.last_name) AS characterName
        FROM core_accounts a INNER JOIN character_profiles p
          ON p.account_id COLLATE utf8mb4_unicode_ci = a.id COLLATE utf8mb4_unicode_ci
        WHERE a.id = ? AND p.character_id = ? AND a.status = 'active' AND p.status = 'active' LIMIT 1]],
        { accountId, characterId })
    return row
end

local function targetAudit(row)
    return { accountId = row.accountId, name = row.accountName,
        characterId = row.characterId, characterName = row.characterName }
end

FeatherAdmin.RegisterRPC('feather-admin:inventory:inspect', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'inventory.inspect') or not InspectionContractSatisfied then return end
    local target = inventoryTarget(params)
    if not target or not FeatherAdmin.CheckTargetAccountHierarchy(
            src, 'inventory.inspect', target.accountId, target.serverId) then return end
    local resolved = exports['feather-inventory']:GetCharacterInventory(target.characterId)
    if failed(resolved) then
        return TriggerClientEvent('feather-admin:inventory:inspect:result', src, false,
            'inventory_inspection_unavailable')
    end
    local listed = Inventory.Inventory.GetInventoryItems(resolved.value.id)
    if failed(listed) then
        return TriggerClientEvent('feather-admin:inventory:inspect:result', src, false,
            'inventory_inspection_unavailable')
    end
    local rows = {}
    for _, item in ipairs(listed.value) do
        rows[#rows + 1] = { id = tonumber(item.id), name = item.name,
            displayName = item.display_name or item.name, description = item.description,
            slot = tonumber(item.slot_index), weight = tonumber(item.weight), metadata = item.metadata }
    end
    TriggerClientEvent('feather-admin:inventory:inspect:result', src, true, nil,
        target, rows, resolved.value)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 192 })

FeatherAdmin.RegisterRPC('feather-admin:inventory:remove-instance', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'inventory.remove') or not InspectionContractSatisfied then return end
    local target, instanceId = inventoryTarget(params), tonumber(params.instanceId)
    if not target or not instanceId or instanceId % 1 ~= 0
        or not FeatherAdmin.CheckTargetAccountHierarchy(
            src, 'inventory.remove', target.accountId, target.serverId) then return end
    local removed = exports['feather-inventory']:RemoveCharacterInventoryInstance(
        target.characterId, instanceId, 'admin_remove')
    if failed(removed) then
        local code = type(removed) == 'table' and removed.error and removed.error.code or 'internal'
        AdminAudit.RecordTarget(src, 'inventory.remove.failed', targetAudit(target),
            ('instance=%s reason=%s'):format(instanceId, tostring(code)))
        return TriggerClientEvent('feather-admin:inventory:remove:result', src, false,
            'inventory_remove_' .. tostring(code))
    end
    AdminAudit.RecordTarget(src, 'inventory.remove', targetAudit(target),
        ('instance=%s item=%s'):format(instanceId, tostring(removed.value.itemName)))
    TriggerClientEvent('feather-admin:inventory:remove:result', src, true,
        'inventory_item_removed', removed.value.displayName or removed.value.itemName)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 192 })

FeatherAdmin.RegisterRPC('feather-admin:inventory:catalog', function(_, _, src)
    if not FeatherAdmin.RequirePermission(src, 'inventory.give') then return end

    if not ContractSatisfied then
        return TriggerClientEvent('feather-admin:inventory:result', src, false, 'inventory_catalog_unavailable')
    end

    local listed = Inventory.Items.GetDefinitions()
    if failed(listed) then
        -- Reported rather than returned as an empty catalog. An empty list is
        -- indistinguishable from "this server has no items configured", which
        -- is the wrong thing to show an admin when inventory is simply down.
        local code = type(listed) == 'table' and listed.error and listed.error.code or 'unavailable'
        AdminAudit.Record(src, 'inventory.catalog.failed', nil, ('reason=%s'):format(tostring(code)))
        return TriggerClientEvent('feather-admin:inventory:result', src, false, 'inventory_catalog_unavailable')
    end

    local catalog = {}
    for _, item in ipairs(listed.value) do
        -- Unique definitions carry per-instance state -- a weapon's serial and
        -- ammunition, a tool's condition -- which a generic grant cannot
        -- supply. feather-inventory refuses them outright with
        -- `unique_requires_issuer`, so offering them here would only produce a
        -- button that always fails. Excluded on instance_mode rather than on
        -- item type: the rule is about per-instance state, not about weapons
        -- specifically.
        --
        -- A future weapon-grant feature calls feather-weapons'
        -- Issuance.Issue explicitly. It must never fall back to GrantItem.
        if tostring(item.instance_mode or 'stack') ~= 'unique' then
            catalog[#catalog + 1] = {
                name = tostring(item.name or ''),
                displayName = tostring(item.display_name or item.name or ''),
                description = tostring(item.description or ''),
                category = tostring(item.category or 'other'),
                maxQuantity = tonumber(item.max_quantity),
                maxStackSize = tonumber(item.max_stack_size),
                weight = tonumber(item.weight)
            }
        end
    end
    TriggerClientEvent('feather-admin:inventory:catalog:result', src, catalog)
end, { windowMs = 3000, maxCalls = 2, maxPayloadBytes = 64 })

FeatherAdmin.RegisterRPC('feather-admin:inventory:give', function(params, _, src)
    local target = FeatherAdmin.RequireTarget(src, 'inventory.give', params.playerId)
    if not target then return end

    if not ContractSatisfied then
        return TriggerClientEvent('feather-admin:inventory:result', src, false, 'inventory_catalog_unavailable')
    end

    local itemName = type(params.itemName) == 'string' and params.itemName:match('^%s*(.-)%s*$') or ''
    local quantity = tonumber(params.quantity)
    local maximum = math.max(1, math.floor(tonumber(Config.inventory.maxGrantQuantity) or 100))
    if itemName == '' or not quantity or quantity < 1 or quantity % 1 ~= 0 or quantity > maximum then
        return TriggerClientEvent('feather-admin:inventory:result', src, false, 'invalid_item_grant')
    end

    local result = Inventory.Items.GrantItem(itemName, quantity, target)
    if failed(result) then
        -- Codes stay domain-specific across the envelope migration, so every
        -- inventory_* key here resolves exactly as it did before. That now
        -- includes inventory_unique_requires_issuer, which is what comes back
        -- if a unique definition reaches this path despite the catalog filter
        -- above -- by a stale client, or by a name typed directly.
        local code = type(result) == 'table' and result.error and result.error.code or 'grant_failed'
        AdminAudit.Record(src, 'inventory.give.failed', target,
            ('item=%s quantity=%s reason=%s'):format(itemName, quantity, tostring(code)))
        return TriggerClientEvent('feather-admin:inventory:result', src, false,
            'inventory_' .. tostring(code))
    end

    local granted = result.value
    AdminAudit.Record(src, 'inventory.give', target,
        ('item=%s quantity=%s'):format(granted.itemName, granted.quantity))
    TriggerClientEvent('feather-admin:inventory:result', src, true, 'item_granted',
        granted.displayName, granted.quantity)
    TriggerClientEvent('feather-admin:inventory:received', target, granted.displayName, granted.quantity)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 256 })
