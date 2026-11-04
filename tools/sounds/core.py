"""Core game and UI sounds: punchy physical hits for play, bright synth for the UI."""

from __future__ import annotations

import numpy as np

from registry import sound
from synth import (
    adsr, bell, bp, drive, env, fade, fm, glide, hp, lp, mix, n_of, noise, note, osc, place,
    reverb, seed, silence, svf, times,
)


def click(seconds=0.004, lo=2500, hi=9000, gain=1.0):
    return bp(noise(seconds + 0.003), lo, hi) * env(seconds + 0.003, 0.0005, seconds) * gain * 3


def thump(f0=160, f1=55, seconds=0.12, gain=1.0):
    return osc(glide(f0, f1, seconds, "fast"), seconds) * env(seconds, 0.001, seconds * 0.9) * gain


def whoosh(seconds, lo, peak, end, q=1.2, color="pink", mode="bp", shape=None):
    seed(int(seconds * 1000) + lo)
    n = noise(seconds, color)
    u = np.linspace(0, 1, len(n))
    cut = np.where(u < 0.45, lo * (peak / lo) ** (u / 0.45), peak * (end / peak) ** ((u - 0.45) / 0.55))
    amp = np.sin(np.pi * u ** 0.8) ** 2 if shape is None else shape(u)
    return svf(n, cut, q, mode) * amp * 2.2


# ---- Core game -------------------------------------------------------------------------

@sound("swing", "Core game", "Swing", "Every swing (left click). Others hear yours nearby, quieter.",
       [("A", "Short airy whoosh"), ("B", "Heavier whoosh with a low body"), ("C", "Sharp high swish")],
       level=-3, where="3D at the swinger; yours at full volume")
def swing(v):
    if v == 0:
        return whoosh(0.2, 600, 2600, 900, 1.4)
    if v == 1:
        return mix(whoosh(0.26, 300, 1400, 500, 1.2),
                   osc(glide(110, 70, 0.26), 0.26) * np.sin(np.linspace(0, np.pi, n_of(0.26))) ** 2 * 0.25)
    return whoosh(0.16, 2000, 7000, 3000, 0.9, "white", "hp")


@sound("tag_hit", "Core game", "Tagging someone", "Your swing tags a Runner (you're It). Crisp hitmarker.",
       [("A", "Tick + clean ding over a soft thud"), ("B", "Metallic tink"), ("C", "Tock into a rising ding")],
       where="only the tagger")
def tag_hit(v):
    seed(3)
    if v == 0:
        ding = (osc(note("B6"), 0.2) + 0.35 * osc(note("F#7"), 0.2)) * env(0.2, 0.001, 0.17)
        return reverb(mix(click(0.004, 3000, 10000), ding * 0.55, thump(150, 60, 0.07, 0.5)), 0.35, 0.12)
    if v == 1:
        tink = fm(2350, 1.41, 2.2 * np.exp(-times(0.22) * 18), 0.22) * env(0.22, 0.001, 0.2)
        return reverb(mix(click(0.003, 4000, 12000, 0.8), tink * 0.6, thump(130, 60, 0.06, 0.35)), 0.3, 0.1)
    tock = osc(glide(950, 650, 0.03), 0.03) * env(0.03, 0.001, 0.028) * 0.8
    f = np.concatenate([glide(1500, 2100, 0.03), np.full(n_of(0.14), 2100.0)])
    ding = osc(f, 0.17) * env(0.17, 0.002, 0.14) * 0.5
    out = place(tock, ding, 0.025)
    return reverb(mix(out, click(0.003, 3000, 9000, 0.6)), 0.3, 0.1)


@sound("tagged", "Core game", "Getting tagged", "You get tagged (you're It now). A single hit. Others nearby hear it too.",
       [("A", "Meaty slap"), ("B", "Deep thud"), ("C", "Sharp clap-like smack")],
       where="the player tagged at full volume; 3D for anyone nearby")
