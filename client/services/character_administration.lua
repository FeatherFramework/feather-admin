AdminCharacter = {
    economySummary = nil
}

local economyFields = { 'dollars', 'gold', 'tokens', 'xp' }
local issueSequence=0
local issueSession=('%08x-%08x'):format(GetGameTimer(),math.random(0,0x7fffffff))
local pendingIssue

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
    local summary=AdminCharacter.economySummary
    if field~='dollars' or operation~='add' or type(summary)~='table'
        or tonumber(summary.playerId)~=tonumber(target) or type(summary.characterId)~='string' then return false end
    local value=tostring(amount)
    if pendingIssue and (pendingIssue.characterId~=summary.characterId or pendingIssue.value~=value) then
        Feather.Notify.RightNotify(AdminTranslate('wallet_pending_request'),4000); return false
    end
    if not pendingIssue then
        issueSequence=issueSequence+1
        pendingIssue={playerId=target,characterId=summary.characterId,field=field,operation=operation,value=value,
            requestId=('%s-%d'):format(issueSession,issueSequence)}
    end
    Feather.RPC.Notify('feather-admin:economy:adjust',pendingIssue)
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

RegisterNetEvent('feather-admin:wallet:error',function(code)
    if pendingIssue then
        if code=='invalid_input' and not pendingIssue.uncertain then pendingIssue=nil
        else pendingIssue.uncertain=true end
    end
    Feather.Notify.RightNotify(AdminTranslate('wallet_issue_unconfirmed'),4000)
end)

RegisterNetEvent('feather-admin:wallet:issued',function(result)
    if type(result)~='table' then return end
    if pendingIssue and result.requestId==pendingIssue.requestId then pendingIssue=nil end
    local summary=AdminCharacter.economySummary
    if type(summary)=='table' and summary.characterId==result.characterId then
        AdminCharacter.economySummary=nil
        AdminCharacter.RequestEconomySummary(summary.playerId)
    end
    Feather.Notify.RightNotify(AdminTranslate('wallet_issue_confirmed'),3000)
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
