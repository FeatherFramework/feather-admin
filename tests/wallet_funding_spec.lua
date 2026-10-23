local count=0
local function test(name,fn) fn(); count=count+1; print('PASS wallet '..name) end
local CHAR='20000000-0000-4000-8000-000000000002'
local ACCOUNT='30000000-0000-4000-8000-000000000003'
local ACTOR='40000000-0000-4000-8000-000000000004'
local function fixture()
    local env=setmetatable({}, {__index=_G})
    local m={commands={},routes={},events={},logs={},receipts={},issues=0,audits={},current=true,allowed=true,hierarchy=true}
    env.Config={walletFunding={maxBaseUnits=1000000,currencies={dollars=true}}}
    local encoded,serial={},0
    env.json={encode=function(v) serial=serial+1; encoded[tostring(serial)]=v; return tostring(serial) end}
    env.print=function(v) local id=v:match('^%[AdminWalletIssue%] (.+)$'); if id then m.logs[#m.logs+1]=encoded[id] end end
    env.GetResourceState=function() return m.stopped and 'stopped' or 'started' end
    env.RegisterCommand=function(name,fn) m.commands[name]=fn end
    env.CreateThread=function(fn) fn() end
    env.TriggerClientEvent=function(name,src,value) m.events[#m.events+1]={name=name,source=src,value=value} end
    env.AdminAudit={RecordTarget=function(src,action,target,details)
        m.audits[#m.audits+1]={source=src,action=action,target=target,details=details}
        if m.onAudit then m.onAudit(action) end
        return not m.auditDown and 'audit:1' or nil
    end}
    env.FeatherAdmin={RegisterRPC=function(name,fn) m.routes[name]=fn end,
        RequirePermission=function(src,action) assert(action=='economy.dollars.add'); return m.allowed end,
        CanUse=function() return m.allowed end,CheckTargetAccountHierarchy=function() return m.hierarchy end}
    local function session(src)
        return {ok=true,value={source=src,accountId=ACCOUNT,characterId=src==17 and ACTOR or CHAR,sessionId='session:'..src}}
    end
    env.exports={['feather-core']={
        RequireSession=function(_,src) return session(src) end,
        IsSessionCurrent=function() return m.current end,
        GetProvider=function() return {ok=true,value={implementation={GetIdentity=setmetatable({__cfx_functionReference='identity'},{__call=function(_,id)
            return {ok=true,value={characterId=id,accountId=ACCOUNT,status=m.inactive and 'deleted' or 'active'}}
        end})}}} end,
    },['feather-economy']={
        GetHealth=function() return {ok=true,value={state='ready'}} end,
        GetCapabilities=function() return {ok=true,value={resource='feather-economy',contract=1,features={supplyOperations=1,idempotency=1}}} end,
        GetCurrency=function() return {ok=true,value={code='dollars',precision=2}} end,
        FindAccountsByOwner=function(_,req)
            return {ok=true,value=m.noWallet and {} or {{accountId=ACCOUNT,ownerType='character',ownerId=req.ownerId,
                accountType='wallet',currency='dollars',status='open',balance=123}}}
        end,
        Issue=function(_,req,context)
            m.lastRequest=req; m.context=context
            if m.deny then return {ok=false,code='authorization_denied',message='Denied.'} end
            local existing=m.receipts[req.idempotencyKey]
            if existing then
                if existing.amount~=req.amount or existing.toAccountId~=req.accountId then
                    return {ok=false,code='idempotency_conflict',message='Changed terms.'}
                end
                local result={}; for k,v in pairs(existing) do result[k]=v end; result.replayed=true
                return {ok=true,value=result}
            end
            m.issues=m.issues+1
            local receipt={transactionId='50000000-0000-4000-8000-000000000005',operation='issue',sourceResource='feather-admin',
                toAccountId=req.accountId,currency=req.currency,amount=req.amount,reasonCode=req.reasonCode,
                referenceType=req.referenceType,referenceId=req.referenceId,replayed=false}
            m.receipts[req.idempotencyKey]=receipt
            if m.lostReply then error('Committed reply lost') end
            return {ok=true,value=receipt}
        end,
    }}
    assert(loadfile('server/services/wallet_funding.lua','t',env))()
    m.command=function(amount,key,source)
        m.commands.AdminWalletIssue(source or 0,{CHAR,'dollars',amount or '1',key or 'proof-fund-1','Stables test funding'})
        return m.logs[#m.logs]
    end
    m.adjust=function(value,key,extra)
        local p={playerId=18,characterId=CHAR,field='dollars',operation='add',value=value or '1.00',requestId=key or 'menu-1'}
        for k,v in pairs(extra or {}) do p[k]=v end
        m.routes['feather-admin:economy:adjust'](p,nil,17)
        return m.events[#m.events]
    end
    m.env=env; return m
end
test('console rejects players and enforces base unit bounds',function()
    local m=fixture(); m.command('1','key',17); assert(m.issues==0 and #m.logs==0)
    assert(m.command('0').code=='invalid_input' and m.command('1.5').code=='invalid_input')
    assert(m.command('1000001').code=='invalid_input' and m.issues==0)
end)
test('console issues through Economy with audit and stable original receipt',function()
    local m=fixture(); local r=m.command(); assert(r.ok and r.value.baseUnits==1 and r.value.auditRecorded)
    assert(m.lastRequest.idempotencyKey=='admin.wallet.issue:proof-fund-1' and #m.audits==2)
    assert(m.command().value.replayed and m.issues==1)
end)
test('changed terms under same key are refused and do not issue twice',function()
    local m=fixture(); assert(m.command().ok); assert(m.command('2').code=='idempotency_conflict' and m.issues==1)
end)
test('audit failure or inactive holder or missing wallet prevents issue',function()
    local m=fixture(); m.auditDown=true; assert(m.command().code=='audit_unavailable' and m.issues==0)
    m=fixture(); m.inactive=true; assert(m.command().code=='character_unavailable' and m.issues==0)
    m=fixture(); m.noWallet=true; assert(m.command().code=='account_not_found' and m.issues==0)
end)
test('lost issue reply recovers same key without duplicate money',function()
    local m=fixture(); m.lostReply=true; assert(m.command().code=='operation_unknown' and m.issues==1)
    m.lostReply=false; assert(m.command().value.replayed and m.issues==1)
end)
test('UI converts exact display dollars and pins actor and target',function()
    local m=fixture(); local r=m.adjust('0.01'); assert(r.name=='feather-admin:wallet:issued' and m.lastRequest.amount==1)
    assert(m.lastRequest.idempotencyKey=='admin.wallet.issue:'..ACCOUNT..':menu-1')
    assert(m.context.actorCharacterId==ACTOR and m.context.actorSource==nil and m.audits[1].source==17)
end)
test('UI decimals are exact and unsupported operations cannot issue',function()
    for _,value in ipairs({'0.001','1e2','-1','0','10001'}) do local m=fixture(); m.adjust(value); assert(m.issues==0) end
    local m=fixture(); m.adjust('1','key',{operation='remove'}); assert(m.issues==0)
    m.adjust('1','key',{field='gold'}); assert(m.issues==0)
    m.adjust('1','key',{characterId=ACTOR}); assert(m.issues==0)
end)
test('permission hierarchy and session changes before issue fail closed',function()
    local m=fixture(); m.allowed=false; m.adjust(); assert(m.issues==0)
    m=fixture(); m.hierarchy=false; m.adjust(); assert(m.issues==0)
    m=fixture(); m.onAudit=function() m.current=false end; m.adjust(); assert(m.issues==0)
    m=fixture(); m.onAudit=function() m.allowed=false end; m.adjust(); assert(m.issues==0)
end)
test('menu retries reuse one Economy receipt and summary reads displayed units',function()
    local m=fixture(); m.adjust('1'); m.adjust('1'); assert(m.issues==1)
    m.routes['feather-admin:economy:summary']({playerId=18},nil,17)
    local r=m.events[#m.events]; assert(r.name=='feather-admin:economy:summary' and r.value.dollars==1.23 and r.value.characterId==CHAR)
end)
test('policy service exception does not enable players or other principals',function()
    local env=setmetatable({}, {__index=_G}); local evaluate
    env.Config={identity={disabledActions={}}}; assert(loadfile('configs/service_policy.lua','t',env))()
    env.FeatherAdmin={IsActionEnabled=function(action) return not action:match('^economy%.') end,CanUse=function() return false end}
    env.exports={['feather-core']={RegisterPolicyProvider=function(_,_,impl) evaluate=impl.Evaluate; return {ok=true} end}}
    env.RegisterCommand=function() end; env.print=function() end
    assert(loadfile('server/services/policy_provider.lua','t',env))()
    local context={source=0,system=true,caller='feather-economy',subject={resource='feather-admin'}}
    assert(evaluate('economy.currency.issue',context).value.allowed)
    assert(not evaluate('economy.currency.destroy',context).value.allowed)
    context.subject.resource='bcc-stables'; assert(not evaluate('economy.currency.issue',context).value.allowed)
    context.subject.resource='feather-admin'; context.caller='other'; assert(not evaluate('economy.currency.issue',context).value.allowed)
    context.caller='feather-economy'; context.characterId='forged'; assert(not evaluate('economy.currency.issue',context).value.allowed)
    context.characterId=nil; env.Config.identity.disabledActions['economy.currency.issue']=true
    assert(not evaluate('economy.currency.issue',context).value.allowed)
    assert(not evaluate('economy.currency.issue',{source=17}).value.allowed)
end)
test('client retries preserve one pending key and refuse changing unknown intent',function()
    local env=setmetatable({}, {__index=_G}); local calls,events={},{}
    env.Config={economy={maxAmount=1000000}}; env.GetGameTimer=function() return 100 end
    env.RegisterNetEvent=function(name,fn) events[name]=fn end
    env.AdminTranslate=function(v) return v end; env.AdminUI={CanUseOnTarget=function() return true end}
    env.Feather={RPC={Notify=function(name,p) calls[#calls+1]=p end},Notify={RightNotify=function() end}}
    assert(loadfile('client/services/character_administration.lua','t',env))()
    env.AdminCharacter.economySummary={playerId=18,characterId=CHAR}
    assert(env.AdminCharacter.AdjustEconomy(18,'dollars','add',1))
    assert(env.AdminCharacter.AdjustEconomy(18,'dollars','add',1) and calls[1].requestId==calls[2].requestId)
    events['feather-admin:wallet:error']('operation_unknown')
    assert(not env.AdminCharacter.AdjustEconomy(18,'dollars','add',2))
    assert(not env.AdminCharacter.AdjustEconomy(18,'gold','add',1))
end)
test('only dollars additions bypass the legacy UI prefix and explicit disables win',function()
    local file=assert(io.open('server/core/init.lua')); local text=file:read('*a'); file:close()
    local body=assert(text:match('(function FeatherAdmin%.IsActionEnabled.-)\nlocal function AuthorityEntitled'))
    local env={FeatherAdmin={},Config={identity={disabledActionPrefixes={'economy.'},enabledActions={['economy.dollars.add']=true},disabledActions={}}}}
    setmetatable(env,{__index=_G}); assert(load(body,'action gate','t',env))()
    assert(env.FeatherAdmin.IsActionEnabled('economy.dollars.add'))
    for _,name in ipairs({'economy.dollars.remove','economy.gold.add','economy.tokens.add','economy.xp.add','economy.currency.issue'}) do
        assert(not env.FeatherAdmin.IsActionEnabled(name))
    end
    env.Config.identity.disabledActions['economy.dollars.add']=true
    assert(not env.FeatherAdmin.IsActionEnabled('economy.dollars.add'))
end)
print(('%d/%d wallet funding cases passed; no real funds moved.'):format(count,count))
