-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'MF, updated by JericoFX'
name 'vehicleshops'
description 'Player-Owned Vehicle Shops — ESX-Legacy / QBCore / QBox'
version '2.1.0'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'customs.lua',
    'bridge/detect.lua',
}

client_scripts {
    'bridge/client/*.lua',
    'modules/client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/*.lua',
    'modules/server/*.lua',
}