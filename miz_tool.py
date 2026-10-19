#!/usr/bin/env python3
"""
miz_tool.py – Werkzeuge für die DynSEAD-Mission (.miz = ZIP mit Lua-Tabellen)

  python tools/miz_tool.py info      MISSION.miz
  python tools/miz_tool.py embed     MISSION.miz src/DynSEAD.lua            [-o OUT.miz]
  python tools/miz_tool.py templates MISSION.miz --base "TPL F-16 Senaki-Kolkhi" [-o OUT.miz]
  python tools/miz_tool.py voice     MISSION.miz overlord_voice.zip [--radio] [-o OUT.miz]

Ohne -o wird die Eingabedatei überschrieben (vorher wird eine .bak angelegt).
Benötigt nur Python 3 (voice zusätzlich ffmpeg im PATH).
"""
import argparse, copy, io, math, os, re, shutil, subprocess, sys, tempfile, wave, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luatable import parse, dump
from geo import ll_to_dcs, AIRFIELDS

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

def blue_groups(m):
    for c in m["coalition"]["blue"]["country"].values():
        for cat in ("plane", "helicopter"):
            for g in c.get(cat, {}).get("group", {}).values():
                yield c, cat, g

def campaign_order(home):
    pos = {i: ll_to_dcs(la, lo) for i, (n, la, lo) in AIRFIELDS.items()}
    d = lambda a, b: math.hypot(pos[a][0] - pos[b][0], pos[a][1] - pos[b][1])
    blue, todo, order = set(home), set(AIRFIELDS) - set(home), []
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
    for i, ap in sorted(w["airports"].items()):
        name = AIRFIELDS.get(i, ("?",))[0]
        links = []
        for cat in ("planes", "helicopters"):
            for t, e in ap["aircrafts"][cat].items():
                if "linkDynTempl" in e: links.append(t)
        print("  %2d %-22s %-8s dyn=%s  Vorlagen: %s" % (i, name, ap.get("coalition"), ap.get("dynamicSpawn"), ", ".join(links) or "-"))
    n = sum(1 for _ in blue_groups(m))
    print("\nBlaue Gruppen:", n, "(davon Vorlagen: %d)" % sum(1 for _, _, g in blue_groups(m) if g.get("dynSpawnTemplate")))

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
TYPES = [  # typ, Kategorie, Gruppen-Task, Land(id,name), Höhe m, Höhentyp, Speed m/s, max. WP, Sprit kg, Label
    ("F-16C_50",      "planes",      "CAP",           (2, "USA"),     7620, "BARO",  220.97, 20, 3104, "F-16"),
    ("FA-18C_hornet", "planes",      "CAP",           (2, "USA"),     7620, "BARO",  220.97, 20, 4900, "F/A-18C"),
    ("A-10C_2",       "planes",      "CAS",           (2, "USA"),     4572, "BARO",  150.0,  20, 5029, "A-10C II"),
    ("AJS37",         "planes",      "Ground Attack", (46, "Sweden"), 3000, "BARO",  220.97,  9, 4476, "AJS-37"),
    ("AH-64D_BLK_II", "helicopters", "CAS",           (2, "USA"),      150, "RADIO",  55.0,  10, 1438, "AH-64D"),
]

def cmd_templates(a):
    miz = Miz(a.miz)
    if theatre(miz) != "Caucasus": sys.exit("Koordinatentabelle (tools/geo.py) gibt es bisher nur für Caucasus")
    m, w = miz.table("mission"), miz.table("warehouses")
    dic = miz.table("l10n/DEFAULT/dictionary")
    base = [g for _, _, g in blue_groups(m) if g["name"] == a.base]
    if not base: sys.exit("Basis-Vorlage '%s' nicht gefunden" % a.base)
    base = copy.deepcopy(base[0])
    home = [i for i, ap in w["airports"].items() if ap.get("coalition", "").upper() == "BLUE"]
    order, pos = campaign_order(home)
    name = {i: n for i, (n, la, lo) in AIRFIELDS.items()}

    # alte Vorlagen entfernen (alle blauen Gruppen mit dynSpawnTemplate)
    for c in m["coalition"]["blue"]["country"].values():
        for cat in ("plane", "helicopter"):
            grp = c.get(cat, {}).get("group", {})
            keep = [g for g in grp.values() if not g.get("dynSpawnTemplate")]
            if cat in c: c[cat]["group"] = {i + 1: g for i, g in enumerate(keep)}
    for ap in w["airports"].values():
        for cat in ("planes", "helicopters"):
            for e in ap["aircrafts"][cat].values(): e.pop("linkDynTempl", None)

    gid = max([g["groupId"] for _, _, g in blue_groups(m)] + [0])
    uid = max([g["units"][1]["unitId"] for _, _, g in blue_groups(m)] + [0])
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
        for af in sorted(AIRFIELDS):
            entry = w["airports"].get(af, {}).get("aircrafts", {}).get(cat, {}).get(typ)
            if not entry: continue
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
            pts = {1: sp}; n = 2
            for t in [t for t in order if t != af][:maxwp]:
                tx, ty = pos[t]
                pts[n] = {"alt": alt, "action": "Turning Point", "alt_type": alt_type, "speed": spd,
                          "task": {"id": "ComboTask", "params": {"tasks": {}}}, "type": "Turning Point",
                          "ETA": 0, "ETA_locked": False, "x": tx, "y": ty, "speed_locked": True,
                          "formation_template": "", "name": wname(name[t])}
                n += 1
            g["route"] = {"points": pts}
            bucket[len(bucket) + 1] = g
            entry["linkDynTempl"] = gid
            total += 1
    print("Vorlagen erzeugt:", total, "| Kampagnenreihenfolge:", ", ".join(name[i] for i in order))
    print("Hinweis: Mission danach einmal im Editor öffnen und speichern (Parkpositionen).")
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
    if a.radio:   # Funk-Charakter: Bandpass + leichte Sättigung + etwas Rauschen
        filt += ",highpass=f=300,lowpass=f=3200,acompressor=threshold=-18dB:ratio=4,volume=1.6," \
                "aeval=val(0)+0.004*(random(0)-0.5):c=same,alimiter=limit=0.9"
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
    print("Sprachbausteine:", len(wavs), "| Funkfilter:", "ja" if a.radio else "nein")
    print("WICHTIG: Mission danach NICHT mehr im Editor speichern (Editor entfernt nicht verknüpfte WAVs).")
    miz.save(a.out)

# ----------------------------------------------------------------- main
if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = p.add_subparsers(dest="cmd", required=True)
    s = sp.add_parser("info");      s.add_argument("miz"); s.set_defaults(f=cmd_info)
    s = sp.add_parser("embed");     s.add_argument("miz"); s.add_argument("lua"); s.add_argument("-o", "--out"); s.set_defaults(f=cmd_embed)
    s = sp.add_parser("templates"); s.add_argument("miz"); s.add_argument("--base", required=True)
    s.add_argument("--types", nargs="*", help="Labels/Typen, z.B. F-16 A-10C_2 (Standard: alle)")
    s.add_argument("-o", "--out"); s.set_defaults(f=cmd_templates)
    s = sp.add_parser("voice");     s.add_argument("miz"); s.add_argument("clips", help="overlord_voice.zip oder Ordner")
    s.add_argument("--radio", action="store_true", help="Funkfilter anwenden"); s.add_argument("-o", "--out"); s.set_defaults(f=cmd_voice)
    a = p.parse_args(); a.f(a)
