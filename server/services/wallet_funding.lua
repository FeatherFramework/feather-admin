-- Audited Economy wallet Issue/Destroy; console Issue remains compatible.
local busy=false
local function Err(code,message) return {ok=false,code=code,message=message} end
local function Require(result)
    if type(result)~='table' or type(result.ok)~='boolean' then error(Err('invalid_contract','Invalid service result.'),0) end
    if not result.ok then error(result,0) end
    return result.value
end
local function Check(ok,code,message) if not ok then error(Err(code,message),0) end end
local function Uuid(v) return type(v)=='string' and v:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')~=nil end
local function Callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
local function Audit(source,action,target,details)
    local called,id=pcall(AdminAudit.RecordTarget,source,action,target,details)
    return called and type(id)=='string' and id~='' and id or nil
end
local function Execute(source,args,done,actor,targetSession,operation)
    operation=operation or 'issue'
    local direction=operation=='issue' and 'add' or 'remove'
    local function Log(result) if done then done(result) else print('[AdminWalletIssue] '..json.encode(result)) end end
    if busy then Log(Err('busy','Wallet funding is already running.')); return end
    local character,currency,amount,key=args[1],args[2],tonumber(args[3]),args[4]
    local reason=table.concat(args,' ',5)
    local cfg=Config.walletFunding or {}
    local maximum=cfg.maxBaseUnits
    if (operation~='issue' and operation~='destroy') or #args<5 or not Uuid(character) or type(currency)~='string' or not currency:match('^[a-z][a-z0-9_]*$')
        or type(cfg.currencies)~='table' or cfg.currencies[currency]~=true
        or type(maximum)~='number' or maximum%1~=0 or maximum<1 or maximum>9007199254740991
        or not amount or amount%1~=0 or amount<1 or amount>maximum
        or type(key)~='string' or #key>(actor and 64 or 100) or not key:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or #reason<3 or #reason>200 or reason:find('%c') then
        Log(Err('invalid_input','AdminWalletIssue <characterUUID> <currency> <integerBaseUnits> <stableRequestId> <reason>')); return
    end
    local action=('economy.%s.%s'):format(currency,direction)
    character=character:lower()
    busy=true
    CreateThread(function()
        local ok,result=pcall(function()
            Check(GetResourceState('feather-core')=='started' and GetResourceState('feather-economy')=='started',
                'dependency_unavailable','Core and Economy must be started.')
            local core,economy=exports['feather-core'],exports['feather-economy']
            local health=Require(economy:GetHealth())
            Check(type(health)=='table' and health.state=='ready','not_ready','Economy must be ready.')
            local caps=Require(economy:GetCapabilities())
            Check(type(caps)=='table' and caps.contract==1 and caps.resource=='feather-economy'
                and type(caps.features)=='table' and caps.features.supplyOperations==1 and caps.features.idempotency==1,
                'unsupported_contract','Economy supply/idempotency Contract 1 required.')
            local provider=Require(core:GetProvider('character-profile',nil,1))
            local impl=type(provider)=='table' and provider.implementation
            Check(type(impl)=='table' and Callable(impl.GetIdentity),'identity_unavailable','Character identity provider required.')
            local identity=Require(impl.GetIdentity(character))
            Check(type(identity)=='table' and identity.characterId==character and identity.status=='active',
                'character_unavailable','An active character is required.')
            Require(economy:GetCurrency(currency))
            local accounts=Require(economy:FindAccountsByOwner({ownerType='character',ownerId=character}))
            Check(type(accounts)=='table','invalid_contract','Account list required.')
            local wallet
            for _,account in ipairs(accounts) do
                if type(account)=='table' and account.ownerType=='character' and account.ownerId==character
                    and account.accountType=='wallet' and account.currency==currency then
                    Check(wallet==nil,'wallet_conflict','Multiple eligible wallets.'); wallet=account
                end
            end
            -- Economy checks open status for new mutations, but can still return
            -- an existing historical receipt after account closure.
            Check(wallet~=nil and Uuid(wallet.accountId),'account_not_found','An existing wallet is required; no account was provisioned.')
            local target={characterId=character,accountId=identity.accountId}
            local details=('request=%s currency=%s baseUnits=%.0f reason=%s'):format(key,currency,amount,reason)
            if actor then
                Check(FeatherAdmin.CanUse(source,action) and FeatherAdmin.CheckTargetAccountHierarchy(source,action,identity.accountId,targetSession.source), 'authorization_denied','Wallet permission or target hierarchy changed.')
                Check(core:IsSessionCurrent(source,actor.sessionId,actor.characterId)==true and core:IsSessionCurrent(targetSession.source,targetSession.sessionId,character)==true,'session_stale','Actor or target character changed.')
            end
            local issueKey='admin.wallet.'..operation..':'..(actor and (actor.accountId..':') or '')..key
            Check(Audit(source,'wallet.'..operation..'.requested',target,details)~=nil,'audit_unavailable','Funding refused because audit intent was not confirmed.')
            if actor then
                Check(FeatherAdmin.CanUse(source,action) and FeatherAdmin.CheckTargetAccountHierarchy(source,action,identity.accountId,targetSession.source), 'authorization_denied','Wallet permission or target hierarchy changed.')
                Check(core:IsSessionCurrent(source,actor.sessionId,actor.characterId)==true and core:IsSessionCurrent(targetSession.source,targetSession.sessionId,character)==true,'session_stale','Actor or target character changed before issue.')
            end
            local request={accountId=wallet.accountId,currency=currency,amount=amount,
                reasonCode='admin.wallet.'..operation,referenceType='admin_wallet_'..operation,referenceId=issueKey,idempotencyKey=issueKey}
            local context={correlationId=issueKey,actorAccountId=actor and actor.accountId,actorCharacterId=actor and actor.characterId}
            local issued
            if operation=='issue' then issued=economy:Issue(request,context) else issued=economy:Destroy(request,context) end
            if type(issued)~='table' or not issued.ok then
                Audit(source,'wallet.'..operation..'.failed',target,details..' code='..tostring(type(issued)=='table' and issued.code or 'invalid_contract'))
                Require(issued)
            end
            local receipt=Require(issued)
            Check(type(receipt)=='table' and Uuid(receipt.transactionId) and receipt.operation==operation
                and receipt.sourceResource=='feather-admin' and receipt[operation=='issue' and 'toAccountId' or 'fromAccountId']==wallet.accountId
                and receipt.currency==currency and receipt.amount==amount and receipt.reasonCode=='admin.wallet.'..operation
                and receipt.referenceType=='admin_wallet_'..operation and receipt.referenceId==issueKey,
                'invalid_receipt','Economy issue result does not match; retry only this same request key.')
            local recorded=Audit(source,'wallet.'..operation,target,details..' transaction='..receipt.transactionId)
            return {ok=true,value={characterId=character,operation=operation,walletAccountId=wallet.accountId,currency=currency,baseUnits=amount,
                requestId=key,idempotencyKey=issueKey,transactionId=receipt.transactionId,replayed=receipt.replayed==true,auditRecorded=recorded~=nil}}
        end)
        busy=false
        if ok then Log(result)
        elseif type(result)=='table' and result.ok==false then Log(result)
        else Log(Err('operation_unknown','Funding outcome unknown. Retry only the same target, currency, amount and request ID.')) end
    end)
