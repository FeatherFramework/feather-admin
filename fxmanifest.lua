fx_version "adamant"
games {"rdr3"}
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."

lua54 "yes"

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

dependency = {
  'vorp_menu'
}