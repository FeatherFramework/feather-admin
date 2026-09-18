-- Server-only policy grants. No wildcards, role-level fallback or client actors.
-- The broker caller authenticates the delegated subject.resource principal.
Config.servicePolicy = {
    ['feather-organizations'] = {
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
