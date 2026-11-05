-- SeasonalProduction
-- Saisonale Produktion (Teil des Feld Managers).
-- Schritt 1: Alle Produktionen der Karte einmal erfassen, einordnen (saisonal / Gewächshaus / unverändert)
-- und eine Übersicht ins Log schreiben. Noch KEIN Eingriff in die Produktion.

SeasonalProduction = {}
SeasonalProduction.modName = g_currentModName

-- Vorgabe: Saison der Hauptware (Kalendermonate 1 = Januar .. 12 = Dezember), später in der Konfiguration änderbar
SeasonalProduction.SEASONS = {
    STRAWBERRY = { from = 5, to = 7 },
    PUMPKIN    = { from = 9, to = 10 },
    CHERRY     = { from = 6, to = 7 },
    APPLE      = { from = 8, to = 10 },
    GRAPE      = { from = 9, to = 10 },
    HONEY      = { from = 4, to = 9 },
    -- Annahmen, bitte pruefen / in der Konfiguration anpassen
    PEAR       = { from = 8, to = 10 },
    PLUM       = { from = 7, to = 9 },
    PEACH      = { from = 7, to = 8 },
    MIRABELLES = { from = 8, to = 9 },
    HOPS       = { from = 8, to = 9 },
    CURRANTS   = { from = 6, to = 7 },
    BLACKBERRY = { from = 8, to = 9 },
    RASPBERRY  = { from = 7, to = 8 },
    OLIVE      = { from = 11, to = 2 },
    TURF       = { from = 4, to = 10 },
}

-- Ausnahmen nach Dateiname (Hauptware ist dort kein echter Fruchttyp, z. B. Tannenbaeume = CASH)
SeasonalProduction.FILE_SEASONS = {
    ["feld_tannenbaum.xml"] = { from = 11, to = 12 },
}

-- Rubriken des Baumenüs, die als Anbau gelten (Vorgabe)
SeasonalProduction.CULTIVATION_TABS = { cultivation = true }
-- Rubriken bzw. Typen, die ganzjährig laufen
SeasonalProduction.YEAR_ROUND_TABS = { greenhouses = true, greenhouse = true }

-- Reihenfolge und Darstellung im Erntekalender (Seite 5 im Menue)
SeasonalProduction.CALENDAR = {
    { fill = "STRAWBERRY" }, { fill = "CURRANTS" }, { fill = "CHERRY" }, { fill = "RASPBERRY" },
    { fill = "PEACH" }, { fill = "PLUM" }, { fill = "APPLE" }, { fill = "PEAR" }, { fill = "MIRABELLES" },
    { fill = "BLACKBERRY" }, { fill = "HOPS" }, { fill = "PUMPKIN" }, { fill = "GRAPE" }, { fill = "OLIVE" },
    { fill = "TURF" },
    { fill = "CASH", file = "feld_tannenbaum.xml", l10n = "season_trees", icons = { "CHRISTMASTREE", "TREE", "WOOD" } },
}

-- Option aus den Einstellungen des Feld Managers (nur der Host ändert sie)
function SeasonalProduction.isEnabled()
    return FieldListHUD ~= nil and FieldListHUD.seasonal == true
end

SeasonalProduction.scanned = false
SeasonalProduction.waited = 0
SeasonalProduction.info = {}

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function fillName(idx)
    if idx == nil then return nil end
    local ok, n = pcall(function() return g_fillTypeManager:getFillTypeNameByIndex(idx) end)
    return ok and n or nil
end

