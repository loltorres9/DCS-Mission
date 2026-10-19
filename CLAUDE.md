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
| `src/DynSEAD.lua` | Missionsskript (aktuell v4.3). Version steht im Kopf als `DynSEAD vX.Y` |
| `mission/Dynamic_Script.miz` | aktuelle Mission (Skript v4.3 eingebettet, Briefing, 105 Spawn-Vorlagen mit Wegpunkten) |
| `tools/miz_tool.py` | CLI: `info`, `embed`, `templates`, `voice` (siehe Docstring) |
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
- `D.cfg` oben: `mode` ("airbases"/"zones"), `campaign` (activeTargets=2, samPerAO, casPerAO, Garnison),
  `sam` (maxActive=5, Typ-Pool, `engageRange`, `modesByType`, `armEvasion`, `relocate`, `pointDefense`),
  `elint`, `awacs` (Overlord E-3A 251 AM, immortal/invisible), `voice`, `tankers` (Texaco KC-135 Boom 255 AM 51Y,
  Arco KC-135MPRS Drogue 256 AM 52Y), `manpads`, `cas`, `cap` (4 Schwierigkeitsstufen, `D.capLoadouts`).
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
1. **Sprachausgabe einbauen**: Nutzer führt `voice/make_overlord_voice.py` aus und liefert `overlord_voice.zip`.
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
