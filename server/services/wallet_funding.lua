-- Economy wallet issue shared by the console and permission-gated Admin UI.
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
local function Execute(source,args,done,actor,targetSession)
    local function Log(result) if done then done(result) else print('[AdminWalletIssue] '..json.encode(result)) end end
    if busy then Log(Err('busy','Wallet funding is already running.')); return end
    local character,currency,amount,key=args[1],args[2],tonumber(args[3]),args[4]
    local reason=table.concat(args,' ',5)
    local cfg=Config.walletFunding or {}
    local maximum=cfg.maxBaseUnits
    if #args<5 or not Uuid(character) or type(currency)~='string' or not currency:match('^[a-z][a-z0-9_]*$')
        or type(cfg.currencies)~='table' or cfg.currencies[currency]~=true
        or type(maximum)~='number' or maximum%1~=0 or maximum<1 or maximum>9007199254740991
        or not amount or amount%1~=0 or amount<1 or amount>maximum
        or type(key)~='string' or #key>(actor and 64 or 100) or not key:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or #reason<3 or #reason>200 or reason:find('%c') then
        Log(Err('invalid_input','AdminWalletIssue <characterUUID> <currency> <integerBaseUnits> <stableRequestId> <reason>')); return
    end
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
            Check(wallet~=nil and Uuid(wallet.accountId),'account_not_found','An existing wallet is required; no account was provisioned.')
            local target={characterId=character,accountId=identity.accountId}
            local details=('request=%s currency=%s baseUnits=%.0f reason=%s'):format(key,currency,amount,reason)
            if actor then
                Check(FeatherAdmin.CanUse(source,'economy.dollars.add') and FeatherAdmin.CheckTargetAccountHierarchy(source,'economy.dollars.add',identity.accountId,targetSession.source), 'authorization_denied','Wallet permission or target hierarchy changed.')
                Check(core:IsSessionCurrent(source,actor.sessionId,actor.characterId)==true and core:IsSessionCurrent(targetSession.source,targetSession.sessionId,character)==true,'session_stale','Actor or target character changed.')
            end
            local issueKey='admin.wallet.issue:'..(actor and (actor.accountId..':') or '')..key
            Check(Audit(source,'wallet.issue.requested',target,details)~=nil,'audit_unavailable','Funding refused because audit intent was not confirmed.')
            if actor then
                Check(FeatherAdmin.CanUse(source,'economy.dollars.add') and FeatherAdmin.CheckTargetAccountHierarchy(source,'economy.dollars.add',identity.accountId,targetSession.source), 'authorization_denied','Wallet permission or target hierarchy changed.')
                Check(core:IsSessionCurrent(source,actor.sessionId,actor.characterId)==true and core:IsSessionCurrent(targetSession.source,targetSession.sessionId,character)==true,'session_stale','Actor or target character changed before issue.')
            end
            local issued=economy:Issue({accountId=wallet.accountId,currency=currency,amount=amount,
                reasonCode='admin.wallet.issue',referenceType='admin_wallet_issue',referenceId=issueKey,
                idempotencyKey=issueKey},{correlationId=issueKey,actorAccountId=actor and actor.accountId,actorCharacterId=actor and actor.characterId})
            if type(issued)~='table' or not issued.ok then
                Audit(source,'wallet.issue.failed',target,details..' code='..tostring(type(issued)=='table' and issued.code or 'invalid_contract'))
                Require(issued)
            end
            local receipt=Require(issued)
            Check(type(receipt)=='table' and Uuid(receipt.transactionId) and receipt.operation=='issue'
                and receipt.sourceResource=='feather-admin' and receipt.toAccountId==wallet.accountId
                and receipt.currency==currency and receipt.amount==amount and receipt.reasonCode=='admin.wallet.issue'
                and receipt.referenceType=='admin_wallet_issue' and receipt.referenceId==issueKey,
                'invalid_receipt','Economy issue result does not match; retry only this same request key.')
            local recorded=Audit(source,'wallet.issue',target,details..' transaction='..receipt.transactionId)
            return {ok=true,value={characterId=character,walletAccountId=wallet.accountId,currency=currency,baseUnits=amount,
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

local function Sessions(params,source)
    Check(FeatherAdmin.RequirePermission(source,'economy.dollars.add'),'authorization_denied','Wallet funding permission required.')
    local core=exports['feather-core']
    local actor=Require(core:RequireSession(source))
    local targetId=tonumber(params.playerId)
    Check(targetId and targetId%1==0 and targetId>0,'invalid_input','Target server ID required.')
    local target=Require(core:RequireSession(targetId))
    Check(FeatherAdmin.CheckTargetAccountHierarchy(source,'economy.dollars.add',target.accountId,targetId),
        'authorization_denied','Target hierarchy denied.')
    return actor,target
end
local function Failure(source,result)
    TriggerClientEvent('feather-admin:wallet:error',source,type(result)=='table' and result.code or 'operation_unknown')
end
FeatherAdmin.RegisterRPC('feather-admin:economy:summary',function(params,_,source)
    local ok,result=pcall(function()
        local _,target=Sessions(params,source)
        local economy=exports['feather-economy']
        local currency=Require(economy:GetCurrency('dollars'))
        Check(type(currency)=='table' and type(currency.precision)=='number' and currency.precision%1==0 and currency.precision>=0 and currency.precision<=8,
            'invalid_contract','Currency precision required.')
        local accounts=Require(economy:FindAccountsByOwner({ownerType='character',ownerId=target.characterId}))
        for _,account in ipairs(accounts) do
            if account.ownerId==target.characterId and account.ownerType=='character' and account.accountType=='wallet'
                and account.currency=='dollars' then
                return {playerId=target.source,characterId=target.characterId,dollars=account.balance/10^currency.precision,
                    characterName='',precision=currency.precision}
            end
        end
        error(Err('account_not_found','No existing dollars wallet.'),0)
    end)
    if ok then TriggerClientEvent('feather-admin:economy:summary',source,result) else Failure(source,result) end
end,{windowMs=2000,maxCalls=2,maxPayloadBytes=128})

FeatherAdmin.RegisterRPC('feather-admin:economy:adjust',function(params,_,source)
    local ok,actor,target,amount=pcall(function()
        local who,subject=Sessions(params,source)
        Check(params.field=='dollars' and params.operation=='add' and params.characterId==subject.characterId,
            'invalid_input','Only dollars additions for the selected character are supported.')
        local currency=Require(exports['feather-economy']:GetCurrency('dollars'))
        local precision=type(currency)=='table' and currency.precision
        Check(type(precision)=='number' and precision%1==0 and precision>=0 and precision<=8,'invalid_contract','Currency precision required.')
        local text=tostring(params.value or '')
        local whole,fraction=text:match('^(%d+)%.?(%d*)$')
        Check(whole and #whole<=12 and #fraction<=precision,'invalid_input','Enter an exact positive currency amount.')
        local units=tonumber(whole)*10^precision+tonumber((fraction..string.rep('0',precision)):sub(1,precision)~='' and (fraction..string.rep('0',precision)):sub(1,precision) or '0')
        return who,subject,units
    end)
    if not ok then Failure(source,actor); return end
    Execute(source,{target.characterId,'dollars',tostring(amount),params.requestId,'Admin menu wallet funding'},function(result)
        if not result.ok then Failure(source,result); return end
        TriggerClientEvent('feather-admin:wallet:issued',source,result.value)
    end,actor,target)
end,{windowMs=3000,maxCalls=2,maxPayloadBytes=512,maxDepth=2,maxNodes=12})
