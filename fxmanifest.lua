fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'central_logger'
description 'Zentrales Logging-System (DB + Discord + Datei) mit automatischer Kategorie-Erkennung'
version '1.0.2'

dependency 'oxmysql'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/utils.lua',
    'server/core.lua',
    'server/auto.lua',
    'server/adapters.lua',
    'server/commands.lua',
}

client_script 'client/main.lua'

-- shared/logger.lua wird NICHT hier geladen, sondern von anderen Ressourcen per
-- shared_script '@central_logger/shared/logger.lua'
files { 'shared/logger.lua' }
