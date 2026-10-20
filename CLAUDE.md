# DynSEAD – dynamische SEAD/CAS-Koop-Kampagne für DCS World

Mit dem Nutzer **auf Deutsch** kommunizieren. Alle Texte **im Spiel** (Meldungen, F10-Menü, Kartenmarker,
Sprachausgabe) sind **Englisch**. Kommentare im Konfigurationsblock des Skripts sind Deutsch.

## Ziel
Koop-Multiplayer-Mission (Karte **Caucasus**) mit möglichst wenig Editor-Arbeit. Alles Dynamische macht ein
einziges Lua-Skript ohne MOOSE/MIST und ohne Template-Gruppen. Eroberungskampagne: Startbasis
**Senaki-Kolkhi** (blau), alle anderen 20 Flugplätze werden per Skript rot und nacheinander zur AO.
Gespielt wird mit **Dynamic Spawn** (kein SRS!). Muster: F-16C, F/A-18C, A-10C II, AJS-37, AH-64D.

## Dateien
| Pfad | Inhalt |
|---|---|
| `src/DynSEAD.lua` | Missionsskript (aktuell v4.24). Version steht im Kopf als `DynSEAD vX.Y` |
| `mission/Dynamic_Script.miz` | aktuelle Mission (Skript v4.24 eingebettet, Briefing, 105 Spawn-Vorlagen mit Wegpunkten) |
| `tools/miz_tool.py` | CLI: `info`, `embed`, `templates`, `options`, `voice` (siehe Docstring); `options` setzt Schwierigkeitsoptionen, z. B. `optionsView=optview_all` |
| `tools/luatable.py` | Parser/Serializer für DCS-Lua-Tabellen (mission, warehouses, dictionary, mapResource) – Roundtrip getestet |
| `tools/geo.py` | Caucasus-Flugplätze (ID, Name, Lat/Lon) + Umrechnung Lat/Lon → DCS x/y (Transverse Mercator, pydcs-Parameter; ~1 km genau) |
| `voice/make_overlord_voice.py` | erzeugt beim Nutzer per Edge-TTS (neuronale Stimme, `pip install edge-tts`, ffmpeg) die 111 WAV-Bausteine `ov_*.wav` + ZIP; Sandbox hat kein Internet |
| `voice/make_overlord_voice_elevenlabs.py` | wie oben, aber mit ElevenLabs (bessere Stimme; Key nur als Umgebungsvariable `ELEVENLABS_API_KEY`); bevorzugt |
| `voice/make_overlord_voice.ps1` | alte Variante mit Windows-Sprachausgabe (SAPI), nicht mehr bevorzugt |

## Arbeitsablauf
1. `src/DynSEAD.lua` ändern → **Version im Kopf erhöhen** (alle Vorkommen von `DynSEAD vX.Y`).
2. `python tools/miz_tool.py embed mission/Dynamic_Script.miz src/DynSEAD.lua`
   – bettet als `DynSEAD_vX.Y.lua` ein. Neuer Dateiname ist Pflicht: der DCS-Editor behält sonst u. U.
   eine alte Kopie gleichen Namens.
3. Lua-Syntax prüfen (kein Lua-Interpreter installiert → mindestens Block/Klammer-Balance mit einem
   Tokenizer, der Strings und Kommentare korrekt überspringt; naive Regex scheitert an `'"'` in Strings).
4. Nutzer testet in DCS; Fehler erscheinen im Spiel (`showErrors = true`) und in `Saved Games\DCS\Logs\dcs.log` (Suche „DynSEAD“).

**Nie Dateien löschen, bevor die neue Version erfolgreich geschrieben ist** (einmal ist dadurch Arbeit verloren gegangen).

