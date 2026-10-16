local function titleCase(value)
    return tostring(value):gsub('_', ' '):gsub('^%l', string.upper)
end

local function itemLabel(item)
    if type(item.displayName) == 'string' and item.displayName ~= '' then return item.displayName end
    return tostring(item.name or item.id or AdminTranslate('not_available'))
end

-- Display-only wrapping; keep JSON/metadata untouched and preserve UTF-8 units.
local function wrappedLines(value,maximum)
    local lines,line,count={}, {},0
    for _,code in utf8.codes(tostring(value)) do
        count=count+1
        if count>(maximum or 8192) then
            if #line>0 then lines[#lines+1]=table.concat(line); line={} end
            lines[#lines+1]=AdminTranslate('metadata_display_truncated'); break
        end
        if code==10 then lines[#lines+1]=table.concat(line); line={}
        else
            line[#line+1]=utf8.char(code)
            if #line==42 then lines[#lines+1]=table.concat(line); line={} end
        end
    end
    if #line>0 then lines[#lines+1]=table.concat(line) end
    return lines
end
local function detail(page,key,value)
    local text=AdminTranslate(key)..': '..tostring(value==nil and AdminTranslate('not_available') or value)
    AdminUI.AddText(page,table.concat(wrappedLines(text), '\n'))
end
local function percent(value,scale)
    if type(value)~='number' or value~=value or math.abs(value)==math.huge then return AdminTranslate('not_available') end
    return ('%.1f%%'):format(value*(scale or 1))
end

local function inventoryBack()
    local target = AdminInventory.target or {}
    if target.serverId then
        AdminUI.SetTarget(target.serverId)
        AdminUI.OpenSelectedPlayer()
    elseif AdminPlayerDirectory.selected then
        AdminUI.OpenOfflinePlayer(AdminPlayerDirectory.selected)
    else
        AdminUI.OpenPlayers()
    end
end

function AdminUI.OpenInventoryActions()
    if not AdminUI.CanUse('inventory.inspect') and not AdminUI.CanUse('inventory.give') then return end
    local page = AdminUI.RegisterPage('inventory_actions')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('inventory_header'))
    if AdminUI.CanUse('inventory.inspect') then
        AdminUI.AddButton(page, AdminTranslate('inspect_inventory'), AdminInventory.RequestInspection)
    end
    local target = AdminInventory.target or {}
    if target.serverId and AdminUI.CanUseOnTarget('inventory.give', target.serverId) then
        AdminUI.AddButton(page, AdminTranslate('give_item_header'), AdminInventory.RequestCatalog)
    end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), inventoryBack)
    AdminUI.OpenPage('inventory_actions')
end

function AdminUI.OpenInventoryCategories()
    if not AdminUI.CanUseOnTarget('inventory.give') then return end
    local page = AdminUI.RegisterPage('inventory_categories')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('inventory_header'))

    local categories = {}
    for _, item in ipairs(AdminInventory.items) do categories[item.category or 'other'] = true end
    local sorted = {}
    for category in pairs(categories) do sorted[#sorted + 1] = category end
    table.sort(sorted)

    if #sorted == 0 then
        AdminUI.AddText(page, AdminTranslate('no_inventory_items'))
    else
        for _, categoryName in ipairs(sorted) do
            local category = categoryName
            AdminUI.AddButton(page, titleCase(category), function()
                AdminUI.OpenInventoryItems(category, 1)
            end)
        end
    end

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryActions)
    AdminUI.OpenPage('inventory_categories')
end

