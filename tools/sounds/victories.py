"""Each victory's sounds, cued on its beats (the times come from client/Victories)."""

from __future__ import annotations

import numpy as np

from core import click, sparkle, thump, whoosh
from registry import SOUNDS, VICTORIES, Sound, Victory
from synth import (
    adsr, bell, bp, drive, env, fm, glide, hp, lp, mix, n_of, noise, note, osc, place, reverb, seed,
    silence, svf, times,
)


def vsound(id: str, name: str, desc: str, level: float = -1.0):
    def deco(fn):
        SOUNDS.append(Sound(id, "Victories", name, desc, [("A", "")], lambda v, fn=fn: fn(), level=level))
        return fn
    return deco


def victory(id, name, rarity, length, cues, skip=False):
    """skip: kept out of the game for now (not rendered or shown on the board)."""
    VICTORIES.append(Victory(id, name, rarity, length, cues, skip))


# ---- Building blocks -------------------------------------------------------------------

def explosion(seconds=2.0, size=1.0, seed_n=1):
    seed(seed_n)
    crack = hp(noise(0.04), 300) * env(0.04, 0.0005, 0.035) * 2.5
    body = svf(mix(noise(seconds, "pink"), noise(seconds, "brown") * 0.8), glide(4000, 150, seconds), 0.7)
    body = body * env(seconds, 0.003, seconds * 0.85) * 2.0
    sub = osc(glide(70, 28, seconds * 0.6, "fast"), seconds * 0.6) * env(seconds * 0.6, 0.002, seconds * 0.55) * 1.2 * size
    return reverb(drive(mix(crack, body, sub), 1.8), 2.2, 0.3)


def debris(seconds=1.0, count=14, lo=200, hi=900, gain=0.4, seed_n=2, start=0.0):
    out = silence(seconds + 0.2)
    rng = np.random.default_rng(seed_n)
    for _ in range(count):
        at = start + rng.uniform(0, 1) ** 1.6 * seconds
        f = rng.uniform(lo, hi)
        hit = mix(osc(glide(f, f * 0.6, 0.05), 0.05) * env(0.05, 0.001, 0.045) * 0.6,
                  bp(noise(0.03), f * 2, f * 8) * env(0.03, 0.0005, 0.025) * 1.5)
        out = place(out, hit * gain * rng.uniform(0.3, 1) * (1 - 0.6 * (at - start) / seconds), at)
    return out


def crackle(seconds, rate=40, lo=1500, hi=7000, gain=0.3, seed_n=3):
    rng = np.random.default_rng(seed_n)
    out = silence(seconds)
    for _ in range(int(seconds * rate)):
        at = rng.uniform(0, seconds - 0.02)
        pop = bp(noise(0.006), lo, hi) * env(0.006, 0.0003, 0.005) * rng.uniform(0.2, 1) * 3
        out = place(out, pop, at)
    return out[: n_of(seconds)] * gain


def rumble(seconds, gain=1.0, attack=0.2, release=0.4, seed_n=4):
    seed(seed_n)
    r = lp(noise(seconds, "brown"), 120) * adsr(seconds, attack, 0.1, 0.9, release) * 1.4
    rattle = bp(noise(seconds), 600, 2500) * (np.random.default_rng(seed_n).random(n_of(seconds)) < 0.01) * 4
    return mix(r, rattle * adsr(seconds, attack, 0.1, 0.9, release) * 0.3) * gain


def thunder(seconds=3.0, big=False, seed_n=5):
    seed(seed_n)
    crack = mix(noise(0.03) * env(0.03, 0.0005, 0.025) * 3, crackle(0.25, 120, 2000, 9000, 0.6, seed_n))
    t = times(seconds)
    rng = np.random.default_rng(seed_n)
    wobble = np.interp(t, np.linspace(0, seconds, 14), rng.uniform(0.3, 1, 14))
    roll = lp(noise(seconds, "brown"), 260 if big else 180) * np.exp(-t * (1.2 if big else 1.6)) * wobble * 1.6
    out = mix(crack * (1.4 if big else 0.9), roll)
    if big:
        out = mix(out, osc(glide(60, 25, 1.2, "fast"), 1.2) * env(1.2, 0.002, 1.1) * 1.0, explosion(1.2, 0.6, seed_n)[: n_of(1.2)] * 0.5)
    return reverb(drive(out, 1.5), 2.5, 0.3)


def fire(seconds, seed_n=6):
    seed(seed_n)
    roar = lp(noise(seconds, "brown"), 450) * (0.6 + 0.4 * np.interp(times(seconds), np.linspace(0, seconds, 10), np.random.default_rng(seed_n).uniform(0, 1, 10)))
    return mix(roar * 0.7, crackle(seconds, 25, 1000, 6000, 0.5, seed_n)) * adsr(seconds, 0.3, 0.1, 0.9, 0.8)


def rain(seconds, heavy=1.0, seed_n=7):
    seed(seed_n)
    hiss = hp(lp(noise(seconds, "pink"), 9000), 500)
    patter = bp(noise(seconds), 2500, 7000) * (np.random.default_rng(seed_n).random(n_of(seconds)) < 0.006 * heavy) * 6
    splash = crackle(seconds, 30 * heavy, 800, 4000, 0.25, seed_n)
    return mix(hiss * 0.7 * heavy, patter * 0.5, splash) * adsr(seconds, 0.6, 0.1, 0.9, 1.0)


