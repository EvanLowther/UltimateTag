"""Map sounds (the Metro's train, gadgets), each map's ambience loop and the lobby's lo-fi music."""

from __future__ import annotations

import numpy as np

from core import click, thump, whoosh
from registry import sound
from synth import (
    adsr, bell, bp, crossfade_loop, drive, env, fm, glide, hp, loop_seam, lp, mix, n_of, noise, note,
    osc, place, reverb, reverb_stereo, seed, silence, svf, times, tremolo, warp,
)

AMB_SR = 22050
AMB_LEN = 12.0


# ---- The Metro's train -----------------------------------------------------------------

@sound("train_horn", "Maps", "Train horn", "The Metro's train sounds its horn as it comes into the station.",
       [("A", "Two-tone horn"), ("B", "Three-note chord horn"), ("C", "Two short toots")],
       where="3D on the train's front car")
def train_horn(v):
    def horn(freqs, seconds):
        t = times(seconds)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
        tone = sum(osc(f * vib * d, seconds, "saw") for f in freqs for d in (0.997, 1.003))
        return drive(lp(tone, 2400), 1.5) * adsr(seconds, 0.05, 0.1, 0.85, 0.2) * 0.35
    if v == 0:
        return reverb(horn((311, 370), 1.3), 2.0, 0.35)
    if v == 1:
        return reverb(horn((277, 349, 415), 1.4), 2.0, 0.35)
    return reverb(place(horn((330, 392), 0.3), horn((330, 392), 0.55), 0.42), 2.0, 0.35)


@sound("train_chime", "Maps", "Door chime", "Plays before the train's doors start to close.",
       [("A", "Three falling notes"), ("B", "Ding-dong"), ("C", "Rising notes + warning beeps")],
       where="3D at the train (the platform hears it)")
def train_chime(v):
    if v == 0:
        out = silence(1.5)
        for i, n in enumerate(("E5", "C5", "A4")):
            out = place(out, bell(note(n), 1.0, 0.8, 1.0) * 0.5, i * 0.32)
        return reverb(out, 1.6, 0.3)
    if v == 1:
        out = place(bell(note("G5"), 1.0, 0.8, 1.0) * 0.5, bell(note("E5"), 1.4, 0.8, 1.0) * 0.5, 0.45)
        return reverb(out, 1.6, 0.3)
    out = silence(2.0)
    for i, n in enumerate(("C5", "E5", "G5")):
        out = place(out, bell(note(n), 0.6, 0.8, 1.0) * 0.45, i * 0.18)
    for i in range(4):
        beep = osc(note("A5"), 0.12, "square") * env(0.12, 0.002, 0.06, 0.05) * 0.18
        out = place(out, lp(beep, 3000), 0.75 + i * 0.3)
    return reverb(out, 1.4, 0.25)


@sound("train_doors", "Maps", "Doors", "The train's doors sliding open or shut (one sound for both).",
       [("A", "Pneumatic hiss + thunk"), ("B", "Quick slide + clack")], where="3D at each car")
def train_doors(v):
    seed(41)
    if v == 0:
        hiss = hp(noise(0.7), 2500) * env(0.7, 0.01, 0.5, 0.1) * 0.6
        slide = lp(noise(1.0), 400) * np.sin(np.linspace(0, np.pi, n_of(1.0))) * 0.6
        out = mix(hiss, slide)
        out = place(out, mix(thump(140, 60, 0.15, 0.9), lp(noise(0.06), 2000) * env(0.06, 0.001, 0.05)), 1.0)
        return reverb(out, 1.4, 0.3)
    slide = bp(noise(0.55), 300, 1500) * np.sin(np.linspace(0, np.pi, n_of(0.55))) ** 0.5 * 0.5
    clack = mix(fm(900, 2.3, 2.5 * np.exp(-times(0.1) * 40), 0.1) * env(0.1, 0.001, 0.08) * 0.4, thump(180, 90, 0.08, 0.6))
    return reverb(place(slide, clack, 0.55), 1.4, 0.3)


