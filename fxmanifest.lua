fx_version "adamant"
games { "rdr3" }
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."
lua54 "yes"

description 'The official Admin menu for the Feather Framework'
author 'BCC Scripts'
name 'feather-admin'
version '0.1.0'

github_version_check 'true'
github_version_type 'release'
github_ui_check 'false'
github_link 'https://github.com/FeatherFramework/feather-admin'

shared_scripts {
  "config.lua"
}

server_scripts {
  '/server/helpers/allPlayersCatch.lua',
  '/server/helpers/*.lua',
  '/server/services/*.lua',
  "/server/main.lua"
}

client_scripts {
  "/client/helpers/functions.lua",
  '/client/helpers/*.lua',
  "/client/main.lua",
  "/client/services/*.lua"
}

dependencies {
  'feather-core',
  'menuapi'
}