local function openModelPage(category, index)
    if not AdminUI.CanUseOnTarget('ped.change') then return end
    local pageKey = ('ped_models_%d'):format(index)
    local page = AdminUI.RegisterPage(pageKey)
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate(category.labelKey))

    for _, ped in ipairs(category.models) do
        local labelKey, model = ped.labelKey, ped.model
        local label = AdminTranslate(labelKey)
        AdminUI.AddButton(page, label, function()
            local target = AdminUI.GetTarget()
            -- The target receives the ped-change result notification. Only
            -- show the generic request message when another player is the
            -- target, otherwise a self-change would display both messages.
            if target == GetPlayerServerId(PlayerId()) then
                AdminPedChanger.Request(target, model)
            else
                AdminUI.RunAction(label, function()
                    AdminPedChanger.Request(target, model)
                end)
            end
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenPedCategories)
    AdminUI.OpenPage(pageKey)
end

function AdminUI.OpenPedCategories()
    if not AdminUI.CanUseOnTarget('ped.change') then return end
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
