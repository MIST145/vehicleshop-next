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
    -- Explicit ordering: main.lua must run first so VehShop = {} exists before
    -- display.lua, management.lua, and warehouse.lua assign into it.
    -- Glob expansion on Linux uses inode (creation) order, NOT alphabetical,
    -- so 'modules/client/*.lua' is unsafe — always enumerate explicitly.
    'modules/client/main.lua',
    'modules/client/display.lua',
    'modules/client/management.lua',
    'modules/client/warehouse.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/*.lua',
    'modules/server/*.lua',
}
