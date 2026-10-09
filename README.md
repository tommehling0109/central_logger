# central_logger – Zentrales Logging für FiveM

## Installation
1. Ordner `central_logger` nach `resources/` kopieren (oxmysql muss laufen).
2. In `server.cfg`: `ensure oxmysql` und **danach als eine der ersten Ressourcen** `ensure central_logger`.
3. In `config.lua` die Discord-Webhooks eintragen (leer = Kanal aus). Tabellen werden automatisch angelegt.
4. Rechte für die Abfrage-Commands:
   ```
   add_ace group.admin command.logs allow
   add_ace group.admin command.logcats allow
   ```

## Was wird automatisch geloggt (ohne Anpassung anderer Skripte)?
| Kategorie | Inhalt |
|---|---|
| `connection.*` | Verbinden, Trennen (mit Grund), ESX-Charakter geladen |
| `chat.message` / `chat.command` | Chat und Commands (Passwort-Commands maskiert, siehe `HiddenCommands`) |
| `death.*` | Tode/Kills (benötigt `baseevents`) |
| `money.change` | ESX: jede Kontoänderung per Watcher (auch von zukünftigen Features!), QBCore: per Event inkl. Grund |
| `item.move` | ox_inventory: Items zwischen Inventaren (Spieler↔Spieler/Drop/Lager/Kofferraum) |
| `job.*` | Jobwechsel (ESX/QBCore), Gangs (QBCore) |
| `admin.*` | Rang-Änderungen (`esx:setGroup`), txAdmin Kick/Ban/Warn/Announcement |
| `security.explosion` | Explosionen |
| `system.*` | Ressource Start/Stop, Restarts, neue Log-Kategorien |

## Neues Feature loggen – eine Zeile, nichts am Logger ändern
In der `fxmanifest.lua` des Features:
```lua
shared_script '@central_logger/shared/logger.lua'
```
Danach im Server-Code:
```lua
CLog('casino.roulette', source, 'Hat 5000$ gesetzt', { bet = 5000, color = 'red' })
CLog('casino.roulette', source, 'Gewonnen', { win = 10000 }, { level = 'warn', target = otherSource })
```
Im Client-Code (landet als `client.<kategorie>`, rate-limitiert):
```lua
CLog('casino.joined', 'Tisch betreten', { table = 3 })
```
Ohne Helper geht es auch: `exports.central_logger:Log(cat, src, msg, data, opts)` oder
`TriggerEvent('central_logger:log', cat, src, msg, data, opts)`.

**Was dann automatisch passiert:**
- Unbekannte Kategorie → wird sofort in die DB geschrieben und in `central_log_categories` registriert.
- Im System-Kanal erscheint einmalig „Neue Log-Kategorie erkannt“ (Ressource steht dabei).
- Discord-Kanal wird per Namen zugeordnet: gibt es `Config.Webhooks.casino`, gehen `casino`, `casino.roulette` usw. dorthin, sonst in `default`.
- Eigene Einstellung nur bei Bedarf: `Config.Categories['casino'] = { label = 'Casino', color = 0xFF0000 }`. Unterkategorien erben von Oberkategorien, spezifischere Einträge überschreiben.
- Läuft `central_logger` nicht, passiert im aufrufenden Skript nichts (kein Fehler).

`opts`: `level` (`debug`/`info`/`warn`/`error`/`critical`), `target` (zweiter Spieler: ID, `license:...`-String oder Name).

## Abfragen
- Ingame/Konsole: `/logs money 30 Max` (Kategorie-Prefix, Anzahl, Spielername/License), `/logcats`
- SQL: `SELECT * FROM central_logs WHERE actor_license = 'license:...' ORDER BY id DESC;` – `data` ist JSON.
- Aufbewahrung: `Config.RetentionDays` (Standard 60 Tage, wird stündlich automatisch bereinigt).

## Hinweise
- DB-Schreiben ist gebatcht (alle 2 s), Discord ist rate-limit-sicher (10 Embeds pro Nachricht, 429-Retry).
- Bei DB-Ausfall werden Logs zwischengepuffert (max. 20.000) und nachgeschrieben.
- Client-Logs sind fälschbar → nur für Komfort, nicht für Beweise. Gleiches gilt für `baseevents`-Tode.
- Ereignisnamen der Frameworks (`esx:setGroup`, `QBCore:Server:OnMoneyChange` …) können je nach Version abweichen → in `server/adapters.lua` prüfen.
- Rang-Änderungen über reines ACE (`add_principal`) lassen sich nicht abfangen; dafür den Befehl/Admin-Menü-Code mit `CLog('admin.rank', ...)` versehen.
