local running=false
RegisterCommand('ShopBusinessLifecycleControl',function(source,args)
    if source~=0 or GetResourceMetadata('feather-shops','shops_dev_tests',0)~='true' then return end
    local called,reason=xpcall(function()
        local revision=tonumber(args[3])
        assert(#args==3 and (args[1]=='suspend' or args[1]=='resume') and revision and revision>=1 and revision%1==0,
            'Use suspend|resume <stable requestId> <expected organization revision>')
        local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
        local shop=Require(exports['feather-shops']:ListShops())[1]
        local catalog=Require(exports['feather-shops']:GetCatalog(shop.id))
        local result=Require(exports['feather-organizations']:ChangeOrganizationStatus({organizationId=catalog.organizationId,
            expectedRevision=revision,status=args[1]=='suspend' and 'suspended' or 'active',requestId=args[2],reasonCode='development.shop_recovery'}))
        local current=Require(exports['feather-organizations']:GetOrganization({organizationId=catalog.organizationId}))
        print(('[ShopBusinessLifecycleControl] PASS organization=%s status=%s revision=%d receiptReplayed=%s'):format(
            catalog.organizationId,current.status,current.revision,tostring(result.replayed)))
    end,debug.traceback)
    if not called then print('[ShopBusinessLifecycleControl] FAIL '..tostring(reason)) end
end,true)

RegisterCommand('ShopOrganizationLifecycleLiveTest',function(source,args)
    if source~=0 or GetResourceMetadata('feather-shops','shops_dev_tests',0)~='true' then return end
    if running then print('[ShopOrganizationLifecycleLiveTest] FAIL already running');return end
    running=true
    local resumeRequest
    local replayed=false
    local called,reason=xpcall(function()
        assert(#args==2 and tonumber(args[1]) and #args[2]<=100,'Use <buyer source near shop> <stable requestId>')
        local buyer,base=tonumber(args[1]),args[2]
        local function Require(result) assert(result.ok,tostring(result.code)..': '..tostring(result.message));return result.value end
        local shop=Require(exports['feather-shops']:ListShops())[1]
        local catalog=Require(exports['feather-shops']:GetCatalog(shop.id))
        local id=catalog.organizationId
        local organization=Require(exports['feather-organizations']:GetOrganization({organizationId=id}))
        assert(organization.status=='active','Start with the shop business active')
        local history=Require(exports['feather-organizations']:InspectOrganizationHistory({organizationId=id,limit=50}))
        local revision=organization.revision
        for _,event in ipairs(history.items) do
            if event.sourceResource==GetCurrentResourceName() and event.requestId==base..':suspend' then
                revision=event.revision-1;replayed=true
            end
        end
        local suspendRequest={organizationId=id,expectedRevision=revision,status='suspended',
            requestId=base..':suspend',reasonCode='development.shop_lifecycle'}
        local originalResume={organizationId=id,expectedRevision=revision+1,status='active',
            requestId=base..':resume',reasonCode='development.shop_lifecycle'}
        if replayed then
            assert(Require(exports['feather-organizations']:ChangeOrganizationStatus(suspendRequest)).replayed,'Suspend receipt not replayed')
            assert(Require(exports['feather-organizations']:ChangeOrganizationStatus(originalResume)).replayed,'Resume receipt not replayed')
            assert(Require(exports['feather-organizations']:GetOrganization({organizationId=id})).revision==organization.revision,'Historical replay changed state')
            return
        end
        local session=Require(exports['feather-core']:GetSessionContext(buyer))
        local before=Require(exports['feather-economy']:FindAccountsByOwner({ownerType='character',ownerId=session.characterId}))
        local quoteRequest={shopId=shop.id,offerId=catalog.offers[1].id,quantity=2}
        local quote=Require(exports['feather-shops']:CreateQuote(quoteRequest,buyer))
        Require(exports['feather-organizations']:ChangeOrganizationStatus(suspendRequest))
        resumeRequest=originalResume
        local function Blocked(result) assert(not result.ok and result.code=='organization_inactive','Inactive business did not block new commerce') end
        Blocked(exports['feather-shops']:CreateQuote(quoteRequest,buyer))
        Blocked(exports['feather-shops']:ValidateQuote(quote.id,buyer))
        Blocked(exports['feather-shops']:PrepareOrder({quoteId=quote.id,requestId=base..':purchase'},buyer))
        local orderCount=tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM shop_orders WHERE source_resource=? AND request_id=?',
            {GetCurrentResourceName(),base..':purchase'}))
        assert(orderCount==0,'Rejected order persisted')
        local after=Require(exports['feather-economy']:FindAccountsByOwner({ownerType='character',ownerId=session.characterId}))
        local balances={}
        for _,account in ipairs(before) do balances[account.accountId]=account.balance end
        assert(#before==#after,'Account identities changed during test')
        for _,account in ipairs(after) do assert(balances[account.accountId]==account.balance,'Buyer balance changed') end
        Require(exports['feather-organizations']:ChangeOrganizationStatus(originalResume));resumeRequest=nil
        Require(exports['feather-shops']:CreateQuote(quoteRequest,buyer))
        assert(Require(exports['feather-organizations']:GetOrganization({organizationId=id})).status=='active','Business not resumed')
    end,debug.traceback)
    local cleanup=true
    if resumeRequest then
        local resumed,result=pcall(function() return exports['feather-organizations']:ChangeOrganizationStatus(resumeRequest) end)
        cleanup=resumed and type(result)=='table' and result.ok==true
    end
    running=false
    if not called then print('[ShopOrganizationLifecycleLiveTest] FAIL '..tostring(reason)) end
    if not cleanup then print('[ShopOrganizationLifecycleLiveTest] FAIL business resume failed; inspect organization state before continuing')
    elseif called and replayed then
        print('[ShopOrganizationLifecycleLiveTest] PASS originalReceiptsReplayed=true businessActive=true stateUnchanged=true (historical replay only)')
    elseif called then
        print(('[ShopOrganizationLifecycleLiveTest] PASS newQuotesBlocked=true preparedPurchaseBlocked=true balancesUnchanged=true noOrder=true businessResumed=true replayed=%s (no funds moved or items granted)'):format(tostring(replayed)))
    end
end,true)
