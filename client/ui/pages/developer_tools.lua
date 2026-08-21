function AdminUI.OpenDeveloperTools()
    if not AdminUI.CanUseAny('developer.') then return end
    local page = AdminUI.RegisterPage('developer_tools')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('developer_tools_header'))
    if AdminUI.CanUse('developer.entity_inspector') then
        local inspectorLabel = AdminTranslate('entity_inspector')
        AdminUI.AddButton(page, AdminUI.GetToggleLabel(inspectorLabel, 'entity_inspector'), function(_, element)
            AdminUI.RunToggleAction(inspectorLabel, 'entity_inspector', element, AdminDeveloperTools.ToggleDevGun)
        end)
    end
    if AdminUI.CanUse('developer.bone_viewer') then
        local boneLabel = AdminTranslate('bone_viewer')
        AdminUI.AddButton(page, AdminUI.GetToggleLabel(boneLabel, 'bone_viewer'), function(_, element)
            AdminUI.RunToggleAction(boneLabel, 'bone_viewer', element, AdminDeveloperTools.ToggleBoneDisplay)
        end)
    end

    if AdminUI.CanUse('developer.copy_coordinates') then
        local options = {
            { display = AdminTranslate('position_vector3'), value = 'vector3' },
            { display = AdminTranslate('position_vector4'), value = 'vector4' },
            { display = AdminTranslate('position_xyz'), value = 'xyz' },
            { display = AdminTranslate('position_heading'), value = 'heading' }
        }
        local selected = options[1].value
        local selectedLabel = options[1].display
        AdminUI.AddArrows(page, AdminTranslate('position_format'), options, 0, function(data)
            selected = data.value.value
            selectedLabel = data.value.display
        end)
        AdminUI.AddButton(page, AdminTranslate('copy'), function()
            local message = ('%s %s'):format(selectedLabel, AdminTranslate('copied'))
            AdminUI.RunAction(message, function() return AdminDeveloperTools.CopyCoordinates(selected) end)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage('developer_tools')
end
