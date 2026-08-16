local actions = {
    { key = 'lightning_strike',        action = 'lightning_strike' },
    { key = 'toggle_freeze',           action = 'freeze',                 toggle = true },
    { key = 'teleport_to_sky',         action = 'teleport_to_heaven' },
    { key = 'toggle_cage',             action = 'cage',                   toggle = true },
    { key = 'toggle_cinematic_camera', action = 'force_cinematic_camera', toggle = true },
    { key = 'toggle_giant_ped',        action = 'make_ped_giant',         toggle = true },
    { key = 'spawn_hostile_group',     action = 'hostile_ped_army' },
    { key = 'toggle_handcuffs',        action = 'handcuff',               toggle = true },
    { key = 'remove_from_vehicle',     action = 'kick_from_vehicle' },
    { key = 'spawn_hostile_bear',      action = 'hostile_bear' },
    { key = 'toggle_lag',              action = 'lag',                    toggle = true }
}

function AdminUI.OpenTrolls()
    if not AdminUI.CanUseAny('troll.') then return end
    local page = AdminUI.RegisterPage('trolls')

    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('trolls_header'))

    for _, entry in ipairs(actions) do
        local action = entry
        if AdminUI.CanUse(('troll.%s'):format(action.action)) then
            local label = AdminTranslate(action.key)
            local buttonLabel = action.toggle and AdminUI.GetToggleLabel(label, action.action) or label
            AdminUI.AddButton(page, buttonLabel, function(_, element)
                local request = function() AdminTrolls.Request(action.action, AdminUI.GetTarget()) end
                if action.toggle then
                    AdminUI.RunToggleAction(label, action.action, element, request)
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
