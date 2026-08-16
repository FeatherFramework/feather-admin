local economyFields = {
    dollars = true,
    gold = true,
    tokens = true,
    xp = true
}

local function validAmount(value)
    local amount = tonumber(value)
    local maximum = tonumber(Config.economy.maxAmount) or 1000000
    if amount == nil or amount ~= amount or amount <= 0 or amount > maximum then return nil end
    return amount
end

RegisterNetEvent('feather-admin:economy:adjust', function(playerId, field, operation, value)
    local src = source
    if economyFields[field] ~= true or (operation ~= 'add' and operation ~= 'remove') then return end

    local permission = ('economy.%s.%s'):format(field, operation)
    if not FeatherAdmin.RequirePermission(src, permission) then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    local amount = validAmount(value)
    if target == nil or amount == nil then return end

    local character = FeatherAdmin.Core.Character.GetCharacter({ src = target })
    if not character or not character.char then return end

    local callSucceeded, succeeded = pcall(function()
        if operation == 'add' then return character:Add(field, amount) end
        return character:Subtract(field, amount)
    end)

    if not callSucceeded or not succeeded then
        if not callSucceeded then
            print(('[feather-admin] Economy adjustment failed: %s'):format(tostring(succeeded)))
        end
        FeatherAdmin.Core.Notify.RightNotify(src, 'The economy adjustment could not be completed.', 3000)
        return
    end

    local balance = character.char[field]
    local details = ('field=%s operation=%s amount=%s balance=%s'):format(field, operation, amount, balance)
    AdminAudit.Record(src, permission, target, details)
    TriggerClientEvent('feather-admin:economy:result', src, field, operation, amount, balance)
    if target ~= src then
        TriggerClientEvent('feather-admin:economy:adjusted', target, field, operation, amount, balance)
    end
end)

RegisterNetEvent('feather-admin:character:restore', function(playerId)
    local src = source
    if not FeatherAdmin.RequirePermission(src, 'character.restore_model') then return end

    local target = FeatherAdmin.ValidTarget(playerId)
    if target == nil then return end
    if GetResourceState('feather-character') ~= 'started' then
        FeatherAdmin.Core.Notify.RightNotify(src, 'Feather Character is not running.', 3000)
        return
    end

    AdminAudit.Record(src, 'character.restore_model', target)
    TriggerClientEvent('feather-admin:character:restore', target)
    FeatherAdmin.Core.Notify.RightNotify(src, 'Character appearance restore requested.', 2500)
end)
