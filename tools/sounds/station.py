"""The Space Station's sounds: its own round music (spacey, not too sci-fi), the station's hum,
the sliding doors and the electrical buzz down in the trench."""

from __future__ import annotations

import numpy as np

from core import thump
from maps import AMB_SR, MUS_SR, amb, gusts, kick, pluck, soft_pad
from registry import sound
from synth import (
    adsr, bell, bp, env, fm, glide, hp, loop_seam, lp, mix, n_of, noise, note, osc, place, reverb,
    reverb_stereo, seed, silence, svf, times, tremolo, warp,
)

GROUP = "Space Station"


# ---- Music ---------------------------------------------------------------------------------

STATION_SONGS = [
    # bpm, (bass root, chord) per bar for 4 bars, a slow melody (note, beat) over 8 bars
    (66, [("F1", ("F3", "A3", "C4", "E4", "G4")), ("A1", ("E3", "A3", "C4", "G4")),
          ("D2", ("D3", "F3", "A3", "C4", "E4")), ("C2", ("E3", "G3", "C4", "D4"))],
     [("E5", 0), ("G5", 3), ("C5", 6), ("A4", 10), ("C5", 12), ("E5", 16), ("D5", 19), ("C5", 22),
      ("G4", 26), ("A4", 28)]),
    (60, [("D2", ("D3", "A3", "E4", "F#4")), ("B1", ("B2", "F#3", "D4", "A4")),
          ("G1", ("G3", "D4", "F#4", "B4")), ("A1", ("A3", "E4", "C#5"))],
     [("F#5", 0), ("A5", 4), ("E5", 8), ("D5", 12), ("B4", 16), ("C#5", 20), ("E5", 24), ("A4", 28)]),
    (74, [("E2", ("E3", "G3", "B3", "D4")), ("C2", ("C3", "G3", "B3", "E4")),
          ("G1", ("G3", "B3", "D4", "F#4")), ("D2", ("D3", "A3", "D4", "F#4"))],
     [("B4", 0), ("D5", 2), ("E5", 4), ("G5", 8), ("F#5", 12), ("E5", 16), ("D5", 18), ("B4", 20),
      ("A4", 24), ("B4", 28)]),
]


def soft_keys(freq, seconds, sr, vel=1.0):
    """A mellow piano-ish tone: sine with a little octave and a soft attack."""
    t = times(seconds, sr)
    tone = osc(freq, seconds, sr=sr) + 0.3 * osc(freq * 2, seconds, sr=sr) * np.exp(-t * 3) \
        + 0.08 * osc(freq * 3, seconds, sr=sr) * np.exp(-t * 6)
    return tone * env(seconds, 0.01, seconds, sr=sr) * vel


@sound("music_station", GROUP, "Station music",
       "The Space Station's own round music, in place of the quiet round music: spacey and calm, not too sci-fi, low under the game and the station's hum.",
       [("A", "Warm pads, slow piano, a soft pulse"), ("B", "Drifting pads and soft bells, no drums"),
        ("C", "Gentle plucked pulse under pads")],
       loop=True, sr=MUS_SR, level=-3, where="2D during rounds on the Space Station (the music slider)")
