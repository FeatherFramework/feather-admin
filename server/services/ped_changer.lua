local allowedModels = {}

local function registerAllowedModels(category)
    for _, ped in ipairs(category.models) do
        local modelName = string.lower(ped.model)
        allowedModels[modelName] = joaat(modelName)
    end
end

for _, category in ipairs(Config.pedChanger.categories) do
    registerAllowedModels(category)
end

RegisterNetEvent('feather-admin:ped:request', function(targetPlayer, modelName)
    local src = source
    local target = FeatherAdmin.RequireTarget(src, 'ped.change', targetPlayer)
    if target == nil or type(modelName) ~= 'string' or #modelName > 64 then return end

    local model = allowedModels[string.lower(modelName)]
    if model == nil then return end

    AdminAudit.Record(src, 'ped.change', target, modelName)
    TriggerClientEvent('feather-admin:ped:apply', target, model)
end)
