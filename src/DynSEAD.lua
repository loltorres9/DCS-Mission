--[[
  DynSEAD v4.61 – Dynamic SEAD/CAS/CAP campaign for DCS World (coop)
  ----------------------------------------------------------------------
  Benötigt KEIN MOOSE/MIST und KEINE Template-Gruppen.

  MODUS "airbases" (Standard) – Eroberungskampagne:
    - Im Editor BLAU gesetzte Flugplätze sind die Startbasis
    - Alle anderen Flugplätze werden rot und nacheinander zur AO
    - AO = Kreis um den Flugplatz. Zu zerstören: SAMs, CAS-Ziele, Garnison
    - Danach wird der Flugplatz blau -> Dynamic Spawn dort möglich

  MODUS "zones" – Endlosmission in Trigger-Zonen, deren Name mit "AO" beginnt

  NEU in v3:
    - Alle Texte im Spiel auf Englisch
    - Keine SAM-Positionen: pro AO nur Lagebild (SAM-Typen, MANPADS ja/nein)
    - Läuft auf Caucasus und Syria; kartenspezifische Werte in D.cfg.maps

  Editor-Voraussetzungen (Modus "airbases"):
    1. Startflugplatz auf BLAU setzen (oder cfg.campaign.homeBase bzw. D.cfg.maps[Karte].homeBases eintragen)
    2. Dynamic Spawn an allen Flugplätzen aktivieren, die erobert werden können
    3. Trigger: MISSIONSSTART / SKRIPTDATEI AUSFÜHREN -> diese Datei
]]

DynSEAD = DynSEAD or {}
local D = DynSEAD

-------------------------------------------------------------------------------
-- KONFIGURATION
-------------------------------------------------------------------------------
D.cfg = {
  mode            = "airbases",    -- "airbases" = Kampagne, "zones" = Editor-Zonen (endlos)
  zonePrefix      = "AO",          -- nur Modus "zones"
  zoneWeighting   = "area",        -- "area" = große AOs mehr Spawns, "equal" = gleich
  redCountry      = country.id.CJTF_RED,
  blueCountry     = country.id.CJTF_BLUE,
  blueSide        = coalition.side.BLUE,
  redSide         = coalition.side.RED,
  skill           = "High",        -- Average / Good / High / Excellent / Random
  msgTime         = 25,
  tickInterval    = 10,
  minDistPlayers  = 15000,
  minDistBlueBase = 15000,
  mapMarks        = true,          -- vermutete SAM-Positionen auf F10-Karte
  drawAO          = true,          -- AO-Kreise auf F10-Karte
  aoWaypointMarks = false,         -- zusätzlicher "WPT"-Marker in der AO-Mitte
  debugMenu       = true,          -- F10-Befehle zum Testen (später false)
  debugShowAll    = false,         -- true: alle Gruppen beider Seiten als Textmarker auf der F10-Karte (auch per F10 > DEBUG schaltbar)
  debugMapInterval = 15,           -- Aktualisierung der Test-Marker in s
  debugVisibleUnits = true,        -- true: rote Bodengruppen NICHT auf der F10-Karte verstecken (für alle Spieler); false: nur per ELINT-Marker auffindbar
  showErrors      = true,          -- Skriptfehler im Spiel anzeigen
  fallbackStart   = 120,

  campaign = {
    homeBase        = nil,         -- z.B. "Kutaisi", falls im Editor kein Platz blau ist
    aoRadius        = 40000,
    activeTargets   = 2,           -- gleichzeitig aktive Ziel-Flugplätze
    samPerAO        = {2, 3},
    casPerAO        = {1, 2},
    garrison        = true,
    garrisonPercent = 100,         -- Garnison muss ganz zerstört werden (Nachzügler-Regel siehe straggler)
    -- Nachzügler: bleiben von Garnison bzw. einer SAM-Stellung höchstens maxLeft Einheiten übrig, gilt sie nach
    -- timeout s trotzdem als zerstört (Rest wird entfernt) – damit eine einzelne unauffindbare Einheit nichts blockiert
    straggler       = { maxLeft = 1, timeout = 1200 },
    exclude         = {},          -- z.B. { "Mozdok", "Beslan" }
    maxDistance     = 0,           -- 0 = egal; sonst max. Entfernung zur nächsten blauen Basis
    aoSeparation    = 85000,       -- Mindestabstand der Mittelpunkte gleichzeitig aktiver AOs (m), ca. 2 x aoRadius + Puffer: Kreise überlappen nicht
    captureDelay    = 60,
  },

  -- Kampagnenstand speichern: (1) Datei auf dem Server, braucht io/lfs (in DCS\Scripts\MissionScripting.lua
  --     "sanitizeModule('io')" und "sanitizeModule('lfs')" auskommentieren), (2) Spielstand-Code, der überall
  --     funktioniert: wird nach jeder Eroberung angezeigt, Laden per Kartenmarker mit Text "LOAD <Code>"
  persistence = {
    enabled  = true,
    file     = true,
    fileName = "DynSEAD_save_%s.txt",   -- in Saved Games\DCS…\ (lfs.writedir), %s = Karte
    interval = 120,                     -- s zwischen automatischen Speicherungen (zusätzlich nach jeder Eroberung)
    code     = true,
  },

  -- Kartenspezifische Einstellungen; gewählt nach env.mission.theatre. Überschreiben die allgemeinen Werte.
  --   homeBases     : Flugplätze, die beim Start blau gesetzt werden
  --   friendly      : weitere Flugplätze, die beim Start blau sind (kein Ziel)
  --   friendlyAreas : alle Flugplätze in diesen Lat/Lon-Rechtecken sind ebenfalls blau (kein Ziel)
  --   exclude       : Flugplätze, die weder blau noch Ziel sind
  --   tankers       : Tanker mit festen Strecken (ersetzt tankers.list)
  --   fronts        : mehrere Fronten mit je eigenen aktiven Zielen (ohne: eine Front, campaign.activeTargets)
  --   ignore        : Lua-Muster für Namen, die gar nicht als Flugplatz zählen (Syria meldet ~140 Hubschrauber-Landeplätze als Flugplatz)
  --   deepStrike    : Deep-Strike-Ziele (Platzhalter-Koordinaten)
  maps = {
    Caucasus = {},                 -- Startbasis kommt aus dem Editor (Senaki-Kolkhi blau)
    Syria = {
      homeBases     = { "Incirlik" },
      friendly      = { -- Türkei (die Front läuft von Incirlik nach Süden)
                        "Adana Sakirpasa", "Chukurova", "Hatay", "Gaziantep", "Kahramanmaras", "Sanliurfa", "Adiyaman",
                        "Gulechoba", "Diyarbakir", "Konya", "Gazipasa",
                        -- Jordanien
                        "King Hussein Air College", "Zarqa", "Ruwayshid", "H4", "H4 Emergency", "Prince Hassan",
                        "King Abdullah II", "Marka", "Muwaffaq Salti" },
      friendlyAreas = { { name = "Cyprus", latMin = 34.4, latMax = 35.8, lonMin = 32.0, lonMax = 34.8 } },
      exclude       = {},
      ignore        = { "^H[%a_]+%d+$", "Heliport" },   -- HS02, HMed01, H_med_orig_03, HOil01 …; nicht H3/H4
      -- Fronten: jede Front hat eigene aktive Ziele und rückt von ihren Basen (plus eroberten Plätzen) aus vor
      -- Tanker (ersetzen tankers.list); track = Start- und End-Lat/Lon der Race-Track-Strecke.
      -- Ohne front: feste Strecke (weicht nur SAM-Reichweiten aus); mit front: rückt mit dieser Front vor (track = Startposition)
      tankers = {
        -- Mittelmeer südöstlich von Zypern
        { name = "Texaco", type = "KC-135",    kind = "boom",   callsignIndex = 1, flight = 1,
          frequency = 255.0, tacan = 51, tacanId = "TEX", alt = 6100, speed = 165, track = { 34.45, 34.15, 34.15, 34.75 } },
        { name = "Arco",   type = "KC135MPRS", kind = "drogue", callsignIndex = 2, flight = 1,
          frequency = 256.0, tacan = 52, tacanId = "ARC", alt = 5500, speed = 160, track = { 34.55, 34.05, 34.25, 34.65 } },
        -- Norden, türkische Seite der Grenze zu Syrien
        { name = "Shell",  type = "KC-135",    kind = "boom",   callsignIndex = 3, flight = 1, front = "North",
          frequency = 257.0, tacan = 53, tacanId = "SHL", alt = 6700, speed = 165, track = { 37.25, 36.60, 37.25, 37.60 } },
        { name = "Arco2",  type = "KC135MPRS", kind = "drogue", callsignIndex = 2, flight = 2, callsign = "Arco", front = "North", offsetBack = 15000,
          frequency = 258.0, tacan = 54, tacanId = "AR2", alt = 5800, speed = 160, track = { 37.40, 36.60, 37.40, 37.60 } },
        -- Süden, über Jordanien (Südfront)
        { name = "Texaco2", type = "KC-135",   kind = "boom",   callsignIndex = 1, flight = 2, callsign = "Texaco", front = "South",
          frequency = 259.0, tacan = 55, tacanId = "TX2", alt = 6400, speed = 165, track = { 32.00, 36.90, 32.00, 37.90 } },
        { name = "Arco3",  type = "KC135MPRS", kind = "drogue", callsignIndex = 2, flight = 3, callsign = "Arco", front = "South", offsetBack = 15000,
          frequency = 260.0, tacan = 56, tacanId = "AR3", alt = 5650, speed = 160, track = { 31.85, 36.90, 31.85, 37.90 } },
      },
      fronts = {
        { name = "North", active = 2, bases = { "Incirlik", "Adana Sakirpasa", "Chukurova", "Hatay", "Gaziantep",
                                                "Kahramanmaras", "Sanliurfa", "Adiyaman", "Gulechoba", "Diyarbakir" } },
        { name = "South", active = 2, bases = { "King Hussein Air College", "Zarqa", "Ruwayshid", "H4", "H4 Emergency",
                                                "Prince Hassan", "King Abdullah II", "Marka", "Muwaffaq Salti" } },
      },
      deepStrike = {
        { name = "Command post near Damascus",      lat = 33.45, lon = 36.40, type = ".Command Center", category = "Fortifications" },
        { name = "Ammunition depot near Homs",      lat = 34.70, lon = 36.80, type = "Warehouse",       category = "Warehouses" },
        { name = "Fuel depot near Palmyra",         lat = 34.55, lon = 38.20, type = "Tank",            category = "Warehouses" },
        { name = "Command post near Deir ez-Zor",   lat = 35.30, lon = 40.10, type = ".Command Center", category = "Fortifications" },
        { name = "Supply depot near Hama",          lat = 35.15, lon = 36.85, type = "Warehouse",       category = "Warehouses" },
      },
    },
  },

  sam = {
    maxActive         = 12,        -- SAM-Stellungen gleichzeitig (gesamt, alle AOs)
    spawnAll          = true,      -- alle SAM-Stellungen einer AO erscheinen sofort beim Aktivieren (nicht nacheinander)
    respawnDelay      = {120, 300},
    minSeparation     = 12000,
    shoradChance      = 0.5,
    killAll           = true,      -- Stellung erst zerstört, wenn ALLE Einheiten zerstört sind: Radare, Gefechtsstände, Startgeräte, Nahbereichsflak und Punktverteidigung
    cleanupAfter      = 900,
    armEvasion = {
      enabled       = true,
      vanilla       = false,       -- DCS-eigenes "Evasion of ARM" zusätzlich aktivieren
      -- Entdeckung der anfliegenden ARM durch das Radar der Stellung:
      -- Chance pro Sekunde, solange die ARM in Reichweite UND Sichtlinie ist (bei Referenzhöhe)
      -- v4.50 deutlich gesenkt (vorher 0.02–0.06): Crews erkennen eine ARM grob nur noch in 25–50 % der Fälle
      detectRate      = { SA2 = 0.005, SA3 = 0.005, SA6 = 0.007, SA11 = 0.008, SA8 = 0.008, SA15 = 0.012, SA5 = 0.006, SA10 = 0.012 },
      defaultRate     = 0.007,
      detectRange     = { SA2 = 40000, SA3 = 30000, SA6 = 30000, SA11 = 40000, SA8 = 20000, SA15 = 25000, SA5 = 50000, SA10 = 60000 },
      defaultRange    = 30000,
      altRef          = 3000,        -- m über Grund, bei der Höhenfaktor 1 gilt
      altFactor       = {0.2, 1.5},  -- tief anfliegend = schwer zu sehen, hoch = leicht
      reactionDelay   = {4, 10},     -- s von Entdeckung bis Radar aus
      launchAlert     = 0.3,         -- Chance, dass der Start selbst bemerkt wird (Shooter im Radar)
      alertMultiplier = 2,           -- dann ist die Crew aufmerksamer
      maxEvasions     = 1,           -- Radar höchstens 1x zum Ausweichen abschalten, danach bleibt die Crew auf Sendung
      recover       = {40, 90},    -- Radar bleibt nach Einschlag/Vorbeiflug X s unterdrückt (vorher 120–300)
      maxAngle      = 20,          -- Grad: Zielzuordnung über Flugrichtung, falls kein direktes Ziel
    },
    relocate = {
      enabled       = true,
      -- Chance auf Stellungswechsel nach HARM-Ausweichen (nur mobile Systeme)
      chance        = { SA6 = 0.25, SA8 = 0.35, SA11 = 0.2, SA15 = 0.35 },
      -- Chance auf Stellungswechsel beim normalen Abschalten im Blink-Modus
      onBlinkChance = { SA6 = 0.05, SA8 = 0.1, SA11 = 0.05, SA15 = 0.1 },
      distance      = {2000, 6000},
      speed         = 10,          -- m/s Gelände
      timeout       = 900,
      setupTime     = {30, 90},    -- Aufbauzeit am neuen Ort (Radar dunkel)
    },
    pointDefense = {
      chance = 0.4,                -- Chance auf eigenständige SA-8 als Punktverteidigung der Mittelstrecken-Stellungen
      types  = { SA2 = true, SA3 = true, SA6 = true, SA11 = true },
      unit   = "Osa 9A33 ln",      -- früher SA-15 (Tor 9A331), auf Nutzerwunsch schwächer
      dist   = 600,
    },
    -- Ungefähre Einsatzreichweite je Typ (m); Hinterhalt schaltet bei Reichweite * ambushFactor ein
    engageRange       = { SA2 = 45000, SA3 = 25000, SA6 = 25000, SA11 = 35000, SA8 = 10000, SA15 = 12000, SA5 = 150000, SA10 = 90000,
                          AAA100 = 12000, AAA57 = 6000 },
    -- schwere Flak mit Fire-Can-Radar (SON-9) als zusätzliches Ziel in einer AO (zählt wie eine SAM-Stellung, auch für die Eroberung)
    aaa               = { chance = 0.6, pool = { AAA100 = 1, AAA57 = 1 } },
    ambushFactor      = 1.5,
    ambushHold        = 90,        -- Radar bleibt nach Auslösen mind. X s an
    ambushRange       = 30000,     -- Fallback für Typen ohne engageRange
    blinkOn           = {120, 300},
    blinkOff          = {20, 60},
    modes             = { always = 2, blink = 2, ambush = 1 },   -- Fallback
    -- Radar-Verhalten je Typ (Gewichtung): große Systeme senden meist, SHORAD lauert
    modesByType = {
      AAA100 = { always = 2, blink = 1 },
      AAA57  = { always = 2, blink = 1 },
      SA2  = { always = 3, blink = 2 },
      SA3  = { always = 2, blink = 2, ambush = 1 },
      SA6  = { always = 2, blink = 2, ambush = 1 },
      SA11 = { always = 3, blink = 2, ambush = 1 },
      SA8  = { always = 1, blink = 1, ambush = 2 },
      SA15 = { always = 1, blink = 1, ambush = 2 },
      SA5  = { always = 1 },       -- Hauptbasis: strahlt immer
      SA10 = { always = 1 },
    },
    pool              = { SA2 = 2, SA3 = 3, SA6 = 3, SA11 = 2, SA8 = 2, SA15 = 1 },
    -- Jede AO bekommt mindestens eine Stellung je Klasse (Typ gewichtet aus pool), weitere frei aus pool
    classes           = {
      medium = { SA2 = true, SA3 = true, SA6 = true, SA11 = true },
      short  = { SA8 = true, SA15 = true },
    },
  },

  awacs = {
    enabled       = true,
    type          = "E-3A",
    groupName     = "Overlord",
    callsignIndex = 1,             -- 1 = Overlord, 2 = Magic, 3 = Wizard, 4 = Focus, 5 = Darkstar
    callsignName  = "Overlord",
    frequency     = 251,           -- MHz AM
    alt           = 9000,
    speed         = 200,
    standoff      = 30000,         -- Orbit X m hinter der nächstgelegenen blauen Basis
    legLength     = 60000,
    immortal      = true,          -- AWACS unverwundbar und für Gegner unsichtbar
    respawnDelay  = 600,
  },

  -- Sprachausgabe von Overlord aus vorproduzierten WAV-Bausteinen (ohne SRS)
  -- Bausteine + Index (DynSEAD_voice.lua) erzeugt das PowerShell-Skript make_overlord_voice.ps1
  voice = {
    enabled       = false,         -- Sprachausgabe vorerst aus (Dateien bleiben in der Mission, true schaltet sie wieder ein)
    output        = "all",         -- "all" = alle blauen Spieler hören es direkt
                                   -- "radio" = nur über Cockpit-Funk auf der AWACS-Frequenz (251 AM)
    gap           = 0.05,          -- Pause zwischen Bausteinen (s)
    maxQueue      = 6,
    popupCooldown = 120,
  },

  tankers = {
    enabled        = true,
    distFromAO     = 90000,        -- Orbit-Mitte X m von der AO-Mitte Richtung eigene Basis
    minAOClearance = 75000,        -- Mindestabstand des Orbits zu jeder aktiven AO-Mitte
    samMargin      = 20000,        -- Strecke bleibt so viel (m) außerhalb der Reichweite jeder SAM-Stellung (sam.engageRange)
    checkInterval  = 60,           -- s: Strecken prüfen und Tanker bei Bedarf verlegen
    legLength      = 50000,
    immortal       = true,         -- unverwundbar und für Gegner unsichtbar
    respawnDelay   = 300,          -- Ersatz nach Abschuss / Rückflug (Sprit leer)
    list = {
      -- Boom: F-16, F-15E, A-10C
      { name = "Texaco", type = "KC-135",    kind = "boom",   callsignIndex = 1,
        frequency = 255.0, tacan = 51, tacanId = "TEX", alt = 6100, speed = 165, offsetBack = 0 },
      -- Korb (Drogue): F/A-18C, AV-8B, F-14, Mirage 2000
      { name = "Arco",   type = "KC135MPRS", kind = "drogue", callsignIndex = 2,
        frequency = 256.0, tacan = 52, tacanId = "ARC", alt = 5500, speed = 160, offsetBack = 15000 },
    },
  },

  manpads = {
    enabled        = true,
    zonesPerAO     = {1, 2},       -- angekündigte MANPADS-Zonen pro AO (min, max)
    airfieldChance = 0.6,          -- Chance, dass eine Zone direkt auf dem Ziel-Flugplatz liegt
    radius         = 4000,
    teams          = {2, 4},       -- Trupps pro Zone
    type           = "SA-18 Igla manpad",
    safeAltFt      = 12000,        -- Empfehlung in der Warnmeldung
  },

  cas = {
    maxActive      = 10,
    autoSpawn      = true,
    spawnAll       = true,         -- alle CAS-Ziele einer AO erscheinen sofort beim Aktivieren (maxActive muss dafür groß genug sein)
    firstDelay     = 30,
    interval       = {300, 900},
    successPercent = 70,
    intelError     = 300,
    manpadsChance  = 0.3,
  },

  ship = {
    enabled        = true,
    maxActive      = 1,
    autoSpawn      = false,        -- true = Schiffsziele automatisch in Intervallen, sonst nur per F10
    autoInterval   = {1200, 2400},
    firstDelay     = 600,
    difficulty     = 2,            -- Standardstufe bei "Current difficulty" (1..#tiers)
    distance       = {35000, 80000}, -- Abstand des Ziels zu einem nicht-blauen Flugplatz (m), muss auf See liegen
    seaMargin      = 3000,         -- um den Startpunkt muss in diesem Radius nur Wasser sein
    leg            = 25000,        -- Länge der Fahrtstrecke (hin und zurück)
    speed          = 6,            -- m/s (ca. 12 kn)
    spacing        = 800,          -- Abstand der Schiffe in der Formation (m)
    minDistPlayers = 20000,
    successPercent = 100,          -- Anteil zerstörter Schiffe für "Auftrag erfüllt"
    intelError     = 1500,         -- Ungenauigkeit der Kartenmarkierung (m)
    markUpdate     = 60,           -- Markierung alle X s nachführen
    cleanupAfter   = 600,
    -- Pro Stufe: Schiffstypen, Skill und alertRange. alertRange > 0: Schiffe halten das Feuer (ROE WEAPON_HOLD),
    -- bis ein Spieler näher als alertRange (m) kommt oder ein Schiff getroffen wird ("Hinterhalt"). Stand-off-Waffen
    -- (RB 15F, Harpoon) treffen so ein noch ruhendes Ziel. alertRange 0 = Schiffe sind sofort feuerbereit.
    -- Typnamen ungetestet (ALBATROS = Grisha, MOLNIYA = Tarantul, NEUSTRASH = Neustrashimy); falsche Namen meldet das Skript.
    tiers = {
      [1] = { label = "Merchant ships (unarmed)", skill = "Average", alertRange = 0,
              ships = { "Dry-cargo ship-1", "ELNYA" },
              brief = "No air defense. Any anti-ship weapon will do." },
      [2] = { label = "Missile boat", skill = "Good", alertRange = 15000,
              ships = { "MOLNIYA" },
              brief = "Light AAA and short-range SAM. Engages inside ~15 km; stand off with RB 15F/Harpoon or use Mavericks from a low, fast attack." },
      [3] = { label = "Corvette pair", skill = "High", alertRange = 30000,
              ships = { "ALBATROS", "ALBATROS" },
              brief = "SA-N-4 and AAA. Engages inside ~30 km; stand-off weapons recommended." },
      [4] = { label = "Frigate group (full defense)", skill = "Excellent", alertRange = 0,
              ships = { "NEUSTRASH", "ALBATROS" },
              brief = "Fully alert, layered air defense. Stand-off weapons and good timing only." },
    },
  },

  convoy = {
    enabled        = true,
    maxActive      = 1,
    autoSpawn      = false,
    autoInterval   = {1500, 3000},
    firstDelay     = 900,
    distance       = {30000, 70000}, -- Luftlinie Start–Ziel (m), Start und Ziel liegen an roten Flugplätzen
    speed          = 12,           -- m/s (ca. 43 km/h)
    size           = {5, 8},
    maxAAA         = 2,            -- höchstens so viele Flak-Fahrzeuge
    types          = { "Ural-375", "Ural-4320T", "GAZ-66", "UAZ-469" },  -- leichte Fahrzeuge
    aaaTypes       = { "Ural-375 ZU-23", "ZSU-23-4 Shilka" },
    successPercent = 70,
    arriveRadius   = 800,          -- so nah am Ziel gilt der Konvoi als angekommen (Auftrag verloren)
    minDistPlayers = 15000,
    cleanupAfter   = 600,
  },

  deepStrike = {
    enabled        = true,
    maxActive      = 1,
    autoSpawn      = false,
    autoInterval   = {2400, 4800},
    firstDelay     = 1200,
    minDistance    = 100000,       -- Mindestabstand zur nächsten blauen Basis (m) = langer Anflug
    defense        = { "ZSU-23-4 Shilka", "ZU-23 Emplacement", "Strela-10M3" },
    defenseRadius  = {150, 400},
    cleanupAfter   = 900,
    -- Statisches Ziel, das das Skript an den Koordinaten erzeugt (Platzhalter-Koordinaten, nach Belieben ändern).
    -- Typ/Kategorie ungetestet; schlägt ein Typ fehl, werden die Ersatztypen unten probiert.
    fallback       = { { type = "Warehouse", category = "Warehouses" }, { type = "Tank", category = "Warehouses" } },
    targets = {
      { name = "Command post north of Mozdok",   lat = 43.95, lon = 44.55, type = ".Command Center", category = "Fortifications" },
      { name = "Ammunition depot near Nalchik",  lat = 43.55, lon = 43.75, type = "Warehouse",       category = "Warehouses" },
      { name = "Fuel depot near Min. Vody",      lat = 44.30, lon = 43.15, type = "Tank",            category = "Warehouses" },
      { name = "Command post near Maykop",       lat = 44.75, lon = 40.15, type = ".Command Center", category = "Fortifications" },
      { name = "Supply depot near Krasnodar",    lat = 45.10, lon = 39.00, type = "Warehouse",       category = "Warehouses" },
    },
  },

  tic = {
    enabled        = true,
    maxActive      = 1,
    autoSpawn      = false,
    autoInterval   = {1800, 3600},
    firstDelay     = 1500,
    -- Eigene Zone abseits der SAM-Zonen, gedacht für A-10C und AH-64D (kein SAM-Risiko, nur leichte Flak):
    --  1) Trigger-Zonen, deren Name mit zonePrefix beginnt (im Editor frei platzierbar), sonst
    --  2) automatisch: baseDistance m von einer blauen Basis, außerhalb aller aktiven AOs (+ aoMargin)
    --     und mindestens samClearance von jeder bekannten SAM-Stellung entfernt.
    zonePrefix     = "TIC",
    baseDistance   = {10000, 45000},
    aoMargin       = 5000,
    samClearance   = 50000,
    samClearanceMin = 35000,       -- zweiter Versuch, falls mit samClearance nichts gefunden wird
    keepClear      = 45000,        -- solange der Auftrag läuft, werden hier keine neuen SAMs platziert
    friendlies     = { "M-2 Bradley", "M-2 Bradley", "M1043 HMMWV Armament", "M1043 HMMWV Armament", "M1045 HMMWV TOW", "M-113" },  -- nur Fahrzeuge (Einzelpersonen sind schwer zu finden)
    spawnDistance  = {4000, 7000}, -- Entfernung, aus der die Feinde anrücken (m)
    waves          = 3,
    waveInterval   = 300,          -- s zwischen den Wellen
    enemySpeed     = 8,            -- m/s
    -- Feindwellen (zufällig gewählt): leichte Fahrzeuge, Infanterie und nur Ural-ZU-23 als Flak
    waveTemplates  = {
      { "BMP-2", "BMP-2", "BTR-80", "Ural-375 ZU-23", "UAZ-469" },
      { "T-72B", "BMP-2", "BTR-80", "Ural-375 ZU-23" },
      { "BRDM-2", "BMP-2", "BMP-2", "BTR-80", "UAZ-469" },
    },
    successPercent = 90,           -- Anteil vernichteter Feinde nach der letzten Welle
    lossPercent    = 75,           -- ab diesem Verlust der Verbündeten gilt der Auftrag als verloren
    maxTime        = 2700,         -- s, danach läuft der Auftrag aus
    autoMarkRange  = 12000,        -- Verbündete markieren sich automatisch, sobald ein Spieler so nah kommt (m)
    laserCode      = 1688,
    cleanupAfter   = 600,
  },

  -- Frontline Battle: große Panzerschlacht nahe einer feindlichen Basis, Verbündete und Feinde kämpfen alleine (KI gegen KI)
  battle = {
    enabled        = true,
    maxActive      = 1,
    autoSpawn      = false,
    autoInterval   = {3000, 6000},
    firstDelay     = 2400,
    -- Kräfteverhältnis: Rot ist ohne Spieler überlegen, die Verbündeten brauchen CAS (Test v4.29: Blau mit Abrams gewann haushoch)
    bluePerSide    = 30,           -- Fahrzeuge Blau (in Gruppen zu je groupSize)
    redPerSide     = 36,           -- Fahrzeuge Rot
    blueSkill      = "Average",
    redSkill       = "Excellent",
    groupSize      = 6,
    baseDistance   = {4000, 12000}, -- Schlachtfeld-Mitte so weit vom feindlichen Flugplatz (m)
    nearestBases   = 3,            -- ohne aktive AO: unter den X feindlichen Flugplätzen wählen, die einer blauen Basis am nächsten sind
    gap            = {2200, 3000}, -- Abstand der beiden Linien zu Beginn (m)
    lineSpacing    = 45,           -- Abstand der Fahrzeuge in der Linie (m)
    speed          = 7,            -- m/s Vormarsch
    blueUnits      = { "M-60", "M-2 Bradley", "M-2 Bradley", "M-113", "M-113", "M1043 HMMWV Armament" },   -- je Gruppe nur ein älterer Panzer
    redUnits       = { "T-72B3", "T-72B3", "BMP-3", "BMP-2", "BTR-82A", "ZSU-23-4 Shilka" },          -- Shilka: Achtung für A-10/AH-64
    activateRange  = 20000,        -- Truppen warten (Feuer halten, kein Vormarsch), bis ein Spieler so nah (m) an der Schlachtfeld-Mitte ist
    waves          = 3,            -- Verstärkungswellen je Seite (nur solange ein Spieler in der Nähe ist)
    waveGroups     = 3,            -- Gruppen pro Welle
    waveBelow      = 40,           -- neue Welle, wenn eine Seite unter diesen Anteil (%) ihrer Grundstärke fällt
    waveCooldown   = 180,          -- s Mindestabstand zwischen zwei Wellen derselben Seite
    waveBack       = 1500,         -- Wellen rücken aus so viel m hinter der eigenen Ausgangslinie an
    endPercent     = 85,           -- Seite besiegt: alle Wellen verbraucht und nur noch (100 - endPercent) % der Grundstärke übrig
    maxTime        = 2700,         -- s ab Kampfbeginn, danach gilt die Schlacht als unentschieden
    idleTime       = 7200,         -- s ohne Spieler in der Nähe, nach denen eine wartende Schlacht abgebaut wird
    cleanupAfter   = 600,
  },

  siting = {
    enabled        = true,
    sceneryRadius  = 150,          -- Radarstandorte mindestens so weit (m) von Szenerie-Objekten (Gebäude, Masten, ggf. Bäume) entfernt
    noZonePrefix   = "NOSAM",      -- Editor-Trigger-Zonen mit diesem Namensanfang (z. B. über Wäldern) sind für SAMs/Radare gesperrt
    -- Gelände: nicht an steilen Hängen, nicht in Kesseln/Tälern mit hohen Bergen ringsum
    slopeRadius    = 150,          -- Hangneigung wird auf diesem Radius (m) in 8 Richtungen gemessen
    maxSlopeDeg    = 6,            -- steilere Standorte werden abgelehnt
    horizonDist    = {1500, 3000, 5000},  -- Abstände (m), in denen der Horizont in 8 Richtungen geprüft wird
    antennaHeight  = 15,           -- Höhe der Radarantenne über Grund (m)
    maxHorizonDeg  = 6,            -- Gelände höher als dieser Erhebungswinkel blockiert die Richtung
    maxBlockedDirs = 3,            -- ab so vielen blockierten Richtungen (von 8) wird der Standort abgelehnt
    -- Bebauung: nicht zwischen vielen/hohen Gebäuden
    urbanRadius    = 400,          -- ab urbanMax Szenerie-Objekten in diesem Radius (m) gilt der Ort als Stadt
    urbanMax       = 10,
    tallHeight     = 12,           -- Objekte mindestens so hoch (m) zählen als Hochhaus ...
    tallRadius     = 300,          -- ... und sperren den Standort im Umkreis (m)
    -- Straßennähe: Wälder lassen sich in DCS nicht abfragen, an Straßen und Feldwegen ist das Gelände meist offen.
    -- SAM-Stellungen werden daher (im ersten Durchlauf) an eine Stelle roadDist m neben die nächste Straße verschoben.
    nearRoad       = true,
    roadDist       = {60, 250},    -- Abstand zur Straße (m): nicht direkt auf der Straße, aber nah dran
    roadMaxShift   = 6000,         -- weiter als so viele m wird ein Standort für die Straßennähe nicht verschoben
  },

  fortress = {
    enabled        = true,
    unlockAfter    = 0,            -- 0 = Hauptbasis wird erst aktiv, wenn alle anderen Flugplätze erobert sind (Finale); N > 0 = schon nach N Eroberungen (dann dauerhaft aktiv)
    candidates     = 5,            -- Hauptbasis: wird beim Kampagnenstart (unsichtbar) zufällig unter den X am weitesten von den blauen Basen entfernten roten Flugplätzen reserviert
    radius         = 45000,        -- Kreis auf der F10-Karte
    intelError     = 3000,         -- Start-Ungenauigkeit der Stellungen (m): bewusste, bekannte Bedrohung
    -- Schichten von außen nach innen: Typ, Anzahl, Abstand zur Basis (m), Mindestabstand untereinander (m)
    layers = {
      { key = "SA5",  count = 2, dist = {22000, 34000}, sep = 18000 },   -- S-200: große Reichweite, außen
      { key = "SA10", count = 2, dist = {10000, 20000}, sep = 10000 },   -- S-300PS: mittlere Schicht
      { key = "SA11", count = 2, dist = {5000, 12000},  sep = 5000 },    -- Buk: Bereichsschutz
      { key = "SA15", count = 2, dist = {2500, 7000},   sep = 3500 },    -- Tor: Nahbereich gegen ARM und Präzisionswaffen
    },
    ewr            = { "1L13 EWR", "55G6 EWR" },                          -- Frühwarnradar (ungetestete Typnamen)
    guards         = { "ZSU-23-4 Shilka", "ZSU-23-4 Shilka", "Strela-10M3", "Strela-10M3", "ZU-23 Emplacement", "ZU-23 Emplacement" },
    garrison       = true,
    manpads        = true,
  },

  farp = {
    enabled        = true,
    maxFarps       = 3,            -- gleichzeitig bestehende Vorwärts-FARPs
    slotsPerFarp   = 4,            -- Kampfhubschrauber-Slots je Lieferung (Vorrat)
    types          = { "AH-64D_BLK_II" },   -- Typen der Slots (reihum); muss zum Land passen
    country        = country.id.USA,        -- Land der Slot-Gruppen (Skill "Client" lehnt DCS bei Skript-Gruppen ab, "Player" geht)
    padOffset      = 60,           -- FARP-Mitte so weit (m) nördlich des gelandeten Transporters
    slotOffset     = 18,           -- Abstand der Slots zur FARP-Mitte (m)
    resupplyRadius = 250,          -- Lieferung innerhalb dieses Radius (m) füllt den nächsten FARP auf
    minSeparation  = 1500,         -- Mindestabstand zwischen zwei FARPs (m)
    maxSpeed       = 1.5,          -- m/s: so langsam muss der Transporter stehen
    cooldown       = 300,          -- s zwischen zwei Lieferungen an denselben FARP
    -- Bewaffnung der Slots. Leere pylons = unbewaffnet. Wird in einer AH-64D-Vorlage der Mission (Dynamic Spawn)
    -- Bewaffnung eingestellt, übernehmen die FARP-Slots sie automatisch; sonst zählt dieser Eintrag (CLSIDs aus dem Editor).
    payloads = {
      ["AH-64D_BLK_II"] = { pylons = {}, fuel = 1438, flare = 45, chaff = 90, gun = 100 },
    },
  },

  bomber = {
    enabled        = true,
    maxActive      = 1,
    autoSpawn      = false,
    autoInterval   = {2400, 4800},
    firstDelay     = 1800,
    distance       = {150000, 350000}, -- Luftlinie vom feindlichen Startflugplatz zum blauen Zielflugplatz (m)
    types = {                      -- ohne Waffen: der Abwurf wird vom Skript nachgestellt (Explosionen), nur der Typ zählt
      { type = "Tu-95MS", alt = 9000,  speed = 210, size = {2, 3}, fuel = 30000 },
      { type = "Tu-160",  alt = 10000, speed = 250, size = {1, 2}, fuel = 30000 },
    },
    releaseRange   = 12000,        -- so nah am Ziel wirft ein Bomber ab (m)
    bombs          = 8,            -- Explosionen pro Bomber
    bombSpacing    = 120,          -- m
    bombPower      = 250,          -- Sprengkraft je Explosion; 0 = nur Meldung, kein Schaden (Achtung: kann Objekte/geparkte Flugzeuge am Platz zerstören)
    startOffset    = 5000,         -- Startpunkt in der Luft so weit vom Startflugplatz Richtung Ziel (m)
    minDistPlayers = 30000,
    reportInterval = 90,           -- s zwischen Lagemeldungen
    intelError     = 1500,         -- Ungenauigkeit der Kartenmarkierung (m)
    markUpdate     = 30,
    maxTime        = 5400,
    cleanupAfter   = 600,
  },

  -- SAM-Hinterhalte tief im Feindgebiet: einzelne Stellungen im Modus "ambush" (Radar erst bei Annäherung an),
  -- nur HINTER den aktiven AOs (weiter von der nächsten blauen Basis entfernt als die nächste AO + Radius + margin),
  -- nie zwischen eigenen Basen und den aktiven AOs; ohne Meldung, nicht im Lagebild, zählen nicht für die Eroberung
  ambush = {
    enabled      = true,
    maxActive    = 3,
    interval     = {600, 1200},    -- s zwischen zwei Spawn-Versuchen
    -- ältere, weniger tödliche Systeme (Nutzerwunsch); ohne SA-8-Punktverteidigung
    pool         = { SA3 = 3, SA2 = 2, SA6 = 2 },
    margin       = 15000,          -- m hinter dem AO-Rand (von blauen Basen aus gesehen)
    baseRadius   = {8000, 40000},  -- Abstand zum gewählten roten Flugplatz
    maxBlueDist  = 250000,         -- nicht weiter als X m von der nächsten blauen Basis (dort fliegt niemand)
    lifetime     = {3600, 7200},   -- s; danach abgebaut, sofern kein Spieler näher als despawnRange ist
    despawnRange = 60000,
  },

  -- "Chaos" im Feindgebiet (Syrien der 2010er): kleine Gefechte, feindliche Hubschrauber
  chaos = {
    skirmish = {                   -- kleine KI-Gefechte: US-Gerät (blau) gegen Regierungstruppen (rot)
      enabled     = true,
      maxActive   = 3,
      interval    = {300, 600},    -- s zwischen zwei neuen Gefechten
      size        = {4, 6},        -- Fahrzeuge je Seite
      gap         = {1500, 2500},  -- Anfangsabstand der Linien (m)
      lifetime    = {1800, 3600},  -- s; danach abgebaut, wenn kein Spieler näher als 20 km
      minBlueDist = 30000,         -- m von jeder blauen Basis
      blue = { "M-2 Bradley", "M1126 Stryker ICV", "M1043 HMMWV Armament", "M-113" },
      red  = { "T-72B", "BMP-2", "BTR-80", "T-55" },
    },
    helos = {                      -- feindliche Hubschrauber zwischen roten Flugplätzen (Gelegenheitsziele, ROE Waffen halten)
      enabled     = true,
      startOn     = true,          -- F10 A2A > "Enemy helicopters: toggle ON/OFF"
      maxActive   = 2,
      interval    = {300, 900},
      types       = { "Mi-8MT" },      -- nur Transporthubschrauber, unbewaffnet (keine Pylone, Bordwaffen ohne Munition)
      size        = {1, 2},
      alt         = 150,           -- m über Grund
      speed       = 55,
      dist        = {30000, 150000},  -- Strecke zwischen Start- und Zielplatz
      minBlueDist = 40000,
      timeout     = 3600,
    },
  },

  -- Scud-Jagd: ein Scud-Werfer baut sich im Hinterland auf und feuert nach setupTime echte Raketen (FireAtPoint)
  -- auf die nächste blaue Basis in Reichweite; Overlord meldet nur ein grobes Gebiet (Kreis auf der Karte)
  scud = {
    enabled       = true,
    interval      = {1800, 3600},  -- s zwischen zwei Scud-Einsätzen (nach Ende des vorigen)
    setupTime     = {1200, 1500},  -- s von der Meldung bis zum Feuerbefehl (dann noch Aufrichten des Werfers)
    range         = {80000, 280000},  -- Entfernung zum Ziel (Scud-B: ca. 50–300 km)
    areaRadius    = 37000,         -- Radius des gemeldeten Suchgebiets (20 NM); der Werfer liegt irgendwo darin
    salvo         = 1,
    impactRadius  = 300,
    fireTimeout   = 480,           -- s nach Feuerbefehl ohne Abschuss-Ereignis -> Einschlag wird nachgestellt
    fallbackPower = 800,           -- Sprengkraft des nachgestellten Einschlags
    escort        = { "Ural-375", "UAZ-469" },
    minBlueDist   = 60000,
  },

  -- Eskorte: eine verbündete C-130 fliegt vom hintersten zum vordersten eigenen Flugplatz; sie wartet am Treffpunkt
  -- auf Begleitschutz, unterwegs starten feindliche Abfangjäger gegen sie (aktuelle CAP-Stufe)
  escort = {
    enabled       = true,
    autoInterval  = {3600, 5400},  -- s zwischen automatischen Eskortaufträgen (0/nil = nur per F10)
    type          = "C-130",
    alt           = 6000,          -- m
    speed         = 140,           -- m/s
    minRoute      = 120000,        -- Mindeststrecke; sonst Start in der Luft weiter hinten
    holdTime      = 900,           -- s am Treffpunkt warten, bis ein Spieler-Jet näher als joinDist ist
    joinDist      = 18500,         -- 10 NM
    waves         = { 0.3, 0.65 }, -- Abfangwellen bei diesem Anteil der Strecke (zweite nur ab longRoute)
    longRoute     = 200000,
    interceptDist = 90000,         -- Abfangjäger erscheinen so weit von der C-130 entfernt, Richtung Feindgebiet
    huntUpdate    = 30,
  },

  -- CSAR: abgeschossene Piloten (Spieler nach Schleudersitz über Feindgebiet oder zufällig ein Verbündeter nahe einer AO)
  -- müssen per Hubschrauber abgeholt und zu einem eigenen Flugplatz/FARP gebracht werden; Feindfahrzeuge rücken an
  csar = {
    enabled       = true,
    playerEject   = true,
    allyInterval  = {2700, 5400},  -- s zwischen zufälligen Verbündeten-Abschüssen (0/nil = aus)
    maxActive     = 2,
    timeout       = 7200,          -- s; danach gilt ein nicht abgeholter Pilot als verloren
    enemyGroups   = {1, 2},
    enemySize     = {2, 3},
    enemyTypes    = { "BTR-80", "UAZ-469", "BRDM-2" },
    enemyDist     = {4000, 7000},  -- Startentfernung der anrückenden Feinde
    enemySpeed    = 2.5,           -- m/s (ca. 30-45 min bis zum Piloten)
    captureDist   = 150,
    pickupDist    = 80,            -- gelandeter Hubschrauber so nah am Piloten -> an Bord
    deliverDist   = 3000,          -- Landung so nah an einer blauen Basis/FARP -> gerettet
    smokeDist     = 6000,          -- Hubschrauber in dieser Entfernung -> grüner Rauch (alle 5 min)
  },

  cap = {
    enabled      = true,
    maxActive    = 4,              -- gleichzeitig aktive feindliche CAP-Gruppen (auch mehrere vom selben Typ)
    huntUpdate   = 30,             -- s: Jagd-CAP ("hunt") fliegt immer zum nächsten Spieler in der Luft, Kurs alle X s neu
    -- Dauer-CAP (F10 A2A > Respawning CAP an/aus): startet vom Boden eines feindlichen Flugplatzes (Startbahn),
    -- patrouilliert an der nächsten aktiven AO und kommt nach Verlust wieder (aktuelle Schwierigkeit)
    persistent   = {
      groups       = 1,            -- gleichzeitig aktive Dauer-CAP-Gruppen (zählen nicht gegen maxActive)
      respawnDelay = {300, 600},   -- s nach Verlust bis zum nächsten Start
      minBlueDist  = 60000,        -- Startplatz mindestens so weit von jeder blauen Basis (m)
      stuckTimeout = 900,          -- s: nie abgehoben -> entfernen und neu starten
      patrolLength = 40000,        -- Länge des Racetracks (m)
    },
    autoChance   = 0.0,            -- z.B. 0.3 = 30 % pro Intervall, 0 = nur per F10
    autoInterval = {900, 1800},
    difficulty   = 3,              -- 1 = nur Fox-2, 2 = frühe Fox-1, 3 = R-27 Fox-1, 4 = Fox-3
    progressive  = false,          -- Schwierigkeit steigt mit eroberten Flugplätzen
    progressStep = 3,              -- +1 Stufe alle X eroberten Flugplätze (bis max. Stufe 4)
    size         = 2,
    alt          = 7000,
    speed        = 220,
    -- Pro Stufe eine oder mehrere Varianten (zufällig gewählt). loadout -> D.capLoadouts
    tiers = {
      [1] = { label = "Fox-2 only", skill = "Average", variants = {
              { type = "MiG-23MLD", loadout = "MiG-23_FOX2" } } },
      [2] = { label = "early Fox-1 (R-24R)", skill = "Good", variants = {
              { type = "MiG-23MLD", loadout = "MiG-23_FOX1" } } },
      [3] = { label = "Fox-1 (R-27)", skill = "High", variants = {
              { type = "MiG-29A", loadout = "MiG-29A_FOX1" },
              { type = "Su-27",   loadout = "Su-27_FOX1" } } },
      [4] = { label = "Fox-3 (R-77)", skill = "Excellent", variants = {
              { type = "MiG-29S", loadout = "MiG-29S_FOX3" } } },
    },
  },
}

