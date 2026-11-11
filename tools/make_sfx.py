"""Builds the game's sound effects (v1.11).

Two sources:
  * Ship horns are synthesised here (no CC0 recording fits a cartoon harbour):
    a reedy horn tone with an onset scoop, bell resonances, a little breath,
    and a harbour echo off the warehouses.
  * Everything else comes from SFX Kit by Wyzowl (CC0 1.0, no credit required,
    https://github.com/wyzowl/sfx-kit). Each file is converted to 44.1 kHz mono
    16-bit, trimmed and level-matched to the sound it replaces, so the volume
    offsets used in the game code keep working.

Usage: python3 tools/make_sfx.py /path/to/sfx-kit
(Without a path only the horns are rebuilt.)
"""
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = np.random.default_rng(11)

# game sound -> (SFX Kit id, options)
PACK = {
    "dispatch_seal": ("mechanical-latch-heavy", {}),
    "dispatch_chime": ("notification-success-chime", {}),
    "land_ship": ("impact-heavy-firm", {"pitch": 0.92}),
    "land_buffer": ("impact-medium-firm", {}),
    "pick": ("click-clip-firm", {}),
    "click": ("click-button-medium", {}),
    "unlock": ("mechanical-lock-light", {}),
    "error": ("notification-failure-knock", {}),
    "win": ("sting-playful-short", {}),
    "lose": ("notification-failure-minor", {}),
    "star1": ("tone-step-3", {}),
    "star2": ("tone-step-4", {}),
    "star3": ("tone-step-5", {}),
    "reveal": ("foley-plastic-slide", {"max": 0.32}),
    "splash": ("props-splash", {}),
    "whoosh": ("whoosh-medium-soft", {}),
    "gold": ("shimmer-short-sparkle", {}),
    "rankup": ("notification-success-flourish", {}),
    "warn": ("notification-alert-soft", {}),
    "star_lost": ("notification-failure-pluck", {}),
    "crate": ("props-box-open", {}),
    "ship_full": ("tone-ding-high", {"max": 0.6}),
    "stamp": ("mechanical-switch-heavy", {}),
}


# ------------------------------------------------------------------ helpers