## Aufbau von `src/DynSEAD.lua`
- `D.cfg` oben: `mode` ("airbases"/"zones"), `campaign` (activeTargets=2, samPerAO, casPerAO, Garnison, `aoSeparation` = Mindestabstand gleichzeitig aktiver AOs, damit sich die Kreise nicht überlappen; sonst wird gewartet),
  `sam` (maxActive=5, Typ-Pool, `engageRange`, `modesByType`, `armEvasion`, `relocate`, `pointDefense`),
  `elint`, `awacs` (Overlord E-3A 251 AM, immortal/invisible), `voice`, `tankers` (Texaco KC-135 Boom 255 AM 51Y,
  Arco KC-135MPRS Drogue 256 AM 52Y), `manpads`, `cas`, `cap` (4 Schwierigkeitsstufen, `D.capLoadouts`).
  `ship` (Ship Strike: 4 Stufen, F10-Untermenü, Ziel 35–80 km vor einem nicht-blauen Flugplatz auf See; Stufe 2/3 halten per
  ROE `WEAPON_HOLD` das Feuer bis ein Spieler näher als `alertRange` kommt oder ein Schiff getroffen wird).
  Nebenaufträge (F10 „Side Missions“): `convoy` (Konvoi zwischen zwei roten Flugplätzen auf Straßen, nur leichte Fahrzeuge + max. 2 Flak,
  Start/Ziel/Linie auf der Karte, verloren bei Ankunft), `deepStrike` (statisches Ziel an festen Lat/Lon-Koordinaten ≥ 100 km von der
  nächsten blauen Basis, Flak-Schutz, für Präzisionswaffen), `bomber` (Bomber Intercept: Tu-95MS/Tu-160 starten in der Luft vor einem feindlichen Flugplatz, Ziel ist ein blauer Flugplatz 150–350 km entfernt; ohne
  Waffen, den Abwurf stellt das Skript mit Explosionen nach, sobald ein Bomber ≤ `releaseRange` ans Ziel kommt; Erfolg nur, wenn alle vorher fallen; Lagemeldungen
  alle 90 s plus ungenauer Kartenmarker; `bombPower = 0` schaltet den Schaden ab), `fortress` (Hauptmission feindliche Hauptbasis als Finale: wird beim Kampagnenstart unsichtbar reserviert (zufällig unter den 5 am weitesten von blauen Basen entfernten roten
  Flugplätzen, aus `targetPool` genommen, `D.reserveFortress`) und erst aktiv, wenn alle anderen Flugplätze erobert sind (`unlockAfter = 0`; N > 0 = schon nach N Eroberungen); Schichten S-200 ×2 außen, S-300PS ×2, SA-11 ×2, SA-15 ×2 innen, alle
  Radare dauerhaft an (`mode = always`), kritisch = Zielradar **und** alle Startgeräte; dazu Frühwarnradar, Flak, Garnison, MANPADS; gewonnen, wenn alle SAM-Stellungen zerstört sind, dann wird
  der Platz blau; `D.createSam(ao, key, p, …)` baut eine Stellung; Hauptbasis-Stellungen zählen nicht gegen `sam.maxActive`; F10 DEBUG > „Activate enemy main base now“), `tic` (Troops in Contact für A-10C/AH-64D, bewusst abseits der SAM-Zonen: Editor-Trigger-Zone `TIC*` oder automatisch 10–45 km von einer blauen Basis,
  außerhalb aller aktiven AOs und ≥ 50 km von SAMs; `D.safeZones` hält neue SAMs fern; blaue Gruppe, 3 anrückende leichte rote Wellen, Rauch/IR-Strobe
  automatisch ab 12 km oder per Menü, JTAC-Menü mit Lage, Rotrauch auf Feind, Laser Code 1688).
- Testhilfe: `cfg.debugShowAll` (standardmäßig aus) bzw. F10 „DEBUG: Show all units on map“ zeichnet alle Gruppen beider Seiten
  (ohne Spielergruppen) als Marker auf die F10-Karte, Aktualisierung alle `debugMapInterval` s.
- F10-Menü: DCS zeigt pro Ebene nur etwa 10 Einträge, daher sind alle Befehle in Untermenüs gruppiert (Info, CAS, A2A, Ship Strike,
  Side Missions mit JTAC, DEBUG), höchstens 8 Einträge pro Ebene. Neue Befehle in ein passendes Untermenü, nicht an die Wurzel.
- Rote Bodengruppen (SAM, Garnison, CAS, Konvoi, TIC-Feinde …) werden mit `hidden = D.hideOnMap()` gespawnt: `hidden = true` versteckt sie auf der
  F10-Karte **unabhängig** von der Option „F10 View Options: All“. `cfg.debugVisibleUnits = true` zeigt sie für alle Spieler (aktuell an, zum Testen); für den echten Spielbetrieb auf `false`.
- Missionsoptionen, die die Mission selbst durchsetzt, stehen in `mission.forcedOptions` (Datei `mission`); die Datei `options` enthält nur die lokalen
  Einstellungen des zuletzt speichernden Nutzers und wirkt nicht. setzt man mit `python tools/miz_tool.py options MISSION.miz optionsView=optview_all --forced`, entfernen mit `optionsView= --forced`.
  Aktuell erzwingt die Mission **keine** F10-View-Option: der Nutzer stellt sie vor jedem Start selbst im Gameplay-Menü ein.