def electric(seconds, seed_n=8):
    seed(seed_n)
    rng = np.random.default_rng(seed_n)
    buzz = lp(osc(100 + 20 * np.sin(2 * np.pi * 3 * times(seconds)), seconds, "saw"), 3000)
    gate = np.interp(times(seconds), np.linspace(0, seconds, int(seconds * 25)), (rng.random(int(seconds * 25)) < 0.45) * 1.0)
    zaps = silence(seconds)
    for _ in range(int(seconds * 6)):
        at = rng.uniform(0, seconds - 0.1)
        z = hp(noise(0.06), 2500) * env(0.06, 0.001, 0.05) * rng.uniform(0.4, 1)
        zaps = place(zaps, z, at)
    return (buzz * gate * 0.25 + zaps[: n_of(seconds)] * 0.8) * adsr(seconds, 0.05, 0.1, 0.8, 0.6)


def pad(names, seconds, attack=0.6, release=1.0, bright=2500, gain=0.12):
    tone = sum(osc(note(n) * d, seconds, "saw") for n in names for d in (0.996, 1.004))
    tone = lp(tone, bright) + sum(osc(note(n), seconds) for n in names) * 0.5
    return tone * adsr(seconds, attack, 0.3, 0.8, release) * gain


def glass(seconds=0.5, count=24, gain=0.25, seed_n=9):
    out = silence(seconds + 0.5)
    rng = np.random.default_rng(seed_n)
    for _ in range(count):
        f = rng.uniform(3000, 9000)
        ting = fm(f, 2.76, 2 * np.exp(-times(0.25) * 20), 0.25) * env(0.25, 0.0005, rng.uniform(0.1, 0.25))
        out = place(out, ting * gain * rng.uniform(0.3, 1), rng.uniform(0, 1) ** 1.5 * seconds)
    return out


def flutter(seconds, density=1.0, seed_n=10, gain=0.5):
    rng = np.random.default_rng(seed_n)
    out = silence(seconds)
    for _ in range(int(seconds * 14 * density)):
        length = rng.uniform(0.12, 0.3)
        rate = rng.uniform(16, 26)
        t = times(length)
        beat = (0.5 + 0.5 * np.sin(2 * np.pi * rate * t)) ** 3
        w = bp(noise(length), rng.uniform(600, 1200), rng.uniform(2500, 4500)) * beat * np.sin(np.pi * t / length)
        out = place(out, w * rng.uniform(0.3, 1), rng.uniform(0, max(0.01, seconds - length)))
    return out[: n_of(seconds)] * gain


def flap(seconds=0.7, lo=150, peak=900, gain=1.0):
    return whoosh(seconds, lo, peak, lo * 1.5, 0.8, shape=lambda u: (1 - np.exp(-u * 12)) * np.exp(-u * 3.5)) * gain


def metal_ring(freq, seconds=1.2, gain=0.4):
    return fm(freq, 2.71, 1.5 * np.exp(-times(seconds) * 4), seconds) * env(seconds, 0.001, seconds) * gain


# ---- Epic: Flex ------------------------------------------------------------------------

@vsound("v_flex_pose", "Flex: pose", "Snapping into the double bicep.")
def v_flex_pose():
    return mix(whoosh(0.18, 500, 2500, 900, 1.2), thump(180, 70, 0.12, 0.7))


@vsound("v_flex_burst", "Flex: sparkle burst", "The gradient sparkles bursting out.")
def v_flex_burst():
    pop = mix(osc(glide(300, 1100, 0.05), 0.05) * env(0.05, 0.001, 0.045) * 0.6, click(0.003, 2000, 8000, 0.5))
    return reverb(mix(pop, sparkle(0.6, 18, 3500, 9000, 0.14, 0.02, 61)), 0.8, 0.2)


victory("victory_flex", "Flex", "Epic", 3.5, [("v_flex_pose", 0.0, 0.8), ("v_flex_burst", 0.3, 0.9), ("v_flex_burst", 0.65, 0.6)])


# ---- Epic: Backflip --------------------------------------------------------------------

@vsound("v_bf_spring", "Backflip: spring", "Springing up into the backflip.")
def v_bf_spring():
    return mix(thump(140, 60, 0.1, 0.6), whoosh(0.3, 400, 2400, 1200, 1.2))


@vsound("v_bf_spin", "Backflip: spin", "The tucked spin through the air.")
def v_bf_spin():
    t = times(0.6)
    w = whoosh(0.6, 300, 1800, 500, 1.4) * (0.6 + 0.4 * np.sin(2 * np.pi * 3.3 * t) ** 2)
    return w


@vsound("v_bf_land", "Backflip: hero landing", "The superhero landing: a slam, cracks and dust.")
def v_bf_land():
    slam = drive(mix(thump(110, 32, 0.4, 1.2), lp(noise(0.12), 1500) * env(0.12, 0.001, 0.1) * 1.5), 1.6)
    out = mix(slam, crackle(0.3, 80, 2000, 8000, 0.4, 71), whoosh(0.6, 200, 900, 300, 0.9) * 0.5)
    return reverb(out, 1.2, 0.2)


