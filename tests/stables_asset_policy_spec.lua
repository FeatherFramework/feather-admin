-- Run from feather-admin with Lua 5.4 (or the workspace's lupa runtime).
Config = {}
assert(loadfile('configs/service_policy.lua'))()
local evaluate
FeatherAdmin = { IsActionEnabled = function() return true end }
exports = { ['feather-core'] = {
    RegisterPolicyProvider = function(_, name, implementation)
        assert(name == 'feather-admin'); evaluate = implementation.Evaluate
        return { ok = true }
    end,
} }
RegisterCommand = function() end
assert(loadfile('server/services/policy_provider.lua'))()
local count=0
local function check(name, action, context, expected)
    local result=evaluate(action,context)
    assert(result.ok and result.value.allowed==expected,name)
    count=count+1
end
local function context(broker,principal)
    return {source=0,system=true,caller=broker,subject={resource=principal}}
end
check('Stables asset management allowed','assets.asset.manage',context('feather-assets','bcc-stables'),true)
check('Stables transfer denied','assets.ownership.transfer',context('feather-assets','bcc-stables'),false)
check('Wrong broker denied','assets.asset.manage',context('bcc-stables','bcc-stables'),false)
check('Unknown principal denied','assets.asset.manage',context('feather-assets','other'),false)
local forged=context('feather-assets','bcc-stables'); forged.characterId='forged'
check('Actor claims denied','assets.asset.manage',forged,false)
check('Unknown action denied','assets.unknown',context('feather-assets','bcc-stables'),false)
check('Existing fixture grants preserved','assets.ownership.transfer',context('feather-assets','feather-assets-access-tests'),true)
assert(Config.servicePolicy['feather-assets']['bcc-stables']['*']==nil)
print(('%d/%d Stables Assets policy cases passed; Core authentication is not modeled.'):format(count,count))

check('Stables buyback currency issue allowed','economy.currency.issue',context('feather-economy','bcc-stables'),true)
check('Stables currency destroy denied','economy.currency.destroy',context('feather-economy','bcc-stables'),false)
check('Wrong issuer broker denied','economy.currency.issue',context('bcc-stables','bcc-stables'),false)
Config.permissions={}
local player=context('feather-economy','bcc-stables');player.source=1;player.system=false
check('Client actor cannot use service issue grant','economy.currency.issue',player,false)
print('PASS Stables service payout scope; reason restriction belongs to Economy')
