-- Exact one-to-one migration names for Admin's legacy numeric permissions.
-- These are capability identities only; this file grants no authority.
Config.authorityMigration = {
    capabilityPrefix = 'staff.admin.',
    roles = {
        { roleKey = 'staff.admin.moderator', label = 'Moderator', legacyLevel = 50 },
        { roleKey = 'staff.admin.senior_admin', label = 'Senior Admin', legacyLevel = 75 },
        { roleKey = 'staff.admin.owner', label = 'Owner', legacyLevel = 99 }
    }
}

Config.authorityActions = {}
for action in pairs(Config.permissions) do
    Config.authorityActions[action] = Config.authorityMigration.capabilityPrefix .. action
end
