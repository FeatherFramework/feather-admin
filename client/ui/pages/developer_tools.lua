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

    local coordinateActions = {
        { key = 'copy_vector3', format = 'vector3' },
        { key = 'copy_vector4', format = 'vector4' },
        { key = 'copy_xyz', format = 'xyz' },
        { key = 'copy_heading', format = 'heading' }
    }
    if AdminUI.CanUse('developer.copy_coordinates') then
        for _, entry in ipairs(coordinateActions) do
            local action = entry
            local label = AdminTranslate(action.key)
            AdminUI.AddButton(page, label, function()
                AdminUI.RunAction(label, function()
                    return AdminDeveloperTools.CopyCoordinates(action.format)
                end)
            end)
        end
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage('developer_tools')
end
