"""Génère les effets sonores du prototype (synthèse simple, aucun fichier tiers).
Usage : python3 tool/gen_sfx.py → assets/audio/*.wav
"""
import math, random, struct, wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets/audio"
SR = 22050
random.seed(7)


def write(name, samples, vol=0.6):
    peak = max(1e-6, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * vol)) * 32767)) for s in samples)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)


def env(i, n, attack=0.01, release=0.6):
    t = i / n
    a = min(1, t / attack) if attack > 0 else 1
    r = 1 if t < 1 - release else max(0, (1 - t) / release)
    return a * r


def tone(dur, f0, f1=None, wave_="square", noise=0.0, attack=0.01, release=0.7):
    n = int(SR * dur); out = []; ph = 0
    f1 = f0 if f1 is None else f1
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / SR
        if wave_ == "square": v = 1 if math.sin(ph) >= 0 else -1
        elif wave_ == "tri": v = 2 / math.pi * math.asin(math.sin(ph))
        else: v = math.sin(ph)
        v = v * (1 - noise) + (random.random() * 2 - 1) * noise
        out.append(v * env(i, n, attack, release))
    return out


def seq(*parts):
    out = []
    for p in parts: out += p
    return out


OUT.mkdir(parents=True, exist_ok=True)
write("swing", tone(0.09, 900, 300, "sine", noise=0.7, release=0.9), 0.35)
write("hit", tone(0.10, 320, 120, "square", noise=0.35), 0.5)
write("enemy_die", tone(0.25, 500, 60, "square", noise=0.5), 0.5)
write("hurt", tone(0.28, 220, 70, "square", noise=0.2), 0.6)
write("jump", tone(0.14, 300, 700, "tri"), 0.4)
write("dodge", tone(0.12, 1200, 400, "sine", noise=0.8), 0.3)
write("shoot", tone(0.10, 700, 900, "tri", noise=0.1), 0.25)
write("life", seq(tone(0.08, 660, None, "tri"), tone(0.08, 880, None, "tri"), tone(0.14, 1320, None, "tri")), 0.45)
write("chest", seq(tone(0.06, 520, None, "square"), tone(0.06, 660, None, "square"), tone(0.06, 780, None, "square"), tone(0.2, 1040, None, "square")), 0.4)
write("card", seq(tone(0.07, 784, None, "tri"), tone(0.07, 988, None, "tri"), tone(0.07, 1175, None, "tri"), tone(0.3, 1568, None, "tri", release=0.9)), 0.5)
write("tick", tone(0.06, 880, None, "sine"), 0.4)
write("go", tone(0.25, 1320, None, "sine", release=0.8), 0.5)
write("run_end", seq(tone(0.12, 523, None, "tri"), tone(0.12, 392, None, "tri"), tone(0.3, 262, None, "tri", release=0.9)), 0.5)
write("coin", seq(tone(0.05, 1568, None, "square"), tone(0.12, 2093, None, "square", release=0.8)), 0.3)
print(sorted(p.name for p in OUT.iterdir()))