@sound("train_brakes", "Maps", "Brakes", "The train slowing into the platform: a squeal, then an air hiss.",
       [("A", "Long squeal + air hiss"), ("B", "Short squeal, softer")], where="3D on the train")
def train_brakes(v):
    seed(42)
    seconds = 2.2 if v == 0 else 1.2
    t = times(seconds)
    jitter = np.cumsum(np.random.default_rng(3).standard_normal(len(t))) * 0.02
    f = 2800 + 60 * np.sin(2 * np.pi * 3 * t) + jitter
    squeal = (osc(f, seconds) + 0.4 * osc(f * 1.5, seconds) + 0.2 * osc(f * 2.01, seconds))
    squeal *= adsr(seconds, 0.3, 0.2, 0.8, 0.5) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t) ** 2) * 0.18
    grind = lp(noise(seconds, "brown"), 300) * adsr(seconds, 0.2, 0.2, 0.8, 0.5) * 0.4
    out = mix(squeal * (1.0 if v == 0 else 0.6), grind)
    air = hp(noise(0.9), 1500) * env(0.9, 0.01, 0.8) * 0.5
    out = place(out, air, seconds - 0.1)
    return reverb(out, 1.6, 0.3)


@sound("train_run", "Maps", "Train running (loop)", "Loops on the train while it moves: rumble, wheel clacks, motor.",
       [("A", "Rumble, clacks and motor whine"), ("B", "Rattly, no whine")],
       loop=True, sr=AMB_SR, level=-3, where="3D on each car while it moves")
def train_run(v):
    sr = AMB_SR
    seed(43)
    length = 8.0
    rumble = lp(noise(length + 1, "brown", sr), 260, sr=sr) * 0.6
    out = rumble.copy()
    for i in range(int(length)):
        for k, g in ((0.0, 1.0), (0.13, 0.8)):
            clack = mix(osc(glide(130, 60, 0.1, sr=sr), 0.1, sr=sr) * env(0.1, 0.001, 0.09, sr=sr) * 0.8,
                        lp(noise(0.05, sr=sr), 1800, sr=sr) * env(0.05, 0.001, 0.04, sr=sr) * 0.8)
            out = place(out, clack * g, i + k + 0.2, sr=sr)
    if v == 0:
        whine = (osc(420, length + 1, sr=sr) + 0.4 * osc(840, length + 1, sr=sr)) * 0.05
        out = mix(out, whine)
    else:
        rattle = bp(noise(length + 1, sr=sr), 1500, 4000, sr=sr) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * times(length + 1, sr))) * 0.12
        out = mix(out, rattle)
    return crossfade_loop(out, length, 0.8, sr)


# ---- Gadgets ---------------------------------------------------------------------------

@sound("launch", "Maps", "Launch pad", "A launch pad or vent throws someone.",
       [("A", "Deep whump + air burst"), ("B", "Pneumatic blast"), ("C", "Springy boing-whoosh")],
       where="3D at the pad")
def launch(v):
    seed(44)
    if v == 0:
        burst = whoosh(0.45, 400, 4000, 2500, 0.9, shape=lambda u: np.exp(-u * 5) * (1 - np.exp(-u * 60)))
        return reverb(mix(drive(thump(160, 40, 0.4, 1.0), 1.5), burst * 0.8), 0.6, 0.15)
    if v == 1:
        hiss = hp(noise(0.5), 1200) * env(0.5, 0.002, 0.45) * 0.9
        return reverb(mix(hiss, thump(220, 70, 0.12, 0.8), click(0.004, 1000, 5000, 0.8)), 0.5, 0.15)
    t = times(0.5)
    boing = osc(glide(180, 520, 0.5) * (1 + 0.08 * np.sin(2 * np.pi * 18 * t) * np.exp(-t * 4)), 0.5) * env(0.5, 0.002, 0.45) * 0.6
    return reverb(mix(boing, whoosh(0.4, 500, 3000, 1500, 1.0) * 0.6), 0.5, 0.15)