@vsound("v_bf_glow", "Backflip: glowing cracks", "The cracks glowing on the block for a moment.", level=-6)
def v_bf_glow():
    t = times(1.0)
    return mix(crackle(1.0, 30, 3000, 9000, 0.25, 72), osc(note("E6"), 1.0) * env(1.0, 0.05, 0.9) * 0.1 * (1 + 0.3 * np.sin(2 * np.pi * 8 * t)))


victory("victory_backflip", "Backflip", "Epic", 5.0,
        [("v_bf_spring", 0.25, 0.8), ("v_bf_spin", 0.4, 0.7), ("v_bf_land", 1.0, 1.0), ("v_bf_glow", 1.05, 0.5)])


# ---- Epic: Confetti Storm --------------------------------------------------------------

@vsound("v_cf_cannon", "Confetti: cannon", "A confetti cannon popping from a hand.")
def v_cf_cannon():
    seed(81)
    pop = drive(mix(thump(200, 60, 0.12, 0.9), hp(noise(0.05), 800) * env(0.05, 0.0005, 0.04) * 2), 1.6)
    paper = bp(noise(0.5), 2000, 7000) * env(0.5, 0.005, 0.45) * 0.4
    return reverb(mix(pop, paper), 0.7, 0.15)


@vsound("v_cf_rain", "Confetti: falling", "Confetti raining down for the rest of the victory.", level=-6)
def v_cf_rain():
    """Lots of paper drifting down: a continuous, fine flutter that never pumps.

    Twelve layers of soft band-passed noise, each fluttering at its own slowly wandering rate
    (a piece of paper flapping as it falls), so together they shimmer evenly; under them a dense
    sprinkle of tiny, quiet paper ticks (pieces brushing each other and landing)."""
    seed(82)
    seconds = 5.5
    sr_t = times(seconds)
    rng = np.random.default_rng(82)
    out = np.zeros(len(sr_t))
    for k in range(12):
        lo = rng.uniform(1400, 2600)
        layer = bp(noise(seconds), lo, lo * rng.uniform(2.0, 2.8))
        drift = np.interp(sr_t, np.linspace(0, seconds, 8), rng.uniform(7, 15, 8))
        phase = 2 * np.pi * np.cumsum(drift) / len(sr_t) * seconds
        flap = (0.55 + 0.45 * np.sin(phase + rng.uniform(0, 6.28))) ** 2
        swell = np.interp(sr_t, np.linspace(0, seconds, 6), rng.uniform(0.6, 1.0, 6))
        out += layer * flap * swell
    out /= 12 ** 0.5
    ticks = np.zeros(len(sr_t))
    hits = rng.random(len(sr_t)) < 220 / 44100
    ticks[hits] = rng.uniform(-1, 1, int(hits.sum())) * rng.uniform(0.2, 1, int(hits.sum()))
    ticks = lp(bp(ticks, 2500, 7000), 6000) * 0.5
    paper = lp(mix(out, ticks), 6500)
    return paper * adsr(seconds, 0.9, 0.2, 0.85, 1.6) * 0.9


victory("victory_confetti", "Confetti Storm", "Epic", 6.0,
        [("v_cf_cannon", 0.12, 0.9), ("v_cf_cannon", 0.2, 0.8), ("v_cf_rain", 0.5, 0.6)])


# ---- Epic: Breakdance ------------------------------------------------------------------

@vsound("v_bd_drop", "Breakdance: drop", "Dropping to the floor, legs kicking out.")
def v_bd_drop():
    return mix(thump(130, 50, 0.2, 0.9), lp(noise(0.08), 1200) * env(0.08, 0.001, 0.07), whoosh(0.25, 400, 1600, 600, 1.1) * 0.6)


@vsound("v_bd_spin", "Breakdance: windmill turn", "One turn of the windmill (plays on each turn, getting faster).")
def v_bd_spin():
    return whoosh(0.3, 300, 1500, 500, 1.3)


@vsound("v_bd_scratch", "Breakdance: scratch", "A record scratch just before the freeze.")
def v_bd_scratch():
    seconds = 0.32
    t = times(seconds)
    speed = np.sin(2 * np.pi * 4.5 * t) * 1.0
    f = 300 + 900 * np.abs(speed)
    tone = svf(noise(seconds), f * 2, 2.5, "bp") * np.abs(speed) * 2
    return mix(tone, osc(f * 0.5, seconds, "saw") * np.abs(speed) * 0.15)


@vsound("v_bd_freeze", "Breakdance: freeze", "Snapping into the freeze: a bass hit with a ring.")
def v_bd_freeze():
    hit = drive(mix(osc(glide(110, 34, 0.7, "fast"), 0.7) * env(0.7, 0.002, 0.65) * 1.2, click(0.004, 1500, 7000, 0.8)), 1.8)
    return reverb(mix(hit, metal_ring(note("A5"), 1.0, 0.12)), 1.0, 0.18)


victory("victory_breakdance", "Breakdance", "Epic", 5.5, skip=True, cues=
        [("v_bd_drop", 0.0, 0.9)] + [("v_bd_spin", 0.45 + i * 0.18, 0.35 + 0.04 * i) for i in range(0, 12, 2)]
        + [("v_bd_scratch", 2.36, 0.6), ("v_bd_freeze", 2.66, 1.0)])


# ---- Epic: Katana (Fruit Ninja) --------------------------------------------------------

