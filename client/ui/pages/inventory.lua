local function titleCase(value)
    return tostring(value):gsub('_', ' '):gsub('^%l', string.upper)
end

local function itemLabel(item)
    if item.displayName ~= '' then return item.displayName end
    return item.name
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
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenSelectedPlayer)
    AdminUI.OpenPage('inventory_categories')
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
