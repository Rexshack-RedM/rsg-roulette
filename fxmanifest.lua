fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'RexShack'
name 'rsg-roulette'
description 'Multiplayer roulette tables for RSG Framework'
version '3.0.1'

ui_page 'web/build/index.html'

files {
    'web/build/**/*',
    'locales/*.json',
}

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

dependencies {
    'rsg-core',
    'oxmysql',
    'rsg-target',
}
