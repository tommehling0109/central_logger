-- Framework-Adapter. Events sind harmlos, wenn das Framework nicht laeuft.
-- Ereignisnamen koennen je nach Framework-Version abweichen -> bei Bedarf hier anpassen.
local function log(...) Logger.log(...) end

-- ESX ------------------------------------------------------------------------
AddEventHandler('esx:playerLoaded', function(playerId)
    log('connection.loaded', playerId, 'Charakter geladen', nil, nil, 'es_extended')
end)
AddEventHandler('esx:setJob', function(src, job, last)
    log('job.change', src, ('Job: %s -> %s'):format(last and last.name or '?', job and job.name or '?'),
        { new = job and { name = job.name, grade = job.grade }, old = last and { name = last.name, grade = last.grade } }, nil, 'es_extended')
end)
-- Admin-/Gruppenrang
AddEventHandler('esx:setGroup', function(src, group, last)
    log('admin.rank', src, ('Rang: %s -> %s'):format(last or '?', group or '?'), { new = group, old = last }, { level = 'warn' }, 'es_extended')
end)

-- QBCore ---------------------------------------------------------------------
AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, action, reason)
    local large = (tonumber(amount) or 0) >= Config.MoneyWatcher.largeDelta
    log('money.change', src, ('%s %s: %s (%s)'):format(moneyType, action, amount, reason or '-'),
        { account = moneyType, amount = amount, action = action, reason = reason },
        { level = large and 'warn' or 'info' }, 'qb-core')
end)
AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    log('job.change', src, ('Neuer Job: %s'):format(job and job.name or '?'), job, nil, 'qb-core')
end)
AddEventHandler('QBCore:Server:OnGangUpdate', function(src, gang)
    log('job.gang', src, ('Neue Gang: %s'):format(gang and gang.name or '?'), gang, nil, 'qb-core')
end)

-- ESX Geld-Watcher: erkennt JEDE Kontoaenderung, auch von kuenftigen Features --------
local W = Config.MoneyWatcher
if W.enabled then
    local last = {}
    AddEventHandler('playerDropped', function() last[source] = nil end)

    CreateThread(function()
        local ESX
        while true do
            Wait(W.interval)
            if GetResourceState('es_extended') == 'started' then
                ESX = ESX or exports['es_extended']:getSharedObject()
                for _, s in ipairs(GetPlayers()) do
                    local src = tonumber(s)
                    local xp = ESX.GetPlayerFromId(src)
                    if xp then
                        local snap = {}
                        for _, acc in ipairs(xp.getAccounts()) do snap[acc.name] = acc.money end
                        local prev = last[src]
                        if prev then
                            for name, now in pairs(snap) do
                                local delta = now - (prev[name] or now)
                                if math.abs(delta) >= W.minDelta then
                                    log('money.change', src,
                                        ('%s: %s%d (Stand %d)'):format(name, delta > 0 and '+' or '', delta, now),
                                        { account = name, before = prev[name], after = now, delta = delta },
                                        { level = math.abs(delta) >= W.largeDelta and 'warn' or 'info' }, 'es_extended')
                                end
                            end
                        end
                        last[src] = snap
                    end
                end
            end
        end
    end)
end

-- ox_inventory: Item-Bewegungen zwischen Inventaren (Spieler <-> Spieler/Drop/Lager/Kofferraum) ---
local hooked = false
local function hookOx()
    if hooked or GetResourceState('ox_inventory') ~= 'started' then return end
    local ok = pcall(function()
        exports.ox_inventory:registerHook('swapItems', function(p)
            if tostring(p.fromInventory) ~= tostring(p.toInventory) then
                local item = p.fromSlot and p.fromSlot.name or '?'
                local who = tonumber(p.source)
                local other = (p.fromType == 'player' and tonumber(p.fromInventory) ~= who) and p.fromInventory
                    or (p.toType == 'player' and tonumber(p.toInventory) ~= who) and p.toInventory or nil
                Logger.log('item.move', who,
                    ('%dx %s: %s (%s) -> %s (%s)'):format(p.count or 0, item, p.fromType, p.fromInventory, p.toType, p.toInventory),
                    { item = item, count = p.count, from = p.fromInventory, to = p.toInventory, fromType = p.fromType, toType = p.toType },
                    { target = other }, 'ox_inventory')
            end
            -- nil zurueckgeben = Aktion nicht blockieren
        end, {})
        hooked = true
    end)
    if not ok then print('^3[central_logger] ox_inventory-Hook konnte nicht registriert werden^7') end
end
AddEventHandler('onServerResourceStart', function(res) if res == 'ox_inventory' then SetTimeout(1000, hookOx) end end)
CreateThread(function() Wait(2000); hookOx() end)
