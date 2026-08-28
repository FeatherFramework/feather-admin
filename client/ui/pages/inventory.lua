local function titleCase(value)
    return tostring(value):gsub('_', ' '):gsub('^%l', string.upper)
end

local function itemLabel(item)
    if item.displayName ~= '' then return item.displayName end
    return item.name
end

local function inventoryBack()
    local target = AdminInventory.target or {}
    if target.serverId then
        AdminUI.SetTarget(target.serverId)
        AdminUI.OpenCharacterManagement()
    elseif AdminPlayerDirectory.selected then
        AdminUI.OpenOfflinePlayer(AdminPlayerDirectory.selected)
    else
        AdminUI.OpenPlayers()
    end
end

function AdminUI.OpenInventoryActions()
    if not AdminUI.CanUse('inventory.inspect') and not AdminUI.CanUse('inventory.give') then return end
    local page = AdminUI.RegisterPage('inventory_actions')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('inventory_header'))
    if AdminUI.CanUse('inventory.inspect') then
        AdminUI.AddButton(page, AdminTranslate('inspect_inventory'), AdminInventory.RequestInspection)
    end
    local target = AdminInventory.target or {}
    if target.serverId and AdminUI.CanUseOnTarget('inventory.give', target.serverId) then
        AdminUI.AddButton(page, AdminTranslate('give_item_header'), AdminInventory.RequestCatalog)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), inventoryBack)
    AdminUI.OpenPage('inventory_actions')
end

function AdminUI.OpenInventoryCategories()
    if not AdminUI.CanUseOnTarget('inventory.give') then return end
    local page = AdminUI.RegisterPage('inventory_categories')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('inventory_header'))

    local categories = {}
    for _, item in ipairs(AdminInventory.items) do categories[item.category or 'other'] = true end
    local sorted = {}
    for category in pairs(categories) do sorted[#sorted + 1] = category end
    table.sort(sorted)

    if #sorted == 0 then
        AdminUI.AddText(page, AdminTranslate('no_inventory_items'))
    else
        for _, categoryName in ipairs(sorted) do
            local category = categoryName
            AdminUI.AddButton(page, titleCase(category), function()
                AdminUI.OpenInventoryItems(category, 1)
            end)
        end
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryActions)
    AdminUI.OpenPage('inventory_categories')
end

function AdminUI.OpenInventoryInspection()
    local page = AdminUI.RegisterPage('inventory_inspection')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('inventory_inspection'))
    local target = AdminInventory.target or {}
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('player'),
        tostring(target.characterName or target.accountName or AdminTranslate('not_available'))))
    if #AdminInventory.inspected == 0 then
        AdminUI.AddText(page, AdminTranslate('inventory_empty'))
    else
        for _, entry in ipairs(AdminInventory.inspected) do
            local item = entry
            AdminUI.AddButton(page, ('#%s - %s'):format(item.id,
                item.displayName or item.name or AdminTranslate('not_available')), function()
                AdminInventory.selected = item
                AdminUI.OpenInventoryInstanceDetails()
            end)
        end
    end
    AdminUI.AddButton(page, AdminTranslate('refresh'), AdminInventory.RequestInspection)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryActions)
    AdminUI.OpenPage('inventory_inspection')
end

function AdminUI.OpenInventoryInstanceDetails()
    local item = AdminInventory.selected
    if not item then return end
    local metadata = type(item.metadata) == 'table' and json.encode(item.metadata) or AdminTranslate('not_available')
    local page = AdminUI.RegisterPage('inventory_instance_details')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('inventory_item_details'))
    AdminUI.AddText(page, table.concat({
        ('%s: %s'):format(AdminTranslate('instance_id'), item.id),
        ('%s: %s'):format(AdminTranslate('item'), item.displayName or item.name),
        ('%s: %s'):format(AdminTranslate('item_name'), item.name),
        ('%s: %s'):format(AdminTranslate('slot'), item.slot or AdminTranslate('not_available')),
        ('%s: %s'):format(AdminTranslate('weight'), item.weight or 0),
        ('%s: %s'):format(AdminTranslate('metadata'), metadata)
    }, '\n'))
    if AdminUI.CanUse('inventory.remove') then
        AdminUI.AddButton(page, AdminTranslate('remove_inventory_item'),
            AdminUI.OpenInventoryRemovalConfirmation, AdminUI.Styles.button)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryInspection)
    AdminUI.OpenPage('inventory_instance_details')
