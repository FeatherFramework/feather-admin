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
        -- (ADM-06) The server now sends the departed player's actual id
        -- (recData), not an index into a different array, so remove by
        -- value here too instead of table.remove(ClientAllPlayers, recData).
        for k, v in pairs(ClientAllPlayers) do
            if v == recData then
                table.remove(ClientAllPlayers, k)
                break
            end
        end
    end
end)