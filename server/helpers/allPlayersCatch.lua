---- Handles updating all known players and passing of them to the client ----
AllPlayers = {}
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
        TriggerClientEvent('feather-admin:ClientAllPlayers', -1, true, _source) --Passes new player to all clients to store
    end
end)

---- Cleanup and player removal on leave ----
AddEventHandler('playerDropped', function()
    local _source = source
    for k, v in pairs(AllPlayers) do
        if _source == v then
            table.remove(AllPlayers, k) --removes source from the table
            TriggerClientEvent('feather-admin:ClientAllPlayers', -1, true, k)
        end
    end
end)