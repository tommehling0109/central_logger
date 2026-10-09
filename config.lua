Config = {}

Config.ServerName = 'Mein Server'

-- Webhooks. Leer lassen = Kanal deaktiviert (faellt dann auf "default" zurueck).
-- Neues Feature "casino"? Einfach hier `casino = 'https://...'` ergaenzen -> alle
-- Kategorien "casino", "casino.roulette", ... landen automatisch dort.
Config.Webhooks = {
    default    = '',
    system     = '',
    connection = '',
    chat       = '',
    death      = '',
    money      = '',
    item       = '',
    admin      = '',
    job        = '',
    security   = '',
}

-- Wohin wird geschrieben?
Config.Storage = {
    db      = true,   -- MySQL (empfohlen, Hauptspeicher, durchsuchbar mit /logs)
    discord = true,
    file    = false,  -- zusaetzliches Backup: logs/YYYY-MM-DD.jsonl im Resource-Ordner
}

-- Standardwerte fuer JEDE Kategorie (auch unbekannte/neue)
Config.Default = {
    webhook         = 'default',
    color           = 0x95A5A6,
    minLevel        = 'info',   -- darunter wird gar nicht gespeichert (debug < info < warn < error < critical)
    discordMinLevel = 'info',
    db              = true,
    discord         = true,
    file            = true,     -- wirkt nur wenn Config.Storage.file = true
}

-- Optionale Feinabstimmung. Vererbung ueber Punkte: "money.bank" erbt von "money",
-- ein spezifischerer Eintrag ("security.explosion") ueberschreibt den allgemeinen.
Config.Categories = {
    system              = { label = 'System',        webhook = 'system',     color = 0x7F8C8D },
    ['system.resource'] = { discord = false },
    connection          = { label = 'Verbindung',    webhook = 'connection', color = 0x3498DB },
    chat                = { label = 'Chat',          webhook = 'chat',       color = 0x2ECC71, discord = false },
    ['chat.command']    = { discord = true },
    death               = { label = 'Tod / Kill',    webhook = 'death',      color = 0xE74C3C },
    money               = { label = 'Geld',          webhook = 'money',      color = 0xF1C40F },
    ['money.change']    = { discordMinLevel = 'warn' },  -- jede Kleinigkeit nur in die DB, grosse Betraege nach Discord
    item                = { label = 'Items',         webhook = 'item',       color = 0x9B59B6 },
    ['item.move']       = { discord = false },
    job                 = { label = 'Jobs',          webhook = 'job',        color = 0x1ABC9C },
    admin               = { label = 'Admin',         webhook = 'admin',      color = 0xE67E22, minLevel = 'debug' },
    security            = { label = 'Sicherheit',    webhook = 'security',   color = 0xC0392B },
    ['security.explosion'] = { discord = false },
}

-- Meldung im System-Kanal, wenn zum ersten Mal eine unbekannte Kategorie auftaucht
Config.NotifyNewCategories = true

Config.Flush = { db = 2000, file = 10000 }      -- ms
Config.RetentionDays = 60                        -- 0 = nie loeschen
Config.DiscordMaxPerCategoryPerSecond = 10       -- Spam-Schutz, DB bekommt trotzdem alles
Config.PingOnCritical = ''                       -- z.B. '<@&123456789>' oder '@here'
Config.PrintToConsole = false

-- Logs, die Clients selbst senden duerfen (immer mit Prefix "client.")
Config.ClientLogs = { enabled = true, perSecond = 3 }

-- Diese Chat-Commands werden NICHT geloggt (Passwoerter etc.)
Config.HiddenCommands = { 'login', 'register', 'password', 'pin' }

-- Geld-Ueberwachung per Vergleich (faengt JEDE Aenderung, auch von zukuenftigen Features; ESX)
Config.MoneyWatcher = {
    enabled    = true,
    interval   = 5000,
    minDelta   = 1,       -- ab dieser Aenderung loggen
    largeDelta = 50000,   -- ab hier Level "warn" -> Discord
}
