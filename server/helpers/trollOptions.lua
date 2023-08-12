RegisterServerEvent('feather-admin:SendLightningStrike', function(playerId)
    TriggerClientEvent('feather-admin:LightningStrikeHandler', playerId)
end)

RegisterServerEvent('feather-admin:SendFreezePlayer', function(playerId)
    TriggerClientEvent('feather-admin:FreezePlayerHandler', playerId)
end)

RegisterServerEvent('feather-admin:SendTeleportToHeaven', function(playerId)
    TriggerClientEvent('feather-admin:SendToHeavenHandler', playerId)
end)

RegisterServerEvent('feather-admin:SendKillPlayer', function(playerId)
    TriggerClientEvent('feather-admin:KillplayerHandler', playerId)
end)

RegisterServerEvent('feather-admin:SendCagePlayer', function(playerId)
    TriggerClientEvent('feather-admin:CagePlayerlayerHandler', playerId)
end)