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
| `src/DynSEAD.lua` | Missionsskript (aktuell v4.60). Version steht im Kopf als `DynSEAD vX.Y` |
| `mission/Dynamic_Script.miz` | aktuelle Mission (Skript v4.60 eingebettet, Briefing, **keine Flugzeuggruppen/Vorlagen** – nur Dynamic Spawn über die Warehouses). Briefing (englisch) steht im Dictionary: `DictKey_descriptionText_1` (Lage), `DictKey_descriptionBlueTask_3` (Auftrag, Support, Lagebild, SAM-Gefechtsordnung, Nebenaufträge, F10-Menü) – bei Änderungen an SAM-Typen, Menü oder Intel mitpflegen |
| `mission/Dynamic_Script_Syria.miz` | Syrien-Mission (gleiches Skript, Profil `D.cfg.maps.Syria`): **keine Vorlagen** (die früheren 492 Vorlagen an allen 82 Flugplätzen sind per `untemplate` entfernt), Dynamic Spawn über die Warehouses (F-16C, F/A-18C, A-10C II, AJS-37, AH-64D, CH-47F). Freundlich: Türkei (Incirlik u. a.), Zypern, Jordanien; Ziele: Syrien, Libanon, Israel, West-Irak (52). F10-Ansicht „All“ erzwungen, Briefing angepasst, keine Sprachdateien |
| `tools/miz_tool.py` | CLI: `info`, `embed`, `templates`, `reroute`, `untemplate`, `tplside`, `options`, `voice` (siehe Docstring); **Vorlagen entfernt** (`untemplate`: alle `dynSpawnTemplate`-Gruppen + `linkDynTempl`): ohne Zielwegpunkte (Nutzerwunsch, „Flut an Wegpunkten“) waren sie überflüssig und erschienen nur als zusätzliche Slots. `templates`/`reroute` bleiben für den Fall, dass Vorlagen wieder gebraucht werden; AO-Koordinaten zum Eintippen per F10 Info > „Navigation: AO steerpoints“ (`D.reportNav`, Briefing-Abschnitt NAVIGATION). Skripte können keine Steuerpunkte in Spielerflugzeuge schreiben. `reroute`/`templates --targets` legt optional wieder eine gemeinsame Route über alle Ziele an (`global_route`; Syria Nord→Süd in 50-km-Bändern, Caucasus Nächster-Nachbar + 2-opt; `thin` dünnt bei zu wenig Speicher aus, Zielpunkte AGL 0; F-16 laut Handbuch: ME-Wegpunkt 0 = Start, 1..n = STPT 1..n, Navigationsbereich 1–25, 26–30 Markpoints, 31–55 Geo-Linien (nur per DTC), 56–70 Bedrohungen, 81–99 Destinations (nur DTC)). Syria-Ziele = alle außer `SYRIA_FRIENDLY`; `tplside MISSION neutral|blue` verschiebt alle Vorlagen ins neutrale Land Schweiz bzw. zurück (USA/Viggen Schweden) – neutral funktioniert nicht (leere Steuerpunkte), Missionen sind blau; `options` setzt Schwierigkeitsoptionen, z. B. `optionsView=optview_all` |
| `tools/luatable.py` | Parser/Serializer für DCS-Lua-Tabellen (mission, warehouses, dictionary, mapResource) – Roundtrip getestet |
| `tools/geo.py` | Caucasus-Flugplätze (ID, Name, Lat/Lon) + Umrechnung Lat/Lon → DCS x/y (Transverse Mercator, pydcs-Parameter; ~1 km genau); `SYRIA_AIRFIELDS` (ID, Name, DCS x/y aus dem Spiel-Log). `miz_tool templates` kann beide Karten |
| `voice/make_overlord_voice.py` | erzeugt beim Nutzer per Edge-TTS (neuronale Stimme, `pip install edge-tts`, ffmpeg) die 111 WAV-Bausteine `ov_*.wav` + ZIP; Sandbox hat kein Internet |
| `voice/make_overlord_voice_elevenlabs.py` | wie oben, aber mit ElevenLabs (bessere Stimme; Key nur als Umgebungsvariable `ELEVENLABS_API_KEY`); bevorzugt |
| `voice/make_overlord_voice.ps1` | alte Variante mit Windows-Sprachausgabe (SAPI), nicht mehr bevorzugt |

