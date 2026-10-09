Logger = {}

local RES = GetCurrentResourceName()
local LEVELS = { debug = 1, info = 2, warn = 3, error = 4, critical = 5 }
local LEVEL_COLOR = { warn = 0xF1C40F, error = 0xE74C3C, critical = 0x992D22 }
local LEVEL_ICON = { debug = '🐛', info = 'ℹ️', warn = '⚠️', error = '❌', critical = '🚨' }
local MAX_QUEUE = 20000

local q = { db = {}, file = {} }
local dq = {}                                  -- Discord-Queues je Webhook-URL
local known = { ['system.category'] = true }   -- bereits bekannte Kategorien
local pendingCats = {}                         -- neu aufgetauchte Kategorien
local cfgCache = {}
local rl = {}
local ready = false

---------------------------------------------------------------------------
-- Kategorie-Konfiguration (Vererbung ueber Punkte + Webhook-Auto-Zuordnung)
---------------------------------------------------------------------------
local function getCfg(category)
    local c = cfgCache[category]
    if c then return c end

    local parts = {}
    for p in category:gmatch('[^%.]+') do parts[#parts + 1] = p end

    local base
    for i = #parts, 1, -1 do
        base = Config.Categories[table.concat(parts, '.', 1, i)]
        if base then break end
    end
    local configured = base ~= nil
    base = base or {}

    c = setmetatable({}, {
        __index = function(_, k)
            local v = base[k]
            if v == nil then v = Config.Default[k] end
            return v
        end
    })

    -- Webhook: voller Link > benannter Eintrag > Webhook passend zum ersten Segment > default
    local url
    local w = base.webhook
    if w then
        if w:sub(1, 4) == 'http' then url = w
        elseif (Config.Webhooks[w] or '') ~= '' then url = Config.Webhooks[w] end
    end
    if not url and (Config.Webhooks[parts[1]] or '') ~= '' then url = Config.Webhooks[parts[1]] end
    if not url and (Config.Webhooks.default or '') ~= '' then url = Config.Webhooks.default end

    c.webhookUrl = url
    c.configured = configured
    c.labelText = base.label or (parts[1]:sub(1, 1):upper() .. parts[1]:sub(2))
    cfgCache[category] = c
    return c
end

local function push(queue, item)
    if #queue >= MAX_QUEUE then table.remove(queue, 1) end
    queue[#queue + 1] = item
end

---------------------------------------------------------------------------
-- Discord
---------------------------------------------------------------------------
local function buildEmbed(e, cfg)
    local fields = {}
    local function pinfo(p)
        local s = ('**%s**'):format(Utils.trunc(p.name or '?', 60))
        if p.id then s = s .. (' (ID %s)'):format(p.id) end
        if p.license and p.license ~= 'unknown' then s = s .. ('\n`%s`'):format(p.license) end
        return s
    end
    if e.actor then fields[#fields + 1] = { name = 'Spieler', value = pinfo(e.actor), inline = true } end
    if e.target then fields[#fields + 1] = { name = 'Ziel', value = pinfo(e.target), inline = true } end

    if e.raw then
        local keys = {}
        for k in pairs(e.raw) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for i = 1, math.min(#keys, 12) do
            local k = keys[i]
            fields[#fields + 1] = { name = Utils.trunc(k, 60), value = '`' .. Utils.trunc(Utils.fmt(e.raw[k]):gsub('`', "'"), 900) .. '`', inline = true }
        end
        if #keys > 12 then fields[#fields + 1] = { name = '…', value = ('+%d weitere Felder (siehe DB)'):format(#keys - 12) } end
    end

    return {
        title = ('%s %s'):format(LEVEL_ICON[e.level] or '', cfg.labelText),
        description = Utils.trunc(e.message, 1900),
        color = LEVEL_COLOR[e.level] or cfg.color or 0x95A5A6,
        fields = fields,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', e.ts),
        footer = { text = ('%s • %s'):format(Config.ServerName, e.category) },
    }
end

local function discordAllowed(category)
    local now = os.time()
    local r = rl[category]
    if not r or r.sec ~= now then r = { sec = now, n = 0 }; rl[category] = r end
    r.n = r.n + 1
    return r.n <= Config.DiscordMaxPerCategoryPerSecond
end

CreateThread(function()
    while true do
        Wait(1200)
        local now = GetGameTimer()
        for url, st in pairs(dq) do
            if #st.items > 0 and now >= (st.blockedUntil or 0) then
                local items, embeds, ping = {}, {}, false
                for i = 1, math.min(10, #st.items) do
                    local it = table.remove(st.items, 1)
                    items[i] = it
                    embeds[i] = it.embed
                    ping = ping or it.ping
                end
                local body = { username = Config.ServerName .. ' Logs', embeds = embeds }
                if ping and Config.PingOnCritical ~= '' then body.content = Config.PingOnCritical end

                PerformHttpRequest(url, function(status, resp)
                    if status == 429 then
                        local ok, d = pcall(json.decode, resp or '{}')
                        local wait = (ok and d and d.retry_after) or 2
                        st.blockedUntil = GetGameTimer() + math.ceil(wait * 1000) + 500
                        for i = #items, 1, -1 do table.insert(st.items, 1, items[i]) end
                    elseif status >= 400 or status == 0 then
                        print(('^1[central_logger] Discord-Fehler (HTTP %s) – Webhook pruefen^7'):format(status))
                    end
                end, 'POST', json.encode(body), { ['Content-Type'] = 'application/json' })
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Datenbank
---------------------------------------------------------------------------
local function flushDb()
    if #q.db == 0 then return end
    local batch = q.db
    q.db = {}

    local i = 1
    while i <= #batch do
        local ph, params = {}, {}
        local last = math.min(i + 199, #batch)
        for j = i, last do
            local e = batch[j]
            ph[#ph + 1] = '(FROM_UNIXTIME(?),?,?,?,?,?,?,?,?,?,?)'
            local a, t = e.actor or {}, e.target or {}
            params[#params + 1] = e.ts
            params[#params + 1] = e.category
            params[#params + 1] = e.level
            params[#params + 1] = e.message
            params[#params + 1] = a.license
            params[#params + 1] = a.name
            params[#params + 1] = a.id
            params[#params + 1] = t.license
            params[#params + 1] = t.name
            params[#params + 1] = e.data
            params[#params + 1] = e.resource
        end
        local res = MySQL.insert.await(
            'INSERT INTO central_logs (created_at, category, level, message, actor_license, actor_name, actor_id, target_license, target_name, data, resource) VALUES '
            .. table.concat(ph, ','), params)
        if not res then
            -- DB nicht erreichbar: zurueck in die Queue, naechster Versuch beim naechsten Flush
            for j = #batch, i, -1 do table.insert(q.db, 1, batch[j]) end
            while #q.db > MAX_QUEUE do table.remove(q.db, 1) end
            return
        end
        i = last + 1
    end
end

local function flushFile()
    if #q.file == 0 then return end
    local batch = q.file
    q.file = {}
    local lines = {}
    for _, e in ipairs(batch) do
        lines[#lines + 1] = Utils.encode({
            ts = e.ts, category = e.category, level = e.level, message = e.message,
            actor = e.actor, target = e.target, data = e.raw, resource = e.resource,
        })
    end
    local path = ('logs/%s.jsonl'):format(os.date('%Y-%m-%d'))
    local old = LoadResourceFile(RES, path) or ''
    SaveResourceFile(RES, path, old .. table.concat(lines, '\n') .. '\n', -1)
end

local function processPending()
    for cat, res in pairs(pendingCats) do
        pendingCats[cat] = nil
        if not known[cat] then
            known[cat] = true
            if Config.Storage.db then
                MySQL.insert('INSERT IGNORE INTO central_log_categories (name, resource) VALUES (?, ?)', { cat, res })
            end
            if Config.NotifyNewCategories and not getCfg(cat).configured then
                Logger.log('system.category', nil,
                    ('Neue Log-Kategorie erkannt: `%s`'):format(cat),
                    { category = cat, resource = res }, nil, RES)
            end
        end
    end
end

local function cleanup()
    if not Config.Storage.db or (Config.RetentionDays or 0) <= 0 then return end
    repeat
        local n = MySQL.update.await('DELETE FROM central_logs WHERE created_at < (NOW() - INTERVAL ? DAY) LIMIT 5000', { Config.RetentionDays }) or 0
        Wait(200)
    until n < 5000
end

MySQL.ready(function()
    if Config.Storage.db then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS central_logs (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
                created_at DATETIME NOT NULL,
                category VARCHAR(64) NOT NULL,
                level VARCHAR(10) NOT NULL,
                message TEXT,
                actor_license VARCHAR(80), actor_name VARCHAR(80), actor_id INT,
                target_license VARCHAR(80), target_name VARCHAR(80),
                data LONGTEXT,
                resource VARCHAR(64),
                INDEX idx_cat_time (category, created_at),
                INDEX idx_time (created_at),
                INDEX idx_actor (actor_license),
                INDEX idx_target (target_license)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS central_log_categories (
                name VARCHAR(64) NOT NULL PRIMARY KEY,
                resource VARCHAR(64),
                first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
        for _, row in ipairs(MySQL.query.await('SELECT name FROM central_log_categories') or {}) do
            known[row.name] = true
        end
    end
    ready = true
    CreateThread(function()
        while true do cleanup(); Wait(3600000) end
    end)
end)

CreateThread(function()
    while true do
        Wait(Config.Flush.db)
        if ready then
            processPending()
            if Config.Storage.db then flushDb() end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Flush.file)
        if Config.Storage.file then flushFile() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    if ready then processPending() end
    if Config.Storage.db then flushDb() end
    if Config.Storage.file then flushFile() end
end)

---------------------------------------------------------------------------
-- Kernfunktion
---------------------------------------------------------------------------
function Logger.log(category, source, message, data, opts, resource)
    category = Utils.sanitizeCategory(category)
    opts = type(opts) == 'table' and opts or {}
    local cfg = getCfg(category)

    local level = LEVELS[opts.level] and opts.level or 'info'
    if LEVELS[level] < LEVELS[cfg.minLevel] then return end

    if not known[category] and not pendingCats[category] then
        pendingCats[category] = resource or 'unknown'
    end

    local raw = type(data) == 'table' and data or (data ~= nil and { value = data } or nil)
    local enc = raw and Utils.encode(raw) or nil
    if enc and #enc > 8000 then enc = Utils.encode({ _truncated = true, preview = enc:sub(1, 7900) }) end

    local e = {
        ts = os.time(), category = category, level = level,
        message = Utils.trunc(message, 1000),
        actor = Utils.playerInfo(source), target = Utils.playerInfo(opts.target),
        data = enc, raw = raw, resource = resource,
    }

    if Config.PrintToConsole then
        print(('[LOG][%s][%s] %s'):format(level, category, e.message))
    end

    if Config.Storage.db and cfg.db then push(q.db, e) end
    if Config.Storage.file and cfg.file then push(q.file, e) end

    if Config.Storage.discord and cfg.discord and cfg.webhookUrl
        and LEVELS[level] >= LEVELS[cfg.discordMinLevel] and discordAllowed(category) then
        local st = dq[cfg.webhookUrl]
        if not st then st = { items = {} }; dq[cfg.webhookUrl] = st end
        push(st.items, { embed = buildEmbed(e, cfg), ping = level == 'critical' })
    end
end

---------------------------------------------------------------------------
-- Schnittstellen fuer andere Ressourcen
---------------------------------------------------------------------------
-- 1) exports['central_logger']:Log(category, source, message, data, opts)
exports('Log', function(category, source, message, data, opts)
    Logger.log(category, source, message, data, opts, GetInvokingResource())
end)

-- 2) TriggerEvent('central_logger:log', category, source, message, data, opts)  (nur serverseitig, nicht von Clients aufrufbar)
AddEventHandler('central_logger:log', function(category, src, message, data, opts)
    Logger.log(category, src, message, data, opts, GetInvokingResource())
end)

-- 3) Optional: Kategorie zur Laufzeit konfigurieren (z.B. eigener Webhook)
exports('RegisterCategory', function(name, cfg)
    Config.Categories[Utils.sanitizeCategory(name)] = cfg
    cfgCache = {}
end)

exports('GetCategories', function()
    local t = {}
    for k in pairs(known) do t[#t + 1] = k end
    table.sort(t)
    return t
end)

-- 4) Clients (Prefix "client." erzwungen, Rate-Limit)
local clientRate = {}
RegisterNetEvent('central_logger:clientLog', function(category, message, data)
    local src = source
    if not Config.ClientLogs.enabled then return end
    local now = os.time()
    local r = clientRate[src]
    if not r or r.sec ~= now then r = { sec = now, n = 0 }; clientRate[src] = r end
    r.n = r.n + 1
    if r.n > Config.ClientLogs.perSecond then return end
    if type(category) ~= 'string' or type(message) ~= 'string' then return end
    Logger.log('client.' .. category, src, Utils.trunc(message, 300),
        type(data) == 'table' and data or nil, nil, 'client')
end)

AddEventHandler('playerDropped', function() clientRate[source] = nil end)
