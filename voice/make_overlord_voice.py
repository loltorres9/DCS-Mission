#!/usr/bin/env python3
"""
make_overlord_voice.py – erzeugt die Sprachbausteine für "Overlord" (DynSEAD) mit Microsoft Edge TTS
(neuronale Stimmen, kostenlos, braucht Internet; ersetzt make_overlord_voice.ps1).

  pip install edge-tts
  python voice/make_overlord_voice.py                       # Standard: en-GB-RyanNeural
  python voice/make_overlord_voice.py --list                # alle englischen Stimmen anzeigen
  python voice/make_overlord_voice.py --voice en-US-GuyNeural --rate=-5%
  python voice/make_overlord_voice.py --only popup new_threat   # nur einzelne Bausteine (Hörprobe)

Benötigt ffmpeg im PATH (mp3 -> wav). Ergebnis: Ordner overlord_voice/ mit ov_*.wav und overlord_voice.zip.
Danach: python tools/miz_tool.py voice mission/Dynamic_Script.miz overlord_voice.zip --radio
"""
import argparse, asyncio, os, shutil, subprocess, sys, zipfile

CLIPS = {
    "overlord": "Overlord,", "all_players": "all players,", "new_threat": "new threat,",
    "area": "area", "plus_minus": "plus minus", "kilometers": "kilometers.",
    "meters": "meters.", "hundred": "hundred", "update": "update,",
    "now": "now", "located": "located,", "coords_f10": "coordinates passed. Check F 10.",
    "popup": "pop-up threat!", "now_active": "now active,", "check_six": "check six, and defend.",
    "gone_silent": "has gone silent.", "back_up": "is back up, emitting again,", "heads_up": "heads up,",
    "relocated": "has relocated.", "new_emissions": "new emissions,", "prev_invalid": "previous fix invalid.",
    "good_effect": "good effect,", "site_destroyed": "site destroyed.", "down": "down.",
    "new_picture": "new picture, group", "contacts": "contacts,", "angels": "angels",
    "hostile": "hostile.", "splash": "splash. Picture clean.", "new_objective": "new objective,",
    "airfield": "airfield,", "now_friendly": "is now friendly. Good work.", "caution_manpads": "caution, MANPADS reported,",
    "stay_above": "stay above", "thousand": "thousand.", "new_cas": "new C A S tasking,",
    "manpads_reported": "MANPADS reported.", "threat_picture": "threat picture,", "sites": "sites.",
    "no_sites": "threat picture. No known SAM sites.", "active": "active.", "silent": "silent.",
    "bullseye": "bullseye", "d0": "zero", "d1": "one",
    "d2": "two", "d3": "three", "d4": "four",
    "d5": "five", "d6": "six", "d7": "seven",
    "d8": "eight", "d9": "niner", "n0": "zero",
    "n1": "one", "n2": "two", "n3": "three",
    "n4": "four", "n5": "five", "n6": "six",
    "n7": "seven", "n8": "eight", "n9": "nine",
    "n10": "ten", "n11": "eleven", "n12": "twelve",
    "n13": "thirteen", "n14": "fourteen", "n15": "fifteen",
    "n16": "sixteen", "n17": "seventeen", "n18": "eighteen",
    "n19": "nineteen", "n20": "twenty", "n30": "thirty",
    "n40": "forty", "n50": "fifty", "n60": "sixty",
    "n70": "seventy", "n80": "eighty", "n90": "ninety",
    "sa2": "S A two", "sa3": "S A three", "sa6": "S A six",
    "sa8": "S A eight", "sa11": "S A eleven", "sa15": "S A fifteen",
    "mig23": "Mig twenty-three,", "mig29": "Mig twenty-nine,", "su27": "Sukhoi twenty-seven,",
    "af_anapavityazevo": "Anapa", "af_krasnodarcenter": "Krasnodar Center", "af_novorossiysk": "Novorossiysk",
    "af_krymsk": "Krymsk", "af_maykopkhanskaya": "Maykop", "af_gelendzhik": "Gelendzhik",
    "af_sochiadler": "Sochi", "af_krasnodarpashkovsky": "Krasnodar Pashkovsky", "af_sukhumibabushara": "Sukhumi",
    "af_gudauta": "Gudauta", "af_batumi": "Batumi", "af_senakikolkhi": "Senaki",
    "af_kobuleti": "Kobuleti", "af_kutaisi": "Kutaisi", "af_mineralnyevody": "Mineralnye Vody",
    "af_nalchik": "Nalchik", "af_mozdok": "Mozdok", "af_tbilisilochini": "Tbilisi",
    "af_soganlug": "Soganlug", "af_vaziani": "Vaziani", "af_beslan": "Beslan",
}

async def synth(text, voice, rate, pitch, path):
    import edge_tts
    await edge_tts.Communicate(text, voice, rate=rate, pitch=pitch).save(path)

async def main_async(a):
    if a.list:
        import edge_tts
        for v in await edge_tts.list_voices():
            if v["Locale"].startswith("en-"):
                print("%-26s %-8s %s" % (v["ShortName"], v["Gender"], v["Locale"]))
        return
    if not shutil.which("ffmpeg"): sys.exit("ffmpeg nicht gefunden")
    keys = a.only or list(CLIPS)
    for k in keys:
        if k not in CLIPS: sys.exit("unbekannter Baustein: " + k)
    os.makedirs(a.out, exist_ok=True)
    sem = asyncio.Semaphore(4)

    async def one(k):
        mp3 = os.path.join(a.out, "ov_%s.mp3" % k)
        wav = os.path.join(a.out, "ov_%s.wav" % k)
        async with sem:
            for attempt in range(3):
                try:
                    await synth(CLIPS[k], a.voice, a.rate, a.pitch, mp3); break
                except Exception:
                    if attempt == 2: raise
                    await asyncio.sleep(2)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", mp3, "-ar", "22050", "-ac", "1",
                        "-sample_fmt", "s16", wav], check=True)
        os.remove(mp3)
        print("ok", k)

    await asyncio.gather(*(one(k) for k in keys))
    if not a.only:
        zp = a.out.rstrip("/\\") + ".zip"
        with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
            for k in CLIPS: z.write(os.path.join(a.out, "ov_%s.wav" % k), "ov_%s.wav" % k)
        print("Fertig: %d Bausteine in %s\nZum Einbauen: %s" % (len(CLIPS), a.out, zp))

if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--voice", default="en-GB-RyanNeural")
    p.add_argument("--rate", default="+0%", help='z.B. -5%% (mit = angeben: --rate=-5%%)')
    p.add_argument("--pitch", default="+0Hz", help='z.B. -10Hz')
    p.add_argument("--out", default="overlord_voice")
    p.add_argument("--only", nargs="*", help="nur diese Bausteine")
    p.add_argument("--list", action="store_true")
    asyncio.run(main_async(p.parse_args()))
