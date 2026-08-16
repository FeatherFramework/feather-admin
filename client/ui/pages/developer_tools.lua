function AdminUI.OpenDeveloperTools()
    local page = AdminUI.RegisterPage('developer_tools')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('developer_tools_header'))
    local inspectorLabel = AdminTranslate('entity_inspector')
    AdminUI.AddButton(page, AdminUI.GetToggleLabel(inspectorLabel, 'entity_inspector'), function(_, element)
        AdminUI.RunToggleAction(inspectorLabel, 'entity_inspector', element, AdminDeveloperTools.ToggleDevGun)
    end)
    local boneLabel = AdminTranslate('bone_viewer')
    AdminUI.AddButton(page, AdminUI.GetToggleLabel(boneLabel, 'bone_viewer'), function(_, element)
        AdminUI.RunToggleAction(boneLabel, 'bone_viewer', element, AdminDeveloperTools.ToggleBoneDisplay)
    end)

    local coordinateActions = {
        { key = 'copy_vector3', format = 'vector3' },
        { key = 'copy_vector4', format = 'vector4' },
        { key = 'copy_xyz', format = 'xyz' },
        { key = 'copy_heading', format = 'heading' }
    }
    for _, entry in ipairs(coordinateActions) do
        local action = entry
        local label = AdminTranslate(action.key)
        AdminUI.AddButton(page, label, function()
            AdminUI.RunAction(label, function()
                return AdminDeveloperTools.CopyCoordinates(action.format)
            end)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage('developer_tools')
end