end

function AdminUI.OpenInventoryRemovalConfirmation()
    local item = AdminInventory.selected
    if not item or not AdminUI.CanUse('inventory.remove') then return AdminUI.NotifyActionDenied() end
    local page = AdminUI.RegisterPage('inventory_removal_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_inventory_removal'))
    AdminUI.AddText(page, ('#%s - %s'):format(item.id, item.displayName or item.name))
    AdminUI.AddButton(page, AdminTranslate('confirm_remove_item'), function()
        AdminInventory.RemoveInstance(item.id)
    end, AdminUI.Styles.button)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryInstanceDetails)
    AdminUI.OpenPage('inventory_removal_confirmation')
end

function AdminUI.OpenInventoryItems(category, pageNumber)
    if not AdminUI.CanUseOnTarget('inventory.give') then return end
    local pageSize = 20
    local selectedPage = math.max(1, math.floor(tonumber(pageNumber) or 1))
    AdminInventory.category = category
    AdminInventory.page = selectedPage
    local page = AdminUI.RegisterPage('inventory_items')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), titleCase(category))

    local items = {}
    for _, entry in ipairs(AdminInventory.items) do
        if entry.category == category then items[#items + 1] = entry end
    end
    table.sort(items, function(left, right) return itemLabel(left):lower() < itemLabel(right):lower() end)
    local first = (selectedPage - 1) * pageSize + 1
    local last = math.min(#items, first + pageSize - 1)
    for index = first, last do
        local item = items[index]
        AdminUI.AddButton(page, itemLabel(item), function()
            AdminInventory.selected = item
            AdminUI.OpenInventoryGrant()
        end)
    end
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('page'), tostring(selectedPage)))
    if selectedPage > 1 then
        AdminUI.AddButton(page, AdminTranslate('previous_page'), function()
            AdminUI.OpenInventoryItems(category, selectedPage - 1)
        end)
    end
    if last < #items then
        AdminUI.AddButton(page, AdminTranslate('next_page'), function()
            AdminUI.OpenInventoryItems(category, selectedPage + 1)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryCategories)
    AdminUI.OpenPage('inventory_items')
end

function AdminUI.OpenInventoryGrant()
    local item = AdminInventory.selected
    if not item or not AdminUI.CanUseOnTarget('inventory.give') then return end
    local page = AdminUI.RegisterPage('inventory_grant')
    local quantity
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('give_item_header'))
    AdminUI.AddText(page, table.concat({
        itemLabel(item),
        item.description ~= '' and item.description or AdminTranslate('not_available'),
        ('%s: %s'):format(AdminTranslate('item_name'), item.name)
    }, '\n'))
    AdminUI.AddInput(page, AdminTranslate('quantity'), AdminTranslate('required'), function(data)
        quantity = data.value
    end)
    AdminUI.AddButton(page, AdminTranslate('continue'), function()
        local parsed = tonumber(quantity)
        local maximum = tonumber(Config.inventory.maxGrantQuantity) or 100
        if not parsed or parsed < 1 or parsed % 1 ~= 0 or parsed > maximum then
            Feather.Notify.RightNotify(AdminTranslate('invalid_item_quantity'), 3000)
            return
        end
        AdminUI.OpenInventoryConfirmation(parsed)
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenInventoryItems(AdminInventory.category, AdminInventory.page)
    end)
    AdminUI.OpenPage('inventory_grant')
end

function AdminUI.OpenInventoryConfirmation(quantity)
    local item = AdminInventory.selected
    if not item or not AdminUI.CanUseOnTarget('inventory.give') then return end
    local page = AdminUI.RegisterPage('inventory_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_item_grant'))
    AdminUI.AddText(page, table.concat({
        ('%s: %s'):format(AdminTranslate('server_id'), tostring(AdminUI.GetTarget())),
        ('%s: %s'):format(AdminTranslate('item'), itemLabel(item)),
        ('%s: %s'):format(AdminTranslate('quantity'), tostring(quantity))
    }, '\n'))
    AdminUI.AddButton(page, AdminTranslate('confirm_action'), function()
        AdminInventory.Give(item.name, quantity)
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryGrant)
    AdminUI.OpenPage('inventory_confirmation')
end