@sound("popup", "Maps", "Jack-in-the-box", "The Playroom's jack-in-the-box springs open.",
       [("A", "Lid thunk + spring boing"), ("B", "Cartoon pop + high boing"), ("C", "Metal coil sproing")],
       where="3D at the toy")
def popup(v):
    seed(45)
    t = times(0.9)
    if v == 0:
        f = 260 + 90 * np.sin(2 * np.pi * 13 * t) * np.exp(-t * 3.5)
        boing = osc(f, 0.9) * env(0.9, 0.003, 0.8) * 0.6
        lid = mix(thump(200, 90, 0.08, 0.7), bp(noise(0.05), 600, 2500) * env(0.05, 0.001, 0.04))
        return reverb(place(lid, boing, 0.03), 0.6, 0.15)
    if v == 1:
        pop = mix(osc(glide(250, 1000, 0.04), 0.04) * env(0.04, 0.001, 0.035), click(0.003, 1500, 7000, 0.8))
        f = 520 + 160 * np.sin(2 * np.pi * 16 * t) * np.exp(-t * 4)
        boing = osc(f, 0.9) * env(0.9, 0.003, 0.7) * 0.5
        return reverb(place(pop, boing, 0.02), 0.6, 0.15)
    f = glide(300, 900, 0.9) * (1 + 0.15 * np.sin(2 * np.pi * 22 * t) * np.exp(-t * 3))
    coil = fm(f, 2.41, 2.5 * np.exp(-t * 3), 0.9) * env(0.9, 0.002, 0.8) * 0.45
    return reverb(coil, 0.6, 0.18)


@sound("spinner", "Maps", "Spinner bar", "The Playroom's spinner bar sweeping past you.",
       [("A", "Deep whoom"), ("B", "Airy whoosh"), ("C", "Whoosh + rattle")], where="3D on the bar as it passes")
def spinner(v):
    if v == 0:
        return mix(whoosh(0.6, 150, 700, 200, 1.6), osc(glide(90, 60, 0.6), 0.6) * np.sin(np.linspace(0, np.pi, n_of(0.6))) ** 2 * 0.3)
    if v == 1:
        return whoosh(0.5, 500, 2600, 800, 1.2)
    rattle = bp(noise(0.55), 2000, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * times(0.55))) * np.sin(np.linspace(0, np.pi, n_of(0.55))) ** 2 * 0.3
    return mix(whoosh(0.55, 300, 1600, 500, 1.3), rattle)


# ---- Ambience (12 s loops) -------------------------------------------------------------

def gusts(seconds, sr, rate=0.25, seed_n=1, lo=0.3, hi=1.0):
    """A smooth random curve between lo and hi."""
    rng = np.random.default_rng(seed_n)
    pts = int(seconds * rate) + 3
    xs = np.linspace(0, seconds, pts)
    ys = rng.uniform(lo, hi, pts)
    return np.interp(times(seconds, sr), xs, ys)


def drips(seconds, sr, per_second, lo=1400, hi=3200, gain=0.15, seed_n=2):
    out = silence(seconds, sr)
    rng = np.random.default_rng(seed_n)
    for _ in range(int(seconds * per_second)):
        f = rng.uniform(lo, hi)
        d = osc(glide(f, f * 0.6, 0.06, sr=sr), 0.06, sr=sr) * env(0.06, 0.001, 0.05, sr=sr) * gain * rng.uniform(0.3, 1)
        out = place(out, d, rng.uniform(0, seconds - 0.1), sr=sr)
    return out


def amb(fn):
    """Renders an ambience a second long, then folds it into a seamless 12 s loop."""
    def wrapped(v):
        seed(100 + v)
        x = fn(v, AMB_LEN + 1.0, AMB_SR)
        return crossfade_loop(x, AMB_LEN, 1.0, AMB_SR)
    return wrapped


