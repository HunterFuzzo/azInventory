fx_version 'cerulean'
game 'gta5'

author 'az_inventory'
description 'AZ Inventory – GLife Extinction Style Inventory for ESX Legacy'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@oxmysql/lib/MySQL.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/items/*.png'
}