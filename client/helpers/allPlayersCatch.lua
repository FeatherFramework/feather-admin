---- Handles the recieving of all known players from the server ----
ClientAllPlayers = {}
RegisterNetEvent('feather-admin:ClientAllPlayers', function(newPlayer)
    local insert  = true
    for k, v in pairs(ClientAllPlayers) do
        if v == newPlayer then
            insert = false
        end
    end
    if insert then
        table.insert(ClientAllPlayers, newPlayer)
    end
end)