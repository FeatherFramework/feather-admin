-- Controls which staff members may target other staff accounts.
Config.hierarchy = {
    strict = true, -- true requires the actor to have a higher level than the target.

    -- These helpful actions may be used on players of any role level.
    exempt = {
        ['booster.heal'] = true,
        ['booster.revive'] = true
    },

    -- Actions staff may intentionally use on their own account.
    allowSelf = {
        ['player.info'] = true,
        ['economy.dollars.add'] = true,
        ['economy.dollars.remove'] = true,
        ['economy.gold.add'] = true,
        ['economy.gold.remove'] = true,
        ['economy.tokens.add'] = true,
        ['economy.tokens.remove'] = true,
        ['economy.xp.add'] = true,
        ['economy.xp.remove'] = true,
        ['character.restore_model'] = true,
        ['booster.invincibility'] = true,
        ['booster.invisibility'] = true,
        ['booster.infinite_stamina'] = true,
        ['booster.heal'] = true,
        ['booster.revive'] = true,
        ['booster.disable_fow'] = true,
        ['ped.change'] = true
    }
}
