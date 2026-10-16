local events,timers,requests={},{},{}
RegisterNetEvent=function(n,fn) events[n]=fn end
SetTimeout=function(_,fn) timers[#timers+1]=fn end
local opened=0
AdminUI={openSequence=1,currentPage='inventory_instance_details',CanUse=function() return true end,
 OpenEvidenceConfirmation=function() opened=opened+1; AdminUI.openSequence=AdminUI.openSequence+1; AdminUI.currentPage='inventory_evidence_confirmation' end}
Feather={RPC={Notify=function(name,payload) requests[#requests+1]={name=name,payload=payload} end}}
dofile('client/services/inventory.lua')
local item={id=135,metadata={flags={evidence=false}}}
AdminInventory.selected=item; AdminInventory.target={serverId=5,characterId='Jane'}
AdminInventory.RequestEvidence()
local request=requests[#requests].payload
assert(request.instanceId==135 and request.serverId==5)
source=10
events['feather-admin:inventory:evidence:result'](request.requestId,'preview',true,nil,{itemId=135,allowed=true})
assert(opened==0,'untrusted client result ignored')
source=65535
events['feather-admin:inventory:evidence:result'](request.requestId,'preview',true,nil,{itemId=135,ticket='private',operation='hold',allowed=true})
assert(opened==1 and AdminInventory.evidence.allowed)
AdminInventory.ChangeEvidence()
local change=requests[#requests].payload
assert(change.ticket=='private' and change.operation=='hold' and change.serialNumber==nil and change.metadata==nil)
local count=#requests
AdminInventory.ChangeEvidence(); assert(#requests==count,'overlap cannot send twice')
events['feather-admin:inventory:evidence:result'](change.requestId,'change',false,'evidence_unresolved')
assert(not AdminInventory.evidence.allowed and AdminInventory.evidence.message=='evidence_unresolved')
AdminInventory.ChangeEvidence(); assert(#requests==count,'unknown outcome has no retry action')
AdminUI.currentPage='inventory_instance_details'
AdminInventory.RequestEvidence(); request=requests[#requests].payload
AdminUI.openSequence=AdminUI.openSequence+1; AdminUI.currentPage=nil
events['feather-admin:inventory:evidence:result'](request.requestId,'preview',true,nil,{itemId=135,allowed=true})
assert(opened==3,'late preview cannot reopen a closed menu')
AdminUI.currentPage='inventory_instance_details'
AdminInventory.RequestEvidence()
AdminInventory.SetOnlineTarget(6)
timers[#timers]()
assert(AdminInventory.evidence==nil and opened==3,'target change discards stale timeout')
AdminInventory.target={serverId=5}; AdminUI.currentPage='inventory_instance_details'
AdminInventory.RequestEvidence(); request=requests[#requests].payload
events['feather-admin:inventory:evidence:result'](request.requestId,'preview',true,nil,
 {itemId=135,ticket='expires',operation='hold',allowed=true,expiresInMs=30000})
timers[#timers]()
assert(not AdminInventory.evidence.allowed and AdminInventory.evidence.message=='evidence_preview_expired')
count=#requests; AdminInventory.ChangeEvidence()
assert(#requests==count,'expired visible confirmation cannot send a mutation')
-- Exercise the actual page builder as well as request lifetime logic.
Feather.Locale={register=function() end}
dofile('translations/en_us.lua')
AdminTranslate=function(key) return AdminEnglishTranslations[key] or key end
json={encode=function() return '{}' end}
GetPlayerServerId=function() return 5 end; PlayerId=function() return 1 end
local labels,texts={},{}
AdminUI.Styles={button={}}
AdminUI.RegisterPage=function() labels={}; texts={}; return {} end
AdminUI.AddHeader=function() end; AdminUI.AddFooter=function() end; AdminUI.AddFooterButton=function() end
AdminUI.AddText=function(_,text) texts[#texts+1]=text end
AdminUI.AddButton=function(_,label) labels[label]=true end
AdminUI.OpenPage=function(key) AdminUI.currentPage=key; AdminUI.openSequence=AdminUI.openSequence+1 end
item.name='weapon_repeater_carbine'; item.metadata.weaponDefinitionId='repeater_carbine'; item.metadata.serialNumber='SERIAL'
AdminInventory.target={serverId=5}; AdminInventory.selected=item
dofile('client/ui/pages/inventory.lua')
AdminUI.OpenInventoryInstanceDetails()
assert(labels[AdminTranslate('evidence_manage')],'own firearm details offer evidence inspection')
item.revision=19; item.metadata.condition=100; item.metadata.maintenance={dirt=0.2,damage=0,permanentDegradation=0,degradation=0,soot=0}
item.metadata.attachments={{slot='sight',definitionId='wide_sight'}}
local originalMetadata=item.metadata
AdminUI.OpenInventoryInstanceDetails()
local summary=table.concat(texts,'\n')
assert(summary:find('Revision: 19',1,true) and summary:find('Condition: 100.0%',1,true)
 and summary:find('Dirt: 20.0%',1,true) and summary:find('wide_sight',1,true))
assert(labels[AdminTranslate('view_raw_metadata')] and not summary:find('Metadata:',1,true),'raw JSON is not the default detail body')
json.encode=function() return string.rep('é',1000) end
AdminUI.OpenInventoryRawMetadata(1)
assert(labels[AdminTranslate('next_page')],'large raw display is paginated')
for line in texts[3]:gmatch('[^\n]+') do assert(utf8.len(line)<=42,'raw text wraps without splitting UTF-8') end
assert(item.metadata==originalMetadata and item.revision==19,'presentation never mutates the source item')
AdminInventory.evidence={allowed=true,operation='hold',serialNumber='SERIAL',itemRevision=17,evidence=false}
AdminUI.OpenEvidenceConfirmation()
assert(labels[AdminTranslate('evidence_confirm_hold')],'explicit hold confirmation present')
AdminInventory.evidence={allowed=false,message='evidence_unresolved'}
AdminUI.OpenEvidenceConfirmation()
assert(not labels[AdminTranslate('evidence_confirm_hold')] and not labels[AdminTranslate('evidence_confirm_release')],
 'unknown result page cannot offer mutation/retry')
print('Admin evidence client PASS (trusted results, exact preview, one pending/no payload metadata, unknown no retry, closed-menu/target lifetime)')