## Arbeitsablauf
1. `src/DynSEAD.lua` ändern → **Version im Kopf erhöhen** (alle Vorkommen von `DynSEAD vX.Y`).
2. `python tools/miz_tool.py embed mission/Dynamic_Script.miz src/DynSEAD.lua` **und** `… embed mission/Dynamic_Script_Syria.miz src/DynSEAD.lua` (beide Missionen nutzen dasselbe Skript)
   – bettet als `DynSEAD_vX.Y.lua` ein. Neuer Dateiname ist Pflicht: der DCS-Editor behält sonst u. U.
   eine alte Kopie gleichen Namens.
3. Lua-Syntax prüfen (kein Lua-Interpreter installiert → mindestens Block/Klammer-Balance mit einem
   Tokenizer, der Strings und Kommentare korrekt überspringt; naive Regex scheitert an `'"'` in Strings).
4. Nutzer testet in DCS; Fehler erscheinen im Spiel (`showErrors = true`) und in `Saved Games\DCS\Logs\dcs.log` (Suche „DynSEAD“).

**Nie Dateien löschen, bevor die neue Version erfolgreich geschrieben ist** (einmal ist dadurch Arbeit verloren gegangen).

## Aufbau von `src/DynSEAD.lua`
- Mehrere Karten (v4.45): `D.cfg.maps[theatre]` wird nach `env.mission.theatre` gewählt (`D.theatre`, `D.map`): `homeBases` (beim Start blau), `friendlyAreas` (Lat/Lon-Rechtecke, alle Flugplätze darin blau,
  kein Ziel), `exclude`, `deepStrike` (ersetzt `cfg.deepStrike.targets`). Caucasus: leer (Startbasis aus dem Editor). Syria: Startbasis Incirlik, Türkei/Zypern/Jordanien freundlich, Eroberung Richtung Süden,
  Deep-Strike-Platzhalterziele (Damaskus, Homs, Palmyra, Deir ez-Zor, Hama). Syrien-Mission (`mission/Syria_*.miz`) folgt, sobald der Nutzer eine leere Syrien-Mission mit Vorlagen an Incirlik liefert;
  F10 DEBUG > „Write airfield list to dcs.log“ schreibt alle Flugplätze mit ID und Koordinaten (Zeilen „DynSEAD AIRFIELD“) – Grundlage für `SYRIA_AIRFIELDS` in `tools/geo.py`.
  Syria meldet ~140 Hubschrauber-Landeplätze (HS02, HMed01, H_med_orig_03, HOil01 …) als AIRDROME: `D.map.ignore` (Lua-Muster) bzw. `D.ignoredBase(ab)` blendet sie überall aus (Ziele, blaue Basen, Konvoi/Bomber/Battle, Schiffe).
  `friendly` = Türkei- und Jordanien-Plätze per Namen, Zypern per Rechteck.
  Fronten (v4.45, `D.map.fronts`, nur Syria): „North“ (Türkei-Plätze) und „South“ (Jordanien-Plätze) mit je `active = 2` Zielen; `D.nextTarget(front)` nimmt das nächste Ziel zu den Basen der Front plus deren Eroberungen (`front.pos`),
  `ao.front` merkt die Front, Meldungen/Status nennen sie. Ohne `fronts` (Caucasus) gilt wie bisher `campaign.activeTargets`.
  Tanker (v4.45, `D.map.tankers` ersetzt `tankers.list`; `track = {lat1, lon1, lat2, lon2}`): ohne `front` feste Strecke, mit `front` rückt der Tanker mit dieser Front vor
  (Strecke hinter der Front-AO, die den eigenen Basen am nächsten ist, Richtung nächste Front-Basis). Alle Tanker (auch Caucasus) bleiben außerhalb der Reichweite jeder SAM-Stellung
  (`sam.engageRange` + `tankers.samMargin` 20 km; AOs mit noch ungebauten SAMs zählen mit AO-Radius + 45 km); `D.repositionTankers` prüft alle `checkInterval` (60 s) und verlegt bei > 10 km Abweichung.
  Syria: Syria Texaco (Boom, 255.0, 51Y) und Arco (Korb, 256.0, 52Y) über dem Mittelmeer südöstlich von Zypern,
  Shell (Boom, 257.0, 53Y) und Arco2 (Korb, Rufzeichen Arco 2-1, 258.0, 54Y) im Norden auf türkischer Seite der Grenze (Lat 37,25/37,40, Lon 36,6–37,6), Texaco2 (Boom, Rufzeichen Texaco 2-1, 259.0, 55Y) und Arco3 (Korb, Arco 3-1, 260.0, 56Y) im Süden über Jordanien (Lat 32,00/31,85, Lon 36,9–37,9). Syrien-Briefing (SUPPORT) entsprechend.
