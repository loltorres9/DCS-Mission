#!/usr/bin/env python3
"""
miz_tool.py – Werkzeuge für die DynSEAD-Mission (.miz = ZIP mit Lua-Tabellen)

  python tools/miz_tool.py info      MISSION.miz
  python tools/miz_tool.py embed     MISSION.miz src/DynSEAD.lua            [-o OUT.miz]
  python tools/miz_tool.py templates MISSION.miz --base "TPL F-16 Senaki-Kolkhi" [--keep] [-o OUT.miz]   (Caucasus, Syria)
  python tools/miz_tool.py reroute   MISSION.miz [-o OUT.miz]   Wegpunkte aller Vorlagen neu: eine gemeinsame Route über alle Ziele
  python tools/miz_tool.py tplside   MISSION.miz neutral|blue [-o OUT.miz]   Vorlagen in neutrales Land (Schweiz) verschieben / zurück
  python tools/miz_tool.py options   MISSION.miz optionsView=optview_all --forced [-o OUT.miz]
  python tools/miz_tool.py voice     MISSION.miz overlord_voice.zip [--radio [1-3]] [-o OUT.miz]

Ohne -o wird die Eingabedatei überschrieben (vorher wird eine .bak angelegt).
Benötigt nur Python 3 (voice zusätzlich ffmpeg im PATH).
"""
import argparse, copy, io, math, os, re, shutil, subprocess, sys, tempfile, wave, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luatable import parse, dump
from geo import ll_to_dcs, AIRFIELDS, SYRIA_AIRFIELDS, SYRIA_FRIENDLY

MAIN_SCRIPT_PREFIX = "DynSEAD"          # eingebettetes Hauptskript: DynSEAD_vX.Y.lua
VOICE_INDEX = "DynSEAD_voice.lua"

# ----------------------------------------------------------------- miz I/O
class Miz:
    def __init__(self, path):
        self.path = path
        with zipfile.ZipFile(path) as z:
            self.files = {n: z.read(n) for n in z.namelist() if not n.endswith("/")}
        self._tables = {}

    def table(self, name):                       # "mission", "warehouses", "l10n/DEFAULT/dictionary", ...
        if name not in self._tables:
            self._tables[name] = parse(self.files[name].decode("utf-8"))
        return self._tables[name][1]

    def save(self, out=None):
        for name, (var, val) in self._tables.items():
            self.files[name] = dump(var, val).encode("utf-8")
        out = out or self.path
        if out == self.path:
            shutil.copy2(self.path, self.path + ".bak")
        order = ["mission", "options", "warehouses", "theatre"]
        names = [n for n in order if n in self.files] + sorted(n for n in self.files if n not in order)
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
            for n in names:
                z.writestr(n, self.files[n])
        open(out, "wb").write(buf.getvalue())
        print("gespeichert:", out)

    def next_reskey(self):
        m = self.table("mission")
        m["currentKey"] = m.get("currentKey", 0) + 1
        return "ResKey_Action_%d" % m["currentKey"]

# ----------------------------------------------------------------- helpers
def theatre(miz):
    return miz.files.get("theatre", b"").decode().strip()

def blue_groups(m, sides=("blue",)):
    for side in sides:
        for c in m["coalition"][side].get("country", {}).values():
            for cat in ("plane", "helicopter"):
                for g in c.get(cat, {}).get("group", {}).values():
                    yield c, cat, g

ALL_SIDES = ("blue", "red", "neutrals")         # Vorlagen können nach tplside neutral liegen

def airfield_table(th):
    """{id: (name, x, y)} für die Karte; Caucasus aus Lat/Lon berechnet, Syria aus dem DCS-Log"""
    if th == "Caucasus":
        return {i: (n,) + ll_to_dcs(la, lo) for i, (n, la, lo) in AIRFIELDS.items()}
    if th == "Syria":
        return dict(SYRIA_AIRFIELDS)
    return {}

def target_ids(th, table, home):
    """Kampagnenziele der Karte (für die Wegpunkte der Vorlagen)"""
    if th == "Syria":
        return [i for i in table if i not in SYRIA_FRIENDLY]
    return [i for i in table if i not in home]

