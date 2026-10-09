-- Eingebaute Hooks: laufen ohne jede Anpassung in anderen Ressourcen
local RES = GetCurrentResourceName()
local function log(...) Logger.log(...) end

-- Verbindungen ---------------------------------------------------------------
AddEventHandler('playerConnecting', function(name)
    local src = source
    log('connection.connect', src, ('%s verbindet sich'):format(name), nil, nil, RES)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    log('connection.disconnect', src, ('Getrennt: %s'):format(reason or '-'), { reason = reason }, nil, RES)
end)

-- Chat & Commands --------------------------------------------------------------
AddEventHandler('chatMessage', function(src, name, msg)
    if type(msg) ~= 'string' then return end
    if msg:sub(1, 1) == '/' then
        local cmd = msg:match('^/(%S+)') or ''
        for _, hidden in ipairs(Config.HiddenCommands) do
            if cmd:lower() == hidden then msg = '/' .. cmd .. ' [versteckt]'; break end
        end
        log('chat.command', src, msg, nil, nil, RES)
    else
        log('chat.message', src, msg, nil, nil, RES)
    end
end)

-- Tode (baseevents, falls aktiv) -----------------------------------------------
RegisterNetEvent('baseevents:onPlayerDied', function(killerType, coords)
    log('death.died', source, 'Spieler gestorben', { killerType = killerType, coords = coords }, nil, RES)
end)

RegisterNetEvent('baseevents:onPlayerKilled', function(killerId, data)
    local src = source
    log('death.killed', killerId, 'Spieler getoetet', data, { target = src }, RES)
end)

-- Explosionen ------------------------------------------------------------------
AddEventHandler('explosionEvent', function(sender, ev)
    log('security.explosion', sender, 'Explosion erzeugt', {
        type = ev.explosionType, x = ev.posX, y = ev.posY, z = ev.posZ,
        damageScale = ev.damageScale, isInvisible = ev.isInvisible,
    }, { level = 'warn' }, RES)
end)

-- Ressourcen -------------------------------------------------------------------
AddEventHandler('onResourceStart', function(res)
    if res ~= RES then log('system.resource', nil, ('Ressource gestartet: %s'):format(res), nil, nil, RES) end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= RES then log('system.resource', nil, ('Ressource gestoppt: %s'):format(res), nil, { level = 'warn' }, RES) end
end)

-- txAdmin (Kicks, Bans, Warns, Ankuendigungen, Restarts) -------------------------------
AddEventHandler('txAdmin:events:playerKicked', function(d)
    log('admin.kick', d.target, ('Kick durch %s: %s'):format(d.author or '?', d.reason or '-'), d, { level = 'warn' }, 'txAdmin')
end)
AddEventHandler('txAdmin:events:playerBanned', function(d)
    log('admin.ban', d.targetNetId or d.targetName, ('Ban durch %s: %s'):format(d.author or '?', d.reason or '-'), d, { level = 'warn' }, 'txAdmin')
end)
AddEventHandler('txAdmin:events:playerWarned', function(d)
    log('admin.warn', d.targetNetId or d.targetName, ('Warnung durch %s: %s'):format(d.author or '?', d.reason or '-'), d, nil, 'txAdmin')
end)
AddEventHandler('txAdmin:events:announcement', function(d)
    log('admin.announcement', d.author, d.message or '-', d, nil, 'txAdmin')
end)
AddEventHandler('txAdmin:events:scheduledRestart', function(d)
    log('system.restart', nil, ('Geplanter Restart in %s s'):format(d.secondsRemaining or '?'), d, { level = 'warn' }, 'txAdmin')
end)
AddEventHandler('txAdmin:events:serverShuttingDown', function(d)
    log('system.shutdown', nil, 'Server faehrt herunter', d, { level = 'warn' }, 'txAdmin')
end)