- `D.cfg` oben: `mode` ("airbases"/"zones"), `campaign` (activeTargets=2, samPerAO, casPerAO, Garnison, `aoSeparation` = Mindestabstand gleichzeitig aktiver AOs, damit sich die Kreise nicht überlappen; sonst wird gewartet),
  `sam` (maxActive=5, Typ-Pool, `classes` (v4.46: jede AO bekommt über `D.nextSamKey(ao)` mindestens eine Mittelstrecke SA-2/3/6/11 und eine Kurzstrecke SA-8/15, Rest frei aus `pool`), `engageRange`, `modesByType`, `armEvasion`, `relocate`, `pointDefense`),
  `awacs` (Overlord E-3A 251 AM, immortal/invisible), `voice`, `tankers` (Texaco KC-135 Boom 255 AM 51Y,
  Arco KC-135MPRS Drogue 256 AM 52Y), `manpads`, `cas`, `cap` (4 Schwierigkeitsstufen, `D.capLoadouts`; v4.52: bis `maxActive` = 4 Gruppen gleichzeitig, auch gleicher Typ; F10 A2A > „Patrol the AO“ (Racetrack in einer AO, Luftziele bis 80 km) oder „Hunt nearest player“ (`D.capHuntRoute` alle `huntUpdate` 30 s Route zum nächsten Spieler in der Luft, ohne Spieler Kreisen), „Remove all enemy CAPs“; v4.53 „Respawning CAP: toggle ON/OFF“ (`cap.persistent`, `D.spawnPersistentCAP`/`D.capPersistTick`): `groups` (1) Gruppen der aktuellen Stufe starten per `TakeOff`/„From Runway“ vom roten Flugplatz (≥ `minBlueDist` 60 km von blauen Basen), der einer aktiven AO am nächsten ist (sonst Luftstart), Racetrack quer vor der nächsten AO; nach Verlust Neustart nach `respawnDelay` 5–10 min; gelandete oder nach `stuckTimeout` 900 s nie gestartete Gruppen werden entfernt und ersetzt; zählen nicht gegen `maxActive`; Startbahnstart im Spiel ungetestet).
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
- Frontline Battle (`cfg.battle`, F10 Side Missions > Frontline Battle): KI-gegen-KI-Panzerschlacht, Blau 30 Fahrzeuge (M-60, Bradley, M-113, HMMWV; Skill Average), Rot 36 (T-72B3, BMP-3/2, BTR-82A, Shilka; Skill Excellent), Gruppen à 6 – Rot ist bewusst überlegen (erster Test: Blau mit Abrams gewann haushoch), Mitte 4–12 km vom Ziel-Flugplatz einer aktiven AO (ohne aktive AO: einer der 3 feindlichen Flugplätze, die einer blauen Basis am nächsten sind),
  Linien 2,2–3 km auseinander. Beide Seiten warten mit ROE WEAPON_HOLD, bis ein Spieler ≤ `activateRange` (20 km) an der Mitte ist, dann ROE OPEN_FIRE und Vormarsch (v4.45).
  Solange ein Spieler in der Nähe ist, kommen je Seite bis zu `waves` (3) Verstärkungswellen à 3 Gruppen, sobald die Seite unter 40 % ihrer Grundstärke fällt (Abstand ≥ 180 s).
  Besiegt ist eine Seite erst, wenn ihre Wellen verbraucht sind und nur noch 15 % der Grundstärke übrig sind (Sieg zählt in `stats.battle`); 45 min nach Kampfbeginn unentschieden; ohne Spieler nach 2 h abgebaut.
  Kartenmarker „FRONTLINE BATTLE“, `autoSpawn` standardmäßig aus. Typnamen (`M-1 Abrams`, `M-113`, `BRDM-2` …) und Verhalten der KI im Spiel ungetestet.