def global_route(th, table, targets, home):
    """Eine gemeinsame Route über alle Ziele; wer weiter hinten startet, fliegt sie rückwärts.
    Syria: Nord -> Süd in Bändern; sonst Kette nächster Nachbarn ab der Startbasis, danach 2-opt gegen Überkreuzungen."""
    if th == "Syria":                            # zwei Fronten: streng Nord -> Süd in 50-km-Bändern, abwechselnd W->O / O->W
        bands = {}
        for t in targets: bands.setdefault(int(-table[t][1] // 50000), []).append(t)
        route = []
        for n, b in enumerate(sorted(bands)):
            route += sorted(bands[b], key=lambda t: table[t][2], reverse=(n % 2 == 1))
        return route
    anchor = min(home) if home else min(table)
    d = lambda a, b: math.hypot(table[a][1] - table[b][1], table[a][2] - table[b][2])
    todo = set(targets); cur = anchor; route = []
    while todo:
        cur = min(todo, key=lambda t: d(cur, t)); route.append(cur); todo.remove(cur)
    better = True
    while better:                                # 2-opt für einen offenen Pfad (Anfang bleibt fest)
        better = False
        for i in range(0, len(route) - 2):
            for j in range(i + 2, len(route)):
                a, b = (anchor if i == 0 else route[i - 1]), route[i]
                c = route[j]; e = route[j + 1] if j + 1 < len(route) else None
                old = d(a, b) + (d(c, e) if e else 0)
                new = d(a, c) + (d(b, e) if e else 0)
                if new < old - 1:
                    route[i:j + 1] = reversed(route[i:j + 1]); better = True
    return route

def thin(route, k):
    """k Punkte gleichmäßig über die ganze Route verteilt (für Muster mit wenigen Wegpunkten)"""
    if len(route) <= k: return list(route)
    if k <= 1: return route[:k]
    return [route[round(i * (len(route) - 1) / (k - 1))] for i in range(k)]

def route_points(af, route, table, wname, alt, alt_type, spd, maxwp):
    """Wegpunkte 2..n: die gemeinsame Route (ohne den eigenen Startplatz), bei zu wenig Speicher gleichmäßig ausgedünnt"""
    pts = {}
    for n, t in enumerate(thin([t for t in route if t != af], maxwp), start=2):
        pts[n] = {"alt": alt, "action": "Turning Point", "alt_type": alt_type, "speed": spd,
                  "task": {"id": "ComboTask", "params": {"tasks": {}}}, "type": "Turning Point",
                  "ETA": 0, "ETA_locked": False, "x": table[t][1], "y": table[t][2], "speed_locked": True,
                  "formation_template": "", "name": wname(table[t][0])}
    return pts

def campaign_order(home, table):
    pos = {i: (x, y) for i, (n, x, y) in table.items()}
    d = lambda a, b: math.hypot(pos[a][0] - pos[b][0], pos[a][1] - pos[b][1])
    home = [h for h in home if h in pos]
    blue, todo, order = set(home), set(pos) - set(home), []
    while todo:                                  # wie D.nextTarget() im Skript: nächster zu einer blauen Basis
        nxt = min(todo, key=lambda t: min(d(t, b) for b in blue))
        order.append(nxt); blue.add(nxt); todo.remove(nxt)
    return order, pos

# ----------------------------------------------------------------- info
def cmd_info(a):
    miz = Miz(a.miz)
    m, w = miz.table("mission"), miz.table("warehouses")
    print("Karte:", theatre(miz))
    res = miz.table("l10n/DEFAULT/mapResource")
    print("Ressourcen:", len(res))
    for k, v in sorted(res.items()):
        if v.endswith(".lua"): print("   %s -> %s" % (k, v))
    print("Trigger beim Start:", m["trig"]["actions"].get(1))
    print("\nFlugplätze:")
    table = airfield_table(theatre(miz))
    for i, ap in sorted(w["airports"].items()):
        if theatre(miz) == "Syria" and i not in table: continue   # Hubschrauber-Landeplätze ausblenden
        name = table.get(i, ("?",))[0]
        links = []
        for cat in ("planes", "helicopters"):
            for t, e in ap["aircrafts"][cat].items():
                if "linkDynTempl" in e: links.append(t)
        print("  %2d %-22s %-8s dyn=%s  Vorlagen: %s" % (i, name, ap.get("coalition"), ap.get("dynamicSpawn"), ", ".join(links) or "-"))
    n = sum(1 for _ in blue_groups(m))
    print("\nBlaue Gruppen:", n, "| Vorlagen (alle Seiten): %d" % sum(1 for _, _, g in blue_groups(m, ALL_SIDES) if g.get("dynSpawnTemplate")))

# ----------------------------------------------------------------- embed
def cmd_embed(a):
    src = open(a.lua, encoding="utf-8").read()
    mv = re.search(r"DynSEAD v(\d+(?:\.\d+)*)", src)
    if not mv: sys.exit("Versionskennung 'DynSEAD vX.Y' im Skriptkopf fehlt")
    fname = "%s_v%s.lua" % (MAIN_SCRIPT_PREFIX, mv.group(1))
    miz = Miz(a.miz)
    res = miz.table("l10n/DEFAULT/mapResource")
    keys = [k for k, v in res.items() if v.startswith(MAIN_SCRIPT_PREFIX) and v.endswith(".lua") and v != VOICE_INDEX]
    if len(keys) != 1: sys.exit("Erwarte genau ein eingebettetes DynSEAD-Skript, gefunden: %s" % keys)
    old = res[keys[0]]
    miz.files.pop("l10n/DEFAULT/" + old, None)
    miz.files["l10n/DEFAULT/" + fname] = src.encode("utf-8")
    res[keys[0]] = fname
    print("%s: %s -> %s" % (keys[0], old, fname))
    miz.save(a.out)

# ----------------------------------------------------------------- templates
# max. WP = Zielpunkte nach dem Startpunkt: F-16 Route STPT 1–24 (25 = Bullseye), F/A-18 WP 0–59, Viggen B1–B9,
# AH-64D W01–W50, CH-47F angenommen wie AH-64D; reicht der Speicher nicht, wird die Route gleichmäßig ausgedünnt
TYPES = [  # typ, Kategorie, Gruppen-Task, Land(id,name), Höhe m, Höhentyp, Speed m/s, max. WP, Sprit kg, Label
    ("F-16C_50",      "planes",      "CAP",           (2, "USA"),     7620, "BARO",  220.97, 23, 3104, "F-16"),
    ("FA-18C_hornet", "planes",      "CAP",           (2, "USA"),     7620, "BARO",  220.97, 59, 4900, "F/A-18C"),
    ("A-10C_2",       "planes",      "CAS",           (2, "USA"),     4572, "BARO",  150.0,  99, 5029, "A-10C II"),
    ("AJS37",         "planes",      "Ground Attack", (46, "Sweden"), 3000, "BARO",  220.97,  9, 4476, "AJS-37"),
    ("AH-64D_BLK_II", "helicopters", "CAS",           (2, "USA"),      150, "RADIO",  55.0,  49, 1438, "AH-64D"),
    ("CH-47Fbl1",     "helicopters", "Transport",     (2, "USA"),      150, "RADIO",  60.0,  49, 3600, "CH-47F"),   # nur, wenn das Lager den Typ führt
]

def cmd_templates(a):
    miz = Miz(a.miz)
    table = airfield_table(theatre(miz))
    if not table: sys.exit("Keine Flugplatztabelle (tools/geo.py) für Karte %s" % theatre(miz))
    m, w = miz.table("mission"), miz.table("warehouses")
    dic = miz.table("l10n/DEFAULT/dictionary")
    base = [g for _, _, g in blue_groups(m) if g["name"] == a.base]
    if not base: sys.exit("Basis-Vorlage '%s' nicht gefunden" % a.base)
    base = copy.deepcopy(base[0])
    home = [i for i, ap in w["airports"].items() if ap.get("coalition", "").upper() == "BLUE"]
    order, pos = campaign_order(home, table)
    name = {i: v[0] for i, v in table.items()}
    targets = target_ids(theatre(miz), table, home)
    route = global_route(theatre(miz), table, targets, home)

    # alte Vorlagen entfernen (alle blauen Gruppen mit dynSpawnTemplate); --keep: behalten, belegte Plätze überspringen
    for c in ([] if a.keep else m["coalition"]["blue"]["country"].values()):
        for cat in ("plane", "helicopter"):
            grp = c.get(cat, {}).get("group", {})
            keep = [g for g in grp.values() if not g.get("dynSpawnTemplate")]
            if cat in c: c[cat]["group"] = {i + 1: g for i, g in enumerate(keep)}
    for ap in ([] if a.keep else w["airports"].values()):
        for cat in ("planes", "helicopters"):
            for e in ap["aircrafts"][cat].values(): e.pop("linkDynTempl", None)

    gid = max([g["groupId"] for _, _, g in blue_groups(m, ALL_SIDES)] + [0])
    uid = max([g["units"][1]["unitId"] for _, _, g in blue_groups(m, ALL_SIDES)] + [0])
    stn = 0o200
    def wname(text):
        m["maxDictId"] += 1
        k = "DictKey_WptName_%d" % m["maxDictId"]; dic[k] = text; return k
    def country(cid, cname):
        cs = m["coalition"]["blue"]["country"]
        for c in cs.values():
            if c["id"] == cid: return c
        c = {"id": cid, "name": cname}; cs[len(cs) + 1] = c; return c

    total = 0
    for (typ, cat, task, (cid, cname), alt, alt_type, spd, maxwp, fuel, label) in TYPES:
        if a.types and label not in a.types and typ not in a.types: continue
        bucket = country(cid, cname).setdefault("plane" if cat == "planes" else "helicopter", {}).setdefault("group", {})
        for af in sorted(table):
            entry = w["airports"].get(af, {}).get("aircrafts", {}).get(cat, {}).get(typ)
            if not entry or "linkDynTempl" in entry: continue
            gid += 1; uid += 1
            g = copy.deepcopy(base); u = g["units"][1]; sp = g["route"]["points"][1]
            x, y = pos[af]
            g["groupId"], u["unitId"] = gid, uid
            g["name"] = "TPL %s %s" % (label, name[af]); u["name"] = g["name"] + "-1"
            g["task"], g["dynSpawnTemplate"] = task, True
            u["type"], u["skill"] = typ, "Player"
            u["onboard_num"] = "%03d" % (gid % 1000)
            u["payload"] = {"pylons": {}, "fuel": fuel, "flare": 60, "chaff": 60, "gun": 100}
            if typ in ("F-16C_50", "FA-18C_hornet"):
                stn += 1
                u["AddPropAircraft"] = dict(base["units"][1].get("AddPropAircraft", {}))
                u["AddPropAircraft"]["STN_L16"] = format(stn, "05o")
            else:
                u["AddPropAircraft"] = {}
            if cat == "helicopters":
                u["ropeLength"] = 15; g["frequency"] = 127.5
            for o in (g, u, sp): o["x"], o["y"] = x, y
            sp["airdromeId"] = af
            sp["task"] = {"id": "ComboTask", "params": {"tasks": {}}}
            u.pop("parking", None); u.pop("parking_id", None)     # Editor vergibt Stellplatz beim Speichern
            pts = {1: sp}
            pts.update(route_points(af, route, table, wname, alt, alt_type, spd, maxwp))
            g["route"] = {"points": pts}
            bucket[len(bucket) + 1] = g
            entry["linkDynTempl"] = gid
            total += 1
    print("Vorlagen erzeugt:", total, "| Kampagnenreihenfolge:", ", ".join(name[i] for i in order))
    print("Hinweis: Mission danach einmal im Editor öffnen und speichern (Parkpositionen).")
    miz.save(a.out)

def cmd_reroute(a):
    """Wegpunkte aller vorhandenen Vorlagen neu setzen (gemeinsame Route über alle Ziele); Startpunkt/Parkplatz bleiben"""
    miz = Miz(a.miz)
    table = airfield_table(theatre(miz))
    if not table: sys.exit("Keine Flugplatztabelle (tools/geo.py) für Karte %s" % theatre(miz))
    m, w = miz.table("mission"), miz.table("warehouses")
    dic = miz.table("l10n/DEFAULT/dictionary")
    home = [i for i, ap in w["airports"].items() if ap.get("coalition", "").upper() == "BLUE"]
    targets = target_ids(theatre(miz), table, home)
    route = global_route(theatre(miz), table, targets, home)
    params = {t[0]: t for t in TYPES}
    def wname(text):
        m["maxDictId"] += 1
        k = "DictKey_WptName_%d" % m["maxDictId"]; dic[k] = text; return k
    n = 0
    for _, _, g in blue_groups(m, ALL_SIDES):
        if not g.get("dynSpawnTemplate"): continue
        typ = g["units"][1]["type"]; sp = g["route"]["points"][1]; af = sp.get("airdromeId")
        if typ not in params or af not in table: continue
        _, _, _, _, alt, alt_type, spd, maxwp, _, _ = params[typ]
        for p in list(g["route"]["points"].values())[1:]:
            if isinstance(p.get("name"), str) and p["name"].startswith("DictKey_WptName_"): dic.pop(p["name"], None)
        pts = {1: sp}
        pts.update(route_points(af, route, table, wname, alt, alt_type, spd, maxwp))
        g["route"]["points"] = pts
        n += 1
    print("Wegpunkte neu gesetzt:", n, "Vorlagen | Route (%d Ziele): %s" % (len(route), ", ".join(table[t][0] for t in route)))
    miz.save(a.out)

# ----------------------------------------------------------------- tplside
NEUTRAL_TPL_COUNTRY = (22, "Switzerland")   # in beiden Missionen in der neutralen Koalition

def cmd_tplside(a):
    """Vorlagen (dynSpawnTemplate) in ein neutrales Land verschieben, damit sie nicht als Slots erscheinen – oder zurück nach blau"""
    miz = Miz(a.miz)
    m = miz.table("mission")
    def country(side, cid, cname):
        cs = m["coalition"][side].setdefault("country", {})
        for c in cs.values():
            if c["id"] == cid: return c
        c = {"id": cid, "name": cname}; cs[len(cs) + 1] = c; return c
    src_side, dst_side = ("blue", "neutrals") if a.side == "neutral" else ("neutrals", "blue")
    blue_land = {t[0]: t[3] for t in TYPES}
    moved = 0
    for c in list(m["coalition"][src_side].get("country", {}).values()):
        for cat in ("plane", "helicopter"):
            grp = c.get(cat, {}).get("group", {})
            keep, move = [], []
            for g in grp.values():
                (move if g.get("dynSpawnTemplate") else keep).append(g)
            if not move: continue
            c[cat]["group"] = {i + 1: g for i, g in enumerate(keep)}
            for g in move:
                cid, cname = NEUTRAL_TPL_COUNTRY if a.side == "neutral" else blue_land.get(g["units"][1]["type"], (2, "USA"))
                dst = country(dst_side, cid, cname).setdefault(cat, {}).setdefault("group", {})
                dst[len(dst) + 1] = g; moved += 1
            if not keep: del c[cat]
    print("Vorlagen verschoben nach %s: %d" % (dst_side, moved))
    miz.save(a.out)

# ----------------------------------------------------------------- voice
def cmd_voice(a):
    if not shutil.which("ffmpeg"): sys.exit("ffmpeg nicht gefunden")
    tmp = tempfile.mkdtemp()
    if a.clips.lower().endswith(".zip"):
        zipfile.ZipFile(a.clips).extractall(tmp); src = tmp
    else:
        src = a.clips
    wavs = {}
    for root, _, files in os.walk(src):
        for f in files:
            mm = re.fullmatch(r"ov_([a-z0-9_]+)\.wav", f)
            if mm: wavs[mm.group(1)] = os.path.join(root, f)
    if not wavs: sys.exit("keine ov_*.wav gefunden")
    filt = "silenceremove=start_periods=1:start_threshold=-45dB,areverse," \
           "silenceremove=start_periods=1:start_threshold=-45dB,areverse"
    lvl = a.radio                    # 0 = aus, 1 leicht, 2 normal, 3 stark verzerrt
    if lvl:   # Funk-Charakter: Bandpass + Kompression (+ Sättigung/Bitcrush ab Stufe 3) + Rauschen
        hp, lp, noise = {1: (250, 3600, 0.002), 2: (300, 3200, 0.004), 3: (400, 2800, 0.012)}[lvl]
        filt += ",highpass=f=%d,lowpass=f=%d,acompressor=threshold=-18dB:ratio=4,volume=1.6" % (hp, lp)
        if lvl >= 3:
            filt += ",acrusher=bits=10:mode=log:aa=1,asoftclip=type=tanh:threshold=0.6"
        filt += ",aeval=val(0)+%s*(random(0)-0.5):c=same,alimiter=limit=0.9" % noise
    miz = Miz(a.miz)
    for n in [n for n in miz.files if re.fullmatch(r"l10n/DEFAULT/ov_[a-z0-9_]+\.wav", n)]:
        del miz.files[n]
    res = miz.table("l10n/DEFAULT/mapResource")
    for k in [k for k, v in res.items() if re.fullmatch(r"ov_[a-z0-9_]+\.wav", v)]:
        del res[k]
    lines = ["DynSEAD_VOICE = { clips = {"]
    for key in sorted(wavs):
        out = os.path.join(tmp, "out_%s.wav" % key)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wavs[key], "-af", filt,
                        "-ar", "22050", "-ac", "1", "-sample_fmt", "s16", out], check=True)
        with wave.open(out) as wf:
            dur = wf.getnframes() / wf.getframerate()
        if lvl >= 2:   # kurzer Rauschstoß am Ende wie beim Loslassen der Sprechtaste
            out2 = os.path.join(tmp, "sq_%s.wav" % key)
            tail = "apad=pad_dur=0.12,aeval=val(0)+if(gt(t\\,%.3f)\\,0.05*(random(0)-0.5)\\,0):c=same,alimiter=limit=0.9" % dur
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", out, "-af", tail, "-ar", "22050", "-ac", "1",
                            "-sample_fmt", "s16", out2], check=True)
            out = out2
            with wave.open(out) as wf:
                dur = wf.getnframes() / wf.getframerate()
        miz.files["l10n/DEFAULT/ov_%s.wav" % key] = open(out, "rb").read()
        res[miz.next_reskey()] = "ov_%s.wav" % key
        lines.append('  ["%s"] = %.3f,' % (key, dur))
    lines.append("} }")
    miz.files["l10n/DEFAULT/" + VOICE_INDEX] = ("\n".join(lines) + "\n").encode("utf-8")

    # Index-Skript VOR dem Hauptskript laden
    m = miz.table("mission")
    vkey = next((k for k, v in res.items() if v == VOICE_INDEX), None)
    if not vkey:
        vkey = miz.next_reskey(); res[vkey] = VOICE_INDEX
        rule = m["trigrules"][1]
        acts = [rule["actions"][i] for i in sorted(rule["actions"])]
        rule["actions"] = {i + 1: x for i, x in enumerate([{"predicate": "a_do_script_file", "file": vkey}] + acts)}
        m["trig"]["actions"][1] = 'a_do_script_file(getValueResourceByKey("%s")); %s' % (vkey, m["trig"]["actions"][1])
    print("Sprachbausteine:", len(wavs), "| Funkfilter:", "Stufe %d" % a.radio if a.radio else "nein")
    print("WICHTIG: Mission danach NICHT mehr im Editor speichern (Editor entfernt nicht verknüpfte WAVs).")
    miz.save(a.out)

