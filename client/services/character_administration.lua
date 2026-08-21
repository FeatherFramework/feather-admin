AdminCharacter = {}

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

function AdminCharacter.RestoreAppearance(target)
    if target == nil then return false end

    Feather.RPC.Notify('feather-admin:character:restore', { playerId = target })
    return true
end

RegisterNetEvent('feather-admin:economy:result', function(field, operation, amount, balance)
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