def tagged(v):
    seed(5)
    if v == 0:
        slap = hp(lp(noise(0.06), 5000), 300) * env(0.06, 0.0008, 0.05) * 2.2
        return drive(mix(slap, thump(220, 70, 0.13, 0.9)), 1.6)
    if v == 1:
        return drive(mix(thump(120, 42, 0.28, 1.0), lp(noise(0.08), 900) * env(0.08, 0.001, 0.07) * 2,
                         click(0.003, 1500, 6000, 0.5)), 1.4)
    out = silence(0.1)
    for i, g in enumerate((1.0, 0.7, 0.9)):
        burst = bp(noise(0.012), 900, 6500) * env(0.012, 0.0005, 0.01) * g * 3
        out = place(out, burst, i * 0.005)
    tail = bp(noise(0.08), 1000, 4000) * env(0.08, 0.001, 0.07)
    return reverb(drive(mix(out, tail, thump(260, 110, 0.06, 0.6)), 1.5), 0.25, 0.12)


def beep_voice(v, f, seconds):
    if v == 0:
        return (osc(f, seconds) + 0.25 * osc(f * 2, seconds) + 0.08 * osc(f, seconds, "square")) * env(seconds, 0.002, seconds * 0.6, seconds * 0.35)
    if v == 1:
        return lp(osc(f, seconds, "pulse"), 4500) * env(seconds, 0.001, seconds * 0.4, seconds * 0.55) * 0.7
    t = times(seconds)
    return (osc(f, seconds) + 0.25 * osc(f * 4, seconds) * np.exp(-t * 60)) * env(seconds, 0.001, seconds)


@sound("countdown", "Core game", "Last 10 seconds",
       "One beep a second for the last 10 s, each a semitone higher (the game raises its pitch); the last 3 louder and doubled.",
       [("A", "Clean beep"), ("B", "Arcade square beep"), ("C", "Marimba blip")],
       where="everyone still in the round",
       demo={"type": "countdown"})
def countdown(v):
    return reverb(beep_voice(v, note("B5") if v != 2 else note("C6"), 0.13 if v != 2 else 0.2), 0.3, 0.1)


@sound("round_start", "Core game", "Round start 3-2-1-GO", "Three beeps during the intro, then GO when you're unfrozen.",
       [("A", "Racing beeps"), ("B", "Synth chord stabs"), ("C", "Deep electronic, rising GO")],
       where="everyone in the round",
       demo={"type": "sequence", "steps": [["beep", 0], ["beep", 1], ["beep", 2], ["go", 3]]})
def round_start(v):
    if v == 0:
        beep = beep_voice(0, note("E5"), 0.22)
        go = (osc(note("E6"), 0.8) + 0.3 * osc(note("E7"), 0.8) + 0.1 * osc(note("E6"), 0.8, "square")) * env(0.8, 0.003, 0.45, 0.25)
        return {"beep": reverb(beep, 0.4, 0.12), "go": reverb(go, 0.6, 0.18)}
    if v == 1:
        def stab(root, seconds, cut):
            chord = sum(osc(note(root) * r * d, seconds, "saw") for r in (1, 1.26, 1.5) for d in (0.997, 1.003))
            return lp(chord, cut) * env(seconds, 0.003, seconds * 0.7, seconds * 0.15) * 0.4
        return {"beep": reverb(stab("C5", 0.2, 2500), 0.4, 0.15),
                "go": reverb(drive(stab("C6", 0.9, 6000) + stab("C5", 0.9, 4000), 1.3), 0.8, 0.22)}
    beep = mix(osc(note("A4"), 0.22) * env(0.22, 0.002, 0.14, 0.06), osc(note("A2"), 0.22) * env(0.22, 0.002, 0.18) * 0.6)
    gf = glide(note("A4"), note("A5"), 0.12)
    gf = np.concatenate([gf, np.full(n_of(0.78), gf[-1])])
    go = mix((osc(gf, 0.9, "saw") * 0.5 + osc(gf * 1.5, 0.9) * 0.3), osc(note("A2"), 0.9) * 0.5) * env(0.9, 0.004, 0.5, 0.3)
    return {"beep": reverb(beep, 0.4, 0.12), "go": reverb(lp(go, 5000), 0.7, 0.2)}


def whistle(seconds, f=2900, trill=34, gain=1.0):
    t = times(seconds)
    tr = np.sin(2 * np.pi * trill * t)
    tone = osc(f + 140 * tr, seconds) * (0.65 + 0.35 * tr)
    breath = bp(noise(seconds), 1800, 6000) * 0.25
    return (tone + breath) * adsr(seconds, 0.015, 0.05, 0.85, 0.05) * gain


