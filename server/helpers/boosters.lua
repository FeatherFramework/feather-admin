RegisterServerEvent('feather-admin:PedChangeSender', function(playerId, model)
    TriggerClientEvent('feather-admin:PedChangeHandler', playerId, model)
end)

RegisterServerEvent('feather-admin:InvincibilitySender', function(playerId)
    TriggerClientEvent('feather-admin:SetPlayerInvincibleHandler', playerId)
end)

RegisterServerEvent('feather-admin:InvisibilitySender', function(playerId)
    TriggerClientEvent('feather-admin:SetPlayerInvisibleHandler', playerId)
end)

RegisterServerEvent('feather-admin:InfStaminaSender', function(playerId)
    TriggerClientEvent('feather-admin:SetPlayerInfStaminaHandler', playerId)
end)

RegisterServerEvent('feather-admin:HealSender', function(playerId)
    TriggerClientEvent('feather-admin:HealPlayerHandler', playerId)
end)