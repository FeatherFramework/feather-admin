local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

local function onlineSourceForCharacter(characterId)
    characterId = tonumber(characterId)
    for _, rawId in ipairs(GetPlayers()) do
        local playerId = tonumber(rawId)
        local character = playerId and FeatherAdmin.Core.Character.GetCharacter({ src = playerId })
        if character and character.char and tonumber(character.char.id) == characterId then return playerId end
    end
    return nil
end

local function targetIdentity(row)
    return {
        label = ('%s, character=%s (%s)'):format(tostring(row.playerName or 'unknown'),
            tostring(row.characterName or 'none'), tostring(row.characterId or 'none')),
        license = row.license,
        name = row.playerName,
        characterId = tonumber(row.characterId),
        characterName = row.characterName
    }
end

local function activePlayers(src)
    local players = {}
    for _, rawId in ipairs(GetPlayers()) do
        local playerId = tonumber(rawId)
        local character = playerId and FeatherAdmin.Core.Character.GetCharacter({ src = playerId })
        local char = character and character.char
        local license = playerId and FeatherAdmin.Core.User.GetLicense(playerId)
        local manageable = playerId ~= src
            and FeatherAdmin.CanActOnLicense(src, license, 'staff.role.assign') == true
        if char and manageable then
            players[#players + 1] = {
                serverId = playerId,
                serverName = GetPlayerName(playerId),
                license = license,
                characterId = tonumber(char.id),
                characterName = ('%s %s'):format(char.first_name or '', char.last_name or ''):gsub('%s+$', ''),
                roleId = tonumber(char.role_id),
                roleName = char.role_name,
                roleLevel = tonumber(char.role_level) or 0,
                isOnline = true
            }
        end
    end
    return players
end

local function assignableRoles(src)
    local actorLevel = FeatherAdmin.GetRoleLevel(src)
    if actorLevel == nil then return {} end
    return MySQL.query.await([[
        SELECT id, name, level FROM roles
        WHERE level <= ? ORDER BY level ASC, name ASC
    ]], { actorLevel }) or {}
end

FeatherAdmin.RegisterRPC('feather-admin:staff:list', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.view') then return end
    if params.playerId ~= nil then
        local target = FeatherAdmin.ValidTarget(params.playerId)
        if target == nil then
            return TriggerClientEvent('feather-admin:staff:list:result', src, {}, {}, 'player_not_online')
        end
        local license = FeatherAdmin.Core.User.GetLicense(target)
        if not FeatherAdmin.CheckTargetHierarchy(src, 'staff.role.assign', license, target) then return end
    end
    TriggerClientEvent('feather-admin:staff:list:result', src, assignableRoles(src), activePlayers(src))
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 64 })

FeatherAdmin.RegisterRPC('feather-admin:staff:search', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.search') then return end
    local query = trim(params.query)
    local minimum = math.max(1, tonumber(Config.staff.minSearchLength) or 2)
    if #query < minimum or #query > 100 then
        return TriggerClientEvent('feather-admin:staff:search:result', src, {}, 'invalid_staff_search')
    end

    local limit = math.max(1, math.min(tonumber(Config.staff.searchLimit) or 25, 100))
    local rows
    if query:sub(1, 8):lower() == 'license:' then
        if not FeatherAdmin.RequirePermission(src, 'staff.search_identifiers') then return end
        rows = MySQL.query.await(([=[
            SELECT u.license, u.username AS playerName, c.id AS characterId,
                   CONCAT(c.first_name, ' ', c.last_name) AS characterName,
                   r.id AS roleId, r.name AS roleName, r.level AS roleLevel
            FROM users u INNER JOIN characters c ON c.user_id = u.id
            INNER JOIN roles r ON r.id = c.role_id
            WHERE u.license = ? ORDER BY c.id ASC LIMIT %d
        ]=]):format(limit), { query })
    elseif query:match('^%d+$') then
        rows = MySQL.query.await([[
            SELECT u.license, u.username AS playerName, c.id AS characterId,
                   CONCAT(c.first_name, ' ', c.last_name) AS characterName,
                   r.id AS roleId, r.name AS roleName, r.level AS roleLevel
            FROM characters c INNER JOIN users u ON u.id = c.user_id
            INNER JOIN roles r ON r.id = c.role_id
            WHERE c.id = ? LIMIT 1
        ]], { tonumber(query) })
    else
        local first, last = query:match('^(%S+)%s+(.+)$')
        local prefix = query .. '%'
        if first and last then
            rows = MySQL.query.await(([=[
                SELECT u.license, u.username AS playerName, c.id AS characterId,
                       CONCAT(c.first_name, ' ', c.last_name) AS characterName,
                       r.id AS roleId, r.name AS roleName, r.level AS roleLevel
                FROM users u INNER JOIN characters c ON c.user_id = u.id
                INNER JOIN roles r ON r.id = c.role_id
                WHERE u.username LIKE ? OR (c.first_name LIKE ? AND c.last_name LIKE ?)
                ORDER BY u.username, c.id LIMIT %d
            ]=]):format(limit), { prefix, first .. '%', last .. '%' })
        else
            rows = MySQL.query.await(([=[
                SELECT u.license, u.username AS playerName, c.id AS characterId,
                       CONCAT(c.first_name, ' ', c.last_name) AS characterName,
                       r.id AS roleId, r.name AS roleName, r.level AS roleLevel
                FROM users u INNER JOIN characters c ON c.user_id = u.id
                INNER JOIN roles r ON r.id = c.role_id
                WHERE u.username LIKE ? OR c.first_name LIKE ? OR c.last_name LIKE ?
                ORDER BY u.username, c.id LIMIT %d
            ]=]):format(limit), { prefix, prefix, prefix })
        end
    end

    local results, hierarchy = {}, {}
    for _, row in ipairs(rows or {}) do
        local allowed = hierarchy[row.license]
        if allowed == nil then
            allowed = FeatherAdmin.CanActOnLicense(src, row.license, 'staff.role.assign') == true
            hierarchy[row.license] = allowed
        end
        if allowed then
            row.serverId = onlineSourceForCharacter(row.characterId)
            row.isOnline = row.serverId ~= nil
            results[#results + 1] = row
        end
    end
    TriggerClientEvent('feather-admin:staff:search:result', src, results)
    local auditQuery = query:sub(1, 8):lower() == 'license:' and 'type=license' or query
    AdminAudit.Record(src, 'staff.search', nil, auditQuery)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 256 })

