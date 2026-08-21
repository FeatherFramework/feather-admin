-- Controls which staff members may target other staff accounts.
Config.hierarchy = {
    strict = true, -- true requires the actor to have a higher level than the target.

    -- These helpful actions may be used on players of any role level.
    exempt = {
        ['booster.heal'] = true,
        ['booster.revive'] = true,
        ['player.go_to'] = true
    },

    -- Self-target rules. Set action to true to allow it; false blocks it.
    -- These checks are enforced by the server, not only by the menu.
    allowSelf = {
        -- Staff roles must always be changed by another authorized staff member.
        ['staff.role.assign'] = false,
        -- Player management
        ['player.info'] = true,
        ['player.go_to'] = false,
        ['player.bring'] = false,
        ['player.send_back'] = false,
        ['player.spectate'] = false,

        -- Moderation
        ['moderation.history'] = false,
        ['moderation.warn'] = false,
        ['moderation.kick'] = false,
        ['moderation.ban'] = false,
        ['moderation.unban'] = false,

        -- Staff cases
        ['cases.create'] = false,
        ['cases.claim'] = false,
        ['cases.link'] = false,
        ['cases.close'] = false,

        -- Economy and character
        ['economy.dollars.add'] = true,
        ['economy.dollars.remove'] = true,
        ['economy.gold.add'] = true,
        ['economy.gold.remove'] = true,
        ['economy.tokens.add'] = true,
        ['economy.tokens.remove'] = true,
        ['economy.xp.add'] = true,
        ['economy.xp.remove'] = true,
        ['character.restore_model'] = true,
        ['inventory.give'] = true,

        -- Player status
        ['booster.invincibility'] = true,
        ['booster.invisibility'] = true,
        ['booster.infinite_stamina'] = true,
        ['booster.heal'] = true,
        ['booster.revive'] = true,
        ['booster.kill'] = false,
        ['booster.disable_fow'] = true,

        -- Appearance
        ['ped.change'] = false,

        -- Special effects
        ['troll.lightning_strike'] = false,
        ['troll.freeze'] = false,
        ['troll.teleport_to_heaven'] = false,
        ['troll.cage'] = false,
        ['troll.force_cinematic_camera'] = false,
        ['troll.make_ped_giant'] = false,
        ['troll.hostile_ped_army'] = false,
        ['troll.handcuff'] = false,
        ['troll.kick_from_vehicle'] = false,
        ['troll.hostile_bear'] = false,
        ['troll.lag'] = false
    }
}
