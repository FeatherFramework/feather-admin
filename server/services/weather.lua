-- User-approved role grants: moderator reads; administrator/owner mutations.
-- Optional Weather consumer; every request is gated on the server.
local routes={
    clock={permission='weather.clock',method='SetClock'},
    weather={permission='weather.weather',method='SetWeather'},
    wind={permission='weather.wind',method='SetWind'},
    windControl={permission='weather.wind',method='SetWindControl'},
    season={permission='weather.seasons',method='SetSeason'},
    reset={permission='weather.reset',method='ResetEnvironment'}
}
local function result(src,id,value)
    TriggerClientEvent('feather-admin:weather:result',src,id,value)
end
local function provider(method,spec)
    if GetResourceState('feather-weather')~='started' then
        return {ok=false,code='unavailable',message='Feather Weather is not running.'}
    end
    local ok,value=pcall(function() return exports['feather-weather'][method](exports['feather-weather'],spec) end)
    if not ok or type(value)~='table' or type(value.ok)~='boolean' then
        return {ok=false,code='unavailable',message='Weather could not complete the request.'}
    end
    return value
end
FeatherAdmin.RegisterRPC('feather-admin:weather:request',function(params,_,src)
    local id=params.id
    if type(id)~='number' or id%1~=0 or id<1 or id>2147483647 then return end
    local action=params.action
    local route=type(action)=='string' and routes[action]
    if action~='read' and not route then
        return result(src,id,{ok=false,code='invalid_input',message='Unknown Weather action.'})
    end
    if not FeatherAdmin.RequirePermission(src,route and route.permission or 'weather.view') then
        return result(src,id,{ok=false,code='denied',message='Weather permission required.'})
    end
    for key in pairs(params) do
        if key~='id' and key~='action' and key~='spec' then
            return result(src,id,{ok=false,code='invalid_input',message='Unexpected request field.'})
        end
    end
    if action=='read' then
        if params.spec~=nil then return result(src,id,{ok=false,code='invalid_input',message='Read takes no input.'}) end
        local state=provider('GetState')
        if not state.ok then return result(src,id,state) end
        local forecast=provider('GetForecast')
        return result(src,id,{ok=true,value={state=state.value,forecast=forecast.ok and forecast.value or nil}})
    end
    if route.method~='ResetEnvironment' and type(params.spec)~='table' then
        return result(src,id,{ok=false,code='invalid_input',message='Expected settings.'})
    end
    local changed=provider(route.method,params.spec)
    if changed.ok then AdminAudit.Record(src,route.permission,nil,'Weather action: '..action) end
    result(src,id,changed)
end,{windowMs=2000,maxCalls=3,maxPayloadBytes=1024})
