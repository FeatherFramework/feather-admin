AdminWebhook = {}

local queue = {}
local processing = false
local maximumQueued = 500

local function RetryDelay(status, body, headers)
    if status ~= 429 then return 2000 end
    local ok, decoded = pcall(json.decode, body or '')
    if ok and type(decoded) == 'table' and tonumber(decoded.retry_after) then
        return math.max(1000, math.floor(tonumber(decoded.retry_after) * 1000))
    end
    local header = headers and (headers['retry-after'] or headers['Retry-After'])
    return math.max(1000, math.floor((tonumber(header) or 1) * 1000))
end

local function ProcessQueue()
    if processing or #queue == 0 then return end
    processing = true
    local item = queue[1]
    PerformHttpRequest(item.url, function(status, body, headers)
        status = tonumber(status) or 0
        if status >= 200 and status < 300 then
            table.remove(queue, 1)
            processing = false
            return ProcessQueue()
        end

        item.attempts = item.attempts + 1
        if item.attempts >= 5 or (status ~= 429 and status < 500) then
            print(('[feather-admin] Webhook delivery failed: status=%s attempts=%s'):format(
                tostring(status), tostring(item.attempts)))
            table.remove(queue, 1)
            processing = false
            return ProcessQueue()
        end

        local delay = RetryDelay(status, body, headers)
        processing = false
        SetTimeout(delay, ProcessQueue)
    end, 'POST', item.payload, { ['Content-Type'] = 'application/json' })
end

function AdminWebhook.Create(url, name, avatar)
    if type(url) ~= 'string' or url == '' then return nil end
    local sink = {}

    function sink:Send(title, description)
        if #queue >= maximumQueued then
            print('[feather-admin] Webhook queue is full; audit notification dropped.')
            return false
        end
        queue[#queue + 1] = {
            url = url,
            attempts = 0,
            payload = json.encode({
                username = tostring(name or 'Feather Admin'),
                avatar_url = tostring(avatar or ''),
                embeds = {{ color = 11342935, title = tostring(title), description = tostring(description) }}
            })
        }
        ProcessQueue()
        return true
    end

    return sink
end
