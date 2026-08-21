AdminUI.Navigation = {
    sections = {},
    items = {}
}

function AdminUI.RegisterNavigationSection(key, labelKey, order)
    if type(key) ~= 'string' or type(labelKey) ~= 'string' then return false end
    AdminUI.Navigation.sections[key] = {
        key = key,
        labelKey = labelKey,
        order = tonumber(order) or 100
    }
    AdminUI.Navigation.items[key] = AdminUI.Navigation.items[key] or {}
    return true
end

function AdminUI.RegisterNavigationItem(sectionKey, item)
    local section = AdminUI.Navigation.sections[sectionKey]
    if not section or type(item) ~= 'table' or type(item.key) ~= 'string'
        or type(item.labelKey) ~= 'string' or type(item.open) ~= 'function' then return false end

    local items = AdminUI.Navigation.items[sectionKey]
    for index, existing in ipairs(items) do
        if existing.key == item.key then
            items[index] = item
            return true
        end
    end
    items[#items + 1] = item
    return true
end

local function canOpen(item)
    if type(item.canOpen) == 'function' then return item.canOpen() == true end
    if type(item.permission) == 'string' then return AdminUI.CanUse(item.permission) end
    if type(item.permissionPrefix) == 'string' then return AdminUI.CanUseAny(item.permissionPrefix) end
    return false
end

local function visibleItems(sectionKey)
    local visible = {}
    for _, item in ipairs(AdminUI.Navigation.items[sectionKey] or {}) do
        if canOpen(item) then visible[#visible + 1] = item end
    end
    table.sort(visible, function(left, right)
        local leftOrder, rightOrder = tonumber(left.order) or 100, tonumber(right.order) or 100
        if leftOrder == rightOrder then return left.key < right.key end
        return leftOrder < rightOrder
    end)
    return visible
end

function AdminUI.HasNavigationItems(sectionKey)
    return #visibleItems(sectionKey) > 0
end

function AdminUI.OpenNavigationSection(sectionKey)
    local section = AdminUI.Navigation.sections[sectionKey]
    if not section then return false end

    local items = visibleItems(sectionKey)
    if #items == 0 then
        AdminUI.NotifyActionDenied()
        return false
    end

    local page = AdminUI.RegisterPage(('navigation_%s'):format(sectionKey))
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate(section.labelKey))
    for _, item in ipairs(items) do
        local entry = item
        AdminUI.AddButton(page, AdminTranslate(entry.labelKey), entry.open)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage(('navigation_%s'):format(sectionKey))
    return true
end

AdminUI.RegisterNavigationSection('server_operations', 'server_operations', 20)
AdminUI.RegisterNavigationSection('moderation_center', 'moderation_center', 30)
AdminUI.RegisterNavigationSection('staff_oversight', 'staff_oversight', 40)
