RegisterCommand('AdminChatCaseFailureSmokeTest', function(source)
    if source ~= 0 then return end
    local tests = {}
    local function check(label, passed) tests[#tests + 1] = { label, passed == true } end
    local function success() return { ok = true, messageId = 'fixture' } end
    local function run(work, driver, ready)
        return AdminChatCaseStore.RunTransaction(work, { ready = ready ~= false, transaction = driver })
    end
    check('database unavailable fails closed', run(success, function() error('must not execute') end, false).code == 'unavailable')
    check('begin failure returns no success', run(success, function() error('synthetic begin failure') end).code == 'persistence_failed')
    check('commit failure returns no success', run(success, function(callback)
        callback({}); error('synthetic commit failure')
    end).code == 'persistence_failed')
    check('unconfirmed commit fails closed', run(success, function(callback)
        callback({}); return false
    end).code == 'persistence_failed')
    check('write exception fails closed', run(function() error('synthetic write failure') end,
        function(callback) return callback({}) end).code == 'persistence_failed')
    check('policy rollback preserves denial', run(function() return { ok = false, code = 'forbidden' } end,
        function(callback) return callback({}) end).code == 'forbidden')
    check('success exposed only after commit', run(success, function(callback)
        assert(callback({}) == true); return true
    end).ok == true)
    local attempts = 0
    local retried = run(function()
        attempts = attempts + 1
        return attempts == 1 and { ok = true } or { ok = false, code = 'session_stale' }
    end, function(callback)
        callback({})
        -- The same work may run again after a deadlock. Its latest outcome,
        -- not an earlier attempt, must determine what is exposed.
        return callback({})
    end)
    check('retry final denial replaces success', attempts == 2 and retried.code == 'session_stale')
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[AdminChatCaseFailureSmokeTest] %-40s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[AdminChatCaseFailureSmokeTest] done %d/%d passed (injected transaction failures; no database writes)'):format(passed, #tests))
end, true)
