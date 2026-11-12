# Feld Manager / Field Manager (FS25)

**Version 1.1.4.8** · Autor: Tovak · Mehrspielerfähig · Sprachen: Deutsch, Englisch

Der Feld Manager fügt dem ESC-Menü des Landwirtschafts-Simulators 25 die Seite **Feld Manager** hinzu (direkt hinter dem Anbaukalender) und blendet auf Wunsch ein HUD-Fenster mit den offenen Arbeiten ein.

*English summary below.*

## Funktionen

### Seite 1: Felder
- Feldliste mit Fruchticon, Fläche, Frucht, Kategorie und Status (Wächst, Erntereif, Düngen nötig usw.); Traktorsymbol, wenn ein eigenes Fahrzeug auf dem Feld steht (grün = arbeitet, grau = steht)
- Filter: Alle, Frucht, Gras, Arbeiten (mit Anzahl und Hektar je Arbeit beim Überfahren)
- Feld-Detail: Anbaugeschichte mit Vorfrüchten bis N-6, aktuelle Frucht, Folgefrucht und Zwischenfrucht
- Anbaukalender mit Aussaat- und Erntemonaten für die aktuelle und die nächste Frucht
- Ertragsanzeige als Basis 100 % plus Bonus (z. B. 197,5 %)
- Feldzustand und Boden: Wachstum, Stickstoff, Kalk, Unkraut, Bodenzustand
- **Unkraut** mit Größe (klein, mittel, ausgewachsen) und passender Maßnahme (Hacken/Striegeln, Hacken, Spritzen)
- **Folgefrucht planen:** Auswahl mit Pfeilen, „x“ setzt zurück, „Optimale Folgefrucht“ plant nur dieses Feld (erneuter Klick schaltet zur nächstbesten Frucht), „Fest übernehmen“ macht einen automatischen Vorschlag zur festen Wahl, „Fruchtfolge weiterschieben“ rückt die Folgefrucht auf
- **Zwischenfrucht** (Ölrettich) als Marker zwischen den Früchten, planbar neben der Folgefrucht

### Fruchtfolge-Bewertung
- Bewertung jeder Folgefrucht nach Spielmechanik und realer Agronomie (Pausen, Wechsel Halm/Blatt, Leguminosen, Zwischenfrucht, spätes Räumen, Monokultur)
- Fruchtfolgefaktor wirkt auf den Planungsertrag und (immer an) auch auf den echten Ernteertrag
- „Automatisch planen“ plant die Folgefrucht aller Felder einmalig (nach Bewertung und größter Fehlmenge); „Fest übernehmen“ übernimmt alle Vorschläge

<img width="1439" height="860" alt="image" src="https://github.com/user-attachments/assets/5b8b60e4-4409-4434-88f0-1c0f5d1159d9" />

### Seite 2: Anstehende Arbeiten in diesem Monat
- Tabelle: eine Zeile je Feld, Spalten Ernte, Pflügen, Steine, Kalk, Dünger, Unkraut, Zwischenfrucht, Aussaat, Walzen; sortierbar
- Eigener Filter (Start mit „Arbeiten“)
- **Arbeiten verschieben:** Klick auf eine Arbeit blendet sie bis zum nächsten Monat aus (grau), erneuter Klick holt sie zurück; Ernte lässt sich nicht verschieben
- Ernte-Aufgabe entfällt, solange die Zwischenfrucht auf dem Feld wächst

<img width="1480" height="892" alt="image" src="https://github.com/user-attachments/assets/0a480ee8-906c-4fa9-8aac-2b1a9ce70cf1" />

- Reiter **Diesen Monat** / **Nächsten Monat**: die Vorschau zeigt nur sichere Arbeiten (Aussaat, Ernte, auf nächsten Monat verschobene Arbeiten)
- Aussaat-Zelle zeigt unter der Frucht die Maschine: Säm. (Sämaschine), Einzel (Einzelkorn), Pflanz (Pflanzmaschine), Säm./Einzel bei Ackerbohnen, Ackererbsen, Zwiebeln; aus den Fruchtkategorien des Spiels gelesen, nicht im HUD
- Nächster Monat: auch erste Ernte von Gras/Ackergras/Luzerne/Klee und „Zwischenfrucht grubbern", wenn die Zwischenfrucht im Monat ausgewachsen ist; Reihenfolge: Grubbern vor Aussaat vor Zwischenfrucht-Aussaat
- Planung: nach Ackergras/Klee/Luzerne wird nach dem nächsten Schnitt gepflügt und die Folgefrucht zum nächsten Saattermin gesät (auch noch im selben Jahr); stehende Früchte rechnen den Wachstumsschritt des laufenden Monats mit; kein Düngen bei Zwischenfrucht ab Stufe 1 (Grubbern bringt Stufe 2)
- Zwischenfrucht (z. B. Ölrettich) voll ausgewachsen: Arbeit „Grubbern", ebenfalls verschiebbar; Düngen auf leerem Feld nur einmal, sonst erst nach einer Wachstumsstufe (Gras: nach dem Monatswechsel)