@vsound("v_kt_appear", "Katana: appears", "The sheathed katana fading in at the hip.", level=-6)
def v_kt_appear():
    return reverb(mix(sparkle(0.4, 8, 4000, 8000, 0.1, 0, 91), osc(note("E7"), 0.5) * env(0.5, 0.05, 0.4) * 0.08), 0.8, 0.2)


@vsound("v_kt_draw", "Katana: draw", "Drawing the blade: a metal shing that rings.")
def v_kt_draw():
    seed(92)
    scrape = svf(noise(0.3), glide(1500, 9000, 0.3), 2.0, "bp") * ramp_up(0.3) * 0.8
    ring = mix(metal_ring(3150, 1.3, 0.25), metal_ring(4720, 1.0, 0.15))
    return reverb(place(scrape, ring, 0.25), 1.0, 0.2)


def ramp_up(seconds):
    u = np.linspace(0, 1, n_of(seconds))
    return u ** 2


@vsound("v_kt_spin", "Katana: spin", "The blade spinning in the hand.")
def v_kt_spin():
    return whoosh(0.22, 1200, 5500, 2000, 1.3, "white")


def slice_swish():
    return whoosh(0.18, 2500, 9000, 4000, 1.0, "white", "hp")


@vsound("v_kt_apple", "Katana: apple", "Slicing the apple: a swish and a crisp crunch.")
def v_kt_apple():
    seed(93)
    crunch = bp(noise(0.08), 1500, 6000) * env(0.08, 0.001, 0.07) * 1.6 * (np.random.default_rng(1).random(n_of(0.08)) < 0.5)
    return reverb(place(slice_swish(), mix(crunch, thump(300, 150, 0.05, 0.3)), 0.06), 0.5, 0.12)


@vsound("v_kt_banana", "Katana: banana", "Slicing the banana: a swish and a soft squish.")
def v_kt_banana():
    seed(94)
    squish = lp(noise(0.12), 1500) * env(0.12, 0.004, 0.1) * 1.2
    return reverb(place(slice_swish(), mix(squish, osc(glide(400, 200, 0.08), 0.08) * env(0.08, 0.002, 0.07) * 0.3), 0.06), 0.5, 0.12)


@vsound("v_kt_melon", "Katana: watermelon", "The two-handed chop through the watermelon: a big wet splat.")
def v_kt_melon():
    seed(95)
    chop = whoosh(0.22, 800, 5000, 1500, 1.0)
    thunk = mix(thump(180, 70, 0.12, 1.0), bp(noise(0.06), 400, 2500) * env(0.06, 0.001, 0.05) * 1.5)
    splat = lp(noise(0.3), 2500) * env(0.3, 0.003, 0.25) * 1.0
    drops = crackle(0.5, 40, 600, 2500, 0.35, 96)
    return reverb(place(chop, mix(thunk, splat, drops), 0.12), 0.7, 0.15)


@vsound("v_kt_fuse", "Katana: bomb fuse", "The bomb's lit fuse hissing as it flies up.", level=-6)
def v_kt_fuse():
    seed(97)
    seconds = 0.9
    return mix(hp(noise(seconds), 3000) * (0.6 + 0.4 * np.random.default_rng(3).random(n_of(seconds))) * 0.4,
               crackle(seconds, 40, 3000, 9000, 0.3, 98)) * adsr(seconds, 0.1, 0.05, 0.9, 0.05)


@vsound("v_kt_clink", "Katana: cutting the bomb", "The big cut going through the bomb: a metal clink.")
def v_kt_clink():
    return reverb(mix(slice_swish(), metal_ring(1800, 0.5, 0.35), click(0.003, 3000, 9000, 0.8)), 0.6, 0.15)


@vsound("v_kt_boom", "Katana: bomb explodes", "The bomb blowing up in front of the podium.")
def v_kt_boom():
    return mix(explosion(2.4, 1.2, 99), debris(1.2, 16, 200, 800, 0.35, 100, 0.1))


@vsound("v_kt_topple", "Katana: block topples", "2nd or 3rd's block going over onto its side.")
def v_kt_topple():
    return reverb(drive(mix(thump(90, 35, 0.4, 1.1), lp(noise(0.2), 900) * env(0.2, 0.002, 0.18) * 1.2), 1.5), 1.0, 0.2)


@vsound("v_kt_flop", "Katana: player hits the floor", "A ragdolled player flopping onto the floor.")
def v_kt_flop():
    return mix(thump(160, 60, 0.15, 0.8), lp(noise(0.08), 1100) * env(0.08, 0.001, 0.07) * 0.8)


@vsound("v_kt_sheathe", "Katana: sheathe", "The blade sliding home with a click.")
def v_kt_sheathe():
    seed(101)
    slide = svf(noise(0.35), glide(7000, 2500, 0.35), 2.0, "bp") * np.sin(np.linspace(0, np.pi / 2, n_of(0.35))) * 0.5
    clack = mix(click(0.004, 2000, 8000, 1.2), thump(400, 200, 0.04, 0.5), metal_ring(2400, 0.6, 0.12))
    return reverb(place(slide, clack, 0.33), 0.9, 0.18)