def music_station(v):
    sr = MUS_SR
    seed(500 + v)
    bpm, prog, melody = STATION_SONGS[v]
    beat = 60 / bpm
    bar = beat * 4
    bars = 16
    total = bar * bars
    n = n_of(total + 6, sr)
    pads = np.zeros((n, 2))
    low = np.zeros(n)
    pulse = np.zeros(n)
    lead = np.zeros(n)
    rng = np.random.default_rng(70 + v)
    for b in range(bars):
        root, chord = prog[b % 4]
        start = b * bar
        r = note(root)
        if v == 0:
            pads = place(pads, soft_pad(chord, bar + 1.0, sr, 1.0, 1.2, 900, 0.085), start, sr=sr)
            low = place(low, osc(r, bar, sr=sr) * adsr(bar, 0.4, 0.4, 0.7, 0.6, sr) * 0.35, start, sr=sr)
            for k in (0, 2):  # a heartbeat-soft pulse on 1 and 3
                pulse = place(pulse, lp(kick(sr), 500, sr=sr) * 0.3, start + k * beat, sr=sr)
        elif v == 1:
            pads = place(pads, soft_pad(chord, bar * 1.3, sr, 2.0, 2.0, 750, 0.09), start, sr=sr)
            if b % 2 == 0:
                low = place(low, osc(r, bar * 2, sr=sr) * adsr(bar * 2, 1.5, 0.5, 0.8, 1.5, sr) * 0.3, start, sr=sr)
        else:
            pads = place(pads, soft_pad(chord, bar + 0.8, sr, 0.8, 1.0, 1100, 0.06), start, sr=sr)
            low = place(low, osc(r, bar, "tri", sr) * adsr(bar, 0.2, 0.4, 0.6, 0.5, sr) * 0.3, start, sr=sr)
            tones = [note(x) for x in chord]
            for s8 in range(8):  # a soft eighth-note pluck pulse through the chord
                f = tones[(s8 * 2) % len(tones)] * (2 if s8 % 4 == 3 else 1)
                pulse = place(pulse, lp(pluck(f, 0.5, sr, 0.3), 1800, sr=sr) * 0.09 * rng.uniform(0.8, 1.0),
                              start + s8 * beat / 2, sr=sr)
            pulse = place(pulse, lp(kick(sr), 400, sr=sr) * 0.22, start, sr=sr)
    # The melody: twice through its 8 bars, coming in after the first two.
    for rep in range(2):
        for name, at in melody:
            t0 = bar * 2 + rep * bar * 8 + at * beat
            if t0 >= total - beat:
                continue
            f = note(name)
            if v == 1:
                tone = bell(f, 3.0, 1.2, 2.0, sr) * 0.09
            else:
                tone = soft_keys(f, beat * 3, sr, 0.16)
            lead = place(lead, tone, t0, sr=sr)
    lead_st = np.stack([lead, np.concatenate([np.zeros(n_of(beat * 0.75, sr)), lead[: -n_of(beat * 0.75, sr)]]) * 0.5], axis=1)
    music = mix(pads, low, lp(pulse, 3000, sr=sr), lead_st)
    music = reverb_stereo(music, 3.2 if v == 1 else 2.4, 0.38, 0.6, sr)
    music = np.stack([lp(warp(music[:, c], 0.25, 0.0015, sr), 6500, sr=sr) for c in range(2)], axis=1)
    return loop_seam(music, total, sr)


# ---- Ambience: the station's hum (12 s loops) ------------------------------------------------

def clank(f, sr, gain=1.0):
    """A distant metal knock: inharmonic FM ring with a soft thud."""
    s = 1.2
    ring = fm(f, 1.41, 2.0 * np.exp(-times(s, sr) * 6), s, sr) * env(s, 0.002, s, sr=sr) * 0.25
    thud = osc(glide(110, 60, 0.2, sr=sr), 0.2, sr=sr) * env(0.2, 0.002, 0.18, sr=sr) * 0.5
    return lp(mix(ring, thud), 2500, sr=sr) * gain


@sound("amb_station", GROUP, "Station hum",
       "Inside the station: a low engine hum and air through the vents, with the odd far-off knock or beep.",
       [("A", "Engine hum, air vents, distant clanks"), ("B", "Softer hum, airy, faint radio beeps")],
       loop=True, sr=AMB_SR, level=-5, where="2D while you're on the Space Station (under its music)")
@amb
def amb_station(v, s, sr):
    t = times(s, sr)
    hum = (osc(55, s, sr=sr) * 0.12 + osc(110, s, sr=sr) * 0.05
           + lp(osc(82.5, s, "saw", sr), 400, sr=sr) * 0.02) * (0.9 + 0.1 * np.sin(2 * np.pi * 0.17 * t))
    air = lp(noise(s, "pink", sr), 900 if v == 0 else 1600, sr=sr) * gusts(s, sr, 0.3, 21, 0.5, 1.0)
    out = mix(hum * (1.0 if v == 0 else 0.6), air * (0.3 if v == 0 else 0.22))
    rng = np.random.default_rng(31 + v)
    if v == 0:
        for at in (2.3, 7.1, 10.4):
            out = place(out, clank(rng.uniform(180, 320), sr, 0.35), at, sr=sr)
    else:
        for at in (1.5, 6.8):
            f = rng.choice([1180, 1320, 990])
            beep = osc(f, 0.09, sr=sr) * env(0.09, 0.003, 0.08, sr=sr) * 0.05
            out = place(out, beep, at, sr=sr)
            out = place(out, beep, at + 0.16, sr=sr)
    return reverb(out, 2.4, 0.35, sr=sr, tail=False)


