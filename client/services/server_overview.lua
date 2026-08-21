AdminServerOverview = {
    snapshot = nil
}

function AdminServerOverview.Request()
    if not AdminUI.CanUse('server.overview') then
        AdminUI.NotifyActionDenied()
        return false
    end

    Feather.RPC.Notify('feather-admin:server:overview', {})
    return true
end

RegisterNetEvent('feather-admin:server:overview', function(snapshot)
    if type(snapshot) ~= 'table' then return end
    AdminServerOverview.snapshot = snapshot
    AdminUI.OpenServerOverview()
end)