@vsound("v_kt_petals", "Katana: petals", "The hanging cut scattering into petals.", level=-5)
def v_kt_petals():
    return reverb(mix(whoosh(1.0, 800, 3000, 1500, 0.8) * 0.4, sparkle(1.0, 16, 3000, 7000, 0.1, 0, 102)), 1.4, 0.3)


victory("victory_katana", "Katana (Fruit Ninja)", "Epic", 6.2, [
    ("v_kt_appear", 0.0, 0.5), ("v_kt_draw", 0.3, 1.0), ("v_kt_spin", 0.85, 0.6), ("v_kt_spin", 1.1, 0.6),
    ("v_kt_apple", 1.48, 0.9), ("v_kt_banana", 1.9, 0.9), ("v_kt_fuse", 2.1, 0.6), ("v_kt_melon", 2.4, 1.0),
    ("v_kt_clink", 2.95, 0.9), ("v_kt_boom", 3.4, 1.0), ("v_kt_topple", 3.45, 0.8), ("v_kt_topple", 3.52, 0.7),
    ("v_kt_flop", 3.85, 0.7), ("v_kt_flop", 3.97, 0.6), ("v_kt_sheathe", 4.0, 0.9), ("v_kt_petals", 4.35, 0.7),
])


# ---- Exclusive: Trophy Lift ------------------------------------------------------------

@vsound("v_tr_pocket", "Trophy: out of the pocket", "Pulling the trophy out of the pocket as it grows.")
def v_tr_pocket():
    seed(111)
    rustle = bp(noise(0.35), 1500, 5000) * env(0.35, 0.02, 0.3) * 0.5
    grow = osc(glide(note("C6"), note("C7"), 0.4), 0.4) * env(0.4, 0.05, 0.35) * 0.12
    return reverb(mix(rustle, grow, sparkle(0.4, 8, 4000, 8000, 0.1, 0.1, 112)), 0.8, 0.2)


@vsound("v_tr_lift", "Trophy: lifted high", "Lifting it overhead: a glint, a sparkle burst and a gold chord.")
def v_tr_lift():
    up = whoosh(0.3, 400, 2000, 900, 1.2) * 0.6
    glint = bell(note("E7"), 0.6, 2.0, 3.0) * 0.3
    chord = sum(bell(note(n), 1.6, 1.0, 2.0) for n in ("C5", "E5", "G5", "C6")) * 0.16
    out = place(up, mix(glint, chord, sparkle(1.0, 22, 3500, 9000, 0.12, 0, 113)), 0.2)
    return reverb(out, 1.4, 0.25)


@vsound("v_tr_pump", "Trophy: pump", "Pumping the trophy up.", level=-4)
def v_tr_pump():
    return whoosh(0.2, 500, 1800, 700, 1.2)


victory("victory_trophy", "Trophy Lift", "Exclusive", 5.5,
        [("v_tr_pocket", 0.4, 0.8), ("v_tr_lift", 1.5, 1.0), ("v_tr_pump", 2.4, 0.5), ("v_tr_pump", 2.8, 0.5)])


# ---- Legendary: Podium Rise ------------------------------------------------------------

@vsound("v_pr_rumble", "Podium Rise: rumble", "The ground rumbling before the block bursts up.")
def v_pr_rumble():
    return rumble(1.2, 1.0, 0.3, 0.4, 121)


@vsound("v_pr_crack", "Podium Rise: cracks", "Glowing cracks spreading round the base.")
def v_pr_crack():
    return reverb(mix(crackle(0.4, 90, 800, 5000, 0.6, 122), thump(90, 50, 0.3, 0.4)), 0.8, 0.15)


@vsound("v_pr_erupt", "Podium Rise: eruption", "The block bursting up out of the ground.")
def v_pr_erupt():
    return mix(explosion(1.8, 1.0, 123), debris(1.5, 24, 150, 700, 0.45, 124, 0.15))


@vsound("v_pr_spot", "Podium Rise: spotlight", "The gold spotlight slamming on: a heavy clunk and a glowing hum.")
def v_pr_spot():
    clunk = drive(mix(thump(120, 60, 0.15, 1.0), click(0.005, 800, 4000, 1.2), metal_ring(600, 0.6, 0.15)), 1.5)
    hum = pad(("C4", "G4", "C5", "E5", "G5"), 3.5, 0.3, 1.5, 3000, 0.08)
    return reverb(mix(clunk, hum, sparkle(3.0, 20, 4000, 9000, 0.06, 0.2, 125)), 2.0, 0.3)


victory("victory_podium", "Podium Rise", "Legendary", 8.3,
        [("v_pr_rumble", 0.0, 0.9), ("v_pr_crack", 0.5, 0.8), ("v_pr_erupt", 0.8, 1.0), ("v_pr_spot", 2.0, 1.0)])


# ---- Legendary: Thunderstorm -----------------------------------------------------------

@vsound("v_ts_rain", "Thunderstorm: rain", "Heavy rain from when the sky darkens to the end.", level=-5)
def v_ts_rain():
    return rain(7.7, 1.2, 131)


@vsound("v_ts_bolt", "Thunderstorm: warning bolt", "A warning bolt hitting the ground near the podium.")
def v_ts_bolt():
    return thunder(2.0, False, 132)


@vsound("v_ts_big", "Thunderstorm: the big bolt", "The big bolt hitting the winner.")
def v_ts_big():
    return thunder(3.5, True, 133)


