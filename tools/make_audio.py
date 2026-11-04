#!/usr/bin/env python3
"""Erzeugt Musik und Soundeffekte für CircleWar (alles synthetisch, keine fremden Dateien).
Aufruf: python3 tools/make_audio.py   (benötigt numpy, scipy, ffmpeg)"""
import os, subprocess, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)


def hz(note):  # MIDI-Note -> Hz
    return 440.0 * 2 ** ((note - 69) / 12.0)


def lp(x, f):
    b, a = butter(2, f / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x, f):
    b, a = butter(2, f / (SR / 2), "high")
    return lfilter(b, a, x)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def wave_(kind, f, dur):
    t = t_(dur)
    ph = 2 * np.pi * f * t
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if kind == "saw":
        return 2 * ((f * t) % 1.0) - 1
    raise ValueError(kind)


def env(n, a=0.01, d=0.2, sustain=0.0):
    t = np.arange(n) / SR
    e = np.minimum(t / max(a, 1e-4), 1.0) * (sustain + (1 - sustain) * np.exp(-t / max(d, 1e-4)))
    return e


def note(kind, f, dur, a=0.01, d=0.2, sustain=0.0, vol=1.0):
    x = wave_(kind, f, dur)
    return x * env(len(x), a, d, sustain) * vol


def put(buf, x, start, loop=True):
    i = int(start * SR)
    n = len(x)
    if loop:  # kreisförmig addieren, damit die Schleife nahtlos ist
        idx = (np.arange(n) + i) % len(buf)
        np.add.at(buf, idx, x)
    else:
        end = min(len(buf), i + n)
        buf[i:end] += x[: end - i]


def norm(x, peak=0.8):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save_wav(name, x):
    path = os.path.join(OUT, name)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path


def to_ogg(wav_path, q=3):
    ogg = wav_path[:-4] + ".ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis",
                    "-q:a", str(q), ogg], check=True)
    os.remove(wav_path)


# ---------- Musik ----------

def chord(root, minor=True):
    return [root, root + (3 if minor else 4), root + 7]


def menu_music():
    bpm = 80
    beat = 60 / bpm
    bar = 4 * beat
    prog = [(57, True), (53, False), (48, False), (55, False)]  # Am F C G
    total = 8 * bar
    buf = np.zeros(int(total * SR))
    for ci, (root, minor) in enumerate(prog):
        start = ci * 2 * bar
        notes = chord(root, minor)
        # weiches Pad
        for n in notes:
            for det in (0.997, 1.003):
                x = wave_("sine", hz(n + 12) * det, 2 * bar + 1.0)
                e = env(len(x), 0.8, 3.0, 0.5)
                put(buf, x * e * 0.10, start)
        # Bass
        for b in range(2):
            put(buf, note("sine", hz(root - 12), bar, 0.02, 0.9, 0.0, 0.35), start + b * bar)
        # Arpeggio in Achteln
        pat = [0, 1, 2, 1, 2, 1, 0, 1]
        for step in range(16):
            n = notes[pat[step % 8]] + 24
            put(buf, note("tri", hz(n), 0.6, 0.005, 0.18, 0.0, 0.16), start + step * beat / 2)
    buf = lp(buf, 5000)
    return norm(buf, 0.75)


