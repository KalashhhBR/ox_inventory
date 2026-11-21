fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
name 'ox_inventory'
author 'Overextended'
version '2.48.1'
klsh_version '0.27.0' -- klsh: fork version (SemVer), upstream base above
repository 'https://github.com/KalashhhBR/ox_inventory' -- klsh: fork of https://github.com/overextended/ox_inventory
description 'Grid inventory with clothing as items (klsh fork of ox_inventory)'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
}

shared_script '@ox_lib/init.lua'

ox_libs {
    'locale',
    'table',
    'math',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua'
}

client_script 'init.lua'

ui_page 'web/build/index.html'

files {
    'client.lua',
    'server.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/*.js', -- klsh: flat build output
    'web/build/*.css',
    'web/build/*.woff2', -- klsh: fonts bundled with the NUI (0.24.2)
    'web/images/*.png',
    'modules/**/shared.lua',
    'modules/**/client.lua',
    'modules/bridge/**/client.lua',
    'data/*.lua',
}
