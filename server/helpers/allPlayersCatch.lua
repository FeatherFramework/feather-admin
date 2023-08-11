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
        TriggerClientEvent('feather-admin:ClientAllPlayers', -1, _source) --Passes new player to all clients to store
    end
end)