- Eroberungsregeln (v4.47): Garnison muss ganz zerstört werden (`campaign.garrisonPercent = 100`), SAM-Stellungen erst, wenn **alle** Einheiten zerstört sind (`sam.killAll`, v4.49): Radare, Gefechtsstände, Startgeräte, Nahbereichsflak/SHORAD der Gruppe und die Punktverteidigung (seit v4.48 SA-8 statt SA-15, bei 40 % der SA-2/3/6/11-Stellungen, Name in `site.critical`). Nachzügler-Regel `campaign.straggler = {maxLeft = 1, timeout = 1200}`: bleibt höchstens 1 relevante Einheit übrig, Meldung „1 unit left – counts as destroyed in 20 min“, danach gilt Stellung/Garnison als zerstört und der Rest wird entfernt (`D.stragglerDone`). MANPADS zählen nicht für die Eroberung (waren nie Bedingung), CAS-Ziele wie bisher 70 %. Briefing beider Missionen entsprechend.
- SAM-Hinterhalte (v4.54, `cfg.ambush`, `D.spawnAmbush`/`D.ambushTick`/`D.ambushSpotOk`; Nutzer: „Karte nicht lebendig genug, außerhalb der Zonen kein Risiko“): alle `interval` 10–20 min bis `maxActive` 3 einzelne Stellungen (v4.56 nur ältere Radar-SAMs, keine IR-Systeme (Nutzerwunsch): Pool SA-3 3, SA-2 2, SA-6 2, ohne Punktverteidigung) im Modus `ambush`, 8–40 km um einen zufälligen roten Flugplatz, nur **hinter** den aktiven AOs (Abstand zur nächsten blauen Basis ≥ der der nächsten AO + Radius + 15 km, außerhalb aller AO-Kreise + 15 km, ≤ 250 km von Blau, nicht an der Hauptbasis/TIC-Zonen). Eigene Pseudo-AO je Stellung (`ao.ambush`), zählen nicht gegen `sam.maxActive`, nicht im Lagebild, nicht für die Eroberung; nach `lifetime` 60–120 min abgebaut, wenn kein Spieler ≤ 60 km. Keine Meldung. DEBUG > „Spawn SAM ambush now“. Briefing (ORDER OF BATTLE, „Pop-up threats“) in beiden Missionen.
- Schwere Flak (v4.57, `sam.aaa = {chance = 0.6, pool}`): mit 60 % bekommt eine AO zusätzlich eine Batterie `AAA100` (4x `KS-19` + 2x `SON_9` Fire Can) oder `AAA57` (6x `S-60_Type59_Artillery` + 1x `SON_9`); `ao.aaaKey`, `ao.samLeft + 1`, kommt über den Plan in `D.nextSamKey`; zählt wie eine SAM-Stellung (Lagebild, Eroberung, killAll). Typnamen ungetestet.
- Chaos im Feindgebiet (v4.57, `cfg.chaos`, `D.chaosTick`; Nutzer: „Syrien der 2010er, viel Chaos“): `skirmish` (bis 3 kleine KI-Gefechte, je 4–6 Fahrzeuge, blau US-Gerät Bradley/Stryker/HMMWV/M-113 vs. rot T-72B/T-55/BMP-2/BTR-80, nur hinter den AOs wie die Hinterhalte (`D.ambushSpotOk`), rücken langsam vor, Ende 5 min nach Vernichtung einer Seite oder nach 30–60 min ohne Spieler in 20 km); `helos` (bis 2 Mi-8MT, v4.59 nur Mi-8 und unbewaffnet: leere Pylone, `gun = 0`, Luftstart über rotem Platz, Landung auf anderem rotem Platz 30–150 km, ROE WEAPON_HOLD, Ersatz nach Landung/Verlust; F10 A2A > „Enemy helicopters: toggle ON/OFF“, aus = vorhandene entfernt, `D.heloOn`). Zivilverkehr gab es in v4.57 kurz, auf Nutzerwunsch in v4.58 wieder entfernt. Briefing-Abschnitt BATTLEFIELD in beiden Missionen. Im Spiel ungetestet.
- Scud-Jagd (v4.60, `cfg.scud`, `D.spawnScud`/`D.scudTick`/`D.scudOnShot`): alle 30–60 min (nach Ende des vorigen) ein `Scud_B` + `Ural-375` + `UAZ-469` im Hinterland (`D.ambushSpotOk`, 80–280 km vor der nächsten blauen Basis = Ziel); Overlord meldet Suchkreis 20 NM (orange, `circleToAll`, Werfer irgendwo darin) und Ziel; nach `setupTime` 20–25 min `FireAtPoint` (echte Rakete, `expendQty` 1) auf den Platz; Abschuss per `S_EVENT_SHOT` (Gruppe = Scud) gemeldet; kommt nach `fireTimeout` 480 s kein Abschuss, wird der Einschlag mit `trigger.action.explosion` (800) nachgestellt. Werfer vorher zerstört = Erfolg (`stats.scud`). F10 Side Missions > „SCUD hunt: status“, DEBUG > „Spawn Scud now“ (feuert nach 3 min). Ob `Scud_B` per FireAtPoint im Spiel wirklich startet: ungetestet.
- CSAR (v4.60, `cfg.csar`, `D.spawnCsar`/`D.csarTick`/`D.csarOnEject`): Spieler-Schleudersitz über Feindgebiet (`S_EVENT_EJECTION`, Pilot nach 60 s am Boden) oder alle 45–90 min ein Verbündeter am Rand einer aktiven AO (eigene Seite); Pilot `Soldier M4` (blau) + Kartenmarker, 1–2 Feindgruppen (BTR-80/UAZ/BRDM-2) starten 4–7 km entfernt und fahren mit 2,5 m/s auf ihn zu (≤ 150 m = gefangen); gelandeter Spieler-Hubschrauber ≤ 80 m = an Bord, Landung ≤ 3 km an blauer Basis oder FARP = gerettet (`stats.csar`); grüner Rauch, wenn ein Heli ≤ 6 km ist (alle 5 min). Timeout 2 h. F10 Side Missions > CSAR (Status, Rauch), DEBUG > „Spawn CSAR now“. Side Missions jetzt mit Untermenüs (Convoy, Deep Strike, Bomber Intercept, Frontline Battle, TIC/JTAC, CSAR) + „SCUD hunt: status“.
- Es gibt keine SAM-Standortinfos mehr: kein ELINT, keine Kartenmarker, keine Meldungen/AWACS-Ansagen zu SAM-Positionen, Die Spieler müssen SAMs selbst finden.
  Stattdessen gibt es pro AO ein Lagebild (`D.aoThreats`): SAM-Typen mit Anzahl und MANPADS ja/nein, keine Positionen. Es kommt automatisch, sobald alle SAMs einer AO stehen, und per F10 Info > „Threats: SAMs & MANPADS per AO“.
  MANPADS-Zonen spawnen weiter, aber ohne Kartenkreise und ohne Positionsmeldung.
  `sam.spawnAll = true` / `cas.spawnAll = true`: alle SAM-Stellungen und CAS-Ziele einer AO erscheinen sofort beim Aktivieren (Garnison und MANPADS ohnehin; Limits `sam.maxActive` = 12, `cas.maxActive` = 10).