-------------------------------------------------------------------------------
-- DEFINITIONEN
-------------------------------------------------------------------------------
D.samTypes = {
  SA2  = { name = "SA-2 Guideline", track = {"SNR_75V"}, search = {"p-19 s-125 sr"},
           ln = "S_75M_Volhov", nLn = 6, r = 100, critical = "track" },
  SA3  = { name = "SA-3 Goa", track = {"snr s-125 tr"}, search = {"p-19 s-125 sr"},
           ln = "5p73 s-125 ln", nLn = 4, r = 80, critical = "track" },
  SA6  = { name = "SA-6 Gainful", track = {"Kub 1S91 str"}, search = {},
           ln = "Kub 2P25 ln", nLn = 4, r = 130, critical = "track" },
  SA11 = { name = "SA-11 Gadfly", track = {}, search = {"SA-11 Buk SR 9S18M1"},
           extra = {"SA-11 Buk CC 9S470M1"}, ln = "SA-11 Buk LN 9A310M1", nLn = 4, r = 160, critical = "ln" },
  SA8  = { name = "SA-8 Gecko", track = {}, search = {}, ln = "Osa 9A33 ln", nLn = 2, r = 250, critical = "ln" },
  SA15 = { name = "SA-15 Gauntlet", track = {}, search = {}, ln = "Tor 9A331", nLn = 2, r = 250, critical = "ln" },
  -- schwere Flak (sam.aaa): KS-19 100 mm mit zwei, S-60 57 mm mit einem Fire-Can-Feuerleitradar
  AAA100 = { name = "Heavy AAA KS-19 + 2x Fire Can", track = {"SON_9"}, search = {}, extra = {"SON_9"},
             ln = "KS-19", nLn = 4, r = 90, critical = "track" },
  AAA57  = { name = "Heavy AAA S-60 + Fire Can", track = {"SON_9"}, search = {},
             ln = "S-60_Type59_Artillery", nLn = 6, r = 70, critical = "track" },
  -- nur für die Hauptbasis (nicht im Pool); Typnamen ungetestet. critical = "all": Zielradar UND alle Startgeräte müssen fallen
  SA5  = { name = "SA-5 Gammon (S-200)", track = {"RPC_5N62V"}, search = {"RLS_19J6"},
           ln = "S-200_Launcher", nLn = 4, r = 150, critical = "all" },
  SA10 = { name = "SA-10 Grumble (S-300PS)", track = {"S-300PS 40B6M tr"}, search = {"S-300PS 64H6E sr"},
           extra = {"S-300PS 54K6 cp"}, ln = "S-300PS 5P85C ln", nLn = 4, r = 120, critical = "all" },
}

D.shoradTypes = { "ZSU-23-4 Shilka", "Strela-10M3", "ZU-23 Emplacement" }

D.casTemplates = {
  { name = "Mech. platoon",           units = {"BMP-2","BMP-2","BMP-2","BTR-80","Ural-375","BTR-80"} },
  { name = "Tank platoon",           units = {"T-72B","T-72B","T-72B","BMP-2","ZSU-23-4 Shilka"} },
  { name = "Artillery battery",      units = {"SAU Gvozdika","SAU Gvozdika","SAU Gvozdika","SAU Gvozdika","Ural-375","BRDM-2"} },
  { name = "Supply convoy",          units = {"Ural-375","Ural-375","Ural-4320T","Ural-375","BTR-80","Ural-375 ZU-23"}, convoy = true },
  { name = "Mech. column",           units = {"BRDM-2","BMP-2","BMP-2","T-72B","Ural-375","Ural-375 ZU-23"}, convoy = true },
}

D.garrisonUnits = { "ZSU-23-4 Shilka", "ZU-23 Emplacement", "ZU-23 Emplacement", "Strela-10M3",
  "BMP-2", "BMP-2", "T-72B", "Ural-375", "BTR-80", "UAZ-469" }

local R73   = "{FBC29BFE-3D24-4C64-B81D-941239D12249}"
local R77   = "{B4C01D60-A8A3-4237-BD72-CA7655BC0FE9}"
local R60   = "{682A481F-0CB5-4693-A382-D00DD4A156D7}"
local R24R  = "{CCF898C9-5BC7-49A4-9D1E-C3ED3D5166A1}"
local R27R  = "{9B25D316-0434-4954-868F-D51DB1A38DF0}"
local R27ER = "{E8069896-8435-4B90-95C0-01A03AE6E400}"
-- Hinweis: Ungültige Pylon/Waffen-Kombinationen ignoriert DCS. Das Skript prüft nach dem
-- Spawn, ob Raketen geladen sind, und meldet sonst einen Fehler mit dem Loadout-Namen.
D.capLoadouts = {
  ["MiG-23_FOX2"] = {
    pylons = { [2] = {CLSID = R60}, [3] = {CLSID = R60}, [5] = {CLSID = R60}, [6] = {CLSID = R60} },
    fuel = 3800, flare = 30, chaff = 30, gun = 100 },
  ["MiG-23_FOX1"] = {
    pylons = { [1] = {CLSID = R24R}, [2] = {CLSID = R60}, [6] = {CLSID = R60}, [7] = {CLSID = R24R} },
    fuel = 3800, flare = 30, chaff = 30, gun = 100 },
  ["MiG-29A_FOX1"] = {
    pylons = { [1] = {CLSID = R73}, [2] = {CLSID = R73}, [3] = {CLSID = R27R},
               [5] = {CLSID = R27R}, [6] = {CLSID = R73}, [7] = {CLSID = R73} },
    fuel = 3000, flare = 30, chaff = 30, gun = 100 },
  ["Su-27_FOX1"] = {
    pylons = { [1] = {CLSID = R73}, [2] = {CLSID = R73}, [3] = {CLSID = R27ER}, [4] = {CLSID = R27ER},
               [7] = {CLSID = R27ER}, [8] = {CLSID = R27ER}, [9] = {CLSID = R73}, [10] = {CLSID = R73} },
    fuel = 9400, flare = 96, chaff = 96, gun = 100 },
  ["MiG-29S_FOX3"] = {
    pylons = { [1] = {CLSID = R73}, [2] = {CLSID = R73}, [3] = {CLSID = R77},
               [5] = {CLSID = R77}, [6] = {CLSID = R73}, [7] = {CLSID = R73} },
    fuel = 3000, flare = 30, chaff = 30, gun = 100 },
}

-------------------------------------------------------------------------------
-- STATUS
-------------------------------------------------------------------------------
D.aos           = {}
D.sites         = {}
D.casTasks      = {}
D.ships         = {}
D.convoys       = {}
D.deeps         = {}
D.tics          = {}
D.battles       = {}
D.bombers       = {}
D.fortress      = nil
D.fortressBase  = nil
D.caps          = {}
D.capPersist    = {}
D.capPersistOn  = false
D.targetPool    = {}
D.targetsTotal  = 0
D.capturedCount = 0
D.counter       = 0
D.markId        = 7000
D.started       = false
D.stats         = { sam = 0, cas = 0, cap = 0, ship = 0, convoy = 0, deep = 0, tic = 0, bomber = 0, fortress = 0, battle = 0,
                    scud = 0, csar = 0, escort = 0 }
D.blueBases     = {}
D.nextSam       = math.huge
D.nextCas       = math.huge
D.nextShip      = math.huge
D.nextConvoy    = math.huge
D.nextDeep      = math.huge
D.nextTic       = math.huge
D.nextBattle    = math.huge
D.nextBomber    = math.huge
D.nextCapRoll   = math.huge
D.arms          = {}
D.armLoopRunning = false
D.awacsSpawned  = false
D.awacsRespawnAt = nil

-------------------------------------------------------------------------------
-- HILFSFUNKTIONEN
-------------------------------------------------------------------------------
-- Skript-Gruppen sind standardmäßig auf der F10-Karte versteckt (Position nur über ELINT/Meldungen); zum Testen sichtbar
function D.hideOnMap() return not D.cfg.debugVisibleUnits end

local function msg(text)
  trigger.action.outTextForCoalition(D.cfg.blueSide, text, D.cfg.msgTime)
end

local function reportError(where, err)
  env.error("DynSEAD " .. where .. ": " .. tostring(err))
  if D.cfg.showErrors then
    trigger.action.outText("DynSEAD ERROR (" .. where .. "):\n" .. tostring(err), 60)
  end
end

local function safe(fn, where)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then reportError(where or "?", err) end
  end
end

local function nextId(prefix)
  D.counter = D.counter + 1
  return string.format("%s-%03d", prefix, D.counter)
end

local function newMarkId()
  D.markId = D.markId + 1
  return D.markId
end

local function randRange(t) return t[1] + math.random() * (t[2] - t[1]) end

local function weighted(tbl)
  local total = 0
  for _, w in pairs(tbl) do total = total + w end
  local r = math.random() * total
  for k, w in pairs(tbl) do
    r = r - w
    if r <= 0 then return k end
  end
  return (next(tbl))
end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function toV2(p3) return { x = p3.x, y = p3.z } end
local function toV3(p2) return { x = p2.x, y = land.getHeight(p2), z = p2.y } end

local function jitter(p, r)
  local a = math.random() * 2 * math.pi
  local d = r * math.sqrt(math.random())
  return { x = p.x + d * math.cos(a), y = p.y + d * math.sin(a) }
end

local function offset(p, heading, d)
  return { x = p.x + d * math.cos(heading), y = p.y + d * math.sin(heading) }
end

local function fmtDist(m)
  if m >= 1000 then return string.format("%.1f km", m / 1000) end
  return string.format("%d m", math.floor(m + 0.5))
end