end

RegisterCommand('AdminWalletIssue',function(source,args)
    if source==0 then Execute(0,args) end
end,true)

local function Sessions(params,source,action)
    Check(FeatherAdmin.RequirePermission(source,action),'authorization_denied','Wallet funding permission required.')
    local core=exports['feather-core']
    local actor=Require(core:RequireSession(source))
    local targetId=tonumber(params.playerId)
    Check(targetId and targetId%1==0 and targetId>0,'invalid_input','Target server ID required.')
    local target=Require(core:RequireSession(targetId))
    Check(FeatherAdmin.CheckTargetAccountHierarchy(source,action,target.accountId,targetId),
        'authorization_denied','Target hierarchy denied.')
    return actor,target
end
local function Failure(source,result)
    local code=type(result)=='table' and result.code or 'operation_unknown'
    local details=type(result)=='table' and type(result.details)=='table' and result.details or {}
    print('[feather-admin:wallet] '..json.encode({source=source,code=code,policyCode=details.policyCode,action=details.action}))
    TriggerClientEvent('feather-admin:wallet:error',source,code)
end
local function Action(params)
    Check((params.field=='dollars' or params.field=='gold') and (params.operation=='add' or params.operation=='remove'),
        'invalid_input','Select cash or gold and add or remove.')
    return ('economy.%s.%s'):format(params.field,params.operation)