# ----------------------------------------------------------------- options
def _lua_value(val):
    if val in ("true", "false"): return val == "true"
    if re.fullmatch(r"-?\d+", val): return int(val)
    if re.fullmatch(r"-?\d+\.\d+", val): return float(val)
    return val

def cmd_options(a):
    """Optionen setzen. Ohne --forced: Abschnitt ["difficulty"] der Datei 'options' (nur die lokalen Einstellungen des
    speichernden Nutzers!). Mit --forced: ["forcedOptions"] in der Datei 'mission' – das setzt die Mission selbst durch."""
    miz = Miz(a.miz)
    if a.forced:
        fo = miz.table("mission").setdefault("forcedOptions", {})
        for kv in a.pairs:
            key, _, val = kv.partition("=")
            if val == "":                      # KEY= entfernt den Eintrag, die Mission erzwingt ihn dann nicht mehr
                print("forcedOptions.%s: %r -> (entfernt)" % (key, fo.pop(key, None)))
                continue
            print("forcedOptions.%s: %r -> %r" % (key, fo.get(key), _lua_value(val)))
            fo[key] = _lua_value(val)
        miz.save(a.out)
        return
    txt = miz.files["options"].decode("utf-8")
    m = re.search(r'\["difficulty"\]\s*=\s*\n\s*\{.*?\}, -- end of \["difficulty"\]', txt, re.S)
    if not m: sys.exit("Abschnitt difficulty nicht gefunden")
    block = m.group(0)
    for kv in a.pairs:
        key, _, val = kv.partition("=")
        lit = val if val in ("true", "false") or re.fullmatch(r"-?\d+(\.\d+)?", val) else '"%s"' % val
        pat = re.compile(r'(\["%s"\]\s*=\s*)("[^"]*"|true|false|-?\d+(\.\d+)?)' % re.escape(key))
        if not pat.search(block): sys.exit("Option nicht gefunden: " + key)
        old = pat.search(block).group(2)
        block = pat.sub(lambda mm: mm.group(1) + lit, block, count=1)
        print("%s: %s -> %s" % (key, old, lit))
    miz.files["options"] = (txt[:m.start()] + block + txt[m.end():]).encode("utf-8")
    miz.save(a.out)

