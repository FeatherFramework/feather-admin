dofile('../feather-weather/config.lua'); dofile('../feather-weather/shared/contract.lua'); dofile('../feather-weather/server/engine.lua')
local W=Weather
local engine=assert(WeatherEngine.New(WeatherConfig,'admin',function() return 100 end).value)
local rpc,options,reply,event,recipient
local writes,audits=0,0
local running,admin=true,true
FeatherAdmin={
    RegisterRPC=function(_,fn,opts) rpc,options=fn,opts end,
    RequirePermission=function(_,permission) return admin or permission=='weather.view' end
}
AdminAudit={Record=function(_,permission) assert(permission:find('weather.',1,true)==1); audits=audits+1 end}
function GetResourceState() return running and 'started' or 'stopped' end
function TriggerClientEvent(name,src,id,result) event,recipient,reply=name,src,result end
local provider={GetState=function() return W.Ok(engine:Snapshot()) end,GetForecast=function() return engine:Forecast() end}
for name,action in pairs({SetClock='clock',SetWeather='weather',SetWind='wind',SetWindControl='windControl',SetSeason='season',ResetEnvironment='reset'}) do
    local method=action
    provider[name]=function(_,spec) writes=writes+1; return engine:Mutate(method,spec) end
end
exports={['feather-weather']=provider}
dofile('server/services/weather.lua')
assert(options.maxCalls==3 and options.maxPayloadBytes==1024)
local function call(action,spec,extra)
    reply=nil; local p={id=1,action=action,spec=spec}; if extra then p.unexpected=true end
    rpc(p,nil,5); assert(event=='feather-admin:weather:result' and recipient==5); return reply
end
assert(call('read').ok)
admin=false
assert(call('read').ok)
assert(not call('weather',{name='hurricane'}).ok); assert(writes==0 and audits==0)
assert(not call('season',{name='winter'}).ok); assert(writes==0)
admin=true
assert(not call('unknown',{}).ok and writes==0)
assert(not call('wind',{speed=4},true).ok and writes==0)
assert(not call('wind','bad').ok and writes==0)
local rev=engine.revision
assert(not call('weather',{name='nonsense'}).ok and engine.revision==rev and audits==0)
assert(call('wind',{direction=90,speed=4}).ok and audits==1 and not engine.windControl.automatic)
assert(call('windControl',{automatic=true}).ok and engine.windControl.automatic)
assert(call('season',{name='winter',day=2}).ok and engine.season.name=='winter')
assert(call('clock',{rate=60}).ok and engine.clock.rate==60)
assert(call('weather',{name='snow',frozen=true}).ok and engine.weather.name=='snow')
assert(call('reset').ok and engine.season.name=='spring')
running=false; local before=writes; assert(not call('read').ok); assert(not call('wind',{speed=3}).ok and writes==before)
running=true
provider.GetState=function() error('provider restarting') end
assert(not call('read').ok)
print('Admin Weather server gates/provider failures and all six mutation routes passed.')

-- Client boundary, request correlation, timeout and menu composition.
local clientEvent,timeout,notifies={}, {},0
source=65535
function RegisterNetEvent(name,fn) clientEvent[name]=fn end
function CreateThread(fn) timeout[#timeout+1]=fn end
function Wait() end
Feather={RPC={Notify=function() end},Notify={RightNotify=function() notifies=notifies+1 end}}
function AdminTranslate(key) return key end
dofile('client/services/weather.lua')
assert(AdminWeather.Request('read')); assert(not AdminWeather.Request('read'))
source=1; clientEvent['feather-admin:weather:result'](1,{ok=true,value={state=engine:Snapshot()}})
assert(AdminWeather.pending==1 and AdminWeather.state==nil)
source=65535; clientEvent['feather-admin:weather:result'](2,{ok=true,value={}}); assert(AdminWeather.pending==1)
InMenu=false
clientEvent['feather-admin:weather:result'](1,{ok=true,value={state=engine:Snapshot()}})
assert(AdminWeather.pending==nil and AdminWeather.state)
assert(AdminWeather.Request('read')); timeout[#timeout](); assert(AdminWeather.pending==nil and notifies==1)
local pages,nav={},nil
function GetCurrentResourceName() return 'feather-admin' end
admin=false
AdminUI={
    CanUse=function(permission) return admin or permission=='weather.view' end,
    RegisterNavigationItem=function(_,item) nav=item end,
    RegisterPage=function(key) local p={key=key,buttons={},inputs={},arrows={}}; pages[key]=p; return p end,
    AddHeader=function() end,AddText=function() end,AddFooter=function() end,AddFooterButton=function() end,
    BeginSection=function(_,_,expanded) assert(expanded==false,'Weather details must start collapsed') end,
    EndSection=function() end,
    BeginRow=function(p) assert(not p.inRow); p.inRow=true end,
    EndRow=function(p) p.inRow=false end,
    AddImage=function(p,path) assert(path:match('^https://cfx%-nui%-feather%-admin/web/weather/[%w]+%.svg$')); p.image=path end,
    AddButton=function(p,label,fn) p.buttons[label]=fn end,
    AddInput=function(p,label,_,fn) p.inputs[label]=fn end,
    AddArrows=function(p,label,_,_,fn) p.arrows[label]=fn end,
    OpenPage=function(key) AdminUI.currentPage=key end,
    NotifyActionDenied=function() error('Unexpected UI denial') end
}
dofile('client/ui/pages/weather.lua')
assert(nav.permission=='weather.view'); AdminUI.OpenWeather()
assert(pages.weather.buttons.weather_refresh and not pages.weather.buttons.weather_clock)
assert(pages.weather.image:find('clear.svg',1,true))
AdminWeather.forecast={paused=false,entries={
    {name='rain',dueRealSeconds=120},{name='clouds',dueRealSeconds=240},
    {name='sunny',dueRealSeconds=360},{name='snow',dueRealSeconds=480}
}}
AdminUI.OpenWeather(); assert(pages.weather.buttons.weather_full_forecast)
pages.weather.buttons.weather_full_forecast(); assert(pages.weather_forecast and not pages.weather_forecast.inRow)
admin=true; AdminUI.OpenWeather()
assert(pages.weather.buttons.weather_clock and pages.weather.buttons.weather_seasons and pages.weather.buttons.weather_reset)
pages.weather.buttons.weather_seasons(); assert(pages.weather_edit.inputs.weather_day)
pages.weather_edit.buttons.weather_continue(); assert(pages.weather_confirm.buttons.weather_apply and AdminWeather.pending==nil)
pages.weather_confirm.buttons.weather_apply(); assert(AdminWeather.pending~=nil)
print('Admin Weather client source/correlation/timeout, view gates and confirmation flow passed.')
