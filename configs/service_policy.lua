-- Server-only policy grants. No wildcards, staff-role fallback, or client actors.
-- The broker caller authenticates the delegated subject.resource principal.
Config.servicePolicy = {
    ['feather-economy'] = {
        ['bcc-stables'] = {
            ['economy.currency.issue'] = true
        },
        ['feather-admin'] = {
            ['economy.currency.issue'] = true,
            ['economy.currency.destroy'] = true
        },
    },
    ['feather-property'] = {
        ['feather-property-access-tests'] = {
            ['property.property.manage'] = true,
            ['property.interest.manage'] = true,
        },
    },
    ['feather-assets'] = {
        -- Assets authenticates this principal and still enforces manager ownership.
        -- Asset management only; no ownership-transfer action is granted.
        ['bcc-stables'] = {
            ['assets.asset.manage'] = true,
        },
        ['feather-assets-access-tests'] = {
            ['assets.asset.manage'] = true,
            ['assets.ownership.transfer'] = true,
        },
    },
    -- Native Jobs brokers authenticate these exact principals independently of staff roles.
    ['feather-jobs'] = {
        -- Dormant unless Jobs grants the development fixture caller trust.
        ['feather-jobs-tests'] = {
            ['jobs.definition.manage'] = true,
            ['jobs.assignment.manage'] = true,
        },
        ['feather-jobs'] = {
            ['jobs.definition.manage'] = true,
            ['jobs.assignment.manage'] = true,
        },
        ['feather-admin'] = {
            ['jobs.definition.manage'] = true,
            ['jobs.assignment.manage'] = true,
        },
    },
    -- Access still requires its own caller trust and target-provider authority.
    -- This fixture principal is dormant unless Access DevMode is enabled.
    ['feather-access'] = {
        ['feather-assets-access-tests'] = {['access.grant.read']=true},
        ['feather-property-access-tests'] = {['access.grant.read']=true},
        ['feather-property'] = {
            ['access.grant.manage'] = true,
            ['access.grant.read'] = true,
        },
        ['feather-assets'] = {
            ['access.grant.manage'] = true,
            ['access.grant.read'] = true,
        },
        ['feather-inventory'] = {
            ['access.grant.manage'] = true,
            ['access.grant.read'] = true,
        },
        ['feather-jobs-tests'] = {
            ['access.grant.manage'] = true,
            ['access.grant.read'] = true,
        },
        ['feather-access-tests'] = {
            ['access.grant.manage'] = true,
            ['access.grant.read'] = true,
        },
    },
    ['feather-organizations'] = {
        -- Organizations grants this caller trust only in development mode.
        ['feather-jobs-tests'] = {
            ['organizations.organization.create'] = true,
            ['organizations.organization.update'] = true,
            ['organizations.organization.suspend'] = true,
        },
        ['feather-shops'] = {
            ['organizations.organization.create']=true,
            ['organizations.organization.update']=true
        },
        ['feather-organizations'] = {
            ['organizations.organization.create']=true,
            ['organizations.organization.update']=true,
            ['organizations.organization.suspend']=true,
            ['organizations.organization.dissolve']=true,
            ['organizations.relationship.manage']=true,
            ['organizations.interest.manage']=true
        },
        ['feather-admin'] = {
            ['organizations.organization.create']=true,
            ['organizations.organization.update']=true,
            ['organizations.organization.suspend']=true,
            ['organizations.organization.dissolve']=true,
            ['organizations.relationship.manage']=true,
            ['organizations.interest.manage']=true
        }
    }
}

-- Service-only exceptions to hidden legacy UI prefixes; explicit disabledActions
-- still wins. This never grants a player/menu permission or an action by itself.
Config.servicePolicyActionExceptions = { ['economy.currency.issue'] = true, ['economy.currency.destroy'] = true }
