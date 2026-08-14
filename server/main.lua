-- (ADM-04) This file was empty. It's the reason every action in this repo
-- had no server-side permission model at all -- the client "isAdmin" flag
-- in boostersMenu() only ever hid UI buttons; the server trusted every
-- event unconditionally. Every privileged handler in this repo now goes
-- through IsAuthorizedAdmin(), which re-derives the caller's role from
-- `source` via feather-core's roles/level primitive (see
-- feather-core/server/services/character.lua's CharacterAPI.IsAdmin) --
-- never from anything the client asserts about itself.
Feather = exports['feather-core'].initiate()

function IsAuthorizedAdmin(src)
    return Feather.Character.IsAdmin(src)
end

function RejectUnauthorized(src, eventName)
    print(("[feather-admin] Rejected %s from unauthorized src %s"):format(eventName, tostring(src)))
end

-- Lets the client decide whether to even open the menu (good UX -- a
-- non-admin never sees a menu full of buttons that will silently fail),
-- without that decision being the actual security boundary. The real gate
-- is IsAuthorizedAdmin() inside each event handler below/in the helpers.
Feather.RPC.Register("feather-admin:IsAdmin", function(params, res, src)
    return res(IsAuthorizedAdmin(src))
end)

-- (ADM-05 support) Gives an admin who opens the menu the current full
-- roster, not just players who join after they do -- see the broadcast
-- change in server/helpers/allPlayersCatch.lua for why that distinction
-- matters now that roster broadcasts are admin-only instead of global.
Feather.RPC.Register("feather-admin:GetOnlinePlayers", function(params, res, src)
    if not IsAuthorizedAdmin(src) then
        return res({})
    end
    return res(AllPlayers or {})
end)
