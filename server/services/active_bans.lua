local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function sendResult(src, rows, page, hasNext, errorKey)
    TriggerClientEvent('feather-admin:active-bans:result', src, rows or {}, page or 1,
        hasNext == true, errorKey)
end

FeatherAdmin.RegisterRPC('feather-admin:active-bans:list', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'moderation.bans.view') then return end

    local page = math.min(100000, math.max(1, math.floor(tonumber(params.page) or 1)))
    if not AdminDatabase.ready then
        return sendResult(src, {}, page, false, 'moderation_unavailable')
    end

    local query = trim(params.query)
    local minimum = math.max(1, tonumber(Config.moderation.minSearchLength) or 2)
    if #query > 100 or (query ~= '' and #query < minimum) then
        return sendResult(src, {}, page, false, 'invalid_active_ban_search')
    end

    local limit = math.max(1, math.min(tonumber(Config.moderation.activeBanLimit) or 20, 100))
    local offset = (page - 1) * limit
    local searchClause, values = '', {}
    if #query == 36 and query:match('^[%x%-]+$') then
        searchClause = 'AND account_id = ?'
        values[#values + 1] = query
    elseif query:sub(1, 8):lower() == 'license:' then
        if not FeatherAdmin.RequirePermission(src, 'moderation.search_identifiers') then return end
        searchClause = 'AND license = ?'
        values[#values + 1] = query
    elseif query ~= '' then
        searchClause = 'AND (player_name LIKE ? OR character_name LIKE ?)'
        local prefix = query .. '%'
        values[#values + 1] = prefix
        values[#values + 1] = prefix
    end

    local rows = MySQL.query.await(([=[
        SELECT id, account_id AS accountId, player_name AS playerName, character_id AS characterId,
               character_name AS characterName, reason,
               admin_name AS adminName, admin_character_name AS adminCharacterName,
               DATE_FORMAT(expires_at, '%%m-%%d-%%Y %%h:%%i %%p') AS expiresAt,
               DATE_FORMAT(created_at, '%%m-%%d-%%Y %%h:%%i %%p') AS createdAt
        FROM feather_admin_bans
        WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW()) %s
        ORDER BY created_at DESC, id DESC
        LIMIT %d OFFSET %d
    ]=]):format(searchClause, limit + 1, offset), values) or {}

    local hasNext = #rows > limit
    if hasNext then table.remove(rows) end
    sendResult(src, rows, page, hasNext)
end, { windowMs = 2000, maxCalls = 3, maxPayloadBytes = 256 })
