local registered = false
local function register()
    if registered or GetResourceState('feather-chat') ~= 'started' then return end
    local health = exports['feather-chat']:GetHealth()
    if not health.ok or health.value.state ~= 'ready' then return end
    local providerName = 'feather-admin.command-suggestions'
    local provider = exports['feather-chat']:RegisterChannelAccessProvider(providerName, {
        CanView = function(request)
            local source = request.actor and request.actor.source
            return { ok=true, value={ allowed=source ~= nil and FeatherAdmin.CanUse(source, 'menu.open') } }
        end
    })
    if not provider.ok and provider.code ~= 'conflict' then return end
    local definitions = {}
    if Config.commands.enabled then
        definitions[#definitions + 1] = { key='feather-admin.menu', trigger='/' .. Config.commands.openMenu,
            description='Open the staff administration menu', descriptionKey='chat_suggestion_menu', accessProvider=providerName }
    end
    if Config.reports.enabled ~= false then
        definitions[#definitions + 1] = { key='feather-admin.report', trigger='/' .. (Config.reports.command or 'report'),
            description='Send a report to the server staff', descriptionKey='chat_suggestion_report' }
    end
    for _, definition in ipairs(definitions) do
        local result = exports['feather-chat']:RegisterSuggestion(definition)
        if not result.ok and result.code ~= 'conflict' then
            print(AdminServerTranslate('chat_suggestion_registration_failed') .. ' code=' .. tostring(result.code)); return
        end
    end
    registered = true
end
AddEventHandler('chat.ready.v1', register)
AddEventHandler('onResourceStop', function(resource) if resource == 'feather-chat' then registered = false end end)
CreateThread(register)