def read_wav(path: Path) -> np.ndarray:
    with wave.open(str(path)) as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        x = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
        x = np.where(x & 0x800000, x - 0x1000000, x) / 8388608.0
    elif sw == 2:
        x = np.frombuffer(raw, dtype=np.int16) / 32768.0
    else:
        raise ValueError(f"{path}: {sw * 8}-bit not supported")
    x = x.reshape(-1, ch).mean(axis=1)
    if sr != SR:
        g = np.gcd(SR, sr)
        x = signal.resample_poly(x, SR // g, sr // g)
    return x


def write_wav(name: str, x: np.ndarray) -> None:
    x = np.clip(x, -1.0, 1.0)
    with wave.open(str(OUT / f"{name}.wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def active_rms(x: np.ndarray) -> float:
    """RMS over the part of the sound that is actually sounding."""
    if len(x) == 0:
        return 0.0
    thr = np.abs(x).max() * 0.05
    a = x[np.abs(x) > thr]
    return float(np.sqrt((a ** 2).mean())) if len(a) else 0.0


def trim(x: np.ndarray, max_len: float | None = None) -> np.ndarray:
    thr = np.abs(x).max() * 10 ** (-50 / 20)
    nz = np.nonzero(np.abs(x) > thr)[0]
    if len(nz):
        x = x[max(0, nz[0] - int(0.002 * SR)): nz[-1] + 1]
    if max_len:
        x = x[: int(max_len * SR)]
    fade = min(len(x) // 4, int(0.03 * SR))
    if fade > 0:
        x = x.copy()
        x[-fade:] *= np.linspace(1, 0, fade) ** 2
    return x


def match_level(x: np.ndarray, ref_rms: float, peak_cap: float = 0.89) -> np.ndarray:
    r = active_rms(x)
    if r > 0:
        x = x * (ref_rms / r)
    p = np.abs(x).max()
    if p > peak_cap:
        x = x * (peak_cap / p)
    return x


# ------------------------------------------------------------------ horns

def _bandpass_gain(x, f, q, gain_db):
    b, a = signal.iirpeak(f / (SR / 2), q)
    return x + (10 ** (gain_db / 20) - 1) * signal.lfilter(b, a, x)


def harbour_echo(x: np.ndarray, tail: float = 1.1, wet: float = 0.22) -> np.ndarray:
    """Open-air harbour: two slap-backs off the warehouses plus a soft diffuse tail."""
    n = len(x) + int(tail * SR)
    y = np.zeros(n)
    y[: len(x)] += x
    lp_b, lp_a = signal.butter(2, 1800 / (SR / 2))
    dark = signal.lfilter(lp_b, lp_a, x)
    for delay, g in ((0.19, 0.30), (0.41, 0.16), (0.66, 0.07)):
        d = int(delay * SR)
        y[d: d + len(x)] += g * dark
    ir_n = int(tail * SR)
    ir = rng.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / SR * (6.9 / tail))
    ir = signal.lfilter(lp_b, lp_a, ir)
    ir /= np.sqrt((ir ** 2).sum())
    rev = signal.fftconvolve(x, ir)[:n]
    y[: len(rev)] += wet * rev
    return y


def horn_tone(f0: float, dur: float, brass: float = 0.85, scoop: float = 0.05) -> np.ndarray:
    n = int(dur * SR)
    tt = np.arange(n) / SR
    # pitch: starts a little flat and settles (air pressure building), gentle drift
    bend = 1.0 - scoop * np.exp(-tt / 0.045)
    drift = 1.0 + 0.0025 * np.sin(2 * np.pi * 0.7 * tt + rng.uniform(0, 6)) + 0.0012 * np.sin(2 * np.pi * 5.2 * tt)
    phase = 2 * np.pi * np.cumsum(f0 * bend * drift) / SR
    x = np.zeros(n)
    k = 1
    while f0 * k < 5000:
        amp = 1.0 / k ** brass
        if k % 2 == 0:
            amp *= 0.62          # reed-like: odd harmonics a touch stronger
        x += amp * np.sin(k * phase + 0.3 * k)
        k += 1
    # brightness grows with the blast: low-pass opens over the attack
    env_bright = 1 - np.exp(-tt / 0.09)
    lp1 = signal.lfilter(*signal.butter(2, 700 / (SR / 2)), x)
    x = lp1 + env_bright * (x - lp1)
    x = np.tanh(1.8 * x / np.abs(x).max())
    x = signal.lfilter(*signal.butter(2, 45 / (SR / 2), btype="high"), x)   # no DC from the clipper
    # bell resonances and distance roll-off
    x = _bandpass_gain(x, 320, 2.2, 6)
    x = _bandpass_gain(x, 1150, 3.0, 4)
    x = signal.lfilter(*signal.butter(2, 3400 / (SR / 2)), x)
    # breath
    breath = signal.lfilter(*signal.butter(2, [500 / (SR / 2), 2200 / (SR / 2)], btype="band"), rng.standard_normal(n))
    x += 0.05 * breath / np.abs(breath).max()
    # envelope: soft attack with slight swell, clean release
    a, r = min(int(0.07 * SR), n // 3), min(int(0.16 * SR), n // 2)
    e = np.ones(n)
    e[:a] = np.sin(np.linspace(0, np.pi / 2, a)) ** 1.5
    e[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    e *= 1 + 0.06 * np.exp(-((tt - 0.12) / 0.06) ** 2)
    return x * e


# The coin sound stays the original one from tools/make_audio.py (players preferred it).


def make_horns() -> dict:
    out = {}
    # feeder: one round mid horn
    out["dispatch_feeder"] = harbour_echo(horn_tone(116.5, 0.62) + 0.35 * horn_tone(174.6, 0.62, 1.0), 1.0, 0.2)
    # tanker: deep two-tone chord, a little longer
    out["dispatch_tanker"] = harbour_echo(horn_tone(87.3, 0.78, 0.8) + 0.7 * horn_tone(110.0, 0.78, 0.85), 1.2, 0.22)
    # coaster: cheerful double toot, higher
    toot1 = horn_tone(196.0, 0.15, 0.95, 0.03)
    toot2 = horn_tone(196.0, 0.28, 0.95, 0.03)
    gap = np.zeros(int(0.07 * SR))
    out["dispatch_coaster"] = harbour_echo(np.concatenate([toot1, gap, toot2]) + 0.0, 0.9, 0.18)
    # title / harbour screen horn: long, distant, deep
    out["horn"] = harbour_echo(0.8 * horn_tone(98.0, 1.05, 0.8) + 0.55 * horn_tone(146.8, 1.05, 0.9), 1.4, 0.3)
    return out


# ------------------------------------------------------------------ main

def main() -> None:
    old = {p.stem: read_wav(p) for p in OUT.glob("*.wav")}
    for name, x in make_horns().items():
        ref = 0.21 if name.startswith("dispatch") else active_rms(old.get(name, x))
        write_wav(name, match_level(x, ref, 0.8))
        print(f"{name:18s} synth  {len(x) / SR:.2f}s")
    if len(sys.argv) < 2:
        return
    kit = Path(sys.argv[1])
    for name, (sid, opt) in PACK.items():
        src = next(kit.glob(f"sounds/*/{sid}.wav"), None)
        if src is None:
            print(f"{name:18s} MISSING {sid}")
            continue
        x = read_wav(src)
        if opt.get("pitch"):
            p = opt["pitch"]
            x = signal.resample(x, int(len(x) / p))
        x = trim(x, opt.get("max"))
        ref = active_rms(old[name]) if name in old else 0.15
        if name == "dispatch_seal":
            ref = 0.12   # was nearly inaudible
        if name == "dispatch_chime":
            ref = 0.09
        write_wav(name, match_level(x, ref))
        print(f"{name:18s} {sid:32s} {len(x) / SR:.2f}s")


if __name__ == "__main__":
    main()