@sound("time_up", "Core game", "Time up", "The round timer hits 0. A referee whistle.",
       [("A", "One long blast"), ("B", "Tweet-tweet-tweeeet"), ("C", "Two-tone, higher")],
       where="everyone in the round")
def time_up(v):
    seed(9)
    if v == 0:
        return reverb(whistle(0.95), 0.6, 0.15)
    if v == 1:
        out = silence(0.1)
        out = place(out, whistle(0.12), 0.0)
        out = place(out, whistle(0.12), 0.19)
        out = place(out, whistle(0.65), 0.38)
        return reverb(out, 0.6, 0.15)
    return reverb(mix(whistle(0.85, 2700, 31, 0.6), whistle(0.85, 3150, 37, 0.5)), 0.6, 0.15)


@sound("eliminated", "Core game", "Eliminated", "You're out. A buzzer.",
       [("A", "Classic harsh buzzer"), ("B", "Double buzz"), ("C", "Lower, duller buzz")],
       where="the player eliminated")
def eliminated(v):
    def buzz(seconds, f=140, beat=7, cut=2600):
        tone = osc(f, seconds, "saw") + osc(f + beat, seconds, "saw") + 0.6 * osc(f / 2, seconds, "square")
        return drive(lp(tone, cut), 2.2) * adsr(seconds, 0.005, 0.02, 0.9, 0.04) * 0.6
    if v == 0:
        return reverb(buzz(0.75), 0.3, 0.08)
    if v == 1:
        out = place(buzz(0.28), buzz(0.34), 0.36)
        return reverb(out, 0.3, 0.08)
    seconds = 0.9
    f = np.concatenate([np.full(n_of(0.65), 98.0), glide(98, 80, 0.25)])
    tone = osc(f, seconds, "square") + osc(f * 1.06, seconds, "square")
    return reverb(drive(lp(tone, 1200), 1.8) * adsr(seconds, 0.005, 0.03, 0.9, 0.08) * 0.6, 0.3, 0.08)


@sound("lobby_beep", "Core game", "Lobby countdown", "A soft beep for each of the last 5 s before a game starts.",
       [("A", "Soft blip"), ("B", "Woody tick"), ("C", "Two-tone bell blip")],
       where="everyone in the lobby",
       demo={"type": "sequence", "steps": [["beep", 0], ["beep", 1], ["beep", 2], ["beep", 3], ["last", 4]]})
def lobby_beep(v):
    """A beep for 5, 4, 3, 2, and a held one for the last second."""
    seed(12)
    if v == 0:
        def blip(seconds, hold):
            return reverb(osc(note("G5"), seconds) * env(seconds, 0.003, seconds - hold, hold), 0.6, 0.2)
        return {"beep": blip(0.12, 0.0), "last": blip(0.75, 0.35)}
    if v == 1:
        tick = mix(bp(noise(0.03), 1200, 3000) * env(0.03, 0.001, 0.025) * 2,
                   osc(note("D6"), 0.05) * env(0.05, 0.001, 0.04) * 0.5)
        held = osc(note("D6"), 0.7) * env(0.7, 0.003, 0.35, 0.3) * 0.5
        return {"beep": reverb(tick, 0.4, 0.15), "last": reverb(mix(tick, held), 0.5, 0.18)}

    def two(seconds, bright):
        a = bell(note("E6"), 0.35, bright, 2.0)
        b = bell(note("A6"), seconds, bright, 2.0)
        return place(a * 0.5, b * 0.5, 0.07)
    t = times(0.9)
    held = (osc(note("A6"), 0.9) + 0.3 * osc(note("E7"), 0.9)) * np.clip(t / 0.02, 0, 1) * np.where(t < 0.5, 1.0, np.exp(-(t - 0.5) * 9)) * 0.22
    return {"beep": reverb(two(0.35, 1.2), 0.6, 0.2), "last": reverb(place(two(0.9, 1.2), held, 0.07), 0.7, 0.22)}


# ---- UI --------------------------------------------------------------------------------