@vsound("v_ts_arcs", "Thunderstorm: arcs", "Electric arcs crackling round the winner as they hover.", level=-5)
def v_ts_arcs():
    return electric(6.0, 134)


victory("victory_thunder", "Thunderstorm", "Legendary", 8.0,
        [("v_ts_rain", 0.25, 0.6), ("v_ts_bolt", 0.6, 0.7), ("v_ts_bolt", 1.0, 0.8), ("v_ts_big", 1.4, 1.0),
         ("v_ts_arcs", 1.5, 0.5), ("v_ts_bolt", 3.0, 0.45)])


# ---- Legendary: Throne -----------------------------------------------------------------

@vsound("v_th_fall", "Throne: falling", "The throne falling from above (its shadow growing).")
def v_th_fall():
    seconds = 0.6
    tone = osc(glide(1800, 500, seconds), seconds) * np.linspace(0.2, 1, n_of(seconds)) * 0.3
    return mix(tone, whoosh(seconds, 300, 1500, 1200, 1.0, shape=lambda u: u ** 2) * 0.5)


@vsound("v_th_crash", "Throne: crash", "The throne crashing down behind the winner.")
def v_th_crash():
    hit = drive(mix(thump(100, 30, 0.6, 1.3), lp(noise(0.25), 1500) * env(0.25, 0.001, 0.2) * 1.5), 1.7)
    return reverb(mix(hit, debris(1.0, 18, 250, 900, 0.4, 141, 0.05), metal_ring(420, 1.2, 0.12)), 1.6, 0.25)


@vsound("v_th_sit", "Throne: falls into it", "The trust fall into the velvet: a soft cushioned thump.")
def v_th_sit():
    return mix(lp(thump(120, 60, 0.2, 0.8), 800), lp(noise(0.15), 700) * env(0.15, 0.005, 0.12) * 0.6)


@vsound("v_th_crown", "Throne: crown", "The crown sparkling into being over the head.")
def v_th_crown():
    out = silence(2.0)
    for i, n in enumerate(("G6", "B6", "D7", "G7", "B7")):
        out = place(out, bell(note(n), 1.2, 1.4, 2.0) * 0.2, i * 0.06)
    return reverb(mix(out, sparkle(1.2, 20, 4000, 9000, 0.1, 0, 142), pad(("G4", "D5", "G5", "B5"), 2.2, 0.4, 1.2, 2500, 0.06)), 1.6, 0.3)


victory("victory_throne", "Throne", "Legendary", 8.0,
        [("v_th_fall", 0.0, 0.8), ("v_th_crash", 0.6, 1.0), ("v_th_sit", 1.45, 0.8), ("v_th_crown", 2.0, 0.9)])


# ---- Legendary: Meteor Touchdown -------------------------------------------------------

@vsound("v_mt_charge", "Meteor: charge", "Crouching to charge, embers rising.")
def v_mt_charge():
    seconds = 0.5
    return mix(rumble(seconds, 0.8, 0.4, 0.05, 151), crackle(seconds, 40, 2000, 7000, 0.3, 152),
               osc(glide(80, 160, seconds), seconds) * ramp_up(seconds) * 0.3)


@vsound("v_mt_launch", "Meteor: launch", "Blasting straight up out of frame on a fire trail.")
def v_mt_launch():
    seed(153)
    blast = mix(thump(140, 45, 0.3, 1.0), hp(noise(0.06), 400) * env(0.06, 0.001, 0.05) * 1.5)
    roar = svf(noise(0.9, "pink"), glide(500, 3000, 0.9), 0.8) * env(0.9, 0.01, 0.8) * 1.6
    return reverb(drive(mix(blast, roar), 1.5), 1.2, 0.2)


@vsound("v_mt_fall", "Meteor: coming down", "Diving back down as a meteor: a roar that grows.")
def v_mt_fall():
    seed(154)
    seconds = 0.55
    u = np.linspace(0, 1, n_of(seconds))
    roar = svf(noise(seconds, "pink"), glide(3000, 900, seconds), 0.8) * u ** 2 * 2.0
    whistle = osc(glide(1600, 700, seconds), seconds) * u ** 2 * 0.15
    return mix(roar, whistle, fire(seconds, 155) * 0.6)


@vsound("v_mt_slam", "Meteor: touchdown", "Slamming into the block: a huge fiery impact.")
def v_mt_slam():
    return mix(explosion(3.0, 1.5, 156), debris(1.6, 26, 150, 800, 0.45, 157, 0.1))


@vsound("v_mt_fire", "Meteor: crater fire", "The crater burning and smoking to the end.", level=-6)
def v_mt_fire():
    return fire(6.0, 158)


victory("victory_meteor", "Meteor Touchdown", "Legendary", 8.0,
        [("v_mt_charge", 0.0, 0.7), ("v_mt_launch", 0.4, 0.9), ("v_mt_fall", 1.25, 0.9), ("v_mt_slam", 1.8, 1.0),
         ("v_mt_fire", 2.0, 0.5)])


# ---- Iridescent: Rift ------------------------------------------------------------------

@vsound("v_rf_gather", "Rift: energy gathers", "Holo energy gathering in the raised hand.")
def v_rf_gather():
    seconds = 0.6
    tone = sum(osc(glide(f, f * 2, seconds), seconds) for f in (220, 330, 441)) * ramp_up(seconds) * 0.15
    return reverb(mix(tone, sparkle(0.6, 8, 3000, 8000, 0.08, 0, 161)), 0.8, 0.2)


