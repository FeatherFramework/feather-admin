local commands,requests={},{}
local flag,clock,target=0,0,5
exports={['feather-toolkit']={ResolveControl=function() return {ok=true,value=0} end}}
RegisterCommand=function(name,fn) commands[name]=fn end
RegisterNetEvent=function() end
AddEventHandler=function() end
GetConvarInt=function(name,default) assert(name=='feather_admin_dev_selfkill' and default==0); return flag end
GetGameTimer=function() return clock end
PlayerId=function() return 1 end
GetPlayerServerId=function(id) assert(id==1); return target end
Feather={RPC={Notify=function(name,params)
 assert(name=='feather-admin:booster:request' and params.action=='kill' and params.playerId==5)
 requests[#requests+1]=params
end}}
SetEntityHealth=function() error('command must not bypass server with native health writes') end
dofile('client/services/boosters.lua')
local run=commands.AdminDevKillSelf
run(0,{}); assert(#requests==0)
flag=1
run(0,{'99'}); assert(#requests==0)
target=0; run(0,{}); assert(#requests==0)
target=5; run(0,{}); assert(#requests==1)
run(0,{}); assert(#requests==1)
clock=2000; run(0,{}); assert(#requests==2)
flag=0; clock=4000; run(0,{}); assert(#requests==2)
flag=2; run(0,{}); assert(#requests==2,'only explicit flag1 enables helper')
flag=1; target=5.5; run(0,{}); assert(#requests==2,'fractional target refused')
target=5; clock=4294967280; run(0,{}); assert(#requests==3)
clock=1000; run(0,{}); assert(#requests==3,'timer wrap must retain cooldown')
clock=1984; run(0,{}); assert(#requests==4,'timer wrap permits request at two seconds')
print('Admin dev self-Kill PASS (disabled default, self only, cooldown, existing RPC, no native bypass)')
