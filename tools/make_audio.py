"""Synthesises every sound effect and the music loop for Sort the Shipment.
Pure numpy - no samples, no external assets. Writes 16-bit mono WAV files."""
import wave
import numpy as np
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.1, total=None):
    """ADSR-ish envelope over n samples (times in seconds)."""
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    sus_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1)),
        np.linspace(1, s, max(d_n, 1)),
        np.full(sus_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def expdecay(n, k):
    return np.exp(-np.arange(n) / SR * k)


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    # one-pole low pass
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def tone(freq, d, kind="sine"):
    tt = t(d)
    if kind == "sine":
        return np.sin(2 * np.pi * freq * tt)
    if kind == "tri":
        return 2 * np.abs(2 * ((freq * tt) % 1) - 1) - 1
    if kind == "square":
        return np.sign(np.sin(2 * np.pi * freq * tt)) * 0.6
    if kind == "saw":
        return 2 * ((freq * tt) % 1) - 1
    raise ValueError(kind)


def marimba(freq, d=0.5):
    tt = t(d)
    x = np.sin(2 * np.pi * freq * tt) + 0.35 * np.sin(2 * np.pi * freq * 4 * tt) * expdecay(len(tt), 30)
    return x * expdecay(len(tt), 7) * env(len(tt), 0.002, 0.01, 1, 0.02)


def bell(freq, d=0.8):
    tt = t(d)
    x = (np.sin(2 * np.pi * freq * tt) + 0.5 * np.sin(2 * np.pi * freq * 2.76 * tt) * expdecay(len(tt), 8)
         + 0.25 * np.sin(2 * np.pi * freq * 5.4 * tt) * expdecay(len(tt), 14))
    return x * expdecay(len(tt), 5) * env(len(tt), 0.002, 0.01, 1, 0.05)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, offset, total):
    out = np.zeros(int(total * SR))
    o = int(offset * SR)
    seg = x[: max(0, len(out) - o)]
    out[o:o + len(seg)] += seg
    return out


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    # tiny fades to avoid clicks
    f = min(200, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(x) / SR:.2f}s")


# --- UI click: soft woody pop
n = int(0.09 * SR)
save("click", marimba(880, 0.09) * 0.8 + lowpass(noise(n), 3000) * expdecay(n, 90) * 0.3, 0.6)

# --- pick: quick rising whoosh + cable zip
d = 0.22
tt = t(d)
sweep = np.sin(2 * np.pi * np.cumsum(np.linspace(300, 900, len(tt))) / SR)
wh = lowpass(noise(len(tt)), 2500) * env(len(tt), 0.03, 0.05, 0.6, 0.12)
save("pick", sweep * 0.25 * env(len(tt), 0.01, 0.05, 0.5, 0.1) + wh * 0.8, 0.55)

# --- land on ship: heavy metal clunk + bright chime (pitch varied in-game for combos)
d = 0.5
n = int(d * SR)
thud = np.sin(2 * np.pi * 75 * t(d)) * expdecay(n, 18)
clank = lowpass(noise(n), 5000) * expdecay(n, 45)
ring = (np.sin(2 * np.pi * 523.25 * t(d)) + np.sin(2 * np.pi * 784 * t(d)) * 0.6) * expdecay(n, 9)
save("land_ship", thud * 0.9 + clank * 0.35 + ring * 0.45, 0.85)

# --- land in buffer: duller thump
n = int(0.35 * SR)
save("land_buffer", np.sin(2 * np.pi * 62 * t(0.35)) * expdecay(n, 16) + lowpass(noise(n), 1800) * expdecay(n, 40) * 0.5, 0.75)

# --- ship horn: two detuned saws through a low pass, with swell
d = 1.4
tt = t(d)
horn = (tone(110, d, "saw") + tone(110.8, d, "saw") * 0.8 + tone(165, d, "saw") * 0.35)
horn = lowpass(horn, 600) * env(len(tt), 0.12, 0.1, 0.9, 0.45)
save("horn", horn, 0.7)

# --- ship full: ascending marimba arpeggio + sparkle
total = 0.9
notes = [523.25, 659.25, 783.99, 1046.5]
parts = [at(marimba(f, 0.5), i * 0.07, total) for i, f in enumerate(notes)]
spark = at(bell(2093, 0.5) * 0.4, 0.28, total)
save("ship_full", mix(*parts, spark), 0.8)

