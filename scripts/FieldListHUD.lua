-- FieldListHUD
-- Fügt dem ESC-Menü die Seite "Feld Manager" hinzu. Erst wenn der Eintrag
-- angeklickt wird, erscheinen die Felder als Kacheln im Inhaltsbereich.
--
-- Kachel: Fruchticon | FELD NN ........ X.XX HA
--                    | Frucht · Kategorie

FieldListHUD = {}
FieldListHUD.modName       = g_currentModName
FieldListHUD.modDirectory  = g_currentModDirectory

-- Übersetzungen: alle Texte stehen in l10n/translation_<sprache>.xml (Schlüssel mit Präfix "fl_").
-- Neue Sprache = neue Datei translation_<code>.xml (Kopie von translation_en.xml übersetzen), kein Code nötig.
-- Fehlt ein Schlüssel in der aktiven Sprache, wird der Text aus translation_en.xml genommen.
local enTexts = nil
local function loadEnglish()
    enTexts = {}
    local path = Utils.getFilename("l10n/translation_en.xml", FieldListHUD.modDirectory)
    local xml = loadXMLFile("fieldManagerEn", path)
    if xml ~= nil and xml ~= 0 then
        local i = 0
        while true do
            local base = string.format("l10n.texts.text(%d)", i)
            local name = getXMLString(xml, base .. "#name")
            if name == nil then break end
            enTexts[name] = getXMLString(xml, base .. "#text")
            i = i + 1
        end
        delete(xml)
    end
end

local function T(key)
    local ok, text = pcall(function()
        return g_i18n:getText("fl_" .. key, FieldListHUD.modName)
    end)
    if ok and type(text) == "string" and text ~= "" and string.sub(text, 1, 8) ~= "Missing " then
        return text
    end
    if enTexts == nil then pcall(loadEnglish) end
    local en = enTexts ~= nil and (enTexts["fl_" .. key] or enTexts[key]) or nil
    if en ~= nil then return en end
    return key
end
FieldListHUD.T = T

local function rectsOverlap(a, b)
    return a ~= nil and b ~= nil and a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

FieldListHUD.pageName      = "pageFieldOverview"
FieldListHUD.pageTitle     = T("pageTitle")
FieldListHUD.pageInstalled = false
FieldListHUD.hookInstalled = false
FieldListHUD.installAttempts = 0

-- Kategorien nach Fruchtname (fruitType.name). Bei Bedarf ergänzen:
-- unbekannte Namen werden einmalig in die log.txt geschrieben.
FieldListHUD.CATEGORIES = {
    WHEAT = T("cat_cereal"), BARLEY = T("cat_cereal"), OAT = T("cat_cereal"), RYE = T("cat_cereal"),
    TRITICALE = T("cat_cereal"), SPELT = T("cat_cereal"), SORGHUM = T("cat_cereal"),
    MAIZE = T("cat_maize"),
    CANOLA = T("cat_oilseed"), SUNFLOWER = T("cat_oilseed"), OILSEEDRADISH = T("cat_oilseed"),
    SOYBEAN = T("cat_legume"), ALFALFA = T("cat_legume"), CLOVER = T("cat_legume"),
    PEA = T("cat_legume"), GREENBEAN = T("cat_vegetable"),
    POTATO = T("cat_root"), SUGARBEET = T("cat_root"), BEETROOT = T("cat_root"),
    CARROT = T("cat_vegetable"), PARSNIP = T("cat_vegetable"), SPINACH = T("cat_vegetable"),
    GRASS = T("cat_forage"), MEADOW = T("cat_forage"), FIELDGRASS = T("cat_forage"),
    SUMMERWHEAT = T("cat_cereal"),
    LINSEED = T("cat_oilseed"),
    LENTILS = T("cat_legume"), BUCKWHEAT = T("cat_cereal"),
    HEMP = T("cat_fiber"),
    -- weitere Fruchttypen der Karte
    SUMMERBARLEY = T("cat_cereal"), RICE = T("cat_cereal"), RICELONGGRAIN = T("cat_cereal"),
    MUSTARD = T("cat_oilseed"), POPPY = T("cat_oilseed"),
    BEANS = T("cat_legume"), PEAS = T("cat_legume"),
    ONION = T("cat_vegetable"),
    COTTON = T("cat_fiber"),
    LAVENDER = T("cat_special"), TOBACCO = T("cat_special"), SUGARCANE = T("cat_special"),
    GRAPE = T("cat_perennial"), OLIVE = T("cat_perennial"),
    POPLAR = T("cat_tree"),
}

-- Kategorie zu einem Fruchtnamen; unbekannte Fruchttypen (z. B. aus Mods) bekommen "Sonstige"
function FieldListHUD.getCategory(name)
    if name == nil or name == "" then
        return nil
    end
    return FieldListHUD.CATEGORIES[string.upper(name)] or T("cat_other")
end

-- Einmal beim Laden des Skripts: Zeichen-Hook ins ESC-Menü.
-- Gezeichnet wird nur, wenn unsere Seite aktiv ist (siehe drawInMenu).
if InGameMenu ~= nil and not FieldListHUD.hookInstalled then
    InGameMenu.draw = Utils.appendedFunction(InGameMenu.draw, function()
        FieldListHUD:drawInMenu()
    end)
    FieldListHUD.hookInstalled = true
end

-- Mausereignisse direkt am Menü abfangen, solange unsere Seite aktiv ist
if InGameMenu ~= nil and InGameMenu.mouseEvent ~= nil and not FieldListHUD.mouseHookInstalled then
    InGameMenu.mouseEvent = Utils.overwrittenFunction(InGameMenu.mouseEvent,
        function(menu, superFunc, posX, posY, isDown, isUp, button, eventUsed)
            if not eventUsed then
                local ok, used = pcall(FieldListHUD.onMouse, FieldListHUD, posX, posY, isDown, isUp, button)
                if ok and used then
                    return true
                end
            end
            return superFunc(menu, posX, posY, isDown, isUp, button, eventUsed)
        end)
    FieldListHUD.mouseHookInstalled = true
end

-- Tastendruck (R) auf Seite 3: Detailfenster zur Zeile unter der Maus
if InGameMenu ~= nil and InGameMenu.keyEvent ~= nil and not FieldListHUD.keyHookInstalled then
    InGameMenu.keyEvent = Utils.overwrittenFunction(InGameMenu.keyEvent,
        function(menu, superFunc, unicode, sym, modifier, isDown, ...)
            if isDown and Input ~= nil and sym == Input.KEY_t and FieldListHUD.page == 3 and FieldListHUD.layout ~= nil then
                FieldListHUD.p3Mode = (FieldListHUD.p3Mode == "this" and "next") or (FieldListHUD.p3Mode == "next" and "in2") or "this"
                return true
            end
            if isDown and Input ~= nil and sym == Input.KEY_r then
                local ok, used = pcall(FieldListHUD.onKeyDetail, FieldListHUD)
                if ok and used then
                    return true
                end
            end
            return superFunc(menu, unicode, sym, modifier, isDown, ...)
        end)
    FieldListHUD.keyHookInstalled = true
end

-- Beim Speichern des Spielstands unsere Daten mitschreiben
local function onSaveGame(missionInfo)
    local dir = missionInfo ~= nil and missionInfo.savegameDirectory or nil
    FieldListHUD:saveData(dir)
end
if FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil and not FieldListHUD.saveHookInstalled then
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, onSaveGame)
    FieldListHUD.saveHookInstalled = true
end

------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------

function FieldListHUD:loadMap(filename)
    self.fields     = {}
    self.icons      = {}
    self.warned     = {}
    self.timer      = 0
    self.retryTimer = 3000 -- Seite erst nach dem Laden einbauen (update() läuft erst im laufenden Spiel)
    self.frame      = nil
    self.pageInstalled   = false
    self.installAttempts = 0

    -- Farben
    -- Overlay-Farben werden vom Spiel als Linearwerte behandelt (0.019 entspricht etwa #252525)
    self.colorTile  = { 0.019, 0.019, 0.019, 1.00 }   -- Füllung = Hintergrundfarbe des Menüs
    self.colorBorder = { 0.070, 0.070, 0.070, 1.00 }  -- Rahmen
    self.colorIcon  = { 0.040, 0.060, 0.050, 1.00 }
    self.colorNoFruit = { 0.19, 0.43, 0.75, 1.00 }   -- Hellblau für Felder ohne Frucht
    self.colorWork    = { 1.00, 0.55, 0.15, 1.00 }   -- Orange: anstehende Arbeit
    self.colorGround  = { 0.55, 0.75, 0.95, 1.00 }   -- Hellblau: Bearbeitungszustand
    self.colorPlow    = { 0.65, 0.05, 0.05, 1.00 }   -- Rot: Feld muss gepflügt werden
    self.colorTitle = { 1.00, 1.00, 1.00, 1.00 }
    self.colorArea  = { 0.55, 0.75, 0.20, 1.00 }
    self.colorSub   = { 0.75, 0.75, 0.75, 1.00 }
    self.colorTileSelected = { 0.026, 0.040, 0.014, 1.00 }
    self.colorPanel = { 0.00, 0.00, 0.00, 0.30 }
    self.colorTrack = { 1.00, 1.00, 1.00, 0.10 }
    self.colorThumb = { 1.00, 1.00, 1.00, 0.45 }

    -- Listen-Zustand
    self.scrollOffset = 0
    self.store        = {}
    self.filterMode   = 1
    self.page         = 1
    self.tbl          = { offset = 0, max = 0 }
    self.pageBtns     = {}
    self.visible      = {}
    self.hitRects     = {}
    self.maxOffset    = 0
    self.selectedId   = nil
    self.layout       = nil

    -- Einfarbiges Overlay, wird für Kachel und Icon-Hintergrund wiederverwendet
    if g_dedicatedServer == nil then
        self.bg = Overlay.new(g_baseUIFilename, 0, 0, 0.1, 0.05)
        self.bg:setUVs(g_colorBgUVs)
    end

    -- Mehrspieler: nur der Server liest und schreibt die Daten, Clients bekommen sie vom Server
    self.synced       = {}
    self.syncReceived = false
    self.fieldOwner   = {}
    self.mpTimer      = 0
    self.requestTimer = 0
    local mi = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if self:isAuthority() then
        self:loadData(mi ~= nil and mi.savegameDirectory or nil)
    else
        self.store = {}
    end

    self:loadPlayerSettings()
    print("FieldListHUD: geladen")
end

function FieldListHUD:deleteMap()
    -- Seite wieder entfernen, damit sie bei einem weiteren Spielstart nicht doppelt auftaucht
    local menu = g_inGameMenu
    if self.frame ~= nil then
        if menu ~= nil and menu.removePage ~= nil then
            local ok, err = pcall(menu.removePage, menu, self.frame)
            if not ok then
                print("FieldListHUD: Seite konnte nicht entfernt werden: " .. tostring(err))
            end
        end
        self.frame = nil
    end
    self.pageInstalled = false

    if self.bg ~= nil then
        self.bg:delete()
        self.bg = nil
    end
    for _, icon in pairs(self.icons or {}) do
        icon:delete()
    end
    self.icons = {}

    -- Jahreszeiten-Symbole (Erntekalender) und Zwischenspeicher freigeben
    for _, ov in pairs(self.seasonIcons or {}) do
        if ov ~= false and ov.delete ~= nil then pcall(ov.delete, ov) end
    end
    self.seasonIcons = nil
    self.seasonRowsCache = nil
end

function FieldListHUD:update(dt)
    -- Liste einmal pro Sekunde neu aufbauen
    self.timer = self.timer - dt
    if self.timer <= 0 then
        -- Im Leerlauf (kein HUD, Menü zu) reicht ein größerer Takt; Server ohne Oberfläche bleibt bei 1 s
        local idle = g_dedicatedServer == nil and not self.settings.hud and not (g_gui ~= nil and g_gui:getIsGuiVisible())
        self.timer = idle and 3000 or 1000
        self:refreshFields()
        self:mpTick()
    end
    self:mpRequest(dt)

    -- Falls das Menü beim Laden noch nicht bereit war, Seite nachträglich einbauen
    if not self.pageInstalled and self.installAttempts < 30 then
        self.retryTimer = self.retryTimer - dt
        if self.retryTimer <= 0 then
            self.retryTimer = 500
            self:tryInstallPage()
        end
    end
end

------------------------------------------------------------------------
-- Menüseite einbauen
------------------------------------------------------------------------

function FieldListHUD:tryInstallPage()
    if self.pageInstalled then
        return
    end

    local menu = g_inGameMenu
    if menu == nil and g_gui ~= nil and g_gui.screenControllers ~= nil and InGameMenu ~= nil then
        menu = g_gui.screenControllers[InGameMenu]
    end
    if menu == nil or menu.pagingElement == nil then
        return
    end

    self.installAttempts = self.installAttempts + 1
    self.pageInstalled = true -- auch bei Fehler nicht endlos wiederholen

    local ok, err = pcall(function()
        local frame = FieldListHUDFrame.new()
        g_gui:loadGui(self.modDirectory .. "gui/FieldListHUDFrame.xml", self.pageName, frame, true)
        frame.name = self.pageName

        -- Am Ende der Tab-Leiste einfügen; Position bei Bedarf ändern (1 = ganz links)
        local position = 10
        if menu.pageFrames ~= nil then
            position = #menu.pageFrames + 1
            -- direkt hinter dem Anbaukalender einfügen (Fallback: ans Ende)
            local names = {}
            local calPos = nil
            for i, f in ipairs(menu.pageFrames) do
                local nm = tostring(f.name or f.pageName or f.className or (f.class ~= nil and f:class().className) or "?")
                names[#names + 1] = nm
                if calPos == nil and (f == menu.pageCalendar or string.find(string.lower(nm), "calendar", 1, true) ~= nil) then
                    calPos = i
                end
            end
            if calPos ~= nil then
                position = calPos + 1
            end
        end

        -- TabbedMenu:addPage trägt frame.elements[1] ins Paging-Element ein, das Menü sucht die Seite
        -- aber über den Frame selbst (-> "attempt to index nil with 'disabled'"). Deshalb die
        -- Schritte von addPage einzeln ausführen und den Frame selbst als Seite eintragen.
        local _, actualPosition = menu:registerPage(frame, position, function() return true end)
        menu:addPageTab(frame, self.modDirectory .. "gui/tabIcon.dds", GuiUtils.getUVs({ 0, 0, 1024, 1024 }))
        if menu.pageRoots ~= nil then
            menu.pageRoots[frame] = frame
        end
        menu.pagingElement:addPage(string.upper(self.pageName), frame, self.pageTitle, actualPosition or position)

        self.frame = frame
    end)

    if not ok then
        print("FieldListHUD: Seite konnte nicht hinzugefügt werden: " .. tostring(err))
        self.frame = nil
        return
    end

    -- Selbsttest: Findet das Menü die Seite, und laufen die Menü-Aktualisierungen fehlerfrei?
    -- Wenn nicht, die Seite sofort wieder entfernen, damit das ESC-Menü nicht kaputtgeht.
    local okTest, errTest = pcall(function()
        local pageId = menu.pagingElement:getPageIdByElement(self.frame)
        assert(pageId ~= nil, "Seite im Paging-Element nicht gefunden")
        menu:rebuildTabList()
        menu:updatePages()
    end)

    if not okTest then
        print("FieldListHUD: Selbsttest fehlgeschlagen, Seite wird entfernt: " .. tostring(errTest))
        if menu.removePage ~= nil then
            local okRm, errRm = pcall(menu.removePage, menu, self.frame)
            if not okRm then
                print("FieldListHUD: Entfernen fehlgeschlagen: " .. tostring(errRm))
            end
        end
        self.frame = nil
        return
    end

    print("FieldListHUD: Menüseite 'Feld Manager' hinzugefügt")
end

------------------------------------------------------------------------
-- Felddaten
------------------------------------------------------------------------

-- Größe in Hektar, mit Fallbacks für unterschiedliche API-Stände
function FieldListHUD:getFieldAreaHa(field)
    if field.getAreaHa ~= nil then
        return field:getAreaHa()
    end
    return field.fieldArea or field.areaHa or 0
end

-- Feldnummer mit Fallbacks für unterschiedliche API-Stände
function FieldListHUD:getFieldNumber(field)
    if field.getId ~= nil then
        local id = field:getId()
        if id ~= nil then
            return id
        end
    end
    if field.fieldId ~= nil then
        return field.fieldId
    end
    if field.id ~= nil then
        return field.id
    end
    if field.farmland ~= nil and field.farmland.id ~= nil then
        return field.farmland.id
    end
    return 0
end

-- Liefert den aktuellen Fruchttyp auf dem Feld (oder nil)
function FieldListHUD:getFieldFruitType(field)
    local state = field.fieldState
    if state == nil or state.update == nil then
        return nil
    end

    local x, z
    if field.getCenterOfFieldWorldPosition ~= nil then
        x, z = field:getCenterOfFieldWorldPosition()
    else
        x, z = field.posX, field.posZ
    end
    if x == nil or z == nil then
        return nil
    end

    state:update(x, z)
    local index = state.fruitTypeIndex
    if index == nil or index == FruitType.UNKNOWN then
        return nil
    end
    return g_fruitTypeManager:getFruitTypeByIndex(index)
end

FieldListHUD.GROUND_TEXT = {
    NONE = T("ground_fallow"), STUBBLE_TILLAGE = T("ground_stubble"), CULTIVATED = T("ground_cultivated"),
    SEEDBED = T("ground_seedbed"), PLOWED = T("ground_plowed"), ROLLED_SEEDBED = T("ground_rolled"),
    RIDGE = T("ground_ridge"), RIDGE_SOWN = T("ground_ridgesown"), RIDGE_SEEDED = T("ground_ridgesown"), SOWN = T("ground_sown"),
    DIRECT_SOWN = T("ground_directsown"), PLANTED = T("ground_planted"), HARVEST_READY = T("ground_ready"),
    HARVESTED = T("ground_harvested"), GRASS = T("ground_grass"), GRASS_CUT = T("ground_mowed"),
    HARVESTED_NO_STUBBLE = T("ground_harvested"),
    ROLLER_LINES = T("ground_rolled"), HARVEST_READY_OTHER = T("ground_ready"),
}

-- Feldstatus als Text: Wachstum aus Wachstumsstufe, sonst Bodenbearbeitung aus groundType
function FieldListHUD:getStatusText(entry)
    -- Schnittfrüchte: 5/4 = abgeerntet (Walzen steht an), 6/4 = gewalzt
    if entry.fruitTitle ~= nil and FieldListHUD.CUT_CROPS[entry.fruitName or ""] and entry.growthState ~= nil
        and entry.maxGrowth ~= nil and entry.growthState > entry.maxGrowth then
        return entry.growthState > entry.maxGrowth + 1 and T("ground_rolled") or T("ground_harvested")
    end
    if entry.fruitTitle ~= nil and self:needsRolling(entry) then
        return T("status_mustroll")
    end
    if entry.fruitTitle ~= nil and entry.growthState ~= nil then
        if entry.harvestReady then
            return T("ground_ready")
        end
        local gs = entry.growthState
        if gs >= 1 and (entry.maxGrowth == nil or gs <= entry.maxGrowth) then
            return T("status_growing")
        end
        if self:needsPlowing(entry) then
            return T("status_mustplow")
        end
        return T("ground_harvested")
    end
    -- Leeres Feld: ist Pflügen vorgeschrieben (Spieleinstellung) und noch nicht erledigt?
    if self:needsPlowing(entry) then
        return T("status_mustplow")
    end
    return self:getGroundText(entry) or T("status_unknown")
end

-- Frucht ist gesät, aber der Walzen-Wert steht noch auf "nicht gewalzt" (Annahme: rollerLevel > 0)
function FieldListHUD:needsRolling(entry)
    -- Schnittfrüchte: Walzen nur direkt nach dem Schnitt (5/4); bei 6/4 ist gewalzt
    if entry.fruitTitle ~= nil and FieldListHUD.CUT_CROPS[entry.fruitName or ""] and entry.growthState ~= nil
        and entry.maxGrowth ~= nil and entry.growthState > entry.maxGrowth then
        return entry.growthState == entry.maxGrowth + 1
    end
    return entry.fruitTitle ~= nil and entry.roller ~= nil and entry.roller > 0
end

-- Aussaat steht an: Folgefrucht (N+1) gewählt und auf dem Feld wächst nichts (auch Stoppelfeld, Direktsaat)
function FieldListHUD:needsSowing(entry)
    if entry.unused or entry.id == nil then
        return false
    end
    local rec = self.store ~= nil and self.store[entry.id] or nil
    if rec == nil or rec.next == nil or rec.manual then
        return false
    end
    if entry.fruitTitle == nil then
        return true
    end
    local gs = entry.growthState
    if gs ~= nil and gs >= 1 and (entry.maxGrowth == nil or gs <= entry.maxGrowth) then
        return false -- wächst oder ist erntereif
    end
    return true
end

-- Liegt der aktuelle Monat im Saatfenster der Frucht (nur bei Saisonwachstum; sonst immer ja)?
function FieldListHUD:canSowNow(fruitName)
    local ft = fruitName ~= nil and g_fruitTypeManager:getFruitTypeByName(string.upper(fruitName)) or nil
    local cur = self:getCurrentPeriod()
    local ses = ft ~= nil and self:parseSeason(ft) or nil
    if cur == nil or ses == nil then
        return true
    end
    return ses.plant[cur] == true
end

-- Leeres Feld, auf dem Pflügen vorgeschrieben und noch nicht erledigt ist
function FieldListHUD:needsPlowing(entry)
    local mi = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if mi == nil or mi.plowingRequiredEnabled ~= true or entry.plow == nil or entry.plow > 0 then
        return false
    end
    if entry.fruitTitle == nil then
        return true
    end
    -- abgeerntetes Feld (Frucht steht noch als Stoppel/Ernterest in der Karte): auch hier muss gepflügt werden
    local gs = entry.growthState
    if gs == nil or entry.harvestReady or FieldListHUD.CUT_CROPS[entry.fruitName or ""] then
        return false
    end
    return not (gs >= 1 and (entry.maxGrowth == nil or gs <= entry.maxGrowth))
end

-- Füllfarbe für Felder ohne Frucht: rot, wenn gepflügt werden muss, sonst hellblau
function FieldListHUD:getNoFruitColor(entry)
    return self:needsPlowing(entry) and self.colorPlow or self.colorNoFruit
end

-- Bodenbearbeitungszustand aus groundType (nil, wenn nicht erkennbar)
function FieldListHUD:getGroundText(entry)
    local gt = entry.groundType
    if gt ~= nil and FieldGroundType ~= nil then
        for name, value in pairs(FieldGroundType) do
            if value == gt and type(name) == "string" then
                return FieldListHUD.GROUND_TEXT[name] or name
            end
        end
    end
    return nil
end

-- Steine liegen in einer eigenen Karte; Abfrage über alle Teilflächen des Feldes (alle 5 s neu)
function FieldListHUD:getStoneInfo(field, id)
    self.stoneCache = self.stoneCache or {}
    local now = g_time or 0
    local c = self.stoneCache[id]
    -- Steine ändern sich selten (Aufsammeln): alle 2 Minuten neu messen, höchstens wenige Felder pro Durchlauf (Last verteilen)
    if c ~= nil and (now - (c.t or 0)) < 120000 then
        return c.area, c.total, c.raw, c.counts
    end
    -- Das gewählte Feld wird immer sofort gemessen (kein Warten auf die Verteilung)
    if (self.stoneBudget or 0) <= 0 and id ~= self.selectedId then
        self.stoneDenied = (self.stoneDenied or 0) + 1
        if c ~= nil then
            return c.area, c.total, c.raw, c.counts
        end
        return nil, nil, nil, {}
    end
    if id ~= self.selectedId then
        self.stoneBudget = self.stoneBudget - 1
    end

    local area, total, raw, counts = nil, nil, nil, {}
    local ok, err = pcall(function()
        local ss = g_currentMission ~= nil and g_currentMission.stoneSystem or nil
        local pts = field.polygonPoints
        if ss == nil or ss.densityMap == nil or type(pts) ~= "table" or #pts < 3 then
            raw = "kein Steine-System oder keine Feldecken"
            return
        end

        -- Eckpunkte des Feldes in Weltkoordinaten
        local px, pz = {}, {}
        local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
        for i = 1, #pts do
            local x, _, z = getWorldTranslation(pts[i])
            px[i], pz[i] = x, z
            minX, maxX = math.min(minX, x), math.max(maxX, x)
            minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
        end

        local function inside(x, z)
            local c = false
            local j = #px
            for i = 1, #px do
                if (pz[i] > z) ~= (pz[j] > z) and x < (px[j] - px[i]) * (z - pz[i]) / (pz[j] - pz[i]) + px[i] then
                    c = not c
                end
                j = i
            end
            return c
        end

        -- Raster mit höchstens ca. 1500 Messpunkten über das Feld legen (einmal pro Seitenöffnung für alle Felder)
        local step = math.max(3, math.sqrt((maxX - minX) * (maxZ - minZ) / 1500))
        area, total = 0, 0
        local x = minX + step / 2
        while x < maxX do
            local z = minZ + step / 2
            while z < maxZ do
                if inside(x, z) then
                    total = total + 1
                    local v = getDensityAtWorldPos(ss.densityMap, x, 0, z)
                    if v ~= nil and v >= ss.minValue and v <= ss.maxValue then
                        area = area + 1
                        counts[v] = (counts[v] or 0) + 1
                    end
                end
                z = z + step
            end
            x = x + step
        end
        raw = string.format("Raster %.1f m, %d Punkte", step, total)
    end)
    if not ok then
        raw = "Fehler: " .. tostring(err)
        area, total = nil, nil
    end
    self.stoneCache[id] = { t = now, area = area, total = total, raw = raw, counts = counts }
    return area, total, raw, counts
end

-- Erste erntereife Stufe. Bei manchen Früchten (Zuckerrüben: 8 Wachstumsstufen, Erntezustand 11) liegt der Wert hinter der
-- letzten Wachstumsstufe; die Stufen davor entstehen erst durch Arbeiten wie Kraut schlagen. Dann ist schon die letzte Wachstumsstufe erntereif.
-- Unkrautgröße aus der Unkrautstufe: 1 klein, 2 mittel, 3 ausgewachsen (Annahme, Rohwerte stehen einmalig im Log)
FieldListHUD.weedSeen = {}
function FieldListHUD.weedSize(w)
    if w == nil or w <= 0 then return 0 end
    if FieldListHUD.weedSeen[w] == nil then
        FieldListHUD.weedSeen[w] = true
        print(string.format("FieldListHUD: Unkrautstufe (Rohwert) %s", tostring(w)))
    end
    return math.min(3, math.floor(w))
end

function FieldListHUD.harvestMinState(ft)
    local m = ft ~= nil and ft.minHarvestingGrowthState or nil
    local n = ft ~= nil and ft.numGrowthStates or nil
    if m ~= nil and n ~= nil and m > n then return n end
    return m
end

function FieldListHUD:buildEntry(field, light)
    local entry = {
        id   = self:getFieldNumber(field),
        area = self:getFieldAreaHa(field),
    }

    entry.unused = self:getRecord(entry.id).unused == true
    local fruitType = self:getFieldFruitType(field) -- aktualisiert auch field.fieldState
    local st = field.fieldState
    if st ~= nil then
        entry.lime   = st.limeLevel
        entry.spray  = st.sprayLevel
        entry.weed   = st.weedState
        entry.plow   = st.plowLevel
        entry.roller = st.rollerLevel
        entry.stone  = st.stoneLevel
        entry.groundType = st.groundType
        entry.weedFactor = st.weedFactor
        entry.stubble    = st.stubbleShredLevel
    end

    if not light then
        local a, t, raw, counts = self:getStoneInfo(field, entry.id)
        entry.stoneArea, entry.stoneTotal, entry.stoneRaw, entry.stoneCounts = a, t, raw, counts
        if a ~= nil then
            entry.stone = a
        end
    end

    if fruitType ~= nil then
        local fillType = fruitType.fillType
        entry.fruitTitle   = (fillType ~= nil and fillType.title) or fruitType.name
        entry.growthState  = field.fieldState ~= nil and field.fieldState.growthState or nil
        entry.maxGrowth    = fruitType.numGrowthStates
        entry.fruitIndex   = fruitType.index
        entry.fruitName    = string.upper(fruitType.name or "")
        if entry.growthState ~= nil and fruitType.minHarvestingGrowthState ~= nil
            and fruitType.maxHarvestingGrowthState ~= nil then
            entry.harvestReady = entry.growthState >= FieldListHUD.harvestMinState(fruitType)
                and entry.growthState <= fruitType.maxHarvestingGrowthState
        end
        -- Schnittfrüchte (Gras, Ackergras, Kleegras, Luzerne): im Spiel gibt es 4 Stufen, erntereif erst bei 4/4
        if FieldListHUD.CUT_CROPS[entry.fruitName] then
            entry.maxGrowth = math.max(entry.maxGrowth or 0, 4)
            if entry.growthState ~= nil then
                -- nur 4/4 ist erntereif; 5/4 = abgeerntet (Walzen nötig), 6/4 = gewalzt
                entry.harvestReady = entry.growthState == entry.maxGrowth
            end
        end
        entry.iconFilename = fillType ~= nil and fillType.hudOverlayFilename or nil
        if entry.iconFilename == nil and g_fillTypeManager ~= nil then
            -- Ersatz-Icon, z. B. für Wiese: das Gras-Icon
            local fallback = g_fillTypeManager:getFillTypeByName("GRASS")
            entry.iconFilename = fallback ~= nil and fallback.hudOverlayFilename or nil
        end

        local name = string.upper(fruitType.name or "")
        entry.category = FieldListHUD.getCategory(name)
        if FieldListHUD.CATEGORIES[name] == nil and not self.warned[name] then
            self.warned[name] = true
            print(string.format("FieldListHUD: keine Kategorie für Frucht '%s' hinterlegt", name))
        end

        if entry.iconFilename == nil and not self.warned["icon_" .. name] then
            self.warned["icon_" .. name] = true
            print(string.format("FieldListHUD: kein Icon für Frucht '%s' gefunden", name))
        end
    end
    -- Mais für Silage: in Feldliste und Kacheln als "Mais (Silage)" anzeigen
    if entry.fruitName == "MAIZE" and entry.fruitTitle ~= nil and self.store ~= nil then
        local rcM = self.store[entry.id]
        if rcM ~= nil and rcM.curSilage then
            entry.fruitTitle = entry.fruitTitle .. " (" .. T("use_silage") .. ")"
        end
    end
    return entry
end

-- Baut die Liste der Felder auf, die zum eigenen Hof gehören
function FieldListHUD:refreshFields()
    local list = {}
    if g_currentMission ~= nil and g_fieldManager ~= nil then
        local farmId = g_currentMission:getFarmId()
        local authority = self:isAuthority()
        -- Erste Messung (und Tab-Öffnung) schnell, danach nur wenige Felder pro Durchlauf
        self.stoneBudget = self.stoneBoost and 100 or (self.stoneInitDone and 4 or 20)
        self.stoneBoost = false
        self.stoneDenied = 0
        for _, field in pairs(g_fieldManager:getFields()) do
            local farmland = field.farmland
            local owner = farmland ~= nil and g_farmlandManager:getFarmlandOwner(farmland.id) or nil
            if owner ~= nil and owner == farmId and owner ~= (FarmlandManager.NO_OWNER_FARM_ID or 0) then
                local entry = self:buildEntry(field)
                if authority then
                    self:trackField(entry)
                end
                self.fieldOwner[entry.id] = owner
                table.insert(list, entry)
            elseif authority and owner ~= nil and owner ~= (FarmlandManager.NO_OWNER_FARM_ID or 0) then
                -- Server: auch die Felder der anderen Höfe mitführen (Fruchtfolge, Ernte-Faktor)
                local entry = self:buildEntry(field, true)
                self:trackField(entry)
                self.fieldOwner[entry.id] = owner
            end
        end
        table.sort(list, function(a, b) return a.id < b.id end)
        if (self.stoneDenied or 0) == 0 then self.stoneInitDone = true end
    end
    self.fields = list
end

------------------------------------------------------------------------
-- Gespeicherte Daten (Folgefrucht, aktuelle Frucht, Vorfrüchte) pro Feld
------------------------------------------------------------------------

FieldListHUD.SAVE_FILE = "fieldManager.xml"
FieldListHUD.SAVE_FILE_OLD = "fieldListHUD.xml" -- früherer Name, wird beim Laden übernommen

function FieldListHUD:getRecord(id)
    local rec = self.store[id]
    if rec == nil then
        rec = { next = nil, cur = nil, hist = {}, gap = false, unused = false }
        self.store[id] = rec
    end
    return rec
end

-- Verfolgt den Fruchtwechsel: neue Frucht (oder Neuansaat nach leerem Feld) schiebt die alte in die Vorfrüchte
-- Gleiche Frucht? Auch zwei Fruchttypen mit gleichem Namen (z. B. PEA und PEAS, beide "Erbsen") zählen als gleich
-- Sommerformen sind dieselbe Art wie die Winterform (für Bedarf, Planung und Fruchtfolge)
FieldListHUD.FRUIT_ALIAS = { SUMMERWHEAT = "WHEAT", SUMMERBARLEY = "BARLEY" }

function FieldListHUD.sameFruit(a, b)
    if a == nil or b == nil then
        return false
    end
    a = FieldListHUD.FRUIT_ALIAS[a] or a
    b = FieldListHUD.FRUIT_ALIAS[b] or b
    if a == b then
        return true
    end
    local fa = g_fruitTypeManager:getFruitTypeByName(a)
    local fb = g_fruitTypeManager:getFruitTypeByName(b)
    if fa == nil or fb == nil then
        return false
    end
    local ta = fa.fillType ~= nil and fa.fillType.title or nil
    local tb = fb.fillType ~= nil and fb.fillType.title or nil
    return ta ~= nil and ta == tb
end

-- Zwischenfrüchte (Gründüngung): keine Hauptfrucht, nur Marker zwischen den Kacheln
FieldListHUD.CATCH_CROPS = { OILSEEDRADISH = true }

function FieldListHUD.isCatchCrop(name)
    return name ~= nil and FieldListHUD.CATCH_CROPS[string.upper(name)] == true
end

-- Vorfrucht-Liste fortschreiben; rec.cc[i] = Zwischenfrucht zwischen Vorfrucht i und der nächstjüngeren Frucht
function FieldListHUD:pushHist(rec, old)
    table.insert(rec.hist, 1, old)
    rec.cc = rec.cc or {}
    table.insert(rec.cc, 1, rec.ccPending == true)
    rec.ccPending = false
    rec.ccPlanned = false
    while #rec.hist > FieldListHUD.MAX_HIST do
        table.remove(rec.hist)
    end
    while #rec.cc > FieldListHUD.MAX_HIST do
        table.remove(rec.cc)
    end
end

-- Hauptfrucht-Eintrag fürs Feld: wächst gerade eine Zwischenfrucht, bleibt die letzte Hauptfrucht "aktuell"
function FieldListHUD:getMainEntry(entry)
    -- Zwischenfrucht steht auf dem Feld: sie wird als aktuelle Frucht gezeigt (Z-Marker und Hinweis unter der Folgefrucht bleiben)
    return self:getCurrentOverride(entry) or entry
end

-- Vorfruchtliste für die Anzeige: Ist das Feld leer (geerntet und bearbeitet, z. B. Gegrubbert/Stoppelsturz),
-- steht dort "Aktuell" der Bodenzustand und die zuletzt geerntete Frucht (rec.cur) ist Vorfrucht 1.
function FieldListHUD:getDisplayHist(entry)
    local rec = entry ~= nil and entry.id ~= nil and self.store ~= nil and self.store[entry.id] or nil
    if rec == nil then
        return {}
    end
    local hist = rec.hist or {}
    if rec.cur ~= nil and not rec.manual and entry.fruitName == nil and not FieldListHUD.isCatchCrop(rec.cur) then
        local out = { rec.cur }
        for i, v in ipairs(hist) do out[i + 1] = v end
        return out
    end
    return hist
end

-- Fruchtfolgefaktor zum Saatzeitpunkt festhalten (gilt später bei der Ernte); nur wenn die Saat gerade erst erfolgt ist
function FieldListHUD:captureSowFactor(rec, name, entry)
    local gs = entry ~= nil and entry.growthState or nil
    if gs == nil or gs > 2 then
        rec.sowFactor, rec.sowFruit = nil, nil -- Bestand war schon gewachsen: Faktor unbekannt
        return
    end
    local ok, r = pcall(self.rateCandidate, self, rec, name)
    rec.sowFruit = string.upper(name)
    rec.sowFactor = (ok and r ~= nil and not r.blocked and r.factor ~= nil) and (r.factor / 100) or 1
end

-- Laufender Monat als fortlaufende Zahl (Jahr * 12 + Periode), nil wenn unbekannt
function FieldListHUD:getMonthKey()
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    if env == nil or env.currentPeriod == nil then
        return nil
    end
    return (env.currentYear or 0) * 12 + env.currentPeriod
end

function FieldListHUD:sprayedThisMonth(id)
    local rec = id ~= nil and self.store ~= nil and self.store[id] or nil
    local key = self:getMonthKey()
    return rec ~= nil and rec.sprayKey ~= nil and key ~= nil and rec.sprayKey == key
end

-- Zweite Düngung gesperrt? Gras: erst nach dem Monatswechsel. Alle anderen Früchte: erst, wenn die Frucht
-- seit der Düngung mindestens eine Wachstumsstufe weitergewachsen ist (Stufe unbekannt: Monatsregel)
function FieldListHUD:sprayBlockedAgain(entry)
    local id = entry ~= nil and entry.id or nil
    local rec = id ~= nil and self.store ~= nil and self.store[id] or nil
    if rec == nil then return false end
    local fname = string.upper(entry.fruitName or "")
    if fname ~= "GRASS" and rec.sprayGs ~= nil and rec.sprayKey ~= nil then
        -- Gedüngt auf leerem Feld oder frisch gesät (Stufe 0/1): erst ab Stufe 2 wieder
        return entry.growthState == nil or entry.growthState <= math.max(rec.sprayGs, 1)
    end
    return self:sprayedThisMonth(id)
end

function FieldListHUD:trackField(entry)
    if entry.id == nil or entry.id == 0 or not self:isAuthority() then
        return
    end
    local rec = self:getRecord(entry.id)
    local name = entry.fruitName
    -- Zwischenfrucht darf nie als Hauptfrucht gespeichert sein (z. B. durch Weiterschieben einer als Folgefrucht gewählten Zwischenfrucht)
    if FieldListHUD.isCatchCrop(rec.cur) then
        rec.cur = table.remove(rec.hist, 1)
        if rec.cc ~= nil then table.remove(rec.cc, 1) end
        rec.manual, rec.skip, rec.skipEmpty = false, nil, nil
        rec.gap = true
    end
    if FieldListHUD.isCatchCrop(rec.next) then
        rec.next, rec.autoNext = nil, false
    end
    -- Bodenzustand merken, solange keine Zwischenfrucht steht (Anzeige "Aktuell" während der Zwischenfrucht)
    if not FieldListHUD.isCatchCrop(name) and entry.groundType ~= nil then
        rec.ccGround = entry.groundType
    end
    -- Düngung erkennen: steigt der Düngewert, gilt der Monat als gedüngt (pro Monat nur einmal möglich)
    if entry.spray ~= nil then
        if rec.lastSpray ~= nil and entry.spray > rec.lastSpray then
            rec.sprayKey = self:getMonthKey()
            rec.sprayGs = entry.growthState or 0 -- leeres Feld: 0
        elseif rec.lastSpray ~= nil and entry.spray < rec.lastSpray then
            rec.sprayGs = nil -- Düngung zurückgesetzt (Ernte/Neuaussaat)
        end
        rec.lastSpray = entry.spray
    end
    if FieldListHUD.isCatchCrop(name) then
        -- Zwischenfrucht: die Hauptfrucht davor ist abgeschlossen, Marker merken
        rec.ccPending = true
        rec.ccPlanned = false
        if rec.cur ~= nil then
            rec.gap = true
        end
        return
    end
    -- Nach manuellem Weiterschieben die alte Frucht (oder ein leeres Feld) ignorieren, bis etwas anderes wächst
    -- Wachstumsstand gegenüber der letzten Beobachtung: fällt er bei gleicher Frucht, wurde neu gesät
    local gsNow = entry.growthState
    local prevGs = rec.lastGs
    rec.lastGs = gsNow
    local growingNow = gsNow ~= nil and gsNow >= 1 and (entry.maxGrowth == nil or gsNow <= entry.maxGrowth)
    local resown = name ~= nil and not FieldListHUD.CUT_CROPS[name] and growingNow and prevGs ~= nil and gsNow < prevGs
    if rec.manual then
        if name == nil then
            if rec.skip ~= nil then rec.skipEmpty = true end
            return
        end
        if name == rec.skip then
            if not growingNow and not FieldListHUD.CUT_CROPS[name] then
                rec.skipEmpty = true
            end
            -- gleiche Frucht wie die weitergeschobene: nur wenn das Feld zwischendurch abgeerntet/leer war und sie neu wächst, ist es eine Neuaussaat
            if not (growingNow and (rec.skipEmpty or resown)) then
                return
            end
            rec.gap = true
        end
        rec.manual = false
        rec.skip = nil
        rec.skipEmpty = nil
    end
    if name == nil then
        if rec.cur ~= nil then
            rec.gap = true
        end
        return
    end
    if rec.cur == nil then
        self:captureSowFactor(rec, name, entry)
        rec.cur = name
        rec.gap = false
        rec.curSilage = nil
        if FieldListHUD.sameFruit(rec.next, name) then
            rec.curSilage = rec.silage
            rec.next = nil -- die geplante Folgefrucht ist jetzt angebaut
            rec.silage = nil
            rec.autoNext = false
        end
    elseif not FieldListHUD.sameFruit(name, rec.cur) or rec.gap then
        self:captureSowFactor(rec, name, entry)
        self:pushHist(rec, rec.cur)
        rec.cur = name
        rec.gap = false
        rec.curSilage = nil
        if FieldListHUD.sameFruit(rec.next, name) then
            rec.curSilage = rec.silage
            rec.next = nil -- die geplante Folgefrucht ist jetzt angebaut
            rec.silage = nil
            rec.autoNext = false
        end
        rec.done = false
    else
        -- Gleiche Frucht noch einmal gesät (Direktsaat auf Stoppeln): erst abgeerntet gesehen, dann wächst sie wieder
        local gs, mx = entry.growthState, entry.maxGrowth
        local growing = gs ~= nil and gs >= 1 and (mx == nil or gs <= mx)
        if FieldListHUD.CUT_CROPS[name] then
            rec.done = false -- Schnittfrüchte wachsen nach jedem Schnitt neu, das ist keine Neuaussaat
        elseif not growing then
            rec.done = true
        elseif rec.done or resown then
            rec.done = false
            self:captureSowFactor(rec, name, entry)
            self:pushHist(rec, rec.cur)
            if FieldListHUD.sameFruit(rec.next, name) then
                rec.curSilage = rec.silage
                rec.next = nil -- die geplante Folgefrucht ist jetzt angebaut
                rec.silage = nil
                rec.autoNext = false
            end
        end
    end
end

-- Schiebt die Fruchtfolge um einen Schritt weiter: Folgefrucht -> aktuell, aktuell -> Vorfrucht 1, usw.
function FieldListHUD:advanceFruit(id)
    local rec = self:getRecord(id)
    if rec.next == nil then
        return -- ohne gewählte Folgefrucht kann nichts weitergeschoben werden
    end
    -- Stand vor dem Weiterschieben merken (für "Rückgängig", nur bis zum Spielende)
    local snap = {}
    for _, k in ipairs({ "cur", "next", "autoNext", "autoOff", "skip", "manual", "gap", "done", "ccPending", "ccPlanned", "sowFactor", "sowFruit" }) do
        snap[k] = rec[k]
    end
    snap.hist, snap.cc = {}, {}
    for i, v in ipairs(rec.hist or {}) do snap.hist[i] = v end
    for i, v in pairs(rec.cc or {}) do snap.cc[i] = v end
    rec.undo = snap
    local old = rec.cur
    if old ~= nil then
        self:pushHist(rec, old)
    end
    rec.cur = rec.next
    rec.curSilage = rec.silage
    rec.next = nil
    rec.silage = nil
    rec.autoNext = false
    rec.skip = old
    rec.skipEmpty = nil
    rec.manual = true -- bis auf dem Feld wirklich etwas anderes wächst, gilt die weitergeschobene Frucht als aktuell
    rec.gap = false
end

-- Macht das letzte Weiterschieben rückgängig
function FieldListHUD:undoAdvance(id)
    local rec = self:getRecord(id)
    local snap = rec.undo
    if snap == nil then
        return
    end
    for k, v in pairs(snap) do
        if k ~= "hist" and k ~= "cc" then rec[k] = v end
    end
    for _, k in ipairs({ "cur", "next", "autoNext", "autoOff", "skip", "manual", "gap", "done", "ccPending", "ccPlanned", "sowFactor", "sowFruit" }) do
        if snap[k] == nil then rec[k] = nil end
    end
    rec.hist, rec.cc = snap.hist, snap.cc
    rec.undo = nil
end

-- Hat der Spieler die Fruchtfolge von Hand weitergeschoben, gilt diese Frucht als aktuell.
-- Gibt (Anzeige-Eintrag, Fruchtindex) zurück oder nil.
function FieldListHUD:getCurrentOverride(entry)
    local rec = entry.id ~= nil and self.store[entry.id] or nil
    if rec == nil or not rec.manual or rec.cur == nil then
        return nil
    end
    local e = self:getEntryByFruitName(rec.cur)
    local ft = g_fruitTypeManager:getFruitTypeByName(rec.cur)
    if e == nil or ft == nil then
        return nil
    end
    return e, ft.index
end

function FieldListHUD:saveData(dir)
    if dir == nil or self.store == nil then
        return
    end
    if g_currentMission ~= nil and g_currentMission.getIsServer ~= nil and not g_currentMission:getIsServer() then
        return
    end
    local ok, err = pcall(function()
        local path = dir .. "/" .. FieldListHUD.SAVE_FILE
        local h = createXMLFile("fieldListHUD", path, "fieldListHUD")
        setXMLInt(h, "fieldListHUD.filter#mode", self.filterMode or 1)
        setXMLInt(h, "fieldListHUD.filter#tableMode", self.tblFilter or 1)
        setXMLInt(h, "fieldListHUD.filter#workMode", self.wkFilter or 4)
        setXMLBool(h, "fieldListHUD.settings#rotYield", FieldListHUD.rotYield == true)
        setXMLBool(h, "fieldListHUD.settings#seasonal", FieldListHUD.seasonal == true)
        local ids = {}
        for id in pairs(self.store) do table.insert(ids, id) end
        table.sort(ids)
        for i, id in ipairs(ids) do
            local rec = self.store[id]
            local key = string.format("fieldListHUD.fields.field(%d)", i - 1)
            setXMLInt(h, key .. "#id", id)
            setXMLString(h, key .. "#next", rec.next or "")
            setXMLString(h, key .. "#current", rec.cur or "")
            setXMLBool(h, key .. "#gap", rec.gap == true)
            setXMLBool(h, key .. "#unused", rec.unused == true)
            setXMLString(h, key .. "#skip", rec.skip or "")
            setXMLBool(h, key .. "#manual", rec.manual == true)
            for n = 1, FieldListHUD.MAX_HIST do
                setXMLString(h, key .. "#prev" .. n, rec.hist[n] or "")
            end
            local ccs = {}
            for n = 1, FieldListHUD.MAX_HIST do
                ccs[n] = (rec.cc ~= nil and rec.cc[n]) and "1" or "0"
            end
            setXMLString(h, key .. "#cc", table.concat(ccs))
            setXMLBool(h, key .. "#ccPending", rec.ccPending == true)
            setXMLBool(h, key .. "#ccPlanned", rec.ccPlanned == true)
            setXMLBool(h, key .. "#silage", rec.silage == true)
            setXMLBool(h, key .. "#curSilage", rec.curSilage == true)
            setXMLBool(h, key .. "#autoNext", rec.autoNext == true)
            setXMLBool(h, key .. "#autoOff", rec.autoOff == true)
            if rec.sprayKey ~= nil then
                setXMLInt(h, key .. "#sprayKey", rec.sprayKey)
            end
            if rec.sprayGs ~= nil then
                setXMLInt(h, key .. "#sprayGs", rec.sprayGs)
            end
            if rec.post ~= nil and rec.post ~= "" then
                setXMLString(h, key .. "#post", rec.post)
            end
            do
                local hs = FieldListHUD.harvToString(rec)
                if hs ~= "" then setXMLString(h, key .. "#harv", hs) end
            end
            if rec.sowFactor ~= nil then
                setXMLFloat(h, key .. "#sowF", rec.sowFactor)
                setXMLString(h, key .. "#sowFruit", rec.sowFruit or "")
            end
        end
        saveXMLFile(h)
        delete(h)
        print(string.format("FieldListHUD: %d Felder gespeichert (%s)", #ids, path))
    end)
    if not ok then
        print("FieldListHUD: Speichern fehlgeschlagen: " .. tostring(err))
    end
end

function FieldListHUD:loadData(dir)
    self.store = {}
    if dir == nil then
        return
    end
    local ok, err = pcall(function()
        local path = dir .. "/" .. FieldListHUD.SAVE_FILE
        if not fileExists(path) and fileExists(dir .. "/" .. FieldListHUD.SAVE_FILE_OLD) then
            path = dir .. "/" .. FieldListHUD.SAVE_FILE_OLD -- Daten der früheren Datei übernehmen, gespeichert wird unter dem neuen Namen
        end
        if not fileExists(path) then
            print("FieldListHUD: keine gespeicherten Daten vorhanden (neu angelegt beim ersten Speichern)")
            return
        end
        local h = loadXMLFile("fieldListHUD", path)
        local rotY = getXMLBool(h, "fieldListHUD.settings#rotYield")
        if rotY ~= nil then FieldListHUD.rotYield = rotY end
        local seaY = getXMLBool(h, "fieldListHUD.settings#seasonal")
        if seaY ~= nil then FieldListHUD.seasonal = seaY end
        local mode = getXMLInt(h, "fieldListHUD.filter#mode")
        if mode ~= nil and mode >= 1 and mode <= #FieldListHUD.FILTERS then
            self.filterMode = mode
        end
        local wmode = getXMLInt(h, "fieldListHUD.filter#workMode")
        if wmode ~= nil and wmode >= 1 and wmode <= #FieldListHUD.FILTERS then
            self.wkFilter = wmode
        end
        local tmode = getXMLInt(h, "fieldListHUD.filter#tableMode")
        if tmode ~= nil and tmode >= 1 and tmode <= 3 then
            self.tblFilter = tmode
        end
        local i, count = 0, 0
        while true do
            local key = string.format("fieldListHUD.fields.field(%d)", i)
            local id = getXMLInt(h, key .. "#id")
            if id == nil then
                break
            end
            local rec = self:getRecord(id)
            local function val(attr)
                local v = getXMLString(h, key .. "#" .. attr)
                if v == nil or v == "" then return nil end
                return v
            end
            rec.next = val("next")
            rec.cur  = val("current")
            rec.gap  = getXMLBool(h, key .. "#gap") == true
            rec.unused = getXMLBool(h, key .. "#unused") == true
            rec.skip = val("skip")
            rec.manual = getXMLBool(h, key .. "#manual") == true
            rec.hist = {}
            for n = 1, FieldListHUD.MAX_HIST do
                local v = val("prev" .. n)
                if v == nil then break end
                table.insert(rec.hist, v)
            end
            rec.cc = {}
            local ccs = val("cc") or ""
            for n = 1, FieldListHUD.MAX_HIST do
                rec.cc[n] = string.sub(ccs, n, n) == "1"
            end
            rec.ccPending = getXMLBool(h, key .. "#ccPending") == true
            rec.ccPlanned = getXMLBool(h, key .. "#ccPlanned") == true
            rec.silage = getXMLBool(h, key .. "#silage") == true
            rec.curSilage = getXMLBool(h, key .. "#curSilage") == true
            rec.autoNext = getXMLBool(h, key .. "#autoNext") == true
            rec.autoOff = getXMLBool(h, key .. "#autoOff") == true
            rec.sowFactor = getXMLFloat(h, key .. "#sowF")
            rec.sprayKey = getXMLInt(h, key .. "#sprayKey")
            rec.sprayGs = getXMLInt(h, key .. "#sprayGs")
            do local pv = getXMLString(h, key .. "#post"); rec.post = (pv ~= nil and pv ~= "") and pv or nil end
            rec.sowFruit = val("sowFruit")
            rec.harv = FieldListHUD.parseHarv(val("harv"))
            i = i + 1
            count = count + 1
        end
        delete(h)
        print(string.format("FieldListHUD: %d Felder geladen (%s)", count, path))
    end)
    if not ok then
        print("FieldListHUD: Laden fehlgeschlagen: " .. tostring(err))
    end
end

------------------------------------------------------------------------
-- Darstellung
------------------------------------------------------------------------

function FieldListHUD:getIcon(filename)
    if filename == nil then
        return nil
    end
    local icon = self.icons[filename]
    if icon == nil then
        icon = Overlay.new(filename, 0, 0, 0.02, 0.04)
        self.icons[filename] = icon
    end
    return icon
end

-- Zeichnet ein farbiges Rechteck mit dem gemeinsamen Overlay
function FieldListHUD:drawRect(x, y, w, h, color)
    self.bg:setPosition(x, y)
    self.bg:setDimension(w, h)
    self.bg:setColor(color[1], color[2], color[3], color[4])
    self.bg:render()
end

-- Rechteck mit Füllung und Rahmen
function FieldListHUD:drawFrame(x, y, w, h, fill, border)
    local bwY = 0.0016
    local bwX = bwY / (g_screenAspectRatio or (16 / 9))
    self:drawRect(x, y, w, h, border)
    self:drawRect(x + bwX, y + bwY, w - 2 * bwX, h - 2 * bwY, fill)
end

-- Eine Kachel; y ist die Unterkante
-- Ertragsbonus eines Feldes in Prozent (Höchstwert 100); Anzeige und Rechnung: Basis 100 % + Bonus. Gewichte nach der Spielmechanik:
-- Pflügen 15, Kalken 15, Düngen 45 (2 Stufen), Unkraut 20, Mulchen 2,5, Walzen 2,5.
-- Die Werte wurden an den Zahlen eines anderen Mods geprüft (z. B. Feld 22: 97,5 %, Feld 1: 22,5 %).
function FieldListHUD:getYieldPercent(entry, force)
    if entry.fruitIndex == nil and not force then
        return nil
    end
    local fm = g_fieldManager
    local mi = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    local sprayMax = (fm ~= nil and fm.sprayLevelMaxValue) or 2
    local limeMax  = (fm ~= nil and fm.limeLevelMaxValue) or 3

    local pct = 0
    -- Kalk (nur wenn im Spielstand erforderlich)
    if mi ~= nil and mi.limeRequired == false then
        pct = pct + 15
    else
        pct = pct + 15 * math.min(1, (entry.lime or 0) / math.max(1, limeMax))
    end
    -- Dünger
    pct = pct + 45 * math.min(1, (entry.spray or 0) / math.max(1, sprayMax))
    -- Pflügen (nur wenn im Spielstand vorgeschrieben)
    if (mi ~= nil and mi.plowingRequiredEnabled == false) or (entry.plow or 0) > 0 then
        pct = pct + 15
    end
    -- Unkraut: volle Punkte ohne Unkraut, sonst anteilig nach Unkrautfaktor
    if (mi ~= nil and mi.weedsEnabled == false) or (entry.weed or 0) <= 0 then
        pct = pct + 20
    else
        pct = pct + 20 * math.max(0, 1 - (entry.weedFactor or 1))
    end
    -- Mulchen (Stoppelbearbeitung) und Walzen
    if (entry.stubble or 0) > 0 then
        pct = pct + 2.5
    end
    if (entry.roller or 0) <= 0 then
        pct = pct + 2.5
    end

    self.yieldLog = self.yieldLog or {}
    local sig = string.format("%.1f lime=%s spray=%s plow=%s weed=%s/%s stubble=%s roller=%s", pct,
        tostring(entry.lime), tostring(entry.spray), tostring(entry.plow), tostring(entry.weed),
        tostring(entry.weedFactor), tostring(entry.stubble), tostring(entry.roller))
    if self.yieldLog[entry.id] ~= sig then
        self.yieldLog[entry.id] = sig
    end
    return pct
end

function FieldListHUD:getYieldColor(pct)
    if pct == nil then return self.colorSub end
    if pct >= 90 then return self.colorArea end
    if pct >= 70 then return self.colorWork end
    return { 0.95, 0.35, 0.30, 1.00 }
end

-- Anstehende Arbeiten eines Feldes in der Reihenfolge der Dringlichkeit.
-- text = ausführlich (Bodenzustand), short = kurz (Kachel)
-- Zurückgestellte Arbeiten: bis zum Beginn des nächsten Monats ausgeblendet. rec.post = "art:monat;art:monat"
function FieldListHUD:isPostponed(id, kind)
    local rec = id ~= nil and self.store ~= nil and self.store[id] or nil
    local key = self:getMonthKey()
    if rec == nil or rec.post == nil or key == nil then return false end
    for k, untilKey in string.gmatch(rec.post, "([^:;]+):(%d+)") do
        if k == kind and key < tonumber(untilKey) then return true end
    end
    return false
end

function FieldListHUD:togglePostpone(id, kind)
    local key = self:getMonthKey()
    if id == nil or kind == nil or kind == "harvest" or key == nil then return end
    local rec = self:getRecord(id)
    local keep, found = {}, false
    for k, untilKey in string.gmatch(rec.post or "", "([^:;]+):(%d+)") do
        if tonumber(untilKey) > key then          -- abgelaufene Einträge verwerfen
            if k == kind then found = true else keep[#keep + 1] = k .. ":" .. untilKey end
        end
    end
    if not found then keep[#keep + 1] = kind .. ":" .. (key + 1) end
    rec.post = #keep > 0 and table.concat(keep, ";") or nil
    self.wkDirty, self.p3Dirty, self.hudRows = true, true, nil
    self:markDirtyCaches()
end

-- Arbeiten eines Feldes. Die Kacheln fragen das jedes Bild ab, deshalb wird das Ergebnis kurz am Eintrag zwischengespeichert
-- (höchstens 0,3 s; sofort ungültig, wenn markDirtyCaches/Verschieben die Version erhöhen).
function FieldListHUD:getWorkItems(entry, withPostponed)
    local now = g_time or 0
    local all = entry.wiAll
    if all == nil or entry.wiVer ~= self.wiVersion or now - (entry.wiTime or 0) > 300 then
        all = {}
        for _, it in ipairs(self:getWorkItemsAll(entry)) do
            it.postponed = it.kind ~= "harvest" and self:isPostponed(entry.id, it.kind) or false
            all[#all + 1] = it
        end
        entry.wiAll, entry.wiVer, entry.wiTime = all, self.wiVersion, now
    end
    if withPostponed then
        return all
    end
    local out = {}
    for _, it in ipairs(all) do
        if not it.postponed then out[#out + 1] = it end
    end
    return out
end

function FieldListHUD:getWorkItemsAll(entry)
    local items = {}
    if entry.unused then
        return items
    end
    local fm = g_fieldManager
    local sprayMax = (fm ~= nil and fm.sprayLevelMaxValue) or 2
    local mi = g_currentMission ~= nil and g_currentMission.missionInfo or nil

    if entry.harvestReady and not FieldListHUD.isCatchCrop(entry.fruitName) then
        table.insert(items, { prio = 1, kind = "harvest", text = T("ground_ready"), short = T("ground_ready"), harvest = true })
    end
    if self:needsPlowing(entry) then
        table.insert(items, { prio = 2, kind = "plow", text = T("status_mustplow"), short = T("work_plow_short") })
    end
    if entry.stone ~= nil and entry.stone > 0 then
        local names = { [2] = T("stone_small"), [3] = T("stone_medium"), [4] = T("stone_large") }
        local tot = math.max(1, entry.stoneTotal or 1)
        local parts = {}
        for v = 2, 4 do
            local n = entry.stoneCounts ~= nil and entry.stoneCounts[v] or 0
            if n > 0 then
                table.insert(parts, string.format("%s %d %%", names[v], math.max(1, math.floor(100 * n / tot + 0.5))))
            end
        end
        table.insert(items, { prio = 3, kind = "stones", cell = string.format("%d %%", math.max(1, math.floor(100 * (entry.stone or 0) / math.max(1, entry.stoneTotal or 1) + 0.5))), text = T("work_stones") .. (#parts > 0 and table.concat(parts, ", ") or T("work_stones_present")),
                              short = T("work_stones_short") })
    end
    -- Kalken geht nur auf leerem Feld oder bei frisch gesäter Frucht (Stufe 1); Düngen nicht mehr, sobald die Frucht erntereif ist
    local growing = entry.fruitIndex ~= nil and entry.growthState ~= nil and entry.growthState >= 1
        and (entry.maxGrowth == nil or entry.growthState <= entry.maxGrowth)
    local limeBlocked = growing and entry.growthState > 1
    local sprayBlocked = false
    if growing then
        local ftg = g_fruitTypeManager:getFruitTypeByIndex(entry.fruitIndex)
        local minHarvest = ftg ~= nil and FieldListHUD.harvestMinState(ftg) or nil
        sprayBlocked = entry.harvestReady == true or (minHarvest ~= nil and entry.growthState >= minHarvest)
    end
    if mi ~= nil and mi.limeRequired and entry.lime ~= nil and entry.lime <= 0 and not limeBlocked then
        table.insert(items, { prio = 4, kind = "lime", cell = string.format("%d/%d", entry.lime or 0, (fm ~= nil and fm.limeLevelMaxValue) or 3), text = T("work_lime"), short = T("work_lime_short") })
    end
    -- Leeres Feld: nur die erste Düngung (0 -> 1) ist möglich; die zweite braucht eine Frucht, die eine Stufe gewachsen ist
    local emptySecond = not growing and (entry.spray or 0) >= 1
    if entry.spray ~= nil and entry.spray < sprayMax and not sprayBlocked and not emptySecond and not self:sprayBlockedAgain(entry) then
        table.insert(items, { prio = 5, kind = "spray", cell = string.format("%d/%d", entry.spray or 0, sprayMax), text = T("work_spray"), short = T("work_spray_short") })
    end
    if entry.weed ~= nil and entry.weed > 0 then
        local ws = FieldListHUD.weedSize(entry.weed)
        table.insert(items, { prio = ws >= 3 and 3 or 6, kind = "weeds", cell = T("weed_cell_" .. ws), text = T("weed_" .. ws), short = T("weed_hud_" .. ws), cell2 = T("weed_hud_" .. ws) })
    end
    -- Geplante Zwischenfrucht (Ölrettich), noch nicht gesät: Arbeit, solange das Feld leer ist und das Saatfenster offen ist
    do
        local rc = self.store ~= nil and self.store[entry.id] or nil
        if rc ~= nil and rc.ccPlanned and not rc.ccPending then
            local gs = entry.growthState
            local empty = entry.fruitTitle == nil
                or (gs ~= nil and not entry.harvestReady and not (gs >= 1 and (entry.maxGrowth == nil or gs <= entry.maxGrowth)))
            if empty and self:canSowNow("OILSEEDRADISH") then
                local ce = self:getEntryByFruitName("OILSEEDRADISH")
                table.insert(items, { prio = 6, kind = "cc", cell = (ce ~= nil and ce.fruitTitle) or "Ölrettich", text = string.format(T("work_cc"), (ce ~= nil and ce.fruitTitle) or "Ölrettich"), short = T("work_cc_short") })
            end
        end
    end
    local rcSow = self.store ~= nil and self.store[entry.id] or nil
    local sowDue = self:needsSowing(entry) and self:canSowNow(rcSow.next)
    -- Erntereifes Feld: ist das Saatfenster der Folgefrucht schon offen, steht die Aussaat im selben Monat an (nach der Ernte)
    if not sowDue and entry.harvestReady and not FieldListHUD.isCatchCrop(entry.fruitName)
        and rcSow ~= nil and rcSow.next ~= nil and not rcSow.manual and self:canSowNow(rcSow.next) then
        sowDue = true
    end
    if sowDue then
        local ne = self:getNextFruitEntry(entry)
        table.insert(items, { prio = 7, kind = "sow", cell = (ne ~= nil and ne.fruitTitle) or "?", text = string.format(T("work_sow"), (ne ~= nil and ne.fruitTitle) or "?"), short = T("work_sow_short") })
    end
    if self:needsRolling(entry) then
        table.insert(items, { prio = 8, kind = "roll", text = T("status_mustroll"), short = T("work_roll_short") })
    end
    return items
end

------------------------------------------------------------------------
-- Fahrzeuge auf Feldern (eigene Zugmaschinen/Selbstfahrer), alle 3 s neu ermittelt
------------------------------------------------------------------------

-- Feldumrisse einmal als Weltkoordinaten zwischenspeichern
function FieldListHUD:getFieldPolys()
    if self.fieldPolys ~= nil then return self.fieldPolys end
    local polys = {}
    pcall(function()
        for _, field in pairs(g_fieldManager:getFields()) do
            local pts = field.polygonPoints
            local id = self:getFieldNumber(field)
            if type(pts) == "table" and #pts >= 3 and id ~= nil then
                local px, pz = {}, {}
                local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
                for i = 1, #pts do
                    local x, _, z = getWorldTranslation(pts[i])
                    px[i], pz[i] = x, z
                    minX, maxX = math.min(minX, x), math.max(maxX, x)
                    minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
                end
                table.insert(polys, { id = id, px = px, pz = pz, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
            end
        end
    end)
    if #polys > 0 then self.fieldPolys = polys end
    return polys
end

local function pointInPoly(poly, x, z)
    if x < poly.minX or x > poly.maxX or z < poly.minZ or z > poly.maxZ then return false end
    local px, pz = poly.px, poly.pz
    local c = false
    local j = #px
    for i = 1, #px do
        if (pz[i] > z) ~= (pz[j] > z) and x < (px[j] - px[i]) * (z - pz[i]) / (pz[j] - pz[i]) + px[i] then
            c = not c
        end
        j = i
    end
    return c
end

-- Liefert { count, working, names } für ein Feld oder nil
function FieldListHUD:getVehiclesOnField(id)
    local now = g_time or 0
    if self.vehTime == nil or (now - self.vehTime) >= 3000 then
        self.vehTime = now
        local res = {}
        local stat = { total = 0, motor = 0, own = 0, inField = 0, polys = 0 }
        local ok, err = pcall(function()
            local mission = g_currentMission
            local farmId = mission:getFarmId()
            local list = (mission.vehicleSystem ~= nil and mission.vehicleSystem.vehicles) or mission.vehicles or {}
            local polys = self:getFieldPolys()
            stat.polys = #polys
            for _, v in pairs(list) do
                stat.total = stat.total + 1
                if v.spec_motorized ~= nil and (v.spec_drivable ~= nil or v.spec_enterable ~= nil) then
                    stat.motor = stat.motor + 1
                    local owner = nil
                    if v.getOwnerFarmId ~= nil then owner = v:getOwnerFarmId() end
                    local node = v.rootNode
                    if (owner == nil or owner == farmId) and node ~= nil then
                        stat.own = stat.own + 1
                        local x, _, z = getWorldTranslation(node)
                        for _, poly in ipairs(polys) do
                            if pointInPoly(poly, x, z) then
                                stat.inField = stat.inField + 1
                                local working = false
                                pcall(function()
                                    if v.getIsMotorStarted ~= nil and v:getIsMotorStarted() then
                                        if v.getLastSpeed ~= nil and v:getLastSpeed() > 0.5 then working = true end
                                        if not working and v.getAttachedImplements ~= nil then
                                            for _, imp in ipairs(v:getAttachedImplements()) do
                                                local o = imp.object
                                                if o ~= nil and o.getIsTurnedOn ~= nil and o:getIsTurnedOn() then working = true break end
                                            end
                                        end
                                    end
                                end)
                                local r = res[poly.id]
                                if r == nil then r = { count = 0, working = false, names = {} }; res[poly.id] = r end
                                r.count = r.count + 1
                                r.working = r.working or working
                                table.insert(r.names, v.getName ~= nil and v:getName() or "?")
                                break
                            end
                        end
                    end
                end
            end
        end)
        if not ok then
            print("[FieldManager] Fahrzeugerkennung fehlgeschlagen: " .. tostring(err))
        end
        self.vehOnField = res
    end
    return self.vehOnField ~= nil and self.vehOnField[id] or nil
end

-- Kleines Traktorsymbol aus Rechtecken (x, y = untere linke Ecke, w, h in Bildschirmeinheiten)
function FieldListHUD:drawTractorBadge(x, y, w, h, working, count, restoreValign)
    local col = working and { 0.71, 0.87, 0.0, 1 } or { 0.85, 0.85, 0.85, 1 }
    local icon = self:getIcon(self.modDirectory .. "gui/tractor.dds")
    if icon ~= nil then
        icon:setPosition(x, y)
        icon:setDimension(w, h)
        icon:setColor(col[1], col[2], col[3], col[4])
        icon:render()
    end
    -- Bei 2 oder mehr Fahrzeugen: kleine Zahl rechts neben dem Symbol
    if count ~= nil and count >= 2 then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(col[1], col[2], col[3], col[4])
        renderText(x + w + 0.0025, y + h / 2, h * 0.62, tostring(count))
        setTextBold(false)
        setTextVerticalAlignment(restoreValign or RenderText.VERTICAL_ALIGN_TOP)
    end
end

function FieldListHUD:drawTile(entry, x, y, w, h, selected)
    local pad = h * 0.09

    self:drawFrame(x, y, w, h, selected and self.colorTileSelected or self.colorTile,
        selected and self.colorArea or self.colorBorder)

    -- Icon-Feld links (quadratisch, unabhängig vom Seitenverhältnis)
    local iconH = h - 2 * pad
    local iconW = iconH / (g_screenAspectRatio or (16 / 9))
    local iconX = x + pad
    local iconY = y + pad
    self:drawRect(iconX, iconY, iconW, iconH, entry.fruitTitle == nil and self:getNoFruitColor(entry) or self.colorIcon)

    local icon = self:getIcon(entry.iconFilename)
    if icon ~= nil then
        icon:setPosition(iconX, iconY)
        icon:setDimension(iconW, iconH)
        icon:render()
    end

    local titleSize = h * 0.27
    local subSize   = h * 0.20
    local textX     = iconX + iconW + pad * 1.5
    local subX      = textX

    -- Folgefrucht (falls geplant): Pfeil und kleines Icon (50 %) rechts neben dem Fruchticon, mittig.
    -- Der Platz wird immer reserviert, damit der Text in allen Kacheln an derselben Stelle steht.
    local sh = iconH * 0.5
    local sw = sh / (g_screenAspectRatio or (16 / 9))
    local arrowSize = iconH * 0.32
    local aw = getTextWidth(arrowSize, ">")
    local ax = iconX + iconW + pad * 0.5
    local nx = ax + aw + pad * 0.4
    local topY = iconY + iconH - sh
    local midY = topY + sh / 2
    local recN = self.store ~= nil and self.store[entry.id] or nil
    if recN ~= nil and recN.next ~= nil and not entry.unused then
        local en = self:getEntryByFruitName(recN.next)
        local nIcon = en ~= nil and self:getIcon(en.iconFilename) or nil
        if nIcon ~= nil then
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextBold(true)
            setTextColor(unpack(recN.autoNext and { 0.55, 0.75, 1, 1 } or self.colorArea))
            renderText(ax, midY, arrowSize, ">")
            setTextBold(false)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
            self:drawRect(nx, midY - sh / 2, sw, sh, self.colorIcon)
            nIcon:setPosition(nx, midY - sh / 2)
            nIcon:setDimension(sw, sh)
            nIcon:render()
        end
    end
    -- Titelzeile steht rechts neben der Folgefrucht, die Zeile darunter (Fruchtname · Kategorie) beginnt direkt am Fruchticon
    textX = nx + sw + pad * 1.2
    local rightX    = x + w - pad
    local titleY    = y + h - pad * 1.6
    local subY      = titleY - titleSize * 1.5

    -- Titel: FELD NN
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(textX, titleY, titleSize, string.format(T("tile_field"), entry.id))
    -- Traktorsymbol hinter dem Feldnamen, wenn ein eigenes Fahrzeug auf dem Feld steht (grün = arbeitet, grau = steht)
    local veh = self:getVehiclesOnField(entry.id)
    if veh ~= nil then
        local bh = titleSize * 1.25
        local bw = bh / (g_screenAspectRatio or (16 / 9))
        local bx = textX + getTextWidth(titleSize, string.format(T("tile_field"), entry.id)) + pad * 0.9
        self:drawTractorBadge(bx, titleY - bh * 1.0 + titleSize * 0.12, bw, bh, veh.working, veh.count, RenderText.VERTICAL_ALIGN_TOP)
    end

    -- Fläche rechts in Grün
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextColor(unpack(self.colorArea))
    renderText(rightX, titleY, titleSize, string.format("%.2f HA", entry.area))

    -- Untertitel: Frucht · Kategorie
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(unpack(self.colorSub))
    local subtitle = self:getSubtitle(entry)
    renderText(subX, subY, subSize, subtitle)

    -- Wichtigste anstehende Arbeit unter der Flächenangabe (rechts)
    local workItems = self:getWorkItems(entry)
    local item = workItems[1]
    local isWork = item ~= nil
    if item ~= nil and #workItems > 1 then
        -- Mehr als eine Arbeit: "(+)" hinter der wichtigsten
        item = { text = item.text, short = item.short .. " (+)", harvest = item.harvest, prio = item.prio }
    end
    if item == nil and entry.fruitTitle == nil and not entry.unused then
        -- Keine Arbeit offen: bei leeren Feldern den Bearbeitungszustand zeigen (Stoppelsturz, Gegrubbert ...)
        local ground = self:getGroundText(entry)
        if ground ~= nil and ground ~= T("ground_fallow") then
            item = { short = ground }
        end
    end
    if item == nil and entry.fruitTitle ~= nil and not entry.unused and not entry.harvestReady
        and entry.growthState ~= nil and entry.maxGrowth ~= nil and entry.growthState >= 1
        and entry.growthState <= entry.maxGrowth then
        -- Keine Arbeit offen: Wachstumsstatus anzeigen (z. B. "Wächst 1/4")
        item = { short = string.format(T("tile_growing"), entry.growthState, entry.maxGrowth) }
    end
    if item ~= nil then
        local size = subSize
        local free = rightX - (subX + getTextWidth(subSize, subtitle)) - pad
        local tw = getTextWidth(size, item.short)
        if tw > free then
            size = size * free / tw
        end
        if size >= subSize * 0.7 then
            setTextAlignment(RenderText.ALIGN_RIGHT)
            setTextBold(true)
            setTextColor(unpack(item.harvest and self.colorArea or (isWork and self.colorWork or self.colorGround)))
            renderText(rightX, subY, size, item.short)
            setTextBold(false)
        end
    end
end

function FieldListHUD:getSubtitle(entry)
    if entry.unused then
        return T("unused")
    elseif entry.fruitTitle == nil then
        return T("no_crop")
    elseif entry.category ~= nil and string.lower(entry.category) ~= string.lower(entry.fruitTitle) then
        return entry.fruitTitle .. " · " .. entry.category
    end
    return entry.fruitTitle
end

------------------------------------------------------------------------
-- Seitenbereich und Layout
------------------------------------------------------------------------

local function hasRect(e)
    return e ~= nil and e.absPosition ~= nil and e.absSize ~= nil
end

-- Inhaltsbereich der Seite (Bildschirmanteile).
function FieldListHUD:getPageArea()
    local menu = g_inGameMenu
    local root = nil
    if self.frame ~= nil and self.frame.elements ~= nil then
        root = self.frame.elements[1]
    end

    local e, source
    if hasRect(root) and root.absSize[1] > 0.2 and root.absSize[2] > 0.2
        and root.absSize[1] < 0.98 and root.absSize[2] < 0.98 then
        e, source = root, "Frame"
    elseif menu ~= nil and hasRect(menu.pagingElement)
        and menu.pagingElement.absSize[1] > 0.2 and menu.pagingElement.absSize[2] > 0.2 then
        e, source = menu.pagingElement, "Paging-Element"
    end

    if e == nil then
        return 0.07, 0.06, 0.92, 0.92, "Fallback"
    end

    local x, y, w, h = e.absPosition[1], e.absPosition[2], e.absSize[1], e.absSize[2]

    -- Untere Buttonleiste des Menüs aussparen
    local bp = menu ~= nil and menu.buttonsPanel or nil
    if hasRect(bp) and bp.absSize[2] > 0 then
        local limit = bp.absPosition[2] + bp.absSize[2]
        if limit > y and limit < y + h * 0.5 then
            h = h - (limit - y)
            y = limit
        end
    end

    return x, y, w, h, source
end

-- Reihenfolge = Anzeige von links nach rechts; mode ist die feste Filter-Nummer (wird gespeichert)
FieldListHUD.FILTERS = {
    { mode = 4, label = T("filter_work") },
    { mode = 3, label = T("filter_crops") },
    { mode = 2, label = T("filter_cropsgrass") },
    { mode = 1, label = T("filter_all") },
}

-- Grasfeld: aktuelle Frucht ist "Gras" (auch Wiese, die im Spiel als Gras angezeigt wird)
FieldListHUD.CUT_CROPS = { GRASS = true, MEADOW = true, FIELDGRASS = true, CLOVER = true, ALFALFA = true }

function FieldListHUD.isGrassName(name)
    return name == "GRASS" or name == "MEADOW"
end

-- Passt das Feld zum gewählten Filter? 1 = alle, 2 = nur Gras, 3 = nur Fruchtfelder ohne Gras, 4 = Arbeiten
function FieldListHUD:matchesFilter(entry, modeOverride)
    local mode = modeOverride or self.filterMode or 1
    if mode == 1 then
        return true
    end
    -- als ungenutzt markierte Felder sind weder Frucht- noch Grasfeld
    if entry.unused then
        return false
    end
    -- Arbeiten: nur Felder, auf denen eine Arbeit ansteht
    if mode == 4 then
        return #self:getWorkItems(entry) > 0
    end
    -- Fruchtfeld = jedes genutzte Feld, das kein Gras trägt (auch ohne aktuelle Frucht)
    if mode == 3 then
        return not FieldListHUD.isGrassName(entry.fruitName)
    end
    -- Gras: nur Felder mit Gras oder Wiese
    if mode == 2 then
        return FieldListHUD.isGrassName(entry.fruitName)
    end
    return true
end

function FieldListHUD:applyFilter()
    local list = {}
    for _, e in ipairs(self.fields or {}) do
        if self:matchesFilter(e) then
            table.insert(list, e)
        end
    end
    self.visible = list
end

function FieldListHUD:setFilter(mode)
    if mode == self.filterMode then
        return
    end
    self.filterMode = mode
    self.scrollOffset = 0
    self:applyFilter()
    -- Ist das gewählte Feld ausgeblendet, das erste sichtbare wählen
    local sel = self.selectedId
    local found = false
    for _, e in ipairs(self.visible) do
        if e.id == sel then found = true break end
    end
    if not found then
        local f = self:getFirstUsedField()
        if f ~= nil then self.selectedId = f.id end
    end
end

-- Berechnet Listen- und Detailbereich sowie die sichtbaren Kacheln
function FieldListHUD:computeLayout()
    local ax, ay, aw, ah, source = self:getPageArea()

    -- Außenabstände wie bei den anderen Menüseiten, relativ zur Größe des Inhaltsbereichs
    local insetLeft, insetRight, insetTop, insetBottom = 0.097, 0.040, 0.081, 0.013
    local nx = ax + aw * insetLeft
    local ny = ay + ah * insetBottom
    local nw = aw * (1 - insetLeft - insetRight)
    local nh = ah * (1 - insetTop - insetBottom)
    ax, ay, aw, ah = nx, ny, nw, nh

    local key = string.format("%s %.3f %.3f %.3f %.3f", source, ax, ay, aw, ah)
    if key ~= self.lastAreaLog then
        self.lastAreaLog = key
    end

    local pad     = 0.010
    local gap     = 0.006
    local tileH   = 0.055
    local scrollW = 0.006
    local listW   = aw * 0.235

    local L = { ax = ax, ay = ay, aw = aw, ah = ah, pad = pad, tiles = {} }

    -- Linkes Panel
    L.listPanel = { x = ax, y = ay, w = listW, h = ah }
    L.titleX = ax + listW / 2
    L.titleY = ay + ah

    local filterH = 0.026
    local headerH = 0.050
    local listTop = ay + ah - headerH

    -- Filter-Schaltflächen am unteren Rand des Panels
    L.filterBtns = {}
    local fgap = 0.004
    local fw = (listW - 2 * pad - (#FieldListHUD.FILTERS - 1) * fgap) / #FieldListHUD.FILTERS
    for i = 1, #FieldListHUD.FILTERS do
        table.insert(L.filterBtns, {
            mode = FieldListHUD.FILTERS[i].mode,
            label = FieldListHUD.FILTERS[i].label,
            x = ax + pad + (i - 1) * (fw + fgap),
            y = ay + pad,
            w = fw,
            h = filterH,
        })
    end
    self:applyFilter()
    local listBottom = ay + pad + filterH + 0.008
    local listH = math.max(0.05, listTop - listBottom)
    L.list = { x = ax + pad, y = listBottom, w = listW - 2 * pad, h = listH }

    local count = #self.visible
    local rows  = math.max(1, math.floor((listH + gap) / (tileH + gap)))
    self.maxOffset = math.max(0, count - rows)
    self.scrollOffset = math.max(0, math.min(self.scrollOffset, self.maxOffset))

    local tileW = L.list.w - (count > rows and (scrollW + gap) or 0)
    for r = 1, rows do
        local index = self.scrollOffset + r
        if index > count then
            break
        end
        table.insert(L.tiles, {
            index = index,
            x = L.list.x,
            y = L.list.y + listH - r * tileH - (r - 1) * gap,
            w = tileW,
            h = tileH,
        })
    end

    if count > rows then
        local thumbH = math.max(0.03, listH * rows / count)
        local frac   = self.maxOffset > 0 and (self.scrollOffset / self.maxOffset) or 0
        L.track = { x = L.list.x + L.list.w - scrollW, y = L.list.y, w = scrollW, h = listH }
        L.thumb = { x = L.track.x, y = L.list.y + listH - thumbH - (listH - thumbH) * frac,
                    w = scrollW, h = thumbH }
    end

    -- Rechter Bereich
    local dx = ax + listW + 0.02
    L.detail = { x = dx, y = ay + pad, w = ax + aw - dx - 0.015, h = ah - pad }

    return L
end

------------------------------------------------------------------------
-- Zeichnen
------------------------------------------------------------------------

function FieldListHUD:getSelectedEntry()
    for _, entry in ipairs(self.fields) do
        if entry.id == self.selectedId then
            return entry
        end
    end
    local first = self:getFirstUsedField()
    if first ~= nil then
        self.selectedId = first.id
        return first
    end
    return nil
end

-- Erstes sichtbares Feld, das genutzt wird; gibt es keins, das erste sichtbare bzw. überhaupt erste Feld
function FieldListHUD:getFirstUsedField()
    for _, e in ipairs(self.visible or {}) do
        if not e.unused then return e end
    end
    for _, e in ipairs(self.fields or {}) do
        if not e.unused and self:matchesFilter(e) then return e end
    end
    return (self.visible ~= nil and self.visible[1]) or (self.fields ~= nil and self.fields[1]) or nil
end

FieldListHUD.CATEGORY_COLORS = {
    [T("cat_cereal")]     = { 0.85, 0.62, 0.05, 1 },
    [T("cat_maize")]         = { 0.85, 0.62, 0.05, 1 },
    [T("cat_oilseed")]     = { 0.85, 0.80, 0.10, 1 },
    [T("cat_legume")] = { 0.40, 0.65, 0.30, 1 },
    [T("cat_root")]   = { 0.75, 0.38, 0.30, 1 },
    [T("cat_vegetable")]       = { 0.75, 0.38, 0.30, 1 },
    [T("cat_forage")]       = { 0.35, 0.60, 0.50, 1 },
    [T("cat_fiber")] = { 0.55, 0.50, 0.30, 1 },
    [T("cat_special")]   = { 0.62, 0.45, 0.70, 1 },
    [T("cat_perennial")] = { 0.55, 0.40, 0.65, 1 },
    [T("cat_tree")]      = { 0.30, 0.55, 0.35, 1 },
    [T("cat_other")]     = { 0.60, 0.60, 0.60, 1 },
}

-- Abschnittsüberschrift mit Linie; gibt die Unterkante zurück
function FieldListHUD:drawSection(x, y, w, text)
    local size = 0.014
    self:drawRect(x, y - size - 0.004, 0.0025, size + 0.004, self.colorArea)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorArea))
    renderText(x + 0.008, y, size, text)
    setTextBold(false)
    local textW = getTextWidth(size, text)
    self:drawRect(x + 0.018 + textW, y - size * 0.55, w - 0.018 - textW, 0.0008, self.colorTrack)
    return y - size - 0.012
end

-- Ein Kasten der Anbaugeschichte
function FieldListHUD:drawHistoryBox(x, y, w, h, label, entry, highlight, border)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(highlight and self.colorArea or self.colorTitle))
    renderText(x + w / 2, y + h + 0.020, 0.010, label)
    setTextBold(false)

    self:drawFrame(x, y, w, h, self.colorTile, border or (highlight and self.colorArea or self.colorBorder))
    if highlight then
        self:drawRect(x, y, w, 0.002, self.colorArea)
    elseif border then
        self:drawRect(x, y, w, 0.004, border)
    end

    if entry ~= nil and entry.fruitTitle == nil and entry.id ~= nil then
        -- Aktuelles Feld ohne Frucht: Bildbereich hellblau, darunter der Bodenzustand
        local iconH = h * 0.42
        local iconW = iconH / (g_screenAspectRatio or (16 / 9))
        local ix = x + (w - iconW) / 2
        local iy = y + h - iconH - h * 0.10
        self:drawRect(ix, iy, iconW, iconH, self:getNoFruitColor(entry))
        setTextColor(unpack(self.colorTitle))
        renderText(x + w / 2, iy - 0.004, 0.012, self:getStatusText(entry))
        return
    end

    if entry == nil or entry.fruitTitle == nil then
        setTextColor(unpack(self.colorSub))
        renderText(x + w / 2, y + h / 2 + 0.006, 0.013, "-")
        return
    end

    local iconH = h * 0.42
    local iconW = iconH / (g_screenAspectRatio or (16 / 9))
    local ix = x + (w - iconW) / 2
    local iy = y + h - iconH - h * 0.10
    self:drawRect(ix, iy, iconW, iconH, self.colorIcon)
    local icon = self:getIcon(entry.iconFilename)
    if icon ~= nil then
        icon:setPosition(ix, iy)
        icon:setDimension(iconW, iconH)
        icon:render()
    end

    setTextColor(unpack(self.colorTitle))
    renderText(x + w / 2, iy - 0.004, 0.012, entry.fruitTitle)

    if entry.category ~= nil then
        local c = self.CATEGORY_COLORS[entry.category] or self.colorIcon
        local tagW = getTextWidth(0.009, string.upper(entry.category)) + 0.012
        local tagH = 0.016
        self:drawRect(x + (w - tagW) / 2, y + h * 0.07, tagW, tagH, c)
        setTextBold(true)
        setTextColor(0.08, 0.08, 0.08, 1)
        renderText(x + w / 2, y + h * 0.07 + tagH - 0.0025, 0.009, string.upper(entry.category))
        setTextBold(false)
    end
end

------------------------------------------------------------------------
-- Nächste Frucht und Jahreskalender
------------------------------------------------------------------------

FieldListHUD.MONTHS = { T("m1"), T("m2"), T("m3"), T("m4"), T("m5"), T("m6"), T("m7"), T("m8"), T("m9"), T("m10"), T("m11"), T("m12") }

function FieldListHUD:getFruitOptions()
    if self.fruitOptions ~= nil then
        return self.fruitOptions
    end
    local list, seen = {}, {}
    local fm = g_fieldManager
    local indices = fm ~= nil and fm.availableFruitTypeIndices or nil
    if indices ~= nil then
        for k, v in pairs(indices) do
            local idx = (type(v) == "number") and v or k
            local ft = g_fruitTypeManager:getFruitTypeByIndex(idx)
            if ft ~= nil and ft.allowsSeeding and not seen[ft.index] and not FieldListHUD.isCatchCrop(ft.name) then
                seen[ft.index] = true
                local title = (ft.fillType ~= nil and ft.fillType.title) or ft.name
                table.insert(list, { index = ft.index, name = string.upper(ft.name or ""), title = title })
            end
        end
    end
    table.sort(list, function(a, b) return a.title < b.title end)
    -- Mais: zwei Einträge, Körner oder Silage (Häckselgut)
    for i, o in ipairs(list) do
        if o.name == "MAIZE" then
            local base = o.title
            o.title = base .. " (" .. T("use_grain") .. ")"
            o.silage = false
            table.insert(list, i + 1, { index = o.index, name = "MAIZE", title = base .. " (" .. T("use_silage") .. ")", silage = true })
            break
        end
    end
    table.insert(list, 1, { index = nil, title = T("no_selection") })
    local nm = {}
    for i, o in ipairs(list) do nm[i] = tostring(o.name) .. "/" .. tostring(o.title) end
    self.fruitOptions = list
    return list
end

-- Eintrag für den Kasten "Folgefrucht" (nil = keine Auswahl)
-- Kasten-Eintrag (Titel, Icon, Kategorie) aus einem Fruchtnamen
function FieldListHUD:getEntryByFruitName(name)
    if name == nil or name == "" then
        return nil
    end
    local ft = g_fruitTypeManager:getFruitTypeByName(name)
    if ft == nil then
        return nil
    end
    local ftl = ft.fillType
    local icon = ftl ~= nil and ftl.hudOverlayFilename or nil
    if (icon == nil or icon == "") and g_fillTypeManager ~= nil then
        local grass = g_fillTypeManager:getFillTypeByName("GRASS")
        icon = grass ~= nil and grass.hudOverlayFilename or nil
    end
    return {
        fruitTitle = (ftl ~= nil and ftl.title) or ft.name,
        iconFilename = icon,
        category = FieldListHUD.getCategory(ft.name),
    }
end

function FieldListHUD:getNextFruitEntry(entry)
    local rc = self:getRecord(entry.id)
    local e = self:getEntryByFruitName(rc.next)
    if e ~= nil and rc.silage and string.upper(rc.next or "") == "MAIZE" then
        local c = {}
        for k, v in pairs(e) do c[k] = v end
        c.fruitTitle = e.fruitTitle .. " (" .. T("use_silage") .. ")"
        return c
    end
    return e
end

-- Position der gewählten Folgefrucht in der Optionsliste (1 = keine Auswahl)
function FieldListHUD:getNextPos(id)
    local name = self:getRecord(id).next
    if name ~= nil then
        -- zuletzt per Pfeil gewählte Position bevorzugen (falls ein Name mehrfach in der Liste steht)
        local rcp = self:getRecord(id)
        local wantSil = rcp.silage == true
        local pp = self.pickPos ~= nil and self.pickPos[id] or nil
        local po = pp ~= nil and self:getFruitOptions()[pp] or nil
        if po ~= nil and po.name == name and (po.silage == true) == wantSil then
            return pp
        end
        for i, o in ipairs(self:getFruitOptions()) do
            if o.name == name and (o.silage == true) == wantSil then
                return i
            end
        end
        for i, o in ipairs(self:getFruitOptions()) do
            if o.name == name then
                return i
            end
        end
    end
    return 1
end

function FieldListHUD:cycleNextFruit(dir)
    local opts = self:getFruitOptions()
    if self.selectedId == nil or #opts == 0 then
        return
    end
    local cur = self:getNextPos(self.selectedId)
    local pos = cur + dir
    -- Ringliste: vor dem ersten Eintrag ("keine Auswahl") kommt der letzte, nach dem letzten wieder der erste
    if pos < 1 then
        pos = #opts
    elseif pos > #opts then
        pos = 1
    end
    local rc = self:getRecord(self.selectedId)
    rc.next = opts[pos].name
    rc.silage = (opts[pos].silage == true) or nil
    self.pickPos = self.pickPos or {}
    self.pickPos[self.selectedId] = pos
    rc.autoNext = false
    rc.autoOff = (opts[pos].name == nil) -- "keine Auswahl" schaltet die Automatik für dieses Feld ab
end

local function truthy(v)
    return v == true or (type(v) == "number" and v ~= 0)
end

-- Liest Saat- und Erntefenster (je Periode) aus growthDataSeasonal. Gibt nil zurück, wenn
-- die Struktur nicht erkannt wird; die genauen Daten stehen dann in der log.txt (seasonal ...).
function FieldListHUD:parseSeason(ft)
    self.seasonCache = self.seasonCache or {}
    local cached = self.seasonCache[ft.index]
    if cached ~= nil then
        return cached or nil
    end

    local function try(t)
        local plant, harvest, found, map = {}, {}, false, {}
        for p = 1, 12 do
            local sub = t[p]
            if type(sub) == "table" then
                for f, v in pairs(sub) do
                    local fl = string.lower(tostring(f))
                    if string.find(fl, "mapping") and type(v) == "table" then
                        -- Wachstum: Stufe -> Stufe beim Übergang in diese Periode
                        map[p] = {}
                        for st, nx in pairs(v) do
                            if type(st) == "number" and type(nx) == "number" then map[p][st] = nx end
                        end
                    elseif string.find(fl, "plant") or string.find(fl, "seed") or string.find(fl, "sow") then
                        found = true
                        if truthy(v) then plant[p] = true end
                    elseif string.find(fl, "harvest") then
                        found = true
                        if truthy(v) then harvest[p] = true end
                    end
                end
            end
        end
        if found then
            return { plant = plant, harvest = harvest, map = (next(map) ~= nil) and map or nil }
        end
        return nil
    end

    local result = nil
    local data = ft.growthDataSeasonal
    if type(data) == "table" then
        result = try(data)
        if result == nil then
            local keys = {}
            for k in pairs(data) do table.insert(keys, k) end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                if type(data[k]) == "table" then
                    result = try(data[k])
                    if result ~= nil then break end
                end
            end
        end
    end

    if result == nil then
        print(string.format("FieldListHUD: Saisondaten für '%s' nicht erkannt", tostring(ft.name)))
    end
    self.seasonCache[ft.index] = result or false
    return result
end

-- Auswahl der nächsten Frucht (Pfeile links/rechts); gibt die neue Oberkante zurück
function FieldListHUD:drawFruitSelector(x, top, w, entry)
    local rowH = 0.040
    local btnW = 0.030
    local y = top - rowH
    local opts = self:getFruitOptions()
    local pos  = self:getNextPos(entry.id)
    local opt  = opts[pos] or opts[1]
    local rec  = self:getRecord(entry.id)
    local bw = btnW / (g_screenAspectRatio or (16 / 9))

    -- Links: Folgefrucht, rechts: geplante Zwischenfrucht (je mit eigenen Pfeilen)
    local gap = 0.010
    local w1 = (w - gap) * 0.60
    local w2 = (w - gap) - w1
    local x2 = x + w1 + gap

    local function drawPicker(px, pw, title, size, prevKey, nextKey, tint, clearKey, showClear)
        self:drawFrame(px, y, pw, rowH, self.colorTile, self.colorBorder)
        local prev = { x = px + 0.006, y = y + 0.006, w = bw, h = rowH - 0.012 }
        local nxt  = { x = px + pw - 0.006 - bw, y = y + 0.006, w = bw, h = rowH - 0.012 }
        self:drawFrame(prev.x, prev.y, prev.w, prev.h, self.colorIcon, self.colorBorder)
        self:drawFrame(nxt.x, nxt.y, nxt.w, nxt.h, self.colorIcon, self.colorBorder)
        self.hitRects[prevKey] = prev
        self.hitRects[nextKey] = nxt
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(unpack(self.colorTitle))
        renderText(prev.x + prev.w / 2, prev.y + prev.h - 0.005, 0.016, "<")
        renderText(nxt.x + nxt.w / 2, nxt.y + nxt.h - 0.005, 0.016, ">")
        local extra = 0
        if clearKey ~= nil then
            self.hitRects[clearKey] = nil
            if showClear then
                local clr = { x = nxt.x - 0.006 - bw, y = nxt.y, w = bw, h = nxt.h }
                self:drawFrame(clr.x, clr.y, clr.w, clr.h, self.colorIcon, self.colorBorder)
                setTextColor(unpack(self.colorTitle))
                renderText(clr.x + clr.w / 2, clr.y + clr.h - 0.005, 0.016, "x")
                self.hitRects[clearKey] = clr
                extra = bw + 0.006
            end
        end
        local maxW = pw - 2 * (bw + 0.020) - 2 * extra
        local ts = size
        local tw = getTextWidth(ts, title)
        if tw > maxW then ts = ts * maxW / tw end
        setTextColor(unpack(tint or self.colorTitle))
        renderText(px + pw / 2, y + rowH / 2 + ts / 2, ts, title)
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_LEFT)
    end

    drawPicker(x, w1, opt.title .. ((rec.autoNext and rec.next ~= nil) and T("auto_suffix") or ""), 0.016, "prev", "next", nil, "clearNext", rec.next ~= nil)
    local ccTitle = T("cc_none")
    if rec.ccPlanned then
        local ft = g_fruitTypeManager:getFruitTypeByName("OILSEEDRADISH")
        ccTitle = (ft ~= nil and ft.fillType ~= nil and ft.fillType.title) or "OILSEEDRADISH"
    end
    drawPicker(x2, w2, ccTitle, 0.014, "ccPrev", "ccNext", rec.ccPlanned and self.colorNoFruit or self.colorSub)
    return y - 0.010
end

-- Jahreskalender mit Aussaat und Ernte; gibt die neue Oberkante zurück
-- Bewertungszeile rechts in einer Abschnittskopfzeile; gibt true zurück, wenn die Maus darauf steht
function FieldListHUD:drawRatingHeader(d, secTop, rating, sectionTitle, rightEdge)
    if rating == nil then return false end
    local lvl, lc = self:getLevelInfo(rating)
    local parts = {}
    -- Die Einzelwerte stehen im Mouseover-Fenster; hier nur bei gesperrten Früchten der Grund
    if rating.blocked then
        for _, r in ipairs(rating.reasons or {}) do
            table.insert(parts, T(r.key))
        end
    end
    local txt = string.format("%s: %s", T("rate_title"), lvl)
    if not rating.blocked then
        txt = txt .. string.format(" (%+d)", rating.points)
        if rating.factor ~= nil then
            txt = txt .. string.format("  ·  %s %d %%", T("p_factor"), rating.factor)
        end
    end
    local detail = #parts > 0 and ("  ·  " .. table.concat(parts, " · ")) or ""
    local size = 0.011 * 1.33
    -- linksbündig direkt hinter dem Abschnittstitel (beide Zeilen beginnen so an derselben Stelle)
    local tx = d.x + 0.018 + getTextWidth(0.014, sectionTitle) + 0.016
    local maxW = rightEdge - tx
    while size > 0.008 and getTextWidth(size, txt .. detail) > maxW do
        size = size - 0.0005
    end
    if getTextWidth(size, txt .. detail) > maxW then detail = "" end
    local tw = getTextWidth(size, txt .. detail)
    local hover = false
    local mx, my = self.mouseX, self.mouseY
    if mx ~= nil and my ~= nil and mx >= tx - 0.008 and mx <= tx + tw + 0.004
        and my <= secTop and my >= secTop - 0.024 then
        hover = true
    end
    self:drawRect(tx - 0.008, secTop - 0.021, tw + 0.010, 0.021, self.colorBgPage or { 0.019, 0.019, 0.019, 1 })
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(lc or self.colorSub))
    renderText(tx, secTop - 0.002, size, txt)
    setTextBold(false)
    setTextColor(unpack(self.colorSub))
    renderText(tx + getTextWidth(size, txt), secTop - 0.002, size, detail)
    return hover
end

-- Bewertung der aktuellen Frucht gegen ihre Vorfrucht (nur Information, ändert keine Mengen)
function FieldListHUD:getCurrentRating(entry)
    local rec = self.store ~= nil and self.store[entry.id] or nil
    if rec == nil or rec.cur == nil or entry.unused or rec.hist == nil or rec.hist[1] == nil then return nil end
    self.curRatingCache = self.curRatingCache or {}
    local key = tostring(entry.id) .. "|" .. tostring(rec.cur) .. "|" .. tostring(rec.hist[1])
    local nowT = g_time or 0
    local c = self.curRatingCache[key]
    if c == nil or (nowT - c.t) > 1000 then
        local virt = { cur = rec.hist[1], hist = {}, cc = {}, ccPending = rec.cc ~= nil and rec.cc[1] == true, ccPlanned = false }
        for i = 2, #rec.hist do table.insert(virt.hist, rec.hist[i]) end
        for i = 2, #(rec.cc or {}) do table.insert(virt.cc, rec.cc[i]) end
        local ok, r = pcall(function() return self:rateCandidate(virt, rec.cur) end)
        c = { t = nowT, v = (ok and r ~= nil and not r.blocked) and r or nil }
        self.curRatingCache[key] = c
    end
    return c.v
end

-- Aufschlüsselung der Fruchtfolge-Bewertung; ersetzt den Kalender der Folgefrucht, solange die Maus auf der Bewertungszeile steht
function FieldListHUD:drawRatingPanel(x, top, w, rating, fruitTitle)
    local rowH, headH = 0.017, 0.014
    local total = headH + 2 * rowH + headH
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorSub))
    renderText(x, top, 0.011, T("rate_title") .. (fruitTitle ~= nil and ("  ·  " .. fruitTitle) or ""))
    setTextBold(false)
    top = top - 0.016
    local y = top - total
    self:drawFrame(x, y, w, total, self.colorTile, self.colorBorder)
    local RED = { 1, 0.4, 0.4, 1 }
    local function valCol(v) return v > 0 and self.colorArea or (v < 0 and RED or self.colorSub) end
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    if rating.blocked then
        local parts = {}
        for _, r in ipairs(rating.reasons or {}) do table.insert(parts, T(r.key)) end
        setTextColor(unpack(self.colorWork))
        renderText(x + 0.012, y + total / 2, 0.0125, table.concat(parts, " · "))
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        return y - 0.008
    end
    -- Eine Tabelle, immer mit allen Kriterien: Zeile 1 = Kriterium, Zeile 2 = Punkte (Stufe), Zeile 3 = Ertrag (%)
    local pts, pct = {}, {}
    for _, r in ipairs(rating.reasons or {}) do pts[r.key] = (pts[r.key] or 0) + r.v end
    for _, r in ipairs(rating.pct or {}) do pct[r.key] = (pct[r.key] or 0) + r.v end
    local SHORT = {
        p_n2 = T("short_p_n2"), r_change = T("short_r_change"),
        r_cc = T("short_r_cc"), r_late = T("short_r_late"),
        r_legume = T("short_r_legume"), p_mono = T("short_p_mono"),
    }
    local PTS = { r_matrix = true, r_pause = true, r_change = true, r_legume = true, r_cc = true, r_late = true, r_self = true }
    local PCT = { r_matrix = true, p_n1 = true, p_n2 = true, r_pause = true, r_change = true, r_cc = true, p_mono = true, p_fallow = true }
    local keys = { "r_matrix", "p_n1", "p_n2", "r_pause", "r_change", "r_legume", "r_cc", "r_late", "p_mono", "p_fallow" }
    if pts.r_self ~= nil then table.insert(keys, 1, "r_self") end
    local lvl = self:getLevelInfo(rating)
    local labW = 0.052
    local ncol = #keys + 1
    local colW = (w - 0.024 - labW) / ncol
    local function fit(text, size, maxW)
        local tw = getTextWidth(size, text)
        if tw > maxW then size = size * maxW / tw end
        return size
    end
    local pitch = (total - 0.012) / 3
    local y1 = y + total - 0.006
    local y2, y3 = y1 - pitch, y1 - 2 * pitch
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    -- Zeilenbeschriftung
    setTextBold(true)
    setTextColor(unpack(self.colorSub))
    renderText(x + 0.012, y2, fit(T("rate_points"), 0.0105, labW - 0.004), T("rate_points"))
    renderText(x + 0.012, y3, fit(T("rate_yield"), 0.0105, labW - 0.004), T("rate_yield"))
    local function cell(cx, cy, text, col, size, bold)
        setTextBold(bold == true)
        setTextColor(unpack(col))
        renderText(cx, cy, fit(text, size, colW - 0.004), text)
    end
    for i, k in ipairs(keys) do
        local cx = x + 0.012 + labW + (i - 1) * colW
        cell(cx, y1, SHORT[k] or T(k), self.colorSub, 0.0105, true)
        local pv, qv = pts[k], pct[k]
        if PTS[k] then
            local v = pv or 0
            cell(cx, y2, v == 0 and "0" or string.format("%+d", v), valCol(v), 0.0125, false)
        else
            cell(cx, y2, "-", self.colorSub, 0.0125, false)
        end
        if PCT[k] then
            local v = qv or 0
            cell(cx, y3, v == 0 and "0 %" or string.format("%+d %%", v), valCol(v), 0.0125, false)
        else
            cell(cx, y3, "-", self.colorSub, 0.0125, false)
        end
    end
    local sx = x + 0.012 + labW + #keys * colW
    cell(sx, y1, T("rate_sum"), self.colorSub, 0.0105, true)
    cell(sx, y2, string.format("%+d %s", rating.points, tostring(lvl)), self.colorTitle, 0.0125, true)
    cell(sx, y3, rating.factor ~= nil and string.format("%d %%", rating.factor) or "-", self.colorTitle, 0.0125, true)
    setTextBold(false)
    return y - 0.008
end

function FieldListHUD:drawCalendar(x, top, w, ftIndex, emptyText)
    local ft = ftIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(ftIndex) or nil

    local iconH  = 0.034
    local iconW  = iconH / (g_screenAspectRatio or (16 / 9))
    local labelW = 0.012 + iconW + 0.060
    local rowH   = 0.017
    local headH  = 0.014
    local padB   = headH -- gleicher Abstand unten, damit die Zeilen mittig im Rahmen liegen
    local total  = headH + 2 * rowH + padB
    local y      = top - total

    local title = T("cal_title")
    if ft ~= nil then
        title = title .. "  ·  " .. ((ft.fillType ~= nil and ft.fillType.title) or ft.name)
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorSub))
    renderText(x, top, 0.011, title)
    setTextBold(false)
    top = top - 0.016
    y = top - total

    self:drawFrame(x, y, w, total, self.colorTile, self.colorBorder)

    local season = ft ~= nil and self:parseSeason(ft) or nil
    if season == nil then
        setTextColor(unpack(self.colorSub))
        renderText(x + 0.012, y + total - 0.020, 0.013,
            ft == nil and (emptyText or T("cal_choose")) or T("cal_unreadable"))
        return y - 0.008
    end

    local cellW = (w - labelW - 0.008) / 12
    local gx = x + labelW
    local plantC, harvestC = self.colorArea, { 0.85, 0.35, 0.10, 1 }

    -- Perioden (1 = März) in Kalendermonate umrechnen
    local plantM, harvestM = {}, {}
    for p = 1, 12 do
        local m = (p + 1) % 12 + 1
        if season.plant[p] then plantM[m] = true end
        if season.harvest[p] then harvestM[m] = true end
    end

    -- aktueller Monat: Spalte hinterlegen und Monatsname hervorheben
    local curM = nil
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    if env ~= nil and env.currentPeriod ~= nil then
        curM = (env.currentPeriod + 1) % 12 + 1
        -- gestrichelte Linie am heutigen Tag (wie im Spielkalender)
        local dpp = env.daysPerPeriod or 1
        local day = env.currentDay or 1
        local frac = (((day - 1) % dpp) + ((env.dayTime or 0) / 86400000)) / dpp
        frac = math.max(0, math.min(1, frac))
        local sw = g_screenWidth or 1920
        local lx0 = math.floor((gx + (curM - 1 + frac) * cellW) * sw + 0.5) / sw
        local dy = y + 0.002
        while dy < y + total - 0.004 do
            self:drawRect(lx0, dy, 1.5 / sw, 0.004, { 1, 1, 1, 0.9 })
            dy = dy + 0.007
        end
    end

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    for m = 1, 12 do
        setTextColor(unpack(self.colorSub))
        renderText(gx + (m - 0.5) * cellW, y + total - 0.003, 0.010, self.MONTHS[m])
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(self.colorTitle))
    local lx = x + 0.012 + iconW + 0.008
    renderText(lx, y + padB + 1.5 * rowH + 0.007, 0.012, T("cal_sowing"))
    renderText(lx, y + padB + 0.5 * rowH + 0.007, 0.012, T("cal_harvest"))

    -- Frucht-Icon links
    local fe = self:getEntryByFruitName(ft.name)
    local ix, iy = x + 0.008, y + padB + (2 * rowH - iconH) / 2
    self:drawRect(ix, iy, iconW, iconH, self.colorIcon)
    local icon = fe ~= nil and self:getIcon(fe.iconFilename) or nil
    if icon ~= nil then
        icon:setPosition(ix, iy)
        icon:setDimension(iconW, iconH)
        icon:render()
    end
    setTextBold(false)

    for m = 1, 12 do
        local cx = gx + (m - 1) * cellW
        -- Trennlinie pixelgenau (sonst verschwindet sie bei manchen Positionen)
        local sw = g_screenWidth or 1920
        local lineX = math.floor(cx * sw + 0.5) / sw
        self:drawRect(lineX, y + padB, 1 / sw, 2 * rowH, self.colorTrack)
        if plantM[m] then
            self:drawRect(cx + 0.001, y + padB + rowH + 0.004, cellW - 0.002, rowH - 0.008, plantC)
        end
        if harvestM[m] then
            self:drawRect(cx + 0.001, y + padB + 0.004, cellW - 0.002, rowH - 0.008, harvestC)
        end
    end
    return y - 0.008
end

-- Zeile mit Beschriftung links und Fortschrittsbalken (Wert/Max) rechts
function FieldListHUD:drawBarRow(x, y, w, h, label, value, max, text)
    local pad = 0.012
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x + pad, y + h - 0.012, 0.014, label)
    setTextBold(false)

    local barX = x + pad + 0.14
    local barW = w - (barX - x) - pad - 0.04
    setTextColor(unpack(self.colorSub))
    renderText(barX, y + h - 0.004, 0.010, text)
    self:drawRect(barX, y + 0.008, barW, 0.010, self.colorTrack)
    local frac = (value ~= nil and max > 0) and math.max(0, math.min(1, value / max)) or 0
    if frac > 0 then
        self:drawRect(barX, y + 0.008, barW * frac, 0.010, self.colorArea)
    end
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextBold(true)
    setTextColor(unpack(self.colorArea))
    renderText(x + w - pad, y + h - 0.004, 0.011, string.format("%d / %d", value or 0, max))
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function FieldListHUD:drawDetail(d, entry)
    local pad = 0.012
    local top = d.y + d.h

    -- Seitentitel
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(d.x, top, 0.036, T("title_overview"))
    setTextBold(false)
    top = top - 0.060

    if entry == nil then
        setTextColor(unpack(self.colorSub))
        renderText(d.x, top, 0.014, T("no_field_selected"))
        return
    end

    -- Kopfzeile
    local barH = 0.040
    self:drawRect(d.x, top - barH, d.w, barH, self.colorTile)
    self:drawRect(d.x, top - 0.0015, d.w, 0.0015, self.colorArea)
    self:drawRect(d.x, top - barH, d.w, 0.0015, self.colorArea)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    local headText = string.format(T("head_field"), entry.id, entry.area)
    renderText(d.x + pad, top - 0.008, 0.017, headText)
    setTextBold(false)

    -- Ertrag hinter der Flächenangabe
    do
        local yx = d.x + pad + getTextWidth(0.017, headText) + 0.030
        local pct = self:getYieldPercent(entry)
        setTextColor(unpack(self.colorSub))
        renderText(yx, top - 0.0105, 0.013, T("col_yield"))
        local lx = yx + getTextWidth(0.013, T("col_yield")) + 0.008
        setTextBold(true)
        setTextColor(unpack(self:getYieldColor(pct)))
        renderText(lx, top - 0.008, 0.017, pct ~= nil and string.format("%.1f %%", 100 + pct) or "-")
        setTextBold(false)
    end

    -- Checkbox "Ungenutzt" rechts in der Kopfleiste
    do
        local boxS = 0.016
        local boxW = boxS / (g_screenAspectRatio or (16 / 9))
        local label = T("unused")
        local size = 0.013
        local tw = getTextWidth(size, label)
        local bx = d.x + d.w - pad - tw - 0.008 - boxW
        local by = top - barH / 2 - boxS / 2
        self:drawFrame(bx, by, boxW, boxS, self.colorIcon, self.colorBorder)
        if entry.unused then
            local m = 0.004
            self:drawRect(bx + boxW * 0.2, by + boxS * 0.2, boxW * 0.6, boxS * 0.6, self.colorArea)
        end
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextColor(unpack(self.colorTitle))
        renderText(bx + boxW + 0.008, top - barH / 2, size, label)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        self.hitRects.unused = { x = bx - 0.004, y = top - barH, w = d.x + d.w - (bx - 0.004), h = barH }
    end
    top = top - barH - 0.018

    -- Anbaugeschichte
    local secTop = top
    top = self:drawSection(d.x, top, d.w, T("sec_history"))
    do
        -- Schaltfläche "X": Fruchtfolge um einen Schritt weiterschieben
        local bh = 0.022
        local bw = bh / (g_screenAspectRatio or (16 / 9))
        local bx = d.x + d.w - bw
        local by = secTop - bh + 0.002
        local capSize = 0.011
        local capW = getTextWidth(capSize, T("advance"))
        self:drawRect(bx - 0.016 - capW, by, capW + 0.016, bh, self.colorBgPage or { 0.019, 0.019, 0.019, 1 })
        local cap = T("advance")
        local canAdvance = self:getRecord(entry.id).next ~= nil
        self:drawFrame(bx, by, bw, bh, self.colorTile, canAdvance and self.colorArea or self.colorBorder)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(unpack(canAdvance and self.colorTitle or self.colorSub))
        do
            local n = 8
            local th = bh * 0.5
            local tw = th * 0.8 / (g_screenAspectRatio or (16 / 9))
            local cw = tw / n
            local tx = bx + (bw - tw) / 2
            local col = canAdvance and self.colorTitle or self.colorSub
            for k = 0, n - 1 do
                local ch = th * (1 - (k + 0.5) / n)
                self:drawRect(tx + k * cw, by + (bh - ch) / 2, cw + 0.0003, ch, col)
            end
        end
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextColor(unpack(self.colorSub))
        renderText(bx - 0.008, by + bh / 2, capSize, cap)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        self.hitRects.advance = { x = bx, y = by, w = bw, h = bh }
        -- Rückgängig: Dreieck nach links links neben der Beschriftung, nur wenn etwas rückgängig gemacht werden kann
        self.hitRects.undo = nil
        if self:getRecord(entry.id).undo ~= nil then
            local ux = bx - 0.008 - capW - 0.012 - bw
            self:drawRect(ux - 0.004, by, bw + 0.008, bh, self.colorBgPage or { 0.019, 0.019, 0.019, 1 })
            self:drawFrame(ux, by, bw, bh, self.colorTile, self.colorArea)
            local n = 8
            local th = bh * 0.5
            local tw = th * 0.8 / (g_screenAspectRatio or (16 / 9))
            local cw = tw / n
            local tx = ux + (bw - tw) / 2
            for k = 0, n - 1 do
                local ch = th * (1 - (k + 0.5) / n)
                self:drawRect(tx + tw - (k + 1) * cw, by + (bh - ch) / 2, cw + 0.0003, ch, self.colorTitle)
            end
            self.hitRects.undo = { x = ux, y = by, w = bw, h = bh }
        end
    end
    top = top - 0.022 -- Platz für die Beschriftung über den Kästen
    local boxH   = 0.105
    local gapBox = 0.008
    local labels = { T("box_next"), T("box_current"), T("box_prev1"), T("box_prev2"), T("box_prev3"),
        T("box_prev4"), T("box_prev5"), T("box_prev6") }
    local boxes  = #labels
    local boxW   = (d.w - (boxes - 1) * gapBox) / boxes
    local hl = self:getDisplayHist(entry)
    do
        local rc0 = self:getRecord(entry.id)
        if rc0.next ~= nil then
            self.ratingCache = self.ratingCache or {}
            local key = tostring(entry.id) .. "|" .. tostring(rc0.next)
            local rc = self.ratingCache[key]
            local nowT = g_time or 0
            if rc == nil or (nowT - rc.t) > 1000 then
                rc = { t = nowT, v = self:rateCandidate(rc0, rc0.next) }
                self.ratingCache[key] = rc
            end
            self.ratingNow = rc.v
        else
            self.ratingNow = nil
        end
    end
    for i = 1, boxes do
        local bx = d.x + (i - 1) * (boxW + gapBox)
        local e = nil
        if i == 1 then
            e = self:getNextFruitEntry(entry)
        elseif i == 2 then
            e = self:getMainEntry(entry)
        else
            e = self:getEntryByFruitName(hl[i - 2])
        end
        local ratingBorder = nil
        if i == 1 and self.ratingNow ~= nil then
            local _, lc = self:getLevelInfo(self.ratingNow)
            ratingBorder = lc
        end
        self:drawHistoryBox(bx, top - boxH, boxW, boxH, labels[i], e, i == 2, ratingBorder)
        if i == 1 then
            -- Zwischenfrucht unter der Folgefrucht-Kachel: hellblau = geplant, grün = steht auf dem Feld
            local rc = self:getRecord(entry.id)
            -- Wächst der Ölrettich gerade, steht er unter "Aktuell" - die Zeile hier entfällt (nur "geplant" bleibt)
            if rc.ccPlanned and not rc.ccPending then
                local ft = g_fruitTypeManager:getFruitTypeByName("OILSEEDRADISH")
                local nm = (ft ~= nil and ft.fillType ~= nil and ft.fillType.title) or "OILSEEDRADISH"
                setTextAlignment(RenderText.ALIGN_CENTER)
                setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
                setTextBold(true)
                local txt = "+ " .. nm
                local ts = 0.011
                local tw = getTextWidth(ts, txt)
                if tw > boxW then ts = ts * boxW / tw end
                setTextColor(unpack(rc.ccPending and self.colorArea or self.colorNoFruit))
                renderText(bx + boxW / 2, top - boxH - 0.005, ts, txt)
                setTextBold(false)
            end
        end
    end
    -- Zwischenfrucht-Marker auf der Grenze zwischen zwei Kacheln
    do
        local rec = self:getRecord(entry.id)
        local ms = 0.022
        local mw = ms / (g_screenAspectRatio or (16 / 9))
        for i = 1, boxes - 1 do
            local has
            local planned = false
            if i == 1 then
                has = rec.ccPending == true
                planned = (not has) and rec.ccPlanned == true
                has = has or planned
            else
                has = rec.cc ~= nil and rec.cc[i - 1] == true
            end
            if has then
                local mx = d.x + i * boxW + (i - 0.5) * gapBox - mw / 2
                local my = top - boxH / 2 - ms / 2
                self:drawFrame(mx, my, mw, ms, planned and self.colorNoFruit or self.colorArea, self.colorBorder)
                setTextAlignment(RenderText.ALIGN_CENTER)
                setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
                setTextBold(true)
                setTextColor(0.02, 0.02, 0.02, 1)
                renderText(mx + mw / 2, my + ms / 2, 0.013, "Z")
                setTextBold(false)
            end
        end
        setTextAlignment(RenderText.ALIGN_LEFT)
    end
    top = top - boxH - 0.018

    -- Nächste Frucht + Jahreskalender
    local secCurTop = top
    top = self:drawSection(d.x, top, d.w, T("sec_current"))
    self:drawPlanButton(d.x + d.w - 0.17, secCurTop - 0.024, 0.17, 0.022, "left", "plan_one_btn")
    local _, ovIndex = self:getCurrentOverride(entry)
    local curRating = self:getCurrentRating(entry)
    -- Mais auf dem Feld: Körner oder Silage (Häckselgut) umschalten
    self.hitRects.curSilage = nil
    local recCS = self:getRecord(entry.id)
    local curNameCS = string.upper(entry.fruitName or ((recCS.manual and recCS.cur) or "") or "")
    local curRight = d.x + d.w - 0.17 - 0.012
    if curNameCS == "MAIZE" then
        local bw0, bh0 = 0.115, 0.022
        local bx0, by0 = d.x + d.w - 0.17 - 0.008 - bw0, secCurTop - 0.024
        self:drawFrame(bx0, by0, bw0, bh0, self.colorTile, recCS.curSilage and self.colorArea or self.colorBorder)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(unpack(recCS.curSilage and self.colorArea or self.colorTitle))
        renderText(bx0 + bw0 / 2, by0 + bh0 / 2, 0.011, recCS.curSilage and T("cur_use_silage") or T("cur_use_grain"))
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_LEFT)
        self.hitRects.curSilage = { x = bx0, y = by0, w = bw0, h = bh0 }
        curRight = bx0 - 0.012
    end
    local hoverCur = self:drawRatingHeader(d, secCurTop, curRating, T("sec_current"), curRight)
    if hoverCur and curRating ~= nil then
        top = self:drawRatingPanel(d.x, top, d.w, curRating, entry.fruitTitle)
    else
        top = self:drawCalendar(d.x, top, d.w, ovIndex or entry.fruitIndex, T("no_crop_on_field"))
    end
    local secNextTop = top
    top = self:drawSection(d.x, top, d.w, T("sec_next"))
    -- Button: automatisch geplante Folgefrucht dieses Feldes fest übernehmen
    local recAcc = self:getRecord(entry.id)
    local nextRight = d.x + d.w
    self.hitRects.acceptOne = nil
    if recAcc.autoNext and recAcc.next ~= nil then
        local bx, by, bw, bh = d.x + d.w - 0.17, secNextTop - 0.024, 0.17, 0.022
        self:drawFrame(bx, by, bw, bh, self.colorTile, self.colorArea)
        local lbl = T("accept_one_btn")
        local lsz = 0.011
        local lw = getTextWidth(lsz, lbl)
        if lw > bw * 0.92 then lsz = lsz * bw * 0.92 / lw end
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(unpack(self.colorTitle))
        renderText(bx + bw / 2, by + bh / 2, lsz, lbl)
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_LEFT)
        self.hitRects.acceptOne = { x = bx, y = by, w = bw, h = bh }
        nextRight = bx - 0.012
    end
    local hoverRating = self:drawRatingHeader(d, secNextTop, self.ratingNow, T("sec_next"), nextRight)
    local nopt = self:getFruitOptions()[self:getNextPos(entry.id)]
    if hoverRating and self.ratingNow ~= nil then
        top = self:drawRatingPanel(d.x, top, d.w, self.ratingNow, nopt ~= nil and nopt.title or nil)
    else
        top = self:drawCalendar(d.x, top, d.w, nopt ~= nil and nopt.index or nil)
    end
    top = self:drawFruitSelector(d.x, top, d.w, entry)
    top = top - 0.010

    -- Aktueller Feldzustand
    top = self:drawSection(d.x, top, d.w, T("sec_state"))
    local rowH = 0.075
    self:drawFrame(d.x, top - rowH, d.w, rowH, self.colorTile, self.colorBorder)

    local growth = "-"
    -- Abgeerntet (Stufe über der Reife): kein Wachstum anzeigen
    local harvestedNow = entry.fruitTitle ~= nil and entry.growthState ~= nil and entry.maxGrowth ~= nil
        and entry.growthState > entry.maxGrowth and not entry.harvestReady
    if entry.growthState ~= nil and not harvestedNow then
        if entry.maxGrowth ~= nil then
            growth = string.format("%d / %d", entry.growthState, entry.maxGrowth)
        else
            growth = string.format(T("level"), entry.growthState)
        end
    end
    local cols = {
        { T("col_crop"),    entry.fruitTitle or T("no_crop") },
        { T("col_category"), entry.category or "-" },
        { T("col_status"),    self:getStatusText(entry) },
        { T("col_weeds"),   (entry.weed ~= nil and entry.weed > 0) and T("weed_" .. FieldListHUD.weedSize(entry.weed)) or T("none") },
        { T("col_growth"),  growth .. (entry.harvestReady and T("ready_suffix") or "") },
    }
    local cw = d.w / #cols
    for i, c in ipairs(cols) do
        local cx = d.x + (i - 0.5) * cw
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(unpack(self.colorTitle))
        renderText(cx, top - 0.012, 0.011, c[1])
        setTextBold(false)
        setTextColor(unpack(self.colorSub))
        local vs = 0.014
        if i == 4 and entry.weed ~= nil and entry.weed > 0 then
            vs = 0.0125
            local ws = FieldListHUD.weedSize(entry.weed)
            if ws >= 3 then setTextColor(unpack(self.colorWork)) end
            local tl = T("weed_tools_" .. ws)
            local tsz = 0.0095
            local tw = getTextWidth(tsz, tl)
            if tw > cw - 0.012 then tsz = tsz * (cw - 0.012) / tw end
            renderText(cx, top - 0.0535, tsz, tl)
            setTextColor(unpack(self.colorSub))
        end
        if i == 4 and entry.weed ~= nil and entry.weed > 0 and FieldListHUD.weedSize(entry.weed) >= 3 then setTextColor(unpack(self.colorWork)) end
        do
            local vw = getTextWidth(vs, c[2])
            if vw > cw - 0.012 then vs = vs * (cw - 0.012) / vw end
        end
        renderText(cx, top - ((i == 4 and entry.weed ~= nil and entry.weed > 0) and 0.036 or 0.042), vs, c[2])
        if i < #cols then
            self:drawRect(d.x + i * cw, top - rowH + 0.012, 0.0008, rowH - 0.024, self.colorTrack)
        end
    end
    top = top - rowH - 0.020

    -- Platzhalter für spätere Abschnitte
    top = self:drawSection(d.x, top, d.w, T("sec_soil"))
    local fm = g_fieldManager
    local sprayMax = (fm ~= nil and fm.sprayLevelMaxValue) or 2
    local limeMax  = (fm ~= nil and fm.limeLevelMaxValue) or 3
    local function levelText(v, max, none, part, full)
        if v == nil then return "-" end
        if v <= 0 then return none end
        if v >= max then return full end
        return part
    end
    local boxTop = top
    local rowH2 = 0.040
    self:drawFrame(d.x, boxTop - 3 * rowH2, d.w, 3 * rowH2, self.colorTile, self.colorBorder)
    self:drawBarRow(d.x, boxTop - rowH2, d.w, rowH2, T("nitrogen"), entry.spray, sprayMax,
        levelText(entry.spray, sprayMax, T("n_none"), T("n_part"), T("n_full")))
    self:drawBarRow(d.x, boxTop - 2 * rowH2, d.w, rowH2, T("lime_ph"), entry.lime, limeMax,
        levelText(entry.lime, limeMax, T("lime_none"), T("lime_part"), T("lime_full")))

    local work = {}
    for _, item in ipairs(self:getWorkItems(entry)) do
        table.insert(work, item.text)
    end
    local ground = self:getGroundText(entry)
    -- Ein abgeerntetes Feld ist nicht erntereif, auch wenn der Bodentyp des Spiels noch so heißt
    if ground == T("ground_ready") and not entry.harvestReady then ground = nil end
    if ground ~= nil and ground ~= T("ground_fallow") then table.insert(work, ground) end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(d.x + pad, boxTop - 2 * rowH2 - 0.012, 0.014, T("ground_state"))
    setTextBold(false)
    setTextColor(unpack(self.colorSub))
    local workTxt = #work > 0 and table.concat(work, " · ") or T("nothing_special")
    local wSize = 0.013 * 1.33
    local wMax = d.w - pad - 0.14 - 0.012
    while wSize > 0.010 and getTextWidth(wSize, workTxt) > wMax do
        wSize = wSize - 0.0004
    end
    renderText(d.x + pad + 0.14, boxTop - 2 * rowH2 - 0.012, wSize, workTxt)
end


------------------------------------------------------------------------
-- Seite 2: Tabelle aller Felder
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Optionen (Seite 5)
-- Pro Spieler (Benutzerordner): Boni für geplante Felder, HUD-Fenster
-- Für das ganze Spiel (Savegame, nur Host): Fruchtfolge-Ernte
------------------------------------------------------------------------
FieldListHUD.settings = { hud = false, hx = 0.012, hy = 0.50, hw = 0.19, hh = 0.22, sortPrio = false }

function FieldListHUD:getPlayerSettingsPath()
    local base = getUserProfileAppPath() .. "modSettings/"
    return base, base .. "FS25_FieldManager/", base .. "FS25_FieldManager/settings.xml"
end

function FieldListHUD:loadPlayerSettings()
    pcall(function()
        local _, _, file = self:getPlayerSettingsPath()
        if fileExists(file) then
            local h = loadXMLFile("fieldManagerSettings", file)
            local pb = getXMLInt(h, "fieldManagerSettings.planBonus#value")
            if pb ~= nil then FieldListHUD.PLAN_BONUS = math.max(0, math.min(200, pb)) end
            local hud = getXMLBool(h, "fieldManagerSettings.hud#value")
            if hud ~= nil then self.settings.hud = hud end
            local sp = getXMLBool(h, "fieldManagerSettings.hudSortPrio#value")
            if sp ~= nil then self.settings.sortPrio = sp end
            for _, k in ipairs({ "hx", "hy", "hw", "hh" }) do
                local v = getXMLFloat(h, "fieldManagerSettings.hudWindow#" .. k)
                if v ~= nil then self.settings[k] = v end
            end
            delete(h)
        end
    end)
end

function FieldListHUD:savePlayerSettings()
    pcall(function()
        local base, dir, file = self:getPlayerSettingsPath()
        createFolder(base)
        createFolder(dir)
        local h = createXMLFile("fieldManagerSettings", file, "fieldManagerSettings")
        setXMLInt(h, "fieldManagerSettings.planBonus#value", FieldListHUD.PLAN_BONUS)
        setXMLBool(h, "fieldManagerSettings.hud#value", self.settings.hud == true)
        setXMLBool(h, "fieldManagerSettings.hudSortPrio#value", self.settings.sortPrio == true)
        for _, k in ipairs({ "hx", "hy", "hw", "hh" }) do
            setXMLFloat(h, "fieldManagerSettings.hudWindow#" .. k, self.settings[k])
        end
        saveXMLFile(h)
        delete(h)
    end)
end

function FieldListHUD:setRotYield(v)
    FieldListHUD.rotYield = v == true
    self:markDirtyCaches()
    -- Server: neuen Wert an alle Clients (Pseudo-Datensatz mit der Nummer 0)
    if self:isMP() and self:isAuthority() and self.sendRecords ~= nil then
        self:sendRecords("all", { { id = 0, s = FieldListHUD.globalSettingsString() } })
    end
end

function FieldListHUD:setSeasonal(v)
    FieldListHUD.seasonal = v == true
    if self:isMP() and self:isAuthority() and self.sendRecords ~= nil then
        self:sendRecords("all", { { id = 0, s = FieldListHUD.globalSettingsString() } })
    end
end

function FieldListHUD:setPlanBonus(v)
    v = math.max(0, math.min(200, v))
    FieldListHUD.PLAN_BONUS = v
    self.p3Dirty, self.wkDirty = true, true
    self:markDirtyCaches()
    self:savePlayerSettings()
end

function FieldListHUD:setHudSort(v)
    self.settings.sortPrio = v == true
    self.wkDirty = true
    self.hudRows = nil
    self:savePlayerSettings()
end

function FieldListHUD:setHud(v)
    self.settings.hud = v == true
    if not self.settings.hud then self:setHudCursor(false) end
    self:savePlayerSettings()
end

-- Seite 5: Optionen
function FieldListHUD:drawOptionsPage(L)
    local x0, w0 = L.ax, L.aw - 0.015
    local top = L.ay + L.ah
    self.optBtns = {}
    self.planBtn = nil
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x0, top, 0.036, T("opt_title"))
    setTextBold(false)
    top = top - 0.070

    local rowH = 0.052
    local gap = 0.008
    local sw = 1 / (g_screenAspectRatio or (16 / 9))
    local function rowBase(y, label, hint, dim)
        self:drawFrame(x0, y - rowH, w0, rowH, self.colorTile, self.colorBorder)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        setTextBold(true)
        setTextColor(unpack(dim and self.colorSub or self.colorTitle))
        renderText(x0 + 0.012, y - 0.007, 0.0145, label)
        setTextBold(false)
        setTextColor(unpack(self.colorSub))
        local size = 0.0100
        local maxW = w0 * 0.62
        -- höchstens zwei Zeilen, Umbruch an Wortgrenzen
        local l1, l2 = hint, nil
        if getTextWidth(size, hint) > maxW then
            local cut = nil
            for pos in hint:gmatch("()%s") do
                if getTextWidth(size, hint:sub(1, pos - 1)) <= maxW then cut = pos else break end
            end
            if cut ~= nil then
                l1, l2 = hint:sub(1, cut - 1), hint:sub(cut + 1)
            end
        end
        local function fit(str)
            local tw = getTextWidth(size, str)
            local sz = size
            if tw > maxW then sz = size * maxW / tw end
            return sz
        end
        renderText(x0 + 0.012, y - 0.0245, fit(l1), l1)
        if l2 ~= nil then renderText(x0 + 0.012, y - 0.0365, fit(l2), l2) end
    end
    local function toggle(y, value, enabled, fn)
        -- Zweigeteilter Schalter: AUS | AN, die aktive Hälfte ist grün
        local hw, bh = 0.048, 0.028
        local bx = x0 + w0 - 0.015 - hw * 2
        local by = y - rowH / 2 - bh / 2
        local function half(hx, label, active)
            self:drawFrame(hx, by, hw, bh, active and self.colorArea or self.colorIcon, self.colorBorder)
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextBold(active)
            setTextColor(unpack(active and { 0.02, 0.02, 0.02, 1 } or (enabled and self.colorTitle or self.colorSub)))
            renderText(hx + hw / 2, by + bh / 2, 0.0125, label)
            setTextBold(false)
        end
        half(bx, T("opt_off"), not value)
        half(bx + hw, T("opt_on"), value)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        if enabled then
            table.insert(self.optBtns, { x = bx, y = by, w = hw, h = bh, fn = function() fn(false) end })
            table.insert(self.optBtns, { x = bx + hw, y = by, w = hw, h = bh, fn = function() fn(true) end })
        end
    end

    -- Bereich Fruchtfolge
    top = self:drawSection(x0, top, w0, T("opt_sec_rot"))
    local canRot = self:isAuthority()
    rowBase(top, T("opt_rot"), T("opt_rot_hint") .. (canRot and "" or ("  " .. T("opt_host_only"))), not canRot)
    toggle(top, FieldListHUD.rotYield == true, canRot, function(v) self:setRotYield(v) end)
    top = top - rowH - gap

    rowBase(top, T("opt_bonus"), string.format(T("opt_bonus_hint"), 100 + FieldListHUD.PLAN_BONUS), false)
    do
        local bh = 0.028
        local bw = bh * sw
        local by = top - rowH / 2 - bh / 2
        local defW = getTextWidth(0.012, T("opt_default")) + 0.020
        local defX = x0 + w0 - 0.015 - defW
        local plusX = defX - 0.012 - bw
        local valW = 0.060
        local valX = plusX - valW
        local minusX = valX - bw
        local function stepBtn(bx, label, fn)
            self:drawFrame(bx, by, bw, bh, self.colorTile, self.colorArea)
            -- Symbol aus Rechtecken zeichnen (exakt mittig, unabhängig von der Schrift)
            local len = bh * 0.50
            local lenX = len / (g_screenAspectRatio or (16 / 9))
            local th = bh * 0.09
            local thX = th / (g_screenAspectRatio or (16 / 9))
            local cx, cy = bx + bw / 2, by + bh / 2
            self:drawRect(cx - lenX / 2, cy - th / 2, lenX, th, self.colorTitle)
            if label == "+" then
                self:drawRect(cx - thX / 2, cy - len / 2, thX, len, self.colorTitle)
            end
            table.insert(self.optBtns, { x = bx, y = by, w = bw, h = bh, fn = fn })
        end
        stepBtn(minusX, "-", function() self:setPlanBonus(FieldListHUD.PLAN_BONUS - 5) end)
        stepBtn(plusX, "+", function() self:setPlanBonus(FieldListHUD.PLAN_BONUS + 5) end)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(unpack(self.colorArea))
        renderText(valX + valW / 2, by + bh / 2, 0.0145, string.format("%d %%", FieldListHUD.PLAN_BONUS))
        self:drawFrame(defX, by, defW, bh, self.colorTile, self.colorBorder)
        setTextBold(false)
        setTextColor(unpack(self.colorTitle))
        renderText(defX + defW / 2, by + bh / 2, 0.012, T("opt_default"))
        table.insert(self.optBtns, { x = defX, y = by, w = defW, h = bh, fn = function() self:setPlanBonus(FieldListHUD.PLAN_BONUS_DEFAULT) end })
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    end
    top = top - rowH - 0.030

    -- Bereich Saisonale Produktion
    top = self:drawSection(x0, top, w0, T("opt_sec_season"))
    rowBase(top, T("opt_season"), T("opt_season_hint") .. (canRot and "" or ("  " .. T("opt_host_only"))), not canRot)
    toggle(top, FieldListHUD.seasonal == true, canRot, function(v) self:setSeasonal(v) end)
    top = top - rowH - 0.030

    -- Bereich HUD
    top = self:drawSection(x0, top, w0, T("opt_sec_hud"))
    rowBase(top, T("opt_hud"), T("opt_hud_hint"), false)
    toggle(top, self.settings.hud == true, true, function(v) self:setHud(v) end)
    top = top - rowH - gap
    rowBase(top, T("opt_hud_sort"), T("opt_hud_sort_hint"), false)
    toggle(top, self.settings.sortPrio == true, true, function(v) self:setHudSort(v) end)
end

-- Klick auf Seite 5
function FieldListHUD:optionsMouse(posX, posY, isDown, button)
    if not isDown or button ~= Input.MOUSE_BUTTON_LEFT then return false end
    for _, b in ipairs(self.optBtns or {}) do
        if posX >= b.x and posX <= b.x + b.w and posY >= b.y and posY <= b.y + b.h then
            b.fn()
            return true
        end
    end
    return false
end

-- Seitenreihenfolge im Menü: Agronomie, Arbeiten (intern 4), Feldtabelle (2), Produktionen (3), Erntekalender (intern 6)
FieldListHUD.PAGE_ORDER = { 1, 4, 2, 3 }

-- Erntekalender (intern 6) gibt es nur bei eingeschalteter Option "Saisonale Produktion"
function FieldListHUD.getPageOrder()
    local o = { 1, 4, 2, 3, 7 }
    if FieldListHUD.seasonal == true then o[#o + 1] = 6 end
    return o
end

-- Pfeile oben rechts zum Wechseln zwischen Seite 1 und 2
function FieldListHUD:drawPageArrows(L)
    local h = 0.034
    local w = h / (g_screenAspectRatio or (16 / 9))
    local top = L.ay + L.ah
    local nextX = L.ax + L.aw - 0.015 - w
    local prevX = nextX - w - 0.006
    local y = top - h - 0.004
    local order = FieldListHUD.getPageOrder()
    local pos = 1
    for i, pg in ipairs(order) do if pg == self.page then pos = i end end
    -- Einstellungs-Button (Regler-Symbol); auf der Optionsseite ganz rechts, sonst links vom Seitenzähler
    local gw, gh = w, h
    local gx = prevX - getTextWidth(0.013, string.format(T("page_x"), pos, #order)) - 0.020 - gw
    if self.page == 5 then gx = nextX end
    local gearOn = (self.page == 5)
    self:drawFrame(gx, y, gw, gh, gearOn and self.colorArea or self.colorTile, gearOn and self.colorBorder or self.colorArea)
    local gc = gearOn and { 0.02, 0.02, 0.02, 1 } or self.colorTitle
    if gearOn then
        -- Kreuz zum Schließen: zwei Diagonalen aus kleinen Quadraten
        local steps = 12
        local sz = gh * 0.075
        local szx = sz / (g_screenAspectRatio or (16 / 9))
        local m = 0.28
        for k = 0, steps do
            local f = k / steps
            local px = gx + gw * (m + (1 - 2 * m) * f) - szx / 2
            local py1 = y + gh * (m + (1 - 2 * m) * f) - sz / 2
            local py2 = y + gh * (1 - m - (1 - 2 * m) * f) - sz / 2
            self:drawRect(px, py1, szx, sz, gc)
            self:drawRect(px, py2, szx, sz, gc)
        end
    else
        for i = 0, 2 do
            local ly = y + gh * (0.28 + i * 0.22)
            self:drawRect(gx + gw * 0.18, ly, gw * 0.64, gh * 0.045, gc)
            local kx = gx + gw * (0.30 + ((i * 2) % 3) * 0.20)
            self:drawRect(kx, ly - gh * 0.045, gw * 0.12, gh * 0.135, gc)
        end
    end
    self.gearBtn = { x = gx, y = y, w = gw, h = gh }
    if self.page == 5 then
        self.pageBtns = {}
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextColor(unpack(self.colorSub))
        renderText(gx - 0.008, y + h / 2, 0.013, T("opt_back"))
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        return
    end
    self.pageBtns = {
        prev = { x = prevX, y = y, w = w, h = h, page = order[math.max(1, pos - 1)], isPrev = true },
        next = { x = nextX, y = y, w = w, h = h, page = order[math.min(#order, pos + 1)] },
    }
    for _, b in pairs(self.pageBtns) do
        local active = (self.page == b.page)
        -- Der Pfeil in Richtung der anderen Seite ist die aktive Schaltfläche
        self:drawFrame(b.x, b.y, b.w, b.h, self.colorTile, active and self.colorBorder or self.colorArea)
        -- Pfeil als kleines Dreieck zeichnen (exakt mittig, unabhängig von der Schrift)
        local col = active and self.colorSub or self.colorTitle
        local th = b.h * 0.42
        local tw = th * 0.62 / (g_screenAspectRatio or (16 / 9)) * 1.0
        local steps = 10
        local sw = tw / steps
        local x0 = b.x + (b.w - tw) / 2
        local cy = b.y + b.h / 2
        for k = 0, steps - 1 do
            local frac = (k + 0.5) / steps
            if not b.isPrev then
                frac = 1 - frac
            end
            local sh = th * frac
            self:drawRect(x0 + k * sw, cy - sh / 2, sw + 0.0001, sh, col)
        end
    end
    setTextAlignment(RenderText.ALIGN_RIGHT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextColor(unpack(self.colorSub))
    renderText(prevX - 0.008, y + h / 2, 0.013, string.format(T("page_x"), pos, #order))
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
end

-- Eine Frucht-Zelle: kleines Icon plus Name (oder "-")
function FieldListHUD:drawFruitCell(e, x, y, w, h, textSize)
    local iconH = h * 0.70
    local iconW = iconH / (g_screenAspectRatio or (16 / 9))
    local ix = x + 0.008
    local iy = y + (h - iconH) / 2
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextAlignment(RenderText.ALIGN_LEFT)
    if e == nil then
        setTextColor(unpack(self.colorSub))
        renderText(x + 0.008, y + h / 2, textSize, "-")
        return
    end
    local fill = self.colorIcon
    local label = e.fruitTitle
    if label == nil then
        fill = (e.id ~= nil) and self:getNoFruitColor(e) or self.colorNoFruit
        label = (e.id ~= nil) and self:getStatusText(e) or "-"
    end
    self:drawRect(ix, iy, iconW, iconH, fill)
    local icon = self:getIcon(e.iconFilename)
    if icon ~= nil then
        icon:setPosition(ix, iy)
        icon:setDimension(iconW, iconH)
        icon:render()
    end
    setTextColor(unpack(self.colorTitle))
    local tx = ix + iconW + 0.007
    local maxW = x + w - tx - 0.004
    local size = textSize
    local tw = getTextWidth(size, label)
    if tw > maxW then
        size = size * maxW / tw
    end
    renderText(tx, y + h / 2, size, label)
end

function FieldListHUD:drawTablePage(L)
    local x0, w0 = L.ax, L.aw - 0.015
    local top = L.ay + L.ah

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x0, top, 0.036, T("title_table"))
    setTextBold(false)
    top = top - 0.060

    -- Filter-Schaltflächen unten links (gleiche Filter wie auf Seite 1)
    local filterH = 0.026
    local bw, bgap = 0.12, 0.006
    self.filterBtns2 = {}
    -- Den Filter "Arbeiten" gibt es hier nicht (die Arbeiten stehen auf einer eigenen Seite)
    local fi = 0
    for _, f in ipairs(FieldListHUD.FILTERS) do
        if f.mode ~= 4 then
            table.insert(self.filterBtns2, {
                mode = f.mode, label = f.label,
                x = x0 + fi * (bw + bgap), y = L.ay + L.pad, w = bw, h = filterH,
            })
            fi = fi + 1
        end
    end
    self:drawFilterButtons(self.filterBtns2)
    -- Breite der beiden Planungsknöpfe: Text plus kleiner Rand, beide gleich breit
    local nAuto = 0
    for _, e in ipairs(self.fields or {}) do
        local rA = self.store[e.id]
        if rA ~= nil and rA.autoNext and rA.next ~= nil then nAuto = nAuto + 1 end
    end
    setTextBold(true)
    local planW = math.max(getTextWidth(0.011, T("plan_btn")), getTextWidth(0.011, string.format(T("accept_btn"), nAuto))) + 0.030
    setTextBold(false)
    self:drawPlanButton(x0 + w0 - planW, L.ay + L.pad, planW, filterH, "left", nil, x0 + w0 - 2 * planW - 0.006)
    -- Auto-Vorschläge fest übernehmen (werden dann von "Automatisch planen" nicht mehr überschrieben)
    do
        local ab = { x = x0 + w0 - planW - 0.006 - planW, y = L.ay + L.pad, w = planW, h = filterH }
        local on = nAuto > 0
        self:drawFrame(ab.x, ab.y, ab.w, ab.h, self.colorTile, on and self.colorArea or self.colorBorder)
        local label = string.format(T("accept_btn"), nAuto)
        local size = 0.011
        local tw = getTextWidth(size, label)
        if tw > ab.w * 0.92 then size = size * (ab.w * 0.92) / tw end
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(unpack(on and self.colorTitle or self.colorSub))
        renderText(ab.x + ab.w / 2, ab.y + ab.h / 2, size, label)
        setTextBold(false)
        self.acceptBtn = on and ab or nil
    end

    -- Detailfeld (Produktion) über den Filterknöpfen
    local infoH = 0.108 -- Platz für 4 Zeilen (Kopf + dieses Jahr + nächstes Jahr + in 2 Jahren)
    local infoY = L.ay + L.pad + filterH + 0.010
    local bottom = infoY + infoH + 0.008
    local headH = 0.036
    local rowH = 0.042
    local scrollW = 0.006
    local gap = 0.006
    -- Eigener Filter dieser Seite (unabhängig von Seite 1 und 2)
    local fields = {}
    for _, e in ipairs(self.fields or {}) do
        if self:matchesFilter(e, self.tblFilter or 1) then fields[#fields + 1] = e end
    end
    local bodyH = top - bottom - headH
    local rows = math.max(1, math.floor(bodyH / rowH))
    local t = self.tbl
    t.max = math.max(0, #fields - rows)
    t.offset = math.max(0, math.min(t.offset or 0, t.max))
    local needScroll = #fields > rows
    local tableW = w0 - (needScroll and (scrollW + gap) or 0)

    -- Spalten: Feld, Fläche, Folgefrucht, Aktuell, Vorfrucht 1..6
    local cols = {
        { title = T("col_field"),           f = 0.08 },
        { title = T("col_area"),         f = 0.09 },
        { title = T("col_yield"),         f = 0.09 },
        { title = T("col_prod"),          f = 0.07 },
        { title = T("box_next"),    f = 0.30 },
        { title = T("sec_current"), f = 0.19 },
        { title = T("box_prev1"),    f = 0.165 },
        { title = T("box_prev2"),    f = 0.155 },
        { title = T("box_prev3"),    f = 0.155 },
        { title = T("box_prev4"),    f = 0.14 },
        { title = T("box_prev5"),    f = 0.14 },
        { title = T("box_prev6"),    f = 0.14 },
    }
    local sum = 0
    for _, c in ipairs(cols) do sum = sum + c.f end
    local cx = x0
    for _, c in ipairs(cols) do
        c.x = cx
        c.w = tableW * c.f / sum
        cx = cx + c.w
    end

    -- Kopfzeile
    self:drawFrame(x0, top - headH, tableW, headH, self.colorTile, self.colorBorder)
    self:drawRect(x0, top - headH, tableW, 0.0015, self.colorArea)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    for _, c in ipairs(cols) do
        renderText(c.x + 0.008, top - headH / 2, 0.011, c.title)
    end
    setTextBold(false)

    -- Zeilen
    local prodMap = self:getProdMap()
    local hoverId, hoverX = nil, nil
    local altColor = { 0.026, 0.026, 0.026, 1 }
    t.hitRows = {}
    for r = 1, rows do
        local e = fields[t.offset + r]
        if e == nil then
            break
        end
        local ry = top - headH - r * rowH
        table.insert(t.hitRows, { x = x0, y = ry, w = tableW, h = rowH, id = e.id })
        do
            local mx, my = self.mouseX, self.mouseY
            if mx ~= nil and mx >= x0 and mx <= x0 + tableW and my >= ry and my <= ry + rowH then
                hoverId = e.id
                hoverX = mx
            end
        end
        if rectsOverlap({ x = x0, y = ry, w = tableW, h = rowH }, self.tipRectPrev) then
            -- unter dem Tooltip nichts zeichnen (Text würde durchscheinen)
            self:drawRect(x0, ry, tableW, rowH, { 0.016, 0.016, 0.016, 1 })
        else
        self:drawFrame(x0, ry, tableW, rowH, (r % 2 == 1) and self.colorTile or altColor, self.colorBorder)

        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(true)
        setTextColor(unpack(self.colorTitle))
        renderText(cols[1].x + 0.008, ry + rowH / 2, 0.014, tostring(e.id))
        setTextBold(false)
        setTextColor(unpack(self.colorArea))
        renderText(cols[2].x + 0.008, ry + rowH / 2, 0.013, string.format("%.2f ha", e.area))

        local rec = self:getRecord(e.id)
        local textSize = 0.013
        local ypct = self:getYieldPercent(e)
        setTextColor(unpack(self:getYieldColor(ypct)))
        renderText(cols[3].x + 0.008, ry + rowH / 2, 0.013, ypct ~= nil and string.format("%.1f %%", 100 + ypct) or "-")
        do
            local info = prodMap[e.id]
            if info ~= nil then
                local col = info.state == "full" and { 0.45, 0.85, 0.30, 1 }
                    or (info.state == "part" and { 1, 0.80, 0.20, 1 } or { 0.45, 0.45, 0.45, 1 })
                local dh = 0.012
                local dw = dh * g_screenHeight / g_screenWidth
                self:drawRect(cols[4].x + 0.012, ry + rowH / 2 - dh / 2, dw, dh, col)
            else
                setTextColor(unpack(self.colorSub))
                renderText(cols[4].x + 0.012, ry + rowH / 2, 0.013, "-")
            end
        end
        self:drawFruitCell(self:getNextFruitEntry(e), cols[5].x, ry, cols[5].w, rowH, textSize)
        if rec.autoNext and rec.next ~= nil then
            -- automatisch geplant, noch nicht fest übernommen
            setTextAlignment(RenderText.ALIGN_RIGHT)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextBold(true)
            setTextColor(unpack(self.colorNoFruit))
            renderText(cols[5].x + cols[5].w - 0.008, ry + rowH / 2, 0.011, (string.gsub(T("auto_suffix"), "^%s*", "")))
            setTextBold(false)
            setTextAlignment(RenderText.ALIGN_LEFT)
        end
        if e.unused then
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextColor(unpack(self.colorSub))
            renderText(cols[6].x + 0.008, ry + rowH / 2, textSize, T("unused"))
        else
            self:drawFruitCell(self:getMainEntry(e), cols[6].x, ry, cols[6].w, rowH, textSize)
        end
        local dispHist = self:getDisplayHist(e)
        for i = 1, FieldListHUD.MAX_HIST do
            self:drawFruitCell(self:getEntryByFruitName(dispHist[i]), cols[6 + i].x, ry, cols[6 + i].w, rowH, textSize)
        end
        end
    end
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    if #fields == 0 then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(unpack(self.colorSub))
        renderText(x0 + 0.008, top - headH - 0.012, 0.013,
            #(self.fields or {}) == 0 and T("no_fields") or T("no_fields_sel"))
    end

    -- Detailfeld
    self:drawFrame(x0, infoY, w0, infoH, self.colorTile, self.colorBorder)
    do
        local info = hoverId ~= nil and prodMap[hoverId] or nil
        local fcLines = nil
        if hoverId ~= nil and hoverX ~= nil then
            -- Maus über "Folgefrucht" = Werte der Folgefrucht, über "Aktuell" = Werte der aktuellen Frucht,
            -- Vorfrüchte = nichts, sonst die Frucht mit der besten Deckung
            local he = nil
            for _, fe in ipairs(fields) do if fe.id == hoverId then he = fe break end end
            local nameWanted, colHit = nil, false
            if he ~= nil then
                if hoverX >= cols[5].x and hoverX < cols[5].x + cols[5].w then
                    nameWanted, colHit = self:getRecord(he.id).next, true
                elseif hoverX >= cols[6].x and hoverX < cols[6].x + cols[6].w then
                    nameWanted, colHit = he.fruitName, true
                elseif hoverX >= cols[7].x then
                    info = nil -- Vorfrüchte: keine Produktionsangaben
                end
            end
            if colHit then
                -- Sommerweizen/-gerste zählen wie Weizen/Gerste
                if nameWanted ~= nil then
                    nameWanted = string.upper(nameWanted)
                    nameWanted = FieldListHUD.FRUIT_ALIAS[nameWanted] or nameWanted
                end
                local own = (info ~= nil and info.byName ~= nil and nameWanted ~= nil) and info.byName[nameWanted] or nil
                info = own
                if info == nil and nameWanted ~= nil then
                    -- kein Produktionsbedarf: stattdessen die Ertragsprognose im passenden Erntejahr
                    fcLines = self:getForecastTip(hoverId, nameWanted)
                end
            end
        end
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        if info ~= nil or fcLines ~= nil then
            local lines = fcLines or self:getProdTip(info)
            local lh = 0.022
            local ty = infoY + infoH - 0.008 - lh / 2
            for _, ln in ipairs(lines) do
                setTextBold(ln[2] == true)
                setTextColor(unpack(ln[2] and self.colorTitle or (ln[3] and { 1, 0.4, 0.4, 1 } or self.colorSub)))
                renderText(x0 + 0.010, ty, 0.012, ln[1])
                ty = ty - lh
            end
            setTextBold(false)
        else
            setTextColor(unpack(self.colorSub))
            renderText(x0 + 0.010, infoY + infoH / 2, 0.012, T("prod_hint"))
        end
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    end

    -- Scrollleiste
    t.track, t.thumb = nil, nil
    if needScroll then
        local trackH = rows * rowH
        local thumbH = math.max(0.03, trackH * rows / #fields)
        local frac = t.max > 0 and (t.offset / t.max) or 0
        t.track = { x = x0 + tableW + gap, y = top - headH - trackH, w = scrollW, h = trackH }
        t.thumb = { x = t.track.x, y = t.track.y + trackH - thumbH - (trackH - thumbH) * frac, w = scrollW, h = thumbH }
        self:drawRect(t.track.x, t.track.y, t.track.w, t.track.h, self.colorTrack)
        self:drawRect(t.thumb.x, t.thumb.y, t.thumb.w, t.thumb.h, self.colorThumb)
    end
    t.area = { x = x0, y = bottom, w = w0, h = top - bottom }
    t.rows = rows
end


-- Seite "Arbeiten": Tabelle aller anstehenden Arbeiten je Feld (gleicher Filter wie Seite 1)
FieldListHUD.WORK_COLS = {
    { kind = "harvest", key = "wk_col_harvest", green = true, f = 0.085 },
    { kind = "plow",    key = "wk_col_plow",    f = 0.085 },
    { kind = "stones",  key = "wk_col_stones",  f = 0.085 },
    { kind = "lime",    key = "wk_col_lime",    f = 0.085 },
    { kind = "spray",   key = "wk_col_spray",   f = 0.085 },
    { kind = "weeds",   key = "wk_col_weeds",   f = 0.085 },
    { kind = "cc",      key = "wk_col_cc",      green = true, f = 0.115 },
    { kind = "sow",     key = "wk_col_sow",     green = true, f = 0.115 },
    { kind = "roll",    key = "wk_col_roll",    f = 0.085 },
}

function FieldListHUD:getWorkRows()
    local c = self.wkCache
    local now = g_time or 0
    if c ~= nil and not self.wkDirty and c.mode == (self.wkFilter or 4) and c.sort == (tostring(self.workCol) .. tostring(self.workDir)) and (now - c.t) < 1000 then
        return c.rows
    end
    self.wkDirty = false
    local rows = self:buildWorkRows()
    self.wkCache = { rows = rows, t = now, mode = (self.wkFilter or 4), sort = (tostring(self.workCol) .. tostring(self.workDir)) }
    return rows
end

function FieldListHUD:buildWorkRows()
    local rows = {}
    -- Arbeiten-Tabelle: im Filter "Arbeiten" auch Felder, auf denen nur zurückgestellte Arbeiten übrig sind
    -- Eigener Filter dieser Seite (unabhängig von Seite 1 und 3)
    local wkMode = self.wkFilter or 4
    local src = {}
    for _, e in ipairs(self.fields or {}) do
        local ok
        if wkMode == 4 then
            ok = not e.unused and #self:getWorkItems(e, true) > 0
        else
            ok = self:matchesFilter(e, wkMode)
        end
        if ok then src[#src + 1] = e end
    end
    for _, e in ipairs(src) do
        local items = self:getWorkItems(e, true)
        local byKind, minPrio, n = {}, 99, 0
        for _, it in ipairs(items) do
            byKind[it.kind or "?"] = it
            if not it.postponed then
                n = n + 1
                if (it.prio or 99) < minPrio then minPrio = it.prio or 99 end
            end
        end
        table.insert(rows, { e = e, kinds = byKind, n = n, prio = minPrio })
    end
    local col = self.workCol or "id"
    local dir = self.workDir or 1
    local function key(rd)
        if col == "id" then return rd.e.id end
        if col == "area" then return rd.e.area or 0 end
        if col == "fruit" then
            local en = (not rd.e.unused) and self:getMainEntry(rd.e) or nil
            return string.lower((en ~= nil and en.fruitTitle) or "~")
        end
        return (rd.kinds[col] ~= nil and not rd.kinds[col].postponed) and 1 or 0
    end
    for _, rd in ipairs(rows) do rd.key = (col ~= "urgent") and key(rd) or 0 end
    table.sort(rows, function(x, y)
        if col == "urgent" then
            if x.prio ~= y.prio then return x.prio < y.prio end
            if x.n ~= y.n then return x.n > y.n end
        elseif x.key ~= y.key then
            if dir == 1 then return x.key < y.key else return x.key > y.key end
        end
        return x.e.id < y.e.id
    end)
    return rows
end

function FieldListHUD:drawWorkPage(L)
    local x0, w0 = L.ax, L.aw - 0.015
    local top = L.ay + L.ah
    self.wk = self.wk or { offset = 0, max = 0 }
    local t = self.wk

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    do
        -- Titel ist lang: Schrift verkleinern, damit er nicht in die Seitenpfeile rechts läuft
        local tsize = 0.036
        local tw = getTextWidth(tsize, T("title_work"))
        local maxW = w0 - 0.30
        if tw > maxW and tw > 0 then tsize = tsize * maxW / tw end
        renderText(x0, top, tsize, T("title_work"))
    end
    setTextBold(false)
    top = top - 0.060

    -- Filter unten links, Sortierung unten rechts
    local filterH = 0.026
    local bw, bgap = 0.12, 0.006
    self.filterBtns4 = {}
    for i, f in ipairs(FieldListHUD.FILTERS) do
        table.insert(self.filterBtns4, {
            mode = f.mode, label = f.label,
            x = x0 + (i - 1) * (bw + bgap), y = L.ay + L.pad, w = bw, h = filterH,
        })
    end
    self:drawFilterButtons(self.filterBtns4)
    self.sortBtn4 = nil

    local rowsData = self:getWorkRows()
    local bottom = L.ay + L.pad + filterH + 0.010
    local headH = 0.036
    local rowH = 0.042
    local footH = 0.050
    local scrollW, gap = 0.006, 0.006
    local bodyH = top - bottom - headH - footH
    local rows = math.max(1, math.floor(bodyH / rowH))
    t.max = math.max(0, #rowsData - rows)
    t.offset = math.max(0, math.min(t.offset or 0, t.max))
    local needScroll = #rowsData > rows
    local tableW = w0 - (needScroll and (scrollW + gap) or 0)

    -- Spalten: Feld, Fläche, Frucht, dann die Arbeiten
    local cols = {
        { title = T("col_field"), f = 0.07 },
        { title = T("col_area"), f = 0.09 },
        { title = T("wk_col_fruit"), f = 0.17 },
    }
    for _, c in ipairs(FieldListHUD.WORK_COLS) do
        table.insert(cols, { title = T(c.key), f = c.f, kind = c.kind, green = c.green })
    end
    local sum = 0
    for _, c in ipairs(cols) do sum = sum + c.f end
    local cx = x0
    for _, c in ipairs(cols) do
        c.x = cx
        c.w = tableW * c.f / sum
        cx = cx + c.w
    end

    -- Kopfzeile
    self:drawFrame(x0, top - headH, tableW, headH, self.colorTile, self.colorBorder)
    self:drawRect(x0, top - headH, tableW, 0.0015, self.colorArea)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    local colKeys = { "id", "area", "fruit" }
    t.heads = {}
    local curCol, curDir = self.workCol or "id", self.workDir or 1
    for i, c in ipairs(cols) do
        c.key = colKeys[i] or c.kind
        local hs = 0.011
        local tw = getTextWidth(hs, c.title)
        local maxW = c.w - 0.012 - (c.key == curCol and 0.014 or 0)
        if tw > maxW then hs = hs * maxW / tw end
        -- Text unter einem Tooltip nicht zeichnen (Text liegt sonst über dem Tooltip)
        local covered = rectsOverlap({ x = c.x, y = top - headH, w = c.w, h = headH }, self.tipRectPrev)
        if not covered then renderText(c.x + 0.008, top - headH / 2, hs, c.title) end
        table.insert(t.heads, { x = c.x, y = top - headH, w = c.w, h = headH, key = c.key, isKind = c.kind ~= nil })
        if c.key == curCol and not covered then
            -- Dreieck: nach unten = absteigend, nach oben = aufsteigend
            local tw2 = getTextWidth(hs, c.title)
            local ax0 = c.x + 0.008 + tw2 + 0.008
            local steps, sh, sw = 5, 0.0016, 0.010 / (g_screenAspectRatio or (16 / 9)) * 1.6
            local ay0 = top - headH / 2 - (steps * sh) / 2
            for k = 0, steps - 1 do
                local wk = sw * ((curDir == 1) and (1 - k / steps) or ((k + 1) / steps))
                self:drawRect(ax0 + (sw - wk) / 2, ay0 + k * sh, wk, sh + 0.0001, self.colorArea)
            end
        end
    end
    setTextBold(false)

    -- Zeilen
    local altColor = { 0.026, 0.026, 0.026, 1 }
    t.rows = {}
    t.cells = {}
    local hoverPost = nil
    local dotH = 0.012
    local dotW = dotH / (g_screenAspectRatio or (16 / 9))
    for r = 1, rows do
        local rd = rowsData[t.offset + r]
        if rd == nil then break end
        local e = rd.e
        local ry = top - headH - r * rowH
        table.insert(t.rows, { x = x0, y = ry, w = tableW, h = rowH, id = e.id })
        if rectsOverlap({ x = x0, y = ry, w = tableW, h = rowH }, self.tipRectPrev) then
            self:drawRect(x0, ry, tableW, rowH, { 0.016, 0.016, 0.016, 1 })
        else
            self:drawFrame(x0, ry, tableW, rowH, (r % 2 == 1) and self.colorTile or altColor, self.colorBorder)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextBold(true)
            setTextColor(unpack(self.colorTitle))
            renderText(cols[1].x + 0.008, ry + rowH / 2, 0.014, tostring(e.id))
            -- Traktorsymbol hinter der Feldnummer, wenn ein eigenes Fahrzeug auf dem Feld steht
            local veh = self:getVehiclesOnField(e.id)
            if veh ~= nil then
                local bh = math.min(rowH * 0.72, 0.022)
                local bw = bh / (g_screenAspectRatio or (16 / 9))
                local bx = cols[1].x + 0.008 + getTextWidth(0.014, tostring(e.id)) + 0.006
                if bx + bw < cols[2].x then
                    self:drawTractorBadge(bx, ry + rowH / 2 - bh / 2, bw, bh, veh.working, veh.count, RenderText.VERTICAL_ALIGN_MIDDLE)
                end
            end
            setTextBold(false)
            setTextColor(unpack(self.colorArea))
            renderText(cols[2].x + 0.008, ry + rowH / 2, 0.013, string.format("%.2f ha", e.area or 0))
            if e.unused then
                setTextColor(unpack(self.colorSub))
                renderText(cols[3].x + 0.008, ry + rowH / 2, 0.013, T("unused"))
            else
                self:drawFruitCell(self:getMainEntry(e), cols[3].x, ry, cols[3].w, rowH, 0.012)
            end
            for i = 4, #cols do
                local c = cols[i]
                local it = rd.kinds[c.kind]
                if it ~= nil then
                    local col = c.green and self.colorArea or self.colorWork
                    if it.postponed then col = { 0.45, 0.45, 0.45, 1 } end
                    if it.kind ~= "harvest" then
                        local cell = { x = c.x, y = ry, w = c.w, h = rowH, id = e.id, kind = it.kind, postponed = it.postponed }
                        table.insert(t.cells, cell)
                        local mx, my = self.mouseX, self.mouseY
                        if mx ~= nil and mx >= cell.x and mx <= cell.x + cell.w and my >= cell.y and my <= cell.y + cell.h then
                            hoverPost = it.postponed and 2 or 1
                        end
                    end
                    local dx = c.x + 0.008
                    self:drawRect(dx, ry + rowH / 2 - dotH / 2, dotW, dotH, col)
                    if it.cell ~= nil then
                        local size = 0.012
                        local maxW = c.w - 0.008 - dotW - 0.012
                        local tw = getTextWidth(size, it.cell)
                        if tw > maxW then size = size * maxW / tw end
                        setTextAlignment(RenderText.ALIGN_LEFT)
                        setTextColor(unpack(it.postponed and self.colorSub or self.colorTitle))
                        local cy = ry + rowH / 2
                        if it.cell2 ~= nil then cy = cy + 0.0065 end
                        renderText(dx + dotW + 0.006, cy, size, it.cell)
                        if it.cell2 ~= nil then
                            local s2 = 0.0098
                            local w2 = getTextWidth(s2, it.cell2)
                            if w2 > maxW then s2 = s2 * maxW / w2 end
                            setTextColor(unpack(self.colorSub))
                            renderText(dx + dotW + 0.006, ry + rowH / 2 - 0.0075, s2, it.cell2)
                        end
                    end
                else
                    setTextAlignment(RenderText.ALIGN_LEFT)
                    setTextColor(unpack(self.colorSub))
                    renderText(c.x + 0.008, ry + rowH / 2, 0.013, "-")
                end
            end
        end
    end
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    if #rowsData == 0 then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(unpack(self.colorSub))
        renderText(x0 + 0.008, top - headH - 0.012, 0.013,
            #(self.fields or {}) == 0 and T("no_fields") or T("no_fields_sel"))
    end

    -- Hinweis unten rechts neben den Filterknöpfen (statt Tooltip)
    do
        local hint = hoverPost == 2 and (T("wk_post_on") .. ". " .. T("wk_post_back")) or T("wk_post_hint")
        local hx0 = x0 + #FieldListHUD.FILTERS * (bw + bgap) + 0.010
        local maxW = x0 + w0 - hx0
        local size = 0.0115
        -- bei Platzmangel auf zwei Zeilen umbrechen statt die Schrift zu verkleinern
        local lines = { hint }
        if getTextWidth(size, hint) > maxW then
            local cut = nil
            for pos in hint:gmatch("()%s") do
                if getTextWidth(size, hint:sub(1, pos - 1)) <= maxW then cut = pos end
            end
            local half = math.floor(#hint / 2)
            local best, bd = nil, math.huge
            for pos in hint:gmatch("()%s") do
                if math.abs(pos - half) < bd then best, bd = pos, math.abs(pos - half) end
            end
            cut = best or cut
            if cut ~= nil then lines = { hint:sub(1, cut - 1), hint:sub(cut + 1) } end
        end
        local widest = 0
        for _, ln in ipairs(lines) do widest = math.max(widest, getTextWidth(size, ln)) end
        if widest > maxW and widest > 0 then size = size * maxW / widest end
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(false)
        setTextColor(unpack(hoverPost == 2 and self.colorWork or self.colorSub))
        local cy = L.ay + L.pad + filterH / 2
        if #lines == 1 then
            renderText(x0 + w0, cy, size, lines[1])
        else
            renderText(x0 + w0, cy + size * 0.65, size, lines[1])
            renderText(x0 + w0, cy - size * 0.65, size, lines[2])
        end
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    end

    -- Fußzeile: je Arbeit Hektar und Anzahl Felder (alle Felder des Filters, nicht nur die sichtbaren Zeilen)
    local sums = {}
    for _, rd in ipairs(rowsData) do
        for kind, it in pairs(rd.kinds) do
            if not it.postponed then
                local s2 = sums[kind] or { ha = 0, n = 0 }
                s2.ha = s2.ha + (rd.e.area or 0)
                s2.n = s2.n + 1
                sums[kind] = s2
            end
        end
    end
    local fy = top - headH - rows * rowH - footH
    self:drawFrame(x0, fy, tableW, footH, self.colorTile, self.colorArea)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(cols[1].x + 0.008, fy + footH / 2, 0.012, T("wk_sum"))
    for i = 4, #cols do
        local c = cols[i]
        local s2 = sums[c.kind]
        if s2 ~= nil then
            setTextColor(unpack(c.green and self.colorArea or self.colorWork))
            renderText(c.x + 0.008, fy + footH * 0.70, 0.012, string.format("%.1f ha", s2.ha))
            setTextBold(false)
            setTextColor(unpack(self.colorSub))
            renderText(c.x + 0.008, fy + footH * 0.28, 0.011, string.format(T("wk_fields"), s2.n))
            setTextBold(true)
        else
            setTextBold(false)
            setTextColor(unpack(self.colorSub))
            renderText(c.x + 0.008, fy + footH / 2, 0.012, "-")
            setTextBold(true)
        end
    end
    setTextBold(false)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)

    -- Scrollleiste
    t.track, t.thumb = nil, nil
    if needScroll then
        local trackH = rows * rowH
        local thumbH = math.max(0.03, trackH * rows / #rowsData)
        local frac = t.max > 0 and (t.offset / t.max) or 0
        t.track = { x = x0 + tableW + gap, y = top - headH - trackH, w = scrollW, h = trackH }
        t.thumb = { x = t.track.x, y = t.track.y + trackH - thumbH - (trackH - thumbH) * frac, w = scrollW, h = thumbH }
        self:drawRect(t.track.x, t.track.y, t.track.w, t.track.h, self.colorTrack)
        self:drawRect(t.thumb.x, t.thumb.y, t.thumb.w, t.thumb.h, self.colorThumb)
    end
    t.area = { x = x0, y = bottom, w = w0, h = top - bottom }
end

-- Springt zum Feld auf Seite 1 (Feld auswählen, Liste dorthin scrollen)
function FieldListHUD:jumpToField(id)
    self.selectedId = id
    for i, e in ipairs(self.visible or {}) do
        if e.id == id then
            self.scrollOffset = math.max(0, math.min(i - 1, self.maxOffset or 0))
            break
        end
    end
    self.page = 1
    self.popup = nil
end

function FieldListHUD:scrollWorkToY(posY)
    local t = self.wk
    if t == nil or t.track == nil or t.max <= 0 then
        return
    end
    local range = t.track.h - t.thumb.h
    if range <= 0 then
        return
    end
    local frac = ((t.track.y + t.track.h - t.thumb.h / 2) - posY) / range
    frac = math.max(0, math.min(1, frac))
    t.offset = math.floor(frac * t.max + 0.5)
end

function FieldListHUD:scrollTableToY(posY)
    local t = self.tbl
    if t == nil or t.track == nil or t.max <= 0 then
        return
    end
    local range = t.track.h - t.thumb.h
    if range <= 0 then
        return
    end
    local frac = ((t.track.y + t.track.h - t.thumb.h / 2) - posY) / range
    frac = math.max(0, math.min(1, frac))
    t.offset = math.floor(frac * t.max + 0.5)
end

function FieldListHUD:scrollP3ToY(posY)
    local p = self.p3
    if p == nil or p.track == nil or p.thumb == nil or p.max <= 0 then
        return
    end
    local range = p.track.h - p.thumb.h
    if range <= 0 then
        return
    end
    local frac = ((p.track.y + p.track.h - p.thumb.h / 2) - posY) / range
    frac = math.max(0, math.min(1, frac))
    p.offset = math.floor(frac * p.max + 0.5)
end

-- Seite 3: Erträge je Frucht in Litern (nur Hauptertrag), dieses und nächstes Jahr
local function fmtLiters(v)
    if v == nil or v <= 0 then
        return "-"
    end
    local n = string.format("%d", math.floor(v + 0.5))
    n = n:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return n .. " l"
end

-- Produktions-Markierung: welche Felder werden gebraucht, um den Jahresbedarf zu decken?
-- Je Frucht und Jahr (dieses / nächstes) werden die Felder nach Ertrag absteigend vergeben, bis der Bedarf gedeckt ist.
function FieldListHUD:getProdMap()
    local list = self:getPage3ListCached()
    if self.prodMapSrc == list and self.prodMap ~= nil then
        return self.prodMap
    end
    local rank = { full = 3, part = 2, over = 1 }
    local res = {}
    for _, item in ipairs(list or {}) do
        local isCut = item.multiCut or FieldListHUD.MULTI_CUT[item.name]
        local dem = item.demand or 0
        if dem > 0 and not item.isStraw and not item.isAnimal and not item.isSilage
            and item.fields ~= nil and (not isCut or item.cuts ~= nil) then
            local cutsF = (isCut and not item.yearly and item.cuts) or 1
            local totals, per = {}, {}
            for _, mode in ipairs({ "this", "next", "in2" }) do
                local entries, total = {}, 0
                for _, f in ipairs(item.fields) do
                    if f.mode == mode and f.liters ~= nil and f.liters > 0 then
                        local v = f.liters * cutsF
                        table.insert(entries, { id = f.id, v = v })
                        total = total + v
                    end
                end
                table.sort(entries, function(a, b)
                    if a.v ~= b.v then return a.v > b.v end
                    return a.id < b.id
                end)
                local cum = 0
                per[mode] = {}
                for _, en in ipairs(entries) do
                    local state, cover
                    if total <= dem then
                        state, cover = "full", en.v
                    elseif cum >= dem then
                        state, cover = "over", 0
                    elseif cum + en.v <= dem + 0.5 then
                        state, cover = "full", en.v
                    else
                        state, cover = "part", dem - cum
                    end
                    cum = cum + en.v
                    local old = per[mode][en.id]
                    if old == nil or rank[state] > rank[old.state] then
                        per[mode][en.id] = { state = state, cover = cover, yield = en.v }
                    end
                end
                totals[mode] = total
            end
            local ids = {}
            for _, mode in ipairs({ "this", "next", "in2" }) do
                for id in pairs(per[mode]) do ids[id] = true end
            end
            for id in pairs(ids) do
                local th, nx, i2 = per.this[id], per.next[id], per.in2[id]
                local state = (th or nx or i2).state
                local info = { state = state, title = item.title, dem = dem,
                    totThis = totals.this, totNext = totals.next, totIn2 = totals.in2, this = th, next = nx, in2 = i2 }
                local old = res[id]
                -- alle Früchte merken, damit beim Überfahren die Frucht der Zeile angezeigt werden kann
                local byName = (old ~= nil and old.byName) or {}
                if item.name ~= nil then byName[item.name] = info end
                if old == nil or rank[state] > rank[old.state] then
                    res[id] = info
                else
                    res[id] = old
                end
                res[id].byName = byName
            end
        end
    end
    self.prodMapSrc, self.prodMap = list, res
    return res
end

-- Ertragsprognose einer Frucht auf einem Feld (wenn es dafür keinen Produktionsbedarf gibt)
function FieldListHUD:getForecastTip(fieldId, fruitName)
    local list = self:getPage3ListCached()
    local lines, title = {}, nil
    for _, item in ipairs(list or {}) do
        if item.name == fruitName and item.fields ~= nil and not item.isStraw and not item.isAnimal then
            title = item.title
            local cuts = ((item.multiCut or FieldListHUD.MULTI_CUT[item.name]) and not item.yearly and item.cuts) or 1
            for _, mode in ipairs({ "this", "next", "in2" }) do
                local sum, mine = 0, 0
                for _, f in ipairs(item.fields) do
                    if f.mode == mode and f.liters ~= nil and f.liters > 0 then
                        sum = sum + f.liters * cuts
                        if f.id == fieldId then mine = mine + f.liters * cuts end
                    end
                end
                if sum > 0 then
                    local txt = string.format(T("prod_fc_" .. mode), fmtLiters(sum))
                    if mine > 0 then txt = txt .. string.format(T("prod_fc_field"), fmtLiters(mine)) end
                    table.insert(lines, { txt, false })
                end
            end
            break
        end
    end
    if #lines == 0 then return nil end
    table.insert(lines, 1, { string.format(T("prod_fc_head"), tostring(title or fruitName)), true })
    return lines
end

function FieldListHUD:getProdTip(info)
    local lines = { { string.format(T("prod_head"), tostring(info.title), fmtLiters(info.dem)), true } }
    local function fl(v) return (v or 0) > 0 and fmtLiters(v) or "0 l" end
    local function line(key, tot, fld)
        local txt = string.format(T(key), fl(tot), fl(info.dem), math.floor(tot / info.dem * 100 + 0.5))
        if fld ~= nil then
            local pct = math.floor(fld.cover / info.dem * 100 + 0.5)
            if fld.state == "full" then
                txt = txt .. string.format(T("prod_fld_full"), fl(fld.yield), pct)
            elseif fld.state == "part" then
                txt = txt .. string.format(T("prod_fld_part"), fl(fld.yield), fl(fld.cover), pct)
            else
                txt = txt .. string.format(T("prod_fld_over"), fl(fld.yield))
            end
        end
        local missing = tot < info.dem
        table.insert(lines, { txt, false, missing })
    end
    line("prod_y1", info.totThis, info.this)
    line("prod_y2", info.totNext, info.next)
    if (info.totIn2 or 0) > 0 then line("prod_y3", info.totIn2, info.in2) end
    return lines
end

local function fmtPerHour(v)
    if v == nil or v <= 0 then
        return "-"
    end
    local n = string.format("%d", math.floor(v + 0.5))
    n = n:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return n .. " l/h"
end

-- Ertrag je m²: bei Schnittfrüchten mit eigenem Schwad (z. B. Ackergras: 0,3988 l/m² roh, 3 l/m² als Schwad)
-- zählt die Schwadmenge, denn Mäher/Häcksler wandeln den Rohertrag darauf um.
function FieldListHUD.fruitLitersPerSqm(ft)
    if ft == nil then return 0 end
    local base = ft.literPerSqm or 0
    local wr = ft.windrowLiterPerSqm or 0
    if wr > base and FieldListHUD.CUT_CROPS ~= nil and FieldListHUD.CUT_CROPS[string.upper(ft.name or "")] then
        return wr
    end
    return base
end

function FieldListHUD:getFruitLiters(fruitIndex, areaHa, pct)
    local ft = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
    if ft == nil then
        return 0
    end
    return (ft.literPerSqm or 0) * (areaHa or 0) * 10000 * (1 + (pct or 0) / 100)
end

-- Aktuelle Spielperiode (1 = März) oder nil
function FieldListHUD:getCurrentPeriod()
    local ok, v = pcall(function()
        local env = g_currentMission ~= nil and g_currentMission.environment or nil
        return env ~= nil and env.currentPeriod or nil
    end)
    if ok and type(v) == "number" and v >= 1 and v <= 12 then
        return v
    end
    return nil
end

-- Erntejahr einer Frucht relativ zum laufenden Jahr (0 = noch dieses Jahr, 1 = nächstes, 2 = übernächstes).
-- kind "standing": Frucht steht schon; "sow": wird ab jetzt (nächste Saatperiode) gesät.
-- Ohne Perioden- oder Saisondaten gilt 0 (altes Verhalten).

-- Periode (1 = März) als Monatsname
function FieldListHUD.periodMonth(p)
    local m = ((p + 1) % 12) + 1
    return T("month_" .. m)
end

-- Erntemonat(e) einer Frucht als Text, z. B. "Jul–Aug"; "-" wenn unbekannt
-- Aussaatmonat einer geplanten Folgefrucht (gleiche Logik wie beim Erntemonat)
function FieldListHUD:getSowMonthText(fruitName, kind, fieldId)
    if kind ~= "n1" then return T("pop_sown") end
    local ft = fruitName ~= nil and g_fruitTypeManager:getFruitTypeByName(fruitName) or nil
    local ses = ft ~= nil and self:parseSeason(ft) or nil
    local cur = self:getCurrentPeriod()
    if ses == nil or ses.map == nil or cur == nil then return "-" end
    local e = nil
    for _, fe in ipairs(self.fields or {}) do
        if fe.id == fieldId then e = fe break end
    end
    local ab = cur
    if e ~= nil and e.fruitIndex ~= nil and e.growthState ~= nil and not FieldListHUD.isCatchCrop(string.upper(e.fruitName or "")) then
        local ftC = g_fruitTypeManager:getFruitTypeByIndex(e.fruitIndex)
        local sesC = ftC ~= nil and self:parseSeason(ftC) or nil
        if sesC ~= nil then
            local qC = self:simHarvestAbs(ftC, sesC, cur, e.growthState, true)
            if qC ~= nil and qC <= 12 then
                local he = qC
                while he < 12 and sesC.harvest[he + 1] do he = he + 1 end
                ab = he
            elseif qC ~= nil then
                ab = 13
            end
        end
    end
    local _, ps = self:plannedHarvestAbs(ft.index, (ab <= 12) and ab or 1)
    if ps == nil then return "-" end
    return FieldListHUD.periodMonth(((ps - 1) % 12) + 1)
end

function FieldListHUD:getHarvestMonthText(fruitName, mode, kind, fieldId)
    local ft = fruitName ~= nil and g_fruitTypeManager:getFruitTypeByName(fruitName) or nil
    local ses = ft ~= nil and self:parseSeason(ft) or nil
    if ses == nil then return "-" end
    local windows, start = {}, nil
    for p = 1, 13 do
        if p <= 12 and ses.harvest[p] then
            if start == nil then start = p end
        elseif start ~= nil then
            table.insert(windows, { start, p - 1 })
            start = nil
        end
    end
    if #windows == 0 then return "-" end
    -- Genau aus den Wachstumstabellen der Karte (Ruhemonate inklusive)
    do
        local cur = self:getCurrentPeriod()
        local e = nil
        for _, fe in ipairs(self.fields or {}) do
            if fe.id == fieldId then e = fe break end
        end
        if cur ~= nil and ses.map ~= nil and not FieldListHUD.MULTI_CUT[string.upper(fruitName or "")] then
            local q = nil
            if kind == "n" and e ~= nil and e.growthState ~= nil and e.fruitIndex == ft.index then
                if e.harvestReady and ses.harvest[cur] then
                    return FieldListHUD.periodMonth(cur) .. " (" .. T("pop_now") .. ")"
                end
                q = self:simHarvestAbs(ft, ses, cur, e.growthState, true)
            elseif kind == "n1" then
                -- Folgefrucht: Aussaat nach der Ernte der aktuellen Frucht, sonst ab jetzt
                local ab = cur
                if e ~= nil and e.fruitIndex ~= nil and e.growthState ~= nil and not FieldListHUD.isCatchCrop(string.upper(e.fruitName or "")) then
                    local ftC = g_fruitTypeManager:getFruitTypeByIndex(e.fruitIndex)
                    local sesC = ftC ~= nil and self:parseSeason(ftC) or nil
                    if sesC ~= nil then
                        local qC = self:simHarvestAbs(ftC, sesC, cur, e.growthState, true)
                        local startC = qC
                        if qC ~= nil and qC <= 12 then
                            -- Ende des Erntefensters
                            local he = qC
                            while he < 12 and sesC.harvest[he + 1] do he = he + 1 end
                            ab = he
                        elseif qC ~= nil then
                            ab = 13
                        end
                    end
                end
                q = self:plannedHarvestAbs(ft.index, (ab <= 12) and ab or 1)
            end
            if q ~= nil then
                return FieldListHUD.periodMonth(((q - 1) % 12) + 1)
            end
        end
    end
    local pick = windows[1]
    if FieldListHUD.MULTI_CUT[string.upper(fruitName or "")] then
        pick = { windows[1][1], windows[#windows][2] }
    elseif mode == "this" then
        local cur = self:getCurrentPeriod()
        if cur ~= nil then
            for _, wnd in ipairs(windows) do
                if wnd[2] >= cur then pick = wnd break end
            end
            -- Stehende Frucht (noch nicht erntereif): frühester möglicher Monat, nicht die ganze Spanne
            if kind == "n" then
                local first = math.max(pick[1], cur)
                local fe = nil
                for _, fe2 in ipairs(self.fields or {}) do
                    if fe2.id == fieldId then fe = fe2 break end
                end
                if fe ~= nil and not fe.harvestReady then first = math.max(pick[1], cur + 1) end
                if first <= pick[2] then pick = { first, first } end
            end
        end
    end
    local a, b = FieldListHUD.periodMonth(pick[1]), FieldListHUD.periodMonth(pick[2])
    return a == b and a or (a .. "–" .. b)
end

-- Erntejahr einer Folgefrucht auf einem Feld, dessen aktuelle Frucht noch in diesem Jahr geerntet wird:
-- Gesät wird erst, wenn die Ernte der aktuellen Frucht vorbei ist (Ende ihres Erntefensters).
-- Passt danach kein Saatfenster mehr ins laufende Jahr, wird erst im nächsten Jahr gesät.
-- Rückgabe: 1 = Ernte im nächsten Jahr, 2 = Ernte in 2 Jahren
function FieldListHUD:getFolgeOffset(fruitIndex, curIndex, late)
    local cur = self:getCurrentPeriod()
    local ftF = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
    do -- mit Übergangstabellen genau rechnen
        local ftC0 = curIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(curIndex) or nil
        local sesC0 = ftC0 ~= nil and self:parseSeason(ftC0) or nil
        local sesF0 = ftF ~= nil and self:parseSeason(ftF) or nil
        if cur ~= nil and sesC0 ~= nil and sesF0 ~= nil and sesF0.map ~= nil then
            -- Ende des Erntefensters der aktuellen Frucht: erst danach ist das Feld frei
            -- (late: Frucht wird erst im nächsten Jahr geerntet, dann zählt das erste Fenster des Jahres)
            local he, st0 = nil, nil
            for p = 1, 13 do
                if p <= 12 and sesC0.harvest[p] then
                    if st0 == nil then st0 = p end
                elseif st0 ~= nil then
                    if late or p - 1 >= cur then he = p - 1 break end
                    st0 = nil
                end
            end
            if late and he ~= nil then
                local q = self:plannedHarvestAbs(fruitIndex, he)
                if q ~= nil then return 1 + math.floor((q - 1) / 12) end
            end
            if he ~= nil then
                local q = self:plannedHarvestAbs(fruitIndex, he)
                if q ~= nil then return math.max(1, math.floor((q - 1) / 12)) end
            end
        end
    end
    local ftC = curIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(curIndex) or nil
    local sesF = ftF ~= nil and self:parseSeason(ftF) or nil
    local sesC = ftC ~= nil and self:parseSeason(ftC) or nil
    if cur == nil or sesF == nil or sesC == nil then return 1 end
    -- Ende des Erntefensters der aktuellen Frucht (erstes Fenster, das noch nicht vorbei ist)
    local he, start = nil, nil
    for p = 1, 13 do
        if p <= 12 and sesC.harvest[p] then
            if start == nil then start = p end
        elseif start ~= nil then
            if p - 1 >= cur then he = p - 1 break end
            start = nil
        end
    end
    if he == nil then return 1 end
    local sowP, sowOff = nil, 0
    for p = he, 12 do
        if sesF.plant[p] then sowP = p break end
    end
    if sowP == nil then
        for p = 1, 12 do
            if sesF.plant[p] then sowP = p sowOff = 1 break end
        end
    end
    if sowP == nil then return 1 end
    local harvestAfter = false
    for p = sowP + 1, 12 do
        if sesF.harvest[p] then harvestAfter = true break end
    end
    return math.max(1, harvestAfter and sowOff or (sowOff + 1))
end

-- Simuliert das Wachstum mit den Übergangstabellen der Karte (Ruhemonate inklusive).
-- ab: Periode, in der die Frucht in der Stufe "state" steht (1 = März). Rückgabe: absolute Periode (1-12 = dieses Jahr,
-- 13-24 = nächstes Jahr, 25-36 = in 2 Jahren) der ersten möglichen Ernte oder nil.
function FieldListHUD:simHarvestAbs(ft, ses, fromPeriod, state, checkNow)
    if ft == nil or ses == nil or ses.map == nil or state == nil then return nil end
    local minS, maxS = ft.minHarvestingGrowthState, ft.maxHarvestingGrowthState
    if minS == nil or maxS == nil then return nil end
    minS = FieldListHUD.harvestMinState(ft)
    local s = state
    if checkNow and s >= minS and s <= maxS and ses.harvest[fromPeriod] then return fromPeriod end
    for k = 1, 36 do
        local qa = fromPeriod + k
        local p = ((qa - 1) % 12) + 1
        local m = ses.map[p]
        if m ~= nil and m[s] ~= nil then s = m[s] end
        if s >= minS and s <= maxS and ses.harvest[p] then return qa end
    end
    return nil
end

-- Erntezeitpunkt einer Folgefrucht, wenn sie ab der Periode "ab" gesät wird (erste Saatperiode ab dort, sonst im nächsten Jahr)
function FieldListHUD:plannedHarvestAbs(fruitIndex, ab)
    local ft = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
    local ses = ft ~= nil and self:parseSeason(ft) or nil
    if ses == nil or ses.map == nil then return nil end
    local ps = nil
    for p = ab, 12 do
        if ses.plant[p] then ps = p break end
    end
    if ps == nil then
        for p = 1, 12 do
            if ses.plant[p] then ps = p + 12 break end
        end
    end
    if ps == nil then return nil end
    return self:simHarvestAbs(ft, ses, ps, 1, false), ps
end

function FieldListHUD:getHarvestOffset(fruitIndex, kind, state)
    local cur = self:getCurrentPeriod()
    local ft = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
    local ses = ft ~= nil and self:parseSeason(ft) or nil
    -- Mit Übergangstabellen: genau simulieren (Ruhemonate, Saatzeitpunkt, Wachstumsstufe)
    if cur ~= nil and ses ~= nil and ses.map ~= nil then
        local q
        if kind == "standing" and state ~= nil then
            q = self:simHarvestAbs(ft, ses, cur, state, true)
        elseif kind == "sow" then
            q = self:plannedHarvestAbs(fruitIndex, cur)
        end
        if q ~= nil then return math.floor((q - 1) / 12) end
    end
    if cur == nil or ses == nil then
        return 0
    end
    if kind == "standing" then
        for p = cur, 12 do
            if ses.harvest[p] then return 0 end
        end
        for p = 1, cur - 1 do
            if ses.harvest[p] then return 1 end
        end
        return 0
    end
    local sowP, sowOff = nil, 0
    for p = cur, 12 do
        if ses.plant[p] then sowP = p break end
    end
    if sowP == nil then
        for p = 1, cur - 1 do
            if ses.plant[p] then sowP = p sowOff = 1 break end
        end
    end
    if sowP == nil then
        return 0
    end
    for p = sowP + 1, 12 do
        if ses.harvest[p] then return sowOff end
    end
    return sowOff + 1
end

-- Liefert eine nach Fruchttitel sortierte Liste { name, now, nextYear }
-- Welches Stroh liefert die Frucht? Name des Füllstoffs (z. B. STRAW, Hülsenfrucht-Stroh der Karte) oder nil (kein Stroh, z. B. Hanf-/Gras-Schwad)
-- Sucht den Füllstoff "Hülsenfrucht-Stroh" (Name mit STRAW, Titel mit Hülsenfrucht/Legume/Pulse)
-- Strohsorte (STRAW, Hülsenfrucht-Stroh): Name enthält STRAW, aber keine Pellets und keine Erdbeeren (STRAWBERRY)
function FieldListHUD.isStrawFillName(n)
    n = string.upper(n or "")
    return string.find(n, "STRAW", 1, true) ~= nil and not string.find(n, "PELLET", 1, true)
        and not string.find(n, "STRAWBERRY", 1, true)
end

function FieldListHUD.findLegumeStraw()
    if FieldListHUD.legumeStraw ~= nil then
        return FieldListHUD.legumeStraw ~= false and FieldListHUD.legumeStraw or nil
    end
    local found = false
    local fts = g_fillTypeManager ~= nil and (g_fillTypeManager.fillTypes or g_fillTypeManager.indexToFillType) or {}
    for _, ftl in pairs(fts) do
        local n = ftl.name and string.upper(ftl.name) or ""
        local t = string.lower(ftl.title or "")
        if n ~= "STRAW" and FieldListHUD.isStrawFillName(n)
            and (string.find(t, "hülsen", 1, true) or string.find(t, "huelsen", 1, true) or string.find(t, "legume", 1, true)
                or string.find(t, "pulse", 1, true) or string.find(n, "LEGUM", 1, true) or string.find(n, "PULSE", 1, true)
                or string.find(n, "PEA", 1, true) or string.find(n, "BEAN", 1, true)) then
            found = n
            break
        end
    end
    FieldListHUD.legumeStraw = found
    return found ~= false and found or nil
end

function FieldListHUD:getFruitStrawFill(fruitIndex)
    self.strawFillCache = self.strawFillCache or {}
    local c = self.strawFillCache[fruitIndex]
    if c ~= nil then return c ~= false and c or nil end
    local ft = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
    local res = false
    if ft ~= nil and ft.windrowLiterPerSqm ~= nil and ft.windrowLiterPerSqm > 0 then
        local name = ft.windrowName
        if name == nil then
            local ok, idx = pcall(function() return g_fruitTypeManager:getWindrowFillTypeIndexByFruitTypeIndex(fruitIndex) end)
            if ok and idx ~= nil then name = g_fillTypeManager:getFillTypeNameByIndex(idx) end
        end
        if name == nil then
            -- kein Schwadtyp hinterlegt: nur bekannte Strohfrüchte (Getreide, Hirse) zählen, z. B. Raps nicht
            local STRAW_FRUITS = { WHEAT = true, BARLEY = true, OAT = true, TRITICALE = true, SORGHUM = true, RYE = true, SPELT = true }
            local LEGUME_FRUITS = { PEA = true, PEAS = true, GREENBEAN = true, BEANS = true, SOYBEAN = true, LENTILS = true }
            local un = string.upper(ft.name or "")
            if STRAW_FRUITS[un] then
                res = "STRAW"
            elseif LEGUME_FRUITS[un] then
                -- Hülsenfrucht-Stroh: Füllstoff der Karte/des Spiels über Name oder Titel suchen
                res = FieldListHUD.findLegumeStraw() or false
            end
        else
            name = string.upper(name)
            if FieldListHUD.isStrawFillName(name) then res = name end
        end
    end
    self.strawFillCache[fruitIndex] = res
    return res ~= false and res or nil
end

function FieldListHUD:getFruitStraw(fruitIndex, areaHa)
    local ft = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
    if ft == nil or ft.windrowLiterPerSqm == nil or ft.windrowLiterPerSqm <= 0 then
        return 0
    end
    return ft.windrowLiterPerSqm * (areaHa or 0) * 10000
end

-- Tiererzeugnis = Ware aus der Marktgruppe "animalProduct" (Rohprodukte wie Milch, Eier, Wolle).
-- Verarbeitete Waren (z. B. abgefüllte Milch) stehen in der Gruppe "processedGoods".
function FieldListHUD.isAnimalFill(name)
    if name == nil or g_fillTypeManager == nil then
        return false
    end
    name = string.upper(name)
    local ft = g_fillTypeManager:getFillTypeByName(name)
    if ft ~= nil and ft.dynamicMarketGroup ~= nil then
        return ft.dynamicMarketGroup == "animalProduct"
    end
    return false
end

-- Jahresbedarf der aktiven Produktionen an Ackerfrüchten: { [fruchtname] = liter }
function FieldListHUD:getProductionDemand()
    local result = {}
    local fillResult = {}
    local windrowResult = {}
    local strawResult = {}
    local silageResult = { need = 0, out = 0 }
    local ok, err = pcall(function()
        local mission = g_currentMission
        local pcm = mission ~= nil and mission.productionChainManager or nil
        if pcm == nil then
            return
        end
        local farmId = mission:getFarmId()
        local points = pcm:getProductionPointsForFarmId(farmId) or {}
        for _, pp in pairs(points) do
            local active = pp.activeProductions or {}
            local ppLabel = tostring(pp.getName ~= nil and pp:getName() or "?")
            for _, prod in pairs(active) do
                -- Reine Lager-Rezepte (Ballenlager, Zentrallager: Eingang = Ausgang) sind kein Bedarf
                local passThrough = string.find(ppLabel, "Ballenlager", 1, true) ~= nil
                    or string.find(ppLabel, "Zentrallager", 1, true) ~= nil
                for _, o in pairs(prod.outputs or {}) do
                    for _, i in pairs(prod.inputs or {}) do
                        if o.type ~= nil and o.type == i.type then
                            passThrough = true
                        end
                    end
                end
                local perYear = nil
                if passThrough then
                    perYear = nil
                else
                    if prod.cyclesPerMonth ~= nil then
                        perYear = prod.cyclesPerMonth * 12
                    elseif prod.cyclesPerHour ~= nil then
                        local days = (mission.environment ~= nil and mission.environment.daysPerPeriod) or 1
                        perYear = prod.cyclesPerHour * 24 * days * 12
                    end
                end
                -- Silage/Häckselgut: Bedarf der aktiven Produktionen und Silage, die sie selbst herstellen (z. B. Fermenter)
                if perYear ~= nil then
                    for _, o in pairs(prod.outputs or {}) do
                        if o.type ~= nil and o.amount ~= nil and g_fillTypeManager:getFillTypeNameByIndex(o.type) == "SILAGE" then
                            silageResult.out = silageResult.out + o.amount * perYear
                        end
                    end
                    for _, i in pairs(prod.inputs or {}) do
                        local inName = i.type ~= nil and g_fillTypeManager:getFillTypeNameByIndex(i.type) or nil
                        if (inName == "SILAGE" or inName == "CHAFF") and i.amount ~= nil then
                            silageResult.need = silageResult.need + i.amount * perYear
                        end
                    end
                end
                for _, input in pairs(prod.inputs or {}) do
                    local fti = input.type
                    local ftIdx = fti ~= nil and g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(fti) or nil
                    local ft = ftIdx ~= nil and g_fruitTypeManager:getFruitTypeByIndex(ftIdx) or nil
                    local fill = fti ~= nil and g_fillTypeManager:getFillTypeNameByIndex(fti) or "?"
                    -- Strohsorten haben eine eigene Zeile (Stroh-Bereich), keine zweite Fruchtzeile daraus
                    if FieldListHUD.isStrawFillName(fill) then
                        ft = nil; ftIdx = nil
                        if perYear ~= nil and input.amount ~= nil then
                            strawResult[string.upper(fill)] = (strawResult[string.upper(fill)] or 0) + input.amount * perYear
                        end
                    end
                    local ownFill = ft ~= nil and ft.fillType ~= nil and ft.fillType.index or nil
                    local isCutFruit = ft ~= nil and (FieldListHUD.MULTI_CUT[string.upper(ft.name)]
                        or FieldListHUD.CUT_CROPS[string.upper(ft.name)])
                    if isCutFruit and perYear ~= nil and input.amount ~= nil then
                        -- Schnittfrüchte (Gras, Klee, Luzerne): Frischware und Schwad/Heu zählen zur selben Zeile
                        local n = string.upper(ft.name)
                        if n == "MEADOW" then n = "GRASS" end
                        result[n] = (result[n] or 0) + input.amount * perYear
                    elseif ft ~= nil and perYear ~= nil and input.amount ~= nil and ownFill ~= nil and fti ~= ownFill then
                        -- Schwad-Ware (z. B. Flachsschwad, Hanfschwad): eigene Zeile, nicht dem Korn zuschlagen
                        local w = windrowResult[fill]
                        if w == nil then
                            w = { fruit = string.upper(ft.name), liters = 0 }
                            windrowResult[fill] = w
                        end
                        w.liters = w.liters + input.amount * perYear
                    elseif ft ~= nil and perYear ~= nil and input.amount ~= nil then
                        local n = string.upper(ft.name)
                        result[n] = (result[n] or 0) + input.amount * perYear
                    elseif ft == nil and perYear ~= nil and input.amount ~= nil
                        and FieldListHUD.isAnimalFill(fill) then
                        fillResult[fill] = (fillResult[fill] or 0) + input.amount * perYear
                    end
                end
            end
        end
    end)
    if not ok and not self.prodErrLogged then
        self.prodErrLogged = true
        print("FieldListHUD: Produktionsbedarf konnte nicht ermittelt werden: " .. tostring(err))
    end
    return result, fillResult, windrowResult, strawResult, silageResult
end

-- Tiererzeugnisse (Milch, Ziegenmilch, Wolle) der Ställe, hochgerechnet auf ein Jahr: { [fülltypname] = liter }
-- Die Feldnamen der Stall-Daten sind nicht sicher bekannt; die Debug-Zeilen im Log zeigen, was gefunden wird.
function FieldListHUD:getAnimalProductsBySpecs()
    local result = {}
    local ok, err = pcall(function()
        local mission = g_currentMission
        local hs = mission ~= nil and mission.husbandrySystem or nil
        if hs == nil then
            return
        end
        local farmId = mission:getFarmId()
        local days = (mission.environment ~= nil and mission.environment.daysPerPeriod) or 1
        for _, pl in pairs(hs.placeables or {}) do
            if pl.getOwnerFarmId == nil or pl:getOwnerFarmId() == farmId then
                local plName = tostring(pl.getName ~= nil and pl:getName() or "?")
                local specNames = {}
                for k, v in pairs(pl) do
                    if type(k) == "string" and string.sub(k, 1, 14) == "spec_husbandry" and type(v) == "table"
                        and k ~= "spec_husbandryAnimals" then
                        table.insert(specNames, k)
                    end
                end
                table.sort(specNames)
                for _, specName in ipairs(specNames) do
                    local sp = pl[specName]
                    if sp ~= nil then
                        local fti = sp.fillType or sp.fillTypeIndex or sp.palletFillType
                        local lph = sp.litersPerHour
                        if lph == nil and sp.litersPerSecond ~= nil then
                            lph = sp.litersPerSecond * 3600
                        end
                        local fname = fti ~= nil and g_fillTypeManager:getFillTypeNameByIndex(fti) or nil
                        if type(lph) == "table" then
                            -- Tabelle { [fülltypindex] = liter pro Stunde }
                            for k, v in pairs(lph) do
                                local n = type(k) == "number" and g_fillTypeManager:getFillTypeNameByIndex(k) or tostring(k)
                                if type(v) == "number" and FieldListHUD.isAnimalFill(n) then
                                    result[n] = (result[n] or 0) + v * 24 * days * 12
                                end
                            end
                        elseif fname ~= nil and type(lph) == "number" and FieldListHUD.isAnimalFill(fname) then
                            result[fname] = (result[fname] or 0) + lph * 24 * days * 12
                        end
                    end
                end
            end
        end
    end)
    if not ok and not self.animalErrLogged then
        self.animalErrLogged = true
        print("FieldListHUD: Tiererzeugnisse konnten nicht ermittelt werden: " .. tostring(err))
    end
    return result
end

-- Schnitte pro Jahr einer Schnittfrucht (Gras, Klee, Luzerne): Wachstum über die Saisondaten durchspielen
-- (nach jedem Schnitt Neustart bei firstRegrowthState; geschnitten wird, sobald die Periode erntbar ist und der Stand reicht)
-- Abstand zwischen zwei Schnitten in Perioden (Erfahrungswert des Spielers: alle 4 Monate)
FieldListHUD.CUT_INTERVAL = 4

function FieldListHUD:getCutsPerYear(fruitIndex)
    self.cutsCache = self.cutsCache or {}
    local c = self.cutsCache[fruitIndex]
    if c ~= nil then
        return c or nil
    end
    local result = false
    local ft = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
    -- Ackergras, Kleegras und Luzerne werden meist nach dem ersten Jahr umgebrochen: nur 1 Schnitt rechnen
    local ftn = ft ~= nil and string.upper(ft.name or "") or ""
    if ftn == "FIELDGRASS" or ftn == "CLOVER" or ftn == "ALFALFA" then
        self.cutsCache[fruitIndex] = 1
        return 1
    end
    local ok, err = pcall(function()
        local data = ft ~= nil and ft.growthDataSeasonal or nil
        local periods = type(data) == "table" and data.periods or nil
        if type(periods) ~= "table" then return end
                local maxS = math.max(ft.maxForageGrowthState or 0, ft.maxHarvestingGrowthState or 0)
        local minS = maxS -- geschnitten wird erst bei vollem Wachstum (z. B. 4 von 4)
        if minS == 99 or maxS == 0 then return end
        local first = ft.firstRegrowthState or 1
        for per = 1, 12 do
            local pd = periods[per]
            if type(pd) == "table" then
                local m = {}
                if type(pd.growthMapping) == "table" then
                    for k = 1, maxS do m[#m + 1] = tostring(pd.growthMapping[k]) end
                end
            end
        end
        -- Wachstumsperioden: erntbare Perioden, in denen der Bestand wirklich weiterwächst (Mapping ändert einen Stand)
        local grow = 0
        for per = 1, 12 do
            local pd = periods[per]
            local gm = type(pd) == "table" and pd.growthMapping or nil
            if type(gm) == "table" and truthy(pd.isHarvestable) then
                for k = 1, maxS do
                    if gm[k] ~= nil and gm[k] ~= k then grow = grow + 1 break end
                end
            end
        end
        -- Ein Schnitt braucht erfahrungsgemäß CUT_INTERVAL Perioden bis zum vollen Wachstum
        local n = math.floor(grow / FieldListHUD.CUT_INTERVAL)
        if n > 0 then result = n end
    end)
    if not ok then
        print("FieldListHUD: Schnitte pro Jahr nicht ermittelbar: " .. tostring(err))
    end
    self.cutsCache[fruitIndex] = result
    return result or nil
end

function FieldListHUD:collectFruitTotals()
    local strawMap = {} -- [Füllstoffname] = { now, nextYear, fields }
    local map = {}
    -- Zeilen werden nach angezeigtem Namen zusammengefasst (z. B. Gras und Wiese heißen beide "Gras")
    -- Sommerformen zählen für Produktionen wie die Winterform (z. B. Sommerweizen -> Weizen): eine gemeinsame Zeile
    local SUMMER_ALIAS = FieldListHUD.FRUIT_ALIAS
    local function slot(name)
        -- Ackergras liefert Gras (Schwad, Faktor 1) und wird in der Tabelle unter Gras geführt
        name = SUMMER_ALIAS[name] or name
        local en = self:getEntryByFruitName(name)
        local title = en ~= nil and en.fruitTitle or nil
        if title == nil then
            local ftn = g_fruitTypeManager:getFruitTypeByName(name)
            title = (ftn ~= nil and ftn.fillType ~= nil and ftn.fillType.title) or name
        end
        local key = title
        local r = map[key]
        if r == nil then
            r = { name = name, now = 0, planned = 0, nextYear = 0, in2 = 0, demand = 0, title = title }
            map[key] = r
        end
        if FieldListHUD.MULTI_CUT[name] then
            r.multiCut = true
        end
        return r
    end
    local silSlot = { name = "MAIZE", now = 0, planned = 0, nextYear = 0, in2 = 0, demand = 0, fields = {} }
    local function S(name, isSil)
        if isSil and name == "MAIZE" then return silSlot end
        return slot(name)
    end
    local fruitDemand, fillDemand, windrowDemand, strawDemand, silageInfo = self:getProductionDemand()
    silageInfo = silageInfo or { need = 0, out = 0 }
    strawDemand = strawDemand or {}
    -- Schwad-Zeilen (nur wenn eine Produktion die Ware verbraucht), nach Fruchtname gesammelt
    local wrByFruit, wrRows = {}, {}
    for fillName, w in pairs(windrowDemand or {}) do
        local ftl = g_fillTypeManager:getFillTypeByName(fillName)
        local r = { name = w.fruit, windrow = fillName, isWindrow = true, now = 0, planned = 0, nextYear = 0, in2 = 0,
            demand = w.liters, title = (ftl ~= nil and ftl.title) or fillName,
            iconFilename = ftl ~= nil and ftl.hudOverlayFilename or nil }
        wrByFruit[w.fruit] = wrByFruit[w.fruit] or {}
        table.insert(wrByFruit[w.fruit], r)
        table.insert(wrRows, r)
    end
    local function windrowLiters(fruitIndex, areaHa, pct)
        local ft = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
        if ft == nil then return 0 end
        return (ft.windrowLiterPerSqm or 0) * (areaHa or 0) * 10000 * (1 + (pct or 0) / 100)
    end
    -- Flächengewichteter Ertragsprozent je Zeile (für die benötigte Fläche)
    -- ctx: aktuelles Feld und Frucht, damit jede Menge dem Feld zugeordnet werden kann (für das Detailfenster)
    local ctx = { e = nil, fruit = nil, kind = "n", off = nil }
    local function acc(r, areaHa, pct)
        r.pctW = (r.pctW or 0) + (areaHa or 0) * pct
        r.areaW = (r.areaW or 0) + (areaHa or 0)
        r.fields = r.fields or {}
        local d1 = r.now - (r._pn or 0)
        local d2 = r.planned - (r._pp or 0)
        r._pn, r._pp = r.now, r.planned
        if ctx.e ~= nil then
            if d1 ~= 0 then
                table.insert(r.fields, { id = ctx.e.id, fruit = ctx.fruit, area = areaHa, pct = pct, liters = d1, kind = "n", mode = "this" })
            end
            if d2 ~= 0 then
                table.insert(r.fields, { id = ctx.e.id, fruit = ctx.fruit, area = areaHa, pct = pct, liters = d2, kind = "n1", mode = "this" })
            end
        end
    end
    local function accI(r, areaHa, pct)
        r.pctI = (r.pctI or 0) + (areaHa or 0) * pct
        r.areaI = (r.areaI or 0) + (areaHa or 0)
        r.fields = r.fields or {}
        local d = (r.in2 or 0) - (r._pi2 or 0)
        r._pi2 = r.in2 or 0
        if ctx.e ~= nil and d ~= 0 then
            table.insert(r.fields, { id = ctx.e.id, fruit = ctx.fruit, area = areaHa, pct = pct, liters = d, kind = ctx.kind, mode = "in2" })
        end
    end
    local function accN(r, areaHa, pct)
        r.pctN = (r.pctN or 0) + (areaHa or 0) * pct
        r.areaN = (r.areaN or 0) + (areaHa or 0)
        r.fields = r.fields or {}
        local d = r.nextYear - (r._pnx or 0)
        r._pnx = r.nextYear
        if ctx.e ~= nil and d ~= 0 then
            table.insert(r.fields, { id = ctx.e.id, fruit = ctx.fruit, area = areaHa, pct = pct, liters = d, kind = ctx.kind, mode = "next" })
        end
    end
    -- Stroh: Beitrag je Feld für das Detailfenster (Menge hängt nur an der Fläche, daher ohne Ertragsprozent)
    local function strawAdd(fruitIndex, areaHa, mode, kind)
        local fill = self:getFruitStrawFill(fruitIndex)
        if fill == nil then return end
        local l = self:getFruitStraw(fruitIndex, areaHa)
        if l <= 0 then return end
        local r = strawMap[fill]
        if r == nil then r = { now = 0, nextYear = 0, in2 = 0, fields = {} }; strawMap[fill] = r end
        if mode == "this" then r.now = r.now + l elseif mode == "in2" then r.in2 = r.in2 + l else r.nextYear = r.nextYear + l end
        if ctx.e ~= nil then
            table.insert(r.fields, { id = ctx.e.id, fruit = ctx.fruit, area = areaHa, pct = nil, liters = l, kind = kind, mode = mode })
        end
    end
    -- Ackergras wird gedroschen (Samen in der eigenen Zeile); der Schwad hinter dem Drescher zählt als Gras.
    -- Menge: Schwad-Liter je m2 aus den Spieldaten x Ertragsfaktor x Praxisabschlag (gemessen ca. 75 %).
    -- Die Gras-Zeile steht "pro Schnitt" und wird später mit der Schnittzahl multipliziert, der Schwad fällt aber
    -- nur einmal an: darum hier durch die Schnittzahl teilen.
    local function ackerSchwad(fruitName, fruitIdx, areaHa, pct, mode)
        if fruitName ~= "FIELDGRASS" then return end
        local gt = g_fruitTypeManager:getFruitTypeByName("GRASS")
        local ft = fruitIdx ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIdx) or nil
        if gt == nil or ft == nil then return end
        local perSqm = ft.windrowLiterPerSqm or 0
        if perSqm <= 0 then perSqm = 3 end
        local cuts = self:getCutsPerYear(gt.index) or 1
        if cuts < 1 then cuts = 1 end
        local l = perSqm * areaHa * 10000 * (1 + pct / 100) * FieldListHUD.SCHWAD_PRACTICE / cuts
        local r = slot("GRASS")
        if mode == "now" then
            r.now = r.now + l
            acc(r, areaHa, pct)
        elseif mode == "planned" then
            r.planned = r.planned + l
            acc(r, areaHa, pct)
        elseif mode == "in2" then
            r.in2 = r.in2 + l
            accI(r, areaHa, pct)
        else
            r.nextYear = r.nextYear + l
            accN(r, areaHa, pct)
        end
    end
    for _, e in ipairs(self.fields or {}) do
        local rec = self:getRecord(e.id)
        ctx.e = e
        ctx.off = nil
        if not rec.unused then
            local pct = self:getYieldPercent(e, true) or 0
            -- Dieses Jahr: aktuelle Frucht (auch von Hand gesetzte), solange nicht abgeerntet
            local ov, ovIndex = self:getCurrentOverride(e)
            local curIndex, curName = nil, nil
            if ov ~= nil then
                curIndex, curName = ovIndex, string.upper(rec.cur or "")
            elseif e.fruitIndex ~= nil and e.growthState ~= nil and e.growthState >= 1
                and (e.maxGrowth == nil or e.growthState <= e.maxGrowth
                    or FieldListHUD.MULTI_CUT[string.upper(e.fruitName or "")]) then
                -- Mehrschnittfrüchte wachsen nach dem Schnitt (5/4, 6/4) weiter und zählen weiter als stehend
                curIndex, curName = e.fruitIndex, string.upper(e.fruitName or "")
            end
            -- Zwischenfrüchte (Gründüngung) sind keine Ernte: Feld gilt als leer
            if curIndex ~= nil and FieldListHUD.isCatchCrop(curName) then
                curIndex, curName = nil, nil
            end
            -- Zuordnung nach Erntezeitpunkt: Offset 0 = Ernte noch in diesem Jahr, 1 = nach dem Jahreswechsel
            local curOff = nil
            -- Wiese ist Weidefläche für Tiere und wird nicht gemäht: nicht in der Übersicht
            if curIndex ~= nil and curName ~= "" and curName ~= "MEADOW" then
                curOff = (FieldListHUD.MULTI_CUT[curName] and 0) or self:getHarvestOffset(curIndex, "standing", (ov == nil) and e.growthState or nil)
                ctx.fruit, ctx.kind = curName, "n"
                -- Fruchtfolge-Faktor der aktuellen Frucht (gegen ihre Vorfrucht); Schnittfrüchte ohne Faktor
                local rfCur = 1
                if not FieldListHUD.MULTI_CUT[curName] and FieldListHUD.rotYield == true then
                    local crt = self:getCurrentRating(e)
                    if crt ~= nil and crt.factor ~= nil then rfCur = crt.factor / 100 end
                end
                local pcur = (100 + pct) * rfCur - 100
                if curOff == 0 then
                    S(curName, rec.curSilage).now = S(curName, rec.curSilage).now + self:getFruitLiters(curIndex, e.area, pcur)
                    acc(S(curName, rec.curSilage), e.area, pcur)
                    ackerSchwad(curName, curIndex, e.area, pcur, "now")
                    for _, wr in ipairs(wrByFruit[curName] or {}) do
                        wr.now = wr.now + windrowLiters(curIndex, e.area, pcur)
                        acc(wr, e.area, pcur)
                    end
                    strawAdd(curIndex, e.area, "this", "n")
                    -- Mehrschnittige Früchte (Gras, Klee, Luzerne) stehen auch im nächsten Jahr, solange keine andere Folgefrucht geplant ist
                    if FieldListHUD.MULTI_CUT[curName] and rec.next == nil then
                        local rN = slot(curName)
                        local pbN = FieldListHUD.PLAN_BONUS
                        rN.nextYear = rN.nextYear + self:getFruitLiters(curIndex, e.area, pbN)
                        accN(rN, e.area, pbN)
                        ackerSchwad(curName, curIndex, e.area, pbN, "next")
                        for _, wr in ipairs(wrByFruit[curName] or {}) do
                            wr.nextYear = wr.nextYear + windrowLiters(curIndex, e.area, pbN)
                            accN(wr, e.area, pbN)
                        end
                    end
                else
                    -- z. B. Wintergetreide, das schon steht: wird erst nach dem Jahreswechsel geerntet
                    local r = S(curName, rec.curSilage)
                    local pb = (100 + FieldListHUD.PLAN_BONUS) * rfCur - 100
                    r.nextYear = r.nextYear + self:getFruitLiters(curIndex, e.area, pb)
                    accN(r, e.area, pb)
                    ackerSchwad(curName, curIndex, e.area, pb, "next")
                    for _, wr in ipairs(wrByFruit[curName] or {}) do
                        wr.nextYear = wr.nextYear + windrowLiters(curIndex, e.area, pb)
                        accN(wr, e.area, pb)
                    end
                    strawAdd(curIndex, e.area, "next", "n")
                end
            end
            -- Folgefrucht N+1: Erntejahr hängt davon ab, wann sie gesät und geerntet wird
            if rec.next ~= nil and string.upper(rec.next) ~= "MEADOW" then
                local nName = string.upper(rec.next)
                local fp = g_fruitTypeManager:getFruitTypeByName(rec.next)
                if fp ~= nil then
                    ctx.fruit, ctx.kind, ctx.off = nName, "n1", nil
                    local nOff
                    if FieldListHUD.MULTI_CUT[nName] then
                        nOff = (curIndex == nil) and 0 or 1
                    elseif curIndex == nil then
                        nOff = self:getHarvestOffset(fp.index, "sow")   -- leeres Feld: Aussaat ab jetzt
                    elseif curOff == 0 then
                        nOff = self:getFolgeOffset(fp.index, curIndex)  -- erst nach der Ernte; passt kein Saatfenster mehr ins Jahr: Ernte in 2 Jahren
                    else
                        nOff = 2                                         -- Feld trägt noch bis ins nächste Jahr
                    end
                    local rf = self:getRotationFactor(rec, nName)
                    if nOff == 0 then
                        local pe = (100 + pct) * rf - 100
                        local rp = S(nName, rec.silage)
                        rp.planned = rp.planned + self:getFruitLiters(fp.index, e.area, pe)
                        acc(rp, e.area, pe)
                        ackerSchwad(nName, fp.index, e.area, pe, "planned")
                        for _, wr in ipairs(wrByFruit[nName] or {}) do
                            wr.planned = wr.planned + windrowLiters(fp.index, e.area, pe)
                            acc(wr, e.area, pe)
                        end
                    end
                    -- Mehrschnittige Früchte zählen weiter auch im Planungsjahr
                    -- Ernte in 2 Jahren: eigener Reiter
                    if nOff == 2 then
                        local r = S(nName, rec.silage)
                        local pb = (100 + FieldListHUD.PLAN_BONUS) * rf - 100
                        r.in2 = r.in2 + self:getFruitLiters(fp.index, e.area, pb)
                        accI(r, e.area, pb)
                        ackerSchwad(nName, fp.index, e.area, pb, "in2")
                        for _, wr in ipairs(wrByFruit[nName] or {}) do
                            wr.in2 = wr.in2 + windrowLiters(fp.index, e.area, pb)
                            accI(wr, e.area, pb)
                        end
                        strawAdd(fp.index, e.area, "in2", ctx.kind)
                    end
                    if nOff == 1 or (FieldListHUD.MULTI_CUT[nName] and nOff == 0) then
                        local r = S(nName, rec.silage)
                        local pb = (100 + FieldListHUD.PLAN_BONUS) * rf - 100
                        r.nextYear = r.nextYear + self:getFruitLiters(fp.index, e.area, pb)
                        accN(r, e.area, pb)
                        ackerSchwad(nName, fp.index, e.area, pb, "next")
                        for _, wr in ipairs(wrByFruit[nName] or {}) do
                            wr.nextYear = wr.nextYear + windrowLiters(fp.index, e.area, pb)
                            accN(wr, e.area, pb)
                        end
                        strawAdd(fp.index, e.area, "next", ctx.kind)
                    end
                end
            end
        end
    end
    self.fillDemand = fillDemand
    for name, liters in pairs(fruitDemand) do
        if name ~= "MEADOW" and liters > 0 then
            slot(name).demand = slot(name).demand + liters
        end
    end
    local list = {}
    for _, r in pairs(map) do
        local en = self:getEntryByFruitName(r.name)
        r.title = r.title or (en ~= nil and en.fruitTitle) or r.name
        if r.multiCut or FieldListHUD.MULTI_CUT[r.name] then
            local ftc = g_fruitTypeManager:getFruitTypeByName(r.name)
            r.cuts = ftc ~= nil and self:getCutsPerYear(ftc.index) or nil
            -- Alle Mengen der Zeile gelten fürs ganze Jahr (Schnitte x Ertrag je Schnitt)
            if r.cuts ~= nil and r.cuts > 1 then
                r.now, r.planned = r.now * r.cuts, r.planned * r.cuts
                r.nextYear, r.in2 = r.nextYear * r.cuts, r.in2 * r.cuts
                for _, fd in ipairs(r.fields or {}) do
                    if fd.liters ~= nil then fd.liters = fd.liters * r.cuts end
                end
            end
            if r.cuts ~= nil then r.yearly = true end
        end
        table.insert(list, r)
    end
    for _, r in ipairs(wrRows) do
        table.insert(list, r)
    end
    table.sort(list, function(a, b) return a.title < b.title end)
    -- Stroh (und Stroh-Sorten der Karte, z. B. Hülsenfrucht-Stroh) als zusätzliche Zeilen am Ende
    -- Strohsorten der Karte, die nur im Lager/Eingang liegen (kein Feld liefert sie): ebenfalls anzeigen, damit der Bestand sichtbar ist
    pcall(function()
        local stock = self:getStock() or {}
        local inp = self:getInputStock()
        local fts = g_fillTypeManager ~= nil and (g_fillTypeManager.fillTypes or g_fillTypeManager.indexToFillType) or {}
        for fti, ftl in pairs(fts) do
            local name = ftl.name and string.upper(ftl.name) or nil
            if name ~= nil and FieldListHUD.isStrawFillName(name)
                and strawMap[name] == nil and ((stock[ftl.index or fti] or 0) > 0 or (inp.fill[name] or 0) > 0) then
                strawMap[name] = { now = 0, nextYear = 0, in2 = 0, fields = {}, stockOnly = true }
            end
        end
        self.strawLogged = true
    end)
    for fill, l in pairs(strawDemand) do
        if l > 0 and strawMap[fill] == nil then
            strawMap[fill] = { now = 0, nextYear = 0, in2 = 0, fields = {}, stockOnly = true }
        end
    end
    local strawNames = {}
    for fill in pairs(strawMap) do table.insert(strawNames, fill) end
    table.sort(strawNames, function(x, y)
        if x == "STRAW" then return true elseif y == "STRAW" then return false end
        return x < y
    end)
    for _, fill in ipairs(strawNames) do
        local r = strawMap[fill]
        if r.now > 0 or r.nextYear > 0 or r.in2 > 0 or r.stockOnly then
            local ftl = g_fillTypeManager ~= nil and g_fillTypeManager:getFillTypeByName(fill) or nil
            local sumL, sumA = 0, 0
            for _, f in ipairs(r.fields) do sumL = sumL + (f.liters or 0); sumA = sumA + (f.area or 0) end
            local strawPerHa = sumA > 0 and sumL / sumA or 0
            table.insert(list, { name = fill, title = (fill == "STRAW" and T("straw")) or (ftl ~= nil and ftl.title) or fill,
                isStraw = true, strawFill = fill, now = r.now, nextYear = r.nextYear, in2 = r.in2, fields = r.fields,
                demand = strawDemand[fill] or 0, strawPerHa = strawPerHa })
        end
    end
    -- Silage / Häckselgut (Futterpflanzen): Mais als Häckselgut, Bedarf der Produktionen, Lager inkl. Fahrsilos
    pcall(function()
        local mft = g_fruitTypeManager:getFruitTypeByName("MAIZE")
        local f = mft ~= nil and FieldListHUD.getChaffFactor(mft.index) or nil
        local need = math.max(0, (silageInfo.need or 0) - (silageInfo.out or 0))
        local ftl = g_fillTypeManager:getFillTypeByName("SILAGE")
        local probe = { isSilage = true, name = "SILAGE" }
        local stockL = self:getRowStock(probe) or 0
        if need <= 0 and stockL <= 0 and silSlot.now + silSlot.planned + silSlot.nextYear + silSlot.in2 <= 0 then return end
        local row = { name = "SILAGE", isSilage = true, title = T("silage_row"),
            iconFilename = ftl ~= nil and ftl.hudOverlayFilename or nil,
            now = 0, planned = 0, nextYear = 0, in2 = 0, demand = need, fields = {} }
        if f ~= nil then
            row.now = silSlot.now * f
            row.planned = silSlot.planned * f
            row.nextYear = silSlot.nextYear * f
            row.in2 = silSlot.in2 * f
            row.silageBase = ((mft ~= nil and mft.literPerSqm) or 0) * f * 10000
            row.areaW, row.pctW, row.areaN, row.pctN, row.areaI, row.pctI = silSlot.areaW, silSlot.pctW, silSlot.areaN, silSlot.pctN, silSlot.areaI, silSlot.pctI
            for _, fd in ipairs(silSlot.fields or {}) do
                local c = {}
                for k, v in pairs(fd) do c[k] = v end
                if c.liters ~= nil then c.liters = c.liters * f end
                table.insert(row.fields, c)
            end
        end
        table.insert(list, row)
    end)
    return list
end

-- Umrechnung Frucht -> Häckselgut (Feldhäcksler) aus den Spieldaten; nur Mais. Rückfallwert 7,8
function FieldListHUD.getChaffFactor(fruitIndex)
    local ft = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
    if ft == nil or string.upper(ft.name or "") ~= "MAIZE" then return nil end
    local f = nil
    pcall(function()
        local conv = g_fruitTypeManager.nameToConverter ~= nil and g_fruitTypeManager.nameToConverter["FORAGEHARVESTER"] or nil
        local d = conv ~= nil and conv[fruitIndex] or nil
        if d ~= nil then f = d.conversionFactor or d.factor end
    end)
    return (type(f) == "number" and f > 0) and f or 7.8
end

-- Füllstand aller eigenen Fahrsilos (Häckselgut oder Silage; gärendes Häckselgut zählt als Silage)
function FieldListHUD:getBunkerSiloLevel()
    if self.bunkerCache ~= nil and g_time ~= nil and (g_time - (self.bunkerTime or 0)) < 1000 then
        return self.bunkerCache
    end
    local sum = 0
    pcall(function()
        local m = g_currentMission
        local farmId = m:getFarmId()
        for _, pl in pairs(m.placeableSystem ~= nil and m.placeableSystem.placeables or {}) do
            local spec = pl.spec_bunkerSilo
            local bs = spec ~= nil and spec.bunkerSilo or nil
            if bs ~= nil and (pl.getOwnerFarmId == nil or pl:getOwnerFarmId() == farmId) and type(bs.fillLevel) == "number" then
                sum = sum + bs.fillLevel
            end
        end
    end)
    self.bunkerCache, self.bunkerTime = sum, g_time
    return sum
end

function FieldListHUD:getStrawEntry(item)
    local fill = (item ~= nil and item.strawFill) or "STRAW"
    local ftl = g_fillTypeManager ~= nil and g_fillTypeManager:getFillTypeByName(fill) or nil
    return { fruitTitle = (ftl ~= nil and ftl.title) or T("straw"), iconFilename = ftl ~= nil and ftl.hudOverlayFilename or nil }
end

FieldListHUD.MAX_HIST = 6 -- Vorfrüchte N-1 bis N-6
-- Planung Folgejahr: Feld gepflügt (15) + gekalkt (15) + 2x gedüngt (45) + unkrautfrei (20) = 95 % Bonus, also 195 %.
-- Mulchen und Walzen (je 2,5) zählen bewusst nicht mit.
FieldListHUD.PLAN_BONUS_DEFAULT = 15 + 15 + 45 + 20
FieldListHUD.PLAN_BONUS = FieldListHUD.PLAN_BONUS_DEFAULT
FieldListHUD.MULTI_CUT = { GRASS = true, FIELDGRASS = true, ALFALFA = true, CLOVER = true }
FieldListHUD.SCHWAD_PRACTICE = 0.75 -- Ackergras-Schwad: gemessener Anteil am Sollwert der Spieldaten

-- Zeileneintrag der Fruchtübersicht; mehrschnittige Früchte werden als "pro Schnitt" gekennzeichnet
function FieldListHUD:getFruitRowEntry(item)
    if item.isAnimal then
        return { fruitTitle = item.title, iconFilename = item.iconFilename }
    end
    if item.isStraw then
        return self:getStrawEntry(item)
    end
    if item.isSilage then
        return { fruitTitle = item.title, iconFilename = item.iconFilename }
    end
    if item.isWindrow then
        return { fruitTitle = item.title, iconFilename = item.iconFilename }
    end
    local e = self:getEntryByFruitName(item.name)
    if e ~= nil and (item.multiCut or FieldListHUD.MULTI_CUT[item.name]) then
        local copy = {}
        for k, v in pairs(e) do copy[k] = v end
        local suffix = ""
        if item.cuts == nil then suffix = T("per_cut")
        elseif item.cuts > 1 then suffix = string.format(T("per_cut_n"), item.cuts) end
        copy.fruitTitle = e.fruitTitle .. suffix
        return copy
    end
    return e
end

-- Weg 2: Erzeugnisse aus Tierart, Anzahl und Alter der Tiere (Ausgabekurven der Tierdaten).
-- ANNAHME: Die Kurvenwerte gelten pro Tier und Tag.
function FieldListHUD:getAnimalProductsByAnimals()
    local result = {}
    local ok, err = pcall(function()
        local mission = g_currentMission
        local hs = mission ~= nil and mission.husbandrySystem or nil
        local animalSystem = mission ~= nil and mission.animalSystem or nil
        if hs == nil or animalSystem == nil then
            return
        end
        local farmId = mission:getFarmId()
        local daysPerYear = ((mission.environment ~= nil and mission.environment.daysPerPeriod) or 1) * 12
        for _, pl in pairs(hs.placeables or {}) do
            if pl.getOwnerFarmId == nil or pl:getOwnerFarmId() == farmId then
                local plName = tostring(pl.getName ~= nil and pl:getName() or "?")
                local clusters = pl.getClusters ~= nil and pl:getClusters() or nil
                for _, cluster in pairs(clusters or {}) do
                    local num = cluster.numAnimals or 1
                    local age = cluster.age or 0
                    local stIdx = cluster.subTypeIndex or (cluster.getSubTypeIndex ~= nil and cluster:getSubTypeIndex()) or nil
                    local st = stIdx ~= nil and animalSystem:getSubTypeByIndex(stIdx) or nil
                    if st ~= nil and st.output ~= nil then
                        for k, curve in pairs(st.output) do
                            local fname = nil
                            if type(k) == "number" then
                                fname = g_fillTypeManager:getFillTypeNameByIndex(k)
                            elseif type(k) == "string" then
                                fname = string.upper(k)
                            end
                            if FieldListHUD.isAnimalFill(fname) then
                                local perAnimal = nil
                                if type(curve) == "number" then
                                    perAnimal = curve
                                elseif type(curve) == "table" and curve.get ~= nil then
                                    perAnimal = curve:get(age)
                                end
                                if perAnimal ~= nil then
                                    result[fname] = (result[fname] or 0) + perAnimal * num * daysPerYear
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    if not ok and not self.animalErrLogged2 then
        self.animalErrLogged2 = true
        print("FieldListHUD: Tierdaten konnten nicht gelesen werden: " .. tostring(err))
    end
    return result
end

-- Tiererzeugnisse: Weg 1 (Stallwerte) hat Vorrang, fehlende Produkte kommen aus Weg 2 (Tierdaten)
function FieldListHUD:getAnimalProducts()
    local bySpecs = self:getAnimalProductsBySpecs()
    local byAnimals = self:getAnimalProductsByAnimals()
    for name, v in pairs(byAnimals) do
        if bySpecs[name] == nil then
            bySpecs[name] = v
        end
    end
    return bySpecs
end

-- Aktueller Lagerbestand der Farm aus allen Lagern/Silos: { [fülltypindex] = liter } (einmal pro Sekunde neu)
function FieldListHUD:getStock()
    if self.stockCache ~= nil and g_time ~= nil and (g_time - (self.stockTime or 0)) < 1000 then
        return self.stockCache
    end
    local result = {}
    local ok, err = pcall(function()
        local mission = g_currentMission
        local ss = mission ~= nil and mission.storageSystem or nil
        if ss == nil then
            return
        end
        local farmId = mission:getFarmId()
        local storages = ss.getStorages ~= nil and ss:getStorages() or ss.storages or {}
        local seen = {}
        local count, ppCount, palletCount = 0, 0, 0

        local watch = {}
        for _, n in ipairs({ "HEMP", "WHEAT", "MILK", "WOOL", "EGG" }) do
            local i = g_fillTypeManager:getFillTypeIndexByName(n)
            if i ~= nil then watch[i] = n end
        end
        local strawIdx = g_fillTypeManager:getFillTypeIndexByName("STRAW")
        local husb = {}
        for _, pl in pairs((mission.placeableSystem ~= nil and mission.placeableSystem.placeables) or {}) do
            local hs = pl.spec_husbandry
            if hs ~= nil and hs.storage ~= nil then husb[hs.storage] = true end
        end
        local function addStorage(st, source)
            if st == nil or seen[st] then
                return false
            end
            seen[st] = true
            local levels = st.fillLevels
            if levels == nil and st.getFillLevels ~= nil then
                levels = st:getFillLevels()
            end
            for fti, lvl in pairs(levels or {}) do
                if type(lvl) == "number" and lvl > 0 and not (husb[st] and fti == strawIdx) then
                    result[fti] = (result[fti] or 0) + lvl
                end
            end
            return true
        end

        -- Lager und Silos
        for _, st in pairs(storages) do
            local owner = st.getOwnerFarmId ~= nil and st:getOwnerFarmId() or st.ownerFarmId
            if (owner == nil or owner == farmId) and addStorage(st, "storageSystem") then
                count = count + 1
            end
        end

        -- Silos der Gebäude (Lager von Produktionen und Verkaufsstellen zählen bewusst nicht mit)
        local extraCount = 0
        local function ownerOk(obj)
            local owner = obj.getOwnerFarmId ~= nil and obj:getOwnerFarmId() or obj.ownerFarmId
            return owner == farmId
        end
        local function ownStorage(st)
            local owner = st.getOwnerFarmId ~= nil and st:getOwnerFarmId() or st.ownerFarmId
            return owner == farmId
        end
        local psys = mission.placeableSystem
        for _, pl in pairs((psys ~= nil and psys.placeables) or {}) do
            local sp = pl.spec_silo
            if sp ~= nil and ownerOk(pl) then
                local plName = tostring(pl.getName ~= nil and pl:getName() or "?")
                for _, st in pairs(sp.storages or {}) do
                    if ownStorage(st) and addStorage(st, "silo " .. plName) then extraCount = extraCount + 1 end
                end
            end
        end

        -- Produktionen: nur die Ausgangswaren zählen als Bestand (Eingangswaren sind für die Produktion reserviert)
        local pcm = mission.productionChainManager
        if pcm ~= nil then
            for _, pp in pairs(pcm:getProductionPointsForFarmId(farmId) or {}) do
                local st = pp.storage
                if st ~= nil and not seen[st] then
                    seen[st] = true
                    local outs = pp.outputFillTypeIds
                    local ins = pp.inputFillTypeIds
                    local ppName = tostring(pp.getName ~= nil and pp:getName() or "?")
                    local used = false
                    -- Stehende Produktionen (z. B. Ballenlager) dienen nur als Lager: alles zählt
                    local stopped = pp.activeProductions == nil or next(pp.activeProductions) == nil
                    for fti, lvl in pairs(st.fillLevels or {}) do
                        if type(lvl) == "number" and lvl > 0 then
                            local isOut = outs ~= nil and outs[fti] ~= nil
                            local isIn = ins ~= nil and ins[fti] ~= nil
                            if isOut then
                                result[fti] = (result[fti] or 0) + lvl
                                used = true
                            end
                        end
                    end
                    if used then
                        ppCount = ppCount + 1
                    end
                end
            end
        end

        -- Paletten (z. B. Eier, Ziegenmilch, Wolle), die auf dem Hof stehen
        local vs = mission.vehicleSystem
        for _, v in pairs((vs ~= nil and vs.vehicles) or {}) do
            if v.spec_pallet ~= nil and v.getFillUnits ~= nil then
                local owner = v.getOwnerFarmId ~= nil and v:getOwnerFarmId() or v.ownerFarmId
                if owner == nil or owner == farmId then
                    local pc = false
                    for i = 1, #v:getFillUnits() do
                        local fti = v:getFillUnitFillType(i)
                        local lvl = v:getFillUnitFillLevel(i)
                        if fti ~= nil and lvl ~= nil and lvl > 0 then
                            result[fti] = (result[fti] or 0) + lvl
                            pc = true
                        end
                    end
                    if pc then
                        palletCount = palletCount + 1
                    end
                end
            end
        end
    end)
    if not ok and not self.stockErrLogged then
        self.stockErrLogged = true
        print("FieldListHUD: Lagerbestand konnte nicht ermittelt werden: " .. tostring(err))
    end
    self.stockCache = result
    self.stockTime = g_time
    return result
end

-- Eingangswaren der Produktionen (liegen in den Eingangslagern, z. B. Weizen in der Mehlfabrik)
-- Rückgabe: { fruit = { [FRUCHTNAME] = liter }, fill = { [FÜLLTYPNAME] = liter } }
function FieldListHUD:getInputStock()
    if self.inputCache ~= nil and g_time ~= nil and (g_time - (self.inputTime or 0)) < 1000 then
        return self.inputCache
    end
    local res = { fruit = {}, fill = {} }
    local ok, err = pcall(function()
        local mission = g_currentMission
        local pcm = mission ~= nil and mission.productionChainManager or nil
        if pcm == nil then return end
        for _, pp in pairs(pcm:getProductionPointsForFarmId(mission:getFarmId()) or {}) do
            local st = pp.storage
            local outs = pp.outputFillTypeIds or {}
            local ins = pp.inputFillTypeIds or {}
            if st ~= nil then
                for fti, lvl in pairs(st.fillLevels or {}) do
                    if type(lvl) == "number" and lvl > 0 and ins[fti] ~= nil and outs[fti] == nil then
                        local name = g_fillTypeManager:getFillTypeNameByIndex(fti)
                        if name ~= nil then
                            res.fill[name] = (res.fill[name] or 0) + lvl
                        end
                        local fi = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(fti)
                        local ft = fi ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fi) or nil
                        local ownFill = ft ~= nil and ft.fillType ~= nil and ft.fillType.index or nil
                        if ft ~= nil and (ownFill == nil or ownFill == fti or FieldListHUD.MULTI_CUT[string.upper(ft.name)]) then
                            local n = string.upper(ft.name)
                            res.fruit[n] = (res.fruit[n] or 0) + lvl
                        end
                    end
                end
            end
        end
    end)
    if not ok and not self.inputErrLogged then
        self.inputErrLogged = true
        print("FieldListHUD: Eingangsbestand konnte nicht ermittelt werden: " .. tostring(err))
    end
    self.inputCache = res
    self.inputTime = g_time
    return res
end

-- Eingangsbestand einer Zeile der Seite 3 in Litern
function FieldListHUD:getRowInput(item)
    local inp = self:getInputStock()
    if item.isSilage then
        return (inp.fill["SILAGE"] or 0) + (inp.fill["CHAFF"] or 0)
    elseif item.isStraw then
        return inp.fill[item.strawFill or "STRAW"] or 0
    elseif item.isWindrow then
        return inp.fill[item.windrow] or 0
    elseif item.isAnimal then
        return inp.fill[item.name] or 0
    end
    local v = inp.fruit[string.upper(item.name or "")] or 0
    return v
end

-- Lagerbestand einer Zeile der Seite 3 in Litern (nil, wenn die Ware nicht zugeordnet werden kann)
function FieldListHUD:getRowStock(item)
    local idx = nil
    if item.isSilage then
        local st = self:getStock()
        local si = g_fillTypeManager:getFillTypeIndexByName("SILAGE")
        local ci = g_fillTypeManager:getFillTypeIndexByName("CHAFF")
        return (si ~= nil and st[si] or 0) + (ci ~= nil and st[ci] or 0) + self:getBunkerSiloLevel()
    end
    if item.isStraw then
        idx = g_fillTypeManager:getFillTypeIndexByName(item.strawFill or "STRAW")
    elseif item.isWindrow then
        idx = g_fillTypeManager:getFillTypeIndexByName(item.windrow)
    elseif item.isAnimal then
        idx = g_fillTypeManager:getFillTypeIndexByName(item.name)
    else
        local ft = g_fruitTypeManager:getFruitTypeByName(item.name)
        if ft ~= nil then
            idx = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(ft.index)
        end
    end
    if idx == nil then
        return nil
    end
    local stock = self:getStock()
    local sum = stock[idx] or 0
    -- Gras, Kleegras und Luzerne liegen als Ballen/Schwad (…_WINDROW) im Ballenlager
    if not item.isStraw and not item.isAnimal and (item.name == "GRASS" or item.name == "CLOVER" or item.name == "ALFALFA") then
        local wi = g_fillTypeManager:getFillTypeIndexByName(item.name .. "_WINDROW")
        if wi ~= nil then
            sum = sum + (stock[wi] or 0)
        end
    end
    return sum
end

-- Fehlmenge je Jahr (1 = dieses, 2 = nächstes, 3 = in 2 Jahren) nach Verrechnung mit dem Lager.
-- Das Lager läuft kumulativ durch: Bestand nach einem Jahr = Bestand davor + Ertrag - Bedarf (nie unter 0);
-- ein negativer Rest ist die Fehlmenge dieses Jahres.
function FieldListHUD:getStockShortages(item)
    local stock = self:getRowStock(item) or 0
    local dem = item.demand or 0
    local isCut = item.multiCut or FieldListHUD.MULTI_CUT[item.name]
    local cutsF = (isCut and not item.yearly and item.cuts) or 1
    local ys = {
        ((item.now or 0) + ((not item.isAnimal and item.planned) or 0)) * cutsF,
        (item.nextYear or 0) * cutsF,
        (item.in2 or 0) * cutsF,
    }
    -- Was schon in den Produktionen eingelagert ist, ist bereits geliefert: wird einmalig vom Bedarf des ersten Jahres abgezogen
    local inp = (not item.isAnimal) and (self:getRowInput(item) or 0) or 0
    local dems = { math.max(0, dem - inp), dem, dem }
    local out, s = {}, stock
    out.rest = {}
    for i = 1, 3 do
        local bal = s + ys[i] - dems[i]
        out[i] = math.max(0, -bal)
        s = math.max(0, bal)
        -- voraussichtlicher Lagerbestand nach diesem Jahr (Überschuss zählt mit)
        out.rest[i] = s
    end
    return out
end

-- Zwischenspeicher für die Liste der Seite 3: höchstens einmal pro Sekunde neu, sofort neu nach Mausklick/Taste
function FieldListHUD:getPage3ListCached()
    local c = self.p3Cache
    local now = g_time or 0
    if c ~= nil and not self.p3Dirty and c.mode == self.p3Mode and (now - c.t) < 1000 then
        return c.list
    end
    self.p3Dirty = false
    local list = self:buildPage3List()
    self.p3Cache = { list = list, t = now, mode = self.p3Mode }
    return list
end

-- Gesamtliste Seite 3: Abschnitt Feldfrüchte, dann Abschnitt Tiererzeugnisse
function FieldListHUD:buildPage3List()
    local list = {}
    local crops = self:collectFruitTotals()
    local plain, forage = {}, {}
    for _, r in ipairs(crops) do
        if r.isSilage or (r.name ~= "FIELDGRASS" and (r.multiCut or FieldListHUD.MULTI_CUT[r.name])) then
            table.insert(forage, r)
        else
            table.insert(plain, r)
        end
    end
    -- Stroh-Zeile bleibt bei den Feldfrüchten (steht sonst am Ende der Liste)
    if #plain > 0 then
        table.insert(list, { isHeader = true, title = T("sec_crops") })
        for _, r in ipairs(plain) do table.insert(list, r) end
    end
    if #forage > 0 then
        table.insert(list, { isHeader = true, title = T("sec_forage") })
        for _, r in ipairs(forage) do table.insert(list, r) end
    end
    local products = self:getAnimalProducts()
    local fillDem = self.fillDemand or {}
    local names, seen = {}, {}
    for n in pairs(products) do if not seen[n] then seen[n] = true table.insert(names, n) end end
    for n in pairs(fillDem) do if not seen[n] then seen[n] = true table.insert(names, n) end end
    table.sort(names)
    if #names > 0 then
        table.insert(list, { isHeader = true, title = T("sec_animal") })
        for _, n in ipairs(names) do
            local ft = g_fillTypeManager:getFillTypeByName(n)
            local yearly = products[n] or 0
            table.insert(list, {
                isAnimal = true, name = n, title = (ft ~= nil and ft.title) or n,
                iconFilename = ft ~= nil and ft.hudOverlayFilename or nil,
                now = yearly, nextYear = yearly, demand = fillDem[n] or 0,
            })
        end
    end
    return list
end

-- Zeile der Seite 3 unter der Maus (nur Warenzeilen, keine Abschnittsköpfe)
function FieldListHUD:getRowAt(x, y)
    for _, r in ipairs((self.p3 or {}).rows or {}) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            return r.item
        end
    end
    return nil
end

function FieldListHUD:onKeyDetail()
    self.p3Dirty = true
    if self.page ~= 3 or self.layout == nil then
        return false
    end
    if self.popup ~= nil then
        self.popup = nil
        return true
    end
    local item = self:getRowAt(self.mouseX or -1, self.mouseY or -1)
    if item ~= nil then
        self.popup = { item = item }
        return true
    end
    return false
end

-- Alle Produktionen mit Lager/Bedarf zu einer Zeile der Seite 3
function FieldListHUD:getItemSources(item)
    local out = {}
    local mission = g_currentMission
    local pcm = mission ~= nil and mission.productionChainManager or nil
    if pcm == nil then
        return out
    end
    local function matches(fti)
        local fname = g_fillTypeManager:getFillTypeNameByIndex(fti)
        if item.isSilage then
            return fname == "SILAGE" or fname == "CHAFF"
        elseif item.isStraw then
            return fname == (item.strawFill or "STRAW")
        elseif item.isAnimal then
            return fname == item.name
        end
        if item.isWindrow then
            return fname == item.windrow
        end
        if fname ~= nil and (item.name == "GRASS" or item.name == "CLOVER" or item.name == "ALFALFA")
            and fname == item.name .. "_WINDROW" then
            return true
        end
        local fi = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(fti)
        local ft = fi ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fi) or nil
        if ft == nil or string.upper(ft.name) ~= string.upper(item.name or "") then
            return false
        end
        -- Schwad-Waren (z. B. Flachsschwad) gehören zur eigenen Zeile, nicht zum Korn
        local ownFill = ft.fillType ~= nil and ft.fillType.index or nil
        return ownFill == nil or ownFill == fti
    end
    for _, pp in pairs(pcm:getProductionPointsForFarmId(mission:getFarmId()) or {}) do
        local st = pp.storage
        local outs = pp.outputFillTypeIds or {}
        local ins = pp.inputFillTypeIds or {}
        local level, isIn, isOut = 0, false, false
        if st ~= nil then
            for fti, lvl in pairs(st.fillLevels or {}) do
                if type(lvl) == "number" and lvl > 0 and matches(fti) then
                    level = level + lvl
                    isIn = isIn or ins[fti] ~= nil
                    isOut = isOut or outs[fti] ~= nil
                end
            end
        end
        local demand = 0
        local ppName = tostring(pp.getName ~= nil and pp:getName() or "?")
        local lagerName = string.find(ppName, "Ballenlager", 1, true) ~= nil
            or string.find(ppName, "Zentrallager", 1, true) ~= nil
        for _, prod in pairs(pp.activeProductions or {}) do
            local pass = lagerName
            for _, o in pairs(prod.outputs or {}) do
                for _, i in pairs(prod.inputs or {}) do
                    if o.type ~= nil and o.type == i.type then pass = true end
                end
            end
            if not pass then
                local perYear = nil
                if prod.cyclesPerMonth ~= nil then
                    perYear = prod.cyclesPerMonth * 12
                end
                for _, input in pairs(prod.inputs or {}) do
                    if perYear ~= nil and input.amount ~= nil and input.type ~= nil and matches(input.type) then
                        demand = demand + input.amount * perYear
                    end
                end
            end
        end
        if level > 0 or demand > 0 then
            local role = T("pop_input")
            if isOut and isIn then role = T("pop_store")
            elseif isOut then role = T("pop_output") end
            table.insert(out, { name = ppName, role = role, level = level, demand = demand, isInput = isIn and not isOut })
        end
    end
    -- Fahrsilos (Silage/Häckselgut, auch während der Gärung)
    if item.isSilage then
        pcall(function()
            local farmId = mission:getFarmId()
            for _, pl in pairs(mission.placeableSystem ~= nil and mission.placeableSystem.placeables or {}) do
                local sp = pl.spec_bunkerSilo
                local bs = sp ~= nil and sp.bunkerSilo or nil
                if bs ~= nil and (pl.getOwnerFarmId == nil or pl:getOwnerFarmId() == farmId)
                    and type(bs.fillLevel) == "number" and bs.fillLevel > 0 then
                    local nm = tostring(pl.getName ~= nil and pl:getName() or "Fahrsilo")
                    local pct = tonumber(bs.fermentingPercent) or 0
                    if bs.state == 1 and pct > 0 and pct < 1 then
                        nm = string.format("%s (%s %d%%)", nm, T("silo_ferment"), math.floor(pct * 100 + 0.5))
                    end
                    table.insert(out, { name = nm, role = T("pop_store"), level = bs.fillLevel, demand = 0, isInput = false })
                end
            end
        end)
    end
    table.sort(out, function(a, b) return a.level > b.level end)
    return out
end

-- Lage des Detailfensters (volle Tabellenbreite, damit die Zeilen dahinter ganz verdeckt sind)
-- Felder, die im gewählten Reiter zur Zeile beitragen (begrenzt auf die Höhe des Fensters)
function FieldListHUD:getPopupFields(L, item, nSrc)
    local all = {}
    local mode = (self.p3Mode == "next" and "next") or (self.p3Mode == "in2" and "in2") or "this"
    for _, f in ipairs(item.fields or {}) do
        if f.mode == mode then table.insert(all, f) end
    end
    table.sort(all, function(a, b)
        if a.id ~= b.id then return a.id < b.id end
        return a.kind < b.kind
    end)
    if #all == 0 then
        return all, 0
    end
    local rowH, headH = 0.030, 0.034
    local fixed = 0.052 + headH + (math.max(1, nSrc) + 1) * rowH + 0.012 + headH
    local maxRows = math.max(3, math.floor((L.ah - 0.030 - fixed) / rowH))
    if #all <= maxRows then
        return all, 0
    end
    local shown = {}
    for i = 1, maxRows - 1 do shown[i] = all[i] end
    return shown, #all - (maxRows - 1)
end

function FieldListHUD:getPopupRect(L, rowsData, fieldRows, moreCount)
    local rowH, headH = 0.030, 0.034
    local w = L.aw - 0.015
    local n = math.max(1, #rowsData)
    local h = 0.052 + headH + (n + 1) * rowH + 0.012
    if fieldRows ~= nil and #fieldRows > 0 then
        h = h + headH + (#fieldRows + ((moreCount or 0) > 0 and 1 or 0)) * rowH
    end
    local x = L.ax
    local y = L.ay + (L.ah - h) / 2
    return x, y, w, h
end

-- Detailfenster: Produktionen mit ihrem Lager zu einer Ware
function FieldListHUD:drawPopup(L)
    local item = self.popup ~= nil and self.popup.item or nil
    if item == nil then
        return
    end
    local rowsData = self:getItemSources(item)
    local fieldRows, moreCount = self:getPopupFields(L, item, #rowsData)
    local rowH, headH = 0.030, 0.034
    local x, y, w, h = self:getPopupRect(L, rowsData, fieldRows, moreCount)
    self:drawRect(x - 0.004, y - 0.004, w + 0.008, h + 0.008, self.colorArea)
    self:drawRect(x, y, w, h, { 0.016, 0.016, 0.016, 1 })
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x + 0.010, y + h - 0.026, 0.018, tostring(item.title or item.name))
    setTextColor(unpack(self.colorSub))
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(x + w - 0.010, y + h - 0.026, 0.011, T("pop_close"))
    local cx = { x + 0.010, x + w * 0.46, x + w * 0.66, x + w * 0.84 }
    local top = y + h - 0.052
    self:drawRect(x, top - headH, w, headH, self.colorTile)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(self.colorTitle))
    local heads = { T("pop_prod"), T("pop_kind"), T("pop_amount"), T(item.isAnimal and "pop_demand_h" or "pop_demand") }
    -- Tiererzeugnisse: Bedarf pro Stunde, sonst pro Jahr
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    local dDiv = item.isAnimal and (24 * 12 * ((env ~= nil and env.daysPerPeriod) or 1)) or 1
    local dFmt = item.isAnimal and fmtPerHour or fmtLiters
    -- Mengen-Spalten rechtsbündig, damit Überschrift und Zahlen exakt untereinander stehen
    local rx = { nil, nil, x + w * 0.80, x + w - 0.012 }
    for i, t in ipairs(heads) do
        if rx[i] ~= nil then
            setTextAlignment(RenderText.ALIGN_RIGHT)
            renderText(rx[i], top - headH / 2, 0.011, t)
            setTextAlignment(RenderText.ALIGN_LEFT)
        else
            renderText(cx[i], top - headH / 2, 0.011, t)
        end
    end
    setTextBold(false)
    local sumIn, sumOther = 0, 0
    local ry = top - headH
    if #rowsData == 0 then
        ry = ry - rowH
        setTextColor(unpack(self.colorSub))
        renderText(cx[1], ry + rowH / 2, 0.013, T("pop_none"))
    end
    for _, r in ipairs(rowsData) do
        ry = ry - rowH
        setTextColor(unpack(self.colorTitle))
        local nm = r.name
        local maxW = cx[2] - cx[1] - 0.010
        local size = 0.013
        local tw = getTextWidth(size, nm)
        if tw > maxW then size = size * maxW / tw end
        renderText(cx[1], ry + rowH / 2, size, nm)
        setTextColor(unpack(self.colorSub))
        renderText(cx[2], ry + rowH / 2, 0.013, r.role)
        setTextColor(unpack(r.level > 0 and self.colorTitle or self.colorSub))
        setTextAlignment(RenderText.ALIGN_RIGHT)
        renderText(rx[3], ry + rowH / 2, 0.013, fmtLiters(r.level))
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(unpack(r.demand > 0 and self.colorWork or self.colorSub))
        setTextAlignment(RenderText.ALIGN_RIGHT)
        renderText(rx[4], ry + rowH / 2, 0.013, dFmt(r.demand / dDiv))
        setTextAlignment(RenderText.ALIGN_LEFT)
        if r.isInput then sumIn = sumIn + r.level else sumOther = sumOther + r.level end
    end
    -- Summenzeile
    ry = ry - rowH
    self:drawRect(x + 0.006, ry + rowH - 0.0012, w - 0.012, 0.0012, self.colorArea)
    setTextBold(true)
    setTextColor(unpack(self.colorArea))
    renderText(cx[1], ry + rowH / 2, 0.012, T("pop_sum_input") .. " " .. fmtLiters(sumIn))
    renderText(cx[2], ry + rowH / 2, 0.012, T("pop_sum_store") .. " " .. fmtLiters(sumOther))
    setTextBold(false)
    -- Felder, die mit ihren Früchten zu den Werten beitragen (N weiß, N+1 hellblau)
    if #fieldRows > 0 then
        ry = ry - headH
        self:drawRect(x, ry, w, headH, self.colorTile)
        setTextBold(true)
        setTextColor(unpack(self.colorTitle))
        setTextAlignment(RenderText.ALIGN_LEFT)
        renderText(cx[1], ry + headH / 2, 0.011, T("pop_fields"))
        renderText(x + w * 0.13, ry + headH / 2, 0.011, T("pop_harvest"))
        renderText(x + w * 0.335, ry + headH / 2, 0.011, T("pop_fruit"))
        renderText(x + w * 0.475, ry + headH / 2, 0.011, T("pop_sow"))
        renderText(x + w * 0.565, ry + headH / 2, 0.011, T("pop_month"))
        setTextAlignment(RenderText.ALIGN_RIGHT)
        renderText(x + w * 0.69, ry + headH / 2, 0.011, T("pop_area"))
        renderText(rx[3], ry + headH / 2, 0.011, T("pop_pct"))
        renderText(rx[4], ry + headH / 2, 0.011, T("pop_amount"))
        setTextBold(false)
        local total = 0
        for _, f in ipairs(fieldRows) do
            ry = ry - rowH
            local col = f.kind == "n1" and self.colorNoFruit or self.colorTitle
            setTextColor(unpack(col))
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(cx[1], ry + rowH / 2, 0.013, string.format("%s %s", T("field_word"), tostring(f.id)))
            renderText(x + w * 0.13, ry + rowH / 2, 0.012, string.format("%s · %s",
                (f.mode == "in2" and T("pop_h_2y")) or (f.mode == "next" and T("pop_h_next")) or T("pop_h_this"),
                f.kind == "n1" and T("pop_h_planned") or T("pop_h_standing")))
            local en = self:getEntryByFruitName(f.fruit)
            renderText(x + w * 0.335, ry + rowH / 2, 0.013, tostring((en ~= nil and en.fruitTitle) or f.fruit or "-"))
            renderText(x + w * 0.475, ry + rowH / 2, 0.012, self:getSowMonthText(f.fruit, f.kind, f.id))
            renderText(x + w * 0.565, ry + rowH / 2, 0.012, self:getHarvestMonthText(f.fruit, f.mode, f.kind, f.id))
            setTextAlignment(RenderText.ALIGN_RIGHT)
            renderText(x + w * 0.69, ry + rowH / 2, 0.013, string.format("%.2f ha", f.area or 0))
            renderText(rx[3], ry + rowH / 2, 0.013, f.pct ~= nil and string.format("%.1f %%", 100 + f.pct) or "-")
            renderText(rx[4], ry + rowH / 2, 0.013, fmtLiters(f.liters or 0))
            total = total + (f.liters or 0)
        end
        if moreCount > 0 then
            ry = ry - rowH
            setTextColor(unpack(self.colorSub))
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(cx[1], ry + rowH / 2, 0.012, string.format(T("pop_more"), moreCount))
        end
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function FieldListHUD:drawFruitPage(L)
    local x0, w0 = L.ax, L.aw - 0.015
    local top = L.ay + L.ah

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x0, top, 0.036, T("title_crops"))
    setTextBold(false)
    -- Umschalter Dieses Jahr / Nächstes Jahr (Planung), auch per Taste T
    self.p3Mode = self.p3Mode or "this"
    self.p3 = self.p3 or { offset = 0, max = 0 }
    self.p3.tabs = {}
    do
        local ts, th = 0.012, 0.030
        local tabs = { { mode = "this", title = T("tab_this") }, { mode = "next", title = T("tab_next") }, { mode = "in2", title = T("tab_in2") } }
        local gap = 0.006
        local widths, total = {}, 0
        for i, t in ipairs(tabs) do
            widths[i] = getTextWidth(ts, t.title) + 0.024
            total = total + widths[i] + (i > 1 and gap or 0)
        end
        -- links, direkt hinter dem Titel (rechts sitzen Seitenzahl und Pfeile)
        local tx = x0 + getTextWidth(0.036, T("title_crops")) + 0.030
        local ty = top - 0.040
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextAlignment(RenderText.ALIGN_LEFT)
        for i, t in ipairs(tabs) do
            local active = self.p3Mode == t.mode
            self:drawFrame(tx, ty, widths[i], th, active and self.colorArea or self.colorTile, self.colorBorder)
            setTextBold(active)
            setTextColor(unpack(active and { 0.02, 0.02, 0.02, 1 } or self.colorTitle))
            renderText(tx + 0.012, ty + th / 2, ts, t.title)
            setTextBold(false)
            table.insert(self.p3.tabs, { x = tx, y = ty, w = widths[i], h = th, mode = t.mode })
            tx = tx + widths[i] + gap
        end
    end
    top = top - 0.060

    local bottom = L.ay + L.pad + 0.010
    local headH, rowH = 0.036, 0.036
    local list = self:getPage3ListCached()
    local rows = math.max(1, math.floor((top - bottom - headH) / rowH))
    self.p3 = self.p3 or { offset = 0, max = 0 }
    self.p3.max = math.max(0, #list - rows)
    self.p3.offset = math.max(0, math.min(self.p3.offset or 0, self.p3.max))
    self.p3.area = { x = x0, y = bottom, w = w0, h = top - bottom }
    -- Platz für die Scrollleiste rechts, wenn nicht alle Zeilen passen
    local p3ScrollW, p3Gap = 0.006, 0.006
    local needScroll3 = #list > rows
    local tw0 = needScroll3 and (w0 - p3ScrollW - p3Gap) or w0

    local cols = {
        { title = T("col_product"),        f = 0.15 },
        { title = T("col_this"),     f = 0.10 },
        { title = (self.p3Mode == "in2") and T("col_in2") or T("col_next"),   f = 0.10 },
        { title = T("col_demand"),    f = 0.11 },
        { title = T("col_diff"),              f = 0.11 },
        { title = T("col_stock"),           f = 0.10 },
        { title = T("col_input"),           f = 0.11 },
        { title = T("col_rest"),            f = 0.11 },
        { title = T("col_short"),           f = 0.11 },
        { title = T("col_need_area"),           f = 0.11 },
    }
    -- Je Reiter nur eine Ertragsspalte: Spalte 2 = dieses Jahr, Spalte 3 = nächstes Jahr
    local showThis = self.p3Mode == "this" or self.p3Mode == nil
    local showNext = self.p3Mode == "next" or self.p3Mode == "in2"
    local sumF = 0
    for i, c in ipairs(cols) do
        c.hide = (i == 2 and not showThis) or (i == 3 and not showNext)
        if not c.hide then sumF = sumF + c.f end
    end
    local cx = x0
    for _, c in ipairs(cols) do
        if c.hide then
            c.x, c.w = cx, 0
        else
            c.x = cx
            c.w = tw0 * c.f / sumF
            cx = cx + c.w
        end
    end

    self:drawFrame(x0, top - headH, tw0, headH, self.colorTile, self.colorBorder)
    self:drawRect(x0, top - headH, tw0, 0.0015, self.colorArea)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    for _, c in ipairs(cols) do
      if not c.hide then
        local hs = 0.011
        local tw = getTextWidth(hs, c.title)
        local maxW = c.w - 0.012
        if tw > maxW then hs = hs * maxW / tw end
        if c.sub ~= nil then
            -- Titel in zwei Zeilen: Name oben, Faktor klein darunter
            renderText(c.x + 0.008, top - headH / 2 + 0.0075, hs, c.title)
            local ss = 0.0092
            local sw = getTextWidth(ss, c.sub)
            if sw > maxW then ss = ss * maxW / sw end
            setTextBold(false)
            setTextColor(unpack(self.colorSub))
            renderText(c.x + 0.008, top - headH / 2 - 0.0075, ss, c.sub)
            setTextBold(true)
            setTextColor(unpack(self.colorTitle))
        else
            renderText(c.x + 0.008, top - headH / 2, hs, c.title)
        end
      end
    end
    setTextBold(false)

    local altColor = { 0.026, 0.026, 0.026, 1 }
    self.p3.rows = {}
    local pr = nil
    if self.popup ~= nil then
        local srcRows = self:getItemSources(self.popup.item)
        local fRows, fMore = self:getPopupFields(L, self.popup.item, #srcRows)
        local _, py, _, ph = self:getPopupRect(L, srcRows, fRows, fMore)
        pr = { y = py - 0.004, h = ph + 0.008 }
    end
    for r = 1, math.min(rows, #list - self.p3.offset) do
        local item = list[self.p3.offset + r]
        local ry = top - headH - r * rowH
        if not item.isHeader then
            table.insert(self.p3.rows, { x = x0, y = ry, w = tw0, h = rowH, item = item })
        end
        local hidden = pr ~= nil and ry < pr.y + pr.h and ry + rowH > pr.y
        if hidden then
            -- Text lässt sich nicht von Flächen überdecken: Zeilen hinter dem Detailfenster nicht zeichnen
        elseif item.isHeader then
            self:drawRect(x0, ry, tw0, rowH, { 0.012, 0.012, 0.012, 1 })
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextBold(true)
            setTextColor(unpack(self.colorArea))
            renderText(x0 + 0.008, ry + rowH / 2, 0.012, item.title)
            setTextBold(false)
        else
        self:drawFrame(x0, ry, tw0, rowH, (r % 2 == 1) and self.colorTile or altColor, self.colorBorder)
        self:drawFruitCell(self:getFruitRowEntry(item), cols[1].x, ry, cols[1].w, rowH, 0.013)
        -- Tiererzeugnisse pro Stunde, Feldfrüchte und Futterpflanzen pro Jahr
        local fmt, div = fmtLiters, 1
        if item.isAnimal then
            fmt = fmtPerHour
            local env = g_currentMission ~= nil and g_currentMission.environment or nil
            div = 24 * 12 * ((env ~= nil and env.daysPerPeriod) or 1)
        end
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextAlignment(RenderText.ALIGN_LEFT)
        local planned = (not item.isAnimal and item.planned) or 0
        local nextMode = self.p3Mode ~= "this" and not item.isAnimal
        local fwdVal = (self.p3Mode == "in2") and (item.in2 or 0) or (item.nextYear or 0)
        -- Planung: Ertrag = alle Felder mit N+1; sonst: aktuelle Frucht + N+1 auf leeren Feldern
        local yieldVal = nextMode and fwdVal or ((item.now or 0) + planned)
        -- Schnittfrüchte: Werte oben gelten pro Schnitt, für Differenz und Fehlmenge zählt das Jahr (Schnitte x Ertrag)
        local isCut = item.multiCut or FieldListHUD.MULTI_CUT[item.name]
        local cutsF = (isCut and item.cuts) or 1
        local yearVal = item.yearly and yieldVal or yieldVal * cutsF
        if not showThis then
            -- Spalte "dieses Jahr" ist im Reiter Planung ausgeblendet
        elseif planned > 0 then
            -- "84.000 + 12.000 l": erster Teil steht auf dem Feld (weiß), zweiter ist aus der Folgefrucht geplant (hellblau)
            local first = (item.now or 0) > 0 and string.format("%s", string.gsub(fmtLiters(item.now), " l$", "")) or "0"
            setTextColor(unpack(self.colorTitle))
            renderText(cols[2].x + 0.008, ry + rowH / 2, 0.013, first)
            local fw = getTextWidth(0.013, first)
            setTextColor(unpack(self.colorNoFruit))
            renderText(cols[2].x + 0.008 + fw, ry + rowH / 2, 0.013, " + " .. fmtLiters(planned))
        else
            setTextColor(unpack(item.now > 0 and self.colorArea or self.colorSub))
            renderText(cols[2].x + 0.008, ry + rowH / 2, 0.013, fmt(item.now / div))
        end
        -- Bei Tieren steht in der Spalte "Ertrag nächstes Jahr" nur ein Strich (gleicher Wert), die Spalten bleiben ausgerichtet
        if not showNext then
            -- Spalte "nächstes Jahr" ist im Reiter "Dieses Jahr" ausgeblendet
        elseif not item.isAnimal then
            setTextColor(unpack(fwdVal > 0 and self.colorArea or self.colorSub))
            renderText(cols[3].x + 0.008, ry + rowH / 2, 0.013, fmt(fwdVal / div))
        elseif showNext then
            -- Tiere: gleicher Wert pro Stunde in beiden Reitern
            setTextColor(unpack((item.now or 0) > 0 and self.colorArea or self.colorSub))
            renderText(cols[3].x + 0.008, ry + rowH / 2, 0.013, fmt((item.now or 0) / div))
        else
            setTextColor(unpack(self.colorSub))
            renderText(cols[3].x + 0.008, ry + rowH / 2, 0.013, "-")
        end
        local dem = item.demand or 0
        setTextColor(unpack(dem > 0 and self.colorWork or self.colorSub))
        renderText(cols[4].x + 0.008, ry + rowH / 2, 0.013, fmt(dem / div))
        -- Differenz: Ertrag dieses Jahr minus Bedarf (Plus = Überschuss, Minus = es fehlt)
        if (dem > 0 or yearVal > 0) and (not isCut or item.cuts ~= nil) then
            local diff = yearVal - dem
            setTextColor(unpack(diff >= 0 and self.colorArea or { 1, 0.4, 0.4, 1 }))
            renderText(cols[5].x + 0.008, ry + rowH / 2, 0.013,
                math.abs(diff) < 0.5 and "0" or ((diff >= 0 and "+" or "-") .. fmt(math.abs(diff) / div)))
        else
            setTextColor(unpack(self.colorSub))
            renderText(cols[5].x + 0.008, ry + rowH / 2, 0.013, "-")
        end
        local stock = self:getRowStock(item)
        -- Startbestand des Jahres im Reiter: dieses Jahr der echte Bestand, später der Restbestand des Vorjahres
        if stock ~= nil and self.p3Mode ~= nil and self.p3Mode ~= "this" and not item.isAnimal then
            local shs0 = self:getStockShortages(item)
            stock = shs0.rest[(self.p3Mode == "in2") and 2 or 1] or 0
        end
        setTextColor(unpack((stock or 0) > 0 and self.colorTitle or self.colorSub))
        renderText(cols[6].x + 0.008, ry + rowH / 2, 0.013, fmtLiters(stock))
        local inp = self:getRowInput(item)
        setTextColor(unpack(inp > 0 and self.colorTitle or self.colorSub))
        renderText(cols[7].x + 0.008, ry + rowH / 2, 0.013, fmtLiters(inp))
        -- Restbestand: voraussichtlicher Lagerbestand am Ende des Jahres des gewählten Reiters (Lager + Ertrag - Bedarf)
        if not item.isAnimal and stock ~= nil then
            local shs = self:getStockShortages(item)
            local rest = shs.rest[(self.p3Mode == "in2") and 3 or ((self.p3Mode == "next") and 2 or 1)] or 0
            setTextColor(unpack(rest > 0 and self.colorTitle or self.colorSub))
            renderText(cols[8].x + 0.008, ry + rowH / 2, 0.013, fmtLiters(rest))
        else
            setTextColor(unpack(self.colorSub))
            renderText(cols[8].x + 0.008, ry + rowH / 2, 0.013, "-")
        end
        -- Fehlmenge = Jahresbedarf minus Ertrag der Felder (steht + geplant aus N+1), ohne Lager.
        -- Nur Feldfrüchte; Schnittfrüchte (pro Schnitt) und Tiere werden hier nicht gerechnet.
        local short, shortNoPlan = 0, 0
        if not item.isAnimal and (not isCut or item.cuts ~= nil) and dem > 0 then
            short = math.max(0, dem - yearVal)
            shortNoPlan = nextMode and short or math.max(0, dem - (item.yearly and (item.now or 0) or (item.now or 0) * cutsF))
        end
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextAlignment(RenderText.ALIGN_LEFT)
        local shortStock = short
        if short > 0 then
            local shs = self:getStockShortages(item)
            shortStock = shs[(self.p3Mode == "in2") and 3 or ((self.p3Mode == "next") and 2 or 1)] or short
        end
        if short > 0 then
            -- rot: Lager deckt nichts, orange: teilweise, grün: Lager deckt die Fehlmenge ganz
            if shortStock <= 0.5 then
                setTextColor(unpack(self.colorArea))
            elseif shortStock < short - 0.5 then
                setTextColor(unpack(self.colorWork))
            else
                setTextColor(1, 0.4, 0.4, 1)
            end
            renderText(cols[9].x + 0.008, ry + rowH / 2, 0.013, fmtLiters(shortStock <= 0.5 and 0 or shortStock))
            local ft = g_fruitTypeManager:getFruitTypeByName(item.name)
            local perHa = ft ~= nil and ((item.isWindrow and ft.windrowLiterPerSqm or ft.literPerSqm) or 0) * 10000 or 0
            -- Ertrag je ha = Basis x (1 + Prozent/100); Prozent = Schnitt der Felder dieser Frucht, sonst 100 %
            local avgPct = (item.areaW ~= nil and item.areaW > 0) and (item.pctW / item.areaW) or 100
            if nextMode then
                if self.p3Mode == "in2" then
                    avgPct = (item.areaI ~= nil and item.areaI > 0) and (item.pctI / item.areaI) or 100
                else
                    avgPct = (item.areaN ~= nil and item.areaN > 0) and (item.pctN / item.areaN) or 100
                end
            end
            if item.isSilage then perHa = item.silageBase or 0 end
            perHa = perHa * (1 + avgPct / 100) * cutsF
            if item.isStraw then perHa = item.strawPerHa or 0 end
            if shortStock <= 0.5 then
                setTextColor(unpack(self.colorSub))
                renderText(cols[10].x + 0.008, ry + rowH / 2, 0.013, "-")
            elseif perHa > 0 then
                setTextColor(unpack(self.colorWork))
                renderText(cols[10].x + 0.008, ry + rowH / 2, 0.013, string.format("%.1f ha", shortStock / perHa))
            else
                setTextColor(unpack(self.colorSub))
                renderText(cols[10].x + 0.008, ry + rowH / 2, 0.013, "-")
            end
        elseif shortNoPlan > 0 then
            -- nur dank der geplanten Folgefrucht gedeckt: hellblau
            setTextColor(unpack(self.colorNoFruit))
            renderText(cols[9].x + 0.008, ry + rowH / 2, 0.013, "0 l")
            setTextColor(unpack(self.colorSub))
            renderText(cols[10].x + 0.008, ry + rowH / 2, 0.013, "-")
        else
            setTextColor(unpack(self.colorSub))
            renderText(cols[9].x + 0.008, ry + rowH / 2, 0.013, "-")
            renderText(cols[10].x + 0.008, ry + rowH / 2, 0.013, "-")
        end
        end
    end
    -- Scrollleiste
    self.p3.track, self.p3.thumb = nil, nil
    if needScroll3 then
        local trackH = rows * rowH
        local thumbH = math.max(0.03, trackH * rows / #list)
        local frac = self.p3.max > 0 and (self.p3.offset / self.p3.max) or 0
        self.p3.track = { x = x0 + tw0 + p3Gap, y = top - headH - trackH, w = p3ScrollW, h = trackH }
        self.p3.thumb = { x = self.p3.track.x, y = self.p3.track.y + trackH - thumbH - (trackH - thumbH) * frac, w = p3ScrollW, h = thumbH }
        self:drawRect(self.p3.track.x, self.p3.track.y, self.p3.track.w, self.p3.track.h, self.colorTrack)
        self:drawRect(self.p3.thumb.x, self.p3.thumb.y, self.p3.thumb.w, self.p3.thumb.h, self.colorThumb)
    end
    if #list == 0 then
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(unpack(self.colorSub))
        renderText(x0 + 0.008, top - headH - 0.012, 0.013, T("no_crops"))
    end
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    if self.popup ~= nil then
        self:drawPopup(L)
    end
end

-- Zusammenfassung der anstehenden Arbeiten über alle genutzten Felder (einmal pro Sekunde neu)
-- Rückgabe: Anzahl Felder mit Arbeit, Liste { text, fields, ha } nach Fläche absteigend
function FieldListHUD:getWorkSummary()
    if self.workSumCache ~= nil and g_time ~= nil and (g_time - (self.workSumTime or 0)) < 1000 then
        return self.workSumCache.count, self.workSumCache.list
    end
    local count, map, list = 0, {}, {}
    for _, e in ipairs(self.fields or {}) do
        if not e.unused then
            local items = self:getWorkItems(e)
            if #items > 0 then
                count = count + 1
                for _, it in ipairs(items) do
                    local key = it.harvest and T("ground_ready") or it.short
                    local r = map[key]
                    if r == nil then
                        r = { text = key, fields = 0, ha = 0, prio = it.prio or 99 }
                        map[key] = r
                        table.insert(list, r)
                    end
                    r.fields = r.fields + 1
                    r.ha = r.ha + (e.area or 0)
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.prio ~= b.prio then return a.prio < b.prio end
        return a.ha > b.ha
    end)
    self.workSumCache = { count = count, list = list }
    self.workSumTime = g_time
    return count, list
end

-- Übernimmt alle automatischen Folgefrucht-Vorschläge als feste Wahl
function FieldListHUD:acceptAutoNext()
    for _, e in ipairs(self.fields or {}) do
        local r = self.store[e.id]
        if r ~= nil and r.autoNext and r.next ~= nil then
            r.autoNext = false
        end
    end
end

-- Sicherheitsabfrage (Ja/Nein) über der ganzen Seite
function FieldListHUD:askConfirm(text, text2, onYes)
    self.confirm = { text = text, text2 = text2, onYes = onYes }
end

function FieldListHUD:drawConfirm(L)
    if self.confirm == nil then
        self.confirmBtns = nil
        return
    end
    local c = self.confirm
    local w, h = 0.42, 0.150
    local x = L.ax + (L.aw - w) / 2
    local y = L.ay + (L.ah - h) / 2
    -- Abdunklung hinter dem Fenster
    self:drawRect(L.ax, L.ay, L.aw, L.ah, { 0.019, 0.019, 0.019, 1 })
    self:drawRect(x - 0.003, y - 0.003, w + 0.006, h + 0.006, self.colorArea)
    self:drawRect(x, y, w, h, { 0.016, 0.016, 0.016, 1 })
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    local size = 0.016
    local tw = getTextWidth(size, c.text)
    if tw > w - 0.030 then size = size * (w - 0.030) / tw end
    renderText(x + w / 2, y + h - 0.030, size, c.text)
    setTextBold(false)
    setTextColor(unpack(self.colorSub))
    -- zweite Zeile umbrechen, falls zu breit
    local words, line, lines = {}, "", {}
    for wd in string.gmatch(c.text2 or "", "%S+") do table.insert(words, wd) end
    for _, wd in ipairs(words) do
        local try = (line == "") and wd or (line .. " " .. wd)
        if getTextWidth(0.012, try) > w - 0.030 and line ~= "" then
            table.insert(lines, line)
            line = wd
        else
            line = try
        end
    end
    if line ~= "" then table.insert(lines, line) end
    for i, ln in ipairs(lines) do
        renderText(x + w / 2, y + h - 0.056 - (i - 1) * 0.018, 0.012, ln)
    end
    local bw, bh = 0.12, 0.030
    local by = y + 0.012
    local yes = { x = x + w / 2 - bw - 0.008, y = by, w = bw, h = bh }
    local no = { x = x + w / 2 + 0.008, y = by, w = bw, h = bh }
    self:drawFrame(yes.x, yes.y, yes.w, yes.h, self.colorTile, self.colorArea)
    self:drawFrame(no.x, no.y, no.w, no.h, self.colorTile, self.colorBorder)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(yes.x + yes.w / 2, yes.y + yes.h / 2, 0.013, T("confirm_yes"))
    renderText(no.x + no.w / 2, no.y + no.h / 2, 0.013, T("confirm_no"))
    setTextBold(false)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    self.confirmBtns = { yes = yes, no = no }
end


-- Tooltip zum Filterknopf "Arbeiten": Hektar je anstehender Arbeit (wird ganz oben gezeichnet)
function FieldListHUD:drawWorkTip()
    local tip = self.pendingTip
    self.pendingTip = nil
    if tip == nil then
        return
    end
    if tip.lines ~= nil then
        local K = 1.33
        local lw = 0
        setTextBold(false)
        for _, ln in ipairs(tip.lines) do
            lw = math.max(lw, getTextWidth(0.011 * K, ln[1]))
        end
        local w = math.max(tip.w, lw + 0.020)
        local rowH = 0.022 * K
        local h = #tip.lines * rowH + 0.012
        local x = math.min(tip.x, 0.99 - w)
        local y = tip.y
        self:drawRect(x - 0.003, y - 0.003, w + 0.006, h + 0.006, self.colorArea)
        self:drawRect(x, y, w, h, { 0.016, 0.016, 0.016, 1 })
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextAlignment(RenderText.ALIGN_LEFT)
        for i, ln in ipairs(tip.lines) do
            setTextBold(ln[2] == true)
            setTextColor(unpack(ln[2] and self.colorTitle or (ln[3] and { 1, 0.4, 0.4, 1 } or self.colorSub)))
            renderText(x + 0.008, y + h - 0.006 - (i - 0.5) * rowH, 0.011 * K, ln[1])
        end
        setTextBold(false)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        self.tipRect = { x = x - 0.003, y = y - 0.003, w = w + 0.006, h = h + 0.006 }
        return
    end
    local _, list = self:getWorkSummary()
    local K = 1.33 -- Schrift und Zeilen 33 % größer
    local rowH = 0.022 * K
    local n = math.max(1, #list)
    local w = tip.w
    setTextBold(false)
    for _, r in ipairs(list) do
        local need = getTextWidth(0.011 * K, r.text) + getTextWidth(0.011 * K, string.format(T("tip_amount"), r.fields, r.ha)) + 0.040
        if need > w then w = need end
    end
    local h = 0.030 * K + n * rowH + 0.008
    local x = tip.x
    local y = tip.y
    self:drawRect(x - 0.003, y - 0.003, w + 0.006, h + 0.006, self.colorArea)
    self:drawRect(x, y, w, h, { 0.016, 0.016, 0.016, 1 })
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x + 0.008, y + h - 0.016 * K, 0.012 * K, T("tip_title"))
    setTextBold(false)
    if #list == 0 then
        setTextColor(unpack(self.colorSub))
        renderText(x + 0.008, y + h - 0.030 * K - rowH / 2, 0.012 * K, T("tip_none"))
    end
    for i, r in ipairs(list) do
        local ry = y + h - 0.030 * K - i * rowH
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(unpack(self.colorWork))
        renderText(x + 0.008, ry + rowH / 2, 0.011 * K, r.text)
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextColor(unpack(self.colorTitle))
        renderText(x + w - 0.008, ry + rowH / 2, 0.011 * K, string.format(T("tip_amount"), r.fields, r.ha))
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    self.tipRect = { x = x - 0.003, y = y - 0.003, w = w + 0.006, h = h + 0.006 }
end

-- Zeichnet die Filter-Schaltflächen (Seite 1 und Seite 2)
function FieldListHUD:drawFilterButtons(btns)
    for _, b in ipairs(btns) do
        local effMode = self.filterMode
        if self.page == 2 then effMode = self.tblFilter or 1 elseif self.page == 4 then effMode = self.wkFilter or 4 end
        local active = (b.mode == effMode)
        self:drawFrame(b.x, b.y, b.w, b.h, active and self.colorTileSelected or self.colorTile,
            active and self.colorArea or self.colorBorder)
        local label = b.label
        if b.mode == 4 then
            local cnt = self:getWorkSummary()
            label = string.format("%s (%d)", b.label, cnt)
            local mx, my = self.mouseX, self.mouseY
            if self.page == 1 and mx ~= nil and mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
                local L = self.layout
                local tw0 = (self.page == 1 and L ~= nil and L.list ~= nil) and L.list.w or 0.26
                self.pendingTip = { x = b.x, y = b.y + b.h + 0.008, w = tw0 }
            end
        end
        local size = 0.010
        local tw = getTextWidth(size, label)
        if tw > b.w * 0.92 then
            size = size * (b.w * 0.92) / tw
        end
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(unpack(active and self.colorTitle or self.colorSub))
        renderText(b.x + b.w / 2, b.y + b.h / 2, size, label)
        setTextBold(false)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    end
end

-- Seite 5 im Menü (intern 6): Erntekalender der saisonalen Früchte
function FieldListHUD:getSeasonRows()
    if self.seasonRowsCache ~= nil then return self.seasonRowsCache end
    local rows = {}
    local SP = SeasonalProduction
    if SP == nil then return rows end
    for _, def in ipairs(SP.CALENDAR or {}) do
        local season = def.file ~= nil and SP.FILE_SEASONS[def.file] or SP.SEASONS[def.fill]
        if season ~= nil then
            local title, icon = nil, nil
            local ftype = nil
            for _, n in ipairs(def.icons or { def.fill }) do
                local ok, ft = pcall(function() return g_fillTypeManager:getFillTypeByName(n) end)
                if ok and ft ~= nil then
                    ftype = ftype or ft
                    if icon == nil and ft.hudOverlayFilename ~= nil then icon = ft.hudOverlayFilename end
                end
            end
            if def.l10n ~= nil then
                title = T(def.l10n)
            elseif ftype ~= nil then
                title = ftype.title
            else
                title = def.fill
            end
            table.insert(rows, { title = title, icon = icon, season = season })
        end
    end
    if #rows > 0 then self.seasonRowsCache = rows end
    return rows
end

-- Jahreszeiten-Symbole (Pixelraster 13x13), gezeichnet aus kleinen Rechtecken
FieldListHUD.SEASON_ICONS = {
    spring = { ".............", "...#..#..#...", "...##.#.##...", "...#######...", "...#######...", "....#####....", ".....###.....", "......#......", "..#...#...#..", "..##..#..##..", "...##.#.##...", "....#####....", "......#......" },
    summer = { "......#......", "......#......", "..#.......#..", "...#..#..#...", "....#####....", "....#...#....", "##.##...##.##", "....#...#....", "....#####....", "...#..#..#...", "..#.......#..", "......#......", "......#......" },
    autumn = { ".............", ".............", "......####...", ".....#...##..", "....#...#.#..", "...#...#..#..", "..#...#...#..", "..#..#...#...", "..#.#...#....", "..##...#.....", "..#####......", ".#...........", "............." },
    winter = { "#.....#.....#", ".#....#....#.", "..#...#...#..", "...#.###.#...", "....#.#.#....", "...#.###.#...", "#############", "...#.###.#...", "....#.#.#....", "...#.###.#...", "..#...#...#..", ".#....#....#.", "#.....#.....#" },
}

-- Jahreszeiten-Symbole direkt aus dem Hauptspiel (Slices des Anbaukalenders)
FieldListHUD.SEASON_SLICES = {
    spring = "gui.icon_calendar_spring",
    summer = "gui.icon_calendar_summer",
    autumn = "gui.icon_calendar_fall",
    winter = "gui.icon_calendar_winter",
}

function FieldListHUD:getSeasonIcon(name)
    self.seasonIcons = self.seasonIcons or {}
    local ov = self.seasonIcons[name]
    if ov == nil then
        ov = false
        if g_overlayManager ~= nil and g_overlayManager.createOverlay ~= nil then
            local ok, res = pcall(function()
                return g_overlayManager:createOverlay(FieldListHUD.SEASON_SLICES[name], 0, 0, 0.02, 0.02)
            end)
            if ok and res ~= nil then ov = res end
        end
        self.seasonIcons[name] = ov
    end
    return ov or nil
end

function FieldListHUD:drawPixelIcon(rows, x, y, h, color)
    local n = #rows
    local ch = h / n
    local cw = ch / (g_screenAspectRatio or (16 / 9))
    for ry = 1, n do
        local line = rows[ry]
        for rx = 1, #line do
            if string.sub(line, rx, rx) == "#" then
                self:drawRect(x + (rx - 1) * cw, y + (n - ry) * ch, cw + 0.00008, ch + 0.00008, color)
            end
        end
    end
    return n * cw
end

function FieldListHUD:drawSeasonPage(L)
    local x0, w0 = L.ax, L.aw - 0.015
    local top = L.ay + L.ah

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x0, top, 0.036, T("title_season"))
    setTextBold(false)
    top = top - 0.060

    local rows = self:getSeasonRows()
    local bottom = L.ay + L.pad
    local bandH = 0.036 -- Jahreszeiten-Symbole
    local nameH = 0.028 -- Monatsnamen
    local headH = bandH + nameH
    local n = math.max(1, #rows)
    local rowH = math.min(0.040, (top - bottom - headH) / n)
    local total = headH + rowH * #rows
    local y = top - total

    local iconH = math.min(0.030, rowH * 0.86)
    local iconW = iconH / (g_screenAspectRatio or (16 / 9))
    local labelW = 0.012 + iconW + 0.010 + 0.120
    local cellW = (w0 - labelW - 0.008) / 12
    local gx = x0 + labelW
    local sw = g_screenWidth or 1920

    -- Monate laufen wie im Spielkalender von Maerz bis Februar
    local function pos(m) return (m - 3) % 12 + 1 end

    self:drawFrame(x0, y, w0, total, self.colorTile, self.colorBorder)

    local curM = nil
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    if env ~= nil and env.currentPeriod ~= nil then
        curM = (env.currentPeriod + 1) % 12 + 1
    end

    -- Jahreszeiten: Symbole mittig ueber je drei Monaten
    local seasons = { "spring", "summer", "autumn", "winter" }
    local symH = bandH * 0.62
    for k = 1, 4 do
        local sx = gx + (k - 1) * 3 * cellW
        local rowsIcon = FieldListHUD.SEASON_ICONS[seasons[k]]
        local symW = (symH / #rowsIcon) * #rowsIcon / (g_screenAspectRatio or (16 / 9))
        local px, py = sx + (3 * cellW - symW) / 2, top - bandH + (bandH - symH) / 2
        local ov = self:getSeasonIcon(seasons[k])
        local drawn = false
        if ov ~= nil then
            drawn = pcall(function()
                ov:setPosition(px, py)
                ov:setDimension(symW, symH)
                ov:render()
            end)
        end
        if not drawn then
            self:drawPixelIcon(rowsIcon, px, py, symH, self.colorTitle)
        end
    end

    -- Monatsnamen
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    for m = 1, 12 do
        renderText(gx + (pos(m) - 0.5) * cellW, top - bandH - nameH / 2, 0.011, self.MONTHS[m])
    end
    setTextBold(false)
    self:drawRect(x0, top - headH, w0, 0.0015, self.colorArea)

    local harvestC = { 0.757, 0.278, 0.051, 1 }
    local aspect = g_screenAspectRatio or (16 / 9)
    local function drawBar(m1, m2, ry)
        local bx1 = gx + (m1 - 1) * cellW + 0.0012
        local bx2 = gx + m2 * cellW - 0.0012
        local bh = rowH * 0.28
        local by = ry + (rowH - bh) / 2
        local rx = bh / (2 * aspect)
        self:drawRect(bx1 + rx * 0.7, by, (bx2 - bx1) - rx * 1.4, bh, harvestC)
        self:drawRect(bx1 + rx * 0.25, by + bh * 0.14, (bx2 - bx1) - rx * 0.5, bh * 0.72, harvestC)
        self:drawRect(bx1, by + bh * 0.30, (bx2 - bx1), bh * 0.40, harvestC)
    end
    for i, r in ipairs(rows) do
        local ry = top - headH - i * rowH
        if i % 2 == 0 then self:drawRect(x0 + 0.002, ry, w0 - 0.004, rowH, { 1, 1, 1, 0.04 }) end
        -- Icon
        local ix, iy = x0 + 0.008, ry + (rowH - iconH) / 2
        self:drawRect(ix, iy, iconW, iconH, self.colorIcon)
        local icon = r.icon ~= nil and self:getIcon(r.icon) or nil
        if icon ~= nil then
            icon:setPosition(ix, iy)
            icon:setDimension(iconW, iconH)
            icon:render()
        end
        -- Name
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextColor(unpack(self.colorTitle))
        setTextBold(true)
        local ts = 0.013
        local nw = getTextWidth(ts, r.title)
        local maxW = labelW - (0.012 + iconW + 0.010) - 0.004
        if nw > maxW and nw > 0 then ts = ts * maxW / nw end
        renderText(x0 + 0.012 + iconW + 0.010, ry + rowH / 2, ts, r.title)
        setTextBold(false)
        -- Erntebalken: durchgehend, mit abgerundeten Enden, mittig in der Zeile (wie im Spielkalender)
        local p1, p2 = pos(r.season.from), pos(r.season.to)
        if p2 >= p1 then
            drawBar(p1, p2, ry)
        else
            drawBar(p1, 12, ry)
            drawBar(1, p2, ry)
        end
    end

    -- senkrechte Monatstrenner; an den Jahreszeitengrenzen laenger und heller (bis in die Symbolzeile)
    for m = 0, 12 do
        local lineX = math.floor((gx + m * cellW) * sw + 0.5) / sw
        if m % 3 == 0 then
            self:drawRect(lineX, y + 0.002, 1 / sw, total - 0.002, { 0.55, 0.55, 0.55, 1 })
        else
            self:drawRect(lineX, y + 0.002, 1 / sw, total - bandH - 0.002, self.colorTrack)
        end
    end

    -- gestrichelte Linie am heutigen Tag (wandert durch den Monat)
    if curM ~= nil then
        local dpp = env.daysPerPeriod or 1
        local frac = (((env.currentDay or 1) - 1) % dpp + (env.dayTime or 0) / 86400000) / dpp
        frac = math.max(0, math.min(1, frac))
        local lx0 = math.floor((gx + (pos(curM) - 1 + frac) * cellW) * sw + 0.5) / sw
        local dy = y + 0.002
        while dy < top - bandH - 0.002 do
            self:drawRect(lx0, dy, 1.5 / sw, 0.004, { 1, 1, 1, 0.9 })
            dy = dy + 0.007
        end
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(false)
end

-- Seite 7: tatsächlich geerntete Mengen nach Frucht, Details je Feld
function FieldListHUD:getHarvestData(tab)
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    local year = ((env ~= nil and env.currentYear) or 1) - (tab - 1)
    local own = {}
    for _, e in ipairs(self.fields or {}) do own[e.id] = e end
    local byFruit, list = {}, {}
    local now = g_currentMission ~= nil and g_currentMission.time or 0
    local function isAct(id, name)
        local a = FieldListHUD.activity ~= nil and FieldListHUD.activity[id] or nil
        return tab == 1 and a ~= nil and a[name] ~= nil and now - a[name] < 4000
    end
    for id, rec in pairs(self.store or {}) do
        local e = own[id]
        local t = e ~= nil and rec.harv ~= nil and rec.harv[year] or nil
        if t ~= nil then
            -- alte Schlüssel "WR_GRASS_WINDROW" usw. (frühere Testversion) gehören zur Zeile Gras/Klee/Luzerne
            local merged = {}
            for name, l in pairs(t) do
                local pre = string.sub(name, 1, 1) == "~" and "~" or ""
                local plain = pre == "~" and string.sub(name, 2) or name
                local base = string.match(plain, "^WR_(.+)_WINDROW$")
                if base ~= nil and FieldListHUD.WINDROW_FRUITS ~= nil and FieldListHUD.WINDROW_FRUITS[base] then plain = base end
                merged[pre .. plain] = (merged[pre .. plain] or 0) + l
            end
            for name, l in pairs(merged) do
                if string.sub(name, 1, 1) ~= "~" and l > 0 then
                    local f = byFruit[name]
                    if f == nil then
                        local baseName, outName = string.match(name, "^(.-)@(.+)$")
                        local info = string.sub(name, 1, 3) ~= "WR_" and self:getEntryByFruitName(baseName or name) or nil
                        local title, icon = info ~= nil and info.fruitTitle or name, info ~= nil and info.iconFilename or nil
                        if outName ~= nil then
                            local oi = g_fillTypeManager:getFillTypeIndexByName(outName)
                            local od = oi ~= nil and g_fillTypeManager:getFillTypeByIndex(oi) or nil
                            title = string.format("%s (%s)", info ~= nil and info.fruitTitle or baseName, od ~= nil and od.title or outName)
                            if info == nil and od ~= nil then icon = od.hudOverlayFilename end
                        end
                        if string.sub(name, 1, 3) == "WR_" then
                            local fi = g_fillTypeManager:getFillTypeIndexByName(string.sub(name, 4))
                            local fd = fi ~= nil and g_fillTypeManager:getFillTypeByIndex(fi) or nil
                            if fd ~= nil then title, icon = fd.title or title, fd.hudOverlayFilename end
                        end
                        f = { name = name, title = title, icon = icon, total = 0, fields = {} }
                        byFruit[name] = f
                        list[#list + 1] = f
                    end
                    f.total = f.total + l
                    local act = isAct(id, name)
                    if act then f.active = true end
                    f.fields[#f.fields + 1] = { id = id, area = e.area or 0, liters = l, ha = (merged["~" .. name] or 0) / 10000, active = act }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    for _, f in ipairs(list) do
        table.sort(f.fields, function(a, b) return a.liters > b.liters end)
    end
    return list, year
end

function FieldListHUD:drawHarvestPage(L)
    local x0, w0 = L.ax, L.aw - 0.015
    local top = L.ay + L.ah
    self.hv = self.hv or { tab = 1, offL = 0, offR = 0 }
    local hv = self.hv
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x0, top, 0.036, T("title_harv"))
    setTextBold(false)

    -- Reiter
    hv.tabs = {}
    do
        local ts, th, gap = 0.012, 0.030, 0.006
        local tabs = { T("tab_this"), T("tab_hv_last"), T("tab_hv_prev") }
        local tx = x0 + getTextWidth(0.036, T("title_harv")) + 0.030
        local ty = top - 0.040
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        for i, title in ipairs(tabs) do
            local active = hv.tab == i
            local w = getTextWidth(ts, title) + 0.024
            self:drawFrame(tx, ty, w, th, active and self.colorArea or self.colorTile, self.colorBorder)
            setTextBold(active)
            setTextColor(unpack(active and { 0.02, 0.02, 0.02, 1 } or self.colorTitle))
            renderText(tx + 0.012, ty + th / 2, ts, title)
            setTextBold(false)
            hv.tabs[#hv.tabs + 1] = { x = tx, y = ty, w = w, h = th, tab = i }
            tx = tx + w + gap
        end
    end
    top = top - 0.060

    local list, year = self:getHarvestData(hv.tab)
    local bottom = L.ay + L.pad + 0.026
    local headH, rowH = 0.032, 0.036
    local rows = math.max(1, math.floor((top - bottom - headH) / rowH))
    local gapX = 0.012
    local lw = w0 * 0.42
    local rx = x0 + lw + gapX
    local rw = w0 - lw - gapX
    local aspect = g_screenAspectRatio or (16 / 9)

    -- gewählte Frucht prüfen
    local sel = nil
    for _, f in ipairs(list) do if f.name == hv.sel then sel = f end end
    if sel == nil then sel = list[1]; hv.sel = sel ~= nil and sel.name or nil end

    local needL = #list > rows
    local lwr = needL and (lw - 0.012) or lw
    hv.offL = math.max(0, math.min(hv.offL or 0, math.max(0, #list - rows)))
    hv.maxL = math.max(0, #list - rows)
    hv.areaL = { x = x0, y = bottom, w = lw, h = top - bottom }
    hv.areaR = { x = rx, y = bottom, w = rw, h = top - bottom }
    hv.rows = {}

    -- Kopf links
    local function head(x, w, txt, align)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextAlignment(align or RenderText.ALIGN_LEFT)
        setTextBold(true)
        setTextColor(unpack(self.colorSub))
        renderText(align == RenderText.ALIGN_RIGHT and (x + w) or x, top - headH / 2, 0.011, txt)
        setTextBold(false)
    end
    local iconH = rowH * 0.74
    local iconW = iconH / aspect
    head(x0 + 0.010 + iconW + 0.008, lw, T("hv_fruit"))
    head(x0, lwr - 0.010, T("hv_amount"), RenderText.ALIGN_RIGHT)
    self:drawRect(x0, top - headH, lw, 0.0015, self.colorArea)

    if #list == 0 then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        setTextColor(unpack(self.colorSub))
        renderText(x0 + 0.010, top - headH - 0.016, 0.014, T("hv_none"))
    end

    for i = 1, rows do
        local f = list[i + hv.offL]
        if f == nil then break end
        local ry = top - headH - i * rowH
        local active = sel ~= nil and f.name == sel.name
        self:drawFrame(x0, ry + 0.001, lwr, rowH - 0.002, active and { 0.10, 0.12, 0.06, 1 } or self.colorTile, active and self.colorArea or self.colorBorder)
        local iy = ry + (rowH - iconH) / 2
        self:drawRect(x0 + 0.010, iy, iconW, iconH, self.colorIcon)
        local ic = f.icon ~= nil and self:getIcon(f.icon) or nil
        if ic ~= nil then
            ic:setPosition(x0 + 0.010, iy); ic:setDimension(iconW, iconH); ic:render()
        end
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextBold(true)
        setTextColor(unpack(f.active and self.colorArea or self.colorTitle))
        renderText(x0 + 0.010 + iconW + 0.008, ry + rowH / 2, 0.013, f.title)
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextColor(unpack((active or f.active) and self.colorArea or self.colorTitle))
        renderText(x0 + lwr - 0.010, ry + rowH / 2, 0.013, fmtLiters(f.total))
        hv.rows[#hv.rows + 1] = { x = x0, y = ry, w = lwr, h = rowH, name = f.name }
    end

    -- Scrollleiste links
    hv.trackL, hv.thumbL = nil, nil
    if needL then
        local trackH = rows * rowH
        local thumbH = math.max(0.03, trackH * rows / #list)
        local frac = hv.maxL > 0 and (hv.offL / hv.maxL) or 0
        hv.trackL = { x = x0 + lw - 0.006, y = top - headH - trackH, w = 0.006, h = trackH }
        hv.thumbL = { x = hv.trackL.x, y = hv.trackL.y + trackH - thumbH - (trackH - thumbH) * frac, w = 0.006, h = thumbH }
        self:drawRect(hv.trackL.x, hv.trackL.y, hv.trackL.w, hv.trackL.h, self.colorTrack)
        self:drawRect(hv.thumbL.x, hv.thumbL.y, hv.thumbL.w, hv.thumbL.h, self.colorThumb)
    end

    -- rechts: Felder der gewählten Frucht
    self:drawFrame(rx, bottom, rw, top - bottom, self.colorTile, self.colorBorder)
    hv.trackR, hv.thumbR = nil, nil
    if sel ~= nil then
        local cols = {
            { t = T("hv_field"),  f = 0.16, a = RenderText.ALIGN_LEFT },
            { t = T("hv_area"),   f = 0.20, a = RenderText.ALIGN_RIGHT },
            { t = T("hv_amount"), f = 0.24, a = RenderText.ALIGN_RIGHT },
            { t = T("hv_share"),  f = 0.17, a = RenderText.ALIGN_RIGHT },
            { t = T("hv_perha"),  f = 0.23, a = RenderText.ALIGN_RIGHT },
        }
        local pad = 0.010
        local rows2 = math.max(1, math.floor((top - bottom - headH - rowH) / rowH))
        local needR = #sel.fields > rows2
        local cw = rw - 2 * pad - (needR and 0.010 or 0)
        local xs, cx = {}, rx + pad
        for k, c in ipairs(cols) do xs[k] = cx; cx = cx + cw * c.f end
        local function cellX(k)
            local c = cols[k]
            return c.a == RenderText.ALIGN_RIGHT and (xs[k] + cw * c.f - 0.004) or xs[k]
        end
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(unpack(self.colorSub))
        for k, c in ipairs(cols) do
            setTextAlignment(c.a)
            renderText(cellX(k), top - headH / 2, 0.011, c.t)
        end
        setTextBold(false)
        self:drawRect(rx, top - headH, rw, 0.0015, self.colorArea)

        local nf = #sel.fields
        hv.maxR = math.max(0, nf - rows2)
        hv.offR = math.max(0, math.min(hv.offR or 0, hv.maxR))
        for i = 1, rows2 do
            local fd = sel.fields[i + hv.offR]
            if fd == nil then break end
            local ry = top - headH - i * rowH
            if i % 2 == 0 then self:drawRect(rx + 0.002, ry, rw - 0.004, rowH, { 1, 1, 1, 0.04 }) end
            setTextColor(unpack(fd.active and self.colorArea or self.colorTitle))
            local vals = {
                string.format("%s %d", T("hv_field_s"), fd.id),
                string.format("%.2f ha", fd.area),
                fmtLiters(fd.liters),
                string.format("%.1f %%", sel.total > 0 and fd.liters / sel.total * 100 or 0),
                (fd.ha or 0) > 0.005 and fmtLiters(fd.liters / fd.ha) or "-",
            }
            for k, c in ipairs(cols) do
                setTextAlignment(c.a)
                setTextBold(k == 1)
                renderText(cellX(k), ry + rowH / 2, 0.013, vals[k])
            end
            setTextBold(false)
        end
        hv.trackR, hv.thumbR = nil, nil
        if needR then
            local trackH = rows2 * rowH
            local thumbH = math.max(0.03, trackH * rows2 / nf)
            local frac = hv.maxR > 0 and (hv.offR / hv.maxR) or 0
            hv.trackR = { x = rx + rw - 0.012, y = top - headH - trackH, w = 0.006, h = trackH }
            hv.thumbR = { x = hv.trackR.x, y = hv.trackR.y + trackH - thumbH - (trackH - thumbH) * frac, w = 0.006, h = thumbH }
            self:drawRect(hv.trackR.x, hv.trackR.y, hv.trackR.w, hv.trackR.h, self.colorTrack)
            self:drawRect(hv.thumbR.x, hv.thumbR.y, hv.thumbR.w, hv.thumbR.h, self.colorThumb)
        end
        -- Summenzeile
        local sy = bottom
        self:drawRect(rx, sy + rowH, rw, 0.0015, self.colorArea)
        local totArea = 0
        local totHa = 0
        for _, fd in ipairs(sel.fields) do totArea = totArea + fd.area; totHa = totHa + (fd.ha or 0) end
        local vals = { T("hv_sum"), string.format("%.2f ha", totArea), fmtLiters(sel.total), "100 %", totHa > 0.005 and fmtLiters(sel.total / totHa) or "-" }
        setTextBold(true)
        setTextColor(unpack(self.colorArea))
        for k, c in ipairs(cols) do
            setTextAlignment(c.a)
            renderText(cellX(k), sy + rowH / 2, 0.013, vals[k])
        end
        setTextBold(false)
    end

    -- Hinweis
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextColor(unpack(self.colorSub))
    renderText(x0, L.ay + L.pad + 0.016, 0.0105, string.format(T("hv_hint"), year))
end

-- Wird vom Hook aufgerufen, solange das ESC-Menü gezeichnet wird
function FieldListHUD:drawInMenu()
    local menu = g_inGameMenu
    if self.bg == nil or self.frame == nil or menu == nil then
        return
    end

    if menu.currentPage ~= self.frame and menu.currentPageName ~= self.pageName then
        self.layout = nil
        self.confirm = nil
        return
    end

    if g_time ~= nil and (g_time - (self.lastMenuRefresh or 0)) > 1000 then
        self.lastMenuRefresh = g_time
        self:refreshFields()
    end

    if self.page == 6 and FieldListHUD.seasonal ~= true then self.page = 1 end
    if self.prevPage == 6 and FieldListHUD.seasonal ~= true then self.prevPage = 1 end
    local selected = self:getSelectedEntry()
    local L = self:computeLayout()
    self.layout = L
    self.planBtn = nil
    self.tipRectPrev = self.tipRect
    self.tipRect = nil
    self.pendingTip = nil

    -- Sicherheitsabfrage: Text der Seite lässt sich nicht von Flächen überdecken, deshalb wird die Seite dahinter nicht gezeichnet
    if self.confirm ~= nil then
        self:drawConfirm(L)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        setTextBold(false)
        setTextColor(1, 1, 1, 1)
        return
    end

    if self.page == 2 or self.page == 3 or self.page == 4 or self.page == 5 or self.page == 6 or self.page == 7 then
        self.hitRects = {}
        if self.page == 7 then
            self:drawHarvestPage(L)
        elseif self.page == 6 then
            self:drawSeasonPage(L)
        elseif self.page == 5 then
            self:drawOptionsPage(L)
        elseif self.page == 2 then
            self:drawTablePage(L)
        elseif self.page == 4 then
            self:drawWorkPage(L)
        else
            self:drawFruitPage(L)
        end
        self:drawPageArrows(L)
        self:drawWorkTip()
        self:drawConfirm(L)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        setTextBold(false)
        setTextColor(1, 1, 1, 1)
        return
    end

    -- Linkes Panel
    self:drawFrame(L.listPanel.x, L.listPanel.y, L.listPanel.w, L.listPanel.h, self.colorTile, self.colorBorder)

    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(L.titleX, L.titleY - 0.004, 0.024, T("title_fields"))
    setTextBold(false)

    -- Filter-Schaltflächen
    self:drawFilterButtons(L.filterBtns)

    if #self.visible == 0 then
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(unpack(self.colorSub))
        renderText(L.list.x, L.list.y + L.list.h, 0.013,
            #self.fields == 0 and T("no_fields") or T("no_fields_sel"))
    end
    for _, t in ipairs(L.tiles) do
        local entry = self.visible[t.index]
        if not rectsOverlap(t, self.tipRectPrev) then
            self:drawTile(entry, t.x, t.y, t.w, t.h, selected ~= nil and entry.id == selected.id)
        end
    end

    if L.track ~= nil then
        self:drawRect(L.track.x, L.track.y, L.track.w, L.track.h, self.colorTrack)
        self:drawRect(L.thumb.x, L.thumb.y, L.thumb.w, L.thumb.h, self.colorThumb)
    end

    -- Rechter Bereich
    self.hitRects = {}
    self:drawDetail(L.detail, selected)
    self:drawPageArrows(L)
    self:drawWorkTip()
    self:drawConfirm(L)

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

------------------------------------------------------------------------
-- Maus: Scrollen mit dem Mausrad, Auswählen per Linksklick
------------------------------------------------------------------------

local function inRect(r, x, y)
    return r ~= nil and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Gibt true zurück, wenn das Ereignis verarbeitet wurde
function FieldListHUD:scrollToY(posY)
    local L = self.layout
    if L == nil or L.track == nil or self.maxOffset <= 0 then
        return
    end
    local range = L.track.h - L.thumb.h
    if range <= 0 then
        return
    end
    -- Oberkante des Tracks = Offset 0
    local frac = ((L.track.y + L.track.h - L.thumb.h / 2) - posY) / range
    frac = math.max(0, math.min(1, frac))
    self.scrollOffset = math.floor(frac * self.maxOffset + 0.5)
end

function FieldListHUD:onMouse(posX, posY, isDown, isUp, button)
    if isDown or isUp then
        self.p3Dirty = true
        self.wkDirty = true
        self.ratingCache = nil
    end
    local L = self.layout
    if L == nil then
        self.dragging = false
        return false
    end

    self.mouseX, self.mouseY = posX, posY

    -- Sicherheitsabfrage hat Vorrang vor allem anderen
    if self.confirm ~= nil then
        if isDown and Input ~= nil and button == Input.MOUSE_BUTTON_LEFT then
            local cb = self.confirmBtns
            local c = self.confirm
            if cb ~= nil and inRect(cb.yes, posX, posY) then
                self.confirm = nil
                pcall(c.onYes)
            elseif cb ~= nil and inRect(cb.no, posX, posY) then
                self.confirm = nil
            end
        end
        return true
    end

    if not self.mouseLogged then
        self.mouseLogged = true
    end

    -- Scrollleiste ziehen
    if self.dragging then
        if isUp then
            self.dragging = false
        else
            self:scrollToY(posY)
        end
        return true
    end

    if Input == nil then
        return false
    end

    local wheelUp   = Input.MOUSE_BUTTON_WHEEL_UP
    local wheelDown = Input.MOUSE_BUTTON_WHEEL_DOWN
    local left      = Input.MOUSE_BUTTON_LEFT

    -- Einstellungs-Button: öffnet die Optionen bzw. springt zurück
    if isDown and button == left and inRect(self.gearBtn, posX, posY) then
        if self.page == 5 then
            self.page = self.prevPage or 1
        else
            self.prevPage = self.page
            self.page = 5
        end
        self.popup = nil
        self.confirm = nil
        self.dragging, self.tblDragging, self.p3Dragging, self.wkDragging = false, false, false, false
        return true
    end

    -- Seitenwechsel per Pfeile (beide Seiten)
    if isDown and button == left then
        for _, b in pairs(self.pageBtns or {}) do
            if inRect(b, posX, posY) then
                self.page = b.page
                self.popup = nil
                self.confirm = nil
                self.dragging = false
                self.tblDragging = false
                self.p3Dragging = false
                self.wkDragging = false
                return true
            end
        end
    end

    if self.page == 5 then
        if self:optionsMouse(posX, posY, isDown, button) then return true end
        return true
    end

    if self.page == 6 then
        return true
    end

    if self.page == 7 then
        local hv = self.hv
        if hv ~= nil then
            local function dragTo(which, y)
                local tr, th = hv["track" .. which], hv["thumb" .. which]
                local mx = hv["max" .. which]
                if tr == nil or th == nil or not mx or mx <= 0 then return end
                local range = tr.h - th.h
                if range <= 0 then return end
                local frac = math.max(0, math.min(1, ((tr.y + tr.h - th.h / 2) - y) / range))
                hv["off" .. which] = math.floor(frac * mx + 0.5)
            end
            if hv.drag ~= nil then
                if isUp then hv.drag = nil else dragTo(hv.drag, posY) end
                return true
            end
            if isDown and button == left then
                for _, w in ipairs({ "L", "R" }) do
                    local tr = hv["track" .. w]
                    if tr ~= nil and inRect({ x = tr.x - 0.006, y = tr.y, w = tr.w + 0.012, h = tr.h }, posX, posY) then
                        hv.drag = w
                        dragTo(w, posY)
                        return true
                    end
                end
            end
            if isDown and button == left then
                for _, t in ipairs(hv.tabs or {}) do
                    if inRect(t, posX, posY) then hv.tab = t.tab; hv.offL = 0; hv.offR = 0; hv.sel = nil; return true end
                end
                for _, r in ipairs(hv.rows or {}) do
                    if inRect(r, posX, posY) then hv.sel = r.name; hv.offR = 0; return true end
                end
            end
            if isDown and (button == wheelUp or button == wheelDown) then
                local step = (button == wheelUp) and -1 or 1
                if inRect(hv.areaL, posX, posY) then
                    hv.offL = math.max(0, math.min((hv.offL or 0) + step, hv.maxL or 0))
                elseif inRect(hv.areaR, posX, posY) then
                    hv.offR = math.max(0, math.min((hv.offR or 0) + step, hv.maxR or 0))
                end
                return true
            end
        end
        return true
    end

    if isDown and button == left and self.page ~= 3 and inRect(self.planBtn, posX, posY) then
        if self.page == 1 then
            self:planOneNext(self.selectedId)
        else
            self:askConfirm(T("confirm_plan"), T("confirm_plan2"), function() self:planAllNext() end)
        end
        return true
    end

    if self.page == 3 then
        local p3 = self.p3
        -- Scrollleiste ziehen
        if self.p3Dragging then
            if isUp then
                self.p3Dragging = false
            else
                self:scrollP3ToY(posY)
            end
            return true
        end
        if isDown and button == left and p3 ~= nil and p3.track ~= nil and self.popup == nil then
            local hit = { x = p3.track.x - 0.006, y = p3.track.y, w = p3.track.w + 0.012, h = p3.track.h }
            if inRect(hit, posX, posY) then
                self.p3Dragging = true
                self:scrollP3ToY(posY)
                return true
            end
        end
        if isDown and button == left and p3 ~= nil then
            for _, t in ipairs(p3.tabs or {}) do
                if inRect(t, posX, posY) then
                    self.p3Mode = t.mode
                    self.popup = nil
                    return true
                end
            end
        end
        -- Klick auf eine Zeile öffnet/schließt das Detailfenster; Klick irgendwo sonst schließt es
        if isDown and button == left then
            if self.popup ~= nil then
                self.popup = nil
                return true
            end
            local item = self:getRowAt(posX, posY)
            if item ~= nil then
                self.popup = { item = item }
                return true
            end
        end
        if p3 ~= nil and isDown and (button == wheelUp or button == wheelDown) and inRect(p3.area, posX, posY) then
            p3.offset = math.max(0, math.min((p3.offset or 0) + ((button == wheelUp) and -1 or 1), p3.max))
            return true
        end
        return false
    end

    -- Seite "Arbeiten" (intern 4)
    if self.page == 4 then
        local t = self.wk or { offset = 0, max = 0 }
        if self.wkDragging then
            if isUp then
                self.wkDragging = false
            else
                self:scrollWorkToY(posY)
            end
            return true
        end
        if isDown and (button == wheelUp or button == wheelDown) and t.area ~= nil and inRect(t.area, posX, posY) then
            t.offset = math.max(0, math.min((t.offset or 0) + ((button == wheelUp) and -1 or 1), t.max))
            return true
        end
        if isDown and button == left then
            for _, b in ipairs(self.filterBtns4 or {}) do
                if inRect(b, posX, posY) then
                    self.wkFilter = b.mode
                    self.wkDirty = true
                    t.offset = 0
                    return true
                end
            end
            for _, hd in ipairs(t.heads or {}) do
                if inRect(hd, posX, posY) then
                    if self.workCol == hd.key then
                        self.workDir = -(self.workDir or 1)
                    else
                        self.workCol = hd.key
                        self.workDir = hd.isKind and -1 or 1 -- Arbeitsspalten: zuerst die Felder mit Arbeit
                    end
                    t.offset = 0
                    return true
                end
            end
            if t.track ~= nil then
                local hit = { x = t.track.x - 0.006, y = t.track.y, w = t.track.w + 0.012, h = t.track.h }
                if inRect(hit, posX, posY) then
                    self.wkDragging = true
                    self:scrollWorkToY(posY)
                    return true
                end
            end
            -- Klick auf eine Arbeit: in den nächsten Monat verschieben bzw. zurückholen
            for _, cell in ipairs(t.cells or {}) do
                if inRect(cell, posX, posY) then
                    self:togglePostpone(cell.id, cell.kind)
                    return true
                end
            end
            -- Klick auf eine Zeile: zum Feld auf Seite 1 springen
            for _, r in ipairs(t.rows or {}) do
                if inRect(r, posX, posY) then
                    self.wkDragging = false
                    self:jumpToField(r.id)
                    return true
                end
            end
        end
        return false
    end

    -- Seite 2: Tabelle scrollen
    if self.page == 2 then
        local t = self.tbl
        if self.tblDragging then
            if isUp then
                self.tblDragging = false
            else
                self:scrollTableToY(posY)
            end
            return true
        end
        if isDown and (button == wheelUp or button == wheelDown) and inRect(t.area, posX, posY) then
            t.offset = math.max(0, math.min((t.offset or 0) + ((button == wheelUp) and -1 or 1), t.max))
            return true
        end
        if isDown and button == left then
            for _, b in ipairs(self.filterBtns2 or {}) do
                if inRect(b, posX, posY) then
                    self.tblFilter = b.mode
                    t.offset = 0
                    return true
                end
            end
        end
        if isDown and button == left and t.track ~= nil then
            local hit = { x = t.track.x - 0.006, y = t.track.y, w = t.track.w + 0.012, h = t.track.h }
            if inRect(hit, posX, posY) then
                self.tblDragging = true
                self:scrollTableToY(posY)
                return true
            end
        end
        if isDown and button == left and inRect(self.acceptBtn, posX, posY) then
            self:askConfirm(T("confirm_accept"), T("confirm_accept2"), function() self:acceptAutoNext() end)
            return true
        end
        -- Klick auf eine Zeile: zum Feld auf Seite 1 springen
        if isDown and button == left then
            for _, r in ipairs(t.hitRows or {}) do
                if inRect(r, posX, posY) then
                    self:jumpToField(r.id)
                    return true
                end
            end
        end
        return false
    end

    if isDown and (button == wheelUp or button == wheelDown) then
        -- Mausrad nur über dem linken Panel
        if inRect(L.listPanel, posX, posY) then
            local step = (button == wheelUp) and -1 or 1
            self.scrollOffset = math.max(0, math.min(self.scrollOffset + step, self.maxOffset))
            return true
        end
        return false
    end

    if isDown and button == left then
        local hr = self.hitRects
        if hr ~= nil then
            if inRect(hr.unused, posX, posY) and self.selectedId ~= nil then
                local rec = self:getRecord(self.selectedId)
                rec.unused = not rec.unused
                self:refreshFields()
                self:applyFilter()
                return true
            end
            if (inRect(hr.ccPrev, posX, posY) or inRect(hr.ccNext, posX, posY)) and self.selectedId ~= nil then
                local rec = self:getRecord(self.selectedId)
                rec.ccPlanned = not rec.ccPlanned -- Optionen: keine / Ölrettich
                return true
            end
            if inRect(hr.undo, posX, posY) and self.selectedId ~= nil then
                self:undoAdvance(self.selectedId)
                return true
            end
            if inRect(hr.advance, posX, posY) and self.selectedId ~= nil then
                local rcA = self:getRecord(self.selectedId)
                if rcA.next ~= nil then -- ohne gewählte Folgefrucht passiert nichts, also auch keine Abfrage
                    local idA = self.selectedId
                    self:askConfirm(string.format(T("confirm_advance"), tostring(idA)), T("confirm_advance2"),
                        function() self:advanceFruit(idA) end)
                end
                return true
            end
            if inRect(hr.curSilage, posX, posY) and self.selectedId ~= nil then
                local rcS = self:getRecord(self.selectedId)
                rcS.curSilage = not rcS.curSilage
                self.p3Dirty = true
                return true
            end
            if inRect(hr.acceptOne, posX, posY) and self.selectedId ~= nil then
                local rcA = self:getRecord(self.selectedId)
                if rcA.autoNext and rcA.next ~= nil then rcA.autoNext = false end
                return true
            end
            if inRect(hr.clearNext, posX, posY) and self.selectedId ~= nil then
                local rc = self:getRecord(self.selectedId)
                rc.next = nil
                rc.silage = nil
                rc.autoNext = false
                rc.autoOff = true -- wie "keine Auswahl": Automatik für dieses Feld aus
                return true
            end
            if inRect(hr.prev, posX, posY) then self:cycleNextFruit(-1) return true end
            if inRect(hr.next, posX, posY) then self:cycleNextFruit(1) return true end
        end

        -- Scrollleiste (etwas breiter klickbar)
        if L.track ~= nil then
            local hit = { x = L.track.x - 0.006, y = L.track.y, w = L.track.w + 0.012, h = L.track.h }
            if inRect(hit, posX, posY) then
                self.dragging = true
                self:scrollToY(posY)
                return true
            end
        end

        for _, b in ipairs(L.filterBtns or {}) do
            if inRect(b, posX, posY) then
                self:setFilter(b.mode)
                return true
            end
        end

        for _, t in ipairs(L.tiles) do
            if inRect(t, posX, posY) then
                local entry = self.visible[t.index]
                if entry ~= nil then
                    self.selectedId = entry.id
                    return true
                end
            end
        end
    end

    return false
end

------------------------------------------------------------------------
-- Fruchtfolge-Bewertung (Richtlinie): Stufe für N+1 aus Historie N bis N-6
------------------------------------------------------------------------

-- Gruppen (Kürzel wie in der Richtlinie); unbekannte Früchte = "UN" (neutral)
FieldListHUD.GROUP = {
    WHEAT = "WG", BARLEY = "WG", RYE = "WG", SPELT = "WG", TRITICALE = "WG",
    OAT = "SG", SORGHUM = "SG", SUMMERWHEAT = "SG", SUMMERBARLEY = "SG", BUCKWHEAT = "SG",
    MAIZE = "MA",
    CANOLA = "OE", SUNFLOWER = "OE", MUSTARD = "OE", POPPY = "OE", LINSEED = "OE",
    SOYBEAN = "KL", PEA = "KL", PEAS = "KL", GREENBEAN = "KL", BEANS = "KL", LENTILS = "KL",
    ALFALFA = "FL", CLOVER = "FL",
    SUGARBEET = "RU", BEETROOT = "RU",
    POTATO = "KW", CARROT = "KW", PARSNIP = "KW",
    SPINACH = "GE", ONION = "GE",
    COTTON = "FA", HEMP = "FA",
    GRASS = "GR", FIELDGRASS = "GR", MEADOW = "GR",
    SUGARCANE = "DS", POPLAR = "DS", GRAPE = "DS", OLIVE = "DS", LAVENDER = "DS",
    RICE = "NF", RICELONGGRAIN = "NF",
    OILSEEDRADISH = "ZF",
}
FieldListHUD.GROUP_TYPE = { WG = "halm", SG = "halm", MA = "halm", NF = "halm",
    OE = "blatt", KL = "blatt", FL = "blatt", RU = "blatt", KW = "blatt", GE = "blatt", FA = "blatt", GR = "blatt" }
-- Anbaupause in Jahren (Hauptfrüchte mit eigener Pause)
FieldListHUD.PAUSE = { OE = 3, KL = 4, FL = 4, RU = 3, KW = 3, GE = 2, FA = 2 }
FieldListHUD.STRONG = { WG = true, MA = true, OE = true, RU = true, KW = true }
FieldListHUD.LATE = { MA = true, RU = true, KW = true, FA = true }
FieldListHUD.MATRIX_COLS = { "WG", "SG", "MA", "OE", "KL", "RU", "KW", "GE", "FA" }
FieldListHUD.MATRIX = {
    WG = { -1,  0,  1,  1,  1,  1,  1,  1,  0 },
    SG = {  0, -1,  1,  1,  1,  1,  1,  1,  0 },
    MA = { -1,  1, -1,  0,  1,  0,  0,  0,  0 },
    OE = {  2,  1,  1, -2, -1,  0,  1,  0,  0 },
    KL = {  2,  1,  2,  1, -2,  1,  1,  1,  1 },
    FL = {  2,  2,  2,  1, -2,  1,  1,  1,  1 },
    RU = {  1,  1,  0, -1,  1, -2, -1,  0,  0 },
    KW = {  1,  1,  1,  0,  1, -1, -2,  0,  0 },
    GE = {  1,  1,  1,  0,  0,  0,  0, -2,  0 },
    FA = {  0,  1,  1,  0,  1,  0,  0,  0, -1 },
    GR = {  1,  1,  2,  0,  1, -1, -1,  0,  0 },
}

function FieldListHUD.getGroup(name)
    if name == nil or name == "" then
        return nil
    end
    return FieldListHUD.GROUP[string.upper(name)] or "UN"
end

local function matrixValue(gN, gC)
    local row = FieldListHUD.MATRIX[gN]
    if row == nil then
        return 0
    end
    for i, c in ipairs(FieldListHUD.MATRIX_COLS) do
        if c == gC then
            return row[i]
        end
    end
    return nil -- Spalte nicht in der Matrix
end

-- Bewertet die Frucht cand als N+1 für das Feld mit dem Datensatz rec.
-- Gibt { points = -2..2, blocked = bool, reasons = { {key, value}, ... } } zurück.
FieldListHUD.MATRIX_PCT = {
    [2] = { 15, 10, 5 }, [1] = { 10, 5, 2 }, [0] = { 0, 0, 0 }, [-1] = { -10, -10, -5 }, [-2] = { -25, -20, -10 },
}

-- Ertragswirkung (Richtlinie, Abschnitt Ertragswirkung): Prozentwerte je Regel, Faktor 50 bis 140 %
function FieldListHUD:calcRotationPct(rec, cand, gC, nName, gN, hits, selfCrop)
    local parts = {}
    local function addP(key, v)
        if v ~= 0 then table.insert(parts, { key = key, v = v }) end
    end
    local hist = rec.hist or {}
    local seq = { nName }
    local hs = rec.cur ~= nil and 1 or 2
    seq[2] = hist[hs]
    seq[3] = hist[hs + 1]
    for j = 1, 3 do
        local g = FieldListHUD.getGroup(seq[j])
        if g ~= nil then
            local m = matrixValue(g, gC)
            if m ~= nil then
                local row = FieldListHUD.MATRIX_PCT[m]
                addP(j == 1 and "r_matrix" or (j == 2 and "p_n1" or "p_n2"), row ~= nil and row[j] or 0)
            elseif j == 1 then
                local tN, tC = FieldListHUD.GROUP_TYPE[g], FieldListHUD.GROUP_TYPE[gC]
                if tN ~= nil and tC ~= nil and tN ~= tC then addP("r_change", 5) end
            end
        end
    end
    if hits ~= nil and hits > 0 then addP("r_pause", -10 * hits) end
    if rec.ccPending or rec.ccPlanned then
        addP("r_cc", (gC == "OE" and FieldListHUD.isBrassica(cand)) and -10 or 10)
    end
    if seq[1] ~= nil and seq[2] ~= nil and FieldListHUD.sameFruit(string.upper(seq[1]), string.upper(cand))
        and FieldListHUD.sameFruit(string.upper(seq[2]), string.upper(cand)) then
        addP("p_mono", -5)
    end
    if seq[1] == nil then addP("p_fallow", 5) end
    if seq[2] == nil then addP("p_fallow", 5) end
    local sum = 0
    for _, q in ipairs(parts) do sum = sum + q.v end
    local f = math.max(50, math.min(140, 100 + sum))
    if selfCrop then f = math.min(f, 75) end
    return parts, f
end

-- Kreuzblütler unter den Ölfrüchten (Raps, Senf): nur für sie gilt die Zwischenfrucht-Regel mit Ölrettich;
-- das späte Räumen (W6) betrifft nur den im Spätsommer gesäten Raps. Leinsamen, Sonnenblumen, Mohn sind ausgenommen.
FieldListHUD.BRASSICA = { CANOLA = true, MUSTARD = true }
function FieldListHUD.isBrassica(name)
    return name ~= nil and FieldListHUD.BRASSICA[string.upper(name)] == true
end

function FieldListHUD:getRotationFactor(rec, cand)
    if rec == nil or cand == nil or FieldListHUD.rotYield ~= true then return 1 end
    local r = self:rateCandidate(rec, cand)
    return (r ~= nil and r.factor or 100) / 100
end

function FieldListHUD:rateCandidate(rec, cand)
    local res = { points = 0, blocked = false, reasons = {} }
    local gC = FieldListHUD.getGroup(cand)
    local nName = rec.cur or (rec.hist ~= nil and rec.hist[1]) or nil
    local gN = FieldListHUD.getGroup(nName)
    local function add(key, v)
        if v ~= 0 then
            res.points = res.points + v
            table.insert(res.reasons, { key = key, v = v })
        end
    end
    -- H4: Frucht muss auf der geladenen Karte existieren und aussäbar sein
    local ftC = g_fruitTypeManager:getFruitTypeByName(cand)
    local available = false
    if ftC ~= nil then
        for _, o in ipairs(self:getFruitOptions()) do
            if o.name == string.upper(cand) then available = true break end
        end
    end
    if not available then
        res.blocked = true
        res.reasons = { { key = "h_unknown", v = 0 } }
        return res
    end
    -- H1: Saatfenster (nur bei aktivem Saisonwachstum): Frucht, die nie gesät werden kann, ist gesperrt
    local seasonC = self:parseSeason(ftC)
    if seasonC ~= nil and next(seasonC.plant) == nil and next(seasonC.harvest) ~= nil then
        res.blocked = true
        res.reasons = { { key = "h_season", v = 0 } }
        return res
    end
    -- H3: Nassfeld-Früchte nur auf Nassfeldern (Feldart wird aus der Vorfrucht abgeleitet)
    if gN ~= nil and gN ~= "UN" and (gN == "NF") ~= (gC == "NF") then
        res.blocked = true
        res.reasons = { { key = "h_field", v = 0 } }
        return res
    end
    -- W7: Selbstfolge ist immer schlecht
    if nName ~= nil and FieldListHUD.sameFruit(string.upper(nName), string.upper(cand)) then
        res.points = -2
        res.reasons = { { key = "r_self", v = -2 } }
        res.pct, res.factor = self:calcRotationPct(rec, cand, gC, nName, gN, 0, true)
        return res
    end
    -- W1: Grundstufe aus der Matrix; fehlt die Gruppe in der Matrix, gilt W3 (Halm/Blatt-Wechsel)
    if gN ~= nil then
        local m = matrixValue(gN, gC)
        if m ~= nil then
            add("r_matrix", m)
        else
            local tN, tC = FieldListHUD.GROUP_TYPE[gN], FieldListHUD.GROUP_TYPE[gC]
            if tN ~= nil and tC ~= nil and tN ~= tC then
                add("r_change", 1)
            end
        end
    end
    -- W2: Anbaupause, geprüft bis N-6; Getreide und Mais nur beim dritten Jahr in Folge
    local hist = rec.hist or {}
    local hits = 0
    if gC == "WG" or gC == "SG" or gC == "MA" then
        if gN == gC and FieldListHUD.getGroup(hist[1]) == gC then
            hits = 1
            if FieldListHUD.getGroup(hist[2]) == gC then hits = 2 end
        end
    elseif FieldListHUD.PAUSE[gC] ~= nil then
        for i = 1, math.min(FieldListHUD.PAUSE[gC], FieldListHUD.MAX_HIST) do
            if FieldListHUD.getGroup(hist[i]) == gC then hits = hits + 1 end
        end
    end
    if hits >= 2 then add("r_pause", -2) elseif hits == 1 then add("r_pause", -1) end
    -- W4: Leguminose als N-1 vor stark zehrender Frucht
    local g1 = FieldListHUD.getGroup(hist[1])
    if (g1 == "KL" or g1 == "FL") and FieldListHUD.STRONG[gC] then
        add("r_legume", 1)
    end
    -- W5: Zwischenfrucht (Kreuzblütler wie Ölrettich) zwischen N und N+1
    if rec.ccPending or rec.ccPlanned then
        if gC == "OE" and FieldListHUD.isBrassica(cand) then add("r_cc", -1) else add("r_cc", 1) end
    end
    -- H5: geplante Zwischenfrucht muss nach der Ernte von N ins Saatfenster passen und vor der Saat von N+1 stehen können
    if rec.ccPlanned and not rec.ccPending and nName ~= nil then
        local ftN = g_fruitTypeManager:getFruitTypeByName(nName)
        local ftZ = g_fruitTypeManager:getFruitTypeByName("OILSEEDRADISH")
        local sN = ftN ~= nil and self:parseSeason(ftN) or nil
        local sZ = ftZ ~= nil and self:parseSeason(ftZ) or nil
        if sN ~= nil and sZ ~= nil and seasonC ~= nil and not FieldListHUD.MULTI_CUT[string.upper(nName)] then
            local hEnd = nil
            for q = 1, 12 do
                if sN.harvest[q] and not sN.harvest[q % 12 + 1] then hEnd = q end
            end
            if hEnd ~= nil then
                local function dist(a, b) return (b - a) % 12 end
                local sStart = 13
                for q = 1, 12 do
                    if seasonC.plant[q] then sStart = math.min(sStart, dist(hEnd, q)) end
                end
                local fits = false
                for q = 1, 12 do
                    if sZ.plant[q] and dist(hEnd, q) < sStart then fits = true end
                end
                if not fits then
                    res.blocked = true
                    res.reasons = { { key = "h_cc", v = 0 } }
                    return res
                end
            end
        end
    end
    -- W6: spätes Räumen vor Wintergetreide oder Raps
    if gN ~= nil and FieldListHUD.LATE[gN] and (gC == "WG" or (gC == "OE" and string.upper(cand) == "CANOLA")) then
        add("r_late", -1)
    end
    res.points = math.max(-2, math.min(2, res.points))
    res.pct, res.factor = self:calcRotationPct(rec, cand, gC, nName, gN, hits, false)
    return res
end

function FieldListHUD:getLevelInfo(r)
    if r == nil then return nil, nil end
    if r.blocked then return T("lvl_block"), { 0.75, 0.25, 0.25, 1 } end
    local p = r.points
    if p >= 2 then return T("lvl_p2"), self.colorArea end
    if p == 1 then return T("lvl_p1"), { 0.55, 0.78, 0.35, 1 } end
    if p == 0 then return T("lvl_0"), self.colorSub end
    if p == -1 then return T("lvl_m1"), self.colorWork end
    return T("lvl_m2"), { 1, 0.4, 0.4, 1 }
end

-- Planung N+1 per Knopf (einmalig): nur Hauptfrüchte mit Fehlmenge im nächsten Jahr und mindestens Stufe "Gut".
-- Felder mit Handwahl bleiben unberührt; frühere Auto-Vorschläge werden neu berechnet.
function FieldListHUD:planAllNext()
    local planned = 0
    local ok, err = pcall(function()
        for _, e in ipairs(self.fields or {}) do
            local r0 = self.store[e.id]
            if r0 ~= nil and r0.autoNext and r0.next ~= nil then
                r0.next = nil
                r0.silage = nil
                r0.autoNext = false
            end
        end
        local list = self:buildPage3List()
        -- Fehlmengen je Horizont: [1] = Ernte im nächsten Jahr, [2] = Ernte in 2 Jahren
        local shortH, shortWH = { {}, {} }, { {}, {} }
        -- Stroh (auch Hülsenfrucht-Stroh): Fehlmenge je Strohsorte, gedeckt von den Früchten, die diese Sorte liefern
        local shortS = { {}, {} }
        for _, it in ipairs(list) do
            if it.isStraw and it.strawFill ~= nil and (it.demand or 0) > 0 then
                local shs = self:getStockShortages(it)
                shortS[1][it.strawFill] = shs[2]
                shortS[2][it.strawFill] = shs[3]
            elseif it.isSilage and (it.demand or 0) > 0 then
                -- Silage/Häckselgut: Fehlmenge wird vom Mais gedeckt (Schlüssel "MAIZE_CHAFF")
                local shs = self:getStockShortages(it)
                shortS[1]["MAIZE_CHAFF"] = shs[2]
                shortS[2]["MAIZE_CHAFF"] = shs[3]
            end
        end
        for _, it in ipairs(list) do
            if it.name ~= nil and not it.isAnimal and not it.isStraw and not it.isSilage and not it.isWindrow and not it.isHeader
                and not it.multiCut and not FieldListHUD.MULTI_CUT[it.name] then
                -- Fehlmenge nach Verrechnung mit dem Lager (kumulativ über die Jahre)
                local shs = self:getStockShortages(it)
                shortH[1][it.name] = shs[2]
                shortH[2][it.name] = shs[3]
            end
        end
        -- Schwad-Zeilen (z. B. Flachsschwad, Hanfschwad): Fehlmenge gehört zur Frucht, die den Schwad liefert
        for _, it in ipairs(list) do
            if it.isWindrow and it.name ~= nil then
                local shs = self:getStockShortages(it)
                shortWH[1][it.name] = (shortWH[1][it.name] or 0) + shs[2]
                shortWH[2][it.name] = (shortWH[2][it.name] or 0) + shs[3]
            end
        end
        local ALIAS = FieldListHUD.FRUIT_ALIAS
        local allowed = { WG = true, SG = true, MA = true, OE = true, KL = true, RU = true, KW = true, GE = true, FA = true }
        local opts = self:getFruitOptions()
        -- Runde 1: nur "Gut" und besser (Felder ohne Historie: "Neutral"); Runde 2: für noch fehlende Mengen auch "Neutral"
        for pass = 1, 2 do
        for _, e in ipairs(self.fields or {}) do
            local rec = self:getRecord(e.id)
            -- Sperre für Dauerkulturen gilt nur, solange sie wirklich noch auf dem Feld stehen (oder von Hand als aktuell gesetzt sind).
            -- Ist das Feld nach der Ernte bearbeitet und leer, darf es wieder verplant werden (rec.cur bleibt nur als Vorfrucht stehen).
            local gCur = nil
            if rec ~= nil then
                if rec.manual and rec.cur ~= nil then
                    gCur = FieldListHUD.getGroup(rec.cur)
                elseif e.fruitName ~= nil then
                    gCur = FieldListHUD.getGroup(e.fruitName)
                end
            end
            -- Steht noch eine Frucht, die erst nach dem Jahreswechsel geerntet wird (z. B. Raps), liefert N+1 erst
            -- im übernächsten Jahr und deckt die Fehlmenge des nächsten Jahres nicht
            local curIndex, curNm = nil, nil
            local ov, ovIndex = self:getCurrentOverride(e)
            if ov ~= nil then
                curIndex, curNm = ovIndex, string.upper(rec.cur or "")
            elseif e.fruitIndex ~= nil and e.growthState ~= nil and e.growthState >= 1
                and (e.maxGrowth == nil or e.growthState <= e.maxGrowth) then
                curIndex, curNm = e.fruitIndex, string.upper(e.fruitName or "")
            end
            if curIndex ~= nil and FieldListHUD.isCatchCrop(curNm) then curIndex = nil end
            local standingLate = curIndex ~= nil and not FieldListHUD.MULTI_CUT[curNm]
                and self:getHarvestOffset(curIndex, "standing", (ov == nil) and e.growthState or nil) >= 1
            -- Dauerkulturen (Gras, Luzerne, Klee, Wein ...) bekommen kein automatisches N+1
            if rec ~= nil and rec.next == nil and not rec.unused
                and gCur ~= "GR" and gCur ~= "FL" and gCur ~= "DS" then
                -- Felder ohne bekannte Historie gelten als Brache/Neuanfang: dort reicht "Neutral"
                local noHist = rec.cur == nil and #(rec.hist or {}) == 0
                local minPts = (noHist or pass == 2) and 0 or 1
                local best, bestPts, bestShort, bestOff, bestSil = nil, -9, 0, 1, false
                for _, o in ipairs(opts) do
                    local nm = o.name
                    -- Erntejahr dieser Frucht auf diesem Feld (Simulation): 1 = nächstes Jahr, 2 = in 2 Jahren
                    local off = nil
                    if nm ~= nil and o.index ~= nil then
                        if curIndex == nil then
                            off = self:getHarvestOffset(o.index, "sow")
                        else
                            off = self:getFolgeOffset(o.index, curIndex, standingLate)
                        end
                    end
                    local sowOk = (off == 1 or off == 2)
                    local kk = ALIAS[nm or ""] or nm or ""
                    local hz = (off == 2) and 2 or 1
                    local short, shortW = shortH[hz], shortWH[hz]
                    local sFill = (nm ~= nil and o.index ~= nil) and self:getFruitStrawFill(o.index) or nil
                    local chaffF = (nm ~= nil and o.index ~= nil and o.silage == true) and FieldListHUD.getChaffFactor(o.index) or nil
                    local shS = sFill ~= nil and (shortS[hz][sFill] or 0) or 0
                    if chaffF ~= nil then shS = math.max(shS, shortS[hz]["MAIZE_CHAFF"] or 0) end
                    if o.silage == false then shS = sFill ~= nil and (shortS[hz][sFill] or 0) or 0 end
                    local eff = math.max(short[kk] or 0, shortW[kk] or 0, shS)
                    if o.silage == true then eff = shortS[hz]["MAIZE_CHAFF"] or 0 end
                    local pbE = (100 + FieldListHUD.PLAN_BONUS) * (nm ~= nil and self:getRotationFactor(rec, nm) or 1) - 100
                    -- Passt das Feld zur Restmenge? Der Rest-Bedarf muss mindestens halb (Runde 2: ein Fünftel) so groß sein wie der Feldertrag
                    local fits = false
                    if sowOk and nm ~= nil and eff > 0 then
                        local fto = g_fruitTypeManager:getFruitTypeByName(nm)
                        if fto ~= nil then
                            local yF = self:getFruitLiters(fto.index, e.area, pbE)
                            local yW = (fto.windrowLiterPerSqm or 0) * e.area * 10000 * (1 + pbE / 100)
                            local relY = ((shortW[kk] or 0) > (short[kk] or 0) and yW > 0) and yW or yF
                            if shS > (short[kk] or 0) and shS > (shortW[kk] or 0) then
                                local yS = self:getFruitStraw(fto.index, e.area)
                                if chaffF ~= nil and (sFill == nil or (shortS[hz]["MAIZE_CHAFF"] or 0) >= (shortS[hz][sFill] or 0)) then
                                    yS = yF * chaffF
                                end
                                if yS > 0 then relY = yS end
                            end
                            if o.silage == true and chaffF ~= nil then relY = yF * chaffF end
                            fits = eff >= ((pass == 2) and 0.2 or 0.5) * relY
                        end
                    end
                    if fits and allowed[FieldListHUD.getGroup(nm) or ""] then
                        local r = self:rateCandidate(rec, nm)
                        if not r.blocked and r.points >= minPts then
                            if best == nil or r.points > bestPts
                                or (r.points == bestPts and (off < bestOff or (off == bestOff and eff > bestShort))) then
                                best, bestPts, bestShort, bestOff, bestSil = nm, r.points, eff, off, (o.silage == true)
                            end
                        end
                    end
                end
                if best ~= nil then
                    rec.next = best
                    rec.silage = bestSil or nil
                    rec.autoNext = true
                    local ft = g_fruitTypeManager:getFruitTypeByName(best)
                    if ft ~= nil then
                        -- geschätzten Ertrag dieses Feldes abziehen, damit nicht alle Felder dieselbe Frucht bekommen
                        local pbB = (100 + FieldListHUD.PLAN_BONUS) * self:getRotationFactor(rec, best) - 100
                        local bk = ALIAS[best] or best
                        if shortH[bestOff][bk] ~= nil and not bestSil then
                            shortH[bestOff][bk] = shortH[bestOff][bk] - self:getFruitLiters(ft.index, e.area, pbB)
                        end
                        if shortWH[bestOff][bk] ~= nil then
                            shortWH[bestOff][bk] = shortWH[bestOff][bk] - (ft.windrowLiterPerSqm or 0) * e.area * 10000 * (1 + pbB / 100)
                        end
                        local bChaff = bestSil and FieldListHUD.getChaffFactor(ft.index) or nil
                        if bChaff ~= nil and shortS[bestOff]["MAIZE_CHAFF"] ~= nil then
                            shortS[bestOff]["MAIZE_CHAFF"] = shortS[bestOff]["MAIZE_CHAFF"] - self:getFruitLiters(ft.index, e.area, pbB) * bChaff
                        end
                        local bFill = self:getFruitStrawFill(ft.index)
                        if bFill ~= nil and shortS[bestOff][bFill] ~= nil then
                            shortS[bestOff][bFill] = shortS[bestOff][bFill] - self:getFruitStraw(ft.index, e.area)
                        end
                    end
                    planned = planned + 1
                end
            end
        end
        end
    end)
    if not ok then
        print("FieldListHUD: Auto-Folgefrucht fehlgeschlagen: " .. tostring(err))
    end
    self.planMsg = { text = planned > 0 and string.format(T("plan_done"), planned) or T("plan_none"),
        untilT = (g_time or 0) + 5000 }
    return planned
end

-- Seite 1: optimale Folgefrucht nur für das gewählte Feld (Bewertung zuerst, dann größte Fehlmenge im nächsten Jahr)
function FieldListHUD:planOneNext(id)
    local result, resPts = nil, nil
    local ok, err = pcall(function()
        local rec = id ~= nil and self:getRecord(id) or nil
        local e = nil
        for _, f in ipairs(self.fields or {}) do
            if f.id == id then e = f break end
        end
        if rec == nil or e == nil then return end
        -- bisherige Wahl dieses Feldes aus der Bedarfsrechnung nehmen
        local prevNext = rec.next
        local prevSil = rec.silage == true
        rec.next, rec.autoNext = nil, false
        rec.silage = nil
        -- Sperre nur, solange eine Dauerkultur wirklich noch auf dem Feld steht (nicht bei bearbeitetem, leerem Feld)
        local gCur = nil
        if rec.manual and rec.cur ~= nil then
            gCur = FieldListHUD.getGroup(rec.cur)
        elseif e.fruitName ~= nil then
            gCur = FieldListHUD.getGroup(e.fruitName)
        end
        if gCur == "GR" or gCur == "FL" or gCur == "DS" then return end
        local list = self:buildPage3List()
        local shortH, shortWH = { {}, {} }, { {}, {} }
        local shortS = { {}, {} }
        for _, it in ipairs(list) do
            if it.isStraw and it.strawFill ~= nil and (it.demand or 0) > 0 then
                local shs = self:getStockShortages(it)
                shortS[1][it.strawFill] = shs[2]
                shortS[2][it.strawFill] = shs[3]
            elseif it.isSilage and (it.demand or 0) > 0 then
                local shs = self:getStockShortages(it)
                shortS[1]["MAIZE_CHAFF"] = shs[2]
                shortS[2]["MAIZE_CHAFF"] = shs[3]
            end
            if it.name ~= nil and not it.isSilage then
                if it.isWindrow then
                    local shs = self:getStockShortages(it)
                    shortWH[1][it.name] = (shortWH[1][it.name] or 0) + shs[2]
                    shortWH[2][it.name] = (shortWH[2][it.name] or 0) + shs[3]
                elseif not it.isAnimal and not it.isStraw and not it.isHeader and not it.multiCut
                    and not FieldListHUD.MULTI_CUT[it.name] then
                    local shs = self:getStockShortages(it)
                    shortH[1][it.name] = shs[2]
                    shortH[2][it.name] = shs[3]
                end
            end
        end
        local ALIAS = FieldListHUD.FRUIT_ALIAS
        local standingLate = false
        local curIndex = nil
        local ov, ovIndex = self:getCurrentOverride(e)
        if ov ~= nil then
            curIndex = ovIndex
        elseif e.fruitIndex ~= nil and e.growthState ~= nil and e.growthState >= 1
            and (e.maxGrowth == nil or e.growthState <= e.maxGrowth) then
            curIndex = e.fruitIndex
        end
        if curIndex ~= nil then
            local ftc = g_fruitTypeManager:getFruitTypeByIndex(curIndex)
            if ftc ~= nil and FieldListHUD.isCatchCrop(string.upper(ftc.name or "")) then curIndex = nil end
        end
        if curIndex ~= nil then
            local ftc2 = g_fruitTypeManager:getFruitTypeByIndex(curIndex)
            local nmc = string.upper(ftc2 and ftc2.name or "")
            standingLate = not FieldListHUD.MULTI_CUT[nmc]
                and self:getHarvestOffset(curIndex, "standing", (ov == nil) and e.growthState or nil) >= 1
        end
        local allowed = { WG = true, SG = true, MA = true, OE = true, KL = true, RU = true, KW = true, GE = true, FA = true }
        local ranked = {}
        for _, o in ipairs(self:getFruitOptions()) do
            local nm = o.name
            if nm ~= nil and o.index ~= nil and allowed[FieldListHUD.getGroup(nm) or ""] then
                local off
                if curIndex == nil then
                    off = self:getHarvestOffset(o.index, "sow")
                else
                    off = self:getFolgeOffset(o.index, curIndex, standingLate)
                end
                if off == 1 or off == 2 then
                    local r = self:rateCandidate(rec, nm)
                    if not r.blocked then
                        local kk = ALIAS[nm] or nm
                        local sFill = self:getFruitStrawFill(o.index)
                        local eff = math.max(shortH[off][kk] or 0, shortWH[off][kk] or 0, sFill ~= nil and (shortS[off][sFill] or 0) or 0)
                        if o.silage == true then eff = shortS[off]["MAIZE_CHAFF"] or 0 end
                        table.insert(ranked, { name = nm, pts = r.points, eff = eff, silage = (o.silage == true) })
                    end
                end
            end
        end
        -- Rangliste: beste Bewertung zuerst, dann größte Fehlmenge; jeder weitere Klick nimmt den nächsten Eintrag
        table.sort(ranked, function(a, b)
            if a.pts ~= b.pts then return a.pts > b.pts end
            if a.eff ~= b.eff then return a.eff > b.eff end
            if a.name ~= b.name then return a.name < b.name end
            return (a.silage and 1 or 0) < (b.silage and 1 or 0)
        end)
        local best, bestPts, bestSilP = nil, nil, false
        if #ranked > 0 then
            local pick = 1
            for i, c in ipairs(ranked) do
                if c.name == prevNext and c.silage == prevSil then
                    pick = i % #ranked + 1
                    break
                end
            end
            best, bestPts, bestSilP = ranked[pick].name, ranked[pick].pts, ranked[pick].silage == true
        end
        if best ~= nil then
            rec.next, rec.autoNext = best, true
            rec.silage = bestSilP or nil
            rec.autoOff = false
            result, resPts = best, bestPts
        end
    end)
    if not ok then
        print("FieldListHUD: Optimale Folgefrucht fehlgeschlagen: " .. tostring(err))
    end
    if result ~= nil then
        local ft = g_fruitTypeManager:getFruitTypeByName(result)
        local title = (ft ~= nil and ft.fillType ~= nil and ft.fillType.title) or result
        local lvl = FieldListHUD.getLevelInfo(self, { points = resPts })
        self.planMsg = { text = string.format(T("plan_one"), title, tostring(lvl)), untilT = (g_time or 0) + 5000 }
    else
        self.planMsg = { text = T("plan_one_none"), untilT = (g_time or 0) + 5000 }
    end
    return result
end

-- Knopf "N+1 planen" (Seite 1 und 2); setzt self.planBtn für den Klick
function FieldListHUD:drawPlanButton(x, y, w, h, msgSide, labelKey, msgX)
    self:drawFrame(x, y, w, h, self.colorTile, self.colorArea)
    local label = T(labelKey or "plan_btn")
    local size = 0.011
    local tw = getTextWidth(size, label)
    if tw > w * 0.92 then size = size * (w * 0.92) / tw end
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    renderText(x + w / 2, y + h / 2, size, label)
    setTextBold(false)
    self.planBtn = { x = x, y = y, w = w, h = h }
    local m = self.planMsg
    if m ~= nil and (g_time or 0) < m.untilT then
        setTextColor(unpack(self.colorSub))
        if msgSide == "left" then
            local mw = getTextWidth(0.011, m.text)
            local mx0 = msgX or x
            self:drawRect(mx0 - mw - 0.024, y, mw + 0.016, h, self.colorBgPage or { 0.019, 0.019, 0.019, 1 })
            setTextAlignment(RenderText.ALIGN_RIGHT)
            renderText(mx0 - 0.010, y + h / 2, 0.011, m.text)
        else
            setTextAlignment(RenderText.ALIGN_LEFT)
            renderText(x + w + 0.010, y + h / 2, 0.011, m.text)
        end
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
end

------------------------------------------------------------------------
-- Fruchtfolge-Ertrag bei der Ernte (abschaltbar, nur Server; Faktor wurde beim Säen festgehalten).
-- Vorbild: FS25_CropRotation überschreibt FSDensityMapUtil.cutFruitArea und multipliziert realArea.
------------------------------------------------------------------------
FieldListHUD.rotYield = true -- immer an (kein Schalter)
FieldListHUD.seasonal = false -- Saisonale Produktion (Option, nur der Host ändert sie)

-- Einstellungen für das ganze Spiel als Text für den Abgleich mit den Clients
function FieldListHUD.globalSettingsString()
    return "rot=" .. (FieldListHUD.rotYield and "1" or "0") .. ";sea=" .. (FieldListHUD.seasonal and "1" or "0")
end

-- Ist ein anderer Fruchtfolge-Mod (z. B. Realistic Crop Rotation) geladen, rechnet dieser den Ertrag: kein doppelter Faktor
function FieldListHUD.hasOtherRotationMod()
    if FieldListHUD.otherRotationMod ~= nil then
        return FieldListHUD.otherRotationMod
    end
    local found = false
    pcall(function()
        local mm = g_modManager
        for _, m in pairs(mm ~= nil and mm.mods or {}) do
            local n = string.upper(tostring(m.modName or ""))
            if string.find(n, "CROPROTATION", 1, true) ~= nil and n ~= string.upper(tostring(g_currentModName or "")) then
                found = true
                print("FieldListHUD: anderer Fruchtfolge-Mod gefunden (" .. tostring(m.modName) .. "), Ernte-Faktor deaktiviert")
            end
        end
    end)
    FieldListHUD.otherRotationMod = found
    return found
end

function FieldListHUD.getHarvestFactor(fruitIndex, sx, sz, wx, wz, hx, hz)
    if FieldListHUD.rotYield ~= true or g_cropRotation ~= nil or FieldListHUD.hasOtherRotationMod() then
        return 1 -- aus, oder ein anderer Fruchtfolge-Mod rechnet selbst
    end
    if g_currentMission == nil or not g_currentMission:getIsServer() or FieldListHUD.store == nil then
        return 1
    end
    local cx, cz = 0.5 * (wx + hx), 0.5 * (wz + hz)
    local farmlandId = FieldListHUD.getFarmlandIdAt(cx, cz)
    if farmlandId ~= nil and g_missionManager ~= nil and g_missionManager:getIsMissionRunningOnFarmland(farmlandId) then
        return 1
    end
    local field = FieldListHUD.getFieldAtPos(cx, cz)
    if field == nil then
        return 1
    end
    local rec = FieldListHUD.store[FieldListHUD:getFieldNumber(field)]
    if rec == nil or rec.sowFactor == nil or rec.sowFruit == nil then
        return 1
    end
    local ft = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
    if ft == nil or FieldListHUD.MULTI_CUT[string.upper(ft.name or "")] or FieldListHUD.CUT_CROPS[string.upper(ft.name or "")] then
        return 1
    end
    if not FieldListHUD.sameFruit(string.upper(ft.name or ""), rec.sowFruit) then
        return 1
    end
    return rec.sowFactor
end

-- Feld an einer Weltposition. getFieldAtWorldPosition gibt es in FS25 nicht (Fehler im Log), daher mehrere Wege:
-- 1) vorhandene FieldManager-Methoden, 2) Hof-ID (Farmland) an der Position und das nächstgelegene Feld dieses Hofs.
function FieldListHUD.getFarmlandIdAt(x, z)
    local fm = g_farmlandManager
    if fm == nil then return nil end
    local v
    if fm.getFarmlandIdAtWorldPosition ~= nil then
        v = fm:getFarmlandIdAtWorldPosition(x, z)
    elseif fm.getFarmlandAtWorldPosition ~= nil then
        v = fm:getFarmlandAtWorldPosition(x, z)
    end
    if type(v) == "table" then v = v.id end
    if v == nil or v == 0 then return nil end
    return v
end

function FieldListHUD.getFieldAtPos(x, z)
    local fm = g_fieldManager
    if fm == nil then return nil end
    if fm.getFieldAtWorldPosition ~= nil then
        local f = fm:getFieldAtWorldPosition(x, z)
        if f ~= nil then return f end
    end
    if fm.getFieldIdAtWorldPosition ~= nil and fm.getFieldById ~= nil then
        local id = fm:getFieldIdAtWorldPosition(x, z)
        if id ~= nil and id ~= 0 then
            local f = fm:getFieldById(id)
            if f ~= nil then return f end
        end
    end
    local fid = FieldListHUD.getFarmlandIdAt(x, z)
    if fid == nil then return nil end
    local best, bestD
    for _, field in pairs(fm:getFields()) do
        if field.farmland ~= nil and field.farmland.id == fid then
            local cx, cz
            if field.getCenterOfFieldWorldPosition ~= nil then
                cx, cz = field:getCenterOfFieldWorldPosition()
            else
                cx, cz = field.posX, field.posZ
            end
            local d = cx ~= nil and ((cx - x) ^ 2 + (cz - z) ^ 2) or 1e18
            if bestD == nil or d < bestD then best, bestD = field, d end
        end
    end
    return best
end

-- Die Rückgabe von cutFruitArea/updateMowerArea sind Pixel (1. Wert gemäht/geerntet, 2. Wert gesamt im Streifen),
-- keine m². Umrechnung: Streifenfläche aus den Eckpunkten x Anteil der betroffenen Pixel.
function FieldListHUD.pixelsToSqm(pixels, totalPixels, sx, sz, wx, wz, hx, hz)
    if type(pixels) ~= "number" then return 0 end
    -- Das Spiel rechnet selbst Pixel x Fruchtpixel-Fläche; diesen Faktor nehmen, wenn er verfügbar ist
    if FieldListHUD.pixelFactor == nil then
        local m = g_currentMission
        local ok, f = false, nil
        if m ~= nil and m.getFruitPixelsToSqm ~= nil then
            ok, f = pcall(function() return m:getFruitPixelsToSqm() end)
        end
        if ok and type(f) == "number" and f > 0 then
            FieldListHUD.pixelFactor = f
        end
    end
    if FieldListHUD.pixelFactor ~= nil then
        return pixels * FieldListHUD.pixelFactor
    end
    -- Notlösung: Streifenfläche aus den Eckpunkten x Anteil der betroffenen Pixel (ungenau)
    if type(totalPixels) ~= "number" or totalPixels <= 0 then return 0 end
    local strip = math.abs((wx - sx) * (hz - sz) - (wz - sz) * (hx - sx))
    return strip * pixels / totalPixels
end

FieldListHUD.cntErrLeft = 5
function FieldListHUD.safeCount(...)
    local ok, err = pcall(FieldListHUD.countHarvest, ...)
    if not ok and FieldListHUD.cntErrLeft > 0 then
        FieldListHUD.cntErrLeft = FieldListHUD.cntErrLeft - 1
        print("[FieldManager] countHarvest Fehler: " .. tostring(err))
    end
end

if FSDensityMapUtil ~= nil and FSDensityMapUtil.cutFruitArea ~= nil then
    FSDensityMapUtil.cutFruitArea = Utils.overwrittenFunction(FSDensityMapUtil.cutFruitArea,
        function(fruitIndex, superFunc, sx, sz, wx, wz, hx, hz, ...)
            local realArea, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = superFunc(fruitIndex, sx, sz, wx, wz, hx, hz, ...)
            if realArea == nil or realArea <= 0 then
                return realArea, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12
            end
            local px = realArea
            local ok, f = pcall(FieldListHUD.getHarvestFactor, fruitIndex, sx, sz, wx, wz, hx, hz)
            if ok and type(f) == "number" and f ~= 1 and realArea ~= nil then
                realArea = realArea * f
            end
            if not FieldListHUD.inMower then
                -- Fläche merken; sie wird mit der Ausgabe-Ware in Combine:addCutterArea der richtigen Zeile zugeordnet
                local sqm = FieldListHUD.pixelsToSqm(px, a2, sx, sz, wx, wz, hx, hz)
                if sqm > 0 then
                    local pa = FieldListHUD.pendingArea
                    if pa == nil then pa = {}; FieldListHUD.pendingArea = pa end
                    local e = pa[fruitIndex]
                    if e == nil then e = { sqm = 0 }; pa[fruitIndex] = e end
                    e.sqm = e.sqm + sqm
                    e.x, e.z = 0.5 * (wx + hx), 0.5 * (wz + hz)
                end
            end
            return realArea, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12
        end)
end

-- Mähdrescher/Häcksler: die echten Liter kommen aus Combine:addCutterArea (Rückgabe = tatsächlich übernommene Menge).
-- Muss beim Laden der Datei installiert werden, weil Funktionen wie addCutterArea beim Finalisieren der
-- Fahrzeugtypen in jeden Typ kopiert werden. Vorbild: FS25_YieldTracker.
function FieldListHUD.safeAddLiters(...)
    local ok, err = pcall(FieldListHUD.addHarvestLiters, ...)
    if not ok and FieldListHUD.cntErrLeft > 0 then
        FieldListHUD.cntErrLeft = FieldListHUD.cntErrLeft - 1
        print("[FieldManager] Ernte Fehler: " .. tostring(err))
    end
end

if Combine ~= nil and Cutter ~= nil and not Combine.fieldManagerHooksInstalled then
    Combine.fieldManagerHooksInstalled = true
    Cutter.onEndWorkAreaProcessing = Utils.overwrittenFunction(Cutter.onEndWorkAreaProcessing,
        function(cutter, superFunc, dt, hasProcessed)
            FieldListHUD.activeCutter = cutter
            local r = superFunc(cutter, dt, hasProcessed)
            FieldListHUD.activeCutter = nil
            FieldListHUD.pendingArea = nil
            return r
        end)
    Combine.addCutterArea = Utils.overwrittenFunction(Combine.addCutterArea,
        function(combine, superFunc, area, liters, inputFruitType, outputFillType, strawRatio, farmId, cutterLoad)
            local applied = superFunc(combine, area, liters, inputFruitType, outputFillType, strawRatio, farmId, cutterLoad)
            if combine.isServer and type(applied) == "number" and applied > 0 and inputFruitType ~= nil then
                local cutter = FieldListHUD.activeCutter
                local spec = cutter ~= nil and cutter.spec_cutter or nil
                if not (spec ~= nil and spec.useWindrow) then -- Pickup holt Schwad: schon beim Mähen gezählt
                    local x, z
                    local wa = cutter ~= nil and cutter.getWorkAreaByIndex ~= nil and cutter:getWorkAreaByIndex(1) or nil
                    if wa ~= nil and wa.start ~= nil and wa.width ~= nil and wa.height ~= nil then
                        local sx, _, sz = getWorldTranslation(wa.start)
                        local wx, _, wz = getWorldTranslation(wa.width)
                        local hx, _, hz = getWorldTranslation(wa.height)
                        x, z = (sx + wx + hx) / 3, (sz + wz + hz) / 3
                    else
                        local rx, _, rz = getWorldTranslation(combine.rootNode)
                        x, z = rx, rz
                    end
                    local outName = FieldListHUD.getOutputRowName(inputFruitType, outputFillType)
                    FieldListHUD.safeAddLiters(inputFruitType, applied, x, z, outName)
                    local pa = FieldListHUD.pendingArea
                    local e = pa ~= nil and pa[inputFruitType] or nil
                    if e ~= nil then
                        pa[inputFruitType] = nil
                        FieldListHUD.safeAddArea(inputFruitType, e.sqm, e.x or x, e.z or z, true, outName)
                    end
                end
            end
            return applied
        end)
end

-- Schwad: Mäher und Drescher legen Schwad über DensityMapHeightUtil.tipToGroundAroundLine auf den Boden.
-- Die abgelegte Menge (Rückgabewert) wird der Frucht zugeschrieben, zu der das Schwad gehört (Gras-Schwad -> Gras),
-- auch wenn es hinter einem Drescher liegt (Ackergras-Schwad zählt unter Gras). Vorbild: FS25_YieldTracker.
FieldListHUD.WINDROW_FRUITS = { GRASS = true, CLOVER = true, ALFALFA = true, MEADOW = true, FIELDGRASS = true }

function FieldListHUD.onTip(vehicle, delta, fillTypeIndex, sx, sz, ex, ez, dropped)
    if vehicle == nil or FieldListHUD.isDischarging or type(dropped) ~= "number" or dropped <= 0
        or type(delta) ~= "number" or delta <= 0 then
        return
    end
    if vehicle.spec_mower == nil and vehicle.spec_combine == nil and vehicle.spec_cutter == nil then
        return
    end
    local fname = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
    -- Gras-, Klee-, Luzerneschwad direkt am Namen der Ware erkennen: mehrere Früchte (Gras, Ackergras, Wiese) teilen
    -- sich dieselbe Schwad-Ware, die Zuordnung über die Fruchttypen wäre dann von der Lade-Reihenfolge abhängig.
    local fr = nil
    local base = fname ~= nil and string.match(string.upper(fname), "^(.+)_WINDROW$") or nil
    if base ~= nil and FieldListHUD.WINDROW_FRUITS[base] then
        fr = base
    else
        fr = FieldListHUD.getWindrowFruit(fillTypeIndex)
    end
    if fr == nil then return end
    if vehicle.spec_mower ~= nil then
        FieldListHUD.tipSeesMower = true -- ab jetzt zählt der Mäher exakt, die Näherung aus updateMowerArea entfällt
    end
    local x, z = 0.5 * (sx + ex), 0.5 * (sz + ez)
    if FieldListHUD.WINDROW_FRUITS[fr] ~= nil then
        -- Gras-, Klee-, Luzerneschwad zählt unter der Frucht selbst (Ackergras-Schwad unter Gras)
        local ft = g_fruitTypeManager:getFruitTypeByName(fr)
        if ft ~= nil then FieldListHUD.addHarvestLiters(ft.index, dropped, x, z) end
    elseif fname ~= nil and not FieldListHUD.isStrawFillName(string.upper(fname)) then
        -- andere Schwad-Waren (Flachsschwad, Hanfschwad, ...) bekommen eine eigene Zeile
        FieldListHUD.addHarvestLiters(nil, dropped, x, z, "WR_" .. string.upper(fname))
    end
end

-- Schwad-Ware -> Frucht, aus den Fruchttypen der Karte aufgebaut (Name der Frucht in Großbuchstaben)
function FieldListHUD.getWindrowFruit(fillTypeIndex)
    if FieldListHUD.windrowMap == nil then
        local map = {}
        for _, ft in ipairs(g_fruitTypeManager:getFruitTypes()) do
            local ok, wi = pcall(function() return g_fruitTypeManager:getWindrowFillTypeIndexByFruitTypeIndex(ft.index) end)
            if ok and wi ~= nil then map[wi] = string.upper(ft.name or "") end
        end
        FieldListHUD.windrowMap = map
    end
    return FieldListHUD.windrowMap[fillTypeIndex]
end

if DensityMapHeightUtil ~= nil and DensityMapHeightUtil.tipToGroundAroundLine ~= nil and not DensityMapHeightUtil.fieldManagerTipHook then
    DensityMapHeightUtil.fieldManagerTipHook = true
    DensityMapHeightUtil.tipToGroundAroundLine = Utils.overwrittenFunction(DensityMapHeightUtil.tipToGroundAroundLine,
        function(vehicle, superFunc, delta, fillTypeIndex, sx, sy, sz, ex, ey, ez, ...)
            local res = table.pack(superFunc(vehicle, delta, fillTypeIndex, sx, sy, sz, ex, ey, ez, ...))
            local ok, err = pcall(FieldListHUD.onTip, vehicle, delta, fillTypeIndex, sx, sz, ex, ez, res[1])
            if not ok and FieldListHUD.cntErrLeft > 0 then
                FieldListHUD.cntErrLeft = FieldListHUD.cntErrLeft - 1
                print("[FieldManager] Schwad Fehler: " .. tostring(err))
            end
            return table.unpack(res, 1, res.n)
        end)
end

-- Abkippen auf den Boden (Anhänger, Ladewagen, Schaufel) ist kein Mähen und wird nicht gezählt.
if Dischargeable ~= nil and Dischargeable.dischargeToGround ~= nil and not Dischargeable.fieldManagerHook then
    Dischargeable.fieldManagerHook = true
    Dischargeable.dischargeToGround = Utils.overwrittenFunction(Dischargeable.dischargeToGround,
        function(vehicle, superFunc, dischargeNode, emptyLiters)
            FieldListHUD.isDischarging = true
            local res = table.pack(superFunc(vehicle, dischargeNode, emptyLiters))
            FieldListHUD.isDischarging = false
            return table.unpack(res, 1, res.n)
        end)
end

-- Mäher laufen nicht über cutFruitArea, sondern über updateMowerArea(Frucht, sx, sz, wx, wz, hx, hz, ...).
-- Der Mäher fragt dabei alle Fruchtarten ab; nur die mit Rückgabe > 0 wurden wirklich gemäht.
if FSDensityMapUtil ~= nil and FSDensityMapUtil.updateMowerArea ~= nil then
    FSDensityMapUtil.updateMowerArea = Utils.overwrittenFunction(FSDensityMapUtil.updateMowerArea,
        function(fruitIndex, superFunc, sx, sz, wx, wz, hx, hz, ...)
            -- alle Rückgabewerte unverändert durchreichen (auch mehr als vier)
            FieldListHUD.inMower = true
            local res = table.pack(superFunc(fruitIndex, sx, sz, wx, wz, hx, hz, ...))
            FieldListHUD.inMower = false
            local area = res[1]
            if type(area) == "number" and area > 0 then
                local sqm = FieldListHUD.pixelsToSqm(area, res[2], sx, sz, wx, wz, hx, hz)
                FieldListHUD.safeAddArea(fruitIndex, sqm, 0.5 * (wx + hx), 0.5 * (wz + hz), false)
                if not FieldListHUD.tipSeesMower then
                    FieldListHUD.safeCount(fruitIndex, sqm, wx, wz, hx, hz, true)
                end
            end
            return table.unpack(res, 1, res.n)
        end)
end

------------------------------------------------------------------------
-- Mehrspieler: Der Server führt die Daten aller Höfe, Clients bekommen sie per Event.
-- Änderungen von Spielern (Folgefrucht, Planung, Weiterschieben) gehen als Event an den Server.
------------------------------------------------------------------------

function FieldListHUD:isMP()
    local m = g_currentMission
    return m ~= nil and m.missionDynamicInfo ~= nil and m.missionDynamicInfo.isMultiplayer == true
end

-- Server (oder Einzelspieler)? Nur dort wird die Fruchtfolge verfolgt
function FieldListHUD:isAuthority()
    local m = g_currentMission
    return m == nil or m.getIsServer == nil or m:getIsServer()
end


-- Tatsächlich geerntete Mengen: rec.harv[Jahr][FRUCHT] = Liter (Näherung: Erntefläche x Liter pro m²)
function FieldListHUD.harvToString(rec)
    local hp = {}
    for y, t in pairs(rec.harv or {}) do
        for n, l in pairs(t) do
            hp[#hp + 1] = string.format("%d:%s:%d", y, n, math.floor(l + 0.5))
        end
    end
    table.sort(hp)
    return table.concat(hp, ";")
end

function FieldListHUD.parseHarv(str)
    local h = nil
    for y, n, l in string.gmatch(str or "", "(%d+):([^:;]+):(%d+)") do
        h = h or {}
        y = tonumber(y)
        h[y] = h[y] or {}
        h[y][n] = tonumber(l)
    end
    return h
end

-- Trägt Liter einer Frucht auf dem Feld an der Position x/z für das laufende Jahr ein.
function FieldListHUD.addHarvestLiters(fruitIndex, liters, x, z, key)
    local function dlog() end
    local m = g_currentMission
    if m == nil or not m:getIsServer() or FieldListHUD.store == nil or liters == nil or liters <= 0 then
        dlog("abgebrochen: Server/Store/Liter")
        return
    end
    local ft = fruitIndex ~= nil and g_fruitTypeManager:getFruitTypeByIndex(fruitIndex) or nil
    if key == nil and (ft == nil or ft.name == nil) then
        dlog("abgebrochen: Fruchttyp unbekannt")
        return
    end
    local field = FieldListHUD.getFieldAtPos(x, z)
    local env = m.environment
    if field == nil or env == nil or env.currentYear == nil then
        dlog("abgebrochen: kein Feld an der Position oder kein Jahr (" .. tostring(key or ft.name) .. ")")
        return
    end
    local fn = FieldListHUD:getFieldNumber(field)
    local rec = FieldListHUD:getRecord(fn)
    local year = env.currentYear
    rec.harv = rec.harv or {}
    if rec.harv[year] == nil then
        rec.harv[year] = {}
        for y in pairs(rec.harv) do
            if y < year - 2 then rec.harv[y] = nil end
        end
    end
    local name = key
    if name == nil then
        name = string.upper(ft.name)
        name = FieldListHUD.FRUIT_ALIAS[name] or name
    end
    rec.harv[year][name] = (rec.harv[year][name] or 0) + liters
    FieldListHUD.markActive(fn, name)
    dlog(string.format("gezählt Feld %s %s Jahr %s Summe %.0f", tostring(fn), name, tostring(year), rec.harv[year][name]))
end

-- Geerntete Fläche (m²) wird in derselben Tabelle gezählt, Schlüssel "~NAME". So laufen Speichern und Abgleich unverändert mit.
-- Letzte Ernte-Aktivität je Feld und Zeile (Spielzeit in ms), für die Anzeige "wird gerade geerntet" (nur Server/Einzelspieler)
FieldListHUD.activity = {}
function FieldListHUD.markActive(fieldNumber, name)
    local m = g_currentMission
    if m == nil or fieldNumber == nil or name == nil then return end
    local a = FieldListHUD.activity[fieldNumber]
    if a == nil then a = {}; FieldListHUD.activity[fieldNumber] = a end
    a[name] = m.time
end

function FieldListHUD.getHarvYearTable(x, z)
    local m = g_currentMission
    if m == nil or not m:getIsServer() or FieldListHUD.store == nil then return nil end
    local field = FieldListHUD.getFieldAtPos(x, z)
    local env = m.environment
    if field == nil or env == nil or env.currentYear == nil then return nil end
    local rec = FieldListHUD:getRecord(FieldListHUD:getFieldNumber(field))
    local year = env.currentYear
    rec.harv = rec.harv or {}
    if rec.harv[year] == nil then
        rec.harv[year] = {}
        for y in pairs(rec.harv) do
            if y < year - 2 then rec.harv[y] = nil end
        end
    end
    return rec.harv[year], FieldListHUD:getFieldNumber(field)
end

-- Zeilen, zu denen die Ernte einer Frucht gehört: eigene Zeile (Tank/Samen) und Schwad-Zeile (Gras, Klee, Luzerne oder WR_...)
function FieldListHUD.getHarvestRowNames(fruitIndex)
    FieldListHUD.rowNameCache = FieldListHUD.rowNameCache or {}
    local c = FieldListHUD.rowNameCache[fruitIndex]
    if c ~= nil then return c[1], c[2] end
    local own, sch
    local ft = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
    if ft ~= nil and ft.name ~= nil then
        own = string.upper(ft.name)
        own = FieldListHUD.FRUIT_ALIAS[own] or own
        local ok, wi = pcall(function() return g_fruitTypeManager:getWindrowFillTypeIndexByFruitTypeIndex(fruitIndex) end)
        local fname = ok and wi ~= nil and g_fillTypeManager:getFillTypeNameByIndex(wi) or nil
        if fname ~= nil then
            fname = string.upper(fname)
            local base = string.match(fname, "^(.+)_WINDROW$")
            if base ~= nil and FieldListHUD.WINDROW_FRUITS[base] then
                sch = base
            elseif not FieldListHUD.isStrawFillName(fname) then
                sch = "WR_" .. fname
            end
        end
    end
    FieldListHUD.rowNameCache[fruitIndex] = { own or false, sch or false }
    return own, sch
end

-- Zeilenname der Ernte nach Ausgabe-Ware: kommt nicht die eigene Ware der Frucht aus der Maschine (z. B. Mais -> Häckselgut),
-- bekommt sie eine eigene Zeile "FRUCHT@WARE". Sonst nil (= normale Zeile der Frucht).
function FieldListHUD.getOutputRowName(fruitIndex, outputFillType)
    if fruitIndex == nil or outputFillType == nil then return nil end
    local ft = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
    if ft == nil or ft.name == nil then return nil end
    local ownFill = ft.fillType ~= nil and ft.fillType.index or nil
    if ownFill == nil or ownFill == outputFillType then return nil end
    local fname = g_fillTypeManager:getFillTypeNameByIndex(outputFillType)
    if fname == nil then return nil end
    local own = string.upper(ft.name)
    own = FieldListHUD.FRUIT_ALIAS[own] or own
    return own .. "@" .. string.upper(fname)
end

-- sqm = geerntete Fläche; withOwn: auch auf die eigene Zeile (Dreschen/Häckseln), sonst nur Schwad-Zeile (Mähen)
function FieldListHUD.addHarvestArea(fruitIndex, sqm, x, z, withOwn, ownOverride)
    if type(sqm) ~= "number" or sqm <= 0 then return end
    local own, sch = FieldListHUD.getHarvestRowNames(fruitIndex)
    if ownOverride ~= nil then own = ownOverride end
    if not own and not sch then return end
    local t, fn = FieldListHUD.getHarvYearTable(x, z)
    if t == nil then return end
    if withOwn and own then t["~" .. own] = (t["~" .. own] or 0) + sqm; FieldListHUD.markActive(fn, own) end
    if sch and (not withOwn or sch ~= own) then t["~" .. sch] = (t["~" .. sch] or 0) + sqm; FieldListHUD.markActive(fn, sch) end
end

function FieldListHUD.safeAddArea(...)
    local ok, err = pcall(FieldListHUD.addHarvestArea, ...)
    if not ok and FieldListHUD.cntErrLeft > 0 then
        FieldListHUD.cntErrLeft = FieldListHUD.cntErrLeft - 1
        print("[FieldManager] Fläche Fehler: " .. tostring(err))
    end
end

-- Mäher: Fläche in m² (aus Pixeln) x Schwadmenge je m²; Position = Mitte des Streifens.
function FieldListHUD.countHarvest(fruitIndex, sqm, wx, wz, hx, hz, asWindrow)
    local ft = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
    if ft == nil or sqm == nil or sqm <= 0 then return end
    local lps = asWindrow and FieldListHUD.fruitLitersPerSqm(ft) or (ft.literPerSqm or 0)
    FieldListHUD.addHarvestLiters(fruitIndex, sqm * lps, 0.5 * (wx + hx), 0.5 * (wz + hz))
end

FieldListHUD.SER_STR  = { "next", "cur", "skip", "sowFruit", "post" }
FieldListHUD.SER_BOOL = { "gap", "unused", "manual", "autoNext", "autoOff", "ccPending", "ccPlanned", "done", "skipEmpty", "silage", "curSilage" }
FieldListHUD.SER_NUM  = { "sowFactor", "sprayKey", "sprayGs", "lastSpray", "lastGs", "ccGround" }

function FieldListHUD.serializeRec(rec)
    local p = {}
    for _, k in ipairs(FieldListHUD.SER_STR) do
        if rec[k] ~= nil then p[#p + 1] = k .. "=" .. tostring(rec[k]) end
    end
    for _, k in ipairs(FieldListHUD.SER_BOOL) do
        if rec[k] ~= nil then p[#p + 1] = k .. "=" .. (rec[k] and "1" or "0") end
    end
    for _, k in ipairs(FieldListHUD.SER_NUM) do
        if rec[k] ~= nil then p[#p + 1] = k .. "=" .. string.format("%.6g", rec[k]) end
    end
    do
        local hs = FieldListHUD.harvToString(rec)
        if hs ~= "" then p[#p + 1] = "harv=" .. hs end
    end
    p[#p + 1] = "hist=" .. table.concat(rec.hist or {}, ",")
    local ccs = {}
    for n = 1, FieldListHUD.MAX_HIST do
        ccs[n] = (rec.cc ~= nil and rec.cc[n]) and "1" or "0"
    end
    p[#p + 1] = "cc=" .. table.concat(ccs)
    return table.concat(p, "|")
end

function FieldListHUD.deserializeRec(rec, str, keepHarv)
    local kv = {}
    for part in string.gmatch(str or "", "[^|]+") do
        local k, v = string.match(part, "^([^=]+)=(.*)$")
        if k ~= nil then kv[k] = v end
    end
    for _, k in ipairs(FieldListHUD.SER_STR) do
        local v = kv[k]
        rec[k] = (v ~= nil and v ~= "") and v or nil
    end
    for _, k in ipairs(FieldListHUD.SER_BOOL) do
        local v = kv[k]
        if v == nil then rec[k] = nil else rec[k] = (v == "1") end
    end
    for _, k in ipairs(FieldListHUD.SER_NUM) do
        rec[k] = kv[k] ~= nil and tonumber(kv[k]) or nil
    end
    if not keepHarv then rec.harv = FieldListHUD.parseHarv(kv.harv) end
    rec.hist = {}
    for name in string.gmatch(kv.hist or "", "[^,]+") do
        table.insert(rec.hist, name)
    end
    rec.cc = {}
    local ccs = kv.cc or ""
    for n = 1, FieldListHUD.MAX_HIST do
        rec.cc[n] = string.sub(ccs, n, n) == "1"
    end
end

FieldListHUDEvent = {}
local FieldListHUDEvent_mt = Class(FieldListHUDEvent, Event)
InitEventClass(FieldListHUDEvent, "FieldListHUDEvent")
FieldListHUDEvent.MODE_RECORDS = 0
FieldListHUDEvent.MODE_REQUEST = 1

function FieldListHUDEvent.emptyNew()
    return Event.new(FieldListHUDEvent_mt)
end

function FieldListHUDEvent.new(mode, recs)
    local self = FieldListHUDEvent.emptyNew()
    self.mode = mode
    self.recs = recs or {}
    return self
end

function FieldListHUDEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.mode)
    streamWriteUInt16(streamId, #self.recs)
    for _, r in ipairs(self.recs) do
        streamWriteInt32(streamId, r.id)
        streamWriteString(streamId, r.s)
    end
end

function FieldListHUDEvent:readStream(streamId, connection)
    self.mode = streamReadUInt8(streamId)
    local n = streamReadUInt16(streamId)
    self.recs = {}
    for i = 1, n do
        local id = streamReadInt32(streamId)
        local str = streamReadString(streamId)
        self.recs[i] = { id = id, s = str }
    end
    self:run(connection)
end

function FieldListHUDEvent:run(connection)
    local ok, err = pcall(FieldListHUD.onSyncEvent, FieldListHUD, self.mode, self.recs, connection)
    if not ok then
        print("FieldListHUD: Sync-Fehler: " .. tostring(err))
    end
end

-- Hof des Spielers hinter einer Verbindung (nil, wenn nicht ermittelbar)
function FieldListHUD:getConnectionFarmId(connection)
    local ok, farmId = pcall(function()
        local um = g_currentMission.userManager
        local userId = um:getUserIdByConnection(connection)
        local farm = userId ~= nil and g_farmManager:getFarmByUserId(userId) or nil
        return farm ~= nil and farm.farmId or nil
    end)
    return ok and farmId or nil
end

function FieldListHUD:markDirtyCaches()
    self.wiVersion = (self.wiVersion or 0) + 1
    self.p3Dirty = true
    self.wkDirty = true
    self.ratingCache = nil
end

function FieldListHUD:onSyncEvent(mode, recs, connection)
    if not connection:getIsServer() then
        -- wir sind der Server
        if mode == FieldListHUDEvent.MODE_REQUEST then
            self:sendAllTo(connection)
        elseif mode == FieldListHUDEvent.MODE_RECORDS then
            local farmId = self:getConnectionFarmId(connection)
            for _, r in ipairs(recs) do
                local owner = self.fieldOwner[r.id]
                if owner ~= nil and (farmId == nil or farmId == owner) then
                    local rec = self:getRecord(r.id)
                    local undo = rec.undo
                    FieldListHUD.deserializeRec(rec, r.s, true)
                    rec.undo = undo
                end
            end
            self:markDirtyCaches()
        end
    else
        -- wir sind ein Client: Stand vom Server übernehmen
        for _, r in ipairs(recs) do
            if r.id == 0 then
                -- Einstellung für das ganze Spiel (Fruchtfolge-Ernte), kein Feld
                FieldListHUD.rotYield = string.find(r.s or "", "rot=1", 1, true) ~= nil
                FieldListHUD.seasonal = string.find(r.s or "", "sea=1", 1, true) ~= nil
            else
                local rec = self:getRecord(r.id)
                local undo = rec.undo
                FieldListHUD.deserializeRec(rec, r.s)
                rec.undo = undo
                self.synced[r.id] = FieldListHUD.serializeRec(rec)
            end
        end
        self.syncReceived = true
        self:markDirtyCaches()
    end
end

-- Records in kleinen Paketen verschicken (target: Verbindung, "all" = alle Clients, "server" = zum Server)
function FieldListHUD:sendRecords(target, list)
    local CHUNK = 12
    local i = 1
    repeat
        local part = {}
        for k = i, math.min(#list, i + CHUNK - 1) do
            part[#part + 1] = list[k]
        end
        local ev = FieldListHUDEvent.new(FieldListHUDEvent.MODE_RECORDS, part)
        if target == "all" then
            if g_server ~= nil then g_server:broadcastEvent(ev, false) end
        elseif target == "server" then
            if g_client ~= nil and g_client:getServerConnection() ~= nil then
                g_client:getServerConnection():sendEvent(ev)
            end
        else
            target:sendEvent(ev)
        end
        i = i + CHUNK
    until i > #list
end

function FieldListHUD:sendAllTo(connection)
    local list = {}
    for id, rec in pairs(self.store) do
        list[#list + 1] = { id = id, s = FieldListHUD.serializeRec(rec) }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    list[#list + 1] = { id = 0, s = FieldListHUD.globalSettingsString() }
    self:sendRecords(connection, list)
end

-- Einmal pro Sekunde: geänderte Records verschicken (Server an alle, Client an den Server)
function FieldListHUD:mpTick()
    if not self:isMP() or self.store == nil then
        return
    end
    local isServer = self:isAuthority()
    local changed = {}
    for id, rec in pairs(self.store) do
        local str = FieldListHUD.serializeRec(rec)
        if self.synced[id] ~= str then
            -- Clients schicken nur Records, die sie schon vom Server kennen (kein Überschreiben mit Leerwerten)
            if isServer or self.synced[id] ~= nil then
                changed[#changed + 1] = { id = id, s = str }
                self.synced[id] = str
            end
        end
    end
    if #changed > 0 then
        table.sort(changed, function(a, b) return a.id < b.id end)
        self:sendRecords(isServer and "all" or "server", changed)
    end
end

-- Client: Stand beim Server anfordern, bis er angekommen ist
function FieldListHUD:mpRequest(dt)
    if self.syncReceived or self:isAuthority() or not self:isMP() then
        return
    end
    self.requestTimer = (self.requestTimer or 0) - dt
    if self.requestTimer <= 0 then
        self.requestTimer = 3000
        if g_client ~= nil and g_client:getServerConnection() ~= nil then
            g_client:getServerConnection():sendEvent(FieldListHUDEvent.new(FieldListHUDEvent.MODE_REQUEST, {}))
        end
    end
end


------------------------------------------------------------------------
-- HUD-Fenster im Spiel: Arbeiten für das Feld, auf dem der Spieler steht
------------------------------------------------------------------------
FieldListHUD.hudCursor = false
FieldListHUD.hudEdit = false
FieldListHUD.hudDrag = nil

-- Maus für das HUD aktiv: eigene Taste (Alt+F) oder ein anderer Mod hat den Mauszeiger eingeschaltet
function FieldListHUD:isHudMouseActive()
    if self.hudCursor then return true end
    local shown = false
    pcall(function() shown = g_inputBinding ~= nil and g_inputBinding:getShowMouseCursor() == true end)
    return shown and not (g_gui ~= nil and g_gui:getIsGuiVisible())
end

function FieldListHUD:setHudCursor(on)
    on = on == true
    if self.hudCursor == on then return end
    self.hudCursor = on
    self.hudDrag = nil
    if not on then self.hudEdit = false end
    pcall(function() g_inputBinding:setShowMouseCursor(on) end)
    if not on then self:savePlayerSettings() end
end

-- Taste: Maus für das HUD-Fenster ein/aus
if PlayerInputComponent ~= nil and not FieldListHUD.hudActionInstalled then
    PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
        PlayerInputComponent.registerGlobalPlayerActionEvents,
        function(inputComponent, _)
            pcall(function()
                local action = InputAction["FM_HUD_MOUSE"]
                if action == nil then return end
                local _, eventId = g_inputBinding:registerActionEvent(action, FieldListHUD, FieldListHUD.onHudMouseAction, false, true, false, true, nil, true)
                g_inputBinding:setActionEventTextVisibility(eventId, false)
            end)
        end)
    FieldListHUD.hudActionInstalled = true
end

function FieldListHUD:onHudMouseAction()
    if g_dedicatedServer ~= nil or not self.settings.hud then return end
    if g_gui ~= nil and g_gui:getIsGuiVisible() then return end
    -- Hat ein anderer Mod den Zeiger schon eingeschaltet, nutzen wir ihn einfach mit und lassen ihn auch an
    local ext = false
    pcall(function() ext = not self.hudCursor and g_inputBinding:getShowMouseCursor() == true end)
    if ext then return end
    self:setHudCursor(not self.hudCursor)
end

-- Feld unter dem Spieler (oder seinem Fahrzeug), alle 0,5 s neu bestimmt
function FieldListHUD:getHudField()
    local now = g_time or 0
    if self.hudFieldTime ~= nil and now - self.hudFieldTime < 500 then
        return self.hudFieldId
    end
    self.hudFieldTime = now
    local id = nil
    pcall(function()
        local node = nil
        local veh = g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil and g_localPlayer:getCurrentVehicle() or nil
        if veh ~= nil then node = veh.rootNode end
        if node == nil and g_localPlayer ~= nil then node = g_localPlayer.rootNode end
        if node == nil and g_currentMission.player ~= nil then node = g_currentMission.player.rootNode end
        if node == nil then return end
        local x, _, z = getWorldTranslation(node)
        for _, poly in ipairs(self:getFieldPolys()) do
            if pointInPoly(poly, x, z) then id = poly.id break end
        end
    end)
    self.hudFieldId = id
    return id
end

function FieldListHUD:hudRects()
    local st = self.settings
    st.hw = math.max(0.10, math.min(0.60, st.hw))
    st.hh = math.max(0.07, math.min(0.80, st.hh))
    st.hx = math.max(0, math.min(1 - st.hw, st.hx))
    st.hy = math.max(0, math.min(1 - st.hh, st.hy))
    local sc = st.hw / 0.19
    local titleH = 0.034 * sc
    local hs = 0.012 * sc
    return {
        x = st.hx, y = st.hy, w = st.hw, h = st.hh, sc = sc, titleH = titleH,
        title = { x = st.hx, y = st.hy + st.hh - titleH, w = st.hw, h = titleH },
        icon = { x = st.hx + st.hw - titleH * 0.85 / (g_screenAspectRatio or 1.78) - 0.004 * sc, y = st.hy + st.hh - titleH * 0.92, w = titleH * 0.85 / (g_screenAspectRatio or 1.78), h = titleH * 0.85 },
        grip = { x = st.hx + st.hw - hs / (g_screenAspectRatio or 1.78) * 1.6, y = st.hy, w = hs / (g_screenAspectRatio or 1.78) * 1.6, h = hs },
    }
end

-- Alle Felder mit offenen Arbeiten: Feldnummer + Arbeit mit der höchsten Priorität, "(+)" bei weiteren
function FieldListHUD:getHudRows()
    local now = g_time or 0
    if self.hudRows ~= nil and now - (self.hudRowsTime or 0) < 1000 and not self.wkDirty then
        return self.hudRows
    end
    self.hudRowsTime = now
    local rows = {}
    pcall(function()
        -- Immer die frische Feldliste (self.fields wird jede Sekunde neu aufgebaut), unabhängig vom Filter im Menü.
        -- self.visible wäre nur nach dem Öffnen des Menüs aktuell.
        for _, e in ipairs(self.fields or {}) do
            local items = self:getWorkItems(e)
            if #items > 0 then
                local best = items[1]
                for _, it in ipairs(items) do
                    if (it.prio or 99) < (best.prio or 99) then best = it end
                end
                local txt = best.short or best.text or "?"
                if #items > 1 then txt = txt .. " (+)" end
                table.insert(rows, { id = e.id, text = txt, harvest = best.harvest == true, prio = best.prio or 99 })
            end
        end
    end)
    if self.settings.sortPrio == true then
        table.sort(rows, function(a, b)
            if a.prio ~= b.prio then return a.prio < b.prio end
            return a.id < b.id
        end)
    else
        table.sort(rows, function(a, b) return a.id < b.id end)
    end
    self.hudRows = rows
    return rows
end

function FieldListHUD:draw()
    if g_dedicatedServer ~= nil or not self.settings.hud or self.bg == nil then return end
    if g_gui ~= nil and g_gui:getIsGuiVisible() then
        if self.hudCursor then self.hudCursor = false; self.hudEdit = false; self.hudDrag = nil end
        return
    end
    local ok, err = pcall(self.drawHud, self)
    -- Textzustand für andere Mods zurücksetzen (Standard: links, Grundlinie, nicht fett, weiß)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    if not ok and not self.hudErrShown then
        self.hudErrShown = true
        print("[FieldManager] HUD-Fenster Fehler: " .. tostring(err))
    end
end

function FieldListHUD:drawHud()
    local mouseOn = self:isHudMouseActive()
    if not mouseOn then
        if self.hudEdit then self:savePlayerSettings() end
        self.hudEdit, self.hudDrag = false, nil
        self.hudHover = false
    end
    local R = self:hudRects()
    -- Symbol nur zeigen, wenn die Maus aktiv ist und über dem Fenster steht (oder im Bearbeitungsmodus)
    local showIcon = mouseOn and (self.hudEdit or self.hudHover == true)
    local sc = R.sc
    local fid = self:getHudField()

    -- Hintergrund und Rahmen
    local border = self.hudEdit and self.colorArea or { 1, 1, 1, 0.12 }
    -- Rahmen als vier Linien, damit die Füllung wirklich durchsichtig bleibt
    local bwY = 0.0016
    local bwX = bwY / (g_screenAspectRatio or (16 / 9))
    self:drawRect(R.x, R.y, R.w, R.h, { 0.0, 0.0, 0.0, 0.30 })
    self:drawRect(R.x, R.y, R.w, bwY, border)
    self:drawRect(R.x, R.y + R.h - bwY, R.w, bwY, border)
    self:drawRect(R.x, R.y, bwX, R.h, border)
    self:drawRect(R.x + R.w - bwX, R.y, bwX, R.h, border)
    self:drawRect(R.title.x, R.title.y, R.title.w, R.title.h, { 0.0, 0.0, 0.0, 0.40 })

    local pad = 0.006 * sc
    local function fitText(x, y, size, str, maxW)
        local tw = getTextWidth(size, str)
        if tw > maxW and tw > 0 then size = size * maxW / tw end
        renderText(x, y, size, str)
    end
    -- Zeilen: Feld mit der wichtigsten offenen Arbeit
    local rows = self:getHudRows()
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)
    setTextColor(unpack(self.colorTitle))
    local innerW = R.w - pad * 2
    fitText(R.title.x + pad, R.title.y + R.title.h / 2, 0.018 * sc, string.format(T("hud_title"), #rows), innerW - (showIcon and R.icon.w + pad or 0))
    if showIcon then
        -- Einstellungs-Symbol; im Bearbeitungsmodus ein Kreuz zum Zurückwechseln
        local ic = R.icon
        local on = self.hudEdit
        if on then
            self:drawFrame(ic.x, ic.y, ic.w, ic.h, self.colorArea, self.colorBorder)
        else
            -- durchsichtige Füllung mit grünem Rand aus vier Linien (drawFrame würde den Rand durchscheinen lassen)
            local bY = 0.0016
            local bX = bY / (g_screenAspectRatio or 1.78)
            self:drawRect(ic.x, ic.y, ic.w, ic.h, { 0, 0, 0, 0.35 })
            self:drawRect(ic.x, ic.y, ic.w, bY, self.colorArea)
            self:drawRect(ic.x, ic.y + ic.h - bY, ic.w, bY, self.colorArea)
            self:drawRect(ic.x, ic.y, bX, ic.h, self.colorArea)
            self:drawRect(ic.x + ic.w - bX, ic.y, bX, ic.h, self.colorArea)
        end
        local gc = on and { 0.02, 0.02, 0.02, 1 } or self.colorTitle
        if on then
            local steps, sz = 12, ic.h * 0.075
            local szx = sz / (g_screenAspectRatio or 1.78)
            for k = 0, steps do
                local f = k / steps
                local px = ic.x + ic.w * (0.28 + 0.44 * f) - szx / 2
                self:drawRect(px, ic.y + ic.h * (0.28 + 0.44 * f) - sz / 2, szx, sz, gc)
                self:drawRect(px, ic.y + ic.h * (0.72 - 0.44 * f) - sz / 2, szx, sz, gc)
            end
        else
            for i = 0, 2 do
                local ly = ic.y + ic.h * (0.28 + i * 0.22)
                self:drawRect(ic.x + ic.w * 0.18, ly, ic.w * 0.64, ic.h * 0.045, gc)
                local kx = ic.x + ic.w * (0.30 + ((i * 2) % 3) * 0.20)
                self:drawRect(kx, ly - ic.h * 0.045, ic.w * 0.12, ic.h * 0.135, gc)
            end
        end
    end
    setTextBold(false)

    local size = 0.0153 * sc
    local lineH = size * 1.5
    local top = R.title.y - pad
    local bottomPad = self.hudEdit and 0.024 * sc or 0
    local minY = R.y + bottomPad + pad
    local visibleN = math.max(1, math.floor((top - minY) / lineH))
    local maxScroll = math.max(0, #rows - visibleN)
    -- Wechselt das Feld unter dem Spieler, die Liste so scrollen, dass seine Zeile sichtbar ist
    if fid ~= self.hudScrollFid then
        self.hudScrollFid = fid
        if fid ~= nil then
            for i, r in ipairs(rows) do
                if r.id == fid then
                    local s = self.hudScroll or 0
                    if i <= s then
                        self.hudScroll = i - 1
                    elseif i > s + visibleN then
                        self.hudScroll = i - visibleN
                    end
                    break
                end
            end
        end
    end
    self.hudScroll = math.max(0, math.min(maxScroll, self.hudScroll or 0))
    local col2 = R.x + pad + innerW * 0.40
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    if #rows == 0 then
        setTextColor(unpack(self.colorArea))
        fitText(R.x + pad, top, size, T("hud_nowork"), innerW)
    end
    local y = top
    for i = 1 + self.hudScroll, math.min(#rows, self.hudScroll + visibleN) do
        local r = rows[i]
        if r.id == fid then
            self:drawRect(R.x + pad * 0.5, y - lineH + size * 0.2, innerW + pad, lineH, { 0.55, 0.75, 0.20, 0.22 })
        end
        setTextColor(unpack(self.colorTitle))
        local ftxt = string.format(T("tile_field"), r.id)
        fitText(R.x + pad, y, size, ftxt, innerW * 0.28)
        -- Traktorsymbol wie in den Kacheln: grün = arbeitet, grau = steht
        local veh = self:getVehiclesOnField(r.id)
        if veh ~= nil then
            local bh = size * 1.05
            local bw = bh / (g_screenAspectRatio or (16 / 9))
            local bx = R.x + pad + math.min(getTextWidth(size, ftxt), innerW * 0.28) + 0.005 * sc
            if bx + bw < col2 then
                self:drawTractorBadge(bx, y - bh, bw, bh, veh.working, veh.count, RenderText.VERTICAL_ALIGN_TOP)
            end
        end
        setTextColor(unpack(r.harvest and self.colorArea or self.colorWork))
        fitText(col2, y, size, r.text, R.x + R.w - pad - col2)
        y = y - lineH
    end
    if maxScroll > 0 then
        local th = (top - minY) * visibleN / #rows
        local ty = top - (top - minY - th) * (self.hudScroll / maxScroll) - th
        self:drawRect(R.x + R.w - 0.0025 * sc, ty, 0.0015 * sc, th, self.colorThumb)
    end

    -- Bedienhilfe und Größen-Griff nur im Bearbeitungsmodus
    if self.hudEdit then
        setTextColor(unpack(self.colorSub))
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BOTTOM)
        fitText(R.x + pad, R.y + 0.003 * sc, 0.0126 * sc, T("hud_hint"), innerW - R.grip.w)
        self:drawRect(R.grip.x, R.grip.y, R.grip.w, R.grip.h, self.colorArea)
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

function FieldListHUD:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.settings.hud or not self:isHudMouseActive() then self.hudHover = false; return end
    local st = self.settings
    local R = self:hudRects()
    local function inside(r) return posX >= r.x and posX <= r.x + r.w and posY >= r.y and posY <= r.y + r.h end
    self.hudHover = inside(R)
    if isDown and inside(R) then
        if button == Input.MOUSE_BUTTON_WHEEL_UP then self.hudScroll = (self.hudScroll or 0) - 1 end
        if button == Input.MOUSE_BUTTON_WHEEL_DOWN then self.hudScroll = (self.hudScroll or 0) + 1 end
    end
    if button == Input.MOUSE_BUTTON_LEFT and isDown and inside(R.icon) then
        self.hudEdit = not self.hudEdit
        self.hudDrag = nil
        if not self.hudEdit then self:savePlayerSettings() end
        return
    end
    if not self.hudEdit then return end
    if button == Input.MOUSE_BUTTON_LEFT and isDown then
        local grip = { x = R.grip.x - 0.004, y = R.grip.y, w = R.grip.w + 0.004, h = R.grip.h + 0.004 }
        if inside(grip) then
            self.hudDrag = { mode = "size", dx = posX - (st.hx + st.hw), dy = posY - st.hy, top = st.hy + st.hh }
        elseif inside(R.title) then
            self.hudDrag = { mode = "move", dx = posX - st.hx, dy = posY - st.hy }
        end
    elseif button == Input.MOUSE_BUTTON_LEFT and isUp then
        if self.hudDrag ~= nil then
            self.hudDrag = nil
            self:savePlayerSettings()
        end
    end
    local d = self.hudDrag
    if d ~= nil then
        if d.mode == "move" then
            st.hx, st.hy = posX - d.dx, posY - d.dy
        else
            -- Größe ändern: obere linke Ecke bleibt, untere rechte Ecke folgt der Maus
            st.hw = (posX - d.dx) - st.hx
            local newBottom = posY - d.dy
            st.hh = d.top - newBottom
            st.hy = newBottom
        end
    end
end

addModEventListener(FieldListHUD)
