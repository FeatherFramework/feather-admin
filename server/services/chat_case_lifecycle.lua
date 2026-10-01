-- Core emits these locally on the server, not from client-supplied events.
-- Clear presentation on leaving AND ready so character/account transitions
-- cannot retain prior staff history, drafts or unread hints.
local function reset(session)
    if type(session) ~= 'table' or type(session.source) ~= 'number' then return end
    TriggerClientEvent('feather-admin:conversation:reset', session.source)
end
AddEventHandler('core.session.leaving.v1', reset)
AddEventHandler('core.session.ready.v1', reset)
