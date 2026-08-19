AdminInventory = {
    items = {},
    selected = nil,
    category = nil,
    page = 1
}

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