@sound("amb_lobby", "Ambience", "Lobby: rain", "The Night Market under rain (plays under the lobby music).",
       [("A", "Heavy rain, city rumble, neon buzz"), ("B", "Lighter rain, more drips")],
       loop=True, sr=AMB_SR, level=-4, where="2D while you're in the lobby")
@amb
def amb_lobby(v, s, sr):
    rain = hp(lp(noise(s, "pink", sr), 9000, sr=sr), 500, sr=sr) * gusts(s, sr, 0.3, 4, 0.75, 1.0)
    patter = bp(noise(s, sr=sr), 2500, 7000, sr=sr) * (np.random.default_rng(5).random(n_of(s, sr)) < 0.004) * 6
    city = lp(noise(s, "brown", sr), 180, sr=sr) * 0.5
    if v == 0:
        neon = (osc(120, s, "saw", sr) * 0.02 + osc(240, s, sr=sr) * 0.01) * gusts(s, sr, 0.5, 6, 0.5, 1)
        return mix(rain * 0.8, patter * 0.4, city, neon, drips(s, sr, 1.5, gain=0.08))
    return mix(rain * 0.45, patter * 0.5, city * 0.6, drips(s, sr, 5, gain=0.14, seed_n=8))


@sound("amb_clocktower", "Ambience", "Clocktower", "Inside the tower: the clock ticking, gears grinding.",
       [("A", "Tick-tock every second, gear grind"), ("B", "Slow heavy tock, creaking")],
       loop=True, sr=AMB_SR, level=-4, where="2D while you're on the Clocktower")
@amb
def amb_clocktower(v, s, sr):
    out = lp(noise(s, "brown", sr), 140, sr=sr) * 0.35
    period = 1.0 if v == 0 else 2.0
    i = 0
    while i * period < s:
        f = (1900, 1500)[i % 2] if v == 0 else 700
        tick = mix(bp(noise(0.04, sr=sr), f * 0.7, f * 1.6, sr=sr) * env(0.04, 0.001, 0.035, sr=sr) * 2.5,
                   osc(f, 0.05, sr=sr) * env(0.05, 0.001, 0.04, sr=sr) * 0.3)
        out = place(out, tick * (0.6 if v == 0 else 1.0), i * period + 0.1, sr=sr)
        i += 1
    t = times(s, sr)
    creak = fm(95 + 10 * np.sin(2 * np.pi * 0.2 * t), 2.03, 1.5, s, sr) * gusts(s, sr, 0.4, 9, 0.0, 1.0) ** 3 * 0.06
    out = mix(out, creak)
    return reverb(out, 2.2, 0.35, sr=sr, tail=False)


@sound("amb_rooftop", "Ambience", "Rooftop District", "High above the city: wind and far-off traffic.",
       [("A", "Gusty wind with a whistle"), ("B", "Calmer breeze, city hum")],
       loop=True, sr=AMB_SR, level=-4, where="2D while you're on the Rooftops")
@amb
def amb_rooftop(v, s, sr):
    g = gusts(s, sr, 0.35 if v == 0 else 0.2, 13, 0.25, 1.0)
    wind = svf(noise(s, "pink", sr), 300 + 900 * g, 0.9, "bp", sr) * (0.4 + 0.6 * g) * (1.6 if v == 0 else 0.9)
    whistle = svf(noise(s, sr=sr), 900 + 300 * g, 9, "bp", sr) * g ** 2 * (0.25 if v == 0 else 0.05)
    city = lp(noise(s, "brown", sr), 250, sr=sr) * (0.4 if v == 0 else 0.7)
    return mix(wind, whistle, city)


@sound("amb_metro", "Ambience", "Metro", "The underground station: electrical hum, vents, a far-off rumble.",
       [("A", "Hum, vents, distant rumble"), ("B", "Emptier, echoing drips")],
       loop=True, sr=AMB_SR, level=-5, where="2D while you're on the Metro")
