-- Validate actual Admin layout definitions against the real Menu contract.
dofile('../feather-menu-v2/client/results.lua'); dofile('../feather-menu-v2/client/validation.lua')
dofile('../feather-weather/config.lua'); dofile('../feather-weather/shared/contract.lua'); dofile('../feather-weather/server/engine.lua')
local elements={}
local provider=setmetatable({}, {__index=function(_,method)
    return function(_,...)
        local args={...}
        if method=='CreateMenu' then return {ok=true,value={menuId='weather-menu'}} end
        if method=='CreatePage' then return {ok=true,value={pageId=args[2].key}} end
        if method=='AddElement' then
            local problem=MenuValidation.Element(args[3],args[4]); assert(not problem,problem and problem.message)
            elements[#elements+1]={kind=args[3],spec=args[4],callback=args[5]}
            return {ok=true,value={elementId=#elements}}
        end
        return {ok=true,value={}}
    end
end})
exports={['feather-menu-v2']=provider}
function AddEventHandler() end
function GetCurrentResourceName() return 'feather-admin' end
function AdminTranslate(key) return key end
function CreateThread() end
AdminPermissions={['weather.view']=true,['weather.clock']=true,['weather.weather']=true,
    ['weather.wind']=true,['weather.seasons']=true,['weather.reset']=true}
dofile('client/ui/menu.lua'); AdminUI.RegisterNavigationItem=function() end
local engine=WeatherEngine.New(WeatherConfig,'layout',function() return 100 end).value
AdminWeather={state=engine:Snapshot(),forecast=engine:Forecast().value}
dofile('client/ui/pages/weather.lua')
AdminUI.OpenWeather()
local paths,forecastLabels,controlRows={},0,{}
for _,element in ipairs(elements) do
    if element.kind=='imagebox' then
        assert(element.spec.height=='4rem' and element.spec.objectFit=='contain')
        assert(element.spec.image:find('/web/weather/clear.svg',1,true))
    end
    if element.kind=='textdisplay' and element.spec.value=='weather_expected_in' then
        assert(element.spec.row); forecastLabels=forecastLabels+1
    end
    if element.kind=='button' and element.spec.row then
        controlRows[element.spec.row]=(controlRows[element.spec.row] or 0)+1
    end
end
assert(forecastLabels==1)
local rows=0; for _,count in pairs(controlRows) do assert(count==2); rows=rows+1 end; assert(rows==3)
for name in pairs(Weather.types) do
    elements={}; AdminWeather.state.weather.name=name; AdminUI.OpenWeather()
    for _,element in ipairs(elements) do
        if element.kind=='imagebox' then
            local path=assert(element.spec.image:match('/(web/weather/[%w]+%.svg)$'))
            paths[path]=true
            local file=assert(io.open(path)); local data=file:read('*a'); file:close()
            assert(data:find('viewBox="0 0 128 64"',1,true) and not data:find('<script',1,true))
        end
    end
end
local total=0; for _ in pairs(paths) do total=total+1 end; assert(total==7)
print('Weather layout PASS (real Menu validation, compact image sizing, table rows, paired controls, all weather types map to seven local SVGs).')