- SAM-/Radar-Standorte (`D.samSpotClear`, `cfg.siting`): nicht in Editor-Trigger-Zonen `NOSAM*`; Gelände: Hangneigung ≤ 6° (8 Richtungen auf 150 m) und Horizont (Berge ≥ 6° Erhebung
  in ≥ 3 von 8 Richtungen bei 1,5/3/5 km blockieren); Bebauung: nicht direkt neben Gebäuden (`world.searchObjects(SCENERY)` im Umkreis `sceneryRadius` = 150 m), nicht zwischen
  ≥ 10 Objekten im Umkreis 400 m und nicht neben Objekten ≥ 12 m Höhe (aus `getDesc().box`) im Umkreis 300 m. DCS hat keine Wald-Abfrage: Bäume werden nur erkannt, falls sie als Szenerie-Objekte geliefert werden; große Wälder sperrt man per `NOSAM`-Zone.
  Die Prüfung gilt nur im ersten Durchlauf von `D.findSpot` (weich, blockiert nie), auch für Hauptbasis-Schichten und Stellungswechsel. `dcs.log` zeigt pro Stellung die Zähler
  „siting checks“ (Wirkung prüfbar).
- Keine einzelnen Infanteristen: Einzelpersonen sind schwer zu finden, daher spawnen Garnison, CAS, TIC (auch die Verbündeten) und Deep-Strike-Schutz nur
  Fahrzeuge. Ausnahme MANPADS (`SA-18 Igla manpad`): daneben parkt ein `UAZ-469` (Marker für die Suche, 6 m Abstand).
- Spawns per `coalition.addGroup` mit selbst gebauten Gruppentabellen (Land `CJTF_RED` / `CJTF_BLUE`).
- Hauptschleife `D.update` alle 10 s; ARM-Tracking `D.armTick` jede Sekunde; `D.voiceTick` alle 0,5 s.
- SAM-Radar = `ALARM_STATE` RED/GREEN. Modi: always / blink / ambush (typabhängige Auslöse-Reichweite).
- ARM-Abwehr: Rakete wird verfolgt, Zielzuordnung über `getTarget()` sonst horizontale Flugrichtung;
  Entdeckung pro Sekunde abhängig von Sichtlinie (`land.isVisible`), Höhe über Grund, Reichweite, Start bemerkt;
  danach Reaktionszeit, Unterdrückung 120–300 s, mobile Systeme ziehen evtl. 2–6 km um.
- ELINT: Fehler schrumpft pro Tick, Untergrenze wächst mit Sensor-Entfernung (`errPerKm`); Marker bleibt bei
  Stellungswechsel an alter Position, Fehler wächst.
- Kartenzeichnungen werden bei jedem Spieler-Spawn neu gezeichnet (`D.scheduleRedraw`) – DCS überträgt
  Skript-Zeichnungen nicht zuverlässig an später joinende Spieler.
- Sprachausgabe: `D.say({tokens})` → Warteschlange → Bausteine nacheinander per `outSoundForCoalition`
  (oder `radioTransmission` bei `voice.output = "radio"`). Längen kommen aus `DynSEAD_VOICE.clips`
  (Datei `DynSEAD_voice.lua`, wird vom Trigger **vor** dem Hauptskript geladen). Fehlt sie: Stimme still aus.

## DCS-Erkenntnisse (bestätigt im Test)
- `math.randomseed` ist in der Missionsumgebung gesperrt → Zufall über variable Anzahl `math.random()`-Aufrufe
  abhängig vom Zeitpunkt des ersten Spieler-Spawns.
- `os`/`io` sind gesperrt (Nutzer will das nicht ändern, kein SRS).
- Dynamic Spawn Templates: Gruppe mit `dynSpawnTemplate = true`, Start-Wegpunkt mit `airdromeId`, Unit-Typ muss
  der **spielbare** Typ sein (`F-16C_50`, nicht `F-16C bl.50`), Skill `"Player"`, und im Warehouse des Flugplatzes
  `airports[id].aircrafts.planes|helicopters[TYP].linkDynTempl = groupId`. Bestand muss > 0 sein.
  F-16-Vorlagen funktionieren („sieht besser aus“). Neue Vorlagen ohne Parkposition → einmal im Editor speichern.
- Spielbare Typnamen: `F-16C_50`, `FA-18C_hornet`, `A-10C_2`, `AJS37`, `AH-64D_BLK_II`. Viggen nimmt nur B1–B9.

## Ungetestet / offene Punkte
1. **Sprachausgabe** (vorerst abgeschaltet: `cfg.voice.enabled = false`, Nutzer gefällt die TTS-Stimme nicht; Bausteine bleiben in der Mission,
   Menüpunkt „Overlord: Request threat picture“ entfällt). Einbau: Nutzer führt `voice/make_overlord_voice.py` aus und liefert `overlord_voice.zip`.
   Dann `python tools/miz_tool.py voice mission/Dynamic_Script.miz voice/overlord_voice.zip --radio`
   (benötigt ffmpeg; schneidet Stille, optional Funkfilter, schreibt Index + Trigger). Danach Mission **nicht**
   mehr im Editor speichern (Editor entfernt unverknüpfte WAVs) – sonst `voice` erneut ausführen.
   Ungetestet: Pfadformat `l10n/DEFAULT/ov_x.wav` für `outSoundForCoalition`, Pausen zwischen Bausteinen.