@amb
def amb_metro(v, s, sr):
    hum = (osc(60, s, sr=sr) * 0.12 + osc(120, s, sr=sr) * 0.06 + lp(osc(120, s, "saw", sr), 2500, sr=sr) * 0.015)
    vent = lp(noise(s, "pink", sr), 1300, sr=sr) * 0.35
    t = times(s, sr)
    swell = np.exp(-((t - s * 0.55) / 2.0) ** 2)
    rumble = lp(noise(s, "brown", sr), 110, sr=sr) * (0.2 + 0.8 * swell)
    if v == 0:
        return mix(hum, vent, rumble)
    return reverb(mix(hum * 0.6, vent * 0.4, drips(s, sr, 0.8, 900, 2200, 0.12, 15)), 2.5, 0.4, sr=sr, tail=False)


@sound("amb_school", "Ambience", "School", "An empty school: air conditioning, fluorescent lights, a door far off.",
       [("A", "AC hum, light buzz, distant door"), ("B", "Quiet hall, clock ticking")],
       loop=True, sr=AMB_SR, level=-6, where="2D while you're in the School")
@amb
def amb_school(v, s, sr):
    hvac = lp(noise(s, "pink", sr), 700, sr=sr) * 0.4
    buzz = hp(osc(120, s, "saw", sr), 1500, sr=sr) * 0.012
    out = mix(hvac, buzz)
    if v == 0:
        door = reverb(mix(thump(110, 60, 0.2, 0.5), lp(noise(0.1, sr=sr), 1200, sr=sr) * env(0.1, 0.001, 0.08, sr=sr) * 0.4), 2.5, 0.6, sr=sr)
        out = place(out, door * 0.5, 4.0, sr=sr)
        return out
    for i in range(int(s)):
        tick = bp(noise(0.02, sr=sr), 2000, 5000, sr=sr) * env(0.02, 0.001, 0.018, sr=sr) * 0.6
        out = place(out, tick, i + 0.3, sr=sr)
    return reverb(out, 1.5, 0.3, sr=sr, tail=False)


def chirp(sr, f0, f1, seconds=0.07, gain=0.1):
    return osc(glide(f0, f1, seconds, sr=sr), seconds, sr=sr) * np.sin(np.linspace(0, np.pi, n_of(seconds, sr))) * gain


@sound("amb_playroom", "Ambience", "Playroom", "A kid's bedroom: a wall clock, birds outside.",
       [("A", "Soft clock tick, birds outside"), ("B", "Quiet room, wind chimes")],
       loop=True, sr=AMB_SR, level=-7, where="2D while you're in the Playroom")
@amb
def amb_playroom(v, s, sr):
    room = lp(noise(s, "brown", sr), 350, sr=sr) * 0.25
    out = room
    rng = np.random.default_rng(20 + v)
    if v == 0:
        for i in range(int(s)):
            out = place(out, bp(noise(0.02, sr=sr), 1500, 4000, sr=sr) * env(0.02, 0.001, 0.015, sr=sr) * 0.35, i + 0.5, sr=sr)
        for _ in range(9):
            at = rng.uniform(0, s - 1)
            base = rng.uniform(2800, 4200)
            for k in range(rng.integers(2, 5)):
                out = place(out, chirp(sr, base, base * rng.uniform(1.2, 1.6), 0.06, 0.05), at + k * 0.11, sr=sr)
        return out
    pent = [note(n) for n in ("C6", "D6", "E6", "G6", "A6", "C7")]
    for _ in range(10):
        f = pent[rng.integers(0, len(pent))]
        out = place(out, bell(f, 2.0, 0.6, 3.01, sr) * 0.05, rng.uniform(0, s - 2), sr=sr)
    return reverb(out, 1.5, 0.25, sr=sr, tail=False)


# ---- Lobby music -----------------------------------------------------------------------

