RegisterCommand('AdminChatCaseAdapterSmokeTest', function(source)
    if source ~= 0 then return end
    local account = '00000000-0000-4000-8000-000000000001'
    local target = '00000000-0000-4000-8000-000000000002'
    local identity = { accountId = account, sessionId = 'session-A', characterId = 'character-A' }
    local grants, session, hierarchy = true, true, true
    local deps = {
        resolve = function() return identity end,
        current = function() return session end,
        permitted = function() return grants end,
        hierarchy = function() return hierarchy end
    }
    local tests = {}
    local function check(label, passed) tests[#tests + 1] = { label, passed == true } end
    local actor, refresh = AdminChatCaseAdapter.Actor(1, target, 'create', deps)
    check('server staff creation allowed', actor ~= nil and actor.accountId == account)
    grants = false
    check('revoked grants fail revalidation', not refresh())
    check('ordinary player cannot initiate', AdminChatCaseAdapter.Actor(1, target, 'create', deps) == nil)
    identity.accountId = target
    actor, refresh = AdminChatCaseAdapter.Actor(1, target, 'read', deps)
    check('target read needs no staff grant', actor ~= nil)
    identity.sessionId = 'session-B'
    check('replaced session denied', not refresh())
    identity.accountId, grants = account, true
    hierarchy = false
    check('staff hierarchy denied', AdminChatCaseAdapter.Actor(1, target, 'close', deps) == nil)
    hierarchy, session = true, false
    check('stale staff denied', AdminChatCaseAdapter.Actor(1, target, 'create', deps) == nil)
    session = true
    actor, refresh = AdminChatCaseAdapter.Actor(1, target, 'read', deps)
    identity.accountId = target
    check('source account reuse denied', not refresh())
    check('invalid target denied', AdminChatCaseAdapter.Actor(1, 'spoof', 'read', deps) == nil)
    identity.accountId, grants = account, true
    actor, refresh = AdminChatCaseAdapter.Actor(1, target, 'reply', deps)
    check('authorized staff reply allowed', actor ~= nil)
    grants = false
    check('revoked reply grant denied', not refresh())
    identity.accountId = target
    check('target reply needs no staff grant', AdminChatCaseAdapter.Actor(1, target, 'reply', deps) ~= nil)
    local calls = 0
    deps.permitted = function() calls = calls + 1; error('target must not query staff permissions') end
    deps.hierarchy = function() error('target must not query hierarchy') end
    check('target skips staff database work', AdminChatCaseAdapter.Actor(1, target, 'read', deps) ~= nil and calls == 0)
    identity.accountId = account
    deps.hierarchy = function() return true end
    deps.grants = function() calls = calls + 1; return { ['cases.view'] = true, ['cases.claim'] = true } end
    calls = 0
    check('staff grants fetched once per check', AdminChatCaseAdapter.Actor(1, target, 'reply', deps) ~= nil and calls == 1)
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminChatCaseAdapterSmokeTest] %-36s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminChatCaseAdapterSmokeTest] done %d/%d passed (injected identity/policy; no database writes)'):format(passed, #tests))
end, true)
