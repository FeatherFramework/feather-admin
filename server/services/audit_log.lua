AdminAudit = {}
local publishing = false

local function safe(value, maximum)
    if value == nil then return nil end
    local text = tostring(value):gsub('[%c]', ' ')
    local lower = text:lower()
    if lower:find('-----begin private key-----', 1, true)
        or lower:find('discord%.com/api/webhooks/') or lower:find('discordapp%.com/api/webhooks/') then
        return '[sensitive content removed]'
    end
    text = text:gsub('[Ll][Ii][Cc][Ee][Nn][Ss][Ee]2?:[^%s]+', '[identifier removed]')
        :gsub('https?://[^%s]+', '[URL removed]')
        :gsub('[Bb][Ee][Aa][Rr][Ee][Rr]%s+[^%s]+', '[credential removed]')
        :gsub('%-%-%-%-%-BEGIN PRIVATE KEY%-%-%-%-%-', '[key removed]')
    return text:sub(1, maximum)
end

local function identity(source)
    if tonumber(source) == 0 then return { name = 'Server Console', systemId = 'server-console' } end
    local resolved = source and FeatherAdmin.Identity.Resolve(source) or nil
    return { accountId = resolved and resolved.accountId, characterId = resolved and resolved.characterId,
        characterName = resolved and resolved.characterName, name = source and GetPlayerName(source) or 'Unknown player',
        systemId = 'unresolved-player' }
end

