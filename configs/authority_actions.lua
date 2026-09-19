-- Stable Authority identities and private hierarchy precedence for Admin roles.
Config.authorityMigration = {
    capabilityPrefix = 'staff.admin.',
    enforcement = true,
    hierarchy = true,
    roles = {
        { key = 'moderator', roleKey = 'staff.admin.moderator', label = 'Moderator', precedence = 1 },
        { key = 'administrator', roleKey = 'staff.admin.administrator', label = 'Administrator', precedence = 2 },
        { key = 'owner', roleKey = 'staff.admin.owner', label = 'Owner', precedence = 3 }
    }
}

Config.authorityActions = {}
for action in pairs(Config.permissions) do
    Config.authorityActions[action] = Config.authorityMigration.capabilityPrefix .. action
end