- Testhilfe: `cfg.debugShowAll` (standardmäßig aus) bzw. F10 „DEBUG: Show all units on map“ zeichnet alle Gruppen beider Seiten
  (ohne Spielergruppen) als Marker auf die F10-Karte, Aktualisierung alle `debugMapInterval` s.
- F10-Menü: DCS zeigt pro Ebene nur etwa 10 Einträge, daher sind alle Befehle in Untermenüs gruppiert (Info, CAS, A2A, Ship Strike,
  Side Missions mit Frontline Battle und TIC/JTAC, DEBUG), höchstens 8 Einträge pro Ebene. Neue Befehle in ein passendes Untermenü, nicht an die Wurzel.
- Rote Bodengruppen (SAM, Garnison, CAS, Konvoi, TIC-Feinde …) werden mit `hidden = D.hideOnMap()` gespawnt: `hidden = true` versteckt sie auf der
  F10-Karte **unabhängig** von der Option „F10 View Options: All“. `cfg.debugVisibleUnits = true` zeigt sie für alle Spieler (aktuell an, zum Testen); für den echten Spielbetrieb auf `false`.
- Missionsoptionen, die die Mission selbst durchsetzt, stehen in `mission.forcedOptions` (Datei `mission`); die Datei `options` enthält nur die lokalen
  Einstellungen des zuletzt speichernden Nutzers und wirkt nicht. setzt man mit `python tools/miz_tool.py options MISSION.miz optionsView=optview_all --forced`, entfernen mit `optionsView= --forced`.
  Die Mission erzwingt `optionsView = optview_all` (F10 View „All“; im Editor: Mission Options > Enforce). Ohne Erzwingen galt im Spiel trotz Gameplay-Einstellung „All“ eine
  andere Ansicht: auf der Karte erschienen nur feindliche Radare (von der eigenen Seite erfasst), keine Werfer, Garnisonen oder CAS-Ziele. Für den echten Spielbetrieb ggf. wieder entfernen.