local function playerPositions()
  local out = {}
  for _, u in ipairs(coalition.getPlayers(D.cfg.blueSide) or {}) do
    if u and u:isExist() then out[#out + 1] = toV2(u:getPoint()) end
  end
  return out
end

local function farFrom(p, list, d)
  for _, q in ipairs(list or {}) do
    if dist(p, q) < d then return false end
  end
  return true
end

local function okGround(p)
  if land.getSurfaceType(p) ~= land.SurfaceType.LAND then return false end
  local h = land.getHeight(p)
  for _, o in ipairs({ {250, 0}, {-250, 0}, {0, 250}, {0, -250} }) do
    local q = { x = p.x + o[1], y = p.y + o[2] }
    if land.getSurfaceType(q) ~= land.SurfaceType.LAND then return false end
    if math.abs(land.getHeight(q) - h) > 35 then return false end
  end
  return true
end

local function unitAlive(name)
  local u = Unit.getByName(name)
  return u ~= nil and u:isExist() and u:getLife() >= 1
end

local function groupPos(gname)
  local g = Group.getByName(gname)
  if not g or not g:isExist() then return nil end
  for _, u in ipairs(g:getUnits()) do
    if u:isExist() then return toV2(u:getPoint()) end
  end
  return nil
end

local function groupAliveCount(gname)
  local g = Group.getByName(gname)
  if not g or not g:isExist() then return 0 end
  local n = 0
  for _, u in ipairs(g:getUnits()) do
    if u:isExist() and u:getLife() >= 1 then n = n + 1 end
  end
  return n
end

-- Bodengruppen so vollständig wie Editor-Gruppen anlegen (Gruppen-x/y, Startwegpunkt, Editor-Felder).
function D.addGround(country, data)
  local u1 = data.units and data.units[1]
  if u1 then
    data.x = data.x or u1.x
    data.y = data.y or u1.y
    if not data.route then
      data.route = { points = { { x = u1.x, y = u1.y, alt = land.getHeight({ x = u1.x, y = u1.y }), alt_type = "BARO",
        type = "Turning Point", action = "Off Road", speed = 0, ETA = 0, ETA_locked = true, speed_locked = true,
        formation_template = "", task = { id = "ComboTask", params = { tasks = {} } } } } }
    end
  end
  if data.visible == nil then data.visible = false end
  if data.hidden == nil then data.hidden = false end
  if data.hiddenOnMFD == nil then data.hiddenOnMFD = false end
  if data.hiddenOnPlanner == nil then data.hiddenOnPlanner = data.hidden end
  if data.uncontrollable == nil then data.uncontrollable = false end
  if data.lateActivation == nil then data.lateActivation = false end
  data.start_time = data.start_time or 0
  data.tasks = data.tasks or {}
  for _, u in ipairs(data.units or {}) do
    if u.transportable == nil then u.transportable = { randomTransportable = false } end
  end
  return coalition.addGroup(country, Group.Category.GROUND, data)
end

local function destroyGroup(gname)
  local g = Group.getByName(gname)
  if g and g:isExist() then g:destroy() end
end

local function ddm(v, pos, neg, width)
  local h = v >= 0 and pos or neg
  v = math.abs(v)
  local d = math.floor(v)
  local m = (v - d) * 60
  return string.format("%s%0" .. width .. "d°%06.3f'", h, d, m)
end

local function beParts(p)
  local be = coalition.getMainRefPoint(D.cfg.blueSide)
  if not be then return nil end
  local dN, dE = p.x - be.x, p.y - be.z
  local brg = math.floor((math.deg(math.atan2(dE, dN)) + 360) % 360 + 0.5) % 360
  local rng = math.floor(dist(p, { x = be.x, y = be.z }) / 1852 + 0.5)
  return brg, rng
end

-- Funksprüche bestehen aus Bausteinen (Dateinamen ohne "ov_" und ".wav")
local function tDigits(str)                 -- "045" -> d0 d4 d5
  local t = {}
  for c in tostring(str):gmatch("%d") do t[#t + 1] = "d" .. c end
  return t
end
local function tNum(n)                      -- 0..999 als gesprochene Zahl
  n = math.max(0, math.floor(n))
  local t = {}
  if n >= 100 then
    t[#t + 1] = "n" .. math.floor(n / 100); t[#t + 1] = "hundred"
    n = n % 100
    if n == 0 then return t end
  end
  if n < 20 then
    t[#t + 1] = "n" .. n
  else
    t[#t + 1] = "n" .. (math.floor(n / 10) * 10)
    if n % 10 > 0 then t[#t + 1] = "n" .. (n % 10) end
  end
  return t
end
local function tBE(p)
  local brg, rng = beParts(p)
  if not brg then return {} end
  return { "bullseye", tDigits(string.format("%03d", brg)), tNum(rng) }
end
local function tSam(key) return { "sa" .. (key:match("%d+") or "") } end
local function tDist(m)                     -- "plus minus 3 kilometers" / "plus minus 7 hundred meters"
  if m >= 950 then return { "plus_minus", tNum(math.floor(m / 1000 + 0.5)), "kilometers" } end
  return { "plus_minus", tNum(math.max(1, math.floor(m / 100 + 0.5))), "hundred", "meters" }
end
local function tPlace(name)                 -- Flugplatz-/AO-Name -> Baustein (fehlt er, wird er übersprungen)
  return "af_" .. tostring(name):lower():gsub("[^%w]", "")
end
local function tAircraft(typ)
  local k = typ:lower():gsub("[^%w]", "")
  if k:find("^mig23") then return "mig23" elseif k:find("^mig29") then return "mig29"
  elseif k:find("^su27") then return "su27" end
  return nil
end

local function bullseyeStr(p)
  local be = coalition.getMainRefPoint(D.cfg.blueSide)
  if not be then return "" end
  local dN, dE = p.x - be.x, p.y - be.z
  local brg = (math.deg(math.atan2(dE, dN)) + 360) % 360
  local rng = dist(p, { x = be.x, y = be.z }) / 1852
  return string.format("BE %03d/%d", math.floor(brg + 0.5) % 360, math.floor(rng + 0.5))
end

function D.fmtPos(p)
  local lat, lon = coord.LOtoLL(toV3(p))
  local m = coord.LLtoMGRS(lat, lon)
  local mgrs = string.format("%s %s %05d %05d", m.UTMZone, m.MGRSDigraph,
    math.floor(m.Easting), math.floor(m.Northing))
  local ll = ddm(lat, "N", "S", 2) .. " " .. ddm(lon, "E", "W", 3)
  local elev = math.floor(land.getHeight(p) * 3.28084)
  return string.format("%s | %s | %s | %d ft", bullseyeStr(p), mgrs, ll, elev)
end

-- Hubschrauber-Landeplätze, die die Karte als Flugplatz meldet (D.map.ignore), zählen nirgends mit
function D.ignoredBase(ab)
  local ok, name = pcall(function() return ab:getName() end)
  if not ok or not name then return true end
  for _, pat in ipairs((D.map and D.map.ignore) or {}) do
    if name:find(pat) then return true end
  end
  return false
end

function D.refreshBlueBases()
  D.blueBases = {}
  for _, ab in ipairs(world.getAirbases() or {}) do
    if ab:getCoalition() == D.cfg.blueSide and not D.ignoredBase(ab) then
      local p = toV2(ab:getPoint())
      p.name = ab:getName()
      D.blueBases[#D.blueBases + 1] = p
    end
  end
end

local function tacanFreq(ch, mode)
  local A, B = 1151, 64
  if ch < 64 then B = 1 end
  if mode == "Y" then
    A = (ch < 64) and 1088 or 1025
  elseif ch < 64 then
    A = 962
  end
  return (A + ch - B) * 1000000
end

local function supportUnit(gname)
  local g = Group.getByName(gname)
  if not g or not g:isExist() then return nil end
  local u = g:getUnit(1)
  if u and u:isExist() and u:getLife() >= 1 then return u end
  return nil
end

local function nearestBlueBase(p)
  local best, bd = nil, math.huge
  for _, b in ipairs(D.blueBases) do
    local d = dist(b, p)
    if d < bd then best, bd = b, d end
  end
  return best
end

local function airWP(p, alt, speed, tasks)
  return { x = p.x, y = p.y, alt = alt, alt_type = "BARO", type = "Turning Point",
    action = "Turning Point", speed = speed, speed_locked = true,
    ETA = 0, ETA_locked = false, task = { id = "ComboTask", params = { tasks = tasks or {} } } }
end

-------------------------------------------------------------------------------
-- SPRACHAUSGABE (Overlord über SRS)
-------------------------------------------------------------------------------
D.voiceQueue = {}
D.voiceBusyUntil = 0
D.voiceOK = false
D.voiceTx = 0

local function flatten(list, out)
  out = out or {}
  for _, v in ipairs(list) do
    if type(v) == "table" then flatten(v, out) elseif v then out[#out + 1] = v end
  end
  return out
end

-- tokens: verschachtelte Liste von Baustein-Namen; "overlord" wird automatisch vorangestellt
function D.say(tokens)
  local v = D.cfg.voice
  if not v.enabled or not D.voiceOK then return end
  local clips = DynSEAD_VOICE.clips
  local seq = {}
  for _, tk in ipairs(flatten({ "overlord", tokens })) do
    if clips[tk] then seq[#seq + 1] = tk else env.info("DynSEAD voice: missing clip " .. tostring(tk)) end
  end
  if #seq <= 1 then return end
  D.voiceQueue[#D.voiceQueue + 1] = seq
  while #D.voiceQueue > v.maxQueue do table.remove(D.voiceQueue, 1) end
end

local function playClip(tk)
  local file = "l10n/DEFAULT/ov_" .. tk .. ".wav"
  if D.cfg.voice.output == "radio" then
    local u = D.awacsUnit and D.awacsUnit()
    if not u then return end
    D.voiceTx = D.voiceTx + 1
    trigger.action.radioTransmission(file, u:getPoint(), 0, false,
      D.cfg.awacs.frequency * 1000000, 1000, "OverlordTx" .. D.voiceTx)
  else
    trigger.action.outSoundForCoalition(D.cfg.blueSide, file)
  end
end

function D.voiceTick(_, t)
  local ok, err = pcall(function()
    if #D.voiceQueue > 0 and t >= D.voiceBusyUntil then
      local seq = table.remove(D.voiceQueue, 1)
      local clips, off = DynSEAD_VOICE.clips, 0
      for _, tk in ipairs(seq) do
        timer.scheduleFunction(function() pcall(playClip, tk) end, nil, t + off)
        off = off + clips[tk] + D.cfg.voice.gap
      end
      D.voiceBusyUntil = t + off + 1.0
    end
  end)
  if not ok then reportError("Voice", err) end
  return t + 0.5
end

-------------------------------------------------------------------------------
-- AO-AUSWAHL
-------------------------------------------------------------------------------
local function aoCandidates(field)
  local out = {}
  for _, ao in ipairs(D.aos) do
    if ao.state == "active" and (not field or ao[field] > 0) then out[#out + 1] = ao end
  end
  return out
end

local function pickZone(list)
  if D.cfg.zoneWeighting == "equal" then return list[math.random(#list)] end
  local total = 0
  for _, z in ipairs(list) do total = total + z.radius * z.radius end
  local r = math.random() * total
  for _, z in ipairs(list) do
    r = r - z.radius * z.radius
    if r <= 0 then return z end
  end
  return list[#list]
end

local function randomPointInZone(z, margin)
  local r = math.max(0, z.radius - (margin or 0)) * math.sqrt(math.random())
  local a = math.random() * 2 * math.pi
  return { x = z.x + r * math.cos(a), y = z.y + r * math.sin(a) }
end

-- Standortprüfung für SAMs/Radare: nicht in gesperrten Zonen, nicht direkt neben Gebäuden/Bäumen.
-- DCS bietet keine direkte Wald-Abfrage; erkannt wird, was world.searchObjects(SCENERY) liefert (Gebäude, Masten, evtl. Bäume),
-- großflächige Wälder sperrt man mit Trigger-Zonen "NOSAM*" im Editor. Wirkt nur im ersten Durchlauf von findSpot (weich).
D.siting = { tested = 0, scenery = 0, zone = 0, slope = 0, horizon = 0, urban = 0, apiFailed = false, noZones = nil }

function D.samSpotClear(p)
  local c = D.cfg.siting
  if not c or not c.enabled then return true end
  local st = D.siting
  st.tested = st.tested + 1

  if st.noZones == nil then
    st.noZones = {}
    local mz = env.mission and env.mission.triggers and env.mission.triggers.zones or {}
    for _, z in pairs(mz) do
      if type(z) == "table" and z.name and z.name:sub(1, #c.noZonePrefix) == c.noZonePrefix then
        local tz = trigger.misc.getZone(z.name)
        if tz and tz.radius and tz.radius > 0 then
          st.noZones[#st.noZones + 1] = { x = tz.point.x, y = tz.point.z, r = tz.radius }
        end
      end
    end
  end
  for _, z in ipairs(st.noZones) do
    if dist(p, z) < z.r then st.zone = st.zone + 1 return false end
  end

  -- Gelände: Hangneigung und Horizont (Berge ringsum verdecken das Radar)
  local h0 = land.getHeight(p)
  local maxSlope = 0
  for k = 0, 7 do
    local q = offset(p, k * math.pi / 4, c.slopeRadius)
    maxSlope = math.max(maxSlope, math.abs(land.getHeight(q) - h0) / c.slopeRadius)
  end
  if math.deg(math.atan(maxSlope)) > c.maxSlopeDeg then st.slope = st.slope + 1 return false end
  local blocked = 0
  for k = 0, 7 do
    local a = k * math.pi / 4
    for _, d in ipairs(c.horizonDist) do
      local dh = land.getHeight(offset(p, a, d)) - h0 - c.antennaHeight
      if dh > 0 and math.deg(math.atan(dh / d)) > c.maxHorizonDeg then blocked = blocked + 1 break end
    end
  end
  if blocked >= c.maxBlockedDirs then st.horizon = st.horizon + 1 return false end

  -- Szenerie: direkt neben Gebäuden, zwischen vielen oder hohen Gebäuden
  local v3 = toV3(p)
  local found = false
  local ok, err = pcall(function()
    world.searchObjects(Object.Category.SCENERY,
      { id = world.VolumeType.SPHERE, params = { point = v3, radius = c.sceneryRadius } },
      function() found = true return false end)
  end)
  if not ok then
    if not st.apiFailed then
      st.apiFailed = true
      env.warning("DynSEAD: scenery search not available, siting check limited to terrain and NOSAM zones: " .. tostring(err))
    end
    return true
  end
  if found then st.scenery = st.scenery + 1 return false end

  local wide = math.max(c.urbanRadius, c.tallRadius)
  local count, tall = 0, false
  pcall(function()
    world.searchObjects(Object.Category.SCENERY,
      { id = world.VolumeType.SPHERE, params = { point = v3, radius = wide } },
      function(obj)
        local okp, op = pcall(function() return obj:getPoint() end)
        local d = okp and op and dist(toV2(op), p) or wide
        if d <= c.urbanRadius then count = count + 1 end
        if d <= c.tallRadius then
          local okd, desc = pcall(function() return obj:getDesc() end)
          if okd and desc and desc.box and desc.box.max and desc.box.min
             and (desc.box.max.y - desc.box.min.y) >= c.tallHeight then
            tall = true
            return false
          end
        end
        return true
      end)
  end)
  if tall or count >= c.urbanMax then st.urban = st.urban + 1 return false end
  return true
end

-- Punkt neben die nächste Straße verschieben (nil, wenn keine Straße innerhalb maxShift liegt)
function D.nearRoad(p, maxShift)
  local c = D.cfg.siting
  if not c or not c.nearRoad then return p end
  local ok, rx, ry = pcall(land.getClosestPointOnRoads, "roads", p.x, p.y)
  if not ok or not rx then return nil end
  local r = { x = rx, y = ry }
  if dist(p, r) > (maxShift or c.roadMaxShift) then return nil end
  for _ = 1, 8 do
    local q = offset(r, math.random() * 2 * math.pi, randRange(c.roadDist))
    local okr, qx, qy = pcall(land.getClosestPointOnRoads, "roads", q.x, q.y)
    -- nicht auf einer anderen Straße landen
    if okr and qx and dist(q, { x = qx, y = qy }) >= c.roadDist[1] * 0.8 then return q end
  end
  return nil
end

D.safeZones = {}   -- { x, y, r }: im ersten Durchlauf von findSpot (SAM/CAS/CAP) gemieden

function D.findSpot(aos, avoid, sep, check)
  if #aos == 0 then return nil end
  local players = playerPositions()
  for pass = 1, 2 do
    local f = (pass == 1) and 1 or 0.5
    for _ = 1, 100 do
      local z = pickZone(aos)
      local p = randomPointInZone(z, 1000)
      if pass == 1 and check == D.samSpotClear then
        p = D.nearRoad(p)
        if p and dist(p, z) > z.radius - 1000 then p = nil end
      end
      local safe = p ~= nil
      if pass == 1 then
        for _, sz in ipairs(D.safeZones) do
          if dist(p, sz) < sz.r then safe = false break end
        end
      end
      if safe and okGround(p)
        and farFrom(p, players, D.cfg.minDistPlayers * f)
        and farFrom(p, D.blueBases, D.cfg.minDistBlueBase * f)
        and farFrom(p, avoid, (sep or 0) * f)
        and (pass ~= 1 or not check or check(p)) then
        return p, z
      end
    end
  end
  return nil
end

local function drawAO(ao)
  if not D.cfg.drawAO then return end
  if ao.drawId then trigger.action.removeMark(ao.drawId) end
  ao.drawId = newMarkId()
  trigger.action.circleToAll(D.cfg.blueSide, ao.drawId, toV3({ x = ao.x, y = ao.y }), ao.radius,
    {1, 0.15, 0.15, 0.9}, {1, 0.15, 0.15, 0.08}, 2, true, "AO " .. ao.name)
end

-------------------------------------------------------------------------------
-- SAM
-------------------------------------------------------------------------------
local function buildSamUnits(def, c, gname)
  local units, crit = {}, {}
  local hdg = math.random() * 2 * math.pi
  local function add(t, dx, dy, critical)
    local n = gname .. "-" .. (#units + 1)
    units[#units + 1] = { name = n, type = t, x = c.x + dx, y = c.y + dy,
      heading = hdg, skill = D.cfg.skill, playerCanDrive = false }
    if critical then crit[#crit + 1] = n end
  end
  local critTrack = (def.critical == "track" or def.critical == "all")
  local critLn = (def.critical == "ln" or def.critical == "all")
  local all = D.cfg.sam.killAll
  if all then critTrack, critLn = true, true end
  for _, t in ipairs(def.track or {}) do add(t, 0, 0, critTrack) end
  for i, t in ipairs(def.search or {}) do add(t, -180 * i, 120, all) end
  for i, t in ipairs(def.extra or {}) do add(t, 120 * i, -150, all) end
  for i = 1, def.nLn do
    local a = hdg + (i - 1) * 2 * math.pi / def.nLn
    add(def.ln, def.r * math.cos(a), def.r * math.sin(a), critLn)
  end
  if math.random() < D.cfg.sam.shoradChance then
    for _ = 1, math.random(1, 2) do
      local a = math.random() * 2 * math.pi
      add(D.shoradTypes[math.random(#D.shoradTypes)], 400 * math.cos(a), 400 * math.sin(a), D.cfg.sam.killAll)
    end
  end
  return units, crit
end

function D.setRadar(site, on)
  local g = Group.getByName(site.group)
  if not g or not g:isExist() then return end
  local c = g:getController()
  if not c then return end
  c:setOption(AI.Option.Ground.id.ALARM_STATE,
    on and AI.Option.Ground.val.ALARM_STATE.RED or AI.Option.Ground.val.ALARM_STATE.GREEN)
  site.radarOn = on
end

function D.spawnSam()
  local n = 0
  for _, st in ipairs(D.sites) do if not st.ao.fortress and not st.ao.ambush then n = n + 1 end end   -- Hauptbasis/Hinterhalte zählen nicht mit
  if n >= D.cfg.sam.maxActive then return false end
  local aos = aoCandidates("samLeft")
  if #aos == 0 then return false end

  local avoid = {}
  for _, s in ipairs(D.sites) do avoid[#avoid + 1] = s.pos end
  local p, ao = D.findSpot(aos, avoid, D.cfg.sam.minSeparation, D.samSpotClear)
  if not p then
    env.warning("DynSEAD: no valid SAM position found")
    return false
  end

  return D.createSam(ao, D.nextSamKey(ao), p)
end

-- SAM-Typ für die nächste Stellung der AO: zuerst je eine aus jeder Klasse (zufällige Reihenfolge), dann frei
function D.nextSamKey(ao)
  local cfg = D.cfg.sam
  if not ao.samPlan then
    ao.samPlan = {}
    for _, cls in pairs(cfg.classes or {}) do
      local sub = {}
      for k, w in pairs(cfg.pool) do if cls[k] then sub[k] = w end end
      if next(sub) then table.insert(ao.samPlan, math.random(#ao.samPlan + 1), weighted(sub)) end
    end
    if ao.aaaKey then table.insert(ao.samPlan, math.random(#ao.samPlan + 1), ao.aaaKey) end
  end
  if #ao.samPlan > 0 then return table.remove(ao.samPlan, 1) end
  return weighted(cfg.pool)
end

-------------------------------------------------------------------------------
-- SAM-HINTERHALTE im inaktiven Feindgebiet (hinter den aktiven AOs)
-------------------------------------------------------------------------------
D.nextAmbush = 0

-- liegt p "hinter" den AOs? (weiter von Blau entfernt als die nächste aktive AO samt Radius + margin)
function D.ambushSpotOk(p)
  local c = D.cfg.ambush
  local b = nearestBlueBase(p)
  if not b then return false end
  local dB = dist(p, b)
  if dB > c.maxBlueDist then return false end
  local nearest, nd
  for _, ao in ipairs(D.aos) do
    local q = { x = ao.x, y = ao.y }
    local d = dist(p, q)
    if d < ao.radius + c.margin then return false end
    if not nd or d < nd then nearest, nd = ao, d end
  end
  if nearest then
    local q = { x = nearest.x, y = nearest.y }
    local bq = nearestBlueBase(q)
    if bq and dB < dist(q, bq) + nearest.radius + c.margin then return false end
  elseif dB < c.margin * 4 then
    return false
  end
  if D.fortress and D.fortress.ao and dist(p, D.fortress.ao) < 30000 then return false end
  for _, sz in ipairs(D.safeZones or {}) do
    if dist(p, sz) < sz.r then return false end
  end
  return true
end

function D.spawnAmbush(force)
  local c = D.cfg.ambush
  local n = 0
  for _, st in ipairs(D.sites) do if st.ao.ambush then n = n + 1 end end
  if n >= c.maxActive then return false end
  D.refreshBlueBases()
  -- rote Flugplätze (ohne aktive AOs) als Anker: Hinterhalte liegen im Hinterland, nicht im Niemandsland
  local anchors = {}
  for _, ab in ipairs(world.getAirbases() or {}) do
    local okc, desc = pcall(function() return ab:getDesc() end)
    if okc and desc and desc.category == Airbase.Category.AIRDROME and ab:getCoalition() == D.cfg.redSide
       and not D.ignoredBase(ab) then
      anchors[#anchors + 1] = toV2(ab:getPoint())
    end
  end
  if #anchors == 0 then return false end
  local players = playerPositions()
  local avoid = {}
  for _, st in ipairs(D.sites) do avoid[#avoid + 1] = st.pos end
  for _ = 1, 60 do
    local a = anchors[math.random(#anchors)]
    local p = offset(a, math.random() * 2 * math.pi, randRange(c.baseRadius))
    p = D.nearRoad(p) or p
    if okGround(p) and D.ambushSpotOk(p) and farFrom(p, avoid, D.cfg.sam.minSeparation)
       and farFrom(p, players, D.cfg.minDistPlayers) and (force or D.samSpotClear(p)) then
      local key = weighted(c.pool)
      local ao = { name = "Ambush", x = p.x, y = p.y, radius = 8000, samLeft = 1, samActive = 0, ambush = true,
                   expires = timer.getTime() + randRange(c.lifetime) }
      D.createSam(ao, key, p, "ambush")
      env.info(string.format("DynSEAD: ambush %s at %s", key, D.fmtPos(p)))
      if force then msg(string.format("DEBUG: Ambush %s spawned at %s", D.samTypes[key].name, D.fmtPos(p))) end
      return true
    end
  end
  if force then msg("DEBUG: No valid ambush position found.") end
  return false
end

function D.ambushTick(now, players)
  local c = D.cfg.ambush
  if not c.enabled then return end
  for i = #D.sites, 1, -1 do
    local s = D.sites[i]
    if s.ao.ambush and now >= s.ao.expires and farFrom(s.pos, players, c.despawnRange) then
      destroyGroup(s.group)
      if s.pdGroup then destroyGroup(s.pdGroup) end
      table.remove(D.sites, i)
    end
  end
  if D.nextAmbush == 0 then D.nextAmbush = now + randRange(c.interval) end   -- erster Hinterhalt nicht sofort
  if now >= D.nextAmbush then
    D.nextAmbush = now + randRange(c.interval)
    D.spawnAmbush()
  end
end

-- Eine SAM-Stellung des Typs key an Position p in der AO ao erzeugen
function D.createSam(ao, key, p, forceMode)
  local def = D.samTypes[key]
  local gname = nextId("SAM-" .. key)
  local units, crit = buildSamUnits(def, p, gname)
  D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units })

  local now = timer.getTime()
  local site = {
    group = gname, key = key, def = def, pos = p, critical = crit, ao = ao,
    mode = forceMode or weighted((D.cfg.sam.modesByType or {})[key] or D.cfg.sam.modes), radarOn = true,
    ambushRange = ((D.cfg.sam.engageRange or {})[key] and D.cfg.sam.engageRange[key] * D.cfg.sam.ambushFactor)
                  or D.cfg.sam.ambushRange,
    nextToggle = now + randRange(D.cfg.sam.blinkOn),
  }
  ao.samLeft = ao.samLeft - 1
  ao.samActive = ao.samActive + 1

  local pd = D.cfg.sam.pointDefense
  if pd and pd.types[key] and not ao.ambush and math.random() < pd.chance then
    local pp = offset(p, math.random() * 2 * math.pi, pd.dist)
    site.pdGroup = gname .. "-PD"
    D.addGround(D.cfg.redCountry, {
      name = site.pdGroup, task = "Ground Nothing", hidden = D.hideOnMap(),
      units = { { name = site.pdGroup .. "-1", type = pd.unit, x = pp.x, y = pp.y,
                  heading = math.random() * 2 * math.pi, skill = D.cfg.skill, playerCanDrive = false } } })
    if D.cfg.sam.killAll then site.critical[#site.critical + 1] = site.pdGroup .. "-1" end
  end

  D.sites[#D.sites + 1] = site
  timer.scheduleFunction(safe(function()
    local evId = AI.Option.Ground.id.EVASION_OF_ARM
    if evId then
      for _, gn in ipairs({ site.group, site.pdGroup }) do
        local g = gn and Group.getByName(gn)
        if g and g:isExist() then g:getController():setOption(evId, D.cfg.sam.armEvasion.vanilla) end
      end
    end
    D.setRadar(site, site.mode ~= "ambush")
    -- Kontrolle: sind alle Einheiten der Stellung wirklich entstanden? (DCS verwirft Einheiten mit ungültigem Typnamen stillschweigend)
    local g = Group.getByName(site.group)
    local alive = g and g:isExist() and #(g:getUnits() or {}) or 0
    env.info(string.format("DynSEAD: %s %s – %d of %d units spawned", key, gname, alive, #units))
    if alive < #units then
      local have = {}
      for _, u in ipairs(g and g:isExist() and g:getUnits() or {}) do have[u:getTypeName()] = (have[u:getTypeName()] or 0) + 1 end
      local missing = {}
      for _, u in ipairs(units) do
        if (have[u.type] or 0) > 0 then have[u.type] = have[u.type] - 1 else missing[#missing + 1] = u.type end
      end
      reportError("SAM", string.format("%s: only %d of %d units spawned, missing: %s", key, alive, #units, table.concat(missing, ", ")))
    end
  end, "Radar"), nil, now + 3)

  env.info(string.format("DynSEAD: %s placed – siting checks so far: %d tested, rejected: %d scenery, %d urban, %d slope, %d horizon, %d NOSAM zones%s",
    key, D.siting.tested, D.siting.scenery, D.siting.urban, D.siting.slope, D.siting.horizon, D.siting.zone,
    D.siting.apiFailed and " (scenery search unavailable)" or ""))
  return true
end

local function groundRoute(from, to, speed)
  local function pt(p)
    return { x = p.x, y = p.y, type = "Turning Point", action = "Off Road", speed = speed,
      speed_locked = true, ETA = 0, ETA_locked = false,
      task = { id = "ComboTask", params = { tasks = {} } } }
  end
  return { id = "Mission", params = { route = { points = { pt(from), pt(to) } } } }
end

function D.startRelocation(s)
  local cfg = D.cfg.sam.relocate
  if not cfg.enabled then return false end
  local g = Group.getByName(s.group)
  if not g or not g:isExist() then return false end
  local cur = groupPos(s.group) or s.pos
  local center = { x = s.ao.x, y = s.ao.y }
  local dest
  for _ = 1, 40 do
    local q = offset(cur, math.random() * 2 * math.pi, randRange(cfg.distance))
    q = D.nearRoad(q, 1500) or q
    if okGround(q) and farFrom(q, D.blueBases, D.cfg.minDistBlueBase)
       and dist(q, center) <= s.ao.radius and D.samSpotClear(q) then
      dest = q
      break
    end
  end
  if not dest then return false end

  D.setRadar(s, false)
  g:getController():setTask(groundRoute(cur, dest, cfg.speed))
  if s.pdGroup then
    local pg = Group.getByName(s.pdGroup)
    local pcur = groupPos(s.pdGroup)
    if pg and pg:isExist() and pcur then
      pg:getController():setTask(groundRoute(pcur,
        offset(dest, math.random() * 2 * math.pi, D.cfg.sam.pointDefense.dist), cfg.speed))
    end
  end
  s.moving = { dest = dest, deadline = timer.getTime() + cfg.timeout }
  env.info("DynSEAD: " .. s.group .. " relocating")
  return true
end

function D.finishRelocation(s, p, now)
  s.pos = p
  s.moving = nil
  s.setupUntil = now + randRange(D.cfg.sam.relocate.setupTime)
end

function D.updateEmcon(s, now, players)
  if s.moving then
    if s.radarOn then D.setRadar(s, false) end
    local p = groupPos(s.group)
    if p and (dist(p, s.moving.dest) < 250 or now > s.moving.deadline) then
      D.finishRelocation(s, p, now)
    end
    return
  end
  if s.setupUntil then
    if now < s.setupUntil then
      if s.radarOn then D.setRadar(s, false) end
      return
    end
    s.setupUntil = nil
    s.nextToggle = now
  end
  if s.armDark then
    if s.radarOn then D.setRadar(s, false) end
    return
  end
  if s.darkUntil then
    if now < s.darkUntil then
      if s.radarOn then D.setRadar(s, false) end
      return
    end
    s.darkUntil = nil
    s.nextToggle = now
  end

  if s.mode == "always" then
    if not s.radarOn then D.setRadar(s, true) end
  elseif s.mode == "blink" then
    if now >= s.nextToggle then
      if s.radarOn then
        local ch = (D.cfg.sam.relocate.onBlinkChance or {})[s.key] or 0
        if ch > 0 and math.random() < ch and D.startRelocation(s) then return end
      end
      D.setRadar(s, not s.radarOn)
      s.nextToggle = now + randRange(s.radarOn and D.cfg.sam.blinkOn or D.cfg.sam.blinkOff)
    end
  elseif s.mode == "ambush" then
    if not farFrom(s.pos, players, s.ambushRange) then s.lastNear = now end
    local on = s.lastNear ~= nil and (now - s.lastNear) < D.cfg.sam.ambushHold
    if on ~= s.radarOn then D.setRadar(s, on) end
  end
end

-- ARM-Abwehr: jede anti-radiation missile wird im Flug verfolgt. Nur die angeflogene
-- Stellung reagiert, und erst kurz vor dem Einschlag (mit Wahrscheinlichkeit je Typ).
local function siteOfUnit(unitName)
  for _, s in ipairs(D.sites) do
    if unitName:sub(1, #s.group + 1) == s.group .. "-" then return s end
  end
  return nil
end

local function armTargetSite(w, p, v)
  local ok, tgt = pcall(function() return w:getTarget() end)
  if ok and tgt then
    local okn, n = pcall(function() return tgt:getName() end)
    if okn and n then
      local s = siteOfUnit(n)
      if s then return s end
    end
  end
  -- Fallback: horizontale Flugrichtung (robust gegen Loft-Flugbahn)
  local hv = math.sqrt(v.x * v.x + v.z * v.z)
  if hv < 1 then return nil end
  local best, bestAng = nil, math.rad(D.cfg.sam.armEvasion.maxAngle)
  for _, s in ipairs(D.sites) do
    local dx, dz = s.pos.x - p.x, s.pos.y - p.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d > 1 then
      local cosA = (dx * v.x + dz * v.z) / (d * hv)
      local ang = math.acos(math.max(-1, math.min(1, cosA)))
      if ang < bestAng then best, bestAng = s, ang end
    end
  end
  return best
end

function D.updateArms()
  local now = timer.getTime()
  local cfg = D.cfg.sam.armEvasion
  for i = #D.arms, 1, -1 do
    local a = D.arms[i]
    local w = a.weapon
    if not w:isExist() then
      -- Rakete eingeschlagen/vorbei -> Stellung kommt nach kurzer Pause wieder
      local s = a.site
      if s and s.armDark then
        s.armDark = s.armDark - 1
        if s.armDark <= 0 then
          s.armDark = nil
          local ch = (D.cfg.sam.relocate.chance or {})[s.key] or 0
          if not (ch > 0 and math.random() < ch and D.startRelocation(s)) then
            s.darkUntil = now + randRange(cfg.recover)
            s.announceBack = true
          end
        end
      end
      table.remove(D.arms, i)
    elseif not a.site then
      local p = w:getPoint()
      local v = w:getVelocity()
      local speed = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
      local s = (speed > 50) and armTargetSite(w, p, v) or nil
      if s and s ~= a.cand then a.cand, a.reactAt = s, nil end   -- Zielwechsel: neu bewerten
      if s then
        -- Entdeckung: nur wenn das Radar sendet, die ARM in Reichweite ist und Sichtlinie besteht
        if not a.reactAt and s.radarOn and (s.evasions or 0) < (cfg.maxEvasions or math.huge) then
          local rp = toV3(s.pos)
          rp.y = rp.y + 15
          local dx, dy, dz = rp.x - p.x, rp.y - p.y, rp.z - p.z
          local d3 = math.sqrt(dx * dx + dy * dy + dz * dz)
          if d3 <= ((cfg.detectRange or {})[s.key] or cfg.defaultRange) and land.isVisible(rp, p) then
            local agl = p.y - land.getHeight({ x = p.x, y = p.z })
            local altF = math.max(cfg.altFactor[1], math.min(cfg.altFactor[2], agl / cfg.altRef))
            local rate = ((cfg.detectRate or {})[s.key] or cfg.defaultRate) * altF
            if a.alert[s] then rate = rate * cfg.alertMultiplier end
            if math.random() < rate then a.reactAt = now + randRange(cfg.reactionDelay) end
          end
        end
        -- Reaktion der Crew (kommt evtl. zu spät, wenn die ARM vorher einschlägt)
        if a.reactAt and now >= a.reactAt then
          a.site = s
          if not s.armDark then s.evasions = (s.evasions or 0) + 1 end
          s.armDark = (s.armDark or 0) + 1
          D.setRadar(s, false)
        end
      end
    end
  end
end

function D.armTick(_, t)
  local ok, err = pcall(D.updateArms)
  if not ok then reportError("ARM", err) end
  if #D.arms == 0 then
    D.armLoopRunning = false
    return nil
  end
  return t + 1
end

local function onShot(e)
  local w = e.weapon
  if not w or not e.initiator then return end
  if not D.cfg.sam.armEvasion.enabled then return end
  if e.initiator:getCoalition() ~= D.cfg.blueSide then return end
  local desc = w:getDesc()
  if not desc or desc.guidance ~= Weapon.GuidanceType.RADAR_PASSIVE then return end

  local cfg = D.cfg.sam.armEvasion
  local a = { weapon = w, alert = {} }
  local shooter = e.initiator:getPoint()
  for _, s in ipairs(D.sites) do
    if s.radarOn then
      local rp = toV3(s.pos)
      rp.y = rp.y + 15
      -- ein Flugzeug sieht das Radar deutlich weiter als eine kleine ARM
      local range = ((cfg.detectRange or {})[s.key] or cfg.defaultRange) * 2
      if dist(toV2(shooter), s.pos) <= range and land.isVisible(rp, shooter)
         and math.random() < cfg.launchAlert then
        a.alert[s] = true
      end
    end
  end
  D.arms[#D.arms + 1] = a
  if not D.armLoopRunning then
    D.armLoopRunning = true
    timer.scheduleFunction(D.armTick, nil, timer.getTime() + 1)
  end
end

-------------------------------------------------------------------------------
-- AWACS + ELINT
-------------------------------------------------------------------------------
function D.awacsUnit()
  local g = Group.getByName(D.cfg.awacs.groupName)
  if not g or not g:isExist() then return nil end
  local u = g:getUnit(1)
  if u and u:isExist() and u:getLife() >= 1 then return u end
  return nil
end

-- Orbit hinter der blauen Basis, die der ersten aktiven AO am nächsten ist
function D.awacsOrbit()
  D.refreshBlueBases()
  local ao = D.aos[1]
  if not ao or #D.blueBases == 0 then return nil end
  local aoP = { x = ao.x, y = ao.y }
  local best, bd = nil, math.huge
  for _, b in ipairs(D.blueBases) do
    local d = dist(b, aoP)
    if d < bd then best, bd = b, d end
  end
  local away = math.atan2(best.y - aoP.y, best.x - aoP.x)
  local c = offset(best, away, D.cfg.awacs.standoff)
  local half = D.cfg.awacs.legLength / 2
  return offset(c, away + math.pi / 2, -half), offset(c, away + math.pi / 2, half)
end

local function awacsTasks(p1, p2)
  local cfg = D.cfg.awacs
  return {
    { number = 1, enabled = true, auto = false, id = "AWACS", params = {} },
    { number = 2, enabled = true, auto = false, id = "Orbit",
      params = { pattern = "Race-Track", point = { x = p1.x, y = p1.y }, point2 = { x = p2.x, y = p2.y },
                 speed = cfg.speed, altitude = cfg.alt } },
  }
end

function D.spawnAwacs()
  local cfg = D.cfg.awacs
  local p1, p2 = D.awacsOrbit()
  if not p1 then return false end
  local hdg = math.atan2(p2.y - p1.y, p2.x - p1.x)

  coalition.addGroup(D.cfg.blueCountry, Group.Category.AIRPLANE, {
    name = cfg.groupName, task = "AWACS", uncontrolled = false,
    communication = true, frequency = cfg.frequency, modulation = 0,
    units = { {
      name = cfg.groupName .. "-1", type = cfg.type,
      x = p1.x, y = p1.y, alt = cfg.alt, alt_type = "BARO", speed = cfg.speed, heading = hdg,
      skill = "Excellent",
      callsign = { [1] = cfg.callsignIndex, [2] = 1, [3] = 1, name = cfg.callsignName .. "11" },
      payload = { pylons = {}, fuel = 65000, flare = 0, chaff = 0, gun = 0 },
    } },
    route = { points = { airWP(p1, cfg.alt, cfg.speed, awacsTasks(p1, p2)), airWP(p2, cfg.alt, cfg.speed, {}) } },
  })

  if cfg.immortal then
    timer.scheduleFunction(safe(function()
      local g = Group.getByName(cfg.groupName)
      if g and g:isExist() then
        local c = g:getController()
        c:setCommand({ id = "SetImmortal", params = { value = true } })
        c:setCommand({ id = "SetInvisible", params = { value = true } })
      end
    end, "AWACS"), nil, timer.getTime() + 2)
  end

  D.awacsSpawned = true
  msg(string.format("%s is on station. %.3f AM.", cfg.callsignName, cfg.frequency))
  return true
end

function D.repositionAwacs()
  if not D.cfg.awacs.enabled then return end
  local u = D.awacsUnit()
  if not u then return end
  local p1, p2 = D.awacsOrbit()
  if not p1 then return end
  local cfg = D.cfg.awacs
  local cur = toV2(u:getPoint())
  u:getGroup():getController():setTask({ id = "Mission", params = { route = { points = {
    airWP(cur, cfg.alt, cfg.speed, {}),
    airWP(p1, cfg.alt, cfg.speed, awacsTasks(p1, p2)),
    airWP(p2, cfg.alt, cfg.speed, {}),
  } } } })
  msg(cfg.callsignName .. " is repositioning to support the new AO.")
end

function D.checkAwacs(now)
  local cfg = D.cfg.awacs
  if not cfg.enabled then return end
  if D.awacsUnit() then return end
  if not D.awacsRespawnAt then
    if D.awacsSpawned then
      msg(string.format("%s is down! Replacement expected in %d min.", cfg.callsignName, math.floor(cfg.respawnDelay / 60)))
      D.awacsRespawnAt = now + cfg.respawnDelay
    else
      D.awacsRespawnAt = now
    end
  end
  if now >= D.awacsRespawnAt then
    D.awacsRespawnAt = nil
    if not D.spawnAwacs() then D.awacsRespawnAt = now + 60 end
  end
end

-- Tanker-Orbit: auf der Linie AO -> nächste blaue Basis, außerhalb der SAM-Reichweite
-- Liegt die Tankerstrecke außerhalb aller SAM-Reichweiten (plus Sicherheitsabstand)?
-- Gezählt werden gebaute Stellungen und AOs, deren SAMs noch nicht stehen (dort irgendwo im AO-Kreis).
local function tankerThreats()
  local cfg, list = D.cfg.tankers, {}
  for _, st in ipairs(D.sites) do
    local r = ((D.cfg.sam.engageRange or {})[st.key] or D.cfg.sam.ambushRange) + cfg.samMargin
    list[#list + 1] = { p = st.pos, r = r }
  end
  local maxR = 0
  for _, r in pairs(D.cfg.sam.engageRange or {}) do if r < 100000 then maxR = math.max(maxR, r) end end
  for _, ao in ipairs(D.aos) do
    if ao.samLeft and ao.samLeft > 0 and ao.samLeft ~= math.huge then
      list[#list + 1] = { p = { x = ao.x, y = ao.y }, r = ao.radius + maxR + cfg.samMargin }
    end
  end
  return list
end

local function trackClear(p1, p2, threats)
  for k = 0, 4 do
    local q = { x = p1.x + (p2.x - p1.x) * k / 4, y = p1.y + (p2.y - p1.y) * k / 4 }
    for _, th in ipairs(threats) do
      if dist(q, th.p) < th.r then return false, th end
    end
  end
  return true
end

local function frontByName2(n)
  for _, f in ipairs(D.fronts or {}) do if f.name == n then return f end end
end

function D.tankerOrbit(t)
  local cfg = D.cfg.tankers
  local threats = tankerThreats()
  local half = cfg.legLength / 2
  local front = t.front and frontByName2(t.front)
  local frontAOs = {}
  for _, ao in ipairs(D.aos) do if front and ao.front == front then frontAOs[#frontAOs + 1] = ao end end

  -- 1) feste Strecke (ohne Front, oder Front noch ohne Ziel): bleibt, weicht aber SAM-Reichweiten aus
  if t.track and #frontAOs == 0 then
    local a = coord.LLtoLO(t.track[1], t.track[2], 0)
    local b = coord.LLtoLO(t.track[3], t.track[4], 0)
    local p1, p2 = { x = a.x, y = a.z }, { x = b.x, y = b.z }
    for _ = 1, 30 do
      local ok, th = trackClear(p1, p2, threats)
      if ok then break end
      local c = { x = (p1.x + p2.x) / 2, y = (p1.y + p2.y) / 2 }
      local away = math.atan2(c.y - th.p.y, c.x - th.p.x)
      p1, p2 = offset(p1, away, 10000), offset(p2, away, 10000)
    end
    return p1, p2, { x = (p1.x + p2.x) / 2, y = (p1.y + p2.y) / 2 }
  end

  -- 2) mitlaufend: hinter den Zielen der eigenen Front (bzw. hinter der ersten AO), Richtung eigene Basen
  D.refreshBlueBases()
  local A, bases
  if #frontAOs > 0 then
    -- die Front-AO, die den eigenen Basen am nächsten ist (dort tankt man auf dem Weg ins Ziel)
    bases = front.pos
    local best = math.huge
    for _, ao in ipairs(frontAOs) do
      for _, fb in ipairs(bases) do
        local d = dist(ao, fb)
        if d < best then best, A = d, { x = ao.x, y = ao.y } end
      end
    end
  else
    local ao = D.aos[1]
    if not ao or #D.blueBases == 0 then return nil end
    A, bases = { x = ao.x, y = ao.y }, D.blueBases
  end
  local B, bd = nil, math.huge
  for _, b in ipairs(bases) do local d = dist(A, b); if d < bd then B, bd = b, d end end
  if not B then return nil end
  local dir = math.atan2(B.y - A.y, B.x - A.x)
  local along = cfg.minAOClearance + (t.offsetBack or 0)   -- so nah wie möglich, aber außerhalb aller SAM-Reichweiten
  local c, p1, p2
  for _ = 1, 40 do
    c = offset(A, dir, along)
    p1, p2 = offset(c, dir + math.pi / 2, -half), offset(c, dir + math.pi / 2, half)
    local clear = trackClear(p1, p2, threats)
    if clear then
      for _, a in ipairs(D.aos) do
        if dist(c, { x = a.x, y = a.y }) < cfg.minAOClearance then clear = false break end
      end
    end
    if clear then break end
    along = along + 10000
  end
  return p1, p2, c
end

local function tankerTasks(t, p1, p2)
  return {
    { number = 1, enabled = true, auto = false, id = "Tanker", params = {} },
    { number = 2, enabled = true, auto = false, id = "Orbit",
      params = { pattern = "Race-Track", point = { x = p1.x, y = p1.y }, point2 = { x = p2.x, y = p2.y },
                 speed = t.speed, altitude = t.alt } },
  }
end

local function tankerLabel(t)
  return string.format("%s (%s, %s) %.3f AM, TACAN %dY",
    t.name, t.type, t.kind == "boom" and "boom" or "drogue", t.frequency, t.tacan)
end

function D.spawnTanker(t)
  local cfg = D.cfg.tankers
  local p1, p2, c = D.tankerOrbit(t)
  if not p1 then return false end
  local hdg = math.atan2(p2.y - p1.y, p2.x - p1.x)

  coalition.addGroup(D.cfg.blueCountry, Group.Category.AIRPLANE, {
    name = t.name, task = "Refueling", uncontrolled = false,
    communication = true, frequency = t.frequency, modulation = 0,
    units = { {
      name = t.name .. "-1", type = t.type,
      x = p1.x, y = p1.y, alt = t.alt, alt_type = "BARO", speed = t.speed, heading = hdg,
      skill = "Excellent",
      callsign = { [1] = t.callsignIndex, [2] = t.flight or 1, [3] = 1, name = (t.callsign or t.name) .. (t.flight or 1) .. "1" },
      payload = { pylons = {}, fuel = 90700, flare = 0, chaff = 0, gun = 0 },
    } },
    route = { points = { airWP(p1, t.alt, t.speed, tankerTasks(t, p1, p2)), airWP(p2, t.alt, t.speed, {}) } },
  })

  timer.scheduleFunction(safe(function()
    local g = Group.getByName(t.name)
    if not g or not g:isExist() then return end
    local ctrl = g:getController()
    local u = g:getUnit(1)
    if u and t.tacan then
      ctrl:setCommand({ id = "ActivateBeacon", params = {
        type = 4, system = 5, callsign = t.tacanId, frequency = tacanFreq(t.tacan, "Y"),
        channel = t.tacan, modeChannel = "Y", bearing = true, AA = true, unitId = u:getID() } })
    end
    if cfg.immortal then
      ctrl:setCommand({ id = "SetImmortal", params = { value = true } })
      ctrl:setCommand({ id = "SetInvisible", params = { value = true } })
    end
  end, "Tanker"), nil, timer.getTime() + 3)

  t.spawned = true
  t.center = c
  msg(string.format("%s on station, FL%03d.\nTrack center: %s",
    tankerLabel(t), math.floor(t.alt * 3.28084 / 100 + 0.5), bullseyeStr(c)))
  return true
end

function D.repositionTankers(quiet)
  local cfg = D.cfg.tankers
  if not cfg.enabled then return end
  for _, t in ipairs(cfg.list) do
    local u = supportUnit(t.name)
    if u then
      local p1, p2, c = D.tankerOrbit(t)
      if p1 and (not t.center or dist(c, t.center) > 10000) then
        t.center = c
        u:getGroup():getController():setTask({ id = "Mission", params = { route = { points = {
          airWP(toV2(u:getPoint()), t.alt, t.speed, {}),
          airWP(p1, t.alt, t.speed, tankerTasks(t, p1, p2)),
          airWP(p2, t.alt, t.speed, {}),
        } } } })
        msg(string.format("%s repositioning. New track center: %s", t.name, bullseyeStr(c)))
      end
    end
  end
end

function D.checkTankers(now)
  local cfg = D.cfg.tankers
  if not cfg.enabled then return end
  for _, t in ipairs(cfg.list) do
    local u = supportUnit(t.name)
    if not (u and u:inAir()) then
      if not t.respawnAt then
        if t.spawned then
          msg(string.format("%s is off station. Replacement expected in %d min.", t.name, math.floor(cfg.respawnDelay / 60)))
          t.respawnAt = now + cfg.respawnDelay
        else
          t.respawnAt = now
        end
      end
      if now >= t.respawnAt then
        t.respawnAt = nil
        destroyGroup(t.name)
        if not D.spawnTanker(t) then t.respawnAt = now + 60 end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- MANPADS (angekündigte Gefahrenzonen)
-------------------------------------------------------------------------------
function D.spawnManpadsZones(ao)
  local cfg = D.cfg.manpads
  if not cfg.enabled then return end
  ao.manpads = ao.manpads or {}
  local n = math.random(cfg.zonesPerAO[1], cfg.zonesPerAO[2])
  for i = 1, n do
    local c
    if i == 1 and ao.airbase and math.random() < cfg.airfieldChance then
      c = { x = ao.x, y = ao.y }
    else
      for _ = 1, 50 do
        local p = randomPointInZone(ao, cfg.radius)
        if land.getSurfaceType(p) == land.SurfaceType.LAND then c = p break end
      end
    end

    if c then
      local gname = nextId("MANPADS")
      local units = {}
      for _ = 1, math.random(cfg.teams[1], cfg.teams[2]) do
        local pos
        for _ = 1, 30 do
          local q = jitter(c, cfg.radius * 0.8)
          if land.getSurfaceType(q) == land.SurfaceType.LAND then pos = q break end
        end
        if pos then
          local hdg = math.random() * 2 * math.pi
          units[#units + 1] = { name = gname .. "-" .. (#units + 1), type = cfg.type, x = pos.x, y = pos.y,
            heading = hdg, skill = D.cfg.skill, playerCanDrive = false }
          units[#units + 1] = { name = gname .. "-" .. (#units + 1), type = "UAZ-469", x = pos.x + 6, y = pos.y + 4,
            heading = hdg, skill = D.cfg.skill, playerCanDrive = false }
        end
      end

      if #units > 0 then
        D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units })
        ao.manpads[#ao.manpads + 1] = { group = gname, center = c }
      end
    end
  end
end

-- Alle Kartenzeichnungen neu anlegen (DCS überträgt Skript-Zeichnungen nicht
-- zuverlässig an Spieler, die später joinen oder den Slot wechseln)
function D.redrawAll()
  for _, ao in ipairs(D.aos) do
    if ao.drawId then trigger.action.removeMark(ao.drawId) end
    drawAO(ao)
    if ao.wptMark then
      trigger.action.removeMark(ao.wptMark)
      D.addAOWaypoint(ao)
    end
  end
end

function D.scheduleRedraw()
  local now = timer.getTime()
  if D.redrawAt and D.redrawAt > now then return end   -- schon geplant
  D.redrawAt = now + 3
  timer.scheduleFunction(safe(function() D.redrawAt = nil; D.redrawAll() end, "Redraw"), nil, now + 3)
end

function D.clearManpads(ao)
  for _, m in ipairs(ao.manpads or {}) do
    destroyGroup(m.group)
  end
  ao.manpads = {}
end

-- Lagebild einer AO: nur SAM-Typen und MANPADS ja/nein, keine Positionen
function D.aoThreats(ao)
  local counts, order = {}, {}
  for _, st in ipairs(D.sites) do
    if st.ao == ao then
      local n = st.def.name
      if not counts[n] then counts[n] = 0; order[#order + 1] = n end
      counts[n] = counts[n] + 1
    end
  end
  local parts = {}
  for _, n in ipairs(order) do parts[#parts + 1] = string.format("%dx %s", counts[n], n) end
  local manpads = false
  for _, m in ipairs(ao.manpads or {}) do
    if groupAliveCount(m.group) > 0 then manpads = true break end
  end
  return string.format("[%s] SAM: %s\n   MANPADS: %s", ao.name,
    #parts > 0 and table.concat(parts, ", ") or "none", manpads
      and string.format("expect MANPADS – stay above %d ft AGL", D.cfg.manpads.safeAltFt) or "none reported")
end

function D.reportThreats()
  if #D.aos == 0 then msg("THREATS: No active AOs.") return end
  local lines = { "THREAT ASSESSMENT (locations unknown):" }
  for _, ao in ipairs(D.aos) do lines[#lines + 1] = D.aoThreats(ao) end
  lines[#lines + 1] = string.format("SAM sites neutralized so far: %d", D.stats.sam)
  msg(table.concat(lines, "\n"))
end

function D.reportSupport()
  local lines = { "SUPPORT ASSETS:" }
  if D.cfg.awacs.enabled then
    lines[#lines + 1] = string.format("%s (AWACS) %.3f AM – %s", D.cfg.awacs.callsignName, D.cfg.awacs.frequency,
      D.awacsUnit() and "on station" or "not available")
  end
  if D.cfg.tankers.enabled then
    for _, t in ipairs(D.cfg.tankers.list) do
      local u = supportUnit(t.name)
      local where = u and ("on station, " .. bullseyeStr(toV2(u:getPoint()))) or "not available"
      lines[#lines + 1] = string.format("%s, FL%03d – %s", tankerLabel(t),
        math.floor(t.alt * 3.28084 / 100 + 0.5), where)
    end
  end
  msg(table.concat(lines, "\n"))
end

-------------------------------------------------------------------------------
-- NAVIGATION (AO-Mittelpunkte als Wegpunkte)
-------------------------------------------------------------------------------
local function steerLines(p)
  local lat, lon = coord.LOtoLL(toV3(p))
  local elev = math.floor(land.getHeight(p) * 3.28084 + 0.5)
  return string.format("   LAT %s   LON %s   ELEV %d ft",
    ddm(lat, "N ", "S ", 2), ddm(lon, "E ", "W ", 3), elev)
end

function D.addAOWaypoint(ao)
  if not D.cfg.drawAO or not D.cfg.aoWaypointMarks then return end
  local p = { x = ao.x, y = ao.y }
  ao.wptMark = newMarkId()
  trigger.action.markToCoalition(ao.wptMark,
    string.format("WPT – AO %s (center)\n%s", ao.name, D.fmtPos(p)),
    toV3(p), D.cfg.blueSide, true)
end

function D.reportNav()
  if #D.aos == 0 then msg("NAVIGATION: No active AOs.") return end
  D.refreshBlueBases()
  local lines = { "NAVIGATION – AO CENTER STEERPOINTS:" }
  for i, ao in ipairs(D.aos) do
    local p = { x = ao.x, y = ao.y }
    local lat, lon = coord.LOtoLL(toV3(p))
    local m = coord.LLtoMGRS(lat, lon)
    lines[#lines + 1] = string.format("%d) AO %s", i, ao.name)
    lines[#lines + 1] = steerLines(p)
    lines[#lines + 1] = string.format("   MGRS %s %s %05d %05d | %s", m.UTMZone, m.MGRSDigraph,
      math.floor(m.Easting), math.floor(m.Northing), bullseyeStr(p))
    local b = nearestBlueBase(p)
    if b then
      local brg = (math.deg(math.atan2(p.y - b.y, p.x - b.x)) + 360) % 360
      lines[#lines + 1] = string.format("   From %s: %03d°T / %d NM", b.name or "home",
        math.floor(brg + 0.5) % 360, math.floor(dist(p, b) / 1852 + 0.5))
    end
  end
  msg(table.concat(lines, "\n"))
end

-------------------------------------------------------------------------------
-- CAS
-------------------------------------------------------------------------------
local function emptyTask() return { id = "ComboTask", params = { tasks = {} } } end

function D.spawnCAS(manual)
  if #D.casTasks >= D.cfg.cas.maxActive then
    if manual then msg("CAS: Maximum number of active taskings reached.") end
    return false
  end
  local aos = aoCandidates("casLeft")
  if #aos == 0 then
    if manual then msg("CAS: No further CAS targets in the active AOs.") end
    return false
  end
  local p, ao = D.findSpot(aos, nil, 0)
  if not p then
    if manual then msg("CAS: No suitable area found – try again later.") end
    return false
  end

  local tpl = D.casTemplates[math.random(#D.casTemplates)]
  local list = {}
  for _, t in ipairs(tpl.units) do list[#list + 1] = t end
  local hasManpads = math.random() < D.cfg.cas.manpadsChance
  if hasManpads then list[#list + 1] = "SA-18 Igla manpad" list[#list + 1] = "__JEEP" end   -- Jeep parkt neben dem MANPADS-Trupp

  local hdg = math.random() * 2 * math.pi
  local route, isConvoy = nil, false
  if tpl.convoy then
    local sx, sy = land.getClosestPointOnRoads("roads", p.x, p.y)
    local dest = offset(p, math.random() * 2 * math.pi, randRange({8000, 20000}))
    local ex, ey = land.getClosestPointOnRoads("roads", dest.x, dest.y)
    if sx and ex then
      p = { x = sx, y = sy }
      hdg = math.atan2(ey - sy, ex - sx)
      isConvoy = true
      route = { points = {
        { x = sx, y = sy, type = "Turning Point", action = "On Road", speed = 11,
          speed_locked = true, ETA = 0, ETA_locked = false, task = emptyTask() },
        { x = ex, y = ey, type = "Turning Point", action = "On Road", speed = 11,
          speed_locked = true, ETA = 0, ETA_locked = false, task = emptyTask() },
      } }
    end
  end

  local gname = nextId("CAS")
  local units = {}
  for i, t in ipairs(list) do
    local u
    if t == "__JEEP" and units[#units] then      -- Jeep direkt neben dem vorherigen Fahrzeug/Trupp
      u = { x = units[#units].x + 6, y = units[#units].y + 4 }
      t = "UAZ-469"
    elseif isConvoy then
      u = offset(p, hdg, -30 * (i - 1))
    else
      u = offset(p, math.random() * 2 * math.pi, 40 + math.random() * 160)
    end
    units[#units + 1] = { name = gname .. "-" .. i, type = t, x = u.x, y = u.y,
      heading = hdg, skill = D.cfg.skill, playerCanDrive = false }
  end

  D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units, route = route })

  D.casTasks[#D.casTasks + 1] = { group = gname, name = tpl.name, initial = #units, convoy = isConvoy, ao = ao,
    manpads = hasManpads }
  ao.casLeft = ao.casLeft - 1
  ao.casActive = ao.casActive + 1

  D.say({ "new_cas", tBE(p), hasManpads and "manpads_reported" or nil })
  msg(string.format("CAS TASKING [%s]: %s%s\nApprox. position: %s%s",
    ao.name, tpl.name, isConvoy and " (moving)" or "", D.fmtPos(jitter(p, D.cfg.cas.intelError)),
    hasManpads and "\nWARNING: MANPADS reported with this group." or ""))
  return true
end

function D.requestCAS() D.spawnCAS(true) end

function D.reportCAS()
  if #D.casTasks == 0 then msg("CAS: No active taskings.") return end
  local lines = { "CAS TASKINGS:" }
  for i, t in ipairs(D.casTasks) do
    local p = groupPos(t.group)
    if p then
      lines[#lines + 1] = string.format("%d) [%s] %s%s%s – %d/%d units remaining\n   %s",
        i, t.ao.name, t.name, t.convoy and " (convoy)" or "", t.manpads and " [MANPADS]" or "",
        groupAliveCount(t.group), t.initial,
        D.fmtPos(jitter(p, D.cfg.cas.intelError)))
    end
  end
  msg(table.concat(lines, "\n"))
end

function D.smokeCAS()
  if #D.casTasks == 0 then msg("CAS: No active taskings.") return end
  for _, t in ipairs(D.casTasks) do
    local p = groupPos(t.group)
    if p then trigger.action.smoke(toV3(jitter(p, 80)), trigger.smokeColor.Red) end
  end
  msg("JTAC: Targets marked with red smoke.")
end

-------------------------------------------------------------------------------
-- CAP
-------------------------------------------------------------------------------
function D.currentCapTier()
  local c = D.cfg.cap
  local t = c.difficulty
  if c.progressive then t = t + math.floor(D.capturedCount / c.progressStep) end
  return math.max(1, math.min(#c.tiers, t))
end

-- nächster Spieler in der Luft (Flugzeug/Hubschrauber) zu Punkt p
local function nearestAirPlayer(p)
  local best, bestD
  for _, u in ipairs(coalition.getPlayers(D.cfg.blueSide) or {}) do
    if u and u:isExist() and u:inAir() then
      local q = toV2(u:getPoint())
      local d = dist(p, q)
      if not bestD or d < bestD then best, bestD = q, d end
    end
  end
  return best
end

-- Jagd-CAP: Route direkt zum nächsten Spieler in der Luft, Luftziele ohne Entfernungsgrenze bekämpfen
function D.capHuntRoute(c)
  local g = Group.getByName(c.group)
  if not g or not g:isExist() then return end
  local u = g:getUnit(1)
  if not u or not u:isExist() then return end
  local p = toV2(u:getPoint())
  local tgt = nearestAirPlayer(p)
  local cfg = D.cfg.cap
  local tasks = { { number = 1, enabled = true, auto = false, id = "EngageTargets",
                    params = { targetTypes = { "Air" }, priority = 0 } } }
  local pts
  if tgt then
    pts = { airWP(p, cfg.alt, cfg.speed, tasks), airWP(tgt, cfg.alt, cfg.speed * 1.2, {}) }
  else
    tasks[2] = { number = 2, enabled = true, auto = false, id = "Orbit",
                 params = { pattern = "Circle", point = p, speed = cfg.speed, altitude = cfg.alt } }
    pts = { airWP(p, cfg.alt, cfg.speed, tasks) }
  end
  g:getController():setTask({ id = "Mission", params = { route = { points = pts } } })
end

-- mode: "patrol" (Racetrack in einer AO, bekämpft Luftziele bis 80 km) oder "hunt" (sucht den nächsten Spieler)
function D.spawnCAP(tier, mode)
  local cfg = D.cfg.cap
  if not cfg.enabled then return end
  mode = mode or "patrol"
  if #D.caps >= cfg.maxActive then
    msg(string.format("%s: Already %d enemy CAP groups airborne (maximum).", D.cfg.awacs.callsignName, #D.caps))
    return
  end
  local aos = aoCandidates(nil)
  if #aos == 0 then return end

  tier = tier or D.currentCapTier()
  local td = cfg.tiers[tier]
  local v = td.variants[math.random(#td.variants)]

  local players = playerPositions()
  local best, bestZone, bestD = nil, nil, -1
  for _ = 1, 25 do
    local z = pickZone(aos)
    local p = randomPointInZone(z, 0)
    local d = math.huge
    for _, q in ipairs(players) do d = math.min(d, dist(p, q)) end
    if d > bestD then best, bestZone, bestD = p, z, d end
  end

  local center = { x = bestZone.x, y = bestZone.y }
  local hdg = (dist(best, center) > 1000)
    and math.atan2(center.y - best.y, center.x - best.x)
    or math.random() * 2 * math.pi
  local p2 = offset(best, hdg, 40000)

  local gname = nextId("CAP")
  local lo = D.capLoadouts[v.loadout]
  local units = {}
  for i = 1, cfg.size do
    units[i] = {
      name = gname .. "-" .. i, type = v.type,
      x = best.x - 300 * (i - 1), y = best.y + 300 * (i - 1),
      alt = cfg.alt, alt_type = "BARO", speed = cfg.speed, heading = hdg,
      skill = td.skill or D.cfg.skill,
      payload = lo and { pylons = lo.pylons, fuel = lo.fuel, flare = lo.flare,
                         chaff = lo.chaff, gun = lo.gun } or nil,
    }
  end

  local tasks = {
    { number = 1, enabled = true, auto = false, id = "EngageTargets",
      params = { targetTypes = { "Air" }, priority = 0, maxDistEnabled = true, maxDist = 80000 } },
    { number = 2, enabled = true, auto = false, id = "Orbit",
      params = { pattern = "Race-Track", point = { x = best.x, y = best.y }, point2 = p2,
                 speed = cfg.speed, altitude = cfg.alt } },
  }

  coalition.addGroup(D.cfg.redCountry, Group.Category.AIRPLANE, {
    name = gname, task = "CAP", uncontrolled = false, units = units,
    route = { points = { airWP(best, cfg.alt, cfg.speed, tasks), airWP(p2, cfg.alt, cfg.speed, {}) } },
  })

  -- Prüfen, ob Raketen geladen wurden (falsche Pylon-IDs -> unbewaffnet)
  timer.scheduleFunction(safe(function()
    local g = Group.getByName(gname)
    if not g or not g:isExist() then return end
    local u = g:getUnit(1)
    local missiles = 0
    for _, a in ipairs((u and u:getAmmo()) or {}) do
      if a.desc and a.desc.category == Weapon.Category.MISSILE then missiles = missiles + (a.count or 0) end
    end
    env.info(string.format("DynSEAD: CAP %s (%s, %s) spawned with %d missiles", gname, v.type, v.loadout, missiles))
    if missiles == 0 then
      reportError("CAP", string.format("%s spawned WITHOUT missiles – check D.capLoadouts['%s']", v.type, v.loadout))
    end
  end, "CAP check"), nil, timer.getTime() + 5)

  local c = { group = gname, hunt = (mode == "hunt"), nextHunt = timer.getTime() + 2 }
  D.caps[#D.caps + 1] = c
  D.say({ "new_picture", tBE(best), tNum(cfg.size), "contacts", tAircraft(v.type),
          "angels", tNum(math.floor(cfg.alt * 3.28084 / 1000 + 0.5)), "hostile" })
  msg(string.format("%s [%s]: New hostile group – %dx %s, %s, angels %d, approx. %s – %s (%d/%d airborne)",
    D.cfg.awacs.callsignName, bestZone.name, cfg.size, v.type, td.label,
    math.floor(cfg.alt * 3.28084 / 1000 + 0.5), bullseyeStr(best),
    c.hunt and "hunting the nearest aircraft" or "patrolling the AO", #D.caps, cfg.maxActive))
end

function D.removeCAPs()
  local n = #D.caps + #D.capPersist
  if n == 0 then msg(D.cfg.awacs.callsignName .. ": No enemy CAP airborne.") return end
  for _, c in ipairs(D.caps) do destroyGroup(c.group) end
  for _, c in ipairs(D.capPersist) do destroyGroup(c.group) end
  D.caps, D.capPersist = {}, {}
  msg(string.format("%s: %d enemy CAP group(s) removed.%s", D.cfg.awacs.callsignName, n,
    D.capPersistOn and " Respawning CAP is still ON." or ""))
end

-- Dauer-CAP: Startplatz = feindlicher Flugplatz (weit genug von blauen Basen), der einer aktiven AO am nächsten ist
function D.spawnPersistentCAP()
  local cfg, pc = D.cfg.cap, D.cfg.cap.persistent
  D.refreshBlueBases()
  local aos = aoCandidates(nil)
  local function nearestAO(p)
    local b, bd
    for _, ao in ipairs(aos) do
      local d = dist(p, { x = ao.x, y = ao.y })
      if not bd or d < bd then b, bd = ao, d end
    end
    return b, bd
  end
  local base, baseD
  for _, ab in ipairs(world.getAirbases() or {}) do
    local okc, desc = pcall(function() return ab:getDesc() end)
    if okc and desc and desc.category == Airbase.Category.AIRDROME and ab:getCoalition() == D.cfg.redSide
       and not D.ignoredBase(ab) then
      local p = toV2(ab:getPoint())
      if farFrom(p, D.blueBases, pc.minBlueDist) then
        local _, d = nearestAO(p)
        if not d then local b = nearestBlueBase(p); d = b and dist(p, b) or 0 end
        if not baseD or d < baseD then base, baseD = { ab = ab, p = p }, d end
      end
    end
  end
  if not base and #aos == 0 then return false end

  -- Patrouillengebiet: nächste aktive AO, sonst Richtung nächste blaue Basis
  local from = base and base.p or { x = aos[1].x, y = aos[1].y }
  local ao = nearestAO(from)
  local center
  if ao then
    center = { x = ao.x, y = ao.y }
  else
    local b = nearestBlueBase(from)
    center = b and { x = from.x + 0.4 * (b.x - from.x), y = from.y + 0.4 * (b.y - from.y) } or from
  end
  local hdg = math.atan2(center.y - from.y, center.x - from.x)
  local p1 = offset(center, hdg + math.pi / 2, pc.patrolLength / 2)
  local p2 = offset(center, hdg - math.pi / 2, pc.patrolLength / 2)

  local td = cfg.tiers[D.currentCapTier()]
  local v = td.variants[math.random(#td.variants)]
  local lo = D.capLoadouts[v.loadout]
  local tasks = {
    { number = 1, enabled = true, auto = false, id = "EngageTargets",
      params = { targetTypes = { "Air" }, priority = 0, maxDistEnabled = true, maxDist = 80000 } },
    { number = 2, enabled = true, auto = false, id = "Orbit",
      params = { pattern = "Race-Track", point = p1, point2 = p2, speed = cfg.speed, altitude = cfg.alt } },
  }
  local function build(ground)
    local gname = nextId("RCAP")
    local start = ground and base.p or offset(center, hdg + math.pi, 30000)
    local units = {}
    for i = 1, cfg.size do
      units[i] = {
        name = gname .. "-" .. i, type = v.type,
        x = start.x - 30 * (i - 1), y = start.y + 30 * (i - 1),
        alt = ground and land.getHeight(start) or cfg.alt, alt_type = "BARO",
        speed = ground and 0 or cfg.speed, heading = hdg, skill = td.skill or D.cfg.skill,
        payload = lo and { pylons = lo.pylons, fuel = lo.fuel, flare = lo.flare, chaff = lo.chaff, gun = lo.gun } or nil,
      }
    end
    local first
    if ground then
      first = { x = start.x, y = start.y, alt = land.getHeight(start), alt_type = "BARO", type = "TakeOff",
        action = "From Runway", airdromeId = base.ab:getID(), speed = 0, speed_locked = true,
        ETA = 0, ETA_locked = false, task = { id = "ComboTask", params = { tasks = {} } } }
    else
      first = airWP(start, cfg.alt, cfg.speed, {})
    end
    coalition.addGroup(D.cfg.redCountry, Group.Category.AIRPLANE, {
      name = gname, task = "CAP", uncontrolled = false, units = units,
      route = { points = { first, airWP(p1, cfg.alt, cfg.speed, tasks), airWP(p2, cfg.alt, cfg.speed, {}) } },
    })
    local g = Group.getByName(gname)
    return (g and g:isExist()) and gname or nil
  end
  local ground = base ~= nil
  local gname = ground and build(true)
  if not gname then ground = false; gname = build(false) end
  if not gname then return false end
  D.capPersist[#D.capPersist + 1] = { group = gname, spawned = timer.getTime() }
  msg(string.format("%s: Respawning enemy CAP – %dx %s, %s, %s, patrolling %s.",
    D.cfg.awacs.callsignName, cfg.size, v.type, td.label,
    ground and ("taking off from " .. base.ab:getName()) or ("airborne near " .. bullseyeStr(center)),
    ao and ("near " .. ao.name) or bullseyeStr(center)))
  return true
end

function D.capPersistTick(now)
  local pc = D.cfg.cap.persistent
  local alive = 0
  for i = #D.capPersist, 1, -1 do
    local c = D.capPersist[i]
    local n = groupAliveCount(c.group)
    local airborne = false
    if n > 0 then
      for _, u in ipairs(Group.getByName(c.group):getUnits()) do
        if u:isExist() and u:inAir() then airborne = true end
      end
    end
    if airborne then c.wasAirborne = true end
    -- gelandet (z. B. RTB ohne Sprit) oder nie abgehoben: entfernen und neu starten
    local stale = n > 0 and not airborne and (c.wasAirborne or now - c.spawned > pc.stuckTimeout)
    if n == 0 or stale then
      if stale then
        destroyGroup(c.group)
      else
        D.stats.cap = D.stats.cap + 1
        msg(D.cfg.awacs.callsignName .. ": Respawning hostile CAP destroyed.")
      end
      table.remove(D.capPersist, i)
      D.capPersistNext = now + randRange(pc.respawnDelay)
    else
      alive = alive + 1
    end
  end
  if D.capPersistOn and alive < pc.groups and now >= (D.capPersistNext or 0) then
    D.capPersistNext = now + 60
    D.spawnPersistentCAP()
  end
end

function D.toggleCapPersist()
  local pc = D.cfg.cap.persistent
  D.capPersistOn = not D.capPersistOn
  if D.capPersistOn then
    D.capPersistNext = 0
    msg(string.format("%s: Respawning enemy CAP ON – %d group(s) at current difficulty, launching from the enemy airfield nearest to an active AO, back %d-%d min after each loss.",
      D.cfg.awacs.callsignName, pc.groups, math.floor(pc.respawnDelay[1] / 60), math.floor(pc.respawnDelay[2] / 60)))
  else
    msg(D.cfg.awacs.callsignName .. ": Respawning enemy CAP OFF – groups still airborne stay until destroyed (or use Remove all).")
  end
end

-------------------------------------------------------------------------------
-- CHAOS IM FEINDGEBIET: kleine Gefechte, feindliche Hubschrauber
-------------------------------------------------------------------------------
D.skirmishes, D.helos = {}, {}
D.nextSkirmish, D.nextHelo = 0, 0
D.heloOn = D.cfg.chaos.helos.startOn ~= false

-- rote Flugplätze (Anker für Feindgebiet), optional mit Mindestabstand zu blauen Basen
local function redAirbases(minBlue)
  local out = {}
  for _, ab in ipairs(world.getAirbases() or {}) do
    local okc, desc = pcall(function() return ab:getDesc() end)
    if okc and desc and desc.category == Airbase.Category.AIRDROME and ab:getCoalition() == D.cfg.redSide
       and not D.ignoredBase(ab) then
      local p = toV2(ab:getPoint())
      if farFrom(p, D.blueBases, minBlue or 0) then out[#out + 1] = { ab = ab, p = p } end
    end
  end
  return out
end

-- Punkt im Feindgebiet: nächster Flugplatz ist rot, weit genug von blauen Basen
local function enemyGround(p, minBlue)
  if not okGround(p) or not farFrom(p, D.blueBases, minBlue) then return false end
  local best, bd
  for _, ab in ipairs(world.getAirbases() or {}) do
    if not D.ignoredBase(ab) then
      local d = dist(p, toV2(ab:getPoint()))
      if not bd or d < bd then best, bd = ab, d end
    end
  end
  return best ~= nil and best:getCoalition() == D.cfg.redSide
end

local function groundGroup(country, gname, types, n, c, hdg, spacing, hidden)
  local units = {}
  for i = 1, n do
    local o = offset(c, hdg + math.pi / 2, (i - (n + 1) / 2) * spacing)
    units[i] = { name = gname .. "-" .. i, type = types[math.random(#types)], x = o.x, y = o.y,
                 heading = hdg, skill = D.cfg.skill, playerCanDrive = false }
  end
  D.addGround(country, { name = gname, task = "Ground Nothing", hidden = hidden, units = units })
  return units
end

local function moveTo(gname, to, speed, onRoad)
  local g = Group.getByName(gname)
  local p = groupPos(gname)
  if not g or not g:isExist() or not p then return end
  local act = onRoad and "On Road" or "Off Road"
  g:getController():setTask({ id = "Mission", params = { route = { points = {
    { x = p.x, y = p.y, type = "Turning Point", action = act, speed = speed, speed_locked = true,
      ETA = 0, ETA_locked = false, task = emptyTask() },
    { x = to.x, y = to.y, type = "Turning Point", action = act, speed = speed, speed_locked = true,
      ETA = 0, ETA_locked = false, task = emptyTask() } } } } })
end

-- Kleines Gefecht im Hinterland hinter den aktiven AOs (nie in einer AO, bei blauen Basen oder auf dem Weg dorthin)
function D.spawnSkirmish()
  local c = D.cfg.chaos.skirmish
  local anchors = redAirbases(c.minBlueDist)
  if #anchors == 0 then return false end
  local players = playerPositions()
  for _ = 1, 40 do
    local a = anchors[math.random(#anchors)]
    local p = offset(a.p, math.random() * 2 * math.pi, randRange({5000, 40000}))
    local others = {}
    for _, sk in ipairs(D.skirmishes) do others[#others + 1] = sk.pos end
    -- wie die SAM-Hinterhalte nur hinter den aktiven AOs, nie auf dem Weg dorthin
    if D.ambushSpotOk(p) and enemyGround(p, c.minBlueDist) and farFrom(p, players, 10000) and farFrom(p, others, 20000)
       and farFrom(p, D.safeZones or {}, 15000) then
      local hdg = math.random() * 2 * math.pi
      local half = randRange(c.gap) / 2
      local bp, rp = offset(p, hdg, -half), offset(p, hdg, half)
      if okGround(bp) and okGround(rp) then
        local n = math.random(c.size[1], c.size[2])
        local bname, rname = nextId("SKB"), nextId("SKR")
        groundGroup(D.cfg.blueCountry, bname, c.blue, n, bp, hdg, 45, false)
        groundGroup(D.cfg.redCountry, rname, c.red, n, rp, hdg + math.pi, 45, D.hideOnMap())
        -- beide Seiten rücken langsam auf die Mitte vor
        timer.scheduleFunction(safe(function()
          moveTo(bname, offset(p, hdg, 300), 4, false)
          moveTo(rname, offset(p, hdg, -300), 4, false)
        end, "Skirmish"), nil, timer.getTime() + 2)
        D.skirmishes[#D.skirmishes + 1] = { pos = p, blue = bname, red = rname,
          expires = timer.getTime() + randRange(c.lifetime) }
        env.info(string.format("DynSEAD: skirmish %dv%d at %s", n, n, D.fmtPos(p)))
        return true
      end
    end
  end
  return false
end

-- Feindlicher Hubschrauber (unbewaffnet): Luftstart über einem roten Flugplatz, Landung auf einem anderen
function D.spawnHelo()
  local c = D.cfg.chaos.helos
  local bases = redAirbases(c.minBlueDist)
  if #bases < 2 then return false end
  for _ = 1, 30 do
    local a, b = bases[math.random(#bases)], bases[math.random(#bases)]
    local d = dist(a.p, b.p)
    if a ~= b and d >= c.dist[1] and d <= c.dist[2] then
      local gname = nextId("HELO")
      local typ = c.types[math.random(#c.types)]
      local hdg = math.atan2(b.p.y - a.p.y, b.p.x - a.p.x)
      local start = offset(a.p, hdg, 1500)
      local units = {}
      for i = 1, math.random(c.size[1], c.size[2]) do
        units[i] = { name = gname .. "-" .. i, type = typ, x = start.x - 60 * (i - 1), y = start.y - 60 * (i - 1),
                     alt = c.alt, alt_type = "RADIO", speed = c.speed, heading = hdg, skill = D.cfg.skill,
                     payload = { pylons = {}, fuel = 1929, flare = 0, chaff = 0, gun = 0 } }
      end
      local wp1 = airWP(start, c.alt, c.speed, {})
      wp1.alt_type = "RADIO"
      local lwp = { x = b.p.x, y = b.p.y, alt = c.alt, alt_type = "RADIO", type = "Land", action = "Landing",
                     airdromeId = b.ab:getID(), speed = c.speed, speed_locked = true, ETA = 0, ETA_locked = false,
                     task = emptyTask() }
      coalition.addGroup(D.cfg.redCountry, Group.Category.HELICOPTER, {
        name = gname, task = "Transport", uncontrolled = false, units = units,
        route = { points = { wp1, lwp } } })
      local g = Group.getByName(gname)
      if g and g:isExist() then
        local air = AI.Option.Air
        if air and air.id and air.id.ROE then
          pcall(function() g:getController():setOption(air.id.ROE, air.val.ROE.WEAPON_HOLD) end)
        end
        D.helos[#D.helos + 1] = { group = gname, spawned = timer.getTime() }
        env.info(string.format("DynSEAD: helo %s %s -> %s", typ, a.ab:getName(), b.ab:getName()))
        return true
      end
    end
  end
  return false
end

function D.toggleHelos()
  D.heloOn = not D.heloOn
  if D.heloOn then
    D.nextHelo = 0
    msg(D.cfg.awacs.callsignName .. ": Enemy helicopter traffic ON.")
  else
    for _, h in ipairs(D.helos) do destroyGroup(h.group) end
    D.helos = {}
    msg(D.cfg.awacs.callsignName .. ": Enemy helicopter traffic OFF – airspace clear of enemy helicopters.")
  end
end

function D.chaosTick(now, players)
  local cc = D.cfg.chaos
  D.refreshBlueBases()
  -- Gefechte: Ende, wenn eine Seite vernichtet ist (Rest nach 5 min weg) oder Lebensdauer ohne Spieler in der Nähe
  for i = #D.skirmishes, 1, -1 do
    local sk = D.skirmishes[i]
    local nb, nr = groupAliveCount(sk.blue), groupAliveCount(sk.red)
    if (nb == 0 or nr == 0) and not sk.over then sk.over = now + 300 end
    if (sk.over and now >= sk.over) or (now >= sk.expires and farFrom(sk.pos, players, 20000)) then
      destroyGroup(sk.blue); destroyGroup(sk.red)
      table.remove(D.skirmishes, i)
    end
  end
  if cc.skirmish.enabled and #D.skirmishes < cc.skirmish.maxActive and now >= D.nextSkirmish then
    D.nextSkirmish = now + randRange(cc.skirmish.interval)
    D.spawnSkirmish()
  end
  -- Hubschrauber: abgeschossen, gelandet oder Zeitüberschreitung
  for i = #D.helos, 1, -1 do
    local h = D.helos[i]
    local n = groupAliveCount(h.group)
    local airborne = false
    if n > 0 then
      for _, u in ipairs(Group.getByName(h.group):getUnits()) do if u:isExist() and u:inAir() then airborne = true end end
    end
    if airborne then h.wasAirborne = true end
    if n == 0 or (h.wasAirborne and not airborne) or now - h.spawned > cc.helos.timeout then
      if n > 0 then destroyGroup(h.group) end
      table.remove(D.helos, i)
      D.nextHelo = math.max(D.nextHelo, now + randRange(cc.helos.interval))
    end
  end
  if cc.helos.enabled and D.heloOn and #D.helos < cc.helos.maxActive and now >= D.nextHelo then
    D.nextHelo = now + randRange(cc.helos.interval)
    D.spawnHelo()
  end
end

-------------------------------------------------------------------------------
-- ESKORTE: verbündete C-130
-------------------------------------------------------------------------------
D.escort, D.nextEscort = nil, 0

local function blueJets()
  local out = {}
  for _, u in ipairs(coalition.getPlayers(D.cfg.blueSide) or {}) do
    local ok, cat = pcall(function() return u:getDesc().category end)
    if ok and cat == Unit.Category.AIRPLANE and u:isExist() and u:inAir() then out[#out + 1] = toV2(u:getPoint()) end
  end
  return out
end

-- Ziel = eigener Platz, der einer aktiven AO am nächsten ist; Start = am weitesten entfernter eigener Platz
function D.requestEscort()
  local c = D.cfg.escort
  if D.escort then msg("ESCORT: A C-130 escort mission is already running.") return false end
  D.refreshBlueBases()
  if #D.blueBases == 0 then return false end
  local aos = aoCandidates(nil)
  local function frontDist(b)
    local d = math.huge
    for _, ao in ipairs(aos) do d = math.min(d, dist(b, { x = ao.x, y = ao.y })) end
    return d
  end
  local dest, origin
  for _, b in ipairs(D.blueBases) do
    if not dest or frontDist(b) < frontDist(dest) then dest = b end
  end
  for _, b in ipairs(D.blueBases) do
    if b ~= dest and dist(b, dest) >= c.minRoute and (not origin or dist(b, dest) > dist(origin, dest)) then origin = b end
  end
  local destAb
  for _, ab in ipairs(world.getAirbases() or {}) do
    if ab:getName() == dest.name then destAb = ab end
  end
  if not destAb then return false end
  -- Treffpunkt/Start: über dem Startplatz oder, wenn keiner weit genug weg ist, hinter dem Ziel (weg von der Front)
  local start
  if origin then
    start = { x = origin.x, y = origin.y }
  else
    local away = math.random() * 2 * math.pi
    if #aos > 0 then
      local ao = aos[1]
      for _, a in ipairs(aos) do if dist(dest, { x = a.x, y = a.y }) < dist(dest, { x = ao.x, y = ao.y }) then ao = a end end
      away = math.atan2(dest.y - ao.y, dest.x - ao.x)
    end
    start = offset(dest, away, c.minRoute)
  end
  local gname = nextId("ESC")
  local hdg = math.atan2(dest.y - start.y, dest.x - start.x)
  local callsign = "Kingfish " .. math.random(1, 9) .. "-1"
  coalition.addGroup(D.cfg.blueCountry, Group.Category.AIRPLANE, {
    name = gname, task = "Transport", uncontrolled = false,
    units = { { name = gname .. "-1", type = c.type, x = start.x, y = start.y, alt = c.alt, alt_type = "BARO",
                speed = c.speed, heading = hdg, skill = "High", payload = { pylons = {}, fuel = 20830, flare = 60, chaff = 120, gun = 100 } } },
    route = { points = { airWP(start, c.alt, c.speed, { { number = 1, enabled = true, auto = false, id = "Orbit",
      params = { pattern = "Circle", point = start, speed = c.speed, altitude = c.alt } } }) } },
  })
  local g = Group.getByName(gname)
  if not g or not g:isExist() then
    reportError("Escort", "C-130 could not be spawned – check cfg.escort.type")
    return false
  end
  local total = dist(start, dest)
  local mark = newMarkId()
  trigger.action.lineToAll(D.cfg.blueSide, mark, toV3(start), toV3(dest), {0.2, 0.6, 1, 0.9}, 2, true, "C-130 route")
  D.escort = { group = gname, unit = gname .. "-1", callsign = callsign, start = start, dest = dest, destAb = destAb,
               total = total, state = "hold", holdUntil = timer.getTime() + c.holdTime, wave = 1, mark = mark, interceptors = {} }
  msg(string.format("ESCORT: %s (C-130) is holding at %s, angels %d, waiting for escort (up to %d min).\n"
    .. "Destination: %s, %d NM. Expect enemy interceptors en route – keep the Hercules alive!",
    callsign, bullseyeStr(start), math.floor(c.alt * 3.28084 / 1000 + 0.5), math.floor(c.holdTime / 60),
    dest.name or "front airfield", math.floor(total / 1852 + 0.5)))
  return true
end

local function escortDepart(es)
  local c = D.cfg.escort
  local g = Group.getByName(es.group)
  if not g or not g:isExist() then return end
  local p = groupPos(es.group) or es.start
  local lwp = { x = es.dest.x, y = es.dest.y, alt = 0, alt_type = "RADIO", type = "Land", action = "Landing",
                airdromeId = es.destAb:getID(), speed = 80, speed_locked = true, ETA = 0, ETA_locked = false,
                task = { id = "ComboTask", params = { tasks = {} } } }
  g:getController():setTask({ id = "Mission", params = { route = { points = { airWP(p, c.alt, c.speed, {}), lwp } } } })
end

-- Abfangjäger: kommen aus Richtung Feindgebiet und jagen die C-130 (Route alle huntUpdate s neu)
local function escortIntercept(es, cp)
  local c, cap = D.cfg.escort, D.cfg.cap
  local enemy
  for _, a in ipairs(redAirbases(0)) do
    if not enemy or dist(a.p, cp) < dist(enemy, cp) then enemy = a.p end
  end
  local dir = enemy and math.atan2(enemy.y - cp.y, enemy.x - cp.x) or math.random() * 2 * math.pi
  local sp = offset(cp, dir, c.interceptDist)
  local td = cap.tiers[D.currentCapTier()]
  local v = td.variants[math.random(#td.variants)]
  local lo = D.capLoadouts[v.loadout]
  local gname = nextId("INT")
  local units = {}
  for i = 1, cap.size do
    units[i] = { name = gname .. "-" .. i, type = v.type, x = sp.x - 300 * (i - 1), y = sp.y + 300 * (i - 1),
      alt = cap.alt, alt_type = "BARO", speed = cap.speed, heading = dir + math.pi, skill = td.skill or D.cfg.skill,
      payload = lo and { pylons = lo.pylons, fuel = lo.fuel, flare = lo.flare, chaff = lo.chaff, gun = lo.gun } or nil }
  end
  local tasks = { { number = 1, enabled = true, auto = false, id = "EngageTargets",
                    params = { targetTypes = { "Air" }, priority = 0 } } }
  coalition.addGroup(D.cfg.redCountry, Group.Category.AIRPLANE, {
    name = gname, task = "CAP", uncontrolled = false, units = units,
    route = { points = { airWP(sp, cap.alt, cap.speed, tasks), airWP(cp, cap.alt, cap.speed * 1.2, {}) } },
  })
  es.interceptors[#es.interceptors + 1] = gname
  msg(string.format("%s: Hostile interceptors – %dx %s – launched toward %s from %s, %s!",
    D.cfg.awacs.callsignName, cap.size, v.type, es.callsign,
    string.format("%03d°", math.floor((math.deg(math.atan2(sp.y - cp.y, sp.x - cp.x)) + 360) % 360 + 0.5)),
    string.format("%d NM", math.floor(c.interceptDist / 1852 + 0.5))))
end

function D.reportEscort()
  local es = D.escort
  if not es then msg("ESCORT: No C-130 escort mission running.") return end
  local p = groupPos(es.group)
  if not p then msg("ESCORT: Contact lost.") return end
  local left = dist(p, es.dest)
  local hostile = 0
  for _, n in ipairs(es.interceptors) do if groupAliveCount(n) > 0 then hostile = hostile + 1 end end
  msg(string.format("ESCORT: %s at %s, %s. %d NM to %s. Hostile interceptor groups: %d.",
    es.callsign, bullseyeStr(p), es.state == "hold" and "holding for escort" or "en route",
    math.floor(left / 1852 + 0.5), es.dest.name or "destination", hostile))
end

local function endEscort(es, now)
  trigger.action.removeMark(es.mark)
  local g, ints = es.group, es.interceptors
  timer.scheduleFunction(function()
    destroyGroup(g)
    for _, n in ipairs(ints) do destroyGroup(n) end
  end, nil, now + 600)
  D.escort = nil
  local c = D.cfg.escort
  if c.autoInterval and c.autoInterval[1] and c.autoInterval[1] > 0 then D.nextEscort = now + randRange(c.autoInterval) end
end

function D.escortTick(now)
  local c = D.cfg.escort
  local es = D.escort
  if not es then
    if c.autoInterval and c.autoInterval[1] and c.autoInterval[1] > 0 then
      if D.nextEscort == 0 then D.nextEscort = now + randRange(c.autoInterval) end
      if now >= D.nextEscort then
        D.nextEscort = now + 600
        if #aoCandidates(nil) > 0 then D.requestEscort() end
      end
    end
    return
  end
  local u = Unit.getByName(es.unit)
  if not u or not u:isExist() or u:getLife() < 1 then
    msg(string.format("ESCORT: %s has been shot down – mission failed.", es.callsign))
    endEscort(es, now)
    return
  end
  local p = toV2(u:getPoint())
  if es.state == "hold" then
    if now >= es.holdUntil or not farFrom(p, blueJets(), c.joinDist) then
      es.state = "enroute"
      escortDepart(es)
      msg(string.format("ESCORT: %s %s – departing for %s.", es.callsign,
        now >= es.holdUntil and "could not wait any longer" or "has its escort", es.dest.name or "destination"))
    end
  elseif es.state == "enroute" then
    if u:inAir() then es.wasAirborne = true end
    local progress = 1 - dist(p, es.dest) / es.total
    local w = c.waves[es.wave]
    if w and progress >= w and (es.wave == 1 or es.total >= c.longRoute) then
      escortIntercept(es, p)
      es.wave = es.wave + 1
    end
    if now >= (es.nextHunt or 0) then
      es.nextHunt = now + c.huntUpdate
      for _, n in ipairs(es.interceptors) do
        local g = Group.getByName(n)
        local ip = groupPos(n)
        if g and g:isExist() and ip then
          g:getController():setTask({ id = "Mission", params = { route = { points = {
            airWP(ip, D.cfg.cap.alt, D.cfg.cap.speed, { { number = 1, enabled = true, auto = false, id = "EngageTargets",
              params = { targetTypes = { "Air" }, priority = 0 } } }),
            airWP(p, D.cfg.cap.alt, D.cfg.cap.speed * 1.2, {}) } } } })
        end
      end
    end
    if es.wasAirborne and not u:inAir() and dist(p, es.dest) < 5000 then
      D.stats.escort = D.stats.escort + 1
      msg(string.format("ESCORT: %s has landed at %s – cargo delivered, good escort! (%d total)",
        es.callsign, es.dest.name or "destination", D.stats.escort))
      endEscort(es, now)
    end
  end
end

-------------------------------------------------------------------------------
-- SCUD-JAGD
-------------------------------------------------------------------------------
D.scud, D.nextScud = nil, 0

local function clearMark(id) if id then trigger.action.removeMark(id) end end

function D.spawnScud(force)
  local c = D.cfg.scud
  D.refreshBlueBases()
  local anchors = redAirbases(c.minBlueDist)
  if #anchors == 0 or #D.blueBases == 0 then return false end
  for _ = 1, 80 do
    local a = anchors[math.random(#anchors)]
    local p = offset(a.p, math.random() * 2 * math.pi, randRange({5000, 30000}))
    p = D.nearRoad(p) or p
    local tgt = nearestBlueBase(p)
    local d = tgt and dist(p, tgt)
    if d and d >= c.range[1] and d <= c.range[2] and okGround(p) and D.ambushSpotOk(p) then
      local gname = nextId("SCUD")
      local hdg = math.atan2(tgt.y - p.y, tgt.x - p.x)
      local units = { { name = gname .. "-1", type = "Scud_B", x = p.x, y = p.y, heading = hdg,
                        skill = D.cfg.skill, playerCanDrive = false } }
      for i, t in ipairs(c.escort) do
        local o = offset(p, hdg + math.pi + (i - 1) * 0.6, 60)
        units[#units + 1] = { name = gname .. "-" .. (i + 1), type = t, x = o.x, y = o.y, heading = hdg,
                              skill = D.cfg.skill, playerCanDrive = false }
      end
      D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units })
      local center = offset(p, math.random() * 2 * math.pi, math.random() * c.areaRadius * 0.7)
      local mark = newMarkId()
      trigger.action.circleToAll(D.cfg.blueSide, mark, toV3(center), c.areaRadius,
        {1, 0.5, 0, 0.9}, {1, 0.5, 0, 0.06}, 2, true, "SCUD launch area")
      local now = timer.getTime()
      D.scud = { group = gname, pos = p, target = tgt, center = center, mark = mark,
                 fireAt = now + randRange(c.setupTime), state = "setup" }
      msg(string.format("%s: SCUD ALERT – intelligence reports a Scud launcher setting up within %d NM of %s (orange circle on the map). "
        .. "Expected target: %s. Launch expected in about %d min – find and destroy it!",
        D.cfg.awacs.callsignName, math.floor(c.areaRadius / 1852 + 0.5), bullseyeStr(center), tgt.name or "a friendly airfield",
        math.floor((D.scud.fireAt - now) / 60 + 0.5)))
      env.info("DynSEAD: Scud at " .. D.fmtPos(p))
      if force then msg("DEBUG: Scud at " .. D.fmtPos(p)) end
      return true
    end
  end
  if force then msg("DEBUG: No valid Scud position found.") end
  return false
end

function D.reportScud()
  local sc = D.scud
  if not sc or sc.state == "done" then msg("SCUD: No Scud activity reported.") return end
  local left = math.max(0, math.floor((sc.fireAt - timer.getTime()) / 60 + 0.5))
  msg(string.format("SCUD: Launcher within %d NM of %s, target %s. %s",
    math.floor(D.cfg.scud.areaRadius / 1852 + 0.5), bullseyeStr(sc.center), sc.target.name or "friendly airfield",
    sc.state == "setup" and string.format("Launch expected in about %d min.", left)
      or (sc.state == "firing" and "Launcher erecting – launch imminent!" or "Missile launched.")))
end

function D.scudOnShot(e)
  local sc = D.scud
  if not sc or (sc.state ~= "firing" and sc.state ~= "setup") then return end
  local ok, gname = pcall(function() return e.initiator:getGroup():getName() end)
  if not ok or gname ~= sc.group then return end
  sc.state, sc.launchedAt = "launched", timer.getTime()
  local t = dist(sc.pos, sc.target) / 1100
  msg(string.format("%s: SCUD LAUNCH! Missile inbound to %s – impact in about %d min. Take cover!",
    D.cfg.awacs.callsignName, sc.target.name or "a friendly airfield", math.max(1, math.floor(t / 60 + 0.5))))
end

function D.scudTick(now)
  local c = D.cfg.scud
  local sc = D.scud
  if not sc then
    if now >= D.nextScud then
      if D.nextScud == 0 then D.nextScud = now + randRange(c.interval) return end
      D.nextScud = now + 300
      D.spawnScud()
    end
    return
  end
  local alive = unitAlive(sc.group .. "-1")
  if (sc.state == "setup" or sc.state == "firing") and not alive then
    D.stats.scud = D.stats.scud + 1
    msg(string.format("%s: Scud launcher destroyed – launch prevented! Good work. (%d total)", D.cfg.awacs.callsignName, D.stats.scud))
    sc.state, sc.endAt = "done", now + 300
  elseif sc.state == "setup" then
    if not sc.warned and now >= sc.fireAt - 300 then
      sc.warned = true
      msg(D.cfg.awacs.callsignName .. ": Scud launch expected within 5 minutes!")
    end
    if now >= sc.fireAt then
      local g = Group.getByName(sc.group)
      if g and g:isExist() then
        local ctl = g:getController()
        pcall(function() ctl:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED) end)
        ctl:setTask({ id = "FireAtPoint", params = { point = { x = sc.target.x, y = sc.target.y },
          radius = c.impactRadius, expendQty = c.salvo, expendQtyEnabled = true } })
      end
      sc.state, sc.firedAt = "firing", now
      msg(D.cfg.awacs.callsignName .. ": Scud launcher is erecting – launch imminent!")
    end
  elseif sc.state == "firing" and now - sc.firedAt > c.fireTimeout then
    -- kein Abschuss-Ereignis: Einschlag nachstellen
    local t = dist(sc.pos, sc.target) / 1100
    msg(string.format("%s: SCUD LAUNCH! Missile inbound to %s – impact in about %d min. Take cover!",
      D.cfg.awacs.callsignName, sc.target.name or "a friendly airfield", math.max(1, math.floor(t / 60 + 0.5))))
    local tp = toV3(offset(sc.target, math.random() * 2 * math.pi, math.random() * c.impactRadius))
    timer.scheduleFunction(function() trigger.action.explosion(tp, c.fallbackPower) end, nil, now + t)
    env.info("DynSEAD: Scud fired no weapon – impact simulated")
    sc.state, sc.launchedAt = "launched", now
  elseif sc.state == "launched" then
    sc.state, sc.endAt = "done", now + 600
  elseif sc.state == "done" and now >= sc.endAt then
    destroyGroup(sc.group)
    clearMark(sc.mark)
    D.scud = nil
    D.nextScud = now + randRange(c.interval)
  end
end

-------------------------------------------------------------------------------
-- CSAR
-------------------------------------------------------------------------------
D.csars, D.nextCsar = {}, 0

-- Pilot am Boden bei p (name = Rufname für die Meldungen)
function D.spawnCsar(p, name, force)
  local c = D.cfg.csar
  if #D.csars >= c.maxActive and not force then return false end
  if not okGround(p) then return false end
  local gname = nextId("CSAR")
  D.addGround(D.cfg.blueCountry, { name = gname, task = "Ground Nothing", hidden = false, units = {
    { name = gname .. "-1", type = "Soldier M4", x = p.x, y = p.y, heading = 0, skill = "Average", playerCanDrive = false } } })
  local cs = { group = gname, pos = p, name = name, enemies = {}, spawned = timer.getTime(), nextSmoke = 0 }
  for _ = 1, math.random(c.enemyGroups[1], c.enemyGroups[2]) do
    local ep = offset(p, math.random() * 2 * math.pi, randRange(c.enemyDist))
    if okGround(ep) then
      local en = nextId("CSARE")
      groundGroup(D.cfg.redCountry, en, c.enemyTypes, math.random(c.enemySize[1], c.enemySize[2]), ep,
        math.atan2(p.y - ep.y, p.x - ep.x), 30, D.hideOnMap())
      cs.enemies[#cs.enemies + 1] = en
      timer.scheduleFunction(safe(function() moveTo(en, p, c.enemySpeed, false) end, "CSAR"), nil, timer.getTime() + 2)
    end
  end
  cs.mark = newMarkId()
  trigger.action.markToCoalition(cs.mark, "CSAR: downed pilot " .. name .. "\n" .. D.fmtPos(p), toV3(p), D.cfg.blueSide, true)
  D.csars[#D.csars + 1] = cs
  msg(string.format("%s: CSAR – %s is down at %s. Enemy forces are closing in. "
    .. "Land a helicopter next to the pilot and fly them to a friendly airfield or FARP. Jets: keep the enemy away!",
    D.cfg.awacs.callsignName, name, D.fmtPos(p)))
  return true
end

-- zufälliger Verbündeter: nahe dem Rand einer aktiven AO auf der eigenen Seite
function D.spawnAllyCsar(force)
  local aos = aoCandidates(nil)
  if #aos == 0 then return false end
  D.refreshBlueBases()
  for _ = 1, 40 do
    local ao = aos[math.random(#aos)]
    local c0 = { x = ao.x, y = ao.y }
    local b = nearestBlueBase(c0)
    local hdg = b and math.atan2(b.y - c0.y, b.x - c0.x) or math.random() * 2 * math.pi
    local p = offset(c0, hdg + (math.random() - 0.5) * 2, ao.radius + randRange({-10000, 10000}))
    if okGround(p) and enemyGround(p, 15000) then
      local cs = { "Viper", "Hawg", "Hornet", "Jedi", "Dude", "Pontiac" }
      return D.spawnCsar(p, string.format("%s %d-%d", cs[math.random(#cs)], math.random(1, 9), math.random(1, 4)), force)
    end
  end
  return false
end

function D.csarOnEject(e)
  local c = D.cfg.csar
  if not c.enabled or not c.playerEject then return end
  local u = e.initiator
  local ok, info = pcall(function()
    return { side = u:getCoalition(), player = u:getPlayerName(), p = toV2(u:getPoint()) }
  end)
  if not ok or not info or info.side ~= D.cfg.blueSide or not info.player then return end
  D.refreshBlueBases()
  if not enemyGround(info.p, 10000) then return end
  local p = offset(info.p, math.random() * 2 * math.pi, math.random() * 300)
  timer.scheduleFunction(safe(function() D.spawnCsar(p, info.player, true) end, "CSAR"), nil, timer.getTime() + 60)
end

local function blueHelos()
  local out = {}
  for _, u in ipairs(coalition.getPlayers(D.cfg.blueSide) or {}) do
    local ok, cat = pcall(function() return u:getDesc().category end)
    if ok and cat == Unit.Category.HELICOPTER and u:isExist() then out[#out + 1] = u end
  end
  return out
end

local function endCsar(cs, i, now)
  clearMark(cs.mark)
  destroyGroup(cs.group)
  local en = cs.enemies
  timer.scheduleFunction(function() for _, n in ipairs(en) do destroyGroup(n) end end, nil, now + 300)
  table.remove(D.csars, i)
end

function D.csarTick(now)
  local c = D.cfg.csar
  for i = #D.csars, 1, -1 do
    local cs = D.csars[i]
    if cs.carrier then
      local u = Unit.getByName(cs.carrier)
      if not u or not u:isExist() then
        msg(string.format("%s: Contact lost with the helicopter carrying %s – rescue failed.", D.cfg.awacs.callsignName, cs.name))
        endCsar(cs, i, now)
      elseif not u:inAir() then
        local p = toV2(u:getPoint())
        local home = not farFrom(p, D.blueBases, c.deliverDist)
        for _, f in ipairs(D.farps or {}) do if dist(p, f.pos) < c.deliverDist then home = true end end
        if home then
          D.stats.csar = D.stats.csar + 1
          msg(string.format("%s: %s delivered safely – CSAR complete! (%d total)", D.cfg.awacs.callsignName, cs.name, D.stats.csar))
          endCsar(cs, i, now)
        end
      end
    else
      local pp = groupPos(cs.group)
      if not pp then
        msg(string.format("%s: %s is KIA – CSAR failed.", D.cfg.awacs.callsignName, cs.name))
        endCsar(cs, i, now)
      else
        local captured = false
        for _, en in ipairs(cs.enemies) do
          local g = Group.getByName(en)
          for _, eu in ipairs((g and g:isExist() and g:getUnits()) or {}) do
            if eu:isExist() and eu:getLife() >= 1 and dist(toV2(eu:getPoint()), pp) < c.captureDist then captured = true end
          end
        end
        if captured then
          msg(string.format("%s: %s has been captured by enemy forces – CSAR failed.", D.cfg.awacs.callsignName, cs.name))
          endCsar(cs, i, now)
        elseif now - cs.spawned > c.timeout then
          msg(string.format("%s: No more contact with %s – CSAR failed.", D.cfg.awacs.callsignName, cs.name))
          endCsar(cs, i, now)
        else
          for _, h in ipairs(blueHelos()) do
            local hp = toV2(h:getPoint())
            local d = dist(hp, pp)
            if d < c.smokeDist and now >= cs.nextSmoke then
              trigger.action.smoke(toV3(pp), trigger.smokeColor.Green)
              cs.nextSmoke = now + 300
            end
            if d < c.pickupDist and not h:inAir() then
              cs.carrier = h:getName()
              destroyGroup(cs.group)
              clearMark(cs.mark)
              cs.mark = nil
              msg(string.format("%s: %s is aboard %s! Fly them to any friendly airfield or FARP.",
                D.cfg.awacs.callsignName, cs.name, h:getPlayerName() or h:getName()))
              break
            end
          end
        end
      end
    end
  end
  if c.allyInterval and c.allyInterval[1] and c.allyInterval[1] > 0 then
    if D.nextCsar == 0 then D.nextCsar = now + randRange(c.allyInterval) end
    if now >= D.nextCsar then
      D.nextCsar = now + randRange(c.allyInterval)
      if #D.csars < c.maxActive then D.spawnAllyCsar() end
    end
  end
end

function D.reportCsar()
  if #D.csars == 0 then msg("CSAR: No downed pilots.") return end
  local lines = { "CSAR:" }
  for _, cs in ipairs(D.csars) do
    if cs.carrier then
      lines[#lines + 1] = string.format("• %s – aboard %s, return to base", cs.name, cs.carrier)
    else
      local pp = groupPos(cs.group) or cs.pos
      local nearest
      for _, en in ipairs(cs.enemies) do
        local ep = groupPos(en)
        if ep then nearest = math.min(nearest or math.huge, dist(ep, pp)) end
      end
      lines[#lines + 1] = string.format("• %s at %s\n   enemy forces: %s", cs.name, D.fmtPos(pp),
        nearest and string.format("%.1f km away", nearest / 1000) or "none")
    end
  end
  msg(table.concat(lines, "\n"))
end

function D.smokeCsar()
  local n = 0
  for _, cs in ipairs(D.csars) do
    local pp = not cs.carrier and groupPos(cs.group)
    if pp then trigger.action.smoke(toV3(pp), trigger.smokeColor.Green); n = n + 1 end
  end
  msg(n > 0 and "CSAR: Downed pilots popping green smoke." or "CSAR: No pilot on the ground.")
end

-------------------------------------------------------------------------------
-- SCHIFFSZIELE (Ship Strike)
-------------------------------------------------------------------------------
local function isSea(p)
  local t = land.getSurfaceType(p)
  return t == land.SurfaceType.WATER or t == land.SurfaceType.SHALLOW_WATER
end

local function seaClear(p, r)
  if not isSea(p) then return false end
  for k = 0, 7 do
    local a = k * math.pi / 4
    if not isSea({ x = p.x + r * math.cos(a), y = p.y + r * math.sin(a) }) then return false end
  end
  return true
end

-- Startpunkt auf See vor einem nicht-blauen Flugplatz, mit komplett freier Fahrstrecke
function D.findSeaSpot()
  local cfg = D.cfg.ship
  local bases = {}
  for _, ab in ipairs(world.getAirbases() or {}) do
    local desc = ab:getDesc()
    if desc and desc.category == Airbase.Category.AIRDROME and ab:getCoalition() ~= D.cfg.blueSide and not D.ignoredBase(ab) then
      bases[#bases + 1] = toV2(ab:getPoint())
    end
  end
  for i = #bases, 2, -1 do
    local j = math.random(i)
    bases[i], bases[j] = bases[j], bases[i]
  end
  local players = playerPositions()
  for _, b in ipairs(bases) do
    for _ = 1, 40 do
      local p = offset(b, math.random() * 2 * math.pi, randRange(cfg.distance))
      if seaClear(p, cfg.seaMargin) and farFrom(p, players, cfg.minDistPlayers) then
        for _ = 1, 8 do
          local hdg = math.random() * 2 * math.pi
          local ok = true
          for k = 1, 10 do
            if not seaClear(offset(p, hdg, cfg.leg * k / 10), 1000) then ok = false break end
          end
          if ok then return p, hdg end
        end
      end
    end
  end
  return nil
end

local function shipWP(p, speed)
  return { x = p.x, y = p.y, type = "Turning Point", action = "Turning Point", speed = speed,
           speed_locked = true, ETA = 0, ETA_locked = false, task = emptyTask() }
end

-- free = true: Feuer frei; false: Feuer halten (Hinterhalt)
local function shipFire(gname, free)
  local g = Group.getByName(gname)
  if not g or not g:isExist() then return end
  local c = g:getController()
  if not c then return end
  local naval = AI and AI.Option and AI.Option.Naval
  local id = (naval and naval.id and naval.id.ROE) or 0
  local val = naval and naval.val and naval.val.ROE
  local open = (val and val.OPEN_FIRE) or 2
  local hold = (val and val.WEAPON_HOLD) or 4
  pcall(function() c:setOption(id, free and open or hold) end)
end

function D.updateShipMark(t)
  if not D.cfg.mapMarks then return end
  local p = groupPos(t.group)
  if not p then return end
  if t.mark then trigger.action.removeMark(t.mark) end
  t.mark = newMarkId()
  t.intelPos = { x = p.x + t.offX, y = p.y + t.offY }
  trigger.action.markToCoalition(t.mark,
    string.format("SHIP STRIKE: %s (±%s)", t.name, fmtDist(D.cfg.ship.intelError)),
    toV3(t.intelPos), D.cfg.blueSide, true)
end

function D.spawnShip(tier, manual)
  local cfg = D.cfg.ship
  if not cfg.enabled then return false end
  if #D.ships >= cfg.maxActive then
    if manual then msg("SHIP STRIKE: Maximum number of active taskings reached.") end
    return false
  end
  tier = math.max(1, math.min(#cfg.tiers, tier or cfg.difficulty))
  local td = cfg.tiers[tier]
  local p, hdg = D.findSeaSpot()
  if not p then
    if manual then msg("SHIP STRIKE: No suitable sea area found – try again later.") end
    return false
  end

  local gname = nextId("SHIP")
  local n = #td.ships
  local units = {}
  for i, typ in ipairs(td.ships) do
    local u = offset(p, hdg + math.pi / 2, (i - (n + 1) / 2) * cfg.spacing)
    units[i] = { name = gname .. "-" .. i, type = typ, x = u.x, y = u.y, heading = hdg,
                 skill = td.skill or D.cfg.skill }
  end
  local q = offset(p, hdg, cfg.leg)
  coalition.addGroup(D.cfg.redCountry, Group.Category.SHIP, {
    name = gname, task = "Nothing", units = units,
    route = { points = { shipWP(p, cfg.speed), shipWP(q, cfg.speed), shipWP(p, cfg.speed) } },
  })

  local alive = groupAliveCount(gname)
  if alive < n then
    local names = {}
    for _, typ in ipairs(td.ships) do names[#names + 1] = typ end
    reportError("Ship", string.format("only %d of %d ships spawned (%s) – check ship type names in D.cfg.ship.tiers[%d]",
      alive, n, table.concat(names, ", "), tier))
    if alive == 0 then return false end
  end

  local ambush = (td.alertRange or 0) > 0
  local off = jitter({ x = 0, y = 0 }, cfg.intelError)
  local t = { group = gname, name = td.label, tier = tier, initial = alive, offX = off.x, offY = off.y,
              alertRange = td.alertRange or 0, alerted = not ambush }
  D.ships[#D.ships + 1] = t
  shipFire(gname, not ambush)
  D.updateShipMark(t)
  t.nextMark = timer.getTime() + cfg.markUpdate

  local ip = t.intelPos or p
  msg(string.format("SHIP STRIKE: %s – %d ship%s\nApprox. position: %s\n%s",
    td.label, alive, alive == 1 and "" or "s", D.fmtPos(ip), td.brief or ""))
  return true
end

function D.requestShip(tier) D.spawnShip(tier, true) end

function D.reportShips()
  if #D.ships == 0 then msg("SHIP STRIKE: No active taskings.") return end
  local lines = { "SHIP STRIKE TASKINGS:" }
  for i, t in ipairs(D.ships) do
    local p = groupPos(t.group)
    if p then
      local ip = { x = p.x + t.offX, y = p.y + t.offY }
      lines[#lines + 1] = string.format("%d) %s – %d/%d ships remaining%s\n   Approx. %s",
        i, t.name, groupAliveCount(t.group), t.initial, t.alerted and " [ACTIVE]" or "", D.fmtPos(ip))
    end
  end
  msg(table.concat(lines, "\n"))
end

function D.shipTick(now, players)
  local cfg = D.cfg.ship
  for i = #D.ships, 1, -1 do
    local t = D.ships[i]
    local alive = groupAliveCount(t.group)
    local destroyed = 1 - alive / t.initial
    if destroyed * 100 >= cfg.successPercent then
      table.remove(D.ships, i)
      D.stats.ship = D.stats.ship + 1
      if t.mark then trigger.action.removeMark(t.mark) end
      msg(string.format("SHIP STRIKE: \"%s\" destroyed! (%d total)", t.name, D.stats.ship))
      local g = t.group
      timer.scheduleFunction(safe(function() destroyGroup(g) end, "Cleanup"), nil, now + cfg.cleanupAfter)
    else
      if not t.alerted then
        local reason
        if alive < t.initial then
          reason = "hit"
        else
          local grp = Group.getByName(t.group)
          if grp and grp:isExist() then
            for _, u in ipairs(grp:getUnits()) do
              if u:isExist() then
                local up = toV2(u:getPoint())
                for _, q in ipairs(players) do
                  if dist(up, q) < t.alertRange then reason = "near" break end
                end
              end
              if reason then break end
            end
          end
        end
        if reason then
          t.alerted = true
          shipFire(t.group, true)
          msg(string.format("SHIP STRIKE: \"%s\" is now ENGAGING!", t.name))
        else
          shipFire(t.group, false)
        end
      end
      if now >= (t.nextMark or 0) then
        D.updateShipMark(t)
        t.nextMark = now + cfg.markUpdate
      end
    end
  end
end

-------------------------------------------------------------------------------
-- NEBENAUFTRÄGE: Konvoi, Deep Strike, Troops in Contact (mit JTAC)
-------------------------------------------------------------------------------
local function redAirbases()
  local out = {}
  for _, ab in ipairs(world.getAirbases() or {}) do
    local desc = ab:getDesc()
    if desc and desc.category == Airbase.Category.AIRDROME and ab:getCoalition() ~= D.cfg.blueSide and not D.ignoredBase(ab) then
      local p = toV2(ab:getPoint())
      p.name = ab:getName()
      out[#out + 1] = p
    end
  end
  return out
end

local function roadPoint(p, maxDist)
  local rx, ry = land.getClosestPointOnRoads("roads", p.x, p.y)
  if rx then
    local q = { x = rx, y = ry }
    if dist(q, p) <= maxDist then return q end
  end
  return nil
end

local function bearingDeg(from, to)
  return math.floor(math.deg(math.atan2(to.y - from.y, to.x - from.x)) + 360.5) % 360
end

local function removeMarks(list)
  for _, id in ipairs(list or {}) do trigger.action.removeMark(id) end
end

local function scheduleCleanup(gnames, delay)
  timer.scheduleFunction(safe(function()
    for _, g in ipairs(gnames) do destroyGroup(g) end
  end, "Cleanup"), nil, timer.getTime() + delay)
end

local function aliveUnits(gname)
  local out = {}
  local g = Group.getByName(gname)
  if g and g:isExist() then
    for _, u in ipairs(g:getUnits()) do
      if u:isExist() and u:getLife() >= 1 then out[#out + 1] = u end
    end
  end
  return out
end

-- ----------------------------------------------------------------- Konvoi abfangen
function D.spawnConvoy(manual)
  local cfg = D.cfg.convoy
  if not cfg.enabled then return false end
  if #D.convoys >= cfg.maxActive then
    if manual then msg("CONVOY: Maximum number of active taskings reached.") end
    return false
  end
  local bases = redAirbases()
  local players = playerPositions()
  local A, B, sp, ep
  for _ = 1, 80 do
    if #bases < 2 then break end
    local a, b = bases[math.random(#bases)], bases[math.random(#bases)]
    local d = dist(a, b)
    if a ~= b and d >= cfg.distance[1] and d <= cfg.distance[2] then
      local s1, e1 = roadPoint(a, 8000), roadPoint(b, 8000)
      if s1 and e1 and dist(s1, e1) > 15000 and farFrom(s1, players, cfg.minDistPlayers) then
        A, B, sp, ep = a, b, s1, e1
        break
      end
    end
  end
  if not sp then
    if manual then msg("CONVOY: No suitable route found – try again later.") end
    return false
  end

  local n = math.random(cfg.size[1], cfg.size[2])
  local nAAA = math.min(math.random(0, cfg.maxAAA), n - 1)
  local isAAA = {}
  while nAAA > 0 do
    local k = math.random(2, n)
    if not isAAA[k] then isAAA[k] = true nAAA = nAAA - 1 end
  end
  local hdg = math.atan2(ep.y - sp.y, ep.x - sp.x)
  local gname = nextId("CONVOY")
  local units, nAA = {}, 0
  for i = 1, n do
    local typ
    if isAAA[i] then typ = cfg.aaaTypes[math.random(#cfg.aaaTypes)] nAA = nAA + 1
    else typ = cfg.types[math.random(#cfg.types)] end
    local u = offset(sp, hdg, -30 * (i - 1))
    units[i] = { name = gname .. "-" .. i, type = typ, x = u.x, y = u.y, heading = hdg,
                 skill = D.cfg.skill, playerCanDrive = false }
  end
  local function wp(p)
    return { x = p.x, y = p.y, type = "Turning Point", action = "On Road", speed = cfg.speed,
             speed_locked = true, ETA = 0, ETA_locked = false, task = emptyTask() }
  end
  D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units, route = { points = { wp(sp), wp(ep) } } })

  local alive = groupAliveCount(gname)
  if alive < n then
    reportError("Convoy", string.format("only %d of %d vehicles spawned – check vehicle type names in D.cfg.convoy", alive, n))
    if alive == 0 then return false end
  end

  local t = { group = gname, initial = alive, start = sp, dest = ep, aName = A.name, bName = B.name,
              spawned = timer.getTime(), marks = {} }
  if D.cfg.mapMarks then
    local side = D.cfg.blueSide
    local id1, id2, id3 = newMarkId(), newMarkId(), newMarkId()
    trigger.action.markToCoalition(id1, "CONVOY START (" .. A.name .. ")", toV3(sp), side, true)
    trigger.action.markToCoalition(id2, "CONVOY DESTINATION (" .. B.name .. ")", toV3(ep), side, true)
    trigger.action.lineToAll(side, id3, toV3(sp), toV3(ep), {1, 0.6, 0, 0.9}, 2, true)
    t.marks = { id1, id2, id3 }
  end
  D.convoys[#D.convoys + 1] = t

  local eta = math.floor(dist(sp, ep) * 1.3 / cfg.speed / 60 + 0.5)
  msg(string.format("CONVOY INTERCEPT: Supply convoy (%d light vehicles, up to %d AAA) departing %s for %s.\nStart: %s\nDestination: %s\nRoute follows the roads between the two points (see F10 map line). Speed ~%d km/h, ETA ~%d min.\nFind them with your AG radar / targeting pod and stop them before they arrive.",
    alive, cfg.maxAAA, A.name, B.name, D.fmtPos(sp), D.fmtPos(ep), math.floor(cfg.speed * 3.6 + 0.5), eta))
  return true
end

function D.requestConvoy() D.spawnConvoy(true) end

function D.reportConvoy()
  if #D.convoys == 0 then msg("CONVOY: No active taskings.") return end
  local lines = { "CONVOY TASKINGS:" }
  for i, t in ipairs(D.convoys) do
    lines[#lines + 1] = string.format("%d) %s -> %s – %d/%d vehicles remaining\n   Start: %s\n   Destination: %s",
      i, t.aName, t.bName, groupAliveCount(t.group), t.initial, D.fmtPos(t.start), D.fmtPos(t.dest))
  end
  msg(table.concat(lines, "\n"))
end

function D.convoyTick(now)
  local cfg = D.cfg.convoy
  for i = #D.convoys, 1, -1 do
    local t = D.convoys[i]
    local alive = groupAliveCount(t.group)
    local pos = groupPos(t.group)
    local verdict
    if (1 - alive / t.initial) * 100 >= cfg.successPercent then
      verdict = "success"
    elseif alive == 0 or not pos then
      verdict = "success"
    elseif dist(pos, t.dest) <= cfg.arriveRadius then
      verdict = "escaped"
    elseif not t.moved then
      if now - t.spawned >= 180 then
        if dist(pos, t.start) < 200 then verdict = "stuck" else t.moved = true end
      end
    end
    if verdict then
      table.remove(D.convoys, i)
      removeMarks(t.marks)
      if verdict == "success" then
        D.stats.convoy = D.stats.convoy + 1
        msg(string.format("CONVOY: Convoy stopped! (%d total)", D.stats.convoy))
      elseif verdict == "escaped" then
        msg("CONVOY: The convoy reached its destination. Tasking failed.")
      else
        msg("CONVOY: Tasking cancelled – convoy could not leave its start position.")
      end
      scheduleCleanup({ t.group }, verdict == "success" and cfg.cleanupAfter or 5)
    end
  end
end

-- ----------------------------------------------------------------- Deep Strike
function D.spawnDeepStrike(manual)
  local cfg = D.cfg.deepStrike
  if not cfg.enabled then return false end
  if #D.deeps >= cfg.maxActive then
    if manual then msg("DEEP STRIKE: Maximum number of active taskings reached.") end
    return false
  end
  local pool, any = {}, false
  for _, tg in ipairs(cfg.targets) do
    local v = coord.LLtoLO(tg.lat, tg.lon, 0)
    local p = { x = v.x, y = v.z }
    local nb = nearestBlueBase(p)
    local d = nb and dist(p, nb) or math.huge
    if d >= cfg.minDistance then
      any = true
      if not tg.used then pool[#pool + 1] = { tg = tg, p = p, d = d } end
    end
  end
  if #pool == 0 and any then
    for _, tg in ipairs(cfg.targets) do tg.used = nil end   -- alle durch: von vorn beginnen
    return D.spawnDeepStrike(manual)
  end
  if #pool == 0 then
    if manual then msg("DEEP STRIKE: No target far enough from friendly bases.") end
    return false
  end
  local c = pool[math.random(#pool)]
  local tg, p = c.tg, c.p
  if land.getSurfaceType(p) ~= land.SurfaceType.LAND then
    local q
    for _ = 1, 40 do
      local r = jitter(p, 800)
      if land.getSurfaceType(r) == land.SurfaceType.LAND then q = r break end
    end
    if not q then
      reportError("DeepStrike", "no land near target coordinates of " .. tg.name)
      return false
    end
    p = q
  end

  local objName = nextId("DEEP")
  local kinds = { { type = tg.type, category = tg.category } }
  for _, k in ipairs(cfg.fallback) do kinds[#kinds + 1] = k end
  local placed
  for _, k in ipairs(kinds) do
    pcall(coalition.addStaticObject, D.cfg.redCountry, { name = objName, type = k.type, category = k.category,
      x = p.x, y = p.y, heading = math.random() * 2 * math.pi, canCrash = false })
    if StaticObject.getByName(objName) then placed = k.type break end
  end
  if not placed then
    reportError("DeepStrike", "could not create static target at " .. tg.name .. " – check type names in D.cfg.deepStrike")
    return false
  end

  local gname = nextId("DEEPDEF")
  local units = {}
  for i, typ in ipairs(cfg.defense) do
    local pos
    for _ = 1, 30 do
      local q = offset(p, math.random() * 2 * math.pi, randRange(cfg.defenseRadius))
      if land.getSurfaceType(q) == land.SurfaceType.LAND then pos = q break end
    end
    pos = pos or offset(p, math.random() * 2 * math.pi, cfg.defenseRadius[2])
    units[#units + 1] = { name = gname .. "-" .. i, type = typ, x = pos.x, y = pos.y,
      heading = math.random() * 2 * math.pi, skill = D.cfg.skill, playerCanDrive = false }
  end
  D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units })

  tg.used = true
  local t = { name = tg.name, obj = objName, def = gname, p = p, mark = nil }
  if D.cfg.mapMarks then
    t.mark = newMarkId()
    trigger.action.markToCoalition(t.mark, "DEEP STRIKE: " .. tg.name, toV3(p), D.cfg.blueSide, true)
  end
  D.deeps[#D.deeps + 1] = t

  local far = (c.d < math.huge) and string.format("%d km", math.floor(c.d / 1000 + 0.5)) or "n/a"
  msg(string.format("DEEP STRIKE: %s\nTarget position (exact): %s\nDistance to nearest friendly base: %s\nA single structure, defended by AAA and short-range SAM around the target. Precision-guided weapons (JDAM, laser-guided) recommended – plan a long ingress.",
    tg.name, D.fmtPos(p), far))
  return true
end

function D.requestDeepStrike() D.spawnDeepStrike(true) end

function D.reportDeepStrike()
  if #D.deeps == 0 then msg("DEEP STRIKE: No active taskings.") return end
  local lines = { "DEEP STRIKE TASKINGS:" }
  for i, t in ipairs(D.deeps) do
    lines[#lines + 1] = string.format("%d) %s\n   %s", i, t.name, D.fmtPos(t.p))
  end
  msg(table.concat(lines, "\n"))
end

function D.deepTick(now)
  local cfg = D.cfg.deepStrike
  for i = #D.deeps, 1, -1 do
    local t = D.deeps[i]
    local o = StaticObject.getByName(t.obj)
    local dead = (o == nil) or (not o:isExist())
    if not dead then
      local ok, life = pcall(function() return o:getLife() end)
      if ok and life and life < 1 then dead = true end
    end
    if dead then
      table.remove(D.deeps, i)
      D.stats.deep = D.stats.deep + 1
      if t.mark then trigger.action.removeMark(t.mark) end
      msg(string.format("DEEP STRIKE: \"%s\" destroyed! (%d total)", t.name, D.stats.deep))
      scheduleCleanup({ t.def }, cfg.cleanupAfter)
    end
  end
end

-- ----------------------------------------------------------------- Bomber abfangen
function D.bomberMark(t)
  if not D.cfg.mapMarks then return end
  local p = groupPos(t.group)
  if not p then return end
  if t.mark then trigger.action.removeMark(t.mark) end
  t.mark = newMarkId()
  t.intelPos = { x = p.x + t.offX, y = p.y + t.offY }
  trigger.action.markToCoalition(t.mark,
    string.format("BOMBERS (±%s)", fmtDist(D.cfg.bomber.intelError)), toV3(t.intelPos), D.cfg.blueSide, true)
end

local function bomberReport(t, now, header)
  local alive = aliveUnits(t.group)
  local p = groupPos(t.group)
  if #alive == 0 or not p then return end
  local d = dist(p, t.target)
  local eta = math.max(0, math.floor((d - D.cfg.bomber.releaseRange) / t.speed / 60 + 0.5))
  local ip = t.intelPos or p
  local hdg = bearingDeg(p, t.target)
  msg(string.format("%s %dx %s, heading %03d, angels %d, approx. %s\nTarget: %s airfield – bomb release in ~%d min (%.0f km to go).",
    header, #alive, t.typ, hdg, math.floor(t.alt * 3.28084 / 1000 + 0.5), bullseyeStr(ip), t.targetName, eta, d / 1000))
end

function D.spawnBomber(manual)
  local cfg = D.cfg.bomber
  if not cfg.enabled then return false end
  if #D.bombers >= cfg.maxActive then
    if manual then msg("BOMBER INTERCEPT: Maximum number of active taskings reached.") end
    return false
  end
  if #D.blueBases == 0 then
    if manual then msg("BOMBER INTERCEPT: No friendly airfield to threaten.") end
    return false
  end
  local reds = redAirbases()
  local players = playerPositions()
  local R, B, S
  for _ = 1, 80 do
    if #reds == 0 then break end
    local r = reds[math.random(#reds)]
    local b = D.blueBases[math.random(#D.blueBases)]
    local d = dist(r, b)
    if d >= cfg.distance[1] and d <= cfg.distance[2] then
      local hdg = math.atan2(b.y - r.y, b.x - r.x)
      local sp = offset(r, hdg, cfg.startOffset)
      if farFrom(sp, players, cfg.minDistPlayers) then R, B, S = r, b, sp break end
    end
  end
  if not R then
    if manual then msg("BOMBER INTERCEPT: No suitable route found – try again later.") end
    return false
  end

  local bt = cfg.types[math.random(#cfg.types)]
  local n = math.random(bt.size[1], bt.size[2])
  local hdg = math.atan2(B.y - S.y, B.x - S.x)
  local gname = nextId("BOMBER")
  local units = {}
  for i = 1, n do
    local u = offset(offset(S, hdg + math.pi, 400 * (i - 1)), hdg + math.pi / 2, 350 * (i - 1))
    units[i] = { name = gname .. "-" .. i, type = bt.type, x = u.x, y = u.y, alt = bt.alt, alt_type = "BARO",
      speed = bt.speed, heading = hdg, skill = "High",
      payload = { pylons = {}, fuel = bt.fuel, flare = 0, chaff = 0, gun = 0 } }
  end
  local tgt = { x = B.x, y = B.y }
  coalition.addGroup(D.cfg.redCountry, Group.Category.AIRPLANE, {
    name = gname, task = "Nothing", uncontrolled = false, units = units,
    route = { points = { airWP(S, bt.alt, bt.speed, {}), airWP(tgt, bt.alt, bt.speed, {}),
                         airWP(offset(tgt, hdg, 60000), bt.alt, bt.speed, {}), airWP(R, bt.alt, bt.speed, {}) } },
  })
  local alive = groupAliveCount(gname)
  if alive < n then
    reportError("Bomber", string.format("only %d of %d bombers spawned (%s) – check type names in D.cfg.bomber.types", alive, n, bt.type))
    if alive == 0 then return false end
  end
  -- Bomber reagieren nicht auf Bedrohung (kein Ausweichen/Abbruch), sonst wären sie vorzeitig weg
  timer.scheduleFunction(safe(function()
    local g = Group.getByName(gname)
    if g and g:isExist() then
      local air = AI and AI.Option and AI.Option.Air
      if air and air.id and air.val and air.val.REACTION_ON_THREAT then
        pcall(function() g:getController():setOption(air.id.REACTION_ON_THREAT, air.val.REACTION_ON_THREAT.NO_REACTION) end)
      end
    end
  end, "BomberOptions"), nil, timer.getTime() + 2)

  local off = jitter({ x = 0, y = 0 }, cfg.intelError)
  local now = timer.getTime()
  local t = { group = gname, typ = bt.type, alt = bt.alt, speed = bt.speed, initial = alive, target = tgt,
              targetName = B.name or "friendly", startName = R.name, spawned = now, offX = off.x, offY = off.y,
              nextReport = now + cfg.reportInterval, nextMark = now + cfg.markUpdate }
  D.bombers[#D.bombers + 1] = t
  D.bomberMark(t)
  bomberReport(t, now, string.format("BOMBER INTERCEPT: Hostile bombers departed %s –", R.name))
  return true
end

function D.requestBomber() D.spawnBomber(true) end

function D.reportBomber()
  if #D.bombers == 0 then msg("BOMBER INTERCEPT: No active taskings.") return end
  for _, t in ipairs(D.bombers) do bomberReport(t, timer.getTime(), "BOMBER INTERCEPT:") end
end

-- Abwurf nachstellen: eine Reihe Explosionen je lebendem Bomber über dem Zielflugplatz
local function bomberRelease(t, now)
  local cfg = D.cfg.bomber
  local units = aliveUnits(t.group)
  local delay = 0
  if cfg.bombPower and cfg.bombPower > 0 then
    for _, u in ipairs(units) do
      local up = toV2(u:getPoint())
      local hdg = math.atan2(t.target.y - up.y, t.target.x - up.x)
      local start = offset(t.target, hdg + math.pi, 300)
      for j = 0, cfg.bombs - 1 do
        local p = offset(start, hdg, cfg.bombSpacing * j)
        delay = delay + 0.4
        timer.scheduleFunction(safe(function() trigger.action.explosion(toV3(p), cfg.bombPower) end, "Bombs"),
          nil, now + delay)
      end
    end
  end
  msg(string.format("BOMBER INTERCEPT: %d bomber%s released over %s airfield! Intercept failed.",
    #units, #units == 1 and "" or "s", t.targetName))
end

function D.bomberTick(now)
  local cfg = D.cfg.bomber
  for i = #D.bombers, 1, -1 do
    local t = D.bombers[i]
    local alive = groupAliveCount(t.group)
    local verdict
    if alive == 0 then
      verdict = "success"
    else
      for _, u in ipairs(aliveUnits(t.group)) do
        if dist(toV2(u:getPoint()), t.target) <= cfg.releaseRange then verdict = "release" break end
      end
      if not verdict and now - t.spawned >= cfg.maxTime then verdict = "expired" end
    end
    if verdict then
      table.remove(D.bombers, i)
      if t.mark then trigger.action.removeMark(t.mark) end
      if verdict == "success" then
        D.stats.bomber = D.stats.bomber + 1
        msg(string.format("BOMBER INTERCEPT: All bombers destroyed before release – %s airfield is safe! (%d total)",
          t.targetName, D.stats.bomber))
      elseif verdict == "release" then
        bomberRelease(t, now)
      else
        msg("BOMBER INTERCEPT: Tasking ended.")
      end
      scheduleCleanup({ t.group }, cfg.cleanupAfter)
    else
      if now >= t.nextMark then D.bomberMark(t) t.nextMark = now + cfg.markUpdate end
      if now >= t.nextReport then bomberReport(t, now, "BOMBER INTERCEPT UPDATE:") t.nextReport = now + cfg.reportInterval end
    end
  end
end

-- ----------------------------------------------------------------- Troops in Contact (TIC) + JTAC
local smokeColors = { green = "Green", orange = "Orange", white = "White", red = "Red", blue = "Blue" }

local function ticUnitPos(t)
  local u = aliveUnits(t.friend)[1]
  return u, u and toV2(u:getPoint()) or t.p
end

local function ticEnemies(t)
  local out = {}
  for _, gname in ipairs(t.enemies) do
    for _, u in ipairs(aliveUnits(gname)) do out[#out + 1] = u end
  end
  return out
end

local function nearestEnemy(t)
  local _, fp = ticUnitPos(t)
  local best, bd = nil, math.huge
  for _, u in ipairs(ticEnemies(t)) do
    local d = dist(toV2(u:getPoint()), fp)
    if d < bd then best, bd = u, d end
  end
  return best, bd
end

function D.ticSmoke(t, color, auto)
  local _, fp = ticUnitPos(t)
  local p = offset(fp, math.random() * 2 * math.pi, 15)
  trigger.action.smoke(toV3(p), trigger.smokeColor[smokeColors[color]])
  if not auto then msg(string.format("JTAC: Friendlies popping %s smoke.", color)) end
end

function D.ticStrobe(t, on)
  if t.ir then pcall(function() t.ir:destroy() end) t.ir = nil end
  if not on then return end
  local u = aliveUnits(t.friend)[1]
  if not u then return end
  local pt = u:getPoint()
  local ok, spot = pcall(Spot.createInfraRed, u, { x = 0, y = 2, z = 0 }, { x = pt.x + 30, y = pt.y + 2, z = pt.z })
  if ok and spot then t.ir = spot t.irUnit = u:getName()
  else reportError("TIC", "could not create IR pointer: " .. tostring(spot)) end
end

function D.ticMarkFriendly(color)
  local t = D.tics[1]
  if not t then msg("JTAC: No troops in contact tasking active.") return end
  D.ticSmoke(t, color, false)
end

function D.ticToggleStrobe()
  local t = D.tics[1]
  if not t then msg("JTAC: No troops in contact tasking active.") return end
  D.ticStrobe(t, not t.ir)
  msg(t.ir and "JTAC: Friendlies IR strobe ON (visible with NVG/NVD)." or "JTAC: Friendlies IR strobe OFF.")
end

function D.ticMarkEnemy()
  local t = D.tics[1]
  if not t then msg("JTAC: No troops in contact tasking active.") return end
  local u = nearestEnemy(t)
  if not u then msg("JTAC: No enemy in sight.") return end
  trigger.action.smoke(toV3(toV2(u:getPoint())), trigger.smokeColor.Red)
  msg("JTAC: Nearest enemy marked with RED smoke.")
end

function D.ticLase()
  local t = D.tics[1]
  if not t then msg("JTAC: No troops in contact tasking active.") return end
  if t.laser then
    pcall(function() t.laser:destroy() end)
    t.laser, t.laserUnit = nil, nil
    msg("JTAC: Laser off.")
    return
  end
  local src = aliveUnits(t.friend)[1]
  local tgt = nearestEnemy(t)
  if not src or not tgt then msg("JTAC: No target to lase.") return end
  local ok, spot = pcall(Spot.createLaser, src, { x = 0, y = 2, z = 0 }, tgt:getPoint(), D.cfg.tic.laserCode)
  if not ok or not spot then reportError("TIC", "could not create laser spot: " .. tostring(spot)) return end
  t.laser, t.laserUnit = spot, tgt:getName()
  msg(string.format("JTAC: Laser on target, code %d.", D.cfg.tic.laserCode))
  if not D.laserRunning then
    D.laserRunning = true
    timer.scheduleFunction(function(_, now)
      local ok2, nxt = pcall(D.laserTick, now)
      if ok2 and nxt then return nxt end
      D.laserRunning = false
      return nil
    end, nil, timer.getTime() + 1)
  end
end

function D.laserTick(now)
  local any = false
  for _, t in ipairs(D.tics) do
    if t.laser then
      local u = t.laserUnit and Unit.getByName(t.laserUnit)
      if not (u and u:isExist() and u:getLife() >= 1) then
        u = nearestEnemy(t)
        t.laserUnit = u and u:getName() or nil
        if u then msg("JTAC: Target destroyed – shifting laser to the next target.") end
      end
      if u then
        pcall(function() t.laser:setPoint(u:getPoint()) end)
        any = true
      else
        pcall(function() t.laser:destroy() end)
        t.laser = nil
        msg("JTAC: No more targets – laser off.")
      end
    end
  end
  if any then return now + 1 end
  return nil
end

function D.reportTic()
  if #D.tics == 0 then msg("JTAC: No troops in contact tasking active.") return end
  local lines = {}
  for _, t in ipairs(D.tics) do
    local _, fp = ticUnitPos(t)
    local enemies = ticEnemies(t)
    local best, bd = nearestEnemy(t)
    lines[#lines + 1] = string.format("JTAC SITREP – TROOPS IN CONTACT\nFriendlies: %d/%d, %s\n   Marked: %s%s\nEnemy: %d remaining (wave %d/%d)",
      groupAliveCount(t.friend), t.friendInitial, D.fmtPos(fp),
      t.autoMarked and "smoke" or "not yet marked", t.ir and " + IR strobe" or "",
      #enemies, t.waves, D.cfg.tic.waves)
    if best then
      local bp = toV2(best:getPoint())
      lines[#lines + 1] = string.format("Nearest enemy: %s, bearing %03d, %.1f km from friendlies\n   %s\n   Mark: ask for red smoke or laser code %d",
        best:getTypeName(), bearingDeg(fp, bp), bd / 1000, D.fmtPos(bp), D.cfg.tic.laserCode)
    else
      lines[#lines + 1] = "No enemy in sight."
    end
  end
  msg(table.concat(lines, "\n"))
end

-- Ort für Troops in Contact: Editor-Zone "TIC*" oder automatisch abseits der AOs und SAMs
function D.findTicSpot()
  local cfg = D.cfg.tic
  local players = playerPositions()

  if D.ticZones == nil then
    D.ticZones = {}
    local mz = env.mission and env.mission.triggers and env.mission.triggers.zones or {}
    for _, z in pairs(mz) do
      if type(z) == "table" and z.name and z.name:sub(1, #cfg.zonePrefix) == cfg.zonePrefix then
        local tz = trigger.misc.getZone(z.name)
        if tz and tz.radius and tz.radius > 0 then
          D.ticZones[#D.ticZones + 1] = { name = z.name, x = tz.point.x, y = tz.point.z, radius = tz.radius }
        end
      end
    end
  end
  if #D.ticZones > 0 then
    for _ = 1, 60 do
      local z = D.ticZones[math.random(#D.ticZones)]
      local p = randomPointInZone(z, 300)
      if okGround(p) and farFrom(p, players, 3000) then return p, z.name end
    end
  end

  if #D.blueBases == 0 then return nil end
  for pass = 1, 2 do
    local samClear = (pass == 1) and cfg.samClearance or cfg.samClearanceMin
    local aoMargin = (pass == 1) and cfg.aoMargin or 0
    for _ = 1, 150 do
      local b = D.blueBases[math.random(#D.blueBases)]
      local p = offset(b, math.random() * 2 * math.pi, randRange(cfg.baseDistance))
      local clear = okGround(p) and farFrom(p, players, 3000)
      if clear then
        for _, ao in ipairs(D.aos) do
          if dist(p, ao) < ao.radius + aoMargin then clear = false break end
        end
      end
      if clear then
        for _, st in ipairs(D.sites) do
          if dist(p, st.pos) < samClear then clear = false break end
        end
      end
      if clear then return p, (b.name and ("near " .. b.name)) or "friendly area" end
    end
  end
  return nil
end

function D.spawnTicWave(t)
  local cfg = D.cfg.tic
  local tpl = cfg.waveTemplates[math.random(#cfg.waveTemplates)]
  local sp
  for _ = 1, 40 do
    local a = t.axis + (math.random() - 0.5) * math.rad(40)
    local q = offset(t.p, a, randRange(cfg.spawnDistance))
    if okGround(q) then sp = q break end
  end
  if not sp then
    reportError("TIC", "no ground found for the enemy wave")
    return false
  end
  local hdg = math.atan2(t.p.y - sp.y, t.p.x - sp.x)
  local gname = nextId("TICE")
  local units = {}
  for i, typ in ipairs(tpl) do
    local u = offset(sp, hdg + math.pi / 2, (i - (#tpl + 1) / 2) * 25)
    units[i] = { name = gname .. "-" .. i, type = typ, x = u.x, y = u.y, heading = hdg,
                 skill = D.cfg.skill, playerCanDrive = false }
  end
  local function wp(p)
    return { x = p.x, y = p.y, type = "Turning Point", action = "Off Road", speed = cfg.enemySpeed,
             speed_locked = true, ETA = 0, ETA_locked = false, task = emptyTask() }
  end
  D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units, route = { points = { wp(sp), wp(offset(t.p, hdg + math.pi, 150)) } } })
  local alive = groupAliveCount(gname)
  if alive < #tpl then
    reportError("TIC", string.format("only %d of %d enemy units spawned – check type names in D.cfg.tic.waveTemplates", alive, #tpl))
    if alive == 0 then return false end
  end
  t.enemies[#t.enemies + 1] = gname
  t.enemyInitial = t.enemyInitial + alive
  t.waves = t.waves + 1
  t.nextWave = timer.getTime() + cfg.waveInterval
  msg(string.format("JTAC: Wave %d/%d – %d enemy vehicles/troops advancing on our position from bearing %03d, %.1f km out.",
    t.waves, cfg.waves, alive, bearingDeg(t.p, sp), dist(t.p, sp) / 1000))
  return true
end

function D.spawnTic(manual)
  local cfg = D.cfg.tic
  if not cfg.enabled then return false end
  if #D.tics >= cfg.maxActive then
    if manual then msg("TIC: Maximum number of active taskings reached.") end
    return false
  end
  local p, area = D.findTicSpot()
  if not p then
    if manual then msg("TIC: No safe area found away from the SAM zones – try again later.") end
    return false
  end

  local gname = nextId("TICF")
  local units = {}
  for i, typ in ipairs(cfg.friendlies) do
    local u = offset(p, math.random() * 2 * math.pi, 15 + math.random() * 50)
    units[i] = { name = gname .. "-" .. i, type = typ, x = u.x, y = u.y, heading = math.random() * 2 * math.pi,
                 skill = "High", playerCanDrive = false }
  end
  D.addGround(D.cfg.blueCountry, { name = gname, task = "Ground Nothing", units = units })
  local alive = groupAliveCount(gname)
  if alive < #cfg.friendlies then
    reportError("TIC", string.format("only %d of %d friendly units spawned – check type names in D.cfg.tic.friendlies", alive, #cfg.friendlies))
    if alive == 0 then return false end
  end

  local sz = { x = p.x, y = p.y, r = cfg.keepClear }
  D.safeZones[#D.safeZones + 1] = sz
  local t = { friend = gname, friendInitial = alive, p = p, area = area, sz = sz, axis = math.random() * 2 * math.pi,
              waves = 0, enemies = {}, enemyInitial = 0, started = timer.getTime(), nextWave = timer.getTime() + 60 }
  D.tics[#D.tics + 1] = t
  if D.cfg.mapMarks then
    t.mark = newMarkId()
    trigger.action.markToCoalition(t.mark, "TROOPS IN CONTACT (friendlies)", toV3(p), D.cfg.blueSide, true)
  end
  msg(string.format("TROOPS IN CONTACT [%s]: Friendly ground forces (%d) are holding a position and expect an enemy attack in minutes.\nPosition: %s\nNo SAM threat reported in the area, light AAA and MANPADS possible. Best suited for A-10C and AH-64D.\nThey will mark with smoke and IR strobe when you are close (or use the F10 menu: Side Missions > JTAC). Destroy the attacking enemy forces in %d waves. Watch for danger close.",
    area or "friendly area", alive, D.fmtPos(p), cfg.waves))
  return true
end

function D.requestTic() D.spawnTic(true) end

function D.ticTick(now, players)
  local cfg = D.cfg.tic
  for i = #D.tics, 1, -1 do
    local t = D.tics[i]
    if t.waves < cfg.waves and now >= t.nextWave then D.spawnTicWave(t) end

    local fAlive = groupAliveCount(t.friend)
    local eAlive = #ticEnemies(t)

    if not t.autoMarked then
      for _, q in ipairs(players) do
        if dist(q, t.p) < cfg.autoMarkRange then
          t.autoMarked = true
          D.ticSmoke(t, "green", true)
          D.ticStrobe(t, true)
          msg("JTAC: Friendlies marking position with GREEN smoke and IR strobe. Confirm visual.")
          break
        end
      end
    end
    if t.ir and t.irUnit then
      local u = Unit.getByName(t.irUnit)
      if not (u and u:isExist() and u:getLife() >= 1) then D.ticStrobe(t, true) end
    end

    local verdict
    if (1 - fAlive / t.friendInitial) * 100 >= cfg.lossPercent then
      verdict = "lost"
    elseif t.waves >= cfg.waves and eAlive <= math.floor(t.enemyInitial * (1 - cfg.successPercent / 100)) then
      verdict = "success"
    elseif now - t.started >= cfg.maxTime then
      verdict = "expired"
    end
    if verdict then
      table.remove(D.tics, i)
      if t.mark then trigger.action.removeMark(t.mark) end
      for k, sz in ipairs(D.safeZones) do
        if sz == t.sz then table.remove(D.safeZones, k) break end
      end
      if t.ir then pcall(function() t.ir:destroy() end) end
      if t.laser then pcall(function() t.laser:destroy() end) end
      if verdict == "success" then
        D.stats.tic = D.stats.tic + 1
        msg(string.format("JTAC: Enemy attack defeated, friendlies hold the position. Good work! (%d total)", D.stats.tic))
      elseif verdict == "lost" then
        msg("JTAC: Friendly position overrun. Tasking failed.")
      else
        msg("JTAC: Situation stabilised, friendlies are withdrawing. Tasking ended.")
      end
      local list = { t.friend }
      for _, g in ipairs(t.enemies) do list[#list + 1] = g end
      scheduleCleanup(list, cfg.cleanupAfter)
    end
  end
end

-------------------------------------------------------------------------------
-- FRONTLINE BATTLE: KI-gegen-KI-Panzerschlacht nahe einer feindlichen Basis
-------------------------------------------------------------------------------
local function battleWP(p)
  return { x = p.x, y = p.y, type = "Turning Point", action = "Off Road", speed = D.cfg.battle.speed,
           speed_locked = true, ETA = 0, ETA_locked = false, task = emptyTask() }
end

-- Gruppe vorrücken lassen und Feuer frei (bzw. warten mit Feuer halten)
local function battleGo(gname, dest, go)
  local g = Group.getByName(gname)
  if not g or not g:isExist() then return end
  local c = g:getController()
  pcall(function()
    c:setOption(AI.Option.Ground.id.ROE, go and AI.Option.Ground.val.ROE.OPEN_FIRE or AI.Option.Ground.val.ROE.WEAPON_HOLD)
  end)
  if go and dest then
    local cur = groupPos(gname)
    if cur then
      pcall(function() c:setTask({ id = "Mission", params = { route = { points = { battleWP(cur), battleWP(dest) } } } }) end)
    end
  end
end

-- Eine Seite (oder eine Welle mit nGroups Gruppen) spawnen; go = sofort vorrücken
function D.spawnBattleSide(bt, blue, center, axisSign, nGroups, back, go)
  local cfg = D.cfg.battle
  local types = blue and cfg.blueUnits or cfg.redUnits
  local country = blue and D.cfg.blueCountry or D.cfg.redCountry
  nGroups = nGroups or math.max(1, math.floor((blue and cfg.bluePerSide or cfg.redPerSide) / cfg.groupSize))
  local linePos = offset(center, bt.axis, axisSign * (bt.gap / 2 + (back or 0)))
  local hdg = bt.axis + (axisSign > 0 and math.pi or 0)   -- Blick zum Gegner
  local dest = offset(center, bt.axis, -axisSign * 150)   -- bis knapp hinter die Mitte
  local names = {}
  for g = 1, nGroups do
    local gname = nextId(blue and "BATB" or "BATR")
    local units = {}
    local gc = offset(linePos, bt.axis + math.pi / 2, (g - (nGroups + 1) / 2) * (cfg.groupSize * cfg.lineSpacing / 2 + 60))
    for i = 1, cfg.groupSize do
      local typ = types[((i - 1) % #types) + 1]
      local row, col = math.floor((i - 1) / 3), (i - 1) % 3
      local q = offset(offset(gc, bt.axis + math.pi / 2, (col - 1) * cfg.lineSpacing), bt.axis, -axisSign * row * 40)
      if not okGround(q) then q = jitter(gc, 200) end
      units[#units + 1] = { name = gname .. "-" .. i, type = typ, x = q.x, y = q.y, heading = hdg,
                            skill = blue and cfg.blueSkill or cfg.redSkill, playerCanDrive = false }
    end
    local d = offset(dest, bt.axis + math.pi / 2, (g - (nGroups + 1) / 2) * (cfg.groupSize * cfg.lineSpacing / 2 + 60))
    D.addGround(country, { name = gname, task = "Ground Nothing",
      hidden = (not blue) and D.hideOnMap() or nil, units = units,
      route = { points = go and { battleWP(gc), battleWP(d) } or { battleWP(gc) } } })
    local alive = groupAliveCount(gname)
    if alive < #units then
      reportError("BATTLE", string.format("only %d of %d units spawned in %s – check D.cfg.battle unit types", alive, #units, gname))
    end
    if alive > 0 then
      names[#names + 1] = gname
      bt.dest[gname] = d
      battleGo(gname, nil, go)
    end
  end
  return names
end

local function battleCount(list)
  local n = 0
  for _, g in ipairs(list) do n = n + groupAliveCount(g) end
  return n
end

function D.spawnBattle(manual)
  local cfg = D.cfg.battle
  if not cfg.enabled then return false end
  if #D.battles >= cfg.maxActive then
    if manual then msg("BATTLE: A battle is already in progress.") end
    return false
  end
  -- Ort: bevorzugt eine aktive AO (Ziel-Flugplatz), sonst die feindlichen Flugplätze, die einer blauen Basis am nächsten sind
  local bases = {}
  for _, ao in ipairs(D.aos) do
    if ao.state == "active" and not ao.fortress then bases[#bases + 1] = { x = ao.x, y = ao.y, name = ao.name } end
  end
  if #bases == 0 then
    D.refreshBlueBases()
    local all = redAirbases()
    for _, b in ipairs(all) do
      b.d = math.huge
      for _, bb in ipairs(D.blueBases) do b.d = math.min(b.d, dist(b, bb)) end
    end
    table.sort(all, function(a, b) return a.d < b.d end)
    for i = 1, math.min(cfg.nearestBases, #all) do bases[#bases + 1] = all[i] end
  end
  if #bases == 0 then
    if manual then msg("BATTLE: No enemy airfield available.") end
    return false
  end
  local players = playerPositions()
  local center, base, axis, gap
  for _ = 1, 120 do
    local b = bases[math.random(#bases)]
    local c = offset(b, math.random() * 2 * math.pi, randRange(cfg.baseDistance))
    local a = math.random() * 2 * math.pi
    local g = randRange(cfg.gap)
    local ok = land.getSurfaceType(c) == land.SurfaceType.LAND and farFrom(c, players, 5000)
    if ok then
      for _, q in ipairs({ c, offset(c, a, g / 2), offset(c, a, -g / 2) }) do
        if not okGround(q) then ok = false break end
      end
    end
    if ok then center, base, axis, gap = c, b, a, g break end
  end
  if not center then
    if manual then msg("BATTLE: No suitable flat ground found – try again later.") end
    return false
  end

  local bt = { axis = axis, gap = gap, center = center, area = base.name, created = timer.getTime(), lastNear = timer.getTime(),
              dest = {}, active = false, waves = { blue = 0, red = 0 }, lastWave = { blue = -math.huge, red = -math.huge } }
  bt.blue = D.spawnBattleSide(bt, true, center, -1)
  bt.red = D.spawnBattleSide(bt, false, center, 1)
  bt.blueInitial, bt.redInitial = battleCount(bt.blue), battleCount(bt.red)
  if bt.blueInitial == 0 or bt.redInitial == 0 then
    reportError("BATTLE", "a side did not spawn at all – check the type names in D.cfg.battle")
    for _, g in ipairs(bt.blue) do destroyGroup(g) end
    for _, g in ipairs(bt.red) do destroyGroup(g) end
    return false
  end
  D.battles[#D.battles + 1] = bt
  if D.cfg.mapMarks then
    bt.mark = newMarkId()
    trigger.action.markToCoalition(bt.mark, "FRONTLINE BATTLE", toV3(center), D.cfg.blueSide, true)
  end
  bt.blueBase, bt.redBase = bt.blueInitial, bt.redInitial
  msg(string.format("FRONTLINE BATTLE near %s: Allied armor (%d vehicles) is facing an enemy force (%d vehicles), both sides are holding.\nThe attack begins as soon as friendly aircraft are within %d km. More waves will follow while you support the fight – tip the balance with CAS.\nPosition: %s\nExpect AAA (ZSU-23-4) with the enemy and MANPADS around the enemy airfield.",
    base.name or "enemy airfield", bt.blueInitial, bt.redInitial, math.floor(cfg.activateRange / 1000), D.fmtPos(center)))
  return true
end

function D.requestBattle() D.spawnBattle(true) end

function D.reportBattle()
  if #D.battles == 0 then msg("BATTLE: No frontline battle in progress.") return end
  for _, bt in ipairs(D.battles) do
    local cfg = D.cfg.battle
    msg(string.format("FRONTLINE BATTLE near %s – %s:\nAllies: %d vehicles left (reinforcement waves left: %d)\nEnemy: %d vehicles left (reinforcement waves left: %d)\n%s",
      bt.area or "enemy airfield", bt.active and "fighting" or ("holding until friendly aircraft are within " .. math.floor(cfg.activateRange / 1000) .. " km"),
      battleCount(bt.blue), cfg.waves - bt.waves.blue, battleCount(bt.red), cfg.waves - bt.waves.red, D.fmtPos(bt.center)))
  end
end

local function battleEnd(bt, verdict, b, r)
  local cfg = D.cfg.battle
  if bt.mark then trigger.action.removeMark(bt.mark) end
  if verdict == "won" then
    D.stats.battle = D.stats.battle + 1
    msg(string.format("FRONTLINE BATTLE near %s: The enemy force is broken, allied armor holds the field (%d vehicles left). (%d won)",
      bt.area or "enemy airfield", b, D.stats.battle))
  elseif verdict == "lost" then
    msg(string.format("FRONTLINE BATTLE near %s: Allied armor was destroyed. The enemy holds the field (%d vehicles left).",
      bt.area or "enemy airfield", r))
  elseif verdict == "idle" then
    msg(string.format("FRONTLINE BATTLE near %s: No air support arrived, the forces have withdrawn.", bt.area or "enemy airfield"))
  else
    msg(string.format("FRONTLINE BATTLE near %s: The fighting has died down. Allies %d, enemy %d vehicles left.",
      bt.area or "enemy airfield", b, r))
  end
  local list = {}
  for _, g in ipairs(bt.blue) do list[#list + 1] = g end
  for _, g in ipairs(bt.red) do list[#list + 1] = g end
  scheduleCleanup(list, verdict == "idle" and 1 or cfg.cleanupAfter)
end

function D.battleTick(now)
  local cfg = D.cfg.battle
  local players = playerPositions()
  for i = #D.battles, 1, -1 do
    local bt = D.battles[i]
    local near = not farFrom(bt.center, players, cfg.activateRange)
    if near then bt.lastNear = now end

    if not bt.active then
      -- Warten, bis ein Spieler in der Nähe ist
      if near then
        bt.active, bt.started = true, now
        for _, list in ipairs({ bt.blue, bt.red }) do
          for _, gn in ipairs(list) do battleGo(gn, bt.dest[gn], true) end
        end
        msg(string.format("FRONTLINE BATTLE near %s: Friendly aircraft on station – the attack has begun!", bt.area or "enemy airfield"))
      elseif now - bt.lastNear >= cfg.idleTime then
        table.remove(D.battles, i)
        battleEnd(bt, "idle", 0, 0)
      end
    else
      local b, r = battleCount(bt.blue), battleCount(bt.red)
      -- Verstärkungswellen, solange ein Spieler in der Nähe ist
      for _, side in ipairs({ "blue", "red" }) do
        local alive = (side == "blue") and b or r
        local base = (side == "blue") and bt.blueBase or bt.redBase
        if near and bt.waves[side] < cfg.waves and alive < base * cfg.waveBelow / 100
           and now - bt.lastWave[side] >= cfg.waveCooldown then
          local blue = side == "blue"
          local names = D.spawnBattleSide(bt, blue, bt.center, blue and -1 or 1, cfg.waveGroups, cfg.waveBack, true)
          local list = blue and bt.blue or bt.red
          for _, gn in ipairs(names) do list[#list + 1] = gn end
          bt.waves[side] = bt.waves[side] + 1
          bt.lastWave[side] = now
          msg(string.format("FRONTLINE BATTLE near %s: %s reinforcements are moving up (wave %d of %d).",
            bt.area or "enemy airfield", blue and "Allied" or "Enemy", bt.waves[side], cfg.waves))
        end
      end
      b, r = battleCount(bt.blue), battleCount(bt.red)
      local keep = (100 - cfg.endPercent) / 100
      local verdict
      if bt.waves.red >= cfg.waves and r <= bt.redBase * keep then verdict = "won"
      elseif bt.waves.blue >= cfg.waves and b <= bt.blueBase * keep then verdict = "lost"
      elseif not near and r == 0 then verdict = "won"
      elseif not near and b == 0 then verdict = "lost"
      elseif now - bt.started >= cfg.maxTime then verdict = "draw" end
      if verdict then
        table.remove(D.battles, i)
        battleEnd(bt, verdict, b, r)
      end
    end
  end
end

-------------------------------------------------------------------------------
-- HAUPTMISSION: FEINDLICHE HAUPTBASIS mit dichtem, gestaffeltem Luftverteidigungsnetz
-------------------------------------------------------------------------------
function D.fortressSitesLeft()
  local n = 0
  if not D.fortress then return 0 end
  for _, st in ipairs(D.sites) do if st.ao == D.fortress.ao then n = n + 1 end end
  return n
end

-- Hauptbasis beim Kampagnenstart reservieren: aus dem normalen Ziel-Pool nehmen, aber noch nicht aktivieren
function D.reserveFortress()
  local cfg = D.cfg.fortress
  if not cfg.enabled or D.fortressBase then return end
  D.refreshBlueBases()
  local list = {}
  for _, name in ipairs(D.targetPool) do
    local ab = Airbase.getByName(name)
    if ab then
      local p = toV2(ab:getPoint())
      local d = math.huge
      for _, b in ipairs(D.blueBases) do d = math.min(d, dist(p, b)) end
      list[#list + 1] = { name = name, d = d }
    end
  end
  table.sort(list, function(a, b) return a.d > b.d end)
  local n = math.min(cfg.candidates, #list)
  if n == 0 then return end
  local c = list[math.random(n)]
  for i, name in ipairs(D.targetPool) do
    if name == c.name then table.remove(D.targetPool, i) break end
  end
  D.fortressBase = c.name
  D.fortressName = c.name
  env.info("DynSEAD: main base reserved: " .. c.name)
end

function D.activateFortress(manual)
  local cfg = D.cfg.fortress
  if not cfg.enabled then return false end
  if D.fortress then
    if manual then msg("MAIN BASE: The enemy main base is already active.") end
    return false
  end
  if not D.fortressBase then D.reserveFortress() end
  local ab = D.fortressBase and Airbase.getByName(D.fortressBase)
  if not ab then
    if manual then msg("MAIN BASE: No enemy airfield left to serve as main base.") end
    return false
  end
  local c = { name = D.fortressBase, p = toV2(ab:getPoint()) }
  D.fortressBase = nil

  local total = 0
  for _, l in ipairs(cfg.layers) do total = total + l.count end
  local ao = { name = "MAIN BASE " .. c.name, airbase = c.name, x = c.p.x, y = c.p.y, radius = cfg.radius,
    samLeft = total, casLeft = 0, samActive = 0, casActive = 0, state = "fortress", fortress = true }
  drawAO(ao)

  local placed, built, kinds = {}, 0, {}
  for _, layer in ipairs(cfg.layers) do
    for _ = 1, layer.count do
      local p
      for pass = 1, 2 do
        for _ = 1, 150 do
          local q = offset(c.p, math.random() * 2 * math.pi, randRange(layer.dist))
          if pass == 1 then q = D.nearRoad(q, 1500) end
          local ok = q and ((pass == 1) and okGround(q) or (land.getSurfaceType(q) == land.SurfaceType.LAND))
          if ok and farFrom(q, placed, layer.sep * ((pass == 1) and 1 or 0.5)) and (pass ~= 1 or D.samSpotClear(q)) then p = q break end
        end
        if p then break end
      end
      if p then
        placed[#placed + 1] = p
        D.createSam(ao, layer.key, p, "always")   -- Hauptbasis: alle Radare strahlen dauerhaft
        built = built + 1
        kinds[layer.key] = (kinds[layer.key] or 0) + 1
      else
        ao.samLeft = ao.samLeft - 1
      end
    end
  end

  local groups = {}
  local function ring(types, rmin, rmax, prefix)
    local gname = nextId(prefix)
    local units = {}
    for i, typ in ipairs(types) do
      local pos
      for _ = 1, 40 do
        local q = offset(c.p, math.random() * 2 * math.pi, rmin + math.random() * (rmax - rmin))
        if land.getSurfaceType(q) == land.SurfaceType.LAND then pos = q break end
      end
      pos = pos or offset(c.p, math.random() * 2 * math.pi, rmax)
      units[#units + 1] = { name = gname .. "-" .. i, type = typ, x = pos.x, y = pos.y,
        heading = math.random() * 2 * math.pi, skill = D.cfg.skill, playerCanDrive = false }
    end
    D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units })
    groups[#groups + 1] = gname
  end
  if #cfg.ewr > 0 then ring(cfg.ewr, 1500, 5000, "FORT-EWR") end
  if #cfg.guards > 0 then ring(cfg.guards, 300, 1800, "FORT-AAA") end
  if cfg.garrison then D.spawnGarrison(ao) end
  if cfg.manpads then D.spawnManpadsZones(ao) end

  D.fortress = { name = c.name, ao = ao, groups = groups, total = built, state = "active", started = timer.getTime() }
  local parts = {}
  for _, l in ipairs(cfg.layers) do
    if kinds[l.key] then parts[#parts + 1] = string.format("%dx %s", kinds[l.key], D.samTypes[l.key].name) end
  end
  msg(string.format("MAIN BASE: Enemy main base %s is operating an integrated, layered air defense network.\n%s, plus early-warning radar and AAA. All radars are emitting.\nPosition: %s\nThe threat stays active until every SAM site is destroyed. Plan SEAD carefully, long-range systems cover a wide area around the base.",
    c.name, table.concat(parts, ", "), D.fmtPos(c.p)))
  return true
end

function D.checkFortress()
  local cfg = D.cfg.fortress
  if cfg.enabled and not D.fortress and cfg.unlockAfter > 0 and D.capturedCount >= cfg.unlockAfter then
    D.activateFortress(false)
  end
end

function D.fortressTick(now)
  local f = D.fortress
  if not f or f.state ~= "active" then return end
  if D.fortressSitesLeft() > 0 then return end
  f.state = "done"
  local ab = Airbase.getByName(f.name)
  if ab then
    ab:setCoalition(D.cfg.blueSide)
    pcall(function() ab:autoCapture(false) end)
  end
  if f.ao.garrison then destroyGroup(f.ao.garrison) end
  D.clearManpads(f.ao)
  if f.ao.drawId then trigger.action.removeMark(f.ao.drawId) end
  scheduleCleanup(f.groups, D.cfg.sam.cleanupAfter)
  D.capturedCount = D.capturedCount + 1
  D.stats.fortress = D.stats.fortress + 1
  D.captured[#D.captured + 1] = { name = f.name }
  D.fortressName = nil
  D.refreshBlueBases()
  msg(string.format("MAIN BASE: The air defense network of %s is destroyed! The airfield is now under BLUE control. (%d/%d captured)%s",
    f.name, D.capturedCount, D.targetsTotal, D.saveNote()))
  D.saveProgress()
  D.activateNext()
  D.repositionAwacs()
  D.repositionTankers()
end

function D.fortressStatus()
  if not D.fortress or D.fortress.state ~= "active" then
    local cfg = D.cfg.fortress
    if D.fortress then return "MAIN BASE: " .. D.fortress.name .. " neutralized." end
    if cfg.unlockAfter == 0 then return "MAIN BASE: not yet revealed – the enemy main base becomes active once all other airfields are captured." end
    return string.format("MAIN BASE: not yet revealed (unlocks after %d captured airfields, %d so far).", cfg.unlockAfter, D.capturedCount)
  end
  return string.format("MAIN BASE: %s – %d of %d SAM sites remaining.", D.fortress.name, D.fortressSitesLeft(), D.fortress.total)
end

-------------------------------------------------------------------------------
-- KAMPAGNE (Flugplätze)
-------------------------------------------------------------------------------
function D.spawnGarrison(ao)
  local center = { x = ao.x, y = ao.y }
  local gname = nextId("GARRISON")
  local units = {}
  for i, t in ipairs(D.garrisonUnits) do
    local pos
    for _ = 1, 40 do
      local q = offset(center, math.random() * 2 * math.pi, 300 + math.random() * 1200)
      if land.getSurfaceType(q) == land.SurfaceType.LAND then pos = q break end
    end
    pos = pos or offset(center, math.random() * 2 * math.pi, 1500)
    units[#units + 1] = { name = gname .. "-" .. i, type = t, x = pos.x, y = pos.y,
      heading = math.random() * 2 * math.pi, skill = D.cfg.skill, playerCanDrive = false }
  end
  D.addGround(D.cfg.redCountry, { name = gname, task = "Ground Nothing", hidden = D.hideOnMap(), units = units })
  ao.garrison = gname
  ao.garrisonInit = #units
  ao.garrisonDone = false
end

function D.nextTarget(front)
  D.refreshBlueBases()
  local from = (front and #front.pos > 0) and front.pos or D.blueBases
  local best, bestD, bestIdx = nil, math.huge, nil
  local maxD = D.cfg.campaign.maxDistance
  local sep = D.cfg.campaign.aoSeparation or 0
  for i, name in ipairs(D.targetPool) do
    local ab = Airbase.getByName(name)
    if ab then
      local p = toV2(ab:getPoint())
      local d = math.huge
      for _, b in ipairs(from) do d = math.min(d, dist(p, b)) end
      local apart = true   -- Kreise bereits aktiver AOs (auch im Abschluss) dürfen nicht überlappen
      for _, ao in ipairs(D.aos) do
        if dist(p, ao) < sep then apart = false break end
      end
      if D.fortress and D.fortress.state == "active" and dist(p, D.fortress.ao) < sep then apart = false end
      if apart and (maxD <= 0 or d <= maxD) and d < bestD then best, bestD, bestIdx = name, d, i end
    end
  end
  if bestIdx then table.remove(D.targetPool, bestIdx) end
  return best
end

function D.activateAirbaseAO(name, front)
  local c = D.cfg.campaign
  local ab = Airbase.getByName(name)
  if not ab then return end
  local p = toV2(ab:getPoint())
  local ao = {
    name = name, airbase = name, x = p.x, y = p.y, radius = c.aoRadius,
    samLeft = math.random(c.samPerAO[1], c.samPerAO[2]),
    casLeft = math.random(c.casPerAO[1], c.casPerAO[2]),
    samActive = 0, casActive = 0, state = "active", front = front,
  }
  local aaa = D.cfg.sam.aaa
  if aaa and math.random() < aaa.chance then
    ao.aaaKey = weighted(aaa.pool)
    ao.samLeft = ao.samLeft + 1
  end
  if c.garrison then D.spawnGarrison(ao) end
  drawAO(ao)
  D.addAOWaypoint(ao)
  D.aos[#D.aos + 1] = ao

  local now = timer.getTime()
  D.nextSam = math.min(D.nextSam, now + 10)
  D.nextCas = math.min(D.nextCas, now + (D.cfg.cas.spawnAll and 5 or D.cfg.cas.firstDelay))

  D.say({ "new_objective", tPlace(name), "airfield", tBE(p) })
  msg(string.format("NEW OBJECTIVE%s: %s airfield\nDestroy: %d SAM site(s), %d CAS target(s)%s\nPosition: %s",
    front and (" (" .. front.name .. " front)") or "", name, ao.samLeft, ao.casLeft,
    ao.garrison and ", airfield garrison" or "", D.fmtPos(p)))
  D.spawnManpadsZones(ao)
end

function D.activateNext()
  if D.fronts then
    for _, f in ipairs(D.fronts) do
      local n = 0
      for _, ao in ipairs(D.aos) do if ao.front == f then n = n + 1 end end
      while n < f.active do
        local name = D.nextTarget(f)
        if not name then break end
        D.activateAirbaseAO(name, f)
        n = n + 1
      end
    end
  else
    while #D.aos < D.cfg.campaign.activeTargets do
      local name = D.nextTarget()
      if not name then break end
      D.activateAirbaseAO(name)
    end
  end
  if #D.aos == 0 then
    if D.fortress and D.fortress.state == "active" then
      msg("Only the enemy main base remains – destroy its air defense network!")
    elseif #D.targetPool == 0 and D.fortressBase and not D.fortress and D.cfg.fortress.unlockAfter == 0 then
      msg("All outlying airfields are secured. The enemy has fallen back to its main base!")
      D.activateFortress(false)
    elseif #D.targetPool == 0 then
      msg("CAMPAIGN COMPLETE – all airfields captured! Outstanding work.")
    else
      msg("No reachable objectives left (check campaign.maxDistance).")
    end
  end
end

function D.captureAO(ao)
  local ab = Airbase.getByName(ao.airbase)
  if ab then
    ab:setCoalition(D.cfg.blueSide)
    pcall(function() ab:autoCapture(false) end)
  end
  if ao.garrison then destroyGroup(ao.garrison) end
  if ao.drawId then trigger.action.removeMark(ao.drawId) end
  if ao.wptMark then trigger.action.removeMark(ao.wptMark) end
  D.clearManpads(ao)
  for i, a in ipairs(D.aos) do
    if a == ao then table.remove(D.aos, i) break end
  end
  D.capturedCount = D.capturedCount + 1
  if ao.front then ao.front.pos[#ao.front.pos + 1] = { x = ao.x, y = ao.y, name = ao.name } end
  D.captured[#D.captured + 1] = { name = ao.airbase, front = ao.front and ao.front.name }
  D.refreshBlueBases()
  D.say({ tPlace(ao.name), "airfield", "now_friendly" })
  msg(string.format("%s airfield is now under BLUE control! (%d/%d captured)\nSpawning available there.%s",
    ao.name, D.capturedCount, D.targetsTotal, D.saveNote()))
  D.saveProgress()
  D.activateNext()
  D.checkFortress()
  D.repositionAwacs()
  D.repositionTankers()
end

-- Nachzügler-Regel: höchstens straggler.maxLeft Einheiten übrig -> nach straggler.timeout s erledigt (obj merkt sich den Start)
function D.stragglerDone(obj, alive, now, label)
  local c = D.cfg.campaign.straggler
  if not c or alive > c.maxLeft then obj.stragglerSince = nil return false end
  if not obj.stragglerSince then
    obj.stragglerSince = now
    msg(string.format("%s: %d unit%s left – counts as destroyed in %d min if not found.",
      label, alive, alive == 1 and "" or "s", math.floor(c.timeout / 60 + 0.5)))
    return false
  end
  return now - obj.stragglerSince >= c.timeout
end

function D.checkAOs(now)
  for _, ao in ipairs(D.aos) do
    if ao.garrison and not ao.garrisonDone then
      local alive = groupAliveCount(ao.garrison)
      local destroyed = 1 - alive / ao.garrisonInit
      ao.garrisonStraggler = ao.garrisonStraggler or {}
      local strag = alive > 0 and D.stragglerDone(ao.garrisonStraggler, alive, now,
        string.format("[%s] Airfield garrison", ao.name))
      if strag or destroyed * 100 >= D.cfg.campaign.garrisonPercent then
        if strag then destroyGroup(ao.garrison) end
        ao.garrisonDone = true
        msg(string.format("[%s] Airfield garrison neutralized.", ao.name))
      end
    end
    if ao.airbase and ao.state == "active"
       and ao.samLeft == 0 and ao.samActive == 0
       and ao.casLeft == 0 and ao.casActive == 0
       and (not ao.garrison or ao.garrisonDone) then
      ao.state = "capturing"
      msg(string.format("%s airfield secured! Ground forces moving in – capture in %d s.",
        ao.name, D.cfg.campaign.captureDelay))
      timer.scheduleFunction(safe(function() D.captureAO(ao) end, "Capture"), nil, now + D.cfg.campaign.captureDelay)
    end
  end
end

function D.debugCapture()
  local ao
  for _, a in ipairs(D.aos) do
    if a.airbase and a.state == "active" then ao = a break end
  end
  if not ao then msg("DEBUG: No capturable AO active.") return end
  for i = #D.sites, 1, -1 do
    local s = D.sites[i]
    if s.ao == ao then
      destroyGroup(s.group)
      if s.pdGroup then destroyGroup(s.pdGroup) end
      table.remove(D.sites, i)
    end
  end
  for i = #D.casTasks, 1, -1 do
    if D.casTasks[i].ao == ao then
      destroyGroup(D.casTasks[i].group)
      table.remove(D.casTasks, i)
    end
  end
  ao.samLeft, ao.samActive, ao.casLeft, ao.casActive = 0, 0, 0, 0
  ao.garrisonDone = true
  msg("DEBUG: " .. ao.name .. " cleared, capture pending.")
end

-------------------------------------------------------------------------------
-- TESTHILFE: alle Einheiten beider Seiten auf der F10-Karte
-------------------------------------------------------------------------------
D.dbgShow, D.dbgRunning, D.dbgMarks = false, false, {}

function D.debugClearMarks()
  for gname, id in pairs(D.dbgMarks) do trigger.action.removeMark(id) end
  D.dbgMarks = {}
end

function D.debugMapUpdate()
  local seen = {}
  for _, side in ipairs({ D.cfg.redSide, D.cfg.blueSide }) do
    local tag = (side == D.cfg.redSide) and "RED" or "BLUE"
    for _, g in ipairs(coalition.getGroups(side) or {}) do
      if g and g:isExist() then
        local lead, n, types, isPlayer = nil, 0, {}, false
        for _, u in ipairs(g:getUnits() or {}) do
          if u:isExist() and u:getLife() >= 1 then
            if u.getPlayerName and u:getPlayerName() then isPlayer = true end
            lead = lead or u
            n = n + 1
            local tn = u:getTypeName()
            types[tn] = (types[tn] or 0) + 1
          end
        end
        if lead and not isPlayer then
          local gname = g:getName()
          local list = {}
          for tn, c in pairs(types) do list[#list + 1] = c .. "x " .. tn end
          table.sort(list)
          local text = string.format("[%s] %s (%d): %s", tag, gname, n, table.concat(list, ", "))
          if D.dbgMarks[gname] then trigger.action.removeMark(D.dbgMarks[gname]) end
          local id = newMarkId()
          trigger.action.markToCoalition(id, text, lead:getPoint(), D.cfg.blueSide, true)
          D.dbgMarks[gname] = id
          seen[gname] = true
        end
      end
    end
  end
  for gname, id in pairs(D.dbgMarks) do   -- verschwundene Gruppen entfernen
    if not seen[gname] then
      trigger.action.removeMark(id)
      D.dbgMarks[gname] = nil
    end
  end
end

function D.debugMapLoop(_, t)
  if not D.dbgShow then
    D.debugClearMarks()
    D.dbgRunning = false
    return nil
  end
  local ok, err = pcall(D.debugMapUpdate)
  if not ok and err ~= D.lastDbgError then
    D.lastDbgError = err
    reportError("DebugMap", err)
  end
  return t + D.cfg.debugMapInterval
end

function D.debugMapSet(on)
  D.dbgShow = on
  if on and not D.dbgRunning then
    D.dbgRunning = true
    timer.scheduleFunction(D.debugMapLoop, nil, timer.getTime() + 1)
  end
end

function D.debugMapToggle()
  D.debugMapSet(not D.dbgShow)
  msg(D.dbgShow and "DEBUG: All units of both sides are now shown on the F10 map (updated every "
    .. D.cfg.debugMapInterval .. " s)." or "DEBUG: Unit markers removed from the F10 map.")
end

-------------------------------------------------------------------------------
-- VORWÄRTS-FARP: Ein gelandeter Hubschrauber liefert Nachschub, danach spawnen dort Kampfhubschrauber.
-- Der FARP besteht aus Skript-Objekten (Landeplatz, Tank, Munition, Zelt, vom Test bestätigt) und je einer Skript-Gruppe mit
-- Skill "Player" pro Slot (taucht in der Slot-Liste auf, vom Test bestätigt).
-------------------------------------------------------------------------------
D.farps = {}
D.farpCounter = 0
D.farpMenus = {}
D.farpTemplatePayload = nil

local function farpStatic(name, typ, category, p, extra)
  local def = { name = name, type = typ, category = category, x = p.x, y = p.y, heading = 0, canCrash = false }
  for k, v in pairs(extra or {}) do def[k] = v end
  pcall(coalition.addStaticObject, D.cfg.blueCountry, def)
  return StaticObject.getByName(name) ~= nil
end

local function dumpErr(err)
  if type(err) ~= "table" then return tostring(err) end
  local parts = {}
  for k, v in pairs(err) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- Bewaffnung aus einer AH-64D-Vorlage der Mission übernehmen, wenn dort Pylone belegt sind
function D.farpLoadTemplatePayloads()
  D.farpTemplatePayload = {}
  local want = {}
  for _, t in ipairs(D.cfg.farp.types) do want[t] = true end
  pcall(function()
    for _, side in pairs(env.mission.coalition) do
      for _, c in pairs(side.country or {}) do
        for _, g in pairs((c.helicopter and c.helicopter.group) or {}) do
          local u = g.units and g.units[1]
          if u and want[u.type] and u.payload and u.payload.pylons and next(u.payload.pylons) ~= nil
             and not D.farpTemplatePayload[u.type] then
            local p = { pylons = {}, fuel = u.payload.fuel, flare = u.payload.flare, chaff = u.payload.chaff, gun = u.payload.gun }
            for k, v in pairs(u.payload.pylons) do p.pylons[k] = v end
            D.farpTemplatePayload[u.type] = p
          end
        end
      end
    end
  end)
end

local function farpPayload(typ)
  if D.farpTemplatePayload == nil then D.farpLoadTemplatePayloads() end
  return D.farpTemplatePayload[typ] or D.cfg.farp.payloads[typ]
    or { pylons = {}, fuel = 1000, flare = 30, chaff = 30, gun = 100 }
end

function D.farpMark(f)
  if not D.cfg.mapMarks then return end
  if f.mark then trigger.action.removeMark(f.mark) end
  f.mark = newMarkId()
  trigger.action.markToCoalition(f.mark, string.format("%s (%d helicopter slot%s left)", f.name,
    math.max(0, f.stock - f.used), (f.stock - f.used) == 1 and "" or "s"), toV3(f.pos), D.cfg.blueSide, true)
end

local function farpMakeSlot(f, index)
  local cfg = D.cfg.farp
  local typ = cfg.types[((index - 1) % #cfg.types) + 1]
  local gname = string.format("%s-S%d", f.name, f.nextSlot)
  f.nextSlot = f.nextSlot + 1
  local k = (index - 1) % 4
  local o = cfg.slotOffset
  local ox = ({ o, o, -o, -o })[k + 1]
  local oy = ({ o, -o, o, -o })[k + 1]
  local x, y = f.pos.x + ox, f.pos.y + oy
  local h = land.getHeight({ x = x, y = y })
  local data = {
    name = gname, task = "CAS", uncontrolled = false,
    units = { { name = gname .. "-1", type = typ, skill = "Player", x = x, y = y, heading = 0,
                alt = h, alt_type = "BARO", speed = 0, payload = farpPayload(typ) } },
    route = { points = { { x = x, y = y, alt = h, alt_type = "BARO", type = "TakeOffGround",
                           action = "From Ground Area", speed = 0, ETA = 0, ETA_locked = false,
                           speed_locked = true, task = { id = "ComboTask", params = { tasks = {} } } } } },
  }
  local ok, err = pcall(coalition.addGroup, cfg.country, Group.Category.HELICOPTER, data)
  local g = Group.getByName(gname)
  if g and g:isExist() then
    f.slots[#f.slots + 1] = gname
    return true
  end
  reportError("FARP", string.format("slot %s (%s) could not be created: %s", gname, typ,
    ok and "no group exists afterwards" or dumpErr(err)))
  return false
end

local function farpFind(name)
  for _, f in ipairs(D.farps) do
    if f.name == name then return f end
  end
end

local function farpNearest(p, maxD)
  local best, bd = nil, maxD or math.huge
  for _, f in ipairs(D.farps) do
    local d = dist(p, f.pos)
    if d < bd then best, bd = f, d end
  end
  return best, bd
end

-- gelandeten Hubschrauber der Gruppe finden und prüfen
local function farpCaller(gname)
  local g = Group.getByName(gname)
  if not g or not g:isExist() then return nil, "Group not found." end
  local u = g:getUnit(1)
  if not u or not u:isExist() then return nil, "Aircraft not found." end
  if u:inAir() then return nil, "FARP: Land first, then request the delivery." end
  local v = u:getVelocity()
  if v and math.sqrt((v.x or 0) ^ 2 + (v.z or 0) ^ 2) > D.cfg.farp.maxSpeed then
    return nil, "FARP: Come to a full stop before requesting the delivery."
  end
  return u
end

function D.farpDeploy(gname)
  local cfg = D.cfg.farp
  if not cfg.enabled then return end
  local u, why = farpCaller(gname)
  if not u then msg(why) return end
  local up = toV2(u:getPoint())
  local now = timer.getTime()

  -- Nachschub für einen bestehenden FARP in der Nähe
  local near = farpNearest(up, cfg.resupplyRadius)
  if not near then near = farpNearest(up, cfg.resupplyRadius + cfg.padOffset) end
  if near then
    if now - near.lastDelivery < cfg.cooldown then
      msg(string.format("%s: Supplies were delivered recently. Next delivery possible in %d s.",
        near.name, math.ceil(cfg.cooldown - (now - near.lastDelivery))))
      return
    end
    local open = near.stock - near.used
    local add = cfg.slotsPerFarp
    near.stock = near.stock + add
    near.lastDelivery = now
    local made = 0
    for i = 1, add do
      if farpMakeSlot(near, near.nextSlot) then made = made + 1 end
    end
    near.stock = near.stock - (add - made)
    D.farpMark(near)
    msg(string.format("%s: Supplies delivered. %d helicopter slot%s available again (%d in total).",
      near.name, made, made == 1 and "" or "s", near.stock - near.used))
    return
  end

  if #D.farps >= cfg.maxFarps then
    msg(string.format("FARP: Maximum of %d FARPs reached. Dismantle one first (F10 > Logistics).", cfg.maxFarps))
    return
  end
  local c = { x = up.x + cfg.padOffset, y = up.y }
  if farpNearest(c, cfg.minSeparation) then
    msg(string.format("FARP: Too close to another FARP (minimum %d m).", cfg.minSeparation))
    return
  end
  if land.getSurfaceType(c) ~= land.SurfaceType.LAND or not okGround(c) then
    msg("FARP: The ground here is too uneven or not suitable. Land on flat, open ground.")
    return
  end

  D.farpCounter = D.farpCounter + 1
  local name = "FARP-" .. D.farpCounter
  local names = {}
  if not farpStatic(name, "FARP", "Heliports", c,
      { shape_name = "FARPS", heliport_callsign_id = 1, heliport_frequency = "127.5", heliport_modulation = 0 }) then
    reportError("FARP", "could not create the FARP object – check the type name")
    msg("FARP: Construction failed.")
    return
  end
  names[#names + 1] = name
  local extras = {
    { "FUEL", "FARP Fuel Depot", "Fortifications", 28, 0 },
    { "AMMO", "FARP Ammo Dump Coating", "Fortifications", 0, 28 },
    { "TENT", "FARP Tent", "Fortifications", -28, 0 },
  }
  for _, e in ipairs(extras) do
    local sname = name .. "-" .. e[1]
    if farpStatic(sname, e[2], e[3], { x = c.x + e[4], y = c.y + e[5] }) then names[#names + 1] = sname end
  end

  local f = { name = name, pos = c, objects = names, slots = {}, nextSlot = 1, stock = cfg.slotsPerFarp, used = 0,
              usedSlots = {}, lastDelivery = now }
  D.farps[#D.farps + 1] = f
  local made = 0
  for i = 1, cfg.slotsPerFarp do
    if farpMakeSlot(f, i) then made = made + 1 end
  end
  f.stock = made
  D.farpMark(f)
  msg(string.format("%s deployed at %s.\n%d attack helicopter slot%s are now available in the slot list (%s-S1 …). Ground crew at the pad provides rearm and refuel. Deliver again with a transport helicopter to resupply.",
    name, D.fmtPos(c), made, made == 1 and "" or "s", name))
end

-- Ein Spieler ist in einen FARP-Slot eingestiegen: Vorrat zählen
function D.farpOnBirth(u)
  if not u or not D.cfg.farp.enabled then return end
  local ok, gname = pcall(function() return u:getGroup():getName() end)
  if not ok or not gname then return end
  local fname = gname:match("^(FARP%-%d+)%-S%d+$")
  if not fname then return end
  local f = farpFind(fname)
  if not f or f.usedSlots[gname] then return end
  f.usedSlots[gname] = true
  f.used = f.used + 1
  D.farpMark(f)
  local left = f.stock - f.used
  if left > 0 then
    msg(string.format("%s: %d helicopter slot%s left.", f.name, left, left == 1 and "" or "s"))
  else
    msg(string.format("%s: Supplies exhausted. Deliver more with a transport helicopter (F10 > Logistics).", f.name))
  end
end

function D.farpStatus()
  if #D.farps == 0 then msg("FARP: No forward FARP deployed. Land a helicopter and use F10 > Logistics.") return end
  local lines = { "FORWARD FARPS:" }
  for _, f in ipairs(D.farps) do
    lines[#lines + 1] = string.format("%s – %d of %d slots left\n   %s", f.name, math.max(0, f.stock - f.used), f.stock, D.fmtPos(f.pos))
  end
  msg(table.concat(lines, "\n"))
end

function D.farpDismantle(gname)
  local u, why = farpCaller(gname)
  if not u then msg(why) return end
  local f = farpNearest(toV2(u:getPoint()), 300)
  if not f then msg("FARP: No FARP within 300 m.") return end
  for _, n in ipairs(f.objects) do
    local o = StaticObject.getByName(n)
    if o then pcall(function() o:destroy() end) end
  end
  for _, sg in ipairs(f.slots) do destroyGroup(sg) end
  if f.mark then trigger.action.removeMark(f.mark) end
  for i, x in ipairs(D.farps) do
    if x == f then table.remove(D.farps, i) break end
  end
  msg(f.name .. " dismantled.")
end

-- F10-Menü für Spieler-Hubschrauber (gruppenbezogen)
function D.farpAddMenu(u)
  if not u or not D.cfg.farp.enabled then return end
  local okd, desc = pcall(function() return u:getDesc() end)
  if not okd or not desc or desc.category ~= Unit.Category.HELICOPTER then return end
  local g = u:getGroup()
  local gid, gname = g:getID(), g:getName()
  if gname:match("^FARP%-%d+%-S%d+$") then return end   -- FARP-Slot-Hubschrauber selbst brauchen kein Logistik-Menü
  if D.farpMenus[gid] then pcall(missionCommands.removeItemForGroup, gid, D.farpMenus[gid]) end
  local root = missionCommands.addSubMenuForGroup(gid, "Logistics")
  D.farpMenus[gid] = root
  missionCommands.addCommandForGroup(gid, "Deploy FARP here / resupply nearby FARP", root, safe(function() D.farpDeploy(gname) end, "Menu"))
  missionCommands.addCommandForGroup(gid, "FARP status", root, safe(D.farpStatus, "Menu"))
  missionCommands.addCommandForGroup(gid, "Dismantle nearest FARP (within 300 m)", root, safe(function() D.farpDismantle(gname) end, "Menu"))
end

-------------------------------------------------------------------------------
-- BERICHTE
-------------------------------------------------------------------------------
function D.reportCampaign()
  if D.cfg.mode ~= "airbases" then
    msg(string.format("Endless mode – %d AO(s) active.", #D.aos))
    return
  end
  local lines = { string.format("CAMPAIGN: %d/%d airfields captured", D.capturedCount, D.targetsTotal) }
  for _, ao in ipairs(D.aos) do
    lines[#lines + 1] = string.format("• %s%s\n   SAM left: %d | CAS left: %d | Garrison: %s\n   %s",
      ao.name .. (ao.front and (" – " .. ao.front.name .. " front") or ""), ao.state == "capturing" and " (capture in progress)" or "",
      ao.samLeft + ao.samActive, ao.casLeft + ao.casActive,
      ao.garrison and (ao.garrisonDone and "neutralized"
        or string.format("%d/%d left", groupAliveCount(ao.garrison), ao.garrisonInit)) or "–",
      D.fmtPos({ x = ao.x, y = ao.y }))
  end
  if D.cfg.fortress.enabled then lines[#lines + 1] = D.fortressStatus() end
  if D.cfg.awacs.enabled then
    lines[#lines + 1] = string.format("%s: %s (%.3f AM)", D.cfg.awacs.callsignName,
      D.awacsUnit() and "on station" or "not available", D.cfg.awacs.frequency)
  end
  msg(table.concat(lines, "\n"))
end

function D.reportStats()
  msg(string.format("STATISTICS:\nSAM sites: %d\nCAS taskings: %d\nShip strikes: %d\nConvoys stopped: %d\nDeep strikes: %d\nTroops in contact: %d\nFrontline battles won: %d\nBombers intercepted: %d\nScud launchers destroyed: %d\nPilots rescued: %d\nC-130s escorted: %d\nMain bases neutralized: %d\nEnemy CAPs: %d\nAirfields: %d",
    D.stats.sam, D.stats.cas, D.stats.ship, D.stats.convoy, D.stats.deep, D.stats.tic, D.stats.battle, D.stats.bomber,
    D.stats.scud or 0, D.stats.csar or 0, D.stats.escort or 0, D.stats.fortress, D.stats.cap, D.capturedCount))
end

-------------------------------------------------------------------------------
-- HAUPTSCHLEIFE
-------------------------------------------------------------------------------
function D.update()
  local now = timer.getTime()
  local players = playerPositions()

  -- SAM
  for i = #D.sites, 1, -1 do
    local s = D.sites[i]
    local alive = 0
    for _, n in ipairs(s.critical) do
      if unitAlive(n) then alive = alive + 1 end
    end
    local dead = alive == 0
    if not dead and D.stragglerDone(s, alive, now, string.format("SEAD [%s]: %s site", s.ao.name, s.def.name)) then
      dead = true
      destroyGroup(s.group)
      if s.pdGroup then destroyGroup(s.pdGroup) end
    end
    if dead then
      table.remove(D.sites, i)
      s.ao.samActive = s.ao.samActive - 1
      D.stats.sam = D.stats.sam + 1
      msg(string.format("SEAD [%s]: %s site neutralized! (%d total)", s.ao.name, s.def.name, D.stats.sam))
      D.say({ "good_effect", tSam(s.key), "site_destroyed", tNum(D.stats.sam), "down" })
      if not s.ao.fortress then D.nextSam = math.max(D.nextSam, now + randRange(D.cfg.sam.respawnDelay)) end
      local g, pdg = s.group, s.pdGroup
      timer.scheduleFunction(safe(function()
        destroyGroup(g)
        if pdg then destroyGroup(pdg) end
      end, "Cleanup"), nil, now + D.cfg.sam.cleanupAfter)
    else
      D.updateEmcon(s, now, players)
    end
  end

  -- AWACS / ELINT
  D.checkAwacs(now)
  D.checkTankers(now)
  if D.cfg.tankers.enabled and now >= (D.nextTankerCheck or 0) then
    D.nextTankerCheck = now + D.cfg.tankers.checkInterval
    D.repositionTankers()
  end

  -- CAS
  for i = #D.casTasks, 1, -1 do
    local t = D.casTasks[i]
    local destroyed = 1 - groupAliveCount(t.group) / t.initial
    if destroyed * 100 >= D.cfg.cas.successPercent then
      table.remove(D.casTasks, i)
      t.ao.casActive = t.ao.casActive - 1
      D.stats.cas = D.stats.cas + 1
      msg(string.format("CAS [%s]: Tasking \"%s\" complete! (%d total)", t.ao.name, t.name, D.stats.cas))
    end
  end

  -- Schiffsziele und Nebenaufträge
  D.shipTick(now, players)
  D.convoyTick(now)
  D.deepTick(now)
  D.ticTick(now, players)
  D.battleTick(now)
  D.ambushTick(now, players)
  D.chaosTick(now, players)
  if D.cfg.scud.enabled then D.scudTick(now) end
  if D.cfg.csar.enabled then D.csarTick(now) end
  if D.cfg.escort.enabled then D.escortTick(now) end
  D.bomberTick(now)
  D.fortressTick(now)

  -- CAP
  D.capPersistTick(now)
  for i = #D.caps, 1, -1 do
    local c = D.caps[i]
    if c.hunt and groupAliveCount(c.group) > 0 and now >= (c.nextHunt or 0) then
      c.nextHunt = now + D.cfg.cap.huntUpdate
      D.capHuntRoute(c)
    end
    if groupAliveCount(c.group) == 0 then
      table.remove(D.caps, i)
      D.stats.cap = D.stats.cap + 1
      msg(D.cfg.awacs.callsignName .. ": Hostile CAP destroyed. Picture clean.")
      D.say({ "splash" })
    end
  end

  -- Kampagne
  if D.cfg.mode == "airbases" then D.checkAOs(now) end

  for _, ao in ipairs(D.aos) do
    if not ao.briefed and not ao.fortress and ao.samActive > 0 and (ao.samLeft == 0 or ao.samLeft == math.huge) then
      ao.briefed = true
      msg("INTEL " .. D.aoThreats(ao))
    end
  end

  if D.cfg.persistence.enabled and now - (D.lastSave or 0) >= D.cfg.persistence.interval then D.saveProgress() end

  -- Nachschub
  if now >= D.nextSam then
    local ok = D.spawnSam()
    if ok and D.cfg.sam.spawnAll then
      for _ = 1, 20 do if not D.spawnSam() then break end end
    end
    D.nextSam = ok and (now + 5) or (now + 30)
  end
  if D.cfg.cas.autoSpawn and now >= D.nextCas then
    local ok = D.spawnCAS(false)
    if ok and D.cfg.cas.spawnAll then
      for _ = 1, 20 do if not D.spawnCAS(false) then break end end
    end
    D.nextCas = ok and (now + randRange(D.cfg.cas.interval)) or (now + 60)
  end
  if D.cfg.ship.enabled and D.cfg.ship.autoSpawn and now >= D.nextShip then
    D.nextShip = D.spawnShip(nil, false) and (now + randRange(D.cfg.ship.autoInterval)) or (now + 120)
  end
  if D.cfg.convoy.enabled and D.cfg.convoy.autoSpawn and now >= D.nextConvoy then
    D.nextConvoy = D.spawnConvoy(false) and (now + randRange(D.cfg.convoy.autoInterval)) or (now + 120)
  end
  if D.cfg.deepStrike.enabled and D.cfg.deepStrike.autoSpawn and now >= D.nextDeep then
    D.nextDeep = D.spawnDeepStrike(false) and (now + randRange(D.cfg.deepStrike.autoInterval)) or (now + 120)
  end
  if D.cfg.battle.enabled and D.cfg.battle.autoSpawn and now >= D.nextBattle then
    D.nextBattle = D.spawnBattle(false) and (now + randRange(D.cfg.battle.autoInterval)) or (now + 120)
  end
  if D.cfg.tic.enabled and D.cfg.tic.autoSpawn and now >= D.nextTic then
    D.nextTic = D.spawnTic(false) and (now + randRange(D.cfg.tic.autoInterval)) or (now + 120)
  end
  if D.cfg.bomber.enabled and D.cfg.bomber.autoSpawn and now >= D.nextBomber then
    D.nextBomber = D.spawnBomber(false) and (now + randRange(D.cfg.bomber.autoInterval)) or (now + 120)
  end
  if D.cfg.cap.enabled and D.cfg.cap.autoChance > 0 and now >= D.nextCapRoll then
    if #D.caps < D.cfg.cap.maxActive and math.random() < D.cfg.cap.autoChance then D.spawnCAP() end
    D.nextCapRoll = now + randRange(D.cfg.cap.autoInterval)
  end
end

function D.tick(_, t)
  local ok, err = pcall(D.update)
  if not ok and err ~= D.lastTickError then
    D.lastTickError = err
    reportError("tick", err)
  end
  return t + D.cfg.tickInterval
end

-------------------------------------------------------------------------------
-- START / INIT
-------------------------------------------------------------------------------
function D.start()
  if D.started then return end
  D.started = true

  -- math.randomseed ist in DCS gesperrt -> abhängig vom Spawn-Zeitpunkt
  -- eine variable Anzahl Zufallszahlen "verbrauchen"
  if math.randomseed then
    math.randomseed(math.floor((timer.getTime() * 1000) % 2147483647) + math.floor(timer.getAbsTime()))
  end
  local skip = math.floor(timer.getTime() * 1000) % 1000 + math.floor(timer.getAbsTime()) % 100
  for _ = 1, skip do math.random() end

  local now = timer.getTime()
  D.nextSam = now + 5
  D.nextCas = now + D.cfg.cas.firstDelay
  D.nextShip = now + D.cfg.ship.firstDelay
  D.nextConvoy = now + D.cfg.convoy.firstDelay
  D.nextDeep = now + D.cfg.deepStrike.firstDelay
  D.nextTic = now + D.cfg.tic.firstDelay
  D.nextBattle = now + D.cfg.battle.firstDelay
  D.nextBomber = now + D.cfg.bomber.firstDelay
  D.nextCapRoll = now + randRange(D.cfg.cap.autoInterval)

  timer.scheduleFunction(D.tick, nil, now + 2)
  if D.cfg.debugShowAll then D.debugMapSet(true) end
  trigger.action.outText("DynSEAD: Mission started. Check the F10 menu under \"Dynamic Mission\".", 20)
  if D.cfg.mode == "airbases" then
    safe(D.activateNext, "Objective selection")()
  else
    for _, ao in ipairs(D.aos) do safe(D.spawnManpadsZones, "MANPADS")(ao) end
  end
end

-- DEBUG: alle Flugplätze mit ID, Koalition und Position ins dcs.log (für die Spawn-Vorlagen auf neuen Karten)
function D.debugListAirbases()
  local n = 0
  for _, ab in ipairs(world.getAirbases() or {}) do
    local desc = ab:getDesc()
    if desc and desc.category == Airbase.Category.AIRDROME then
      local p = ab:getPoint()
      local lat, lon = coord.LOtoLL(p)
      env.info(string.format("DynSEAD AIRFIELD | %s | id=%s | coalition=%d | x=%.0f | y=%.0f | lat=%.5f | lon=%.5f",
        ab:getName(), tostring(ab:getID()), ab:getCoalition(), p.x, p.z, lat, lon))
      n = n + 1
    end
  end
  msg(string.format("DEBUG: %d airfields written to dcs.log (search for \"DynSEAD AIRFIELD\").", n))
end

function D.buildMenu()
  -- DCS zeigt pro Menüebene nur etwa 10 Einträge: alles in Untermenüs (je höchstens 9 Einträge) gruppieren
  local side = D.cfg.blueSide
  local function sub(parent, name) return missionCommands.addSubMenuForCoalition(side, name, parent) end
  local function cmd(parent, name, fn) missionCommands.addCommandForCoalition(side, name, parent, safe(fn, "Menu")) end

  local root = missionCommands.addSubMenuForCoalition(side, "Dynamic Mission")

  local info = sub(root, "Info")
  cmd(info, "Campaign: Status", D.reportCampaign)
  cmd(info, "Navigation: AO steerpoints", D.reportNav)
  cmd(info, "Threats: SAMs & MANPADS per AO", D.reportThreats)
  cmd(info, "Support: AWACS & tankers", D.reportSupport)
  if D.cfg.farp.enabled then cmd(info, "Forward FARPs: status", D.farpStatus) end
  cmd(info, "Statistics", D.reportStats)
  if D.cfg.persistence.enabled then
    cmd(info, "Campaign: save code / save status", D.reportSave)
    cmd(info, "Campaign: reset saved progress", D.resetSave)
  end

  local cas = sub(root, "CAS")
  cmd(cas, "Request new tasking", D.requestCAS)
  cmd(cas, "Active taskings", D.reportCAS)
  cmd(cas, "Mark targets with smoke", D.smokeCAS)

  if D.cfg.cap.enabled then
    local capMenu = sub(root, "A2A: Request enemy CAP")
    for _, m in ipairs({ { "patrol", "Patrol the AO" }, { "hunt", "Hunt nearest player" } }) do
      local mm = sub(capMenu, m[2])
      cmd(mm, "Current difficulty", function() D.spawnCAP(nil, m[1]) end)
      for i, td in ipairs(D.cfg.cap.tiers) do
        local types = {}
        for _, v in ipairs(td.variants) do types[#types + 1] = v.type end
        cmd(mm, string.format("Level %d – %s (%s)", i, td.label, table.concat(types, "/")),
          function() D.spawnCAP(i, m[1]) end)
      end
    end
    cmd(capMenu, "Respawning CAP: toggle ON/OFF", D.toggleCapPersist)
    if D.cfg.chaos.helos.enabled then cmd(capMenu, "Enemy helicopters: toggle ON/OFF", D.toggleHelos) end
    cmd(capMenu, "Remove all enemy CAPs", D.removeCAPs)
  end

  if D.cfg.ship.enabled then
    local shipMenu = sub(root, "Ship Strike")
    cmd(shipMenu, "Current difficulty", function() D.requestShip() end)
    for i, td in ipairs(D.cfg.ship.tiers) do
      cmd(shipMenu, string.format("Level %d – %s", i, td.label), function() D.requestShip(i) end)
    end
    cmd(shipMenu, "Active taskings", D.reportShips)
  end

  local sq = sub(root, "Side Missions")
  if D.cfg.convoy.enabled then
    local cm = sub(sq, "Convoy")
    cmd(cm, "Request intercept tasking", D.requestConvoy)
    cmd(cm, "Status and route", D.reportConvoy)
  end
  if D.cfg.deepStrike.enabled then
    local dm = sub(sq, "Deep Strike")
    cmd(dm, "Request tasking", D.requestDeepStrike)
    cmd(dm, "Status", D.reportDeepStrike)
  end
  if D.cfg.bomber.enabled then
    local bo = sub(sq, "Bomber Intercept")
    cmd(bo, "Request intercept tasking", D.requestBomber)
    cmd(bo, "Status", D.reportBomber)
  end
  if D.cfg.scud.enabled then cmd(sq, "SCUD hunt: status", D.reportScud) end
  if D.cfg.escort.enabled then
    local em = sub(sq, "C-130 Escort")
    cmd(em, "Request escort mission", D.requestEscort)
    cmd(em, "Status", D.reportEscort)
  end
  if D.cfg.csar.enabled then
    local cm = sub(sq, "CSAR")
    cmd(cm, "Status and positions", D.reportCsar)
    cmd(cm, "Downed pilots: green smoke", D.smokeCsar)
  end
  if D.cfg.battle.enabled then
    local bm = sub(sq, "Frontline Battle")
    cmd(bm, "Start frontline battle", D.requestBattle)
    cmd(bm, "Status", D.reportBattle)
  end
  if D.cfg.tic.enabled then
    local jt = sub(sq, "TIC / JTAC")
    cmd(jt, "Request troops-in-contact tasking", D.requestTic)
    cmd(jt, "Situation report", D.reportTic)
    cmd(jt, "Friendlies: green smoke", function() D.ticMarkFriendly("green") end)
    cmd(jt, "Friendlies: orange smoke", function() D.ticMarkFriendly("orange") end)
    cmd(jt, "Friendlies: white smoke", function() D.ticMarkFriendly("white") end)
    cmd(jt, "Friendlies: IR strobe on/off", D.ticToggleStrobe)
    cmd(jt, "Enemy: mark with red smoke", D.ticMarkEnemy)
    cmd(jt, "Enemy: laser on/off", D.ticLase)
  end

  if D.cfg.debugMenu then
    local dbg = sub(root, "DEBUG")
    cmd(dbg, "Show all units on map (on/off)", D.debugMapToggle)
    if D.cfg.mode == "airbases" then cmd(dbg, "Clear current AO now", D.debugCapture) end
    if D.cfg.fortress.enabled then cmd(dbg, "Activate enemy main base now", function() D.activateFortress(true) end) end
    cmd(dbg, "Write airfield list to dcs.log", D.debugListAirbases)
    if D.cfg.ambush.enabled then cmd(dbg, "Spawn SAM ambush now", function() D.spawnAmbush(true) end) end
    if D.cfg.scud.enabled then cmd(dbg, "Spawn Scud now (fires in 3 min)", function()
      if D.scud then msg("DEBUG: Scud already active.") return end
      if D.spawnScud(true) then D.scud.fireAt = timer.getTime() + 180 end
    end) end
    if D.cfg.csar.enabled then cmd(dbg, "Spawn CSAR now", function()
      if not D.spawnAllyCsar(true) then msg("DEBUG: No valid CSAR position found.") end
    end) end
  end
end

-------------------------------------------------------------------------------
-- KAMPAGNENSTAND SPEICHERN: Datei (Server mit io/lfs) und Spielstand-Code (Kartenmarker "LOAD <Code>")
-------------------------------------------------------------------------------
D.captured = {}          -- { name, front } in Eroberungsreihenfolge
D.campaignList = nil     -- alle Kampagnen-Flugplätze (sortiert) für den Code
local B32 = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

local function saveFilePath()
  local p = D.cfg.persistence
  if not (p.enabled and p.file) or type(io) ~= "table" or type(lfs) ~= "table" or not lfs.writedir then return nil end
  return lfs.writedir() .. string.format(p.fileName, D.theatre or "map")
end

local function frontByName(n)
  for _, f in ipairs(D.fronts or {}) do if f.name == n then return f end end
end

-- Stand als Code: Bitmaske der eroberten Plätze + Index der Hauptbasis + Prüfzeichen
function D.saveCode()
  local list = D.campaignList
  if not list then return nil end
  local captured = {}
  for _, c in ipairs(D.captured) do captured[c.name] = true end
  local bits = {}
  local fi = 0
  for i, n in ipairs(list) do
    bits[#bits + 1] = captured[n] and 1 or 0
    if n == D.fortressName then fi = i end
  end
  local out = { B32:sub(math.floor(fi / 32) + 1, math.floor(fi / 32) + 1), B32:sub(fi % 32 + 1, fi % 32 + 1) }
  for i = 1, #bits, 5 do
    local v = 0
    for k = 0, 4 do v = v * 2 + (bits[i + k] or 0) end
    out[#out + 1] = B32:sub(v + 1, v + 1)
  end
  local sum = 0
  for _, ch in ipairs(out) do sum = sum + B32:find(ch, 1, true) end
  out[#out + 1] = B32:sub(sum % 32 + 1, sum % 32 + 1)
  local raw = (D.theatre or "X"):sub(1, 1):upper() .. table.concat(out)
  return (raw:gsub("(%w%w%w%w)", "%1-"):gsub("%-$", ""))
end

local function decodeCode(code)
  local list = D.campaignList
  if not list then return nil, "campaign list not ready" end
  local raw = code:upper():gsub("[^%w]", "")
  if raw:sub(1, 1) ~= (D.theatre or "X"):sub(1, 1):upper() then return nil, "code is for another map" end
  raw = raw:sub(2)
  local vals = {}
  for i = 1, #raw do
    local p = B32:find(raw:sub(i, i), 1, true)
    if not p then return nil, "invalid character" end
    vals[i] = p - 1
  end
  local need = 2 + math.ceil(#list / 5) + 1
  if #vals ~= need then return nil, "wrong length" end
  local sum = 0
  for i = 1, #vals - 1 do sum = sum + vals[i] + 1 end
  if sum % 32 ~= vals[#vals] then return nil, "checksum mismatch" end
  local fi = vals[1] * 32 + vals[2]
  local state = { captured = {}, fortress = list[fi] }
  local idx = 1
  for i = 3, #vals - 1 do
    for k = 4, 0, -1 do
      if idx <= #list and math.floor(vals[i] / 2 ^ k) % 2 == 1 then state.captured[#state.captured + 1] = { name = list[idx] } end
      idx = idx + 1
    end
  end
  return state
end

function D.saveNote()
  if not (D.cfg.persistence.enabled and D.cfg.persistence.code) then return "" end
  local c = D.saveCode()
  return c and ("\nSave code: " .. c) or ""
end

-- Datei schreiben (einfaches Textformat, wird beim Laden nicht ausgeführt)
function D.saveProgress()
  local path = not D.saveDisabled and saveFilePath()
  if not path then return false end
  local lines = { "version=1", "theatre=" .. tostring(D.theatre) }
  if D.fortressName then lines[#lines + 1] = "fortress=" .. D.fortressName end
  for _, c in ipairs(D.captured) do lines[#lines + 1] = "captured=" .. c.name .. "|" .. (c.front or "") end
  for k, v in pairs(D.stats) do lines[#lines + 1] = "stat=" .. k .. "|" .. tostring(v) end
  local ok, err = pcall(function()
    local fh = assert(io.open(path, "w"))
    fh:write(table.concat(lines, "\n"), "\n")
    fh:close()
  end)
  if not ok then env.warning("DynSEAD: could not write save file " .. path .. ": " .. tostring(err)) end
  D.lastSave = timer.getTime()
  return ok
end

local function readSaveFile()
  local path = saveFilePath()
  if not path then return nil end
  local ok, text = pcall(function()
    local fh = io.open(path, "r")
    if not fh then return nil end
    local t = fh:read("*a")
    fh:close()
    return t
  end)
  if not ok or not text or text == "" then return nil end
  local state = { captured = {}, stats = {} }
  for line in text:gmatch("[^\r\n]+") do
    local k, v = line:match("^(%w+)=(.*)$")
    if k == "theatre" then state.theatre = v
    elseif k == "fortress" then state.fortress = v
    elseif k == "captured" then
      local n, fr = v:match("^(.-)|(.*)$")
      state.captured[#state.captured + 1] = { name = n or v, front = (fr ~= "" and fr) or nil }
    elseif k == "stat" then
      local sk, sv = v:match("^(.-)|(.*)$")
      if sk and tonumber(sv) then state.stats[sk] = tonumber(sv) end
    end
  end
  if state.theatre and state.theatre ~= D.theatre then return nil end
  return state
end

-- Aktive AO aufgeben (für Laden mitten im Spiel): Einheiten entfernen, Ziel zurück in den Pool
local function dropAO(ao)
  for i = #D.sites, 1, -1 do
    local st = D.sites[i]
    if st.ao == ao then
      destroyGroup(st.group)
      if st.pdGroup then destroyGroup(st.pdGroup) end
      table.remove(D.sites, i)
    end
  end
  for i = #D.casTasks, 1, -1 do
    if D.casTasks[i].ao == ao then destroyGroup(D.casTasks[i].group); table.remove(D.casTasks, i) end
  end
  if ao.garrison then destroyGroup(ao.garrison) end
  D.clearManpads(ao)
  if ao.drawId then trigger.action.removeMark(ao.drawId) end
  if ao.wptMark then trigger.action.removeMark(ao.wptMark) end
  table.insert(D.targetPool, 1, ao.airbase)
end

-- Stand anwenden (beim Start oder per LOAD-Code mitten im Spiel)
function D.applySave(state, source)
  if D.fortress then
    msg("LOAD: Not possible while the enemy main base is active.")
    return false
  end
  local inPool = {}
  for _, n in ipairs(D.targetPool) do inPool[n] = true end
  if D.fortressBase then inPool[D.fortressBase] = true end
  for _, ao in ipairs(D.aos) do inPool[ao.airbase] = true end
  -- aktive AOs aufgeben
  for i = #D.aos, 1, -1 do dropAO(D.aos[i]); table.remove(D.aos, i) end
  -- Hauptbasis wie gespeichert
  if state.fortress and inPool[state.fortress] and state.fortress ~= D.fortressBase then
    if D.fortressBase then D.targetPool[#D.targetPool + 1] = D.fortressBase end
    for i, n in ipairs(D.targetPool) do if n == state.fortress then table.remove(D.targetPool, i) break end end
    D.fortressBase, D.fortressName = state.fortress, state.fortress
  end
  local n = 0
  for _, c in ipairs(state.captured) do
    local ab = Airbase.getByName(c.name)
    if ab and inPool[c.name] then
      ab:setCoalition(D.cfg.blueSide)
      pcall(function() ab:autoCapture(false) end)
      for i, t in ipairs(D.targetPool) do if t == c.name then table.remove(D.targetPool, i) break end end
      if c.name == D.fortressBase then D.fortressBase = nil; D.fortressName = nil end
      local f = frontByName(c.front)
      if f then local p = toV2(ab:getPoint()); p.name = c.name; f.pos[#f.pos + 1] = p end
      D.captured[#D.captured + 1] = { name = c.name, front = c.front }
      n = n + 1
    end
  end
  D.capturedCount = D.capturedCount + n
  for k, v in pairs(state.stats or {}) do if D.stats[k] then D.stats[k] = v end end
  D.refreshBlueBases()
  env.info(string.format("DynSEAD: campaign restored from %s – %d airfield(s) captured, main base %s", source, n, tostring(D.fortressName)))
  msg(string.format("CAMPAIGN RESTORED (%s): %d of %d airfields already captured.", source, D.capturedCount, D.targetsTotal))
  if D.started then
    D.activateNext()
    D.checkFortress()
    D.repositionAwacs()
    D.repositionTankers()
  end
  D.saveProgress()
  return true
end

-- Beim Laden der Mission: Datei einlesen
function D.initPersistence()
  local list = {}
  for _, n in ipairs(D.targetPool) do list[#list + 1] = n end
  if D.fortressBase then list[#list + 1] = D.fortressBase end
  table.sort(list)
  D.campaignList = list
  local p = D.cfg.persistence
  if not p.enabled then return end
  if p.file and not saveFilePath() then
    env.info("DynSEAD: save file disabled – io/lfs not available (MissionScripting.lua); save codes still work")
  end
  local state = readSaveFile()
  if state and #state.captured > 0 then D.applySave(state, "save file") end
end

-- Kartenmarker "LOAD <Code>"
function D.onMarkText(e)
  local text = e.text or ""
  local code = text:match("^%s*[Ll][Oo][Aa][Dd]%s+(.+)$")
  if not code or not D.cfg.persistence.enabled then return end
  pcall(trigger.action.removeMark, e.idx)
  local state, err = decodeCode(code)
  if not state then msg("LOAD: Save code not accepted (" .. tostring(err) .. ").") return end
  D.applySave(state, "save code")
end

function D.reportSave()
  local p = D.cfg.persistence
  local lines = { string.format("CAMPAIGN SAVE: %d of %d airfields captured.", D.capturedCount, D.targetsTotal) }
  if p.code then
    lines[#lines + 1] = "Save code: " .. tostring(D.saveCode())
    lines[#lines + 1] = "To restore after a restart: place an F10 map marker with the text  LOAD <code>"
  end
  local path = saveFilePath()
  lines[#lines + 1] = path and ("Save file: active (" .. path .. ")") or "Save file: not available on this server (io/lfs disabled)"
  msg(table.concat(lines, "\n"))
end

function D.resetSave()
  local now = timer.getTime()
  if not D.resetArmed or now - D.resetArmed > 30 then
    D.resetArmed = now
    msg("RESET: Select this command again within 30 s to delete the saved campaign. The current game continues; the next mission start begins a new campaign.")
    return
  end
  D.resetArmed = nil
  local path = saveFilePath()
  if path then
    pcall(function() local fh = io.open(path, "w"); if fh then fh:write(""); fh:close() end end)
    D.saveDisabled = true
    msg("RESET: Saved campaign deleted. Saving is paused until the mission restarts.")
  else
    msg("RESET: No save file on this server – simply do not use a save code after the restart.")
  end
end

D.handler = {}
function D.handler:onEvent(e)
  local ok, err = pcall(function()
    if e.id == world.event.S_EVENT_BIRTH then
      local u = e.initiator
      if u and u.getPlayerName and u:getPlayerName() then
        if not D.started then D.start() else D.scheduleRedraw() end
        safe(D.farpOnBirth, "FARP")(u)
        safe(D.farpAddMenu, "FARP menu")(u)
      end
    elseif e.id == world.event.S_EVENT_SHOT then
      onShot(e)
      if D.cfg.scud.enabled then D.scudOnShot(e) end
    elseif e.id == world.event.S_EVENT_EJECTION then
      D.csarOnEject(e)
    elseif e.id == world.event.S_EVENT_MARK_ADDED or e.id == world.event.S_EVENT_MARK_CHANGE then
      D.onMarkText(e)
    end
  end)
  if not ok then reportError("Event", err) end
end

local function initZones()
  local prefix = D.cfg.zonePrefix
  local mz = env.mission and env.mission.triggers and env.mission.triggers.zones or {}
  for _, z in pairs(mz) do
    if type(z) == "table" and z.name and z.name:sub(1, #prefix) == prefix then
      local tz = trigger.misc.getZone(z.name)
      if tz and tz.radius and tz.radius > 0 then
        local ao = { name = z.name, x = tz.point.x, y = tz.point.z, radius = tz.radius,
          samLeft = math.huge, casLeft = math.huge, samActive = 0, casActive = 0, state = "active" }
        drawAO(ao)
        D.addAOWaypoint(ao)
        D.aos[#D.aos + 1] = ao
      end
    end
  end
  if #D.aos == 0 then
    trigger.action.outText("DynSEAD ERROR: No trigger zone found whose name starts with \"" .. prefix .. "\"!", 60)
    return false
  end
  env.info("DynSEAD: " .. #D.aos .. " AO zone(s) found.")
  return true
end

local function inArea(ab, a)
  local ok, lat, lon = pcall(function() return coord.LOtoLL(ab:getPoint()) end)
  return ok and lat and lat >= a.latMin and lat <= a.latMax and lon >= a.lonMin and lon <= a.lonMax
end

local function initAirbases()
  local c = D.cfg.campaign
  local map = D.map or {}
  local excluded = {}
  for _, n in ipairs(c.exclude or {}) do excluded[n] = true end
  for _, n in ipairs(map.exclude or {}) do excluded[n] = true end

  local homes = {}
  if c.homeBase then homes[#homes + 1] = c.homeBase end
  for _, n in ipairs(map.homeBases or {}) do homes[#homes + 1] = n end
  for _, n in ipairs(map.friendly or {}) do homes[#homes + 1] = n end
  for _, n in ipairs(homes) do
    local hb = Airbase.getByName(n)
    if hb then hb:setCoalition(D.cfg.blueSide) else env.warning("DynSEAD: home base not found: " .. n) end
  end
  for _, ab in ipairs(world.getAirbases() or {}) do
    for _, a in ipairs(map.friendlyAreas or {}) do
      if inArea(ab, a) then pcall(function() ab:setCoalition(D.cfg.blueSide) end) break end
    end
  end

  local home, targets = {}, {}
  for _, ab in ipairs(world.getAirbases() or {}) do
    local desc = ab:getDesc()
    local name = ab:getName()
    if desc and desc.category == Airbase.Category.AIRDROME and not D.ignoredBase(ab) then
      pcall(function() ab:autoCapture(false) end)
      if ab:getCoalition() == D.cfg.blueSide then
        home[#home + 1] = name
      elseif not excluded[name] then
        pcall(function() ab:setCoalition(D.cfg.redSide) end)
        D.targetPool[#D.targetPool + 1] = name
        targets[#targets + 1] = name
      end
    end
  end

  if #home == 0 then
    trigger.action.outText("DynSEAD ERROR: No blue home airfield! Set one airfield to BLUE in the editor or set campaign.homeBase.", 60)
    return false
  end
  D.targetsTotal = #D.targetPool
  env.info("DynSEAD: home base(s): " .. table.concat(home, ", "))
  env.info("DynSEAD: objectives (" .. #targets .. "): " .. table.concat(targets, ", "))
  return true
end

local function initVoice()
  local v = D.cfg.voice
  if not v.enabled then return end
  if type(DynSEAD_VOICE) == "table" and type(DynSEAD_VOICE.clips) == "table" then
    D.voiceOK = true
    local n = 0
    for _ in pairs(DynSEAD_VOICE.clips) do n = n + 1 end
    timer.scheduleFunction(D.voiceTick, nil, timer.getTime() + 1)
    env.info("DynSEAD: voice enabled, " .. n .. " clips, output = " .. v.output)
  else
    env.warning("DynSEAD: voice disabled - DynSEAD_voice.lua not loaded")
  end
end

local function init()
  D.theatre = (env.mission and env.mission.theatre) or "Caucasus"
  D.map = D.cfg.maps[D.theatre] or {}
  if D.map.tankers then D.cfg.tankers.list = D.map.tankers end
  if D.map.deepStrike then D.cfg.deepStrike.targets = D.map.deepStrike end
  env.info("DynSEAD: theatre " .. D.theatre)
  local ok
  if D.cfg.mode == "airbases" then ok = initAirbases() else ok = initZones() end
  if ok and D.cfg.mode == "airbases" and D.map.fronts then
    D.fronts = {}
    for _, fc in ipairs(D.map.fronts) do
      local f = { name = fc.name, active = fc.active or 1, pos = {} }
      for _, n in ipairs(fc.bases or {}) do
        local ab = Airbase.getByName(n)
        if ab then local p = toV2(ab:getPoint()); p.name = n; f.pos[#f.pos + 1] = p
        else env.warning("DynSEAD: front " .. f.name .. ": airfield not found: " .. n) end
      end
      if #f.pos > 0 then D.fronts[#D.fronts + 1] = f end
    end
    if #D.fronts == 0 then D.fronts = nil end
  end
  if ok and D.cfg.mode == "airbases" then safe(D.initPersistence, "Persistence")() end
  if not ok then return end
  D.refreshBlueBases()
  if D.cfg.mode == "airbases" then D.reserveFortress() end
  initVoice()
  D.buildMenu()
  world.addEventHandler(D.handler)
  timer.scheduleFunction(function() if not D.started then safe(D.start, "Start")() end end,
    nil, timer.getTime() + D.cfg.fallbackStart)
  env.info("DynSEAD v4.61 loaded (mode: " .. D.cfg.mode .. ").")
  local info = (D.cfg.mode == "airbases")
    and string.format("%d home base(s), %d objective airfields", #D.blueBases, D.targetsTotal)
    or string.format("%d AO zone(s)", #D.aos)
  trigger.action.outText(string.format(
    "DynSEAD v4.61 loaded – %s.\nStarts on first player spawn, at the latest after %d s.",
    info, D.cfg.fallbackStart), 30)
end

safe(init, "Init")()
