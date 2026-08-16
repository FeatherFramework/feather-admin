function AdminUI.OpenTeleports()
    local coordinates
    local page = AdminUI.RegisterPage('teleports')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('teleport_header'))

    local function runTeleport(label, callback)
        AdminUI.Close()
        CreateThread(function()
            Wait(250)
            AdminUI.RunAction(label, callback)
        end)
    end

    local waypointLabel = AdminTranslate('teleport_to_waypoint')
    AdminUI.AddButton(page, waypointLabel, function()
        runTeleport(waypointLabel, AdminTeleports.ToWaypoint)
    end)
    local autoLabel = AdminTranslate('toggle_auto_waypoint')
    AdminUI.AddButton(page, AdminUI.GetToggleLabel(autoLabel, 'auto_waypoint'), function(_, element)
        AdminUI.RunToggleAction(autoLabel, 'auto_waypoint', element, AdminTeleports.ToggleAutoWaypoint)
    end)

    AdminUI.AddInput(page, AdminTranslate('coordinates'), AdminTranslate('coordinates_placeholder'), function(data)
        coordinates = data.value
    end)

    local coordinatesLabel = AdminTranslate('teleport_to_coordinates')
    AdminUI.AddButton(page, coordinatesLabel, function()
        local x, y, z, heading = AdminTeleports.ParseCoordinates(coordinates)
        if not x then
            Feather.Notify.Notify(AdminTranslate('invalid_coordinates'), 3000)
            return
        end

        runTeleport(coordinatesLabel, function()
            AdminTeleports.ToCoordinates(x, y, z, heading)
        end)
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage('teleports')
end