def game_music():
    bpm = 120
    beat = 60 / bpm
    bar = 4 * beat
    prog = [(50, True), (46, False), (53, False), (48, False)]  # Dm Bb F C
    total = 16 * bar
    buf = np.zeros(int(total * SR))
    for rep in range(2):
        for ci, (root, minor) in enumerate(prog):
            start = (rep * 4 + ci) * 2 * bar
            notes = chord(root, minor)
            for n in notes:
                x = wave_("saw", hz(n), 2 * bar + 0.4)
                put(buf, lp(x, 900) * env(len(x), 0.4, 3.0, 0.6) * 0.07, start)
            for step in range(16):  # Bass in Achteln
                n = root - 12 + (7 if step % 4 == 3 else 0)
                put(buf, note("square", hz(n), 0.25, 0.005, 0.12, 0.0, 0.16), start + step * beat / 2)
            octave = 24 if rep == 0 else 36
            pat = [0, 2, 1, 2, 0, 2, 1, 2] if rep == 0 else [0, 1, 2, 1, 2, 1, 2, 0]
            for step in range(32):  # Arpeggio in Sechzehnteln
                n = notes[pat[step % 8] % 3] + octave
                put(buf, note("tri", hz(n), 0.3, 0.003, 0.09, 0.0, 0.12), start + step * beat / 4)
    # Schlagzeug
    for b in range(16 * 4):
        t0 = b * beat
        k = np.sin(2 * np.pi * (50 + 110 * np.exp(-t_(0.25) * 35)) * t_(0.25)) * np.exp(-t_(0.25) * 14)
        put(buf, k * 0.5, t0)
        h = hp(rng.standard_normal(int(SR * 0.05)), 7000) * np.exp(-t_(0.05) * 80)
        put(buf, h * 0.12, t0 + beat / 2)
        if b % 2 == 1:
            s = hp(rng.standard_normal(int(SR * 0.12)), 1800) * np.exp(-t_(0.12) * 28)
            put(buf, s * 0.18, t0)
    buf = lp(buf, 7000)
    return norm(buf, 0.75)


# ---------- Effekte ----------

def sfx_click():
    return norm(note("sine", 1300, 0.05, 0.001, 0.02) + note("sine", 2600, 0.05, 0.001, 0.015) * 0.3, 0.5)


def sfx_send():
    t = t_(0.2)
    f = 350 + 700 * (t / 0.2) ** 1.5
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.2) ** 0.7
    x += lp(rng.standard_normal(len(t)), 2500) * 0.25 * np.sin(np.pi * t / 0.2)
    return norm(x, 0.55)


def sfx_hit():
    n = int(SR * 0.22)
    t = np.arange(n) / SR
    noise = hp(rng.standard_normal(n), 800) * np.exp(-t * 22)
    thump = np.sin(2 * np.pi * (140 * np.exp(-t * 9)) * t) * np.exp(-t * 14)
    crack = (rng.random(n) < 0.015) * rng.standard_normal(n) * np.exp(-t * 10)
    return norm(noise * 0.7 + thump * 0.9 + crack * 1.2, 0.8)


def arp(notes, step, kind="tri", d=0.18, vol=0.5):
    buf = np.zeros(int(SR * (step * len(notes) + 0.5)))
    for i, n in enumerate(notes):
        put(buf, note(kind, hz(n), 0.5, 0.004, d, 0.0, vol), i * step, loop=False)
    return buf


def sfx_conquer():
    x = arp([72, 76, 79, 84], 0.07)
    x += arp([60, 64, 67, 72], 0.07, "sine", 0.25, 0.25)
    return norm(x, 0.7)


def sfx_lost():
    return norm(arp([69, 65, 62, 57], 0.09, "saw", 0.2, 0.4) * 1.0 + 0, 0.6) if False else norm(
        lp(arp([69, 65, 62, 57], 0.09, "saw", 0.2, 0.35), 2500), 0.6)


def sfx_win():
    x = arp([72, 76, 79, 84, 79, 84, 88], 0.11, "tri", 0.3, 0.5)
    for n in (72, 76, 79, 84):
        put(x, note("sine", hz(n), 1.2, 0.01, 0.6, 0.0, 0.18), 0.66, loop=False)
    return norm(x, 0.75)


def sfx_lose():
    x = arp([67, 63, 60, 55, 51], 0.18, "tri", 0.4, 0.6)
    put(x, note("sine", hz(43), 1.4, 0.01, 0.9, 0.0, 0.35), 0.5, loop=False)
    return norm(lp(x, 3000), 0.7)


def main():
    os.makedirs(OUT, exist_ok=True)
    to_ogg(save_wav("music_menu.wav", menu_music()))
    to_ogg(save_wav("music_game.wav", game_music()))
    for name, fn in [("click", sfx_click), ("send", sfx_send), ("hit", sfx_hit),
                     ("conquer", sfx_conquer), ("lost", sfx_lost), ("win", sfx_win), ("lose", sfx_lose)]:
        save_wav("sfx_%s.wav" % name, fn())
    print(sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