# --- coin: classic two-tone ding
total = 0.45
save("coin", mix(at(bell(1318.5, 0.3) * 0.7, 0, total), at(bell(1760, 0.4), 0.06, total)), 0.6)

# --- reveal: shimmering upward glissando
d = 0.45
tt = t(d)
freqs = np.linspace(700, 1800, len(tt))
gl = np.sin(2 * np.pi * np.cumsum(freqs) / SR) * env(len(tt), 0.01, 0.1, 0.5, 0.25)
save("reveal", gl * 0.6 + lowpass(noise(len(tt)), 8000) * env(len(tt), 0.01, 0.1, 0.2, 0.2) * 0.2, 0.55)

# --- unlock: mechanical clack-clack
total = 0.35
clk = lambda f: lowpass(noise(int(0.06 * SR)), f) * expdecay(int(0.06 * SR), 80)
save("unlock", mix(at(clk(4000), 0, total), at(clk(2500), 0.09, total), at(bell(1568, 0.25) * 0.5, 0.12, total)), 0.6)

# --- error: low double buzz
total = 0.32
bz = lambda: lowpass(tone(130, 0.12, "square"), 1200) * env(int(0.12 * SR), 0.005, 0.02, 0.8, 0.04)
save("error", mix(at(bz(), 0, total), at(bz(), 0.15, total)), 0.5)

# --- whoosh (undo / transitions)
d = 0.4
tt = t(d)
w = lowpass(noise(len(tt)), 1800) * np.sin(np.linspace(0, np.pi, len(tt))) ** 2
save("whoosh", w, 0.5)

# --- splash (ship arrive)
d = 0.9
n = int(d * SR)
sp = lowpass(noise(n), 1400) * env(n, 0.05, 0.2, 0.4, 0.6)
save("splash", sp, 0.45)

# --- star pop (win screen), three pitches
for i, f in enumerate([880, 1108.7, 1318.5]):
    total = 0.5
    save(f"star{i + 1}", mix(at(marimba(f, 0.4), 0, total), at(bell(f * 2, 0.4) * 0.5, 0.02, total)), 0.7)

# --- win fanfare
total = 2.2
seq = [(523.25, 0.0), (659.25, 0.12), (783.99, 0.24), (1046.5, 0.36), (783.99, 0.6), (1046.5, 0.72)]
parts = [at(marimba(f, 0.6) + bell(f, 0.6) * 0.3, o, total) for f, o in seq]
chord = [at(bell(f, 1.5) * 0.35, 0.95, total) for f in (523.25, 659.25, 783.99, 1046.5)]
save("win", mix(*parts, *chord), 0.85)

# --- lose: descending soft tones
total = 1.4
seq = [(392, 0.0), (349.2, 0.22), (311.1, 0.44), (261.6, 0.7)]
save("lose", mix(*[at(lowpass(tone(f, 0.6, "tri"), 1500) * expdecay(int(0.6 * SR), 4), o, total) for f, o in seq]), 0.6)

# --- warn: buffer nearly full, two soft rising beeps
total = 0.4
beep = lambda f: tone(f, 0.11, "tri") * env(int(0.11 * SR), 0.005, 0.03, 0.7, 0.05)
save("warn", mix(at(beep(660), 0, total), at(beep(880), 0.16, total)), 0.5)

# --- gold: bright sparkle cascade
total = 0.9
save("gold", mix(*[at(bell(f, 0.6) * 0.8, i * 0.055, total) for i, f in enumerate([1568, 1976, 2349, 3136])],
                 at(lowpass(noise(int(0.6 * SR)), 9000) * expdecay(int(0.6 * SR), 6) * 0.15, 0, total)), 0.6)

# --- stamp: heavy thud + paper slap
n = int(0.4 * SR)
save("stamp", np.sin(2 * np.pi * 55 * t(0.4)) * expdecay(n, 14) + lowpass(noise(n), 3500) * expdecay(n, 35) * 0.8, 0.85)

# --- star lost: little descending blip
d = 0.3
tt = t(d)
fr = np.linspace(900, 420, len(tt))
save("star_lost", np.sin(2 * np.pi * np.cumsum(fr) / SR) * env(len(tt), 0.005, 0.05, 0.5, 0.15), 0.45)