# ---- The trench's electrical buzz (a 3D loop down in the trench and tunnel) -----------------

@sound("amb_trench", GROUP, "Trench buzz",
       "Electrical buzzing and crackle you only hear down in the trench and the tunnel, louder the closer you are to the bottom.",
       [("A", "Mains buzz with crackle"), ("B", "Deep transformer hum with sparks")],
       loop=True, sr=AMB_SR, level=-5, where="3D from the trench floor and the tunnel")
@amb
def amb_trench(v, s, sr):
    rng = np.random.default_rng(41 + v)
    if v == 0:
        buzz = lp(osc(120, s, "saw", sr), 1800, sr=sr) * 0.12 + osc(60, s, sr=sr) * 0.1
        buzz = buzz * (0.75 + 0.25 * gusts(s, sr, 2.0, 43, 0.0, 1.0))
        crackle = hp(noise(s, sr=sr), 2500, sr=sr) * (rng.random(n_of(s, sr)) < 0.0025) * 4
        crackle = crackle * gusts(s, sr, 0.8, 44, 0.2, 1.0)
        return mix(buzz, lp(crackle, 7000, sr=sr) * 0.35)
    hum = osc(50, s, sr=sr) * 0.16 + osc(100, s, sr=sr) * 0.08 + lp(osc(150, s, "square", sr), 900, sr=sr) * 0.02
    out = hum * (0.85 + 0.15 * np.sin(2 * np.pi * 0.5 * times(s, sr)))
    for _ in range(5):
        at = rng.uniform(0.3, s - 0.6)
        zap_len = rng.uniform(0.08, 0.25)
        zap = bp(noise(zap_len, sr=sr), 1500, 8000, sr=sr) * env(zap_len, 0.001, zap_len * 0.9, sr=sr)
        zap = zap * (rng.random(n_of(zap_len, sr)) < 0.3) * 1.5
        out = place(out, zap * 0.5, at, sr=sr)
    return out


# ---- The sliding doors (3D at the door) --------------------------------------------------------

@sound("door_open", GROUP, "Door opens",
       "One of the hallway's sliding doors opening as someone comes near: a short air hiss as it slides.",
       [("A", "Air hiss and slide"), ("B", "Quick pneumatic whoosh"), ("C", "Soft hiss with a low tone")],
       level=-6, where="3D at the door")
def door_open(v):
    seed(61 + v)
    if v == 0:
        hiss = hp(noise(0.45), 2800) * env(0.45, 0.01, 0.4) * 0.5
        slide = lp(noise(0.4), 500) * np.sin(np.linspace(0, np.pi, n_of(0.4))) * 0.5
        return reverb(mix(hiss, slide), 0.8, 0.2)
    if v == 1:
        u = np.linspace(0, 1, n_of(0.32))
        whoosh = svf(noise(0.32, "pink"), 600 + 4000 * u, 1.0, "bp") * np.sin(np.pi * u) ** 1.5 * 1.6
        return reverb(mix(whoosh, thump(120, 70, 0.08, 0.25)), 0.7, 0.2)
    hiss = hp(noise(0.5), 3500) * env(0.5, 0.02, 0.45) * 0.35
    tone = osc(glide(330, 440, 0.3), 0.3) * env(0.3, 0.01, 0.28) * 0.08
    return reverb(mix(hiss, tone), 1.0, 0.25)


@sound("door_close", GROUP, "Door closes",
       "A sliding door shutting after everyone has gone: a soft thunk as the halves meet.",
       [("A", "Soft thunk"), ("B", "Short hiss, then a thunk")], level=-7, where="3D at the door")
def door_close(v):
    seed(71 + v)
    knock = mix(thump(140, 60, 0.14, 0.8), lp(noise(0.05), 1500) * env(0.05, 0.001, 0.045) * 0.4)
    if v == 0:
        return reverb(knock, 0.7, 0.2)
    hiss = hp(noise(0.3), 2500) * env(0.3, 0.01, 0.28) * 0.35
    return reverb(place(hiss, knock, 0.28), 0.8, 0.2)