function AdminAudit.BuildEvent(eventId, actor, action, target, details)
    actor, target = actor or {}, target or {}
    local result = action:match('%.blocked$') and 'denied'
        or (action:match('%.failed$') or action:match('%.rejected$')) and 'failed' or 'success'
    local targets = {}
    if target.accountId then targets[#targets + 1] = { type = 'account', id = target.accountId, role = 'subject' } end
    if target.characterId then targets[#targets + 1] = { type = 'character', id = target.characterId, role = 'subject' } end
    if #targets == 0 then targets[1] = { type = 'resource', id = 'feather-admin', role = 'subject' } end
    local who = actor.characterId and { type = 'character', id = actor.characterId,
        characterId = actor.characterId, accountId = actor.accountId }
        or actor.accountId and { type = 'account', id = actor.accountId, accountId = actor.accountId }
        or { type = 'system', id = actor.systemId or 'server-console', resource = 'feather-admin' }
    return { contractVersion = 1, eventId = 'admin:' .. eventId,
        eventType = 'admin.action.recorded', eventVersion = 1,
        occurredAt = os.date('!%Y-%m-%dT%H:%M:%SZ'), sourceResource = 'feather-admin',
        sourceInstance = Config.audit.sourceInstance, actor = who, targets = targets, references = {},
        correlationId = target.accountId and ('admin-account:' .. target.accountId) or ('admin:' .. eventId),
        result = result, reasonCode = 'admin_action_' .. (result == 'success' and 'recorded' or result),
        summary = 'Feather Admin action', sensitivityClass = 'internal', retentionClass = 'administrative',
        context = { action = safe(action, 100), details = safe(details or 'none', 500),
            actor_name = safe(actor.characterName or actor.name, 128), target_name = safe(target.characterName or target.name, 128),
            actor_character_id = actor.characterId, target_character_id = target.characterId } }
end

function AdminAudit.RecordTarget(source, action, target, details)
    local actor = identity(source)
    local subject = type(target) == 'table' and { accountId = target.accountId, characterId = target.characterId,
        characterName = target.characterName, name = target.name or target.playerName } or nil
    local occurredAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    local called, eventId = pcall(function()
        local deadline = GetGameTimer() + 10000
        while not AdminDatabase.ready and GetGameTimer() < deadline do Wait(100) end
        if not AdminDatabase.ready then error('Admin database not ready') end
        local id = DB.value('SELECT UUID()')
        local event = AdminAudit.BuildEvent(id, actor, tostring(action), subject, details)
        event.occurredAt = occurredAt
        DB.insert([[INSERT INTO feather_admin_audit_outbox (event_id, payload, state, next_attempt)
            VALUES (?, ?, 'pending', 0)]], event.eventId, json.encode(event))
        print(('[feather-admin] audit queued eventId=%s action=%s'):format(event.eventId, event.context.action))
        return event.eventId
    end)
    if not called then
        print('[feather-admin] AUDIT QUEUE FAILED action=' .. tostring(action) .. '; inspect database readiness. No durable record confirmed.')
        return nil
    end
    return eventId
end

function AdminAudit.Record(source, action, targetSource, details)
    return AdminAudit.RecordTarget(source, action, targetSource and identity(targetSource) or nil, details)
end

function AdminAudit.PublishOnce()
    if publishing or not AdminDatabase.ready or GetResourceState('feather-audit') ~= 'started' then return end
    publishing = true
    local called, problem = pcall(function()
        local owner, now = DB.value('SELECT UUID()'), os.time()
        local rows
        local committed = DB.transaction(function(tx)
            rows = tx.query([[SELECT event_id AS eventId, payload, attempt_count AS attemptCount
                FROM feather_admin_audit_outbox
                WHERE (state = 'pending' AND next_attempt <= ?) OR (state = 'leased' AND lease_until <= ?)
                ORDER BY created_at, event_id LIMIT ? FOR UPDATE]], now, now, Config.audit.batchSize) or {}
            for _, row in ipairs(rows) do
                tx.exec([[UPDATE feather_admin_audit_outbox SET state='leased', lease_owner=?, lease_until=?,
                    attempt_count=attempt_count+1 WHERE event_id=?]], owner, now + 60, row.eventId)
            end
            return true
        end)
        if committed ~= true then error('outbox lease rejected') end
        for _, row in ipairs(rows) do
            local decoded, event = pcall(json.decode, row.payload)
            local transported, response = false, nil
            if decoded and type(event) == 'table' then
                transported, response = pcall(function() return exports['feather-audit']:Ingest(event) end)
            end
            if transported and type(response) == 'table' and type(response.auditEventId) == 'string'
                and #response.auditEventId == 36 and (response.result == 'accepted' or response.result == 'duplicate') then
                DB.exec([[UPDATE feather_admin_audit_outbox SET state='delivered', audit_event_id=?,
                    lease_owner=NULL, lease_until=NULL, last_code=?, delivered_at=NOW()
                    WHERE event_id=? AND state='leased' AND lease_owner=?]], response.auditEventId, response.result, row.eventId, owner)
            elseif not decoded or type(event) ~= 'table'
                or (transported and type(response) == 'table' and response.result == 'quarantined') then
                DB.exec([[UPDATE feather_admin_audit_outbox SET state='quarantined', last_code=?,
                    lease_owner=NULL, lease_until=NULL WHERE event_id=? AND state='leased' AND lease_owner=?]],
                    (not decoded or type(event) ~= 'table') and 'invalid_payload' or response.code, row.eventId, owner)
                print('[feather-admin] audit outbox quarantined eventId=' .. row.eventId)
            else
                local delay = math.min(300, 2 ^ math.min(8, tonumber(row.attemptCount) or 0))
                DB.exec([[UPDATE feather_admin_audit_outbox SET state='pending', next_attempt=?, last_code=?,
                    lease_owner=NULL, lease_until=NULL WHERE event_id=? AND state='leased' AND lease_owner=?]],
                    now + delay, transported and type(response) == 'table' and response.code or 'transport_failure', row.eventId, owner)
            end
        end
    end)
    publishing = false
    if not called then print('[feather-admin] audit publisher failed; durable leases will retry after expiry.') end
    return called
end

CreateThread(function()
    while true do
        Wait(Config.audit.pollMilliseconds)
        AdminAudit.PublishOnce()
    end
end)

RegisterCommand('AdminAuditOutboxStatus', function(source)
    if source ~= 0 or not AdminDatabase.ready then return end
    for _, row in ipairs(DB.query('SELECT state, COUNT(*) AS total FROM feather_admin_audit_outbox GROUP BY state') or {}) do
        print(('[AdminAuditOutboxStatus] state=%s count=%s'):format(row.state, row.total))
    end
end, true)

RegisterCommand('AdminAuditProducerSmokeTest', function(source)
    if source ~= 0 then return end
    local id = AdminAudit.RecordTarget(0, 'audit.producer.smoke', nil, 'Safe Admin producer acceptance fixture')
    print('[AdminAuditProducerSmokeTest] ' .. (id and 'PASS queued eventId=' .. id or 'FAIL enqueue'))
end, true)

RegisterCommand('AdminAuditPublish', function(source)
    if source == 0 then AdminAudit.PublishOnce() end
end, true)

RegisterCommand('AdminAuditProducerVerifySmokeTest', function(source, args)
    if source ~= 0 or not AdminDatabase.ready then return end
    local row = DB.one([[SELECT event_id AS eventId, payload, state, audit_event_id AS auditEventId
        FROM feather_admin_audit_outbox WHERE event_id=?
          AND JSON_UNQUOTE(JSON_EXTRACT(payload, '$.context.action'))='audit.producer.smoke']], args[1])
    if not row or row.state ~= 'delivered' then return print('[AdminAuditProducerVerifySmokeTest] FAIL fixture not delivered') end
    local event = json.decode(row.payload)
    local called, replay = pcall(function() return exports['feather-audit']:Ingest(event) end)
    local count = tonumber(DB.value([[SELECT COUNT(*) FROM feather_audit_events
        WHERE source_resource='feather-admin' AND source_instance=? AND producer_event_id=?]],
        event.sourceInstance, event.eventId))
    local passed = called and type(replay) == 'table' and replay.result == 'duplicate' and replay.auditEventId == row.auditEventId and count == 1
    print(('[AdminAuditProducerVerifySmokeTest] %s eventId=%s state=%s sameAuditId=%s rows=%s'):format(
        passed and 'PASS' or 'FAIL', row.eventId, row.state,
        tostring(called and type(replay) == 'table' and replay.auditEventId == row.auditEventId), tostring(count)))
end, true)