### Seite 3: Fruchtfolge-Planung
- Feldtabelle mit Ertrag, Spalte PROD. (grün/gelb/grau: Feld wird für den Produktionsbedarf gebraucht, teilweise, nicht nötig), Folgefrucht, aktueller Frucht und Vorfrüchten
- Fußzeile mit Details je Zeile: Deckung des Bedarfs (Ernte dieses Jahr, nächstes Jahr, in 2 Jahren); bei Früchten ohne Produktionsbedarf die Ertragsprognose mit Summe und Anteil des Feldes
- Eigener Filter (Alle, Frucht, Gras)

<img width="1464" height="884" alt="image" src="https://github.com/user-attachments/assets/44845002-cd49-4094-a999-a5677366e584" />

### Seite 4: Ertragsplanung
- Je Frucht, Futter und Stroh: Ertrag, Bedarf der Produktionen, Differenz, Lagerbestand, Eingang, Fehlmenge und benötigte Fläche
- Reiter Dieses Jahr, Nächstes Jahr, In 2 Jahren (Erntejahr nach Saat- und Erntemonaten, Wintergetreide zählt zum nächsten Jahr)
- Planung rechnet mit festem Bonus für geplante Felder; Mehrschnitt-Früchte zeigen die Jahresmenge (Gras mit seinen Schnitten, Ackergras, Kleegras und Luzerne mit 1 Schnitt)
- Ackergras-Schwad (Dreschen) zählt zur Gras-Zeile, mit Praxisabschlag von 75 % auf den Sollwert
- Detailfenster je Frucht mit Produktionen, Eingängen und allen beteiligten Feldern (Ernte, Fläche, Ertrag, Menge)
- Weizen/Sommerweizen und Gerste/Sommergerste werden zusammen geführt
- Lagerbestand wird über die Jahre fortgeschrieben: Spalte **Restbestand** je Jahr, Fehlmenge nach Abzug von Lager und Eingang aus laufender Produktion; Schwad-Früchte werden gleich behandelt
- Die automatische Planung berücksichtigt Lager, Restbestand und geplante Ernte
- **Stroh und Hülsenfrucht-Stroh** mit Bedarf der Produktionen, Restbestand und Fehlmenge; die Planung bevorzugt Früchte, die das fehlende Stroh liefern
- **Silage / Häckselgut** (Futterpflanzen): Bedarf aktiver Produktionen (BGA, Komposter, Fermenter), Lager inklusive Fahrsilos (auch gärend), Ertrag aus Mais mit dem Häckselfaktor des Spiels
- **Mais (Körner) oder Mais (Silage)** je Feld: in der Folgefrucht-Auswahl und per Schalter für den stehenden Mais; die automatische Planung deckt Silage-Fehlmengen mit Mais (Silage)

<img width="1481" height="909" alt="image" src="https://github.com/user-attachments/assets/55ee4f4a-7514-4120-9061-c364def5dd55" />

### Seite 5: Tatsächlich geerntet
- Zählt die tatsächlich geernteten Mengen je Frucht und Feld, gespeichert im Spielstand, drei Jahre
- Mähdrescher und Häcksler: die echten Liter, die in den Tank kommen (z. B. Ackergras-Samen, Körner, Häckselgut)
- Schwad: die Menge, die Mäher und Drescher auf dem Boden ablegen. Gras-, Klee- und Luzerneschwad zählt unter Gras, Klee und Luzerne (auch das Schwad hinter dem Drescher bei Ackergras), andere Schwad-Waren wie Flachs- und Hanfschwad bekommen eine eigene Zeile, Stroh wird nicht gezählt
- Ballenpressen, Ladewagen und Abkippen zählen nicht noch einmal
- Reiter Dieses Jahr, Letztes Jahr, Vor 2 Jahren; links die Früchte mit Menge, rechts die Felder der gewählten Frucht mit Fläche, Menge, Anteil in % und Ertrag je Hektar plus Summenzeile
- Ertrag je Hektar wird aus der tatsächlich geernteten Fläche berechnet; die Frucht und das Feld, die gerade geerntet werden, sind grün markiert
- Mais: Körner und Häckselgut stehen in getrennten Zeilen
- Gezählt wird nur auf Feldern mit Besitzer (nicht vor dem Kauf) und erst ab der Installation des Mods; im Mehrspielerspiel zählt der Server, die Clients bekommen die Werte per Abgleich

### Seite 6: Erntekalender (saisonale Produktion)
- Eine Zeile je Frucht mit Symbol, Name und Erntezeitraum als Balken, Monate von März bis Februar mit den Jahreszeiten-Symbolen des Spiels
- Gestrichelte senkrechte Linie am heutigen Tag, sie wandert durch den Monat

