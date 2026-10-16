local rpc,events,timers={},{},{}
local messages,changes,audits={},0,0
local sid,allowed,enabled,unknown='s',true,true,false
local revision,evidence=17,false
Config={}
GetGameTimer=function() return 0 end
GetResourceState=function() return 'started' end
Wait=function() end
CreateThread=function(fn) fn() end
AddEventHandler=function(name,fn) events[name]=fn end
SetTimeout=function(_,fn) timers[#timers+1]=fn end
GetPlayerName=function(id) return id==5 and 'Jane' or id==6 and 'Other' or nil end
DB={one=function() return nil end}
TriggerClientEvent=function(name,src,id,phase,ok,key,value)
 assert(name=='feather-admin:inventory:evidence:result' and src==5)
 messages[#messages+1]={id=id,phase=phase,ok=ok,key=key,value=value}
end
FeatherAdmin={RegisterRPC=function(name,fn) rpc[name]=fn end,
 CanUse=function(_,action) return action=='inventory.inspect' or allowed end,
 CheckTargetAccountHierarchy=function() return true end,
 Identity={Resolve=function(id) return {accountId=id==5 and 'a' or 'other',characterId=id==5 and 'Jane' or 'Other',sessionId=sid} end}}
AdminAudit={RecordTarget=function() audits=audits+1 end}
local api={GetCapabilities=function() return {ok=true,value={contractVersion=4,features={characterInventoryLookup=true,adminExactRemoval=true}}} end}
exports={['feather-inventory']={AwaitReady=function() return {ok=true} end,initiate=function() return api end},
 ['feather-core']={IsSessionCurrent=function(_,src,s,c) return src==5 and s==sid and c=='Jane' end},
 ['feather-weapons']={ReadNativeEvidenceStatus=function(_,src,itemId)
 assert(src==5 and itemId==135)
 return {ok=true,value={identity={sessionId=sid,characterId='Jane'},itemRevision=revision,serialNumber='SERIAL',
  evidence=evidence,enabled=enabled,equipped=false,nativeBound=false,reservation='none',permissions={hold=true,release=true}}}
 end,
 HoldWeaponEvidence=function(_,request,context)
 changes=changes+1
 assert(request.characterId=='Jane' and request.itemInstanceId==135 and request.serialNumber=='SERIAL'
  and request.expectedRevision==revision and context.sessionId==sid and context.actorSource==5)
 if unknown then error('unknown acknowledgement') end
 revision=revision+1; evidence=true
 return {ok=true,value={revision=revision,provenancePersisted=true}}
 end}}
dofile('server/services/inventory.lua')
local preview=rpc['feather-admin:inventory:evidence-status']
local change=rpc['feather-admin:inventory:evidence-change']
local function open(id,target)
 preview({requestId=id,serverId=target or 5,instanceId=135},nil,5)
 return messages[#messages]
end
local function submit(ticket,operation)
 change({requestId='change',serverId=5,ticket=ticket,operation=operation or 'hold'},nil,5)
 return messages[#messages]
end
assert(not open('foreign',6).ok and changes==0,'cross-owner preview refused')
enabled=false
local status=open('off'); assert(status.ok and not status.value.allowed)
assert(not submit(status.value.ticket).ok and changes==0,'disabled preview cannot be used to mutate')
enabled=true; status=open('available'); assert(status.ok and status.value.allowed)
assert(not submit('forged').ok and changes==0)
status=open('success')
local result=submit(status.value.ticket)
assert(result.ok and result.key=='evidence_committed' and changes==1 and audits==1 and revision==18)
assert(not submit(status.value.ticket).ok and changes==1,'one-use ticket prevents repeat commit')
evidence=false
status=open('lost-role'); allowed=false
assert(not submit(status.value.ticket).ok and changes==1,'permission rechecked on confirmation')
allowed=true; status=open('lost-session'); sid='new'
assert(not submit(status.value.ticket).ok and changes==1,'session bound confirmation')
status=open('expired'); timers[#timers]()
local expired=submit(status.value.ticket)
assert(not expired.ok and expired.key=='evidence_preview_expired' and changes==1,'expired preview cannot commit')
status=open('unknown'); unknown=true
assert(submit(status.value.ticket).key=='evidence_unresolved' and changes==2 and audits==1)
assert(not submit(status.value.ticket).ok and changes==2,'unknown result cannot repeat consumed ticket')
print('Admin evidence server PASS (own scope/optin preview, exact one-use ticket, current permissions/session, expiry, audit, unknown no replay; mocked Weapons)')
