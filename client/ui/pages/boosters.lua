local actions = {
    { key = 'toggle_god_mode', action = 'invincibility', toggle = true },
    { key = 'toggle_invisibility', action = 'invisibility', toggle = true },
    { key = 'toggle_infinite_stamina', action = 'infinite_stamina', toggle = true },
    { key = 'heal', action = 'heal' },
    { key = 'revive', action = 'revive' },
    { key = 'kill', action = 'kill' },
    { key = 'disable_fog_of_war', action = 'disable_fow' }
}

local statusEffects = {
    { key = 'toggle_freeze', action = 'freeze' },
    { key = 'toggle_handcuffs', action = 'handcuff' }
}

function AdminUI.CanUsePlayerStatus(includeLocalActions)
    for _, action in ipairs(actions) do
        if AdminUI.CanUseOnTarget(('booster.%s'):format(action.action)) then return true end
    end
    for _, action in ipairs(statusEffects) do
        if AdminUI.CanUseOnTarget(('troll.%s'):format(action.action)) then return true end
    end
    return includeLocalActions == true and AdminUI.CanUse('booster.noclip')
end

function AdminUI.OpenBoosters(includeLocalActions)
    if not AdminUI.CanUsePlayerStatus(includeLocalActions) then return end
    local pageKey = includeLocalActions and 'boosters_self' or 'boosters_player'
    local page = AdminUI.RegisterPage(pageKey)
    AdminUI.AddHeader(page, AdminTranslate('admin_header'),
        AdminTranslate(includeLocalActions and 'self_status_header' or 'player_status_header'))

    for _, entry in ipairs(actions) do
        local action = entry
        if AdminUI.CanUseOnTarget(('booster.%s'):format(action.action)) then
            local label = AdminTranslate(action.key)
            local buttonLabel = action.toggle and AdminUI.GetToggleLabel(label, action.action) or label
            AdminUI.AddButton(page, buttonLabel, function(_, element)
                if action.toggle then
                    AdminUI.RunServerToggleAction(label, action.action, element, function(requestId)
                        AdminBoosters.Request(action.action, AdminUI.GetTarget(), requestId)
                    end)
                else
                    if action.action == 'revive' then
                        AdminBoosters.Request(action.action, AdminUI.GetTarget())
                    else
                        AdminUI.RunAction(label, function()
                            AdminBoosters.Request(action.action, AdminUI.GetTarget())
                        end)
                    end
                end
            end, AdminUI.Styles.button)
        end
    end

    for _, entry in ipairs(statusEffects) do
        local action = entry
        if AdminUI.CanUseOnTarget(('troll.%s'):format(action.action)) then
            local label = AdminTranslate(action.key)
            AdminUI.AddButton(page, AdminUI.GetToggleLabel(label, action.action), function(_, element)
                AdminUI.RunServerToggleAction(label, action.action, element, function(requestId)
                    AdminTrolls.Request(action.action, AdminUI.GetTarget(), requestId)
                end)
            end)
        end
    end

    if includeLocalActions and AdminUI.CanUse('booster.noclip') then
        local label = AdminTranslate('toggle_noclip')
        AdminUI.AddButton(page, AdminUI.GetToggleLabel(label, 'noclip'), function(_, element)
            AdminUI.RunToggleAction(label, 'noclip', element, function(enabled)
                AdminBoosters.ToggleNoClip(enabled)
                if enabled then
                    CreateThread(function()
                        Wait(0)
                        AdminUI.Close()
                    end)
                end
            end)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        if includeLocalActions then AdminUI.OpenSelfTools() else AdminUI.OpenSelectedPlayerTools() end
    end)
    AdminUI.OpenPage(pageKey)
end
