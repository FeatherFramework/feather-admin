local function run(existingOwnerEvidence)
Config={}
dofile('configs/permissions.lua'); dofile('configs/authority_actions.lua')
assert(Config.permissions['weapons.evidence.hold']=='administrator' and Config.permissions['weapons.evidence.release']=='administrator')
local additions={['weapons.evidence.hold']=true,['weapons.evidence.release']=true}
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
assert(roles[1].revision==34 and roles[2].revision==66 and roles[3].revision==(existingOwnerEvidence and 91 or 89))
FeatherAdmin={}
local ready,grantCalls,registrations=nil,0,0
AdminDatabase={OnReady=function(fn) ready=fn end}
Wait=function() end
local policy
exports={['feather-authority']={
 AwaitReady=function() return {ok=true} end,
 RegisterCapabilities=function(_,request)
  registrations=registrations+1
  assert(request.requestId=='admin-authority-capabilities-005' and #request.capabilities==90)
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
  assert((request.roleId==2 or request.roleId==3) and request.scopeType=='server' and request.requestId:find('admin-authority-grants-005',1,true))
  assert(request.capabilityKey=='staff.admin.weapons.evidence.hold' or request.capabilityKey=='staff.admin.weapons.evidence.release')
  local role=roles[request.roleId]; assert(request.expectedRevision==role.revision and not role.grants[request.capabilityKey])
  role.grants[request.capabilityKey]=true; role.revision=role.revision+1
  return {ok=true,value={roleRevision=role.revision,replayed=false}}
 end},['feather-core']={RegisterPolicyProvider=function(_,name,implementation)
 assert(name=='feather-admin'); policy=implementation.Evaluate; return {ok=true}
end}}
dofile('server/services/authority_catalog.lua')
ready()
local result=FeatherAdmin.AuthorityCatalog.State().result
local expectedGrants=existingOwnerEvidence and 2 or 4
assert(grantCalls==expectedGrants and result.capabilities==90 and result.owner==90 and result.totalGrants==190)
assert(result.moderator==33 and result.administrator==67)
ready()
assert(grantCalls==expectedGrants and FeatherAdmin.AuthorityCatalog.State().result.replayed,'restart cannot duplicate grants')
local enabled=true
FeatherAdmin.IsActionEnabled=function() return enabled end
FeatherAdmin.CanUse=function(src,action) return roles[src] and roles[src].grants[Config.authorityActions[action]]==true or false end
RegisterCommand=function() end
dofile('server/services/policy_provider.lua')
for action in pairs(additions) do
 assert(policy(action,{source=3}).value.allowed)
 assert(not policy(action,{source=1}).value.allowed and policy(action,{source=2}).value.allowed)
 assert(not policy(action,{source=0}).value.allowed,'console/service is not an implicit grant')
 enabled=false; assert(not policy(action,{source=3}).value.allowed); enabled=true
end
end
run(false); run(true)
print('Admin evidence authority PASS (88/90 catalog upgrades, administrator+owner only, stable roles/replay, high risk, moderator/service/disabled denied; mocked Authority)')
