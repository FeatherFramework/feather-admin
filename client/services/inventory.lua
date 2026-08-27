AdminInventory = {
    items = {},
    selected = nil,
    category = nil,
    page = 1,
    target = nil,
    inspected = {},
    inspection = nil
}

local function targetPayload(extra)
    local target = AdminInventory.target or {}
    local payload = { serverId = target.serverId, accountId = target.accountId,
        characterId = target.characterId }
    for key, value in pairs(extra or {}) do payload[key] = value end
    return payload
end

function AdminInventory.SetOnlineTarget(serverId)
    AdminInventory.target = { serverId = serverId }
end

function AdminInventory.SetTarget(target)
    AdminInventory.target = type(target) == 'table' and target or nil
end

function AdminInventory.RequestInspection()
    if not AdminUI.CanUse('inventory.inspect') then return AdminUI.NotifyActionDenied() end
    Feather.RPC.Notify('feather-admin:inventory:inspect', targetPayload())
end

function AdminInventory.RemoveInstance(instanceId)
    Feather.RPC.Notify('feather-admin:inventory:remove-instance',
        targetPayload({ instanceId = instanceId }))
end

function AdminInventory.RequestCatalog()
    if not AdminUI.CanUseOnTarget('inventory.give') then return false end
    Feather.RPC.Notify('feather-admin:inventory:catalog', {})
    return true
end

function AdminInventory.Give(itemName, quantity)
    Feather.RPC.Notify('feather-admin:inventory:give', {
        playerId = AdminUI.GetTarget(),
        itemName = itemName,
        quantity = quantity
    })
end

RegisterNetEvent('feather-admin:inventory:catalog:result', function(items)
    AdminInventory.items = type(items) == 'table' and items or {}
    AdminUI.OpenInventoryCategories()
end)

RegisterNetEvent('feather-admin:inventory:result', function(succeeded, messageKey, displayName, quantity)
    local message = AdminTranslate(messageKey)
    if succeeded then
        message = ('%s: %s x%s'):format(message, tostring(displayName), tostring(quantity))
        AdminUI.Close()
    end
    Feather.Notify.RightNotify(message, 3500)
end)

RegisterNetEvent('feather-admin:inventory:received', function(displayName, quantity)
    Feather.Notify.RightNotify(('%s: %s x%s'):format(
        AdminTranslate('item_received'), tostring(displayName), tostring(quantity)), 3500)
end)

RegisterNetEvent('feather-admin:inventory:inspect:result', function(succeeded, messageKey, target, rows, inventory)
    if succeeded ~= true then
        return Feather.Notify.RightNotify(AdminTranslate(messageKey or 'inventory_inspection_unavailable'), 3500)
    end
    AdminInventory.target = type(target) == 'table' and target or AdminInventory.target
    AdminInventory.inspected = type(rows) == 'table' and rows or {}
    AdminInventory.inspection = type(inventory) == 'table' and inventory or nil
    AdminUI.OpenInventoryInspection()
end)

RegisterNetEvent('feather-admin:inventory:remove:result', function(succeeded, messageKey, displayName)
    local message = AdminTranslate(messageKey or 'inventory_remove_internal')
    if displayName then message = ('%s: %s'):format(message, tostring(displayName)) end
    Feather.Notify.RightNotify(message, 3500)
    if succeeded == true then AdminInventory.RequestInspection() end
end)
