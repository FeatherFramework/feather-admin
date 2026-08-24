local Inventory = exports['feather-inventory'].initiate()

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

FeatherAdmin.RegisterRPC('feather-admin:inventory:catalog', function(_, _, src)
    if not FeatherAdmin.RequirePermission(src, 'inventory.give') then return end

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
