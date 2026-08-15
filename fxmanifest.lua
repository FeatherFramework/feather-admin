fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'feather-admin'
description 'The official Admin menu for the Feather Framework'
author 'BCC Team'
version '0.2.0'

github_version_check 'true'
github_version_type 'release'
github_ui_check 'false'
github_link 'https://github.com/FeatherFramework/feather-admin'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/init.lua',
    'client/main.lua',
    'translations/*.lua',
    'client/services/*.lua'
}

server_scripts {
    'server/main.lua',
    'server/helpers/*.lua'
}

dependencies {
    'feather-core',
    'feather-menu'
}