# ----------------------------------------------------------------- main
if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = p.add_subparsers(dest="cmd", required=True)
    s = sp.add_parser("info");      s.add_argument("miz"); s.set_defaults(f=cmd_info)
    s = sp.add_parser("embed");     s.add_argument("miz"); s.add_argument("lua"); s.add_argument("-o", "--out"); s.set_defaults(f=cmd_embed)
    s = sp.add_parser("templates"); s.add_argument("miz"); s.add_argument("--base", required=True)
    s.add_argument("--types", nargs="*", help="Labels/Typen, z.B. F-16 A-10C_2 (Standard: alle)")
    s.add_argument("--keep", action="store_true", help="vorhandene Vorlagen behalten, nur fehlende ergänzen")
    s.add_argument("-o", "--out"); s.set_defaults(f=cmd_templates)
    s = sp.add_parser("reroute"); s.add_argument("miz"); s.add_argument("-o", "--out"); s.set_defaults(f=cmd_reroute)
    s = sp.add_parser("tplside"); s.add_argument("miz"); s.add_argument("side", choices=["neutral", "blue"]); s.add_argument("-o", "--out"); s.set_defaults(f=cmd_tplside)
    s = sp.add_parser("options");   s.add_argument("miz"); s.add_argument("pairs", nargs="+", help="KEY=WERT, z.B. optionsView=optview_all; mit --forced entfernt KEY= den Eintrag"); s.add_argument("--forced", action="store_true", help="in mission.forcedOptions statt in der Datei options setzen"); s.add_argument("-o", "--out"); s.set_defaults(f=cmd_options)
    s = sp.add_parser("voice");     s.add_argument("miz"); s.add_argument("clips", help="overlord_voice.zip oder Ordner")
    s.add_argument("--radio", nargs="?", type=int, const=2, default=0, choices=[0, 1, 2, 3], help="Funkfilter: 1 leicht, 2 normal (Standard bei --radio), 3 stark verzerrt"); s.add_argument("-o", "--out"); s.set_defaults(f=cmd_voice)
    a = p.parse_args(); a.f(a)
