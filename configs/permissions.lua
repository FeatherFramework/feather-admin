-- Minimum Authority role required by the reviewed default Admin catalog.
-- These keys build explicit capability grants; they are not numeric permission levels.
Config.permissions = {
    ['roles.assignment.manage'] = 'owner',
    ['menu.open'] = 'moderator', ['server.overview'] = 'moderator',
    ['server.announce'] = 'administrator', ['players.view'] = 'moderator',
    ['player.info'] = 'moderator', ['player.go_to'] = 'moderator',
    ['player.bring'] = 'moderator', ['player.send_back'] = 'moderator',
    ['player.spectate'] = 'moderator',

    ['moderation.view'] = 'moderator', ['moderation.bans.view'] = 'administrator',
    ['moderation.search'] = 'moderator', ['moderation.search_identifiers'] = 'administrator',
    ['moderation.history'] = 'moderator', ['moderation.warn'] = 'moderator',
    ['moderation.ban'] = 'administrator', ['moderation.unban'] = 'administrator',
    ['moderation.kick'] = 'moderator',

    ['reports.view'] = 'moderator', ['reports.claim'] = 'moderator',
    ['reports.close'] = 'moderator', ['reports.manage'] = 'administrator',
    ['cases.view'] = 'moderator', ['cases.create'] = 'moderator',
    ['cases.claim'] = 'moderator', ['cases.link'] = 'moderator',
    ['cases.close'] = 'administrator', ['cases.manage'] = 'administrator',

    ['notes.view'] = 'moderator', ['notes.create'] = 'moderator',
    ['notes.edit'] = 'administrator', ['notes.archive'] = 'administrator',
    ['notes.history'] = 'administrator', ['audit.view'] = 'administrator',
    ['audit.sensitive'] = 'owner',

    ['staff.view'] = 'owner', ['staff.search'] = 'owner',
    ['staff.search_identifiers'] = 'owner', ['staff.history'] = 'owner',
    ['staff.role.assign'] = 'owner',

    ['economy.dollars.add'] = 'owner', ['economy.dollars.remove'] = 'owner',
    ['economy.gold.add'] = 'owner', ['economy.gold.remove'] = 'owner',
    ['economy.tokens.add'] = 'owner', ['economy.tokens.remove'] = 'owner',
    ['economy.xp.add'] = 'owner', ['economy.xp.remove'] = 'owner',
    ['character.restore_model'] = 'administrator',
    ['inventory.give'] = 'administrator', ['inventory.inspect'] = 'moderator',
    ['inventory.remove'] = 'administrator', ['inventory.manage'] = 'administrator',
    ['weapons.issue'] = 'owner', ['weapons.ammo.grant'] = 'administrator',

    ['booster.invincibility'] = 'administrator', ['booster.invisibility'] = 'administrator',
    ['booster.infinite_stamina'] = 'administrator', ['booster.heal'] = 'moderator',
    ['booster.revive'] = 'moderator', ['booster.kill'] = 'administrator',
    ['booster.disable_fow'] = 'administrator', ['booster.noclip'] = 'administrator',
    ['ped.change'] = 'administrator',

    ['developer.entity_inspector'] = 'administrator',
    ['developer.bone_viewer'] = 'administrator',
    ['developer.copy_coordinates'] = 'moderator',
    ['teleport.waypoint'] = 'moderator', ['teleport.auto_waypoint'] = 'moderator',
    ['teleport.coordinates'] = 'moderator',

    ['troll.lightning_strike'] = 'owner', ['troll.freeze'] = 'administrator',
    ['troll.teleport_to_heaven'] = 'owner', ['troll.cage'] = 'administrator',
    ['troll.force_cinematic_camera'] = 'administrator', ['troll.make_ped_giant'] = 'owner',
    ['troll.hostile_ped_army'] = 'owner', ['troll.handcuff'] = 'administrator',
    ['troll.kick_from_vehicle'] = 'administrator', ['troll.hostile_bear'] = 'owner',
    ['troll.lag'] = 'owner'
}
