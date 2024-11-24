fx_version 'cerulean'
game 'gta5'

author 'ItWasD'
description 'Nearest Postal System with NUI Integration using the original postal code from Devblocky'
version '1.0.0'

lua54 'yes'

shared_script '@ox_lib/init.lua'

client_script 'cl.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'sv.lua'
}

ui_page 'postal_ui.html'

files {
    'postal_ui.html',
    'style.css',
    'script.js',
    'new-postals.json',
}
