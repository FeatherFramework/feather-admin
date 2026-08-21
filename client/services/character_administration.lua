AdminCharacter = {
    economySummary = nil
}

local economyFields = { 'dollars', 'gold', 'tokens', 'xp' }

local function availableEconomyPermission()
    for _, operation in ipairs({ 'add', 'remove' }) do
        for _, field in ipairs(economyFields) do
            local permission = ('economy.%s.%s'):format(field, operation)
            if AdminUI.CanUseOnTarget(permission) then return field, operation end
        end
    end
end

function AdminCharacter.ParseAmount(value)
    local amount = tonumber(value)
    local maximum = tonumber(Config.economy.maxAmount) or 1000000
    if amount == nil or amount ~= amount or amount <= 0 or amount > maximum then return nil end
    return amount
end

function AdminCharacter.AdjustEconomy(target, field, operation, amount)
    if target == nil or AdminCharacter.ParseAmount(amount) == nil then return false end
    Feather.RPC.Notify('feather-admin:economy:adjust', {
        playerId = target, field = field, operation = operation, value = amount
    })
    return true
end

function AdminCharacter.RequestEconomySummary(target)
    local field, operation = availableEconomyPermission()
    if target == nil or not field then
        AdminUI.NotifyActionDenied()
        return false
    end

    Feather.RPC.Notify('feather-admin:economy:summary', {
        playerId = target,
        field = field,
        operation = operation
    })
    return true
end

function AdminCharacter.RestoreAppearance(target)
    if target == nil then return false end
    Feather.RPC.Notify('feather-admin:character:restore', { playerId = target })
    return true
end

RegisterNetEvent('feather-admin:economy:result', function(field, operation, amount, balance)
    if type(AdminCharacter.economySummary) == 'table' then
        AdminCharacter.economySummary[field] = balance
    end
    Feather.Notify.RightNotify(
        ('%s %s %s. %s: %s'):format(
            AdminTranslate(operation == 'add' and 'economy_added' or 'economy_removed'),
            tostring(amount),
            AdminTranslate(('economy_%s'):format(field)),
            AdminTranslate('new_balance'),
            tostring(balance)
        ),
        3000
    )
    if AdminUI.currentPage == 'character_administration' or AdminUI.currentPage == 'economy_confirmation' then
        AdminUI.OpenCharacterAdministration()
    end
end)

RegisterNetEvent('feather-admin:economy:summary', function(summary)
    if type(summary) ~= 'table' then return end
    AdminCharacter.economySummary = summary
    AdminUI.OpenCharacterAdministration()
end)

RegisterNetEvent('feather-admin:economy:adjusted', function(field, operation, amount, balance)
    Feather.Notify.RightNotify(
        ('%s %s %s. %s: %s'):format(
            AdminTranslate(operation == 'add' and 'economy_added' or 'economy_removed'),
            tostring(amount),
            AdminTranslate(('economy_%s'):format(field)),
            AdminTranslate('new_balance'),
            tostring(balance)
        ),
        3000
    )
end)

RegisterNetEvent('feather-admin:character:restore', function()
    ExecuteCommand('rc')
end)
