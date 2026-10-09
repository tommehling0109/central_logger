-- /logs <kategorie|*> [anzahl] [spieler]   z.B.  /logs money 30 Max   |   /logcats
-- Berechtigung:  add_ace group.admin command.logs allow  /  add_ace group.admin command.logcats allow
-- Ausgabe laut Config.OutputMode: 'console' (F8), 'chat' (chat:addMessage), 'legacy' (chatMessage-Event)
local function emit(src, lines)
    if src == 0 then
        for _, l in ipairs(lines) do print(l) end
    elseif Config.OutputMode == 'chat' then
        for _, l in ipairs(lines) do TriggerClientEvent('chat:addMessage', src, { color = { 255, 200, 0 }, multiline = true, args = { 'LOG', l } }) end
    elseif Config.OutputMode == 'legacy' then
        for _, l in ipairs(lines) do TriggerClientEvent('chatMessage', src, 'LOG', { 255, 200, 0 }, l) end
    else
        TriggerClientEvent('central_logger:print', src, lines)
    end
end

RegisterCommand('logs', function(src, args)
    local cat = args[1] or '*'
    local limit = math.min(tonumber(args[2]) or 20, src == 0 and 200 or 15)
    local sql = 'SELECT created_at, category, level, message, actor_name FROM central_logs WHERE category LIKE ?'
    local params = { cat == '*' and '%' or (cat .. '%') }
    if args[3] then
        sql = sql .. ' AND (actor_name LIKE ? OR actor_license LIKE ? OR target_name LIKE ? OR target_license LIKE ?)'
        for _ = 1, 4 do params[#params + 1] = '%' .. args[3] .. '%' end
    end
    sql = sql .. ' ORDER BY id DESC LIMIT ' .. limit

    local rows = MySQL.query.await(sql, params) or {}
    if #rows == 0 then return emit(src, { 'Keine Eintraege gefunden.' }) end
    local lines = {}
    for i = #rows, 1, -1 do
        local r = rows[i]
        local t = type(r.created_at) == 'number' and os.date('%d.%m %H:%M:%S', math.floor(r.created_at / 1000)) or tostring(r.created_at)
        lines[#lines + 1] = ('%s [%s] %s%s: %s'):format(t, r.level, r.category, r.actor_name and (' (' .. r.actor_name .. ')') or '', r.message)
    end
    emit(src, lines)
end, true)

RegisterCommand('logcats', function(src)
    emit(src, { 'Bekannte Kategorien: ' .. table.concat(exports[GetCurrentResourceName()]:GetCategories(), ', ') })
end, true)
