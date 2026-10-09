-- In andere Ressourcen einbinden:  shared_script '@central_logger/shared/logger.lua'
--
-- Server:  CLog('money.bank', source, 'Einzahlung', { amount = 500 }, { target = otherSrc, level = 'warn' })
-- Client:  CLog('mein_feature.aktion', 'Text', { foo = 1 })      (landet als "client.mein_feature.aktion")
--
-- Laeuft central_logger nicht, passiert einfach nichts (kein Fehler).

local RES = 'central_logger'

if IsDuplicityVersion() then
    function CLog(category, source, message, data, opts)
        if GetResourceState(RES) ~= 'started' then return end
        exports[RES]:Log(category, source, message, data, opts)
    end
else
    function CLog(category, message, data)
        TriggerServerEvent('central_logger:clientLog', category, message, data)
    end
end
