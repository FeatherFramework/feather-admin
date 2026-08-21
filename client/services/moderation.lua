AdminModeration = {
    target = nil,
    results = {},
    form = {},
    searchOrigin = 'players'
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
    serverId = tonumber(serverId)
    local target = { serverId = serverId, isOnline = true }
    for _, player in ipairs(ClientAllPlayers) do
        if tonumber(player.serverId) == serverId then
            for key, value in pairs(player) do target[key] = value end
            break
        end
    end
    AdminModeration.target = target
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
    Feather.RPC.Notify('feather-admin:moderation:ban', {
        target = AdminModeration.target, reason = reason, durationMinutes = parsedDuration
    })
    return true
end

function AdminModeration.Warn(reason)
    if not validReason(reason) then return false end
    Feather.RPC.Notify('feather-admin:moderation:warn', { target = AdminModeration.target, reason = reason })
    return true
end

function AdminModeration.Kick(reason)
    local target = AdminModeration.target
    if not target or not target.serverId or not validReason(reason) then return false end
    Feather.RPC.Notify('feather-admin:moderation:kick', { playerId = target.serverId, reason = reason })
    return true
end

function AdminModeration.RequestHistory()
    Feather.RPC.Notify('feather-admin:moderation:history', { target = AdminModeration.target })
end

function AdminModeration.Search(query)
    if type(query) ~= 'string' or query:match('^%s*$') then return false end
    Feather.RPC.Notify('feather-admin:moderation:search', { query = query })
    return true
end

function AdminModeration.SearchPlayers(query)
    if type(query) ~= 'string' or query:match('^%s*$') then return false end
    AdminPlayerDirectory.query = query:match('^%s*(.-)%s*$')
    local minimum = math.max(1, tonumber(Config.moderation.minSearchLength) or 2)
    if #AdminPlayerDirectory.query < minimum or #AdminPlayerDirectory.query > 100 then return false end
    AdminModeration.searchOrigin = 'players'
    Feather.RPC.Notify('feather-admin:moderation:search', {
        query = AdminPlayerDirectory.query,
        roleId = AdminPlayerDirectory.roleFilterId
    })
    return true
end

function AdminModeration.Unban(banId, origin)
    AdminModeration.unbanOrigin = origin or 'history'
    Feather.RPC.Notify('feather-admin:moderation:unban', { banId = banId })
end

RegisterNetEvent('feather-admin:moderation:search:result', function(results)
    AdminModeration.results = type(results) == 'table' and results or {}
    if AdminModeration.searchOrigin == 'players' then
        AdminPlayerDirectory.results = AdminModeration.results
        AdminUI.OpenPlayerSearchResults()
    else
        AdminUI.OpenModerationSearchResults()
    end
end)

RegisterNetEvent('feather-admin:moderation:history:result', function(history)
    AdminUI.OpenModerationHistory(type(history) == 'table' and history or {})
end)

RegisterNetEvent('feather-admin:moderation:result', function(messageKey)
    Feather.Notify.RightNotify(AdminTranslate(messageKey), 3000)
    if messageKey ~= 'ban_revoked' then return end

    local origin = AdminModeration.unbanOrigin
    AdminModeration.unbanOrigin = nil
    if origin == 'active_bans' then
        AdminActiveBans.selected = nil
        AdminActiveBans.Request(AdminActiveBans.page)
    else
        AdminModeration.RequestHistory()
    end
end)
