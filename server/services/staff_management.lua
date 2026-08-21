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

local function adminIdentity(src)
    local character = FeatherAdmin.Core.Character.GetCharacter({ src = src })
    local char = character and character.char or {}
    local characterName
    if char.first_name then
        characterName = ('%s %s'):format(char.first_name, char.last_name or ''):gsub('%s+$', '')
    end
    return {
        license = FeatherAdmin.Core.User.GetLicense(src),
        name = GetPlayerName(src) or ('Source %s'):format(src),
        characterId = tonumber(char.id),
        characterName = characterName
    }
end

local function validPage(value)
    return math.min(100000, math.max(1, math.floor(tonumber(value) or 1)))
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
    local query, page, roleId = trim(params.query), validPage(params.page), tonumber(params.roleId)
    local minimum = math.max(1, tonumber(Config.staff.minSearchLength) or 2)
    if #query < minimum or #query > 100 then
        return TriggerClientEvent('feather-admin:staff:search:result', src, {}, page, false,
            'invalid_staff_search')
    end
    if roleId and (roleId < 1 or roleId % 1 ~= 0
        or not MySQL.scalar.await('SELECT 1 FROM roles WHERE id = ? LIMIT 1', { roleId })) then
        return TriggerClientEvent('feather-admin:staff:search:result', src, {}, page, false,
            'invalid_staff_role_filter')
    end

    local pageSize = math.max(1, math.min(tonumber(Config.staff.searchLimit) or 20, 100))
    local clauses, values = {}, {}
    if query:sub(1, 8):lower() == 'license:' then
        if not FeatherAdmin.RequirePermission(src, 'staff.search_identifiers') then return end
        clauses[1], values[1] = 'u.license = ?', query
    elseif query:match('^%d+$') then
        clauses[1], values[1] = 'c.id = ?', tonumber(query)
    else
        local first, last = query:match('^(%S+)%s+(.+)$')
        if first and last then
            clauses[1] = '(u.username LIKE ? OR (c.first_name LIKE ? AND c.last_name LIKE ?))'
            values = { query .. '%', first .. '%', last .. '%' }
        else
            clauses[1] = '(u.username LIKE ? OR c.first_name LIKE ? OR c.last_name LIKE ?)'
            local prefix = query .. '%'
            values = { prefix, prefix, prefix }
        end
    end
    if roleId then
        clauses[#clauses + 1] = 'r.id = ?'
        values[#values + 1] = roleId
    end
    local rows = MySQL.query.await(([=[
        SELECT u.license, u.username AS playerName, c.id AS characterId,
               CONCAT(c.first_name, ' ', c.last_name) AS characterName,
               r.id AS roleId, r.name AS roleName, r.level AS roleLevel
        FROM users u INNER JOIN characters c ON c.user_id = u.id
        INNER JOIN roles r ON r.id = c.role_id WHERE %s
        ORDER BY u.username, c.id LIMIT %d OFFSET %d
    ]=]):format(table.concat(clauses, ' AND '), pageSize + 1, (page - 1) * pageSize), values) or {}

    local hasNext = #rows > pageSize
    if hasNext then rows[#rows] = nil end
    local results, hierarchy = {}, {}
    for _, row in ipairs(rows) do
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
    TriggerClientEvent('feather-admin:staff:search:result', src, results, page, hasNext)
    local auditQuery = query:sub(1, 8):lower() == 'license:' and 'type=license' or query
    AdminAudit.Record(src, 'staff.search', nil,
        ('query=%s role_id=%s page=%s'):format(auditQuery, tostring(roleId or 'all'), page))
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 384 })

FeatherAdmin.RegisterRPC('feather-admin:staff:history', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.history') then return end
    local characterId, page = tonumber(params.characterId), validPage(params.page)
    if not characterId or characterId < 1 or characterId % 1 ~= 0 then
        return TriggerClientEvent('feather-admin:staff:history:result', src, {}, page, false,
            'staff_history_failed')
    end
    local target = MySQL.single.await([[
        SELECT u.license, u.username AS playerName, c.id AS characterId,
               CONCAT(c.first_name, ' ', c.last_name) AS characterName
        FROM characters c INNER JOIN users u ON u.id = c.user_id WHERE c.id = ? LIMIT 1
    ]], { characterId })
    if not target then
        return TriggerClientEvent('feather-admin:staff:history:result', src, {}, page, false,
            'staff_history_failed')
    end
    if not FeatherAdmin.CheckTargetHierarchy(src, 'staff.history', target.license,
        onlineSourceForCharacter(characterId)) then return end
    local pageSize = math.max(1, math.min(tonumber(Config.staff.historyLimit) or 20, 100))
    local rows = MySQL.query.await(([=[
        SELECT old_role_name AS oldRoleName, old_role_level AS oldRoleLevel,
               new_role_name AS newRoleName, new_role_level AS newRoleLevel,
               reason, admin_name AS adminName, admin_character_name AS adminCharacterName,
               DATE_FORMAT(created_at, '%%m-%%d-%%Y %%H:%%i:%%s') AS createdAt
        FROM feather_admin_role_changes WHERE target_character_id = ?
        ORDER BY id DESC LIMIT %d OFFSET %d
    ]=]):format(pageSize + 1, (page - 1) * pageSize), { characterId }) or {}
    local hasNext = #rows > pageSize
    if hasNext then rows[#rows] = nil end
    TriggerClientEvent('feather-admin:staff:history:result', src, rows, page, hasNext)
end, { windowMs = 2000, maxCalls = 2, maxPayloadBytes = 96 })

FeatherAdmin.RegisterRPC('feather-admin:staff:role:assign', function(params, _, src)
    if not FeatherAdmin.RequirePermission(src, 'staff.role.assign') then return end
    local characterId, roleId = tonumber(params.characterId), tonumber(params.roleId)
    local reason = trim(params.reason):gsub('[%c]', ' ')
    local maxReason = math.max(1, math.min(tonumber(Config.staff.maxReasonLength) or 200, 200))
    if not characterId or characterId < 1 or characterId % 1 ~= 0
        or not roleId or roleId < 1 or roleId % 1 ~= 0 then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_update_failed')
    end
    if reason == '' or #reason > maxReason then
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'invalid_staff_role_reason')
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
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_stale')
    end
    if not changed then
        AdminAudit.RecordTarget(src, 'staff.role.assign.blocked', targetIdentity(target),
            'reason=database_update_failed')
        return TriggerClientEvent('feather-admin:staff:role:result', src, false, 'staff_role_update_failed')
    end

    local admin = adminIdentity(src)
    local historyId = MySQL.insert.await([[
        INSERT INTO feather_admin_role_changes
            (target_license, target_name, target_character_id, target_character_name,
             old_role_id, old_role_name, old_role_level, new_role_id, new_role_name, new_role_level,
             reason, admin_license, admin_name, admin_character_id, admin_character_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        target.license, target.playerName, characterId, target.characterName,
        target.roleId, target.roleName, target.roleLevel, role.id, role.name, role.level,
        reason, admin.license, admin.name, admin.characterId, admin.characterName
    })
    if not historyId then
        print(('[feather-admin] Role change for character %s succeeded but its history row failed.')
            :format(characterId))
    end
    local direction = tonumber(role.level) > tonumber(target.roleLevel) and 'promoted'
        or tonumber(role.level) < tonumber(target.roleLevel) and 'demoted' or 'changed'

    if onlineSource then
        local character = FeatherAdmin.Core.Character.GetCharacter({ src = onlineSource })
        if character and character.char then
            character:UpdateAttribute('role_id', tonumber(role.id))
            character:UpdateAttribute('role_name', tostring(role.name))
            character:UpdateAttribute('role_level', tonumber(role.level))
            local authorized = FeatherAdmin.IsAuthorized(onlineSource)
            TriggerClientEvent('feather-admin:access:permissions', onlineSource,
                authorized, authorized and FeatherAdmin.GetPermissions(onlineSource) or {})
            TriggerClientEvent('feather-admin:staff:role:updated', onlineSource,
                'your_staff_role_' .. direction)
        end
    end

    AdminAudit.RecordTarget(src, 'staff.role.assign', targetIdentity(target),
        ('character_id=%s old_role=%s(%s) new_role=%s(%s) reason=%s')
            :format(characterId, target.roleName, target.roleLevel, role.name, role.level, reason))
    TriggerClientEvent('feather-admin:staff:role:result', src, true, 'staff_role_' .. direction)
end, { windowMs = 3000, maxCalls = 1, maxPayloadBytes = 384 })
