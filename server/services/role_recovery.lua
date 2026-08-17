local function reply(src, message)
    print(('[feather-admin] %s'):format(message))
    if src > 0 then FeatherAdmin.Core.Notify.RightNotify(src, message, 5000) end
end

RegisterCommand(Config.commands.recoverRole, function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, Config.commands.recoverAce) then
        reply(src, 'You do not have permission to use role recovery.')
        return
    end

    local characterId = tonumber(args[1])
    local roleLevel = tonumber(args[2])
    if not characterId or characterId % 1 ~= 0 or characterId < 1
        or not roleLevel or roleLevel % 1 ~= 0 then
        reply(src, ('Usage: /%s <characterId> <roleLevel>'):format(Config.commands.recoverRole))
        return
    end

    local roles = MySQL.query.await('SELECT id, name, level FROM roles WHERE level = ?', { roleLevel }) or {}
    if #roles ~= 1 then
        reply(src, #roles == 0 and 'No role exists at that numeric level.'
            or 'More than one role uses that level; make role levels unique before recovery.')
        return
    end

    local role = roles[1]
    local existing = MySQL.single.await('SELECT id FROM characters WHERE id = ?', { characterId })
    if not existing then
        reply(src, 'Character not found.')
        return
    end

    local changed = MySQL.update.await('UPDATE characters SET role_id = ? WHERE id = ?', { role.id, characterId })
    if changed == nil then
        reply(src, 'The character role could not be updated.')
        return
    end

    local activeSource
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local character = target and FeatherAdmin.Core.Character.GetCharacter({ src = target })
        if character and character.char and tonumber(character.char.id) == characterId then
            character:UpdateAttribute('role_id', tonumber(role.id))
            character:UpdateAttribute('role_name', role.name)
            character:UpdateAttribute('role_level', tonumber(role.level))
            activeSource = target
            break
        end
    end

    if activeSource then
        local authorized = FeatherAdmin.IsAuthorized(activeSource)
        TriggerClientEvent('feather-admin:access:permissions', activeSource,
            authorized, authorized and FeatherAdmin.GetPermissions(activeSource) or {})
    end

    AdminAudit.Record(src > 0 and src or nil, 'role.recover', activeSource,
        ('character_id=%s role_id=%s role_level=%s'):format(characterId, role.id, role.level))
    reply(src, ('Character %s now has role %s (level %s).'):format(characterId, role.name, role.level))
end, false)
