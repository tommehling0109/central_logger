Utils = {}

function Utils.trunc(s, n)
    s = tostring(s == nil and '' or s)
    if #s > n then return s:sub(1, n - 3) .. '...' end
    return s
end

function Utils.encode(t)
    local ok, r = pcall(json.encode, t)
    if ok then return r end
    return tostring(t)
end

function Utils.fmt(v)
    if type(v) == 'table' then return Utils.encode(v) end
    return tostring(v)
end

function Utils.sanitizeCategory(c)
    c = tostring(c or 'misc'):lower()
    c = c:gsub('[^%w_%.%-]', '_')
    c = c:gsub('^%.+', ''):gsub('%.+$', '')
    if c == '' then c = 'misc' end
    return c:sub(1, 64)
end

function Utils.idsOf(src)
    local t = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        local k, v = id:match('^(%w+):(.+)$')
        if k then t[k] = v end
    end
    return t
end

-- Akzeptiert: Server-ID, Identifier-String ("license:..."), beliebigen Namen ("Console") oder Tabelle {name=,license=,id=}
function Utils.playerInfo(p)
    if p == nil then return nil end
    if type(p) == 'table' then return p end
    local n = tonumber(p)
    if n then
        if n <= 0 then return nil end
        if GetPlayerName(n) then
            local ids = Utils.idsOf(n)
            local lic = ids.license2 or ids.license
            return {
                id = n, name = GetPlayerName(n),
                license = lic and ('license:' .. lic) or 'unknown',
                discord = ids.discord,
            }
        end
        return { id = n, name = 'Offline', license = 'unknown' }
    end
    if type(p) == 'string' then
        if p:match('^%w+:') then return { name = p, license = p } end
        return { name = p, license = 'unknown' }
    end
end
