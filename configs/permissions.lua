-- Default numeric staff tiers:
-- 50 = Moderator, 75 = Senior Admin, 99 = Owner.
-- Change the numbers to match the levels in your server's roles table.
Config.permissions = {
    ['menu.open'] = 50,
    ['players.view'] = 50,
    ['player.info'] = 50,
    ['player.go_to'] = 50,
    ['player.bring'] = 50,
    ['player.send_back'] = 50,
    ['player.spectate'] = 50,

    ['moderation.view'] = 50,
    ['moderation.search'] = 50,
    ['moderation.search_identifiers'] = 75,
    ['moderation.history'] = 50,
    ['moderation.warn'] = 50,
    ['moderation.ban'] = 75,
    ['moderation.unban'] = 75,
    ['moderation.kick'] = 50,

    ['audit.view'] = 75,
    ['audit.sensitive'] = 99,

    ['economy.dollars.add'] = 99,
    ['economy.dollars.remove'] = 99,
    ['economy.gold.add'] = 99,
    ['economy.gold.remove'] = 99,
    ['economy.tokens.add'] = 99,
    ['economy.tokens.remove'] = 99,
    ['economy.xp.add'] = 99,
    ['economy.xp.remove'] = 99,
    ['character.restore_model'] = 75,
    ['inventory.give'] = 75,

    ['booster.invincibility'] = 75,
    ['booster.invisibility'] = 75,
    ['booster.infinite_stamina'] = 75,
    ['booster.heal'] = 50,
    ['booster.revive'] = 50,
    ['booster.kill'] = 75,
    ['booster.disable_fow'] = 75,
    ['booster.noclip'] = 75,
    ['ped.change'] = 75,

    ['developer.entity_inspector'] = 75,
    ['developer.bone_viewer'] = 75,
    ['developer.copy_coordinates'] = 50,

    ['teleport.waypoint'] = 50,
    ['teleport.auto_waypoint'] = 50,
    ['teleport.coordinates'] = 50,

    ['troll.lightning_strike'] = 99,
    ['troll.freeze'] = 75,
    ['troll.teleport_to_heaven'] = 99,
    ['troll.cage'] = 75,
    ['troll.force_cinematic_camera'] = 75,
    ['troll.make_ped_giant'] = 99,
    ['troll.hostile_ped_army'] = 99,
    ['troll.handcuff'] = 75,
    ['troll.kick_from_vehicle'] = 75,
    ['troll.hostile_bear'] = 99,
    ['troll.lag'] = 99
}
