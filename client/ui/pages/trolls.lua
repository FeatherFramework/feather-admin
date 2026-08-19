local actions = {
    { key = 'lightning_strike',        action = 'lightning_strike' },
    { key = 'teleport_to_sky',         action = 'teleport_to_heaven' },
    { key = 'toggle_cage',             action = 'cage',                   toggle = true },
    { key = 'toggle_cinematic_camera', action = 'force_cinematic_camera', toggle = true },
    { key = 'spawn_hostile_group',     action = 'hostile_ped_army' },
    { key = 'remove_from_vehicle',     action = 'kick_from_vehicle' },
    { key = 'spawn_hostile_bear',      action = 'hostile_bear' },
    { key = 'toggle_lag',              action = 'lag',                    toggle = true }
}

function AdminUI.CanUseSpecialEffects()
    for _, action in ipairs(actions) do
        if AdminUI.CanUseOnTarget(('troll.%s'):format(action.action)) then return true end
    end
    return false
end

function AdminUI.OpenTrolls()
    if not AdminUI.CanUseSpecialEffects() then return end
    local page = AdminUI.RegisterPage('trolls')

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('special_effects_header'))

    for _, entry in ipairs(actions) do
        local action = entry
        if AdminUI.CanUseOnTarget(('troll.%s'):format(action.action)) then
            local label = AdminTranslate(action.key)
            local buttonLabel = action.toggle and AdminUI.GetToggleLabel(label, action.action) or label
            AdminUI.AddButton(page, buttonLabel, function(_, element)
                local request = function() AdminTrolls.Request(action.action, AdminUI.GetTarget()) end
                if action.toggle then
                    AdminUI.RunServerToggleAction(label, action.action, element, function(requestId)
                        AdminTrolls.Request(action.action, AdminUI.GetTarget(), requestId)
                    end)
                else
                    AdminUI.RunAction(label, request)
                end
            end)
        end
    end

    AdminUI.AddFooter(page)

    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenSelectedPlayer)

    AdminUI.OpenPage('trolls')
end
