local economyFields = {
    { field = 'dollars', key = 'economy_dollars' },
    { field = 'gold', key = 'economy_gold' },
    { field = 'tokens', key = 'economy_tokens' },
    { field = 'xp', key = 'economy_xp' }
}

local function permission(field, operation)
    return ('economy.%s.%s'):format(field, operation)
end

function AdminUI.OpenEconomyConfirmation(field, amount)
    if not AdminUI.CanUse(permission(field, 'remove')) then return end

    local page = AdminUI.RegisterPage('economy_confirmation')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_economy_removal'))
    AdminUI.AddText(page, ('%s: %s\n%s: %s'):format(
        AdminTranslate('economy_type'),
        AdminTranslate(('economy_%s'):format(field)),
        AdminTranslate('economy_amount'),
        tostring(amount)
    ))

    AdminUI.AddButton(page, AdminTranslate('confirm_remove'), function()
        if AdminCharacter.AdjustEconomy(AdminUI.GetTarget(), field, 'remove', amount) then
            AdminUI.OpenCharacterAdministration()
        end
    end, AdminUI.Styles.danger)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenCharacterAdministration)
    AdminUI.OpenPage('economy_confirmation')
end

function AdminUI.OpenCharacterAdministration()
    if not AdminUI.CanUseAny('economy.') and not AdminUI.CanUse('character.restore_model') then return end

    local amount
    local selectedOperation
    local selectedField
    local page = AdminUI.RegisterPage('character_administration')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('character_administration_header'))

    if AdminUI.CanUseAny('economy.') then
        local operationOptions = {}
        for _, operation in ipairs({ 'add', 'remove' }) do
            for _, entry in ipairs(economyFields) do
                if AdminUI.CanUse(permission(entry.field, operation)) then
                    operationOptions[#operationOptions + 1] = {
                        display = AdminTranslate(operation),
                        value = operation
                    }
                    break
                end
            end
        end
        selectedOperation = operationOptions[1].value
        AdminUI.AddArrows(page, AdminTranslate('economy_operation'), operationOptions, 0, function(data)
            selectedOperation = data.value.value
        end)

        AdminUI.AddInput(page, AdminTranslate('economy_amount'), AdminTranslate('economy_amount_placeholder'), function(data)
            amount = data.value
        end)

        local fieldOptions = {}
        for _, entry in ipairs(economyFields) do
            if AdminUI.CanUse(permission(entry.field, 'add')) or AdminUI.CanUse(permission(entry.field, 'remove')) then
                fieldOptions[#fieldOptions + 1] = {
                    display = AdminTranslate(entry.key),
                    value = entry.field
                }
            end
        end
        selectedField = fieldOptions[1].value
        AdminUI.AddArrows(page, AdminTranslate('economy_type'), fieldOptions, 0, function(data)
            selectedField = data.value.value
        end)

        AdminUI.AddButton(page, AdminTranslate('submit'), function()
            local parsedAmount = AdminCharacter.ParseAmount(amount)
            if parsedAmount == nil then
                Feather.Notify.RightNotify(AdminTranslate('invalid_economy_amount'), 3000)
                return
            end
            if not AdminUI.CanUse(permission(selectedField, selectedOperation)) then
                Feather.Notify.RightNotify(AdminTranslate('action_not_permitted'), 3000)
                return
            end

            if selectedOperation == 'remove' then
                AdminUI.OpenEconomyConfirmation(selectedField, parsedAmount)
                return
            end
            AdminCharacter.AdjustEconomy(AdminUI.GetTarget(), selectedField, 'add', parsedAmount)
        end)
    end

    if AdminUI.CanUse('character.restore_model') then
        AdminUI.AddButton(page, AdminTranslate('restore_character_appearance'), function()
            AdminUI.RunAction(AdminTranslate('restore_character_appearance'), function()
                return AdminCharacter.RestoreAppearance(AdminUI.GetTarget())
            end)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenSelectedPlayer)
    AdminUI.OpenPage('character_administration')
end
