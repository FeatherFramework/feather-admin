local actions = {
    { key = 'toggle_god_mode', action = 'invincibility', toggle = true },
    { key = 'toggle_invisibility', action = 'invisibility', toggle = true },
    { key = 'toggle_infinite_stamina', action = 'infinite_stamina', toggle = true },
    { key = 'heal', action = 'heal' },
    { key = 'revive', action = 'revive' },
    { key = 'kill', action = 'kill', danger = true },
    { key = 'disable_fog_of_war', action = 'disable_fow' }
}

function AdminUI.OpenBoosters(includeLocalActions)
    if not AdminUI.CanUseAny('booster.') and not AdminUI.CanUse('ped.change') then return end
    local pageKey = includeLocalActions and 'boosters_self' or 'boosters_player'
    local page = AdminUI.RegisterPage(pageKey)
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('boosters_header'))

    for _, entry in ipairs(actions) do
        local action = entry
        if AdminUI.CanUse(('booster.%s'):format(action.action)) then
            local label = AdminTranslate(action.key)
            local buttonLabel = action.toggle and AdminUI.GetToggleLabel(label, action.action) or label
            AdminUI.AddButton(page, buttonLabel, function(_, element)
                local request = function() AdminBoosters.Request(action.action, AdminUI.GetTarget()) end
                if action.toggle then
                    AdminUI.RunToggleAction(label, action.action, element, request)
                else
                    AdminUI.RunAction(label, request)
                end
            end, action.danger and AdminUI.Styles.danger or nil)
        end
    end

    if AdminUI.CanUse('ped.change') then
        AdminUI.AddButton(page, AdminTranslate('change_ped'), function()
            AdminUI.OpenPedCategories()
        end)
    end

    if includeLocalActions and AdminUI.CanUse('booster.noclip') then
        local label = AdminTranslate('toggle_noclip')
        AdminUI.AddButton(page, AdminUI.GetToggleLabel(label, 'noclip'), function(_, element)
            AdminUI.RunToggleAction(label, 'noclip', element, AdminBoosters.ToggleNoClip)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        if includeLocalActions then AdminUI.OpenMain() else AdminUI.OpenSelectedPlayer() end
    end)
    AdminUI.OpenPage(pageKey)
end
