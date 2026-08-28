fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'feather-admin'
description 'The official Admin menu for the Feather Framework'
author 'BCC Scripts'
version '0.5.0'

github_version_check 'true'
github_version_type 'release'
github_ui_check 'false'
github_link 'https://github.com/FeatherFramework/feather-admin'

ui_page 'web/noclip.html'

files {
    'web/noclip.html'
}

shared_scripts {
    'configs/config.lua',
    'configs/hierarchy.lua',
    'configs/permissions.lua'
}

client_scripts {
    'client/core/init.lua',
    'client/core/runtime.lua',
    'client/core/teleport.lua',
    'translations/*.lua',
    'client/ui/menu.lua',
    'client/ui/navigation.lua',
    'client/services/*.lua',
    'client/ui/pages/players.lua',
    'client/ui/pages/ped_changer.lua',
    'client/ui/pages/boosters.lua',
    'client/ui/pages/developer_tools.lua',
    'client/ui/pages/character_administration.lua',
    'client/ui/pages/inventory.lua',
    'client/ui/pages/staff_management.lua',
    'client/ui/pages/player_management.lua',
    'client/ui/pages/teleports.lua',
    'client/ui/pages/trolls.lua',
    'client/ui/pages/appearance.lua',
    'client/ui/pages/self_tools.lua',
    'client/ui/pages/moderation.lua',
    'client/ui/pages/audit_logs.lua',
    'client/ui/pages/server_overview.lua',
    'client/ui/pages/announcements.lua',
    'client/ui/pages/active_bans.lua',
    'client/ui/pages/reports.lua',
    'client/ui/pages/cases.lua',
    'client/ui/pages/player_notes.lua',
    'client/ui/pages/weapons_admin.lua',
    'client/ui/pages/main.lua',
    'client/core/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core/init.lua',
    'server/database.lua',
    'server/services/*.lua'
}

dependencies {
    'oxmysql',
    'feather-core',
    'feather-inventory',
    'feather-menu'
}