# --- rank up: triumphant arpeggio + chord
total = 1.8
parts = [at(marimba(f, 0.5) + bell(f, 0.5) * 0.4, i * 0.09, total) for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5])]
chord = [at(bell(f, 1.3) * 0.3, 0.5, total) for f in (1046.5, 1318.5, 1568)]
save("rankup", mix(*parts, *chord), 0.8)

# --- crate: wooden knock + pop
total = 0.6
knock = lambda: lowpass(noise(int(0.08 * SR)), 1600) * expdecay(int(0.08 * SR), 60)
save("crate", mix(at(knock(), 0, total), at(knock(), 0.1, total), at(bell(1046.5, 0.4) * 0.6, 0.22, total), at(marimba(1568, 0.3), 0.26, total)), 0.7)

# --- music loop: breezy island tune, 112 bpm, 8 bars of 4/4
bpm = 112
beat = 60 / bpm
bars = 8
total = bars * 4 * beat
SR_M = SR
music = np.zeros(int(total * SR))


def place(sig, when, gain=1.0):
    o = int(when * SR)
    seg = sig[: max(0, len(music) - o)]
    music[o:o + len(seg)] += seg * gain


# chord roots (C major-ish progression): C, Am, F, G, C, Em, F, G
prog = [(261.63, [0, 4, 7]), (220.0, [0, 3, 7]), (174.61, [0, 4, 7]), (196.0, [0, 4, 7]),
        (261.63, [0, 4, 7]), (164.81, [0, 3, 7]), (174.61, [0, 4, 7]), (196.0, [0, 4, 7])]
melody = [  # (bar, beat, semitone offset from C5)
    (0, 0, 0), (0, 1, 4), (0, 2, 7), (0, 3.5, 9), (1, 0, 7), (1, 1.5, 4), (1, 2.5, 2), (1, 3, 0),
    (2, 0, 5), (2, 1, 9), (2, 2, 12), (2, 3, 9), (3, 0, 7), (3, 1, 11), (3, 2.5, 14), (3, 3.5, 11),
    (4, 0, 12), (4, 1, 7), (4, 2, 9), (4, 3, 7), (5, 0, 4), (5, 1.5, 7), (5, 2.5, 11), (5, 3, 7),
    (6, 0, 9), (6, 1, 12), (6, 2, 14), (6, 3, 12), (7, 0, 11), (7, 1, 7), (7, 2, 2), (7, 3, 7),
]
C5 = 523.25
for bar, (root, tri_) in enumerate(prog):
    bt = bar * 4 * beat
    # bass on beats 1 and 3, octave pop on the and-of-2
    for b, mult in [(0, 0.5), (2, 0.5), (1.5, 1.0), (3.5, 0.75)]:
        f = root * mult
        place(lowpass(tone(f, beat * 0.9, "tri"), 900) * expdecay(int(beat * 0.9 * SR), 5), bt + b * beat, 0.5)
    # off-beat chord stabs (marimba)
    for b in [0.5, 1.5, 2.5, 3.5]:
        for semi in tri_:
            place(marimba(root * 2 * 2 ** (semi / 12), 0.25), bt + b * beat, 0.12)
    # shaker on eighths
    for k in range(8):
        sh = lowpass(noise(int(0.05 * SR)), 9000) * expdecay(int(0.05 * SR), 70)
        place(sh, bt + k * beat / 2, 0.08 if k % 2 else 0.05)
    # soft kick on 1 and 3
    for b in [0, 2]:
        kk = t(0.18)
        kick = np.sin(2 * np.pi * np.cumsum(np.linspace(120, 45, len(kk))) / SR) * expdecay(len(kk), 18)
        place(kick, bt + b * beat, 0.45)
for bar, b, semi in melody:
    place(marimba(C5 * 2 ** (semi / 12), 0.6), bar * 4 * beat + b * beat, 0.32)
    place(bell(C5 * 2 * 2 ** (semi / 12), 0.6), bar * 4 * beat + b * beat, 0.05)

# write without fades so it loops seamlessly
peak = np.max(np.abs(music))
data = (music / peak * 0.8 * 32767).astype(np.int16)
with wave.open(str(OUT / "music.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data.tobytes())
print(f"music.wav  {total:.2f}s")
