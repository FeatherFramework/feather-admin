RegisterCommand('AdminLegacyCharacterCutoverSmokeTest', function(source)
    if source ~= 0 then return end

    local routesResult = exports['feather-core']:GetRpcRoutes()
    local routes = {}
    if type(routesResult) == 'table' and routesResult.ok == true then
        for _, route in ipairs(routesResult.value or {}) do routes[route.route] = true end
    end

    local disabled = Config.identity and Config.identity.disabledActionPrefixes or {}
    local disabledPrefixes = {}
    for _, prefix in ipairs(disabled) do disabledPrefixes[prefix] = true end

    local tests = {
        {
            name = 'legacy core object absent',
            passed = type(FeatherAdmin.Core) == 'table' and FeatherAdmin.Core.Character == nil
        },
        {
            name = 'legacy handlers removed',
            passed = LoadResourceFile(GetCurrentResourceName(), 'server/services/economy.lua') == nil
                and LoadResourceFile(GetCurrentResourceName(), 'server/services/staff_management.lua') == nil
        },
        {
            name = 'legacy routes absent',
            passed = routesResult and routesResult.ok == true
                and routes['feather-admin:economy:summary'] == nil
                and routes['feather-admin:economy:adjust'] == nil
                and routes['feather-admin:staff:list'] == nil
                and routes['feather-admin:staff:search'] == nil
                and routes['feather-admin:staff:history'] == nil
                and routes['feather-admin:staff:role:assign'] == nil
        },
        {
            name = 'dormant UI fails closed',
            passed = disabledPrefixes['economy.'] == true and disabledPrefixes['staff.'] == true
        }
    }

    local passed = 0
    for _, test in ipairs(tests) do
        if test.passed then passed = passed + 1 end
        print(('[AdminLegacyCharacterCutoverSmokeTest] %-27s %s')
            :format(test.name, test.passed and 'PASS' or 'FAIL'))
    end
    print(('[AdminLegacyCharacterCutoverSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)
