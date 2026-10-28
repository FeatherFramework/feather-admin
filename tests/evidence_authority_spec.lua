local function run(existingOwnerEvidence,weatherUpgrade)
Config={}
dofile('configs/permissions.lua'); dofile('configs/authority_actions.lua')
assert(Config.permissions['weapons.evidence.hold']=='administrator' and Config.permissions['weapons.evidence.release']=='administrator')
local additions={['weapons.evidence.hold']=true,['weapons.evidence.release']=true}
if weatherUpgrade then
 additions={}
 for action in pairs(Config.permissions) do if action:find('weather.',1,true)==1 then additions[action]=true end end
end
local roles,byKey={},{}
local levels={moderator=1,administrator=2,owner=3}
for id,tier in ipairs(Config.authority.roles) do
 local role={id=id,key=tier.roleKey,grants={},revision=1}
 roles[id]=role; byKey[tier.roleKey]=role
 -- Model an already-provisioned 88-action server, with stable role IDs.
 for action,minimum in pairs(Config.permissions) do
  if (not additions[action] and levels[minimum]<=tier.precedence) or (existingOwnerEvidence and additions[action] and id==3) then
   role.grants[Config.authorityActions[action]]=true; role.revision=role.revision+1
  end
 end
end
if weatherUpgrade then
 assert(roles[1].revision==34 and roles[2].revision==68 and roles[3].revision==(existingOwnerEvidence and 97 or 91))
else
 assert(roles[1].revision==35 and roles[2].revision==72 and roles[3].revision==(existingOwnerEvidence and 97 or 95))
end
FeatherAdmin={}
local ready,grantCalls,registrations=nil,0,0
AdminDatabase={OnReady=function(fn) ready=fn end}
Wait=function() end
local policy
exports={['feather-authority']={
 AwaitReady=function() return {ok=true} end,
 RegisterCapabilities=function(_,request)
  registrations=registrations+1
  assert(request.requestId=='admin-authority-capabilities-006' and #request.capabilities==96)
  for _,entry in ipairs(request.capabilities) do
   if entry.key:find('weapons.evidence.',1,true) then assert(entry.riskClass=='high') end
  end
  return {ok=true,value={replayed=registrations>1}}
 end,
 CreateRole=function(_,request)
  assert(request.requestId:find('admin-authority-roles-002',1,true))
  return {ok=true,value={roleId=byKey[request.roleKey].id,replayed=true}}
 end,
 ListRoleGrants=function(_,request)
  local out={}; for key in pairs(roles[request.roleId].grants) do out[#out+1]={capabilityKey=key,status='active'} end
  return {ok=true,value=out}
 end,
 GetRole=function(_,request) return {ok=true,value={revision=roles[request.roleId].revision}} end,
 GrantRoleCapability=function(_,request)
  grantCalls=grantCalls+1
  assert(request.scopeType=='server' and request.requestId:find('admin-authority-grants-006',1,true))
  local action=request.capabilityKey:sub(#'staff.admin.'+1)
  assert(additions[action] and (request.roleId~=1 or action=='weather.view'))
  local role=roles[request.roleId]; assert(request.expectedRevision==role.revision and not role.grants[request.capabilityKey])
  role.grants[request.capabilityKey]=true; role.revision=role.revision+1
  return {ok=true,value={roleRevision=role.revision,replayed=false}}
 end},['feather-core']={RegisterPolicyProvider=function(_,name,implementation)
 assert(name=='feather-admin'); policy=implementation.Evaluate; return {ok=true}
end}}
dofile('server/services/authority_catalog.lua')
ready()
local result=FeatherAdmin.AuthorityCatalog.State().result
local expectedGrants=weatherUpgrade and (existingOwnerEvidence and 7 or 13) or (existingOwnerEvidence and 2 or 4)
assert(grantCalls==expectedGrants and result.capabilities==96 and result.owner==96 and result.totalGrants==203)
assert(result.moderator==34 and result.administrator==73)
ready()
assert(grantCalls==expectedGrants and FeatherAdmin.AuthorityCatalog.State().result.replayed,'restart cannot duplicate grants')
local enabled=true
FeatherAdmin.IsActionEnabled=function() return enabled end
FeatherAdmin.CanUse=function(src,action) return roles[src] and roles[src].grants[Config.authorityActions[action]]==true or false end
RegisterCommand=function() end
dofile('server/services/policy_provider.lua')
for action in pairs(additions) do
 assert(policy(action,{source=3}).value.allowed)
 assert(policy(action,{source=1}).value.allowed==(action=='weather.view') and policy(action,{source=2}).value.allowed)
 assert(not policy(action,{source=0}).value.allowed,'console/service is not an implicit grant')
 enabled=false; assert(not policy(action,{source=3}).value.allowed); enabled=true
end
end
run(false); run(true)
run(false,true); run(true,true)
print('Admin Authority PASS (evidence and 90-to-96 weather upgrades, reviewed view/mutation tiers, stable roles and replay; mocked Authority)')