function AdminUI.OpenInventoryInspection(pageNumber)
    local page = AdminUI.RegisterPage('inventory_inspection')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('inventory_inspection'))
    local target = AdminInventory.target or {}
    AdminUI.AddText(page, ('%s: %s'):format(AdminTranslate('player'),
        tostring(target.characterName or target.accountName or AdminTranslate('not_available'))))
    local filter = AdminUI.inventoryInspectionFilter or ''
    AdminUI.AddInput(page, AdminTranslate('filter_inventory'), AdminTranslate('search'), function(data)
        filter = tostring(data.value or '')
    end, filter)
    AdminUI.AddButton(page, AdminTranslate('search'), function()
        AdminUI.inventoryInspectionFilter = filter
        AdminUI.OpenInventoryInspection(1)
    end)
    local items = {}
    for _, item in ipairs(AdminInventory.inspected) do
        if filter == '' or tostring(item.displayName or item.name or ''):lower():find(filter:lower(), 1, true)
            or tostring(item.id) == filter then items[#items + 1] = item end
    end
    local total = math.max(1, math.ceil(#items / 15))
    local current = math.min(total, math.max(1, math.floor(tonumber(pageNumber) or 1)))
    AdminUI.AddText(page, ('%s: %d / %d | %d'):format(AdminTranslate('page'), current, total, #items))
    if #items == 0 then
        AdminUI.AddText(page, AdminTranslate('inventory_empty'))
    else
        for index = (current - 1) * 15 + 1, math.min(current * 15, #items) do
            local item = items[index]
            AdminUI.AddButton(page, ('#%s - %s'):format(item.id,
                item.displayName or item.name or AdminTranslate('not_available')), function()
                AdminInventory.selected = item
                AdminUI.OpenInventoryInstanceDetails()
            end)
        end
    end
    AdminUI.AddPagination(page, current, total, AdminUI.OpenInventoryInspection)
    AdminUI.AddButton(page, AdminTranslate('refresh'), AdminInventory.RequestInspection)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryActions)
    AdminUI.OpenPage('inventory_inspection')
end

function AdminUI.OpenInventoryInstanceDetails()
    local item = AdminInventory.selected
    if not item then return end
    local page = AdminUI.RegisterPage('inventory_instance_details')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('inventory_item_details'))
    AdminUI.AddText(page, table.concat({
        ('%s: %s'):format(AdminTranslate('instance_id'), item.id),
        ('%s: %s'):format(AdminTranslate('item'), item.displayName or item.name),
        ('%s: %s'):format(AdminTranslate('item_name'), item.name),
        ('%s: %s'):format(AdminTranslate('slot'), item.slot or AdminTranslate('not_available')),
        ('%s: %s'):format(AdminTranslate('weight'), item.weight or 0)
    }, '\n'))
    detail(page,'item_revision',item.revision)
    if type(item.metadata)=='table' and type(item.metadata.weaponDefinitionId)=='string' then
        local metadata=item.metadata
        detail(page,'weapon_serial',metadata.serialNumber)
        detail(page,'weapon_condition',percent(metadata.condition))
        local wear=type(metadata.maintenance)=='table' and metadata.maintenance or {}
        for _,entry in ipairs({{'weapon_degradation','degradation'},{'weapon_permanent_wear','permanentDegradation'},
            {'weapon_damage','damage'},{'weapon_dirt','dirt'},{'weapon_soot','soot'}}) do
            detail(page,entry[1],percent(wear[entry[2]],100))
        end
        local attachments={}
        for _,attachment in ipairs(type(metadata.attachments)=='table' and metadata.attachments or {}) do
            if type(attachment)=='table' then attachments[#attachments+1]=tostring(attachment.slot)..': '..tostring(attachment.definitionId) end
        end
        table.sort(attachments)
        detail(page,'weapon_attachments',#attachments>0 and table.concat(attachments,'\n') or AdminTranslate('no_weapon_attachments'))
    end
    if AdminUI.CanUse('inventory.remove') then
        AdminUI.AddButton(page, AdminTranslate('remove_inventory_item'),
            AdminUI.OpenInventoryRemovalConfirmation)
    end
    local target=AdminInventory.target or {}
    local weapon=type(item.metadata)=='table' and type(item.metadata.weaponDefinitionId)=='string'
        and type(item.metadata.serialNumber)=='string' and type(item.metadata.flags)=='table'
    if weapon then
        AdminUI.AddText(page,AdminTranslate(item.metadata.flags.evidence and 'evidence_held' or 'evidence_clear'))
        if target.serverId==GetPlayerServerId(PlayerId()) and
            (AdminUI.CanUse('weapons.evidence.hold') or AdminUI.CanUse('weapons.evidence.release')) then
            AdminUI.AddButton(page,AdminTranslate('evidence_manage'),AdminInventory.RequestEvidence)
        end
    end
    AdminUI.AddButton(page,AdminTranslate('view_raw_metadata'),function() AdminUI.OpenInventoryRawMetadata(1) end)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryInspection)
    AdminUI.OpenPage('inventory_instance_details')
end

function AdminUI.OpenInventoryRawMetadata(pageNumber)
    local item=AdminInventory.selected
    if not item then return end
    local ok,encoded=pcall(json.encode,item.metadata)
    local lines=wrappedLines(ok and encoded or AdminTranslate('not_available'))
    local total=math.max(1,math.ceil(#lines/18))
    local index=math.max(1,math.min(total,math.floor(tonumber(pageNumber) or 1)))
    local page=AdminUI.RegisterPage('inventory_raw_metadata')
    AdminUI.AddHeader(page,AdminTranslate('admin_header'),AdminTranslate('view_raw_metadata'))
    detail(page,'instance_id',item.id)
    AdminUI.AddText(page,AdminTranslate('metadata_display_only'))
    local slice={}
    for n=(index-1)*18+1,math.min(index*18,#lines) do slice[#slice+1]=lines[n] end
    AdminUI.AddText(page,table.concat(slice,'\n'))
    if index>1 then AdminUI.AddButton(page,AdminTranslate('previous_page'),function()
        if AdminInventory.selected==item then AdminUI.OpenInventoryRawMetadata(index-1) end
    end) end
    if index<total then AdminUI.AddButton(page,AdminTranslate('next_page'),function()
        if AdminInventory.selected==item then AdminUI.OpenInventoryRawMetadata(index+1) end
    end) end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page,AdminTranslate('back'),AdminUI.OpenInventoryInstanceDetails)
    AdminUI.OpenPage('inventory_raw_metadata')
end

function AdminUI.OpenEvidenceConfirmation()
    local item=AdminInventory.selected
    if not item then return end
    local state=AdminInventory.evidence or {}
    local page=AdminUI.RegisterPage('inventory_evidence_confirmation')
    AdminUI.AddHeader(page,AdminTranslate('admin_header'),AdminTranslate('evidence_manage'))
    AdminUI.AddText(page,('#%s — %s'):format(item.id,item.displayName or item.name))
    if state.message then AdminUI.AddText(page,AdminTranslate(state.message)) end
    if state.serialNumber then
        AdminUI.AddText(page,AdminTranslate('evidence_serial_revision'):format(state.serialNumber,state.itemRevision))
        AdminUI.AddText(page,AdminTranslate(state.evidence and 'evidence_held' or 'evidence_clear'))
    end
    if state.allowed and not AdminInventory.evidencePending then
        AdminUI.AddText(page,AdminTranslate('evidence_confirm_warning'))
        AdminUI.AddButton(page,AdminTranslate(state.operation=='hold' and 'evidence_confirm_hold' or 'evidence_confirm_release'),
            AdminInventory.ChangeEvidence)
    elseif state.serialNumber then AdminUI.AddText(page,AdminTranslate('evidence_unavailable')) end
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page,AdminTranslate('back'),AdminUI.OpenInventoryInstanceDetails)
    AdminUI.OpenPage('inventory_evidence_confirmation')
end

function AdminUI.OpenInventoryRemovalConfirmation()
    local item = AdminInventory.selected
    if not item or not AdminUI.CanUse('inventory.remove') then return AdminUI.NotifyActionDenied() end
    local page = AdminUI.RegisterPage('inventory_removal_confirmation')
    local target, sequence, submitted = AdminInventory.target, AdminUI.openSequence + 1, false
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_inventory_removal'))
    AdminUI.AddText(page, ('#%s - %s'):format(item.id, item.displayName or item.name))
    AdminUI.AddButton(page, AdminTranslate('confirm_remove_item'), function()
        if submitted or AdminInventory.target ~= target or AdminInventory.selected ~= item
            or AdminUI.currentPage ~= 'inventory_removal_confirmation' or AdminUI.openSequence ~= sequence then return end
        submitted = true
        AdminInventory.RemoveInstance(item.id)
        AdminUI.AddText(page, AdminTranslate('action_request_sent'))
    end)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryInstanceDetails)
    AdminUI.OpenPage('inventory_removal_confirmation')
end

function AdminUI.OpenInventoryItems(category, pageNumber)
    if not AdminUI.CanUseOnTarget('inventory.give') then return end
    AdminInventory.category = category
    AdminInventory.catalogLists = AdminInventory.catalogLists or {}
    AdminInventory.catalogLists[category] = AdminInventory.catalogLists[category] or {}
    local state = AdminInventory.catalogLists[category]
    if tonumber(pageNumber) then state.page = tonumber(pageNumber) end
    local page = AdminUI.RegisterPage('inventory_items')
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), titleCase(category))

    local items = {}
    for _, entry in ipairs(AdminInventory.items) do
        if (entry.category or 'other') == category then items[#items + 1] = entry end
    end
    AdminUI.AddCatalog(page, items, state, function() AdminUI.OpenInventoryItems(category) end, itemLabel, function(item)
        AdminInventory.selected = item
        AdminInventory.grantQuantity = ''
        AdminUI.OpenInventoryGrant()
    end)
    AdminInventory.page = state.page

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryCategories)
    AdminUI.OpenPage('inventory_items')
end

function AdminUI.OpenInventoryGrant()
    local item = AdminInventory.selected
    if not item or not AdminUI.CanUseOnTarget('inventory.give') then return end
    local page = AdminUI.RegisterPage('inventory_grant')
    local quantity = AdminInventory.grantQuantity or ''
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('give_item_header'))
    AdminUI.AddText(page, table.concat({
        itemLabel(item),
        item.description ~= '' and item.description or AdminTranslate('not_available'),
        ('%s: %s'):format(AdminTranslate('item_name'), item.name)
    }, '\n'))
    AdminUI.AddInput(page, AdminTranslate('quantity'), AdminTranslate('required'), function(data)
        quantity = data.value
        AdminInventory.grantQuantity = quantity
    end, quantity)
    AdminUI.AddButton(page, AdminTranslate('continue'), function()
        local parsed = tonumber(quantity)
        local maximum = tonumber(Config.inventory.maxGrantQuantity) or 100
        if not parsed or parsed < 1 or parsed % 1 ~= 0 or parsed > maximum then
            Feather.Notify.RightNotify(AdminTranslate('invalid_item_quantity'), 3000)
            return
        end
        AdminUI.OpenInventoryConfirmation(parsed)
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), function()
        AdminUI.OpenInventoryItems(AdminInventory.category, AdminInventory.page)
    end)
    AdminUI.OpenPage('inventory_grant')
end

function AdminUI.OpenInventoryConfirmation(quantity)
    local item = AdminInventory.selected
    if not item or not AdminUI.CanUseOnTarget('inventory.give') then return end
    local page = AdminUI.RegisterPage('inventory_confirmation')
    local target, playerId, sequence, submitted = AdminInventory.target, AdminUI.GetTarget(), AdminUI.openSequence + 1, false
    AdminUI.AddHeader(page, AdminTranslate('admin_header'), AdminTranslate('confirm_item_grant'))
    AdminUI.AddText(page, table.concat({
        ('%s: %s'):format(AdminTranslate('server_id'), tostring(AdminUI.GetTarget())),
        ('%s: %s'):format(AdminTranslate('item'), itemLabel(item)),
        ('%s: %s'):format(AdminTranslate('quantity'), tostring(quantity))
    }, '\n'))
    AdminUI.AddButton(page, AdminTranslate('confirm_action'), function()
        if submitted or AdminInventory.target ~= target or AdminUI.GetTarget() ~= playerId or AdminInventory.selected ~= item
            or AdminUI.currentPage ~= 'inventory_confirmation' or AdminUI.openSequence ~= sequence then return end
        submitted = true
        AdminInventory.Give(item.name, quantity)
        AdminUI.AddText(page, AdminTranslate('action_request_sent'))
    end)

    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page, AdminTranslate('back'), AdminUI.OpenInventoryGrant)
    AdminUI.OpenPage('inventory_confirmation')
end