MUS_SR = 32000
BPM = 78
BEAT = 60 / BPM
BAR = BEAT * 4
BARS = 8


def ep(freq, seconds, sr, vel=1.0):
    """An electric piano: FM tine with a bell attack, warm decay."""
    t = times(seconds, sr)
    body = fm(freq, 1.0, 1.4 * np.exp(-t * 2.5) + 0.25, seconds, sr)
    tine = osc(freq * 14, seconds, sr=sr) * np.exp(-t * 40) * 0.08
    return (body + tine) * env(seconds, 0.004, seconds, sr=sr) * vel


def kick(sr):
    return mix(osc(glide(130, 48, 0.35, "fast", sr), 0.35, sr=sr) * env(0.35, 0.002, 0.32, sr=sr),
               lp(noise(0.01, sr=sr), 3000, sr=sr) * env(0.01, 0.0005, 0.009, sr=sr) * 0.4)


def snare(sr):
    return mix(lp(bp(noise(0.2, sr=sr), 900, 6000, sr=sr), 4000, sr=sr) * env(0.2, 0.001, 0.17, sr=sr) * 1.2,
               osc(glide(210, 170, 0.08, sr=sr), 0.08, sr=sr) * env(0.08, 0.001, 0.07, sr=sr) * 0.4)


def hat(sr, gain):
    return hp(noise(0.05, sr=sr), 7000, sr=sr) * env(0.05, 0.0005, 0.04, sr=sr) * gain


PROGRESSIONS = [
    # (bass root, chord notes) per bar, 4 bars repeated twice.
    [("F2", ("F3", "A3", "C4", "E4", "G4")), ("E2", ("E3", "G3", "B3", "D4")),
     ("D2", ("D3", "F3", "A3", "C4", "E4")), ("C2", ("C3", "E3", "G3", "B3", "D4"))],
    [("D2", ("D3", "F3", "A3", "C4", "E4")), ("G1", ("F3", "B3", "E4", "A4")),
     ("C2", ("E3", "G3", "B3", "D4")), ("A1", ("G3", "C4", "E4", "B3"))],
    [("Ab1", ("Ab3", "C4", "Eb4", "G4")), ("G1", ("G3", "Bb3", "D4", "F4")),
     ("F1", ("F3", "Ab3", "C4", "Eb4", "G4")), ("Eb2", ("Eb3", "G3", "Bb3", "D4"))],
]
MELODIES = [
    [("E5", 4.5), ("C5", 5.5), ("D5", 6.0), ("A4", 7.5), ("G4", 8.5), ("C5", 9.0), ("E5", 10.0), ("D5", 11.5),
     ("C5", 12.5), ("A4", 13.0), ("G4", 14.0), ("E4", 15.0)],
    [("A5", 4.0), ("G5", 5.0), ("E5", 5.5), ("D5", 7.0), ("E5", 8.5), ("G5", 9.5), ("D5", 11.0),
     ("C5", 12.0), ("B4", 12.5), ("C5", 13.5), ("E5", 14.5)],
    [("G5", 4.5), ("Eb5", 5.5), ("F5", 6.5), ("D5", 8.0), ("Bb4", 9.0), ("C5", 10.5), ("Eb5", 12.0),
     ("D5", 13.0), ("Bb4", 14.0), ("G4", 15.0)],
]


@sound("music_lobby", "Music", "Lobby music", "A chill lo-fi loop (about 25 s) for the Night Market lobby, under the rain.",
       [("A", "Fmaj7 Em7 Dm7 Cmaj7, bell melody"), ("B", "ii-V-I jazz chords, airy melody"), ("C", "Darker, in E-flat")],
       loop=True, sr=MUS_SR, level=-2, where="2D in the lobby (the music slider)")
