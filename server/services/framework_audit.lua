local operations = { search = 'Search', detail = 'GetEvent', correlation = 'GetCorrelation' }

FeatherAdmin.RegisterRPC('feather-admin:framework-audit:read', function(params, _, source)
    local ticket = params.ticket
    if type(ticket) ~= 'number' or ticket < 1 or ticket % 1 ~= 0 or ticket > 2147483647 then return end
    local function send(result)
        TriggerClientEvent('feather-admin:framework-audit:result', source, ticket, params.mode, result)
    end
    if not FeatherAdmin.CanUse(source, 'audit.search') then
        return send({ ok = false, code = 'forbidden' })
    end
    if not operations[params.mode] or type(params.query) ~= 'table' then
        return send({ ok = false, code = 'invalid_request' })
    end
    local query = {}
    for key, value in pairs(params.query) do query[key] = value end
    if query.hours ~= nil then
        if params.mode ~= 'search' or query.cursor or query.fromEpoch or query.toEpoch
            or (query.hours ~= 1 and query.hours ~= 24 and query.hours ~= 168) then
            return send({ ok = false, code = 'invalid_request' })
        end
        local now = os.time()
        query.fromEpoch, query.toEpoch = now - query.hours * 3600, now
        query.hours = nil
    end
    local before = exports['feather-core']:GetSessionContext(source)
    if not before or not before.ok or type(before.value) ~= 'table' then return send({ ok = false, code = 'forbidden' }) end
    local sensitive = FeatherAdmin.CanUse(source, 'audit.sensitive.view')
    local called, result = pcall(function()
        local audit = exports['feather-audit']
        if params.mode == 'detail' then return audit:GetEvent(query, source) end
        if params.mode == 'correlation' then return audit:GetCorrelation(query, source) end
        return audit:Search(query, source)
    end)
    local after = exports['feather-core']:GetSessionContext(source)
    if not after or not after.ok or type(after.value) ~= 'table' or before.value.sessionId ~= after.value.sessionId
        or before.value.characterId ~= after.value.characterId
        or before.value.accountId ~= after.value.accountId
        or before.value.generation ~= after.value.generation then return end
    if not called or type(result) ~= 'table' then result = { ok = false, code = 'unavailable' } end
    if result.ok and (not FeatherAdmin.CanUse(source, 'audit.search')
        or (sensitive and not FeatherAdmin.CanUse(source, 'audit.sensitive.view'))) then
        result = { ok = false, code = 'forbidden' }
    end
    if result.ok and type(result.value) == 'table' then
        result.value.window = { fromEpoch = query.fromEpoch, toEpoch = query.toEpoch }
    end
    send(result)
end, { windowMs = 1000, maxCalls = 2, maxPayloadBytes = 1024 })