FeatherAdmin.RegisterRPC('feather-admin:staff:role:assign', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.role.assign') then return end
    local characterId, roleId = tonumber(params.characterId), tonumber(params.roleId)
    if not characterId or characterId < 1 or characterId % 1 ~= 0
        or not roleId or roleId < 1 or roleId % 1 ~= 0 then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_update_failed')
    end

    local target = MySQL.single.await([[
        SELECT u.license, u.username AS playerName, c.id AS characterId,
               CONCAT(c.first_name, ' ', c.last_name) AS characterName,
               r.id AS roleId, r.name AS roleName, r.level AS roleLevel
        FROM characters c INNER JOIN users u ON u.id = c.user_id
        INNER JOIN roles r ON r.id = c.role_id WHERE c.id = ? LIMIT 1
    ]], { characterId })
    local role = MySQL.single.await('SELECT id, name, level FROM roles WHERE id = ? LIMIT 1', { roleId })
    local actorLevel = FeatherAdmin.GetRoleLevel(src)
    if not target or not role or actorLevel == nil then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_update_failed')
    end

    local onlineSource = onlineSourceForCharacter(characterId)
    if not FeatherAdmin.CheckTargetHierarchy(src, 'staff.role.assign', target.license, onlineSource) then return end
    if tonumber(role.level) > actorLevel then
        AdminAudit.RecordTarget(src, 'staff.role.assign.blocked', targetIdentity(target),
            ('reason=role_too_high role_id=%s role_level=%s'):format(role.id, role.level))
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_too_high')
    end
    if tonumber(target.roleId) == tonumber(role.id) then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_unchanged')
    end

    local changed = MySQL.update.await(
        'UPDATE characters SET role_id = ? WHERE id = ? AND role_id = ?',
        { role.id, characterId, target.roleId })
    if changed == 0 then
        AdminAudit.RecordTarget(src, 'staff.role.assign.blocked', targetIdentity(target),
            'reason=role_changed_during_request')
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_changed')
    end
    if not changed then
        AdminAudit.RecordTarget(src, 'staff.role.assign.blocked', targetIdentity(target),
            'reason=database_update_failed')
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_update_failed')
    end

    if onlineSource then
        local character = FeatherAdmin.Core.Character.GetCharacter({ src = onlineSource })
        if character and character.char then
            character:UpdateAttribute('role_id', tonumber(role.id))
            character:UpdateAttribute('role_name', tostring(role.name))
            character:UpdateAttribute('role_level', tonumber(role.level))
            local authorized = FeatherAdmin.IsAuthorized(onlineSource)
            TriggerClientEvent('feather-admin:access:permissions', onlineSource,
                authorized, authorized and FeatherAdmin.GetPermissions(onlineSource) or {})
            TriggerClientEvent('feather-admin:staff:role:updated', onlineSource)
        end
    end

    AdminAudit.RecordTarget(src, 'staff.role.assign', targetIdentity(target),
        ('character_id=%s old_role_id=%s old_role_level=%s new_role_id=%s new_role_level=%s')
            :format(characterId, target.roleId, target.roleLevel, role.id, role.level))
    TriggerClientEvent('feather-admin:staff:role:result', src, true, 'staff_role_updated')
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 128 })