- SAM-/Radar-Standorte (`D.samSpotClear`, `cfg.siting`): nicht in Editor-Trigger-Zonen `NOSAM*`; Gelände: Hangneigung ≤ 6° (8 Richtungen auf 150 m) und Horizont (Berge ≥ 6° Erhebung
  in ≥ 3 von 8 Richtungen bei 1,5/3/5 km blockieren); Bebauung: nicht direkt neben Gebäuden (`world.searchObjects(SCENERY)` im Umkreis `sceneryRadius` = 150 m), nicht zwischen
  ≥ 10 Objekten im Umkreis 400 m und nicht neben Objekten ≥ 12 m Höhe (aus `getDesc().box`) im Umkreis 300 m. DCS hat keine Wald-Abfrage: Bäume werden nur erkannt, falls sie als Szenerie-Objekte geliefert werden; große Wälder sperrt man per `NOSAM`-Zone.
  Straßennähe (v4.45, `siting.nearRoad`): da Wälder nicht abfragbar sind, verschiebt `D.nearRoad(p, maxShift)` SAM-Standorte 60–250 m neben die nächste Straße (`land.getClosestPointOnRoads`),
  im ersten Durchlauf von `D.findSpot` (max. 6 km Verschiebung), bei Hauptbasis-Schichten und Stellungswechseln (max. 1,5 km). Im Spiel bestätigt: deutlich weniger Waldstandorte.
  Die Prüfung gilt nur im ersten Durchlauf von `D.findSpot` (weich, blockiert nie), auch für Hauptbasis-Schichten und Stellungswechsel. `dcs.log` zeigt pro Stellung die Zähler
  „siting checks“ (Wirkung prüfbar).
