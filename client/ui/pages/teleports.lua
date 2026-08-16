function AdminUI.OpenTeleports()
    if not AdminUI.CanUseAny('teleport.') then return end
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

    if AdminUI.CanUse('teleport.waypoint') then
        local waypointLabel = AdminTranslate('teleport_to_waypoint')
        AdminUI.AddButton(page, waypointLabel, function()
            runTeleport(waypointLabel, AdminTeleports.ToWaypoint)
        end)
    end
    if AdminUI.CanUse('teleport.auto_waypoint') then
        local autoLabel = AdminTranslate('toggle_auto_waypoint')
        AdminUI.AddButton(page, AdminUI.GetToggleLabel(autoLabel, 'auto_waypoint'), function(_, element)
            AdminUI.RunToggleAction(autoLabel, 'auto_waypoint', element, AdminTeleports.ToggleAutoWaypoint)
        end)
    end

    if AdminUI.CanUse('teleport.coordinates') then
        AdminUI.AddInput(page, AdminTranslate('coordinates'), AdminTranslate('coordinates_placeholder'), function(data)
            coordinates = data.value
        end)

        local coordinatesLabel = AdminTranslate('teleport_to_coordinates')
        AdminUI.AddButton(page, coordinatesLabel, function()
            local x, y, z, heading = AdminTeleports.ParseCoordinates(coordinates)
            if not x then
                Feather.Notify.RightNotify(AdminTranslate('invalid_coordinates'), 3000)
                return
            end

            runTeleport(coordinatesLabel, function()
                return AdminTeleports.ToCoordinates(x, y, z, heading)
            end)
        end)
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenMain)
    AdminUI.OpenPage('teleports')
end
