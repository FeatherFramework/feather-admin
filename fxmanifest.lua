fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'feather-admin'
description 'The official Admin menu for the Feather Framework'
author 'BCC Scripts'
version '0.2.0'

github_version_check 'true'
github_version_type 'release'
github_ui_check 'false'
github_link 'https://github.com/FeatherFramework/feather-admin'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/core/init.lua',
    'translations/*.lua',
    'client/ui/menu.lua',
    'client/services/*.lua',
    'client/ui/pages/players.lua',
    'client/ui/pages/ped_changer.lua',
    'client/ui/pages/boosters.lua',
    'client/ui/pages/developer_tools.lua',
    'client/ui/pages/teleports.lua',
    'client/ui/pages/trolls.lua',
    'client/ui/pages/main.lua',
    'client/core/main.lua'
}

server_scripts {
    'server/core/init.lua',
    'server/services/*.lua'
}

dependencies {
    'feather-core',
    'feather-menu'
}
