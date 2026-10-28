AdminWeather={pending=nil,sequence=0,state=nil,forecast=nil}
function AdminWeather.Request(action,spec)
    if AdminWeather.pending then return false end
    AdminWeather.sequence=AdminWeather.sequence%2147483647+1
    local id=AdminWeather.sequence
    AdminWeather.pending=id
    Feather.RPC.Notify('feather-admin:weather:request',{id=id,action=action,spec=spec})
    CreateThread(function()
        Wait(10000)
        if AdminWeather.pending==id then
            AdminWeather.pending=nil
            Feather.Notify.RightNotify(AdminTranslate('weather_timeout'),3500)
        end
    end)
    return true
end
RegisterNetEvent('feather-admin:weather:result',function(id,result)
    if source~=65535 or id~=AdminWeather.pending then return end
    AdminWeather.pending=nil
    if type(result)~='table' or result.ok~=true then
        local message=type(result)=='table' and result.message
        Feather.Notify.RightNotify(type(message)=='string' and message or AdminTranslate('weather_unavailable'),4000)
        return
    end
    if type(result.value)=='table' and result.value.state then
        AdminWeather.state,AdminWeather.forecast=result.value.state,result.value.forecast
    else
        AdminWeather.state=result.value
        AdminWeather.forecast=nil
        Feather.Notify.RightNotify(AdminTranslate('weather_applied'),3000)
    end
    if InMenu and (AdminUI.currentPage=='weather' or AdminUI.currentPage=='weather_confirm') then AdminUI.OpenWeather() end
end)
