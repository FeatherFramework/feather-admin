---- Handles the recieving of all known players from the server ----
ClientAllPlayers = {}
RegisterNetEvent('feather-admin:ClientAllPlayers', function(creation, recData)
    if creation then
        local insert  = true
        for k, v in pairs(ClientAllPlayers) do
            if v == recData then
                insert = false
            end
        end
        if insert then
            table.insert(ClientAllPlayers, recData)
        end
    else
        table.remove(ClientAllPlayers, recData)
    end
end)