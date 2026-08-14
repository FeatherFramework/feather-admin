---- Handles updating all known players and passing of them to the client ----
AllPlayers = {}

-- (ADM-05) Roster updates used to broadcast to -1 (every connected client),
-- handing every player -- not just admins -- the full list of valid server
-- ids to target with ADM-01/02/03. Any player still needs to be trackable
-- (admins need to see everyone, not just other admins), so
-- StorePlayersInfo itself stays open to all callers -- what changed is that
-- the resulting roster push only goes to currently-online admins.
local function GetOnlineAdminSources()
    local admins = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and IsAuthorizedAdmin(src) then
            table.insert(admins, src)
        end
    end
    return admins
end

local function BroadcastToAdmins(eventName, ...)
    for _, adminSrc in ipairs(GetOnlineAdminSources()) do
        TriggerClientEvent(eventName, adminSrc, ...)
    end
end

RegisterServerEvent('feather-admin:StorePlayersInfo', function()
    local _source = source
    local insert  = true
    for k, v in pairs(AllPlayers) do
        if v == _source then
            insert = false
        end
    end
    if insert then
        table.insert(AllPlayers, _source)
        BroadcastToAdmins('feather-admin:ClientAllPlayers', true, _source) --Passes new player to online admins only
    end
end)

---- Cleanup and player removal on leave ----
-- (ADM-06) This previously mutated AllPlayers mid-`pairs` iteration, sent
-- `true` (creation) instead of `false` (removal) for a departing player,
-- and broadcast the server-side array *index* `k` -- which has no
-- relationship to the client's independently-indexed ClientAllPlayers
-- array -- instead of the player id itself. Net effect: clients never
-- actually removed a departed player and instead inserted a bogus "player
-- id" equal to the removed index. Fixed to break after removing (safe
-- since ids are unique) and to send the removal flag + the actual player
-- id value, matching how ClientAllPlayers now removes by value (see
-- client/helpers/allPlayersCatch.lua).
AddEventHandler('playerDropped', function()
    local _source = source
    for k, v in pairs(AllPlayers) do
        if _source == v then
            table.remove(AllPlayers, k) --removes source from the table
            BroadcastToAdmins('feather-admin:ClientAllPlayers', false, v)
            break
        end
    end
end)