local function listNames(list)
    local out = {}
    for _, e in pairs(list or {}) do
        local n = fillName(e.type)
        if n ~= nil then out[#out + 1] = n end
    end
    table.sort(out)
    return out
end

-- Alle Produktionsstellen der Karte (eigene und fremde Höfe)
function SeasonalProduction.getAllPoints()
    local result, seen = {}, {}
    local function add(pp)
        if pp ~= nil and not seen[pp] then
            seen[pp] = true
            result[#result + 1] = pp
        end
    end
    local pcm = g_currentMission ~= nil and g_currentMission.productionChainManager or nil
    if pcm == nil then return result end
    pcall(function()
        for _, pp in pairs(pcm.productionPoints or {}) do add(pp) end
    end)
    if #result == 0 then
        pcall(function()
            for _, farm in pairs(g_farmManager.farms or {}) do
                for _, pp in pairs(pcm:getProductionPointsForFarmId(farm.farmId) or {}) do add(pp) end
            end
            for _, pp in pairs(pcm:getProductionPointsForFarmId(0) or {}) do add(pp) end
        end)
    end
    return result
end

-- Einordnung einer Produktionsstelle
function SeasonalProduction.classify(pp)
    local d = { name = "?", file = "?", tab = nil, typeName = nil, greenhouse = false,
        outputs = {}, inputs = {}, main = nil, class = "unchanged", season = nil, factor = nil, reason = "" }
    pcall(function() d.name = tostring(pp.getName ~= nil and pp:getName() or "?") end)
    local pl = pp.owningPlaceable
    if pl ~= nil then
        d.typeName = pl.typeName
        local cfg = pl.configFileName
        if cfg ~= nil then
            d.file = string.match(cfg, "([^/\\]+)$") or cfg
            pcall(function()
                local item = g_storeManager:getItemByXMLFilename(cfg)
                if item ~= nil then
                    d.category = item.categoryName
                    local b = item.brush
                    if b ~= nil then d.tab = b.category or b.tab or b.tabName end
                end
            end)
        end
        d.greenhouse = pl.spec_greenhouse ~= nil or string.find(lower(pl.typeName), "greenhouse", 1, true) ~= nil
    end
    -- Hauptware = erste Ausgabe der ersten Produktion
    pcall(function()
        for _, prod in pairs(pp.productions or {}) do
            for _, o in pairs(prod.outputs or {}) do
                local n = fillName(o.type)
                if n ~= nil then
                    d.outputs[#d.outputs + 1] = n
                    if d.main == nil then d.main = n end
                end
            end
            for _, i in pairs(prod.inputs or {}) do
                local n = fillName(i.type)
                if n ~= nil then d.inputs[#d.inputs + 1] = n end
            end
        end
    end)
    table.sort(d.outputs)
    table.sort(d.inputs)

    local tab = lower(d.tab or d.category)
    if d.greenhouse or SeasonalProduction.YEAR_ROUND_TABS[tab] or string.find(lower(d.file), "greenhouse", 1, true) ~= nil then
        d.class, d.reason = "greenhouse", "Gewächshaus (ganzjährig)"
        return d
    end
    local season = SeasonalProduction.FILE_SEASONS[lower(d.file)] or (d.main ~= nil and SeasonalProduction.SEASONS[d.main] or nil)
    -- Lager / Durchlauf: Hauptware wird auch eingelagert (Eingang = Ausgang) oder Lager-Kategorie
    local cat = string.upper(tostring(d.category or ""))
    local isStorage = cat == "SILOS" or cat == "SELLINGPOINTS"
        or string.find(lower(d.typeName), "extendedproductionpoint", 1, true) ~= nil
        or string.find(lower(d.file), "lager", 1, true) ~= nil
    if not isStorage and d.main ~= nil then
        for _, n in ipairs(d.inputs) do
            if n == d.main then isStorage = true break end
        end
    end
    -- Anbau-Gebaeude: Obst_*/Feld_* oder Bienenstock/Herbizid als Eingang
    local f = lower(d.file)
    local isCultivation = false
    if not isStorage then
        if string.find(f, "^obst_") or string.find(f, "^feld_") then isCultivation = true end
        for _, n in ipairs(d.inputs) do
            if n == "BEEHIVE" then isCultivation = true end
        end
        if season ~= nil then isCultivation = true end
    end
    if isCultivation and season ~= nil then
        d.class, d.season = "seasonal", season
        local months = (season.to - season.from + 12) % 12 + 1
        d.factor = 12 / months
        d.reason = "saisonal"
    elseif isCultivation then
        d.class, d.reason = "nosea", "Anbau, aber Ware ohne Saison - bitte in der Konfiguration ergänzen"
    else
        d.reason = isStorage and "Lager/Durchlauf" or "unverändert"
    end
    return d
end

function SeasonalProduction.scan()
    local points = SeasonalProduction.getAllPoints()
    SeasonalProduction.info = {}
    local counts = { seasonal = 0, greenhouse = 0, unchanged = 0, nosea = 0 }
    print(string.format("SeasonalProduction: %d Produktionsstellen gefunden (Option: %s)", #points,
        (FieldListHUD ~= nil and FieldListHUD.seasonal == true) and "AN" or "AUS"))
    for _, pp in ipairs(points) do
        local d = SeasonalProduction.classify(pp)
        SeasonalProduction.info[pp] = d
        counts[d.class] = (counts[d.class] or 0) + 1
        local seasonTxt = d.season ~= nil and string.format("Monat %d-%d, Faktor x%.1f", d.season.from, d.season.to, d.factor) or "-"
        print(string.format("SeasonalProduction: [%s] %s | Datei %s | Rubrik %s | Kategorie %s | Typ %s | Hauptware %s | Saison %s | Aus: %s | Ein: %s",
            d.class, d.name, d.file, tostring(d.tab), tostring(d.category), tostring(d.typeName), tostring(d.main), seasonTxt,
            table.concat(d.outputs, ","), table.concat(d.inputs, ",")))
        if d.class == "nosea" then
            print(string.format("SeasonalProduction: WARNUNG '%s' ist ein Anbau-Gebäude ohne Saison fuer '%s' - bitte in der Konfiguration ergänzen", d.name, tostring(d.main)))
        end
    end
    for pp, d in pairs(SeasonalProduction.info) do
        if d.class == "seasonal" then
            local keys = {}
            for _, prod in pairs(pp.productions or {}) do
                for k, v in pairs(prod) do
                    if type(v) == "number" and string.find(string.lower(k), "cycl", 1, true) ~= nil then keys[#keys + 1] = k .. "=" .. tostring(v) end
                end
                break
            end
            table.sort(keys)
            print("SeasonalProduction: Zyklusfelder (" .. d.name .. "): " .. table.concat(keys, ", "))
            break
        end
    end
    print(string.format("SeasonalProduction: saisonal %d, Gewächshaus %d, unverändert %d, Anbau ohne Saison %d",
        counts.seasonal, counts.greenhouse, counts.unchanged, counts.nosea))
end

-- ---------------------------------------------------------------------------------------------
-- Schritt 2: Produktion an die Saison anpassen (nur auf dem Server, nur bei eingeschalteter Option)
-- ---------------------------------------------------------------------------------------------

-- Felder einer Produktion, die die Zyklen pro Zeit bestimmen (werden alle skaliert, soweit vorhanden)
SeasonalProduction.CYCLE_FIELDS = { "cyclesPerMinute", "cyclesPerHour", "cyclesPerMonth", "cyclesPerMs",
    "baseCyclesPerMinute", "baseCyclesPerHour", "baseCyclesPerMonth" }
SeasonalProduction.base = setmetatable({}, { __mode = "k" })

-- Monatsfortschritt des Jahres in Monaten (0 = 1. Januar 00:00 ... 12 = Jahresende), aus Periode, Tag und Uhrzeit
function SeasonalProduction.getMonthPosition()
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    if env == nil or env.currentPeriod == nil then return nil end
    local curM = (env.currentPeriod + 1) % 12 + 1
    local dpp = env.daysPerPeriod or 1
    local day = env.currentDay or 1
    local frac = (((day - 1) % dpp) + ((env.dayTime or 0) / 86400000)) / dpp
    frac = math.max(0, math.min(1, frac))
    return (curM - 1) + frac
end

-- Leistung 0..1 (Rampe) und Spitzenfaktor fuer eine Saison; Rueckgabe: Faktor, Rampe
function SeasonalProduction.getFactor(season, monthPos)
    local n = (season.to - season.from + 12) % 12 + 1
    local t = (monthPos - (season.from - 1)) % 12
    local ramp
    if t >= n then
        ramp = 0
    elseif t < 0.5 then
        ramp = t / 0.5
    elseif t > n - 0.5 then
        ramp = (n - t) / 0.5
    else
        ramp = 1
    end
    -- Rampen kosten einen halben Monat Volllast; mit 12 / (n - 0.5) bleibt die Jahresmenge etwa gleich
    local peak = 12 / (n - 0.5)
    return ramp * peak, ramp
end

function SeasonalProduction.apply()
    local on = SeasonalProduction.isEnabled()
    local monthPos = SeasonalProduction.getMonthPosition()
    if monthPos == nil then return end
    for pp, d in pairs(SeasonalProduction.info) do
        if d.class == "seasonal" and d.season ~= nil then
            local f, ramp = 1, 1
            if on then f, ramp = SeasonalProduction.getFactor(d.season, monthPos) end
            if f < 1e-6 then f = 1e-6 end
            -- Nullbereich immer exakt uebernehmen, sonst bleibt ein Rest (~0.002 x Zyklen) hängen
            local zeroChange = d.appliedFactor ~= nil and ((d.appliedFactor <= 1e-5) ~= (f <= 1e-5))
            if d.appliedFactor == nil or zeroChange or math.abs(d.appliedFactor - f) > 0.002 then
                local was = d.appliedFactor
                if (was == nil and f ~= 1) or (was ~= nil and ((was <= 1e-5) ~= (f <= 1e-5))) then
                    print(string.format("SeasonalProduction: %s -> %s (Faktor %.2f, Monatsposition %.2f)", d.name,
                        f <= 1e-5 and "pausiert (ausserhalb der Saison)" or "laeuft", f, monthPos))
                end
                d.appliedFactor = f
                d.ramp = ramp
                for _, prod in pairs(pp.productions or {}) do
                    local b = SeasonalProduction.base[prod]
                    if b == nil then
                        b = {}
                        for _, fn in ipairs(SeasonalProduction.CYCLE_FIELDS) do
                            if type(prod[fn]) == "number" then b[fn] = prod[fn] end
                        end
                        SeasonalProduction.base[prod] = b
                    end
                    for fn, v in pairs(b) do prod[fn] = v * f end
                end
            end
        end
    end
end

-- neue / entfernte Produktionsstellen erfassen (z. B. waehrend des Spiels gebaut oder verkauft)
function SeasonalProduction.rescan()
    local points = SeasonalProduction.getAllPoints()
    local current = {}
    for _, pp in ipairs(points) do
        current[pp] = true
        if SeasonalProduction.info[pp] == nil then
            local d = SeasonalProduction.classify(pp)
            SeasonalProduction.info[pp] = d
            print(string.format("SeasonalProduction: neu erfasst [%s] %s (%s) Hauptware %s", d.class, d.name, d.file, tostring(d.main)))
        end
    end
    for pp in pairs(SeasonalProduction.info) do
        if not current[pp] then SeasonalProduction.info[pp] = nil end
    end
end

-- Statustext im Produktionsmenue des Spiels: ausserhalb der Saison "Ausserhalb der Erntezeit" statt "Laeuft"
SeasonalProduction.STATUS_TEXTS = { ["Läuft"] = true, ["Running"] = true }

function SeasonalProduction.patchMenu()
    -- nur, solange das Menue wirklich sichtbar ist (currentPage bleibt auch nach dem Schliessen gesetzt)
    if g_gui == nil or g_gui.getIsGuiVisible == nil or not g_gui:getIsGuiVisible() then return end
    local menu = g_inGameMenu
    local pg = menu ~= nil and menu.currentPage or nil
    if pg == nil then return end
    local sel = pg.selectedProductionPoint or pg.productionPoint
    if sel == nil then return end
    local d = SeasonalProduction.info[sel]
    if d == nil or d.class ~= "seasonal" or not SeasonalProduction.isEnabled() then return end
    if d.appliedFactor == nil or d.appliedFactor > 1e-5 then return end

    local txt = SeasonalProduction.offText
    if txt == nil then
        txt = g_i18n:getText("fl_season_off", SeasonalProduction.modName)
        SeasonalProduction.offText = txt
    end

    -- Statusfelder zwischenspeichern; der Baum wird nur bei Wechsel der Auswahl und gelegentlich neu durchsucht
    local c = SeasonalProduction.statusCache
    if c == nil or c.sel ~= sel or c.pg ~= pg or c.age > 60 then
        c = { sel = sel, pg = pg, age = 0, els = {} }
        local function walk(el, depth)
            if el == nil or depth > 10 then return end
            if type(el.text) == "string" and el.setText ~= nil
                and (SeasonalProduction.STATUS_TEXTS[el.text] or el.text == txt) then
                c.els[#c.els + 1] = el
            end
            for _, ch in ipairs(el.elements or {}) do walk(ch, depth + 1) end
        end
        walk(pg, 0)
        SeasonalProduction.statusCache = c
    end
    c.age = c.age + 1
    for _, el in ipairs(c.els) do
        if SeasonalProduction.STATUS_TEXTS[el.text] then el:setText(txt) end
    end
end

function SeasonalProduction:update(dt)
    if g_currentMission == nil or g_currentMission.productionChainManager == nil then
        return
    end
    -- erst ein paar Sekunden nach dem Start, damit alle Platzierbaren geladen sind
    self.waited = self.waited + (dt or 0)
    if self.waited < 8000 then return end
    if not self.scanned then
        self.scanned = true
        local ok, err = pcall(SeasonalProduction.scan)
        if not ok then print("SeasonalProduction: Erfassung fehlgeschlagen: " .. tostring(err)) end
        return
    end
    pcall(SeasonalProduction.patchMenu)
    self.acc = (self.acc or 0) + (dt or 0)
    if self.acc < 1000 then return end
    self.acc = 0
    self.tick = (self.tick or 0) + 1
    if self.tick % 10 == 0 then pcall(SeasonalProduction.rescan) end
    if g_currentMission:getIsServer() then
        local ok, err = pcall(SeasonalProduction.apply)
        if not ok and not self.warnedApply then
            self.warnedApply = true
            print("SeasonalProduction: Anpassung fehlgeschlagen: " .. tostring(err))
        end
    end
end

-- Auch beim Zeichnen den Statustext setzen, falls das Spiel ihn nach unserem Update wieder zuruecksetzt
function SeasonalProduction:draw()
    if self.scanned then pcall(SeasonalProduction.patchMenu) end
end

addModEventListener(SeasonalProduction)
