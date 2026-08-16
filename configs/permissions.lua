-- Minimum numeric role level required for each action.
-- Keep menu.open at or below the lowest staff level that needs access.
Config.permissions = {
    ['menu.open'] = 99,
    ['players.view'] = 99,
    ['player.info'] = 99,
    ['player.go_to'] = 99,
    ['player.bring'] = 99,
    ['player.send_back'] = 99,
    ['player.spectate'] = 99,
    ['player.kick'] = 99,

    ['moderation.view'] = 99,
    ['moderation.search'] = 99,
    ['moderation.history'] = 99,
    ['moderation.warn'] = 99,
    ['moderation.ban'] = 99,
    ['moderation.unban'] = 99,

    ['economy.dollars.add'] = 99,
    ['economy.dollars.remove'] = 99,
    ['economy.gold.add'] = 99,
    ['economy.gold.remove'] = 99,
    ['economy.tokens.add'] = 99,
    ['economy.tokens.remove'] = 99,
    ['economy.xp.add'] = 99,
    ['economy.xp.remove'] = 99,
    ['character.restore_model'] = 99,

    ['booster.invincibility'] = 99,
    ['booster.invisibility'] = 99,
    ['booster.infinite_stamina'] = 99,
    ['booster.heal'] = 99,
    ['booster.revive'] = 99,
    ['booster.kill'] = 99,
    ['booster.disable_fow'] = 99,
    ['booster.noclip'] = 99,
    ['ped.change'] = 99,

    ['developer.entity_inspector'] = 99,
    ['developer.bone_viewer'] = 99,
    ['developer.copy_coordinates'] = 99,

    ['teleport.waypoint'] = 99,
    ['teleport.auto_waypoint'] = 99,
    ['teleport.coordinates'] = 99,

    ['troll.lightning_strike'] = 99,
    ['troll.freeze'] = 99,
    ['troll.teleport_to_heaven'] = 99,
    ['troll.cage'] = 99,
    ['troll.force_cinematic_camera'] = 99,
    ['troll.make_ped_giant'] = 99,
    ['troll.hostile_ped_army'] = 99,
    ['troll.handcuff'] = 99,
    ['troll.kick_from_vehicle'] = 99,
    ['troll.hostile_bear'] = 99,
    ['troll.lag'] = 99
}
