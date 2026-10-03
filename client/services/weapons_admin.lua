AdminWeapons = { target = nil, weapons = {}, ammunition = {}, selected = nil,
    action = nil, quantity = '' }

local function payload(extra)
    local target = AdminWeapons.target or {}
    local data = { serverId = target.serverId, accountId = target.accountId,
        characterId = target.characterId }
    for key, value in pairs(extra or {}) do data[key] = value end
    return data
end

function AdminWeapons.SetOnlineTarget(serverId) AdminWeapons.target = { serverId = serverId } end
function AdminWeapons.SetTarget(target) AdminWeapons.target = type(target) == 'table' and target or nil end

function AdminWeapons.RequestCatalog()
    Feather.RPC.Notify('feather-admin:weapons:catalog', {})
end

local issueSequence = 0
local issueSession = ('%08x-%08x'):format(GetGameTimer(), math.random(0, 0x7fffffff))
function AdminWeapons.Issue(definitionId)
    issueSequence = issueSequence + 1
    local requestId = ('%s-%d'):format(issueSession, issueSequence)
    Feather.RPC.Notify('feather-admin:weapons:issue',
        payload({ definitionId = definitionId, requestId = requestId }))
end

function AdminWeapons.GrantAmmo(definitionId, quantity)
    Feather.RPC.Notify('feather-admin:weapons:grant-ammo',
        payload({ definitionId = definitionId, quantity = quantity }))
end

RegisterNetEvent('feather-admin:weapons:catalog:result', function(weapons, ammunition)
    AdminWeapons.weapons = type(weapons) == 'table' and weapons or {}
    AdminWeapons.ammunition = type(ammunition) == 'table' and ammunition or {}
    AdminUI.OpenWeaponAdmin()
end)

RegisterNetEvent('feather-admin:weapons:result', function(succeeded, messageKey, detail, quantity)
    local message = AdminTranslate(messageKey or 'weapons_unavailable')
    if detail then message = ('%s: %s%s'):format(message, tostring(detail),
        quantity and (' x' .. tostring(quantity)) or '') end
    Feather.Notify.RightNotify(message, 4000)
    if succeeded == true then
        AdminWeapons.selected, AdminWeapons.action, AdminWeapons.quantity = nil, nil, ''
        AdminWeapons.RequestCatalog()
    end
end)
