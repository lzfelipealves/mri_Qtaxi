fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'mri_Qtaxi - Sistema de Taxista'
author 'MRI QBOX Team'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/taxi.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/voice/**/*.mp3',
    'html/voice/*.mp3',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_target',
}
