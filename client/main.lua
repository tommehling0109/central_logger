-- Ausgabe der /logs-Ergebnisse in der F8-Konsole (unabhaengig vom Chat-Resource)
RegisterNetEvent('central_logger:print', function(lines)
    if type(lines) ~= 'table' then return end
    for _, l in ipairs(lines) do print('^3[LOG]^7 ' .. tostring(l)) end
    print('^3[LOG]^7 --- ' .. #lines .. ' Eintraege ---')
end)
