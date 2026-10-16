local elements, notices, options = {}, {}, nil
dofile('../feather-menu-v2/client/results.lua')
dofile('../feather-menu-v2/client/validation.lua')
local provider = setmetatable({}, {__index=function(_, method)
    return function(_, ...)
        local args={...}
        if method=='CreateMenu' then options=args[1]; return {ok=true,value={menuId='menu'}} end
        if method=='CreatePage' then return {ok=true,value={pageId=args[2].key}} end
        if method=='AddElement' then
            local problem=MenuValidation.Element(args[3],args[4])
            assert(not problem,problem and problem.message)
            elements[#elements+1]={kind=args[3],data=args[4],callback=args[5]}
            return {ok=true,value={elementId=#elements}}
        end
        return {ok=true,value={}}
    end
end})
exports={['feather-menu-v2']=provider}
AddEventHandler=function() end
CreateThread=function() end
AdminTranslate=function(key) return key end
Feather={Notify={RightNotify=function(value) notices[#notices+1]=value end}}
ClientAllPlayers={{serverId=5,characterName='Jane <Admin>'}}
dofile('client/ui/menu.lua')
AdminUI.SetTarget(5)
local page=AdminUI.RegisterPage('selected_player')
AdminUI.AddHeader(page,'Admin','Player')
assert(options.theme.preset=='redemption' and options.theme.accent==nil and options.size==nil)
assert(elements[#elements].data.value:find('Jane <Admin>',1,true))
local offline=AdminUI.TargetLabel({characterName='Offline',characterId='character-2'})
assert(offline:find('character-2',1,true) and not offline:find('server_id',1,true))
AdminUI.RunAction('submitted',function() end)
assert(#notices==0,'unacknowledged nil callback must not imply success')
AdminUI.RunAction('local success',function() return true end)
assert(#notices==1)
AdminUI.OpenPage=function(key) AdminUI.currentPage=key; AdminUI.openSequence=AdminUI.openSequence+1 end
local dispatched=0
AdminUI.ConfirmTargetAction('Kill',function(target) assert(target==5); dispatched=dispatched+1 end,function() end)
local confirm
for _, element in ipairs(elements) do if element.data.label=='confirm_action' then confirm=element.callback end end
confirm({}); confirm({}); assert(dispatched==1,'one confirmation dispatch only')
AdminUI.ConfirmTargetAction('Kill',function() dispatched=dispatched+1 end,function() end)
for _, element in ipairs(elements) do if element.data.label=='confirm_action' then confirm=element.callback end end
AdminUI.SetTarget(6); confirm({}); assert(dispatched==1,'changed target invalidates confirmation')

AdminPermissions={['players.view']=true}
AdminPlayerDirectory={roles={}}
AdminUI.CanUse=function(action) return action=='players.view' end
AdminUI.AddFooter=function() end
AdminUI.AddFooterButton=function() end
Feather.RPC={Notify=function() end}
for index=1,31 do ClientAllPlayers[index]={serverId=index,characterName=('Player %02d'):format(index)} end
dofile('client/ui/pages/players.lua')
elements={}
AdminUI.OpenPlayers(1)
local count=0
for _, element in ipairs(elements) do
    if element.data.label and element.data.label:find('server_id',1,true) then count=count+1 end
end
assert(count==15,'online list is bounded')
AdminUI.onlinePlayerFilter='Player 31'; elements={}; AdminUI.OpenPlayers(1)
count=0
for _, element in ipairs(elements) do
    if element.data.label and element.data.label:find('server_id',1,true) then count=count+1 end
end
assert(count==1,'literal name filter')
print('Admin menu usability PASS (shared theme, target context, pending feedback, one-shot confirmation, bounded/filterable players)')

local catalog={}
for index=31,1,-1 do catalog[#catalog+1]={id='id-'..index,label=('Entry %02d'):format(index)} end
local state, chosen = {}, nil
local function render()
    elements={}
    AdminUI.AddCatalog(AdminUI.RegisterPage('weapon_issue_catalog'), catalog, state, render,
        function(item) return item.label end, function(item) chosen=item end)
end
local function button(label)
    for _, element in ipairs(elements) do if element.kind=='button' and element.data.label==label then return element.callback end end
end
render()
assert(button('Entry 01') and button('Entry 15') and not button('Entry 16'))
assert(catalog[1].id=='id-31','source catalog order unchanged')
local nextPage
for _, element in ipairs(elements) do if element.kind=='pagearrows' then nextPage=element.callback end end
assert(nextPage,'native Menu V2 pagination')
nextPage({value=1}); assert(state.page==2 and button('Entry 16'))
button('Entry 16')({}); assert(chosen.id=='id-16')
for _, element in ipairs(elements) do if element.kind=='input' then element.callback({value='id-31'}) end end
button('search')({}); assert(state.page==1 and state.query=='id-31' and button('Entry 31') and not button('Entry 30'))
state.query='[no pattern]'; render(); assert(not button('Entry 31'))
local empty=false
for _, element in ipairs(elements) do if element.data.value=='catalog_empty' then empty=true end end
assert(empty,'literal unmatched query renders empty state')
state.query=''; state.page=999; render(); assert(state.page==3,'page clamped after catalog changes')

AdminUI.SetTarget(5)
AdminWeapons={target={serverId=5},selected={id='carbine',label='Carbine'},action='weapon',weapons=catalog,ammunition=catalog}
local issues=0
AdminWeapons.Issue=function(id) assert(id=='carbine'); issues=issues+1 end
dofile('client/ui/pages/weapons_admin.lua')
elements={}; AdminUI.OpenWeaponGrantConfirmation()
local grant=button('confirm_action'); grant({}); grant({}); assert(issues==1)
elements={}; AdminUI.OpenWeaponGrantConfirmation(); grant=button('confirm_action')
AdminWeapons.target={serverId=6}; grant({}); assert(issues==1,'recipient changes invalidate old grant confirmation')

AdminUI.CanUse=function() return true end
AdminUI.CanUseOnTarget=function() return true end
AdminUI.CanUseAnyAction=function() return true end
AdminChatTranslate=AdminTranslate
AdminChatCases={RequestList=function() end}
AdminUI.OpenSelectedPlayerTools=function() end
elements={}; AdminUI.OpenSelectedPlayer()
assert(button('inventory') and button('weapons_and_ammo') and button('player_status') and button('appearance') and button('special_effects'))
assert(not button('player_tools'),'tools are directly accessible from player workspace')
local sections={}
for _, element in ipairs(elements) do
    if element.kind=='accordion' then sections[element.data.key]=element.data end
    if element.data.label=='inventory' then assert(element.data.section,'inventory grouped without extra page') end
    if element.data.label=='special_effects' and element.kind=='accordion' then assert(element.data.value==false) end
    if element.data.section then assert(sections[element.data.section],'section registered before its content') end
end
assert(next(sections),'native accordions present')
print('Admin catalogs/navigation PASS (private sorted paging, name/ID literal filter, empty/clamp, exact selection, one-shot/stale grant, direct player tools)')

AdminInventory={target={serverId=5},items={{name='gun_oil',displayName='',category='supplies',description='Oil'}},category='supplies'}
AdminUI.SetTarget(5)
Config={inventory={maxGrantQuantity=100}}
dofile('client/ui/pages/inventory.lua')
elements={}; AdminUI.OpenInventoryItems('supplies',1)
assert(button('gun_oil'),'missing/empty display labels use item name')
button('gun_oil')({})
for _, element in ipairs(elements) do
    if element.kind=='input' and element.data.label=='quantity' then element.callback({value='2'}) end
end
elements={}; AdminUI.OpenInventoryGrant()
local restored=false
for _, element in ipairs(elements) do if element.data.label=='quantity' and element.data.value=='2' then restored=true end end
assert(restored,'quantity survives confirmation back-navigation')
local granted,removed=0,0
AdminInventory.Give=function(name,amount) assert(name=='gun_oil' and amount==2); granted=granted+1 end
elements={}; AdminUI.OpenInventoryConfirmation(2)
local give=button('confirm_action'); give({}); give({}); assert(granted==1)
AdminInventory.selected={id=135,name='carbine'}
AdminInventory.RemoveInstance=function(id) assert(id==135); removed=removed+1 end
elements={}; AdminUI.OpenInventoryRemovalConfirmation()
local remove=button('confirm_remove_item'); AdminInventory.target={serverId=6}; remove({}); assert(removed==0)
print('Admin inventory UX PASS (fallback labels, retained quantity, one-shot grant, stale removal refusal)')
