local function openModelPage(category, index)
    if not AdminUI.CanUse('ped.change') then return end
    local pageKey = ('ped_models_%d'):format(index)
    local page = AdminUI.RegisterPage(pageKey)
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate(category.labelKey))

    for _, ped in ipairs(category.models) do
        local labelKey, model = ped.labelKey, ped.model
        local label = AdminTranslate(labelKey)
        AdminUI.AddButton(page, label, function()
            AdminUI.RunAction(label, function()
                AdminPedChanger.Request(AdminUI.GetTarget(), model)
            end)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPedCategories)
    AdminUI.OpenPage(pageKey)
end

function AdminUI.OpenPedCategories()
    if not AdminUI.CanUse('ped.change') then return end
    local page = AdminUI.RegisterPage('ped_categories')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('ped_changer_header'))

    for index, category in ipairs(Config.pedChanger.categories) do
        local categoryEntry, categoryIndex = category, index
        AdminUI.AddButton(page, AdminTranslate(categoryEntry.labelKey), function()
            openModelPage(categoryEntry, categoryIndex)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPedParent)
    AdminUI.OpenPage('ped_categories')
end