- Keine einzelnen Infanteristen: Einzelpersonen sind schwer zu finden, daher spawnen Garnison, CAS, TIC (auch die Verbündeten) und Deep-Strike-Schutz nur
  Fahrzeuge. Ausnahme MANPADS (`SA-18 Igla manpad`): daneben parkt ein `UAZ-469` (Marker für die Suche, 6 m Abstand).
- Spawns per `coalition.addGroup` mit selbst gebauten Gruppentabellen (Land `CJTF_RED` / `CJTF_BLUE`). Bodengruppen immer über `D.addGround(country, data)` (ergänzt Gruppen-x/y, Startwegpunkt und Editor-Felder).
- Hauptschleife `D.update` alle 10 s; ARM-Tracking `D.armTick` jede Sekunde; `D.voiceTick` alle 0,5 s.
- SAM-Radar = `ALARM_STATE` RED/GREEN. Modi: always / blink / ambush (typabhängige Auslöse-Reichweite).
- ARM-Abwehr: Rakete wird verfolgt, Zielzuordnung über `getTarget()` sonst horizontale Flugrichtung;
  Entdeckung pro Sekunde abhängig von Sichtlinie (`land.isVisible`), Höhe über Grund, Reichweite, Start bemerkt;
  danach Reaktionszeit, Unterdrückung 40–90 s, mobile Systeme ziehen evtl. 2–6 km um. v4.50 (Nutzer: SAMs wichen zu oft/zu lange aus): Entdeckungsraten pro s 0,005–0,012 (≈ 25–50 % Erkennung je ARM), `launchAlert` 0,3, `alertMultiplier` 2, `maxEvasions` 1 je Stellung (v4.51, Nutzerwunsch: Radar höchstens 1x zum Ausweichen aus), Stellungswechsel nach ARM 20–35 %, im Blink-Modus 5–10 %.
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
  Vorlagen sind fürs Spawnen nicht nötig: Dynamic Spawn erlaubt jeden Typ mit Lagerbestand > 0; die Vorlage legt nur Startzustand und Wegpunkte fest (fehlt sie, spawnt der Typ ohne Route).
  F-16-Vorlagen funktionierten; Vorlagen müssen in der eigenen Koalition liegen (neutral → leere Steuerpunkte). Seit dem Entfernen der Vorlagen spawnt jeder Typ im Standardzustand ohne Route (Nutzerwunsch).
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
4. Ohne Vorlagen ungetestet: ob alle Typen (auch AJS-37, CH-47F) an allen blauen Plätzen per Dynamic Spawn erscheinen und welcher Startzustand (kalt/heiß) gilt.
5. TACAN-Befehl der Tanker (`ActivateBeacon`) ungetestet.
6. **Vorlagen aus der Slot-Liste:** neutral verschieben scheiterte (leere Steuerpunkte); gelöst durch Entfernen aller Vorlagen (`untemplate`).
7. **Kampagnenstand speichern (v4.45, `cfg.persistence`)** ungetestet im Spiel: (a) Datei `lfs.writedir()..DynSEAD_save_<Karte>.txt` (einfaches Textformat: fortress, captured=Name|Front, stat=…),
   geschrieben nach jeder Eroberung und alle 120 s, beim Missionsstart gelesen (`D.initPersistence` → `D.applySave`). Braucht auf dem Server in `Scripts\MissionScripting.lua` auskommentiertes
   `sanitizeModule('io')` und `sanitizeModule('lfs')` (jedes DCS-Update setzt das zurück); ohne io/lfs nur Code. (b) Spielstand-Code (Kartenbuchstabe + Hauptbasis-Index + Bitmaske über die sortierte
   Liste aller Kampagnenplätze `D.campaignList` + Prüfzeichen, Base32 ohne I/O/0/1), angezeigt nach jeder Eroberung und unter F10 Info > „Campaign: save code“; Laden per F10-Kartenmarker „LOAD <Code>“
   (`S_EVENT_MARK_ADDED/CHANGE`), auch mitten im Spiel: aktive AOs werden aufgegeben und neu gewählt; nicht während die Hauptbasis aktiv ist. Statistik nur in der Datei. „Campaign: reset saved progress“
   (zweimal wählen) leert die Datei. Code ist nur gültig, solange sich Zielliste/Konfiguration der Karte nicht ändert. Briefing (SAVING THE CAMPAIGN) in beiden Missionen.
