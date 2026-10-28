local function T(key) return AdminTranslate('weather_'..key) end
local art={
    sunny='clear',highpressure='clear',clouds='clouds',overcast='clouds',overcastdark='clouds',
    rain='rain',drizzle='rain',shower='rain',thunder='storm',thunderstorm='storm',hurricane='storm',
    snow='snow',snowlight='snow',blizzard='snow',groundblizzard='snow',whiteout='snow',sleet='snow',hail='storm',
    fog='fog',misty='fog',sandstorm='sandstorm'
}
local function weatherName(name)
    return name:sub(1,1):upper()..name:sub(2)
end
local function arrival(forecast,entry)
    if forecast.paused then return T('forecast_paused') end
    local seconds=entry.dueRealSeconds
    if not seconds then return T('forecast_unknown') end
    seconds=math.max(0,math.floor(seconds))
    return ('%dm %02ds'):format(math.floor(seconds/60),seconds%60)
end
local function forecastRows(page,forecast,limit)
    AdminUI.BeginRow(page)
    AdminUI.AddText(page,T('condition'))
    AdminUI.AddText(page,T('expected_in'))
    AdminUI.EndRow(page)
    local entries=forecast.entries or {}
    for index=1,math.min(limit or #entries,#entries) do
        AdminUI.BeginRow(page)
        AdminUI.AddText(page,weatherName(entries[index].name))
        AdminUI.AddText(page,arrival(forecast,entries[index]))
        AdminUI.EndRow(page)
    end
    if #entries==0 then AdminUI.AddText(page,T('forecast_empty')) end
end
local function choice(page,label,values,current,set)
    local options,index={},0
    for i,value in ipairs(values) do
        options[i]={value=value,display=tostring(value)}
        if current==value then index=i-1 end
    end
    AdminUI.AddArrows(page,label,options,index,function(data) set(data.value.value) end)
end
local function toggle(page,label,current,set)
    AdminUI.AddArrows(page,label,{{value=false,display=T('off')},{value=true,display=T('on')}},current and 1 or 0,
        function(data) set(data.value.value) end)
end
local function input(page,label,value,set)
    AdminUI.AddInput(page,label,'',function(data) set(tonumber(data.value)) end,tostring(value))
end
local function footer(page,back)
    AdminUI.AddFooter(page)
    AdminUI.AddFooterButton(page,AdminTranslate('back'),back)
end
local function openForecast()
    if not AdminUI.CanUse('weather.view') then return AdminUI.NotifyActionDenied() end
    local page=AdminUI.RegisterPage('weather_forecast')
    AdminUI.AddHeader(page,T('title'),T('forecast'))
    if AdminWeather.forecast then forecastRows(page,AdminWeather.forecast) end
    AdminUI.AddText(page,T('snapshot_help'))
    footer(page,AdminUI.OpenWeather)
    AdminUI.OpenPage('weather_forecast')
end
local function send(action,spec)
    if not AdminWeather.Request(action,spec) then Feather.Notify.RightNotify(T('busy'),2500) end
end
local function confirm(action,spec,summary)
    local page=AdminUI.RegisterPage('weather_confirm')
    AdminUI.AddHeader(page,T('title'),T('confirm'))
    AdminUI.AddText(page,summary..'\n'..T('global_warning'))
    AdminUI.AddButton(page,T('apply'),function() send(action,spec) end)
    footer(page,AdminUI.OpenWeather)
    AdminUI.OpenPage('weather_confirm')
end
local function edit(action)
    local permission=action=='windControl' and 'wind' or action=='season' and 'seasons' or action
    if not AdminUI.CanUse('weather.'..permission) then return AdminUI.NotifyActionDenied() end
    local state=AdminWeather.state
    if not state then return end
    local page=AdminUI.RegisterPage('weather_edit')
    AdminUI.AddHeader(page,T('title'),T(permission))
    local spec,control={},{ }
    if action=='clock' then
        local hour=math.floor(state.clock.seconds/3600)%24
        local minute=math.floor(state.clock.seconds/60)%60
        spec={mode=state.clock.mode,rate=state.clock.rate,frozen=state.clock.frozen,offsetSeconds=state.clock.offsetSeconds}
        choice(page,T('mode'),{'simulated','wall'},spec.mode,function(v) spec.mode=v end)
        input(page,T('hour'),hour,function(v) hour=v end)
        input(page,T('minute'),minute,function(v) minute=v end)
        input(page,T('rate'),spec.rate,function(v) spec.rate=v end)
        input(page,T('offset'),spec.offsetSeconds,function(v) spec.offsetSeconds=v end)
        toggle(page,T('frozen'),spec.frozen,function(v) spec.frozen=v end)
        AdminUI.AddText(page,T('clock_help'))
        AdminUI.AddButton(page,T('continue'),function()
            if not hour or not minute or hour%1~=0 or minute%1~=0 or hour<0 or hour>23 or minute<0 or minute>59
                or spec.rate==nil or spec.offsetSeconds==nil then return Feather.Notify.RightNotify(T('invalid'),3000) end
            spec.seconds=hour*3600+minute*60
            confirm(action,spec,('%s: %02d:%02d, %s, x%s'):format(T('clock'),hour,minute,spec.mode,spec.rate))
        end)
    elseif action=='weather' then
        spec={name=state.weather.name,transitionSeconds=state.weather.transitionSeconds,frozen=state.weather.frozen,snow=state.weather.snow}
        local types={}
        for name in ('blizzard clouds drizzle fog groundblizzard hail highpressure hurricane misty overcast overcastdark rain sandstorm shower sleet snow snowlight sunny thunder thunderstorm whiteout'):gmatch('%S+') do types[#types+1]=name end
        choice(page,T('weather'),types,spec.name,function(v) spec.name=v end)
        input(page,T('transition'),spec.transitionSeconds,function(v) spec.transitionSeconds=v end)
        toggle(page,T('frozen'),spec.frozen,function(v) spec.frozen=v end)
        toggle(page,T('coverage'),spec.snow,function(v) spec.snow=v end)
        AdminUI.AddText(page,T('weather_help'))
        AdminUI.AddButton(page,T('continue'),function()
            if spec.transitionSeconds==nil then return Feather.Notify.RightNotify(T('invalid'),3000) end
            confirm(action,spec,T('weather')..': '..spec.name)
        end)
    elseif action=='wind' then
        spec={direction=state.wind.direction,speed=state.wind.speed}
        input(page,T('direction'),spec.direction,function(v) spec.direction=v end)
        input(page,T('speed'),spec.speed,function(v) spec.speed=v end)
        AdminUI.AddText(page,T('wind_help'))
        AdminUI.AddButton(page,T('continue'),function()
            if spec.direction==nil or spec.speed==nil then return Feather.Notify.RightNotify(T('invalid'),3000) end
            confirm(action,spec,('%s: %s°, %s'):format(T('wind'),spec.direction,spec.speed))
        end)
    elseif action=='windControl' then
        control=state.windControl or {automatic=false,frozen=false}
        spec={automatic=control.automatic,frozen=control.frozen}
        toggle(page,T('automatic'),spec.automatic,function(v) spec.automatic=v end)
        toggle(page,T('frozen'),spec.frozen,function(v) spec.frozen=v end)
        AdminUI.AddButton(page,T('continue'),function() confirm(action,spec,T('wind_controls')) end)
    elseif action=='season' then
        control=state.season or {name='spring',day=1,enabled=false,frozen=false}
        spec={name=control.name,day=control.day,enabled=control.enabled,frozen=control.frozen}
        choice(page,T('season'),{'spring','summer','autumn','winter'},spec.name,function(v) spec.name=v end)
        input(page,T('day'),spec.day,function(v) spec.day=v end)
        toggle(page,T('enabled'),spec.enabled,function(v) spec.enabled=v end)
        toggle(page,T('frozen'),spec.frozen,function(v) spec.frozen=v end)
        AdminUI.AddText(page,T('season_help'))
        AdminUI.AddButton(page,T('continue'),function()
            if spec.day==nil then return Feather.Notify.RightNotify(T('invalid'),3000) end
            confirm(action,spec,('%s: %s, %s %s'):format(T('season'),spec.name,T('day'),spec.day))
        end)
    end
    footer(page,AdminUI.OpenWeather)
    AdminUI.OpenPage('weather_edit')
end
function AdminUI.OpenWeather()
    if not AdminUI.CanUse('weather.view') then return AdminUI.NotifyActionDenied() end
    local page=AdminUI.RegisterPage('weather')
    AdminUI.AddHeader(page,AdminTranslate('admin_header'),T('title'))
    local state=AdminWeather.state
    if state then
        local clock,wind,s=state.clock,state.wind,state.season
        AdminUI.AddImage(page,('https://cfx-nui-%s/web/weather/%s.svg'):format(GetCurrentResourceName(),art[state.weather.name] or 'clouds'),
            weatherName(state.weather.name)..' · '..T('shared_conditions'),T('weather_art')..': '..weatherName(state.weather.name))
        AdminUI.AddText(page,('%s: %02d:%02d (%s, x%s)\n%s: %.1f°, %.1f'):format(
            T('clock'),math.floor(clock.seconds/3600)%24,math.floor(clock.seconds/60)%60,clock.mode,clock.rate,
            T('wind_current'),wind.direction,wind.speed))
        if s then AdminUI.AddText(page,('%s: %s · %s %d/%d'):format(T('season'),s.name,T('day'),s.day,s.daysPerSeason)) end
        local c=state.windControl
        if c then AdminUI.AddText(page,T('wind_controls')..': '..(c.automatic and T('automatic') or T('manual'))..(c.frozen and ' / '..T('frozen') or '')) end
        AdminUI.BeginSection(page,T('details'),false)
        AdminUI.AddText(page,('%s: %s / %s: %s\n%s: %s'):format(T('clock_frozen'),clock.frozen and T('on') or T('off'),
            T('weather_frozen'),state.weather.frozen and T('on') or T('off'),T('coverage'),state.weather.snow and T('on') or T('off')))
        if s then AdminUI.AddText(page,T('seasons')..': '..(s.enabled and T('on') or T('off'))..' / '..T('frozen')..': '..(s.frozen and T('on') or T('off'))) end
        AdminUI.AddText(page,T('snapshot_help'))
        AdminUI.EndSection(page)
        local forecast=AdminWeather.forecast
        if forecast then
            AdminUI.AddText(page,T('next_forecast'))
            forecastRows(page,forecast,3)
            if #(forecast.entries or {})>3 then AdminUI.AddButton(page,T('full_forecast'),openForecast) end
        end
        local buttons=0
        for _,action in ipairs({'clock','weather','wind','windControl','season'}) do
            local a=action
            local permission=a=='windControl' and 'wind' or a=='season' and 'seasons' or a
            if AdminUI.CanUse('weather.'..permission) then
                if buttons%2==0 then AdminUI.BeginRow(page) end
                AdminUI.AddButton(page,T(a=='windControl' and 'wind_controls' or permission),function() edit(a) end)
                buttons=buttons+1
                if buttons%2==0 then AdminUI.EndRow(page) end
            end
        end
        if AdminUI.CanUse('weather.reset') then
            if buttons%2==0 then AdminUI.BeginRow(page) end
            AdminUI.AddButton(page,T('reset'),function() confirm('reset',nil,T('reset_warning')) end)
            buttons=buttons+1
        end
        AdminUI.EndRow(page)
    else AdminUI.AddText(page,T('loading')) end
    AdminUI.AddButton(page,T('refresh'),function() send('read') end)
    footer(page,function() AdminUI.OpenNavigationSection('server_operations') end)
    AdminUI.OpenPage('weather')
    if not state and not AdminWeather.pending then send('read') end
end
AdminUI.RegisterNavigationItem('server_operations',{
    key='weather',labelKey='weather_title',order=25,permission='weather.view',
    open=function() AdminWeather.state=nil; AdminWeather.forecast=nil; AdminUI.OpenWeather() end
})