@sound("ui_hover", "UI and rewards", "Hover", "The mouse moves onto a button or tile. Very quiet.",
       [("A", "Tiny high blip"), ("B", "Air tick"), ("C", "Small wood tick")], level=-14, where="you")
def ui_hover(v):
    seed(21)
    if v == 0:
        return osc(2600, 0.018) * env(0.018, 0.001, 0.016)
    if v == 1:
        return hp(noise(0.012), 4500) * env(0.012, 0.0005, 0.01) * 3
    return mix(bp(noise(0.012), 1600, 2800) * env(0.012, 0.0005, 0.01) * 2, osc(1800, 0.014) * env(0.014, 0.0005, 0.012) * 0.4)


@sound("ui_click", "UI and rewards", "Click", "Every button press.",
       [("A", "Soft synth click"), ("B", "Bloop"), ("C", "Mechanical click")], level=-6, where="you")
def ui_click(v):
    seed(22)
    if v == 0:
        return mix(lp(osc(glide(1300, 700, 0.035), 0.035, "square"), 5000) * env(0.035, 0.001, 0.03) * 0.5, click(0.002, 3000, 9000, 0.4))
    if v == 1:
        return osc(glide(480, 950, 0.06), 0.06) * env(0.06, 0.002, 0.055)
    a = bp(noise(0.006), 2000, 7000) * env(0.006, 0.0003, 0.005) * 3
    return place(a, a * 0.6, 0.016)


def coin_jingle(seconds=0.35, count=8, gain=0.25, start=0.0):
    out = silence(seconds + 0.3)
    rng = np.random.default_rng(31)
    for i in range(count):
        f = rng.uniform(3000, 5600)
        ping = fm(f, 1.41, 1.2 * np.exp(-times(0.14) * 30), 0.14) * env(0.14, 0.001, 0.12) * gain * rng.uniform(0.5, 1)
        out = place(out, ping, start + rng.uniform(0, seconds))
    return out


@sound("buy", "UI and rewards", "Buy", "You buy an item or a crate. Cha-ching.",
       [("A", "Register drawer + ching + coins"), ("B", "Two bright coin dings"), ("C", "One big ching, coins pouring")],
       where="you")
def buy(v):
    seed(23)
    if v == 0:
        drawer = mix(lp(noise(0.05), 2500) * env(0.05, 0.001, 0.045) * 1.5, thump(170, 90, 0.06, 0.5))
        ching = mix(bell(note("C7"), 0.7, 2.5, 3.51) * 0.5, bell(note("E7"), 0.7, 2.5, 3.51) * 0.4)
        out = place(drawer, ching, 0.08)
        return reverb(mix(out, coin_jingle(0.3, 8, 0.2, 0.1)), 0.5, 0.15)
    if v == 1:
        a = bell(note("E6"), 0.45, 1.8, 2.0) * 0.6
        b = bell(note("B6"), 0.6, 1.8, 2.0) * 0.6
        return reverb(mix(place(a, b, 0.09), coin_jingle(0.25, 5, 0.12, 0.12)), 0.6, 0.18)
    ching = mix(bell(note("D7"), 0.9, 3, 3.51) * 0.5, bell(note("A7"), 0.9, 2, 2.76) * 0.3)
    return reverb(mix(ching, coin_jingle(0.6, 18, 0.16, 0.05)), 0.6, 0.15)


@sound("no_coins", "UI and rewards", "Not enough coins", "You try to buy something you can't afford.",
       [("A", "Low double bonk"), ("B", "Two-note nuh-uh"), ("C", "Muted buzz")], level=-3, where="you")
def no_coins(v):
    if v == 0:
        def bonk(f0, f1):
            return mix(osc(glide(f0, f1, 0.1), 0.1, "tri") * env(0.1, 0.002, 0.09), thump(140, 70, 0.06, 0.4))
        return reverb(place(bonk(230, 175), bonk(195, 145), 0.13), 0.3, 0.1)
    if v == 1:
        a = lp(osc(note("E4"), 0.12, "square"), 2000) * env(0.12, 0.003, 0.08, 0.04) * 0.5
        b = lp(osc(note("B3"), 0.18, "square"), 1800) * env(0.18, 0.003, 0.12, 0.05) * 0.5
        return reverb(place(a, b, 0.14), 0.3, 0.1)
    return lp(osc(110, 0.26, "square") + osc(116, 0.26, "square"), 900) * adsr(0.26, 0.005, 0.02, 0.8, 0.04) * 0.4