### Saisonale Produktion (Option, Host) (Ab Version 1.1.1.0)
- Plantagen und Feld-Produktionen (Apfel, Birne, Kirsche, Pflaume, Pfirsich, Mirabelle, Trauben, Beeren, Hopfen, Kürbis, Oliven, Rollrasen, Tannenbäume) produzieren nur in ihrer Saison; Gewächshäuser laufen ganzjährig
- Die Leistung steigt vom Saisonbeginn bis zur Mitte des ersten Monats von 0 auf 100 % und fällt ab der Mitte des letzten Monats wieder auf 0 %; die Spitze (12 / (Saisonmonate − 0,5)) hält die Jahresmenge etwa gleich
- Außerhalb der Saison bleibt die Produktion eingeschaltet, es laufen nur keine Zyklen; im Produktionsmenü steht „Außerhalb der Erntezeit“
- Neue Gebäude werden auch während des Spiels erfasst; der Server entscheidet im Mehrspielermodus

<img width="1487" height="844" alt="image" src="https://github.com/user-attachments/assets/8b73112c-8504-411e-b5ac-7121003e1e04" />


### HUD-Fenster im Spiel
- Durchsichtiges Fenster mit allen Feldern und der wichtigsten offenen Arbeit (weitere Arbeiten mit „(+)“), aktuelles Feld hervorgehoben, Traktorsymbol bei Fahrzeugen auf diesem Feld. Grün wenn sie sich bewegen, Grau wenn sie stehen
- Maus ein/aus mit **Alt+F** (Taste änderbar); ist die Maus durch einen anderen Mod aktiv, nutzt der Mod sie mit
- Einstellungs-Symbol im Titel (nur bei Maus über dem Fenster) schaltet den Bearbeitungsmodus: Titel ziehen = verschieben, Ecke = Größe, Mausrad = scrollen; Position und Größe werden gespeichert

  <img width="320" height="159" alt="image" src="https://github.com/user-attachments/assets/adbbf512-a050-4333-88e3-81dd691516a3" />

### Optionen (Einstellungs-Symbol im Menü)
- HUD-Sortierung: nach Feldnummer oder nach Arbeitsprio; das HUD scrollt automatisch zum eigenen Feld
- Fruchtfolge-Ernte ein/aus (Host)
- Angenommener Bonus für geplante Felder (Standard 95 %)
- HUD-Fenster ein/aus
- Saisonale Produktion ein/aus (Host)

<img width="1507" height="894" alt="image" src="https://github.com/user-attachments/assets/c177b509-2964-4b1d-8551-dfc96f93a47e" />


### Mehrspieler und Technik
- Server führt die Daten (`fieldManager.xml` im Spielstand), Clients planen über Ereignisse
- Optionen und HUD-Position je Spieler unter `modSettings/FS25_FieldManager`
- Alle Texte stehen in `l10n/translation_<sprache>.xml`; eine neue Sprache braucht nur eine neue Datei (Kopie von `translation_en.xml`), fehlende Texte kommen aus dem Englischen

## Installation
1. `FS25_FieldManager.zip` (aus dem Release) in den Mod-Ordner kopieren
2. Mod im Spiel aktivieren
3. Im ESC-Menü die Seite „Feld Manager“ öffnen

---

## English summary

Field Manager adds a page to the pause menu and an optional in-game HUD window.

- **Fields:** overview with crop, growth, yield bonus, soil state, weeds (size and matching tool), crop calendar, history up to N-6, next-crop and cover-crop planning, per-field "optimal next crop" and "keep as is"
- **Work page:** pending work per field in a sortable table with its own filter; postpone a task to next month; no harvest task while the cover crop is growing
- **Crop rotation planning:** rating of next crops, automatic planning, production demand marker, footer with demand coverage and yield forecast per harvest year
- **Yield planning:** this year, next year and in 2 years vs. production demand, shortage in liters and hectares, detail window with all fields
- **Harvested amounts (page 5):** actual harvested liters per crop and field (this year, last year, 2 years ago), with share per field and yield per hectare
- **Silage and straw:** straw and legume straw demand, a silage / chaff row with bunker silos in stock, maize can be planned as grain or silage per field
- **Harvest calendar (page 6):** one row per fruit with its harvest period, seasons like the game calendar, dashed line for today
- **Seasonal production (option):** plantations and field productions only run in season with a smooth ramp up and down; greenhouses run all year
- **HUD window:** transparent, movable and resizable, list of fields with pending work, tractor symbol; mouse toggle with Alt+F (rebindable)
- **Options:** crop rotation harvest, assumed bonus for planned fields, HUD on/off, seasonal production on/off
- **Multiplayer** supported; **languages:** German, English (more can be added with a single `l10n` file)