@vsound("v_rf_tear", "Rift: the tear", "Slashing the air open: a glassy rip in space.")
def v_rf_tear():
    seed(162)
    rip = svf(noise(0.5), glide(800, 7000, 0.5, "fast"), 3.0, "bp") * env(0.5, 0.002, 0.45) * 1.5
    shimmer = sum(fm(f, 1.5, 1.0, 1.2) * env(1.2, 0.01, 1.1) for f in (880, 1320, 1980)) * 0.08
    return reverb(mix(rip, shimmer, glass(0.4, 12, 0.15, 163)), 1.4, 0.3)


@vsound("v_rf_pull", "Rift: pulled in", "Getting sucked into the rift, into space.")
def v_rf_pull():
    seconds = 0.6
    suck = whoosh(seconds, 200, 4000, 6000, 0.9, shape=lambda u: u ** 3)
    flash = mix(thump(90, 40, 0.5, 0.8), hp(noise(0.08), 2000) * env(0.08, 0.001, 0.07) * 0.6)
    return reverb(place(suck * 1.2, flash, seconds - 0.02), 2.0, 0.3)


@vsound("v_rf_space", "Rift: deep space", "Floating in deep space: a low drone with distant shimmer.", level=-6)
def v_rf_space():
    seconds = 7.3
    drone = pad(("A1", "E2", "A2", "B2"), seconds, 1.0, 2.0, 900, 0.18)
    high = pad(("E5", "B5", "F#6"), seconds, 2.0, 2.0, 5000, 0.04) * (1 + 0.3 * np.sin(2 * np.pi * 0.3 * times(seconds)))
    return reverb(mix(drone, high, sparkle(seconds, 30, 5000, 10000, 0.04, 0, 164)), 3.0, 0.4)


@vsound("v_rf_star", "Rift: shooting star", "The pink shooting star streaking across from right to left.")
def v_rf_star():
    seed(165)
    seconds = 1.45
    u = np.linspace(0, 1, n_of(seconds))
    w = svf(noise(seconds, "pink"), 1500 + 4000 * u, 1.5, "bp") * (u ** 1.5) * 1.8
    tone = osc(glide(1200, 2400, seconds), seconds) * u ** 2 * 0.12
    return mix(w, tone, sparkle(seconds, 24, 5000, 10000, 0.08, 0, 166))


@vsound("v_rf_nova", "Rift: supernova", "The star bursting into a supernova behind the winner.")
def v_rf_nova():
    boom = explosion(3.5, 1.4, 167)
    bloom = pad(("A3", "E4", "A4", "C#5", "E5"), 3.5, 0.15, 2.5, 4000, 0.14)
    return reverb(mix(boom, bloom, sparkle(2.5, 40, 3000, 9000, 0.08, 0.1, 168)), 2.5, 0.35)


@vsound("v_rf_push", "Rift: shockwave", "The shockwave pushing the winner toward the camera.")
def v_rf_push():
    return whoosh(0.8, 200, 1800, 300, 0.8, shape=lambda u: (1 - np.exp(-u * 20)) * np.exp(-u * 4)) * 1.2


victory("victory_rift", "Rift", "Iridescent", 9.5,
        [("v_rf_gather", 0.0, 0.7), ("v_rf_tear", 0.55, 0.9), ("v_rf_pull", 1.4, 0.9), ("v_rf_space", 2.2, 0.6),
         ("v_rf_star", 2.4, 0.8), ("v_rf_nova", 3.8, 1.0), ("v_rf_push", 3.9, 0.7)])


# ---- Iridescent: Chrysalis -------------------------------------------------------------

@vsound("v_ch_dark", "Chrysalis: neon goes out", "The stage's neon flickering out.")
def v_ch_dark():
    seconds = 0.5
    t = times(seconds)
    buzz = lp(osc(120, seconds, "saw"), 2500) * (np.sin(2 * np.pi * 30 * t) > -0.2) * np.exp(-t * 5) * 0.3
    return mix(buzz, click(0.005, 600, 3000, 0.8), thump(90, 50, 0.1, 0.4))


@vsound("v_ch_grow", "Chrysalis: overgrowth", "Nature growing over the stage: rustling, a soft rising pad, chimes.", level=-4)
def v_ch_grow():
    seed(171)
    seconds = 4.0
    rustle = bp(noise(seconds), 1500, 6000) * np.interp(times(seconds), np.linspace(0, seconds, 30), np.random.default_rng(1).uniform(0, 1, 30)) * 0.25
    lift = pad(("D4", "A4", "E5", "F#5"), seconds, 1.5, 1.5, 2500, 0.08)
    out = mix(rustle * adsr(seconds, 0.5, 0.1, 0.9, 1.0), lift)
    rng = np.random.default_rng(172)
    pent = ("D6", "E6", "F#6", "A6", "B6", "D7")
    for _ in range(10):
        out = place(out, bell(note(pent[rng.integers(0, 6)]), 1.2, 0.6, 3.01) * 0.08, rng.uniform(0.2, seconds - 0.5))
    return reverb(out, 2.0, 0.3)


