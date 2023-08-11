AllPlayers = {}
RegisterServerEvent('feather-admin:StorePlayersInfo', function()
    local _source = source
    table.insert(AllPlayers, _source)
end)