2. **Spawnen auf noch feindlichen Plätzen sperren**: Dynamic Spawn ignoriert evtl. den Besitzer. Lösung geplant:
   Warehouse-API (`Airbase:getWarehouse()`, `setItem`) – Bestand an roten Plätzen beim Start auf 0, bei Eroberung auffüllen.
   Erst klären, ob das Problem tatsächlich auftritt.
3. MiG-23-Loadouts (`D.capLoadouts`) unsicher – Skript meldet „spawned WITHOUT missiles“, dann Pylone korrigieren.
4. Vorlagen für F/A-18C, A-10C II, AJS-37 (Land Schweden), AH-64D noch nicht im Spiel getestet.
5. TACAN-Befehl der Tanker (`ActivateBeacon`) ungetestet.
6. Optional: Vorlagen auf neutrale Nation verschieben, falls sie als eigene Slots in der Slot-Liste auftauchen.
7. Keine Persistenz – Kampagne beginnt nach Server-Neustart von vorn.
8. **Ship Strike (v4.24)** ungetestet im Spiel: Schiffstypnamen (`ALBATROS`, `MOLNIYA`, `NEUSTRASH`, `Dry-cargo ship-1`, `ELNYA`), Naval-ROE-Option
   (`AI.Option.Naval.id.ROE`, Werte 2 = OPEN_FIRE / 4 = WEAPON_HOLD), Seepunkt-Suche (`land.getSurfaceType`). Fehlen Schiffe, meldet
   das Skript „only X of Y ships spawned“. Keine Sprachbausteine dafür (nur Text).
9. **Nebenaufträge (v4.24)** ungetestet im Spiel: Konvoi-Route (`On Road` über 30–70 km, wird nach 180 s ohne Bewegung abgebrochen), Typnamen
   (Hauptbasis `RPC_5N62V`/`RLS_19J6`/`S-200_Launcher`/`S-300PS …`/`1L13 EWR`/`55G6 EWR`, Bomber `Tu-95MS`/`Tu-160`, `REACTION_ON_THREAT`, Konvoi, Deep-Strike-Statik `.Command Center`/`Warehouse`/`Tank`, TIC-Einheiten), `Spot.createInfraRed`/`createLaser`, Platzhalter-Koordinaten
   in `D.cfg.deepStrike.targets`. Logik wurde nur gegen einen DCS-Mock (lupa) getestet. Keine Sprachbausteine dafür.
10. **Standortprüfung (v4.24)** ungetestet im Spiel: ob `world.searchObjects(Object.Category.SCENERY, …)` Bäume liefert (sonst nur Gebäude), Wirkung über die Zähler „siting checks“ in `dcs.log` prüfen.
11. **Vorwärts-FARP (v4.24)** ungetestet im Spiel (Test-Ergebnisse siehe unten): Ein gelandeter Hubschrauber löst im gruppenbezogenen F10-Menü „Logistics“ > „Deploy FARP here“ aus; das Skript baut
    `FARP` + Tankdepot/Munition/Zelt 60 m nördlich und erzeugt `slotsPerFarp` (4) Slot-Gruppen `FARP-n-S1…` (Skill `"Player"`, Land USA, Start `TakeOffGround`), die in der Slot-Liste erscheinen. Jeder Einstieg
    (`S_EVENT_BIRTH`) zählt den Vorrat herunter; erneute Lieferung am selben FARP (Radius 250 m, 300 s Abstand) füllt auf; „Dismantle nearest FARP“ baut ab; Kartenmarker zeigt die Restslots.
    Bewaffnung: aus einer AH-64D-Vorlage der Mission (`env.mission`), falls dort Pylone belegt sind, sonst `cfg.farp.payloads` (aktuell leer = unbewaffnet, CLSIDs fehlen noch).
    **Test-Ergebnisse (Nutzer):** per Skript gebauter FARP wird als Heliport (blau) mit Warehouse erkannt, `setItem` geht, aber **kein Dynamic-Spawn-Slot**; `coalition.addGroup` mit `skill = "Client"` wird von DCS
    abgelehnt (Fehlerobjekt = Gruppentabelle), mit `skill = "Player"` und Land USA wird die Gruppe angelegt und **erscheint in der Slot-Liste** (Pilot + Copilot/Gunner, Start „Ground“).
    Offen: ob Slots nach Tod/Verlassen des Hubschraubers wieder verschwinden, Typnamen der FARP-Objekte (`FARP`, `FARP Fuel Depot`, `FARP Ammo Dump Coating`, `FARP Tent`) funktionierten im Test.
