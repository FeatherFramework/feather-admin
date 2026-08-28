local function label(definition)
    return tostring(definition.label or definition.id or AdminTranslate('not_available'))
end

local function backToCharacter()
    local target = AdminWeapons.target or {}
    if target.serverId then
        AdminUI.SetTarget(target.serverId)
        AdminUI.OpenCharacterManagement()
    elseif AdminPlayerDirectory.selected then
        AdminUI.OpenOfflinePlayer(AdminPlayerDirectory.selected)
    else
        AdminUI.OpenPlayers()
    end
end

function AdminUI.OpenWeaponAdmin()
    local page = AdminUI.RegisterPage('weapon_admin')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('weapons_and_ammo'))
    if AdminUI.CanUse('weapons.issue') then
        AdminUI.AddButton(page, AdminTranslate('issue_weapon'), AdminUI.OpenWeaponIssueCatalog)
    end
    if AdminUI.CanUse('weapons.ammo.grant') then
        AdminUI.AddButton(page, AdminTranslate('grant_ammunition'), AdminUI.OpenAmmoGrantCatalog)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), backToCharacter)
    AdminUI.OpenPage('weapon_admin')
end

function AdminUI.OpenWeaponIssueCatalog()
    local page = AdminUI.RegisterPage('weapon_issue_catalog')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('issue_weapon'))
    for _, entry in ipairs(AdminWeapons.weapons) do
        local definition = entry
        AdminUI.AddButton(page, label(definition), function()
            AdminWeapons.selected, AdminWeapons.action = definition, 'weapon'
            AdminUI.OpenWeaponGrantConfirmation()
        end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenWeaponAdmin)
    AdminUI.OpenPage('weapon_issue_catalog')
end

function AdminUI.OpenAmmoGrantCatalog()
    local page = AdminUI.RegisterPage('ammo_grant_catalog')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('grant_ammunition'))
    for _, entry in ipairs(AdminWeapons.ammunition) do
        local definition = entry
        AdminUI.AddButton(page, label(definition), function()
            AdminWeapons.selected, AdminWeapons.action, AdminWeapons.quantity = definition, 'ammo', ''
            AdminUI.OpenAmmoGrantQuantity()
        end)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenWeaponAdmin)
    AdminUI.OpenPage('ammo_grant_catalog')
end

function AdminUI.OpenAmmoGrantQuantity()
    local definition = AdminWeapons.selected
    if not definition then return end
    local page = AdminUI.RegisterPage('ammo_grant_quantity')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), label(definition))
    AdminUI.AddInput(page, AdminTranslate('quantity'), AdminTranslate('required'), function(data)
        AdminWeapons.quantity = data.value
    end, AdminWeapons.quantity)
    AdminUI.AddButton(page, AdminTranslate('continue'), function()
        local quantity = tonumber(AdminWeapons.quantity)
        local maximum = tonumber(Config.weapons.maxAmmoGrantQuantity) or 500
        if not quantity or quantity < 1 or quantity % 1 ~= 0 or quantity > maximum then
            return Feather.Notify.RightNotify(AdminTranslate('invalid_ammo_quantity'), 3000)
        end
        AdminUI.OpenWeaponGrantConfirmation()
    end)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenAmmoGrantCatalog)
    AdminUI.OpenPage('ammo_grant_quantity')
end

function AdminUI.OpenWeaponGrantConfirmation()
    local definition = AdminWeapons.selected
    if not definition then return end
    local page = AdminUI.RegisterPage('weapon_grant_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_action'))
    local details = { ('%s: %s'):format(AdminTranslate('item'), label(definition)) }
    if AdminWeapons.action == 'ammo' then
        details[#details + 1] = ('%s: %s'):format(AdminTranslate('quantity'), AdminWeapons.quantity)
    end
    AdminUI.AddText(page, table.concat(details, '\n'))
    AdminUI.AddButton(page, AdminTranslate('confirm_action'), function()
        if AdminWeapons.action == 'weapon' then
            AdminWeapons.Issue(definition.id)
        else
            AdminWeapons.GrantAmmo(definition.id, tonumber(AdminWeapons.quantity))
        end
    end, AdminUI.Styles.button)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        if AdminWeapons.action == 'weapon' then AdminUI.OpenWeaponIssueCatalog()
        else AdminUI.OpenAmmoGrantQuantity() end
    end)
    AdminUI.OpenPage('weapon_grant_confirmation')
end