@sound("equip", "UI and rewards", "Equip", "You equip an item in the Locker. A snappy click-lock.",
       [("A", "Two clicks + rising blip"), ("B", "Metal latch"), ("C", "Zippy snap")], where="you")
def equip(v):
    seed(24)
    if v == 0:
        c = click(0.003, 2500, 8000, 0.8)
        blip = osc(glide(1200, 1900, 0.06), 0.07) * env(0.07, 0.002, 0.06) * 0.45
        out = place(c, c * 0.8, 0.025)
        return reverb(place(out, blip, 0.04), 0.3, 0.1)
    if v == 1:
        clack = fm(1500, 2.7, 3 * np.exp(-times(0.09) * 40), 0.09) * env(0.09, 0.0005, 0.08) * 0.6
        return reverb(mix(clack, thump(200, 100, 0.05, 0.4), click(0.002, 3000, 9000, 0.5)), 0.3, 0.1)
    snap = svf(noise(0.05), glide(2000, 9000, 0.05), 1.0, "hp") * env(0.05, 0.001, 0.045) * 1.5
    return reverb(mix(snap, osc(glide(700, 1100, 0.04), 0.04) * env(0.04, 0.001, 0.035) * 0.5), 0.3, 0.1)


def sparkle(seconds=1.0, count=14, lo=4000, hi=9000, gain=0.12, start=0.0, seed_n=40):
    out = silence(seconds + 0.4)
    rng = np.random.default_rng(seed_n)
    for _ in range(count):
        f = rng.uniform(lo, hi)
        ping = osc(f, 0.12) * env(0.12, 0.001, 0.1) * gain * rng.uniform(0.4, 1)
        out = place(out, ping, start + rng.uniform(0, seconds) ** 1.4 * seconds ** -0.4)
    return out


@sound("level_up", "UI and rewards", "Level up", "The level-up popup.",
       [("A", "Bell arpeggio + chord + sparkle"), ("B", "Synth brass rising"), ("C", "Fast chiptune arpeggio")],
       level=-5, where="you")
def level_up(v):
    seed(25)
    if v == 0:
        out = silence(1.6)
        for i, n in enumerate(("C6", "E6", "G6", "C7")):
            out = place(out, bell(note(n), 0.5, 1.5, 2.0) * 0.4, i * 0.07)
        chord = sum(bell(note(n), 1.3, 1.2, 2.0) for n in ("C6", "E6", "G6", "C7")) * 0.18
        out = place(out, chord, 0.3)
        return reverb(mix(out, sparkle(1.0, 16, start=0.3)), 1.0, 0.25)
    if v == 1:
        out = silence(1.6)
        for i, n in enumerate(("G4", "C5", "E5")):
            stab = lp(osc(note(n), 0.14, "saw"), 3000) * env(0.14, 0.004, 0.1) * 0.4
            out = place(out, stab, i * 0.08)
        seconds = 1.1
        cut = glide(800, 6000, seconds)
        chord = sum(osc(note(n) * d, seconds, "saw") for n in ("C5", "E5", "G5", "C6") for d in (0.996, 1.004))
        chord = svf(chord, cut, 0.9) * adsr(seconds, 0.04, 0.2, 0.7, 0.4) * 0.22
        out = place(out, chord, 0.26)
        return reverb(mix(out, sparkle(0.8, 10, start=0.4, gain=0.08)), 1.0, 0.22)
    out = silence(1.2)
    seq = ("C5", "E5", "G5", "C6", "E6", "G6", "C7")
    for i, n in enumerate(seq):
        out = place(out, lp(osc(note(n), 0.06, "pulse"), 6000) * env(0.06, 0.001, 0.05, 0.02) * 0.35, i * 0.045)
    final = sum(osc(note(n), 0.5, "square") for n in ("C6", "E6", "G6")) * adsr(0.5, 0.002, 0.1, 0.6, 0.3) * 0.12
    out = place(out, lp(final, 5000), len(seq) * 0.045 + 0.02)
    return reverb(out, 0.5, 0.15)


