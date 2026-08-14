-- (ADM-04 UX) The real authorization boundary is server-side (every
-- privileged event re-checks IsAuthorizedAdmin independently), but a
-- non-admin shouldn't see a menu full of buttons that will just silently
-- fail. This RPC re-derives the caller's role server-side the same way, so
-- it can't be spoofed into opening the menu locally.
local function TryOpenAdminMenu()
    if Inmenu then return end

    -- Claimed immediately, before the RPC round-trip below, not after --
    -- CallAsync yields the calling thread while it waits on the server, so
    -- a second keypress/command during that window would otherwise slip
    -- past the `if Inmenu` guard above and race to open the menu twice.
    -- Reset back to false on every path that doesn't end in MainAdminMenu()
    -- actually running, and (via the `closed` callback registered in
    -- client/helpers/functions.lua) whenever the menu genuinely closes.
    Inmenu = true

    local isAdmin = Feather.RPC.CallAsync('feather-admin:IsAdmin', {})
    if not isAdmin then
        Inmenu = false
        return
    end

    -- Full roster, not just players who join after this point -- roster
    -- broadcasts are admin-only now (ADM-05), so a client that wasn't
    -- recognized as admin yet would otherwise have an empty/incomplete
    -- ClientAllPlayers.
    ClientAllPlayers = Feather.RPC.CallAsync('feather-admin:GetOnlinePlayers', {}) or {}

    MainAdminMenu()
end

CreateThread(function()
    TriggerServerEvent('feather-admin:StorePlayersInfo')
    if Config.Setup.OpenMenu.button then
        while true do
            Wait(5)
            if IsControlJustReleased(0, 0xA5BDCD3C) then
                TryOpenAdminMenu()
            end
        end
    else
        RegisterCommand(Config.Setup.OpenMenu.commandName, TryOpenAdminMenu, true)
    end
end)