@vsound("v_ch_silk", "Chrysalis: silk rises", "Shimmering silk spiralling up round the winner.")
def v_ch_silk():
    out = silence(1.6)
    scale = ("D5", "E5", "F#5", "A5", "B5", "D6", "E6", "F#6", "A6", "B6", "D7")
    for i, n in enumerate(scale):
        out = place(out, bell(note(n), 0.6, 0.8, 1.0) * 0.18, i * 0.06)
    return reverb(out, 1.6, 0.35)


@vsound("v_ch_wrap", "Chrysalis: wrapping", "The silk winding round into the cocoon.")
def v_ch_wrap():
    out = silence(1.1)
    for i in range(5):
        out = place(out, whoosh(0.25, 1500, 5000, 2500, 1.4, "white") * 0.4, i * 0.18)
    return reverb(out, 1.2, 0.25)


@vsound("v_ch_heart", "Chrysalis: heartbeat", "The cocoon beating like a heart (three times, each stronger).")
def v_ch_heart():
    lub = lp(thump(70, 40, 0.18, 1.0), 300)
    dub = lp(thump(60, 35, 0.16, 0.7), 300)
    beat = place(lub, dub, 0.17)
    glow = pad(("D5", "A5"), 0.7, 0.05, 0.5, 3000, 0.05)
    return reverb(mix(beat, glow), 1.0, 0.2)


@vsound("v_ch_crack", "Chrysalis: cracks", "Cracks spreading over the shell before the hush.")
def v_ch_crack():
    return reverb(mix(crackle(0.35, 100, 2500, 9000, 0.5, 173), glass(0.35, 10, 0.1, 174)), 0.8, 0.2)


@vsound("v_ch_burst", "Chrysalis: burst", "The shell bursting into butterflies.")
def v_ch_burst():
    pop = mix(lp(thump(150, 60, 0.2, 0.7), 1500), hp(noise(0.05), 1500) * env(0.05, 0.001, 0.04) * 0.8)
    return reverb(mix(pop, glass(0.6, 30, 0.2, 175), flutter(1.5, 4.0, 176, 0.8)), 1.5, 0.3)


@vsound("v_ch_wings", "Chrysalis: wings unfold", "The huge wings unfolding: a grand, airy swell.")
def v_ch_wings():
    seconds = 3.5
    swell = pad(("D3", "A3", "D4", "F#4", "A4", "C#5", "E5", "G#5"), seconds, 0.9, 1.8, 3500, 0.12)
    air = whoosh(1.4, 200, 1200, 400, 0.7) * 0.5
    return reverb(mix(swell, air, sparkle(2.5, 26, 3500, 9000, 0.06, 0.4, 177)), 2.5, 0.35)


@vsound("v_ch_flap", "Chrysalis: first flap", "The first big wing beat, a ring of light rippling out.")
def v_ch_flap():
    ring = sum(bell(note(n), 1.6, 1.0, 2.0) for n in ("D6", "A6", "E7")) * 0.12
    return reverb(mix(flap(0.9, 120, 700, 1.4), ring), 1.8, 0.3)


@vsound("v_ch_beat", "Chrysalis: wing beat", "The slow wing beats as the winner rises (about once a second).", level=-5)
def v_ch_beat():
    return flap(0.6, 140, 600, 1.0)


@vsound("v_ch_swarm", "Chrysalis: butterflies circling", "The butterflies fluttering in a vortex round the winner.", level=-6)
def v_ch_swarm():
    seconds = 4.5
    return flutter(seconds, 2.0, 178, 0.7) * adsr(seconds, 0.4, 0.1, 0.9, 1.2)


@vsound("v_ch_wave", "Chrysalis: wave flies past", "A wave of butterflies flying right at the camera and past it.")
def v_ch_wave():
    seconds = 0.8
    u = np.linspace(0, 1, n_of(seconds))
    return flutter(seconds, 5.0, 179, 1.0) * np.sin(np.pi * u ** 0.7) ** 2 + whoosh(seconds, 300, 1800, 500, 1.0) * 0.4


@vsound("v_ch_leave", "Chrysalis: the last one leaves", "The butterfly on the hand flying off last.")
def v_ch_leave():
    return reverb(mix(flutter(0.6, 2.0, 180, 0.6), bell(note("A6"), 1.2, 0.8, 2.0) * 0.12), 1.4, 0.3)


victory("victory_chrysalis", "Chrysalis", "Iridescent", 11.7, [
    ("v_ch_dark", 0.0, 0.8), ("v_ch_grow", 0.1, 0.7), ("v_ch_silk", 0.6, 0.8), ("v_ch_wrap", 1.2, 0.7),
    ("v_ch_heart", 2.5, 0.5), ("v_ch_heart", 2.9, 0.75), ("v_ch_heart", 3.27, 1.0), ("v_ch_crack", 3.4, 0.8),
    ("v_ch_burst", 3.8, 1.0), ("v_ch_wings", 3.9, 0.9), ("v_ch_flap", 5.1, 0.9), ("v_ch_swarm", 5.3, 0.6),
] + [("v_ch_beat", t, 0.45) for t in (6.1, 7.1, 8.1, 9.1, 10.1)]
  + [("v_ch_wave", t, 0.7) for t in (6.5, 6.95, 7.4, 7.85, 8.3)] + [("v_ch_leave", 10.1, 0.8)])
