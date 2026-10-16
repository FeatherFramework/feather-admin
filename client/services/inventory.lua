AdminInventory = {
    items = {},
    selected = nil,
    category = nil,
    page = 1,
    target = nil,
    inspected = {},
    inspection = nil
}

local function targetPayload(extra)
    local target = AdminInventory.target or {}
    local payload = { serverId = target.serverId, accountId = target.accountId,
        characterId = target.characterId }
    for key, value in pairs(extra or {}) do payload[key] = value end
    return payload
end

function AdminInventory.SetOnlineTarget(serverId)
    AdminInventory.evidence=nil; AdminInventory.evidencePending=nil
    AdminInventory.target = { serverId = serverId }
end

function AdminInventory.SetTarget(target)
    AdminInventory.evidence=nil; AdminInventory.evidencePending=nil
    AdminInventory.target = type(target) == 'table' and target or nil
end

function AdminInventory.RequestInspection()
    if not AdminUI.CanUse('inventory.inspect') then return AdminUI.NotifyActionDenied() end
    Feather.RPC.Notify('feather-admin:inventory:inspect', targetPayload())
end

function AdminInventory.RemoveInstance(instanceId)
    Feather.RPC.Notify('feather-admin:inventory:remove-instance',
        targetPayload({ instanceId = instanceId }))
end

function AdminInventory.RequestCatalog()
    if not AdminUI.CanUseOnTarget('inventory.give') then return false end
    Feather.RPC.Notify('feather-admin:inventory:catalog', {})
    return true
end

function AdminInventory.Give(itemName, quantity)
    Feather.RPC.Notify('feather-admin:inventory:give', {
        playerId = AdminUI.GetTarget(),
        itemName = itemName,
        quantity = quantity
    })
end

RegisterNetEvent('feather-admin:inventory:catalog:result', function(items)
    AdminInventory.items = type(items) == 'table' and items or {}
    AdminUI.OpenInventoryCategories()
end)

local evidenceSequence=0
local function evidenceRequest(phase,payload)
    if AdminInventory.evidencePending then return end
    local item=AdminInventory.selected
    if not item then return end
    evidenceSequence=evidenceSequence+1
    local pending={id='evidence-ui:'..evidenceSequence,phase=phase,item=item,target=AdminInventory.target,sequence=AdminUI.openSequence}
    AdminInventory.evidencePending=pending
    payload.requestId=pending.id
    Feather.RPC.Notify('feather-admin:inventory:evidence-'..(phase=='preview' and 'status' or 'change'),targetPayload(payload))
    SetTimeout(15000,function()
        if AdminInventory.evidencePending~=pending then return end
        AdminInventory.evidencePending=nil
        if AdminInventory.selected==pending.item and AdminInventory.target==pending.target
            and AdminUI.openSequence==pending.sequence and AdminUI.currentPage~=nil then
            AdminInventory.evidence={allowed=false,message=pending.phase=='change' and 'evidence_unresolved' or 'evidence_unavailable'}
            AdminUI.OpenEvidenceConfirmation()
        end
    end)
end
function AdminInventory.RequestEvidence()
    if not AdminUI.CanUse('inventory.inspect') then return end
    AdminInventory.evidence=nil
    evidenceRequest('preview',{instanceId=AdminInventory.selected and AdminInventory.selected.id})
end
function AdminInventory.ChangeEvidence()
    local preview=AdminInventory.evidence
    if not preview or not preview.allowed or AdminInventory.evidencePending
        or preview._item~=AdminInventory.selected or preview._target~=AdminInventory.target then return end
    AdminInventory.evidence={allowed=false,message='evidence_pending'}
    evidenceRequest('change',{ticket=preview.ticket,operation=preview.operation})
    AdminUI.OpenEvidenceConfirmation()
    if AdminInventory.evidencePending then AdminInventory.evidencePending.sequence=AdminUI.openSequence end
end
RegisterNetEvent('feather-admin:inventory:evidence:result',function(id,phase,succeeded,key,value)
    if source~=65535 then return end
    local pending=AdminInventory.evidencePending
    if not pending or pending.id~=id or pending.phase~=phase then return end
    AdminInventory.evidencePending=nil
    if AdminInventory.selected~=pending.item or AdminInventory.target~=pending.target
        or AdminUI.openSequence~=pending.sequence or AdminUI.currentPage==nil then return end
    if succeeded and phase=='preview' and type(value)=='table' and value.itemId==pending.item.id then
        value._item=pending.item; value._target=pending.target
        AdminInventory.evidence=value
        SetTimeout(tonumber(value.expiresInMs) or 30000,function()
            if AdminInventory.evidence~=value or AdminInventory.evidencePending then return end
            value.allowed=false; value.message='evidence_preview_expired'
            if AdminInventory.selected==pending.item and AdminInventory.target==pending.target
                and AdminUI.currentPage=='inventory_evidence_confirmation' then AdminUI.OpenEvidenceConfirmation() end
        end)
    else
        AdminInventory.evidence={allowed=false,message=key or 'evidence_unresolved'}
        if succeeded and phase=='change' and type(value)=='table' and type(pending.item.metadata)=='table'
            and type(pending.item.metadata.flags)=='table' then
            pending.item.metadata.flags.evidence=value.evidence
            pending.item.revision=value.itemRevision
        end
    end
    AdminUI.OpenEvidenceConfirmation()
end)

RegisterNetEvent('feather-admin:inventory:result', function(succeeded, messageKey, displayName, quantity)
    local message = AdminTranslate(messageKey)
    if succeeded then
        message = ('%s: %s x%s'):format(message, tostring(displayName), tostring(quantity))
        AdminUI.Close()
    end
    Feather.Notify.RightNotify(message, 3500)
end)

RegisterNetEvent('feather-admin:inventory:received', function(displayName, quantity)
    Feather.Notify.RightNotify(('%s: %s x%s'):format(
        AdminTranslate('item_received'), tostring(displayName), tostring(quantity)), 3500)
end)

RegisterNetEvent('feather-admin:inventory:inspect:result', function(succeeded, messageKey, target, rows, inventory)
    if succeeded ~= true then
        return Feather.Notify.RightNotify(AdminTranslate(messageKey or 'inventory_inspection_unavailable'), 3500)
    end
    AdminInventory.target = type(target) == 'table' and target or AdminInventory.target
    AdminInventory.inspected = type(rows) == 'table' and rows or {}
    AdminInventory.inspection = type(inventory) == 'table' and inventory or nil
    AdminUI.OpenInventoryInspection()
end)

RegisterNetEvent('feather-admin:inventory:remove:result', function(succeeded, messageKey, displayName)
    local message = AdminTranslate(messageKey or 'inventory_remove_internal')
    if displayName then message = ('%s: %s'):format(message, tostring(displayName)) end
    Feather.Notify.RightNotify(message, 3500)
    if succeeded == true then AdminInventory.RequestInspection() end
end)