8. **Ship Strike (v4.45)** ungetestet im Spiel: Schiffstypnamen (`ALBATROS`, `MOLNIYA`, `NEUSTRASH`, `Dry-cargo ship-1`, `ELNYA`), Naval-ROE-Option
   (`AI.Option.Naval.id.ROE`, Werte 2 = OPEN_FIRE / 4 = WEAPON_HOLD), Seepunkt-Suche (`land.getSurfaceType`). Fehlen Schiffe, meldet
   das Skript „only X of Y ships spawned“. Keine Sprachbausteine dafür (nur Text).
9. **Nebenaufträge (v4.45)** ungetestet im Spiel: Konvoi-Route (`On Road` über 30–70 km, wird nach 180 s ohne Bewegung abgebrochen), Typnamen
   (Hauptbasis `RPC_5N62V`/`RLS_19J6`/`S-200_Launcher`/`S-300PS …`/`1L13 EWR`/`55G6 EWR`, Bomber `Tu-95MS`/`Tu-160`, `REACTION_ON_THREAT`, Konvoi, Deep-Strike-Statik `.Command Center`/`Warehouse`/`Tank`, TIC-Einheiten), `Spot.createInfraRed`/`createLaser`, Platzhalter-Koordinaten
   in `D.cfg.deepStrike.targets`. Logik wurde nur gegen einen DCS-Mock (lupa) getestet. Keine Sprachbausteine dafür.
10. **Standortprüfung (v4.45)** ungetestet im Spiel: ob `world.searchObjects(Object.Category.SCENERY, …)` Bäume liefert (sonst nur Gebäude), Wirkung über die Zähler „siting checks“ in `dcs.log` prüfen.
11. **Vorwärts-FARP (v4.45)** ungetestet im Spiel (Test-Ergebnisse siehe unten): Ein gelandeter Hubschrauber löst im gruppenbezogenen F10-Menü „Logistics“ > „Deploy FARP here“ aus; das Skript baut
    `FARP` + Tankdepot/Munition/Zelt 60 m nördlich und erzeugt `slotsPerFarp` (4) Slot-Gruppen `FARP-n-S1…` (Skill `"Player"`, Land USA, Start `TakeOffGround`), die in der Slot-Liste erscheinen. Jeder Einstieg
    (`S_EVENT_BIRTH`) zählt den Vorrat herunter; erneute Lieferung am selben FARP (Radius 250 m, 300 s Abstand) füllt auf; „Dismantle nearest FARP“ baut ab; Kartenmarker zeigt die Restslots.
    Bewaffnung: aus einer AH-64D-Gruppe der Mission (`env.mission`, derzeit keine vorhanden), falls dort Pylone belegt sind, sonst `cfg.farp.payloads` (aktuell leer = unbewaffnet, CLSIDs fehlen noch).
    **Test-Ergebnisse (Nutzer):** per Skript gebauter FARP wird als Heliport (blau) mit Warehouse erkannt, `setItem` geht, aber **kein Dynamic-Spawn-Slot**; `coalition.addGroup` mit `skill = "Client"` wird von DCS
    abgelehnt (Fehlerobjekt = Gruppentabelle), mit `skill = "Player"` und Land USA wird die Gruppe angelegt und **erscheint in der Slot-Liste** (Pilot + Copilot/Gunner, Start „Ground“).
    Offen: ob Slots nach Tod/Verlassen des Hubschraubers wieder verschwinden, Typnamen der FARP-Objekte (`FARP`, `FARP Fuel Depot`, `FARP Ammo Dump Coating`, `FARP Tent`) funktionierten im Test.