def music_lobby(v):
    sr = MUS_SR
    seed(300 + v)
    total = BAR * BARS
    keys = np.zeros((n_of(total + 3, sr), 2))
    bass = np.zeros(n_of(total + 3, sr))
    drums = np.zeros(n_of(total + 3, sr))
    lead = np.zeros(n_of(total + 3, sr))
    prog = PROGRESSIONS[v]
    rng = np.random.default_rng(50 + v)
    for bar in range(BARS):
        root, chord = prog[bar % 4]
        start = bar * BAR
        # The chord, rolled a touch, held most of the bar; a softer re-hit on beat 3 and a half.
        for k, n in enumerate(chord):
            pan = -0.4 + 0.8 * k / max(1, len(chord) - 1)
            keys = place(keys, ep(note(n), BAR * 1.1, sr, 0.16), start + k * 0.012, sr=sr, pan=pan)
            keys = place(keys, ep(note(n), BEAT * 1.5, sr, 0.07), start + BEAT * 2.5 + k * 0.01, sr=sr, pan=pan)
        # Bass on 1 and the and-of-2, the second a fifth or the root again.
        b = note(root)
        for at, f, length in ((0, b, BEAT * 1.4), (BEAT * 1.5, b, BEAT * 0.5), (BEAT * 2, b * (1.5 if bar % 2 else 1), BEAT * 1.8)):
            tone = (osc(f, length, sr=sr) + 0.3 * osc(f * 2, length, "tri", sr)) * adsr(length, 0.01, 0.2, 0.7, 0.1, sr) * 0.45
            bass = place(bass, tone, start + at, sr=sr)
        # Drums: kick on 1 and the and-of-2, snare on 2 and 4, swung hats.
        drums = place(drums, kick(sr), start, sr=sr)
        drums = place(drums, kick(sr) * 0.7, start + BEAT * 1.5, sr=sr)
        if bar % 4 == 3:
            drums = place(drums, kick(sr) * 0.5, start + BEAT * 3.5, sr=sr)
        for beat in (1, 3):
            drums = place(drums, snare(sr) * 0.55, start + BEAT * beat + rng.uniform(0, 0.012), sr=sr)
        for eighth in range(8):
            swing = 0.0 if eighth % 2 == 0 else BEAT * 0.1
            g = (0.18 if eighth % 2 == 0 else 0.11) * rng.uniform(0.7, 1.1)
            drums = place(drums, hat(sr, g), start + eighth * BEAT / 2 + swing, sr=sr)
    # A sparse melody over the second half (and a hint in the first).
    for n, beat in MELODIES[v]:
        at = beat * BEAT + BAR * 4
        tone = bell(note(n), 1.4, 0.9, 2.0 if v != 1 else 1.0, sr) * 0.14
        lead = place(lead, tone, at, sr=sr)
        if beat < 8:
            lead = place(lead, tone * 0.5, beat * BEAT, sr=sr)
    keys = tremolo(keys, 4.5, 0.15, sr)
    lead_st = reverb_stereo(np.stack([lead, lead], axis=1), 2.0, 0.45, 0.8, sr)
    lead_st[:, 0] += np.concatenate([np.zeros(n_of(0.18, sr)), lead[: -n_of(0.18, sr)]]) * 0.12  # a slapback echo
    music = mix(keys, bass, lp(drums, 5000, sr=sr) * 0.8, lead_st)
    music = reverb_stereo(music, 1.4, 0.22, 0.7, sr)
    # Lo-fi: dull the top, warble the tape, crackle and hiss.
    music = np.stack([lp(music[:, c], 6000, sr=sr) for c in range(2)], axis=1)
    music = warp(music, 0.5, 0.0018, sr)
    n = len(music)
    crackle = (np.random.default_rng(9).random(n) < 6 / sr) * np.random.default_rng(10).uniform(-1, 1, n)
    crackle = hp(crackle, 1500, sr=sr) * 0.35 + hp(noise(n / sr, "pink", sr), 2000, sr=sr)[:n] * 0.02
    music = music + crackle[:, None]
    music = drive(music * 1.2, 1.3)
    return loop_seam(music, total, sr)
