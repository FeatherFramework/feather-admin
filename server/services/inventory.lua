local Inventory = exports['feather-inventory'].initiate()

FeatherAdmin.RegisterRPC('feather-admin:inventory:catalog', function(_, _, src)
    if not FeatherAdmin.RequirePermission(src, 'inventory.give') then return end
    local definitions = Inventory.Items.GetDefinitions()
    local catalog = {}
    for _, item in ipairs(type(definitions) == 'table' and definitions or {}) do
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
    if type(result) ~= 'table' or result.error then
        local code = type(result) == 'table' and result.code or 'grant_failed'
        AdminAudit.Record(src, 'inventory.give.failed', target,
            ('item=%s quantity=%s reason=%s'):format(itemName, quantity, tostring(code)))
        return TriggerClientEvent('feather-admin:inventory:result', src, false,
            'inventory_' .. tostring(code))
    end

    AdminAudit.Record(src, 'inventory.give', target,
        ('item=%s quantity=%s'):format(result.itemName, result.quantity))
    TriggerClientEvent('feather-admin:inventory:result', src, true, 'item_granted',
        result.displayName, result.quantity)
    TriggerClientEvent('feather-admin:inventory:received', target, result.displayName, result.quantity)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 256 })
