AdminModeration = {
    target = nil,
    results = {},
    form = {}
}

local function validReason(reason)
    if type(reason) ~= 'string' then return false end
    reason = reason:match('^%s*(.-)%s*$')
    local maximum = math.min(tonumber(Config.moderation.maxReasonLength) or 200, 200)
    return reason ~= '' and #reason <= maximum
end

function AdminModeration.ValidateReason(reason)
    return validReason(reason)
end

function AdminModeration.SelectOnline(serverId)
    AdminModeration.target = { serverId = tonumber(serverId) }
    AdminModeration.form = {}
    AdminUI.OpenModerationTarget()
end

function AdminModeration.SelectOffline(target)
    AdminModeration.target = target
    AdminModeration.form = {}
    AdminUI.OpenModerationTarget()
end

function AdminModeration.ValidateBan(reason, duration)
    if not validReason(reason) then return false, 'reason' end
    duration = (duration == nil or duration == '') and 0 or tonumber(duration)
    local maximum = tonumber(Config.moderation.maxBanMinutes) or 525600
    if not duration or duration < 0 or duration > maximum or duration % 1 ~= 0 then return false, 'duration' end
    return true, nil, duration
end

function AdminModeration.Ban(reason, duration)
    local valid, problem, parsedDuration = AdminModeration.ValidateBan(reason, duration)
    if not valid then return false, problem end
    TriggerServerEvent('feather-admin:moderation:ban', AdminModeration.target, reason, parsedDuration)
    return true
end

function AdminModeration.Warn(reason)
    if not validReason(reason) then return false end
    TriggerServerEvent('feather-admin:moderation:warn', AdminModeration.target, reason)
    return true
end

function AdminModeration.Kick(reason)
    local target = AdminModeration.target
    if not target or not target.serverId or not validReason(reason) then return false end
    TriggerServerEvent('feather-admin:moderation:kick', target.serverId, reason)
    return true
end

function AdminModeration.RequestHistory()
    TriggerServerEvent('feather-admin:moderation:history', AdminModeration.target)
end

function AdminModeration.Search(query)
    if type(query) ~= 'string' or query:match('^%s*$') then return false end
    TriggerServerEvent('feather-admin:moderation:search', query)
    return true
end

function AdminModeration.Unban(banId)
    TriggerServerEvent('feather-admin:moderation:unban', banId)
end

RegisterNetEvent('feather-admin:moderation:search:result', function(results)
    AdminModeration.results = type(results) == 'table' and results or {}
    AdminUI.OpenModerationSearchResults()
end)

RegisterNetEvent('feather-admin:moderation:history:result', function(history)
    AdminUI.OpenModerationHistory(type(history) == 'table' and history or {})
end)

RegisterNetEvent('feather-admin:moderation:result', function(messageKey)
    Feather.Notify.RightNotify(AdminTranslate(messageKey), 3000)
    if messageKey == 'ban_revoked' then AdminModeration.RequestHistory() end
end)