end
local function Precision(currency)
    local p=type(currency)=='table' and currency.precision
    Check(type(p)=='number' and p%1==0 and p>=0 and p<=8,'invalid_contract','Currency precision required.')
    return p
end
FeatherAdmin.RegisterRPC('feather-admin:economy:summary',function(params,_,source)
    local ok,result=pcall(function()
        local _,target=Sessions(params,source,Action(params))
        local economy=exports['feather-economy']
        local accounts=Require(economy:FindAccountsByOwner({ownerType='character',ownerId=target.characterId}))
        local summary={playerId=target.source,characterId=target.characterId,characterName='',precisions={}}
        for _,field in ipairs({'dollars','gold'}) do
            local canRead=false
            for _,op in ipairs({'add','remove'}) do
                local action=('economy.%s.%s'):format(field,op)
                if FeatherAdmin.CanUse(source,action) and FeatherAdmin.CheckTargetAccountHierarchy(source,action,target.accountId,target.source) then canRead=true end
            end
            if canRead then
                local precision=Precision(Require(economy:GetCurrency(field)))
                local found
                for _,account in ipairs(accounts) do
                    if account.ownerId==target.characterId and account.ownerType=='character' and account.accountType=='wallet'
                        and account.currency==field and account.status=='open' then
                        Check(not found,'wallet_conflict','Multiple eligible wallets.');found=account
                    end
                end
                Check(found~=nil,'account_not_found','Existing currency wallet required.')
                Check(type(found.balance)=='number','invalid_contract','Wallet balance required.')
                summary[field]=found.balance/10^precision;summary.precisions[field]=precision
            end
        end
        return summary
    end)
    if ok then TriggerClientEvent('feather-admin:economy:summary',source,result) else Failure(source,result) end
end,{windowMs=2000,maxCalls=2,maxPayloadBytes=128})

FeatherAdmin.RegisterRPC('feather-admin:economy:adjust',function(params,_,source)
    local ok,actor,target,amount=pcall(function()
        local who,subject=Sessions(params,source,Action(params))
        Check(params.characterId==subject.characterId,'invalid_input','Selected character changed.')
        local precision=Precision(Require(exports['feather-economy']:GetCurrency(params.field)))
        local text=tostring(params.value or '')
        local whole,fraction=text:match('^(%d+)%.?(%d*)$')
        Check(whole and #whole<=12 and #fraction<=precision,'invalid_input','Enter an exact positive currency amount.')
        local units=tonumber(whole)*10^precision+tonumber((fraction..string.rep('0',precision)):sub(1,precision)~='' and (fraction..string.rep('0',precision)):sub(1,precision) or '0')
        return who,subject,units
    end)
    if not ok then Failure(source,actor); return end
    Execute(source,{target.characterId,params.field,tostring(amount),params.requestId,'Admin menu wallet adjustment'},function(result)
        if not result.ok then Failure(source,result); return end
        TriggerClientEvent('feather-admin:wallet:issued',source,result.value)
    end,actor,target,params.operation=='add' and 'issue' or 'destroy')
end,{windowMs=3000,maxCalls=2,maxPayloadBytes=512,maxDepth=2,maxNodes=12})
