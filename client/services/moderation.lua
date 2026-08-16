AdminModeration = {
    target = nil,
    results = {}
}

local function validReason(reason)
    if type(reason) ~= 'string' then return false end
    reason = reason:match('^%s*(.-)%s*$')
    local maximum = math.min(tonumber(Config.moderation.maxReasonLength) or 200, 200)
    return reason ~= '' and #reason <= maximum
end

function AdminModeration.SelectOnline(serverId)
    AdminModeration.target = { serverId = tonumber(serverId) }
    AdminUI.OpenModerationTarget()
end

function AdminModeration.SelectOffline(target)
    AdminModeration.target = target
    AdminUI.OpenModerationTarget()
end

function AdminModeration.Ban(reason, duration)
    if not validReason(reason) then return false, 'reason' end
    duration = (duration == nil or duration == '') and 0 or tonumber(duration)
    local maximum = tonumber(Config.moderation.maxBanMinutes) or 525600
    if not duration or duration < 0 or duration > maximum or duration % 1 ~= 0 then return false, 'duration' end
    TriggerServerEvent('feather-admin:moderation:ban', AdminModeration.target, reason, duration)
    return true
end

function AdminModeration.Warn(reason)
    if not validReason(reason) then return false end
    TriggerServerEvent('feather-admin:moderation:warn', AdminModeration.target, reason)
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