@sound("claim", "UI and rewards", "Claim reward", "Claiming a quest, achievement or streak day.",
       [("A", "Two-note bell"), ("B", "Shimmer chord"), ("C", "Single ding + sparkle")], where="you")
def claim(v):
    seed(26)
    if v == 0:
        return reverb(place(bell(note("E6"), 0.5, 1.6, 2.0) * 0.5, bell(note("B6"), 0.7, 1.6, 2.0) * 0.5, 0.08), 0.7, 0.2)
    if v == 1:
        seconds = 0.9
        pad = sum(osc(note(n), seconds) for n in ("E5", "G#5", "B5", "E6")) * adsr(seconds, 0.02, 0.2, 0.5, 0.5) * 0.18
        return reverb(mix(pad, sparkle(0.6, 12, gain=0.1)), 0.9, 0.25)
    return reverb(mix(bell(note("A6"), 0.8, 2.2, 3.0) * 0.6, sparkle(0.5, 8, gain=0.08, start=0.05)), 0.7, 0.2)


@sound("crate", "UI and rewards", "Crate opening", "A tick for each item that passes the marker as the reel slows, then the reveal (same for every rarity).",
       [("A", "Plastic tick, whoosh into a bright chord"), ("B", "Metal ratchet, pop + ta-da"), ("C", "Soft blip, boom + shimmer swell")],
       where="you", demo={"type": "crate"})
def crate(v):
    seed(27)
    if v == 0:
        tick = mix(bp(noise(0.008), 2500, 6000) * env(0.008, 0.0005, 0.007) * 2.5, osc(2000, 0.01) * env(0.01, 0.0005, 0.009) * 0.3)
        sweep = whoosh(0.4, 300, 6000, 5000, 1.0, shape=lambda u: u ** 2 * (1 - u ** 8))
        chord = sum(osc(note(n) * d, 1.2, "saw") for n in ("C5", "G5", "C6", "E6") for d in (0.996, 1.004))
        chord = lp(chord, 5500) * env(1.2, 0.004, 1.0, 0.1) * 0.18
        bells = sum(bell(note(n), 1.2, 1.4, 2.0) for n in ("C7", "G7")) * 0.15
        reveal = place(sweep * 0.6, mix(chord, bells, sparkle(1.0, 18, gain=0.1)), 0.38)
        return {"tick": tick, "reveal": reverb(reveal, 1.1, 0.22)}
    if v == 1:
        tick = fm(3000, 1.7, 2 * np.exp(-times(0.02) * 200), 0.02) * env(0.02, 0.0005, 0.018) * 0.7
        pop = mix(osc(glide(300, 900, 0.05), 0.05) * env(0.05, 0.001, 0.045), click(0.003, 2000, 8000, 0.6))

        def brass(names, seconds):
            c = sum(osc(note(n) * d, seconds, "saw") for n in names for d in (0.995, 1.005))
            return svf(c, glide(1200, 4500, seconds), 0.8) * adsr(seconds, 0.02, 0.1, 0.8, 0.2) * 0.18
        reveal = place(pop, brass(("G4", "B4", "D5"), 0.18), 0.06)
        reveal = place(reveal, brass(("C5", "E5", "G5", "C6"), 0.9), 0.26)
        return {"tick": tick, "reveal": reverb(mix(reveal, sparkle(0.8, 12, start=0.3, gain=0.08)), 0.9, 0.2)}
    tick = osc(1400, 0.022) * env(0.022, 0.001, 0.02) * 0.6
    boom = mix(thump(120, 40, 0.5, 1.0), lp(noise(0.3), 400) * env(0.3, 0.002, 0.28) * 0.6)
    t = times(1.4)
    swell = sum(osc(note(n), 1.4) for n in ("A5", "C#6", "E6", "A6")) * np.clip(t / 0.5, 0, 1) ** 2 * np.exp(-np.clip(t - 0.5, 0, None) * 2.5) * 0.12
    reveal = mix(boom, swell, sparkle(1.2, 22, gain=0.09, start=0.1))
    return {"tick": tick, "reveal": reverb(reveal, 1.2, 0.25)}
