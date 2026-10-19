#!/usr/bin/env python3
"""
make_overlord_voice_elevenlabs.py – Sprachbausteine für "Overlord" (DynSEAD) mit ElevenLabs.
Nutzt dieselben 111 Texte wie make_overlord_voice.py. Nur Standardbibliothek + ffmpeg im PATH.

API-Key NIE ins Repo schreiben, nur als Umgebungsvariable setzen (PowerShell):
  $env:ELEVENLABS_API_KEY = "sk_..."

  python voice/make_overlord_voice_elevenlabs.py --list                      # verfügbare Stimmen
  python voice/make_overlord_voice_elevenlabs.py --voice Brian --only popup new_threat   # Hörprobe
  python voice/make_overlord_voice_elevenlabs.py --voice Brian               # alle Bausteine + overlord_voice.zip
  python voice/make_overlord_voice_elevenlabs.py --dry                       # nur Zeichenverbrauch anzeigen

--voice: Name (wie in --list) oder Voice-ID. Hinweis: Im Gratis-Tarif sind per API nur die Stimmen nutzbar,
die in --list erscheinen (Standardstimmen und selbst zur Bibliothek hinzugefügte, je nach Tarif).
Danach: python tools/miz_tool.py voice mission/Dynamic_Script.miz overlord_voice.zip --radio
"""
import argparse, json, os, shutil, subprocess, sys, time, urllib.error, urllib.request, zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_overlord_voice import CLIPS

API = "https://api.elevenlabs.io/v1"

def call(path, key, body=None):
    req = urllib.request.Request(API + path, headers={"xi-api-key": key, "Content-Type": "application/json",
                                                      "Accept": "*/*"},
                                 data=None if body is None else json.dumps(body).encode("utf-8"))
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:300]
            if e.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(3 * (attempt + 1)); continue
            sys.exit("ElevenLabs-Fehler %d: %s" % (e.code, detail))

def list_voices(key):
    return json.loads(call("/voices", key))["voices"]

def resolve_voice(key, voice):
    for v in list_voices(key):
        if voice.lower() in (v["name"].lower(), v["voice_id"].lower()) or v["name"].lower().startswith(voice.lower() + " "):
            return v["voice_id"], v["name"]
    sys.exit("Stimme nicht gefunden: %s (siehe --list)" % voice)

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--voice", default="Brian")
    p.add_argument("--model", default="eleven_multilingual_v2", help="z.B. eleven_turbo_v2_5 (billiger, schneller)")
    p.add_argument("--stability", type=float, default=0.6, help="höher = gleichmäßiger über alle Bausteine")
    p.add_argument("--similarity", type=float, default=0.8)
    p.add_argument("--style", type=float, default=0.0)
    p.add_argument("--out", default="overlord_voice")
    p.add_argument("--only", nargs="*")
    p.add_argument("--list", action="store_true")
    p.add_argument("--dry", action="store_true")
    a = p.parse_args()

    keys = a.only or list(CLIPS)
    for k in keys:
        if k not in CLIPS: sys.exit("unbekannter Baustein: " + k)
    if a.dry:
        n = sum(len(CLIPS[k]) for k in keys)
        sys.exit("%d Bausteine, %d Zeichen (Gratis-Tarif: ca. 10000 pro Monat)" % (len(keys), n))

    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key: sys.exit('Umgebungsvariable ELEVENLABS_API_KEY fehlt: $env:ELEVENLABS_API_KEY = "sk_..."')
    if a.list:
        for v in list_voices(key):
            lab = v.get("labels") or {}
            print("%-22s %-10s %s" % (v["name"], v.get("category", ""), ", ".join(lab.values())))
        return
    if not shutil.which("ffmpeg"): sys.exit("ffmpeg nicht gefunden")

    vid, vname = resolve_voice(key, a.voice)
    print("Stimme: %s (%s), Modell: %s" % (vname, vid, a.model))
    os.makedirs(a.out, exist_ok=True)
    for k in keys:
        audio = call("/text-to-speech/%s?output_format=mp3_44100_128" % vid, key, {
            "text": CLIPS[k], "model_id": a.model,
            "voice_settings": {"stability": a.stability, "similarity_boost": a.similarity,
                               "style": a.style, "use_speaker_boost": True}})
        mp3 = os.path.join(a.out, "ov_%s.mp3" % k); wav = os.path.join(a.out, "ov_%s.wav" % k)
        with open(mp3, "wb") as f: f.write(audio)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", mp3, "-ar", "22050", "-ac", "1",
                        "-sample_fmt", "s16", wav], check=True)
        os.remove(mp3)
        print("ok", k)
    if not a.only:
        zp = a.out.rstrip("/\\") + ".zip"
        with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
            for k in CLIPS: z.write(os.path.join(a.out, "ov_%s.wav" % k), "ov_%s.wav" % k)
        print("Fertig: %d Bausteine in %s\nZum Einbauen: %s" % (len(CLIPS), a.out, zp))

if __name__ == "__main__":
    main()
