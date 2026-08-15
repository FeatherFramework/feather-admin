local allowedModels = {}

for _, category in ipairs(Config.pedChanger.categories) do
    for _, ped in ipairs(category.models) do
        local modelName = string.lower(ped.model)
        allowedModels[modelName] = joaat(modelName)
    end
end

RegisterNetEvent('feather-admin:ped:request', function(targetPlayer, modelName)
    local src = source
    if not FeatherAdmin.RequireAuthorized(src) then return end

    local target = FeatherAdmin.ValidTarget(targetPlayer)
    if target == nil or type(modelName) ~= 'string' or #modelName > 64 then return end

    local model = allowedModels[string.lower(modelName)]
    if model == nil then return end

    TriggerClientEvent('feather-admin:ped:apply', target, model)
end)
