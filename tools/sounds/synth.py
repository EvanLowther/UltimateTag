"""A small synth for the game's sound effects: oscillators, noise, envelopes, filters, reverb.

Everything is numpy arrays of floats at SR samples a second (mono unless a function says
otherwise). Sounds are built by mixing these and written as OGG Vorbis (Roblox takes .ogg).
"""

from __future__ import annotations

import math

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(7)


def seed(n: int) -> None:
    """Restart the random numbers so a sound comes out the same every run."""
    global RNG
    RNG = np.random.default_rng(n)


def n_of(seconds: float, sr: int | None = None) -> int:
    return max(1, int(round(seconds * (sr or SR))))


def times(seconds: float, sr: int | None = None) -> np.ndarray:
    return np.arange(n_of(seconds, sr)) / (sr or SR)


def silence(seconds: float, sr: int | None = None) -> np.ndarray:
    return np.zeros(n_of(seconds, sr))


# Pitch curves ---------------------------------------------------------------------------

def glide(f0: float, f1: float, seconds: float, curve: str = "exp", sr: int | None = None) -> np.ndarray:
    """A pitch moving from f0 to f1 over the sound ("exp" sounds even to the ear)."""
    u = np.linspace(0, 1, n_of(seconds, sr))
    if curve == "exp":
        return f0 * (f1 / f0) ** u
    if curve == "fast":  # most of the move early
        return f1 + (f0 - f1) * np.exp(-u * 6)
    return f0 + (f1 - f0) * u


def note(name: str | int) -> float:
    """'A4' or a MIDI number to Hz."""
    if isinstance(name, (int, float)):
        return 440.0 * 2 ** ((name - 69) / 12)
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semis = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semis += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        semis -= 1
        rest = rest[1:]
    return 440.0 * 2 ** ((semis + (int(rest) + 1) * 12 - 69) / 12)


# Oscillators ----------------------------------------------------------------------------

def phase_of(freq, seconds: float, sr: int | None = None) -> np.ndarray:
    n = n_of(seconds, sr)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,)) if np.ndim(freq) == 0 else np.asarray(freq)[:n]
    if len(f) < n:
        f = np.concatenate([f, np.full(n - len(f), f[-1])])
    return 2 * np.pi * np.cumsum(f) / (sr or SR)


def osc(freq, seconds: float, shape: str = "sine", sr: int | None = None, phase0: float = 0.0) -> np.ndarray:
    ph = phase_of(freq, seconds, sr) + phase0
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == "square":
        return np.tanh(np.sin(ph) * 8) * 0.9
    if shape == "pulse":  # a thinner, nasal square
        return np.where(np.mod(ph, 2 * np.pi) < 2 * np.pi * 0.25, 1.0, -0.33)
    if shape == "saw":
        # A band-limited-ish saw: the first harmonics only, so high notes don't alias.
        out = np.zeros_like(ph)
        f = np.asarray(freq, dtype=float)
        top = float(np.max(f)) if np.ndim(f) else float(f)
        k_max = int(max(1, min(40, (sr or SR) / 2.2 / max(top, 1))))
        for k in range(1, k_max + 1):
            out += np.sin(ph * k) / k * (-1) ** (k + 1)
        return out * 0.6
    raise ValueError(shape)


def fm(carrier, ratio: float, index, seconds: float, sr: int | None = None) -> np.ndarray:
    """Two-operator FM: bells, electric pianos, metal."""
    n = n_of(seconds, sr)
    cf = np.broadcast_to(np.asarray(carrier, dtype=float), (n,)) if np.ndim(carrier) == 0 else np.asarray(carrier)[:n]
    mod = np.sin(phase_of(cf * ratio, seconds, sr))
    idx = np.broadcast_to(np.asarray(index, dtype=float), (n,)) if np.ndim(index) == 0 else np.asarray(index)[:n]
    return np.sin(phase_of(cf, seconds, sr) + idx * mod)


def bell(freq: float, seconds: float, bright: float = 3.0, ratio: float = 3.5, sr: int | None = None) -> np.ndarray:
    t = times(seconds, sr)
    idx = bright * np.exp(-t * 6)
    return fm(freq, ratio, idx, seconds, sr) * np.exp(-t * (4.0 / seconds))


def noise(seconds: float, color: str = "white", sr: int | None = None) -> np.ndarray:
    n = n_of(seconds, sr)
    w = RNG.standard_normal(n)
    if color == "white":
        return w / 3
    if color == "pink":
        spec = np.fft.rfft(w)
        f = np.fft.rfftfreq(n, 1 / (sr or SR))
        f[0] = f[1] if n > 1 else 1
        spec /= np.sqrt(f)
        out = np.fft.irfft(spec, n)
        return out / (np.max(np.abs(out)) + 1e-9) * 0.9
    if color == "brown":
        out = np.cumsum(w)
        out = signal.sosfilt(signal.butter(1, 20, "hp", fs=sr or SR, output="sos"), out)
        return out / (np.max(np.abs(out)) + 1e-9) * 0.9
    raise ValueError(color)


# Envelopes ------------------------------------------------------------------------------

def env(seconds: float, attack: float = 0.005, decay: float | None = None, hold: float = 0.0,
        sr: int | None = None) -> np.ndarray:
    """A quick rise, an optional hold, then an exponential fall (decay = time to about -60 dB)."""
    t = times(seconds, sr)
    decay = decay if decay is not None else max(0.01, seconds - attack - hold)
    rise = np.clip(t / max(attack, 1e-4), 0, 1)
    fall = np.where(t < attack + hold, 1.0, np.exp(-(t - attack - hold) * 6.9 / decay))
    return rise * fall


def adsr(seconds: float, a: float, d: float, s: float, r: float, sr: int | None = None) -> np.ndarray:
    t = times(seconds, sr)
    out = np.full_like(t, s)
    out = np.where(t < a, t / max(a, 1e-4), out)
    out = np.where((t >= a) & (t < a + d), 1 - (1 - s) * (t - a) / max(d, 1e-4), out)
    rel_start = seconds - r
    out = np.where(t >= rel_start, out * np.clip((seconds - t) / max(r, 1e-4), 0, 1), out)
    return out


def ramp(seconds: float, points: list[tuple[float, float]], sr: int | None = None) -> np.ndarray:
    """A curve through (time, value) points, straight lines between them."""
    t = times(seconds, sr)
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return np.interp(t, xs, ys)


def fade(x: np.ndarray, start: float = 0.002, end: float = 0.01, sr: int | None = None) -> np.ndarray:
    x = x.copy()
    a, b = min(n_of(start, sr), len(x)), min(n_of(end, sr), len(x) // 2)
    if a > 1:
        x[:a] *= np.linspace(0, 1, a)
    if b > 1:
        x[-b:] *= np.linspace(1, 0, b)
    return x


# Filters --------------------------------------------------------------------------------

def _sos(kind: str, fc, order: int, sr: int | None):
    nyq = (sr or SR) / 2
    if isinstance(fc, (tuple, list)):
        fc = [min(max(f, 10), nyq * 0.95) for f in fc]
    else:
        fc = min(max(fc, 10), nyq * 0.95)
    return signal.butter(order, fc, kind, fs=sr or SR, output="sos")


def lp(x: np.ndarray, fc: float, order: int = 2, sr: int | None = None) -> np.ndarray:
    return signal.sosfilt(_sos("lowpass", fc, order, sr), x)


def hp(x: np.ndarray, fc: float, order: int = 2, sr: int | None = None) -> np.ndarray:
    return signal.sosfilt(_sos("highpass", fc, order, sr), x)


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2, sr: int | None = None) -> np.ndarray:
    return signal.sosfilt(_sos("bandpass", (lo, hi), order, sr), x)


def svf(x: np.ndarray, cutoff, q: float = 0.7, mode: str = "lp", sr: int | None = None) -> np.ndarray:
    """A state-variable filter whose cutoff can move every sample (sweeps, whooshes)."""
    n = len(x)
    fc = np.broadcast_to(np.asarray(cutoff, dtype=float), (n,)) if np.ndim(cutoff) == 0 else np.asarray(cutoff)[:n]
    if len(fc) < n:
        fc = np.concatenate([fc, np.full(n - len(fc), fc[-1])])
    g = np.tan(np.pi * np.clip(fc, 10, (sr or SR) * 0.45) / (sr or SR))
    k = 1 / q
    a1 = 1 / (1 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    ic1 = ic2 = 0.0
    out = np.empty(n)
    xs = x.tolist()
    a1l, a2l, a3l, gl = a1.tolist(), a2.tolist(), a3.tolist(), g.tolist()
    m = {"lp": 0, "bp": 1, "hp": 2}[mode]
    for i in range(n):
        v0 = xs[i]
        v3 = v0 - ic2
        v1 = a1l[i] * ic1 + a2l[i] * v3
        v2 = ic2 + a2l[i] * ic1 + a3l[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        if m == 0:
            out[i] = v2
        elif m == 1:
            out[i] = v1
        else:
            out[i] = v0 - k * v1 - v2
    return out


def peak_eq(x: np.ndarray, fc: float, gain_db: float, q: float = 1.0, sr: int | None = None) -> np.ndarray:
    a = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / (sr or SR)
    alpha = np.sin(w0) / (2 * q)
    b = [1 + alpha * a, -2 * np.cos(w0), 1 - alpha * a]
    den = [1 + alpha / a, -2 * np.cos(w0), 1 - alpha / a]
    return signal.lfilter(b, den, x)


# Effects --------------------------------------------------------------------------------

def drive(x: np.ndarray, amount: float = 2.0) -> np.ndarray:
    return np.tanh(x * amount) / np.tanh(amount)


def bitcrush(x: np.ndarray, bits: int = 6, hold: int = 2) -> np.ndarray:
    steps = 2 ** bits
    y = np.round(x * steps) / steps
    if hold > 1:
        y = np.repeat(y[::hold], hold)[: len(x)]
    return y


def _ir(seconds: float, decay: float, bright: float, sr: int, rng) -> np.ndarray:
    t = np.arange(n_of(seconds, sr)) / sr
    w = rng.standard_normal(len(t))
    dark = signal.sosfilt(signal.butter(1, 1200 * bright, "lp", fs=sr, output="sos"), w)
    light = signal.sosfilt(signal.butter(1, min(9000 * bright, sr * 0.45), "lp", fs=sr, output="sos"), w)
    mix_curve = np.exp(-t * 3 / max(decay, 0.05))  # high end dies first
    ir = (light * mix_curve + dark * (1 - mix_curve)) * np.exp(-t * 6.9 / decay)
    pre = n_of(0.012, sr)
    ir = np.concatenate([np.zeros(pre), ir])
    return ir / np.sqrt(np.sum(ir ** 2) + 1e-9)


def reverb(x: np.ndarray, decay: float = 1.2, wet: float = 0.25, bright: float = 1.0,
           sr: int | None = None, tail: bool = True) -> np.ndarray:
    sr = sr or SR
    rng = np.random.default_rng(11)
    ir = _ir(decay * 1.3, decay, bright, sr, rng)
    padded = np.concatenate([x, np.zeros(len(ir))]) if tail else x
    wet_sig = signal.fftconvolve(padded, ir)[: len(padded)]
    return padded * (1 - wet * 0.5) + wet_sig * wet


def reverb_stereo(x: np.ndarray, decay: float = 1.5, wet: float = 0.3, bright: float = 1.0,
                  sr: int | None = None) -> np.ndarray:
    """Mono or stereo in, stereo out (two different rooms left and right)."""
    sr = sr or SR
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    out = []
    for ch, s in enumerate((21, 37)):
        rng = np.random.default_rng(s)
        ir = _ir(decay * 1.3, decay, bright, sr, rng)
        wet_sig = signal.fftconvolve(x[:, ch], ir)[: len(x)]
        out.append(x[:, ch] * (1 - wet * 0.5) + wet_sig * wet)
    return np.stack(out, axis=1)


def echo(x: np.ndarray, time: float, feedback: float = 0.35, mix: float = 0.3, repeats: int = 4,
         sr: int | None = None) -> np.ndarray:
    d = n_of(time, sr)
    out = np.concatenate([x, np.zeros(d * repeats)])
    for i in range(1, repeats + 1):
        out[d * i: d * i + len(x)] += x * mix * feedback ** (i - 1)
    return out


def tremolo(x: np.ndarray, rate: float, depth: float, sr: int | None = None) -> np.ndarray:
    t = np.arange(len(x)) / (sr or SR)
    if x.ndim == 2:  # stereo: the two sides move against each other (a gentle auto-pan)
        left = 1 - depth * 0.5 * (1 + np.sin(2 * np.pi * rate * t))
        right = 1 - depth * 0.5 * (1 - np.sin(2 * np.pi * rate * t))
        return x * np.stack([left, right], axis=1)
    return x * (1 - depth * 0.5 * (1 + np.sin(2 * np.pi * rate * t)))


def warp(x: np.ndarray, rate: float = 0.6, depth: float = 0.002, sr: int | None = None) -> np.ndarray:
    """Tape wobble: reads the sound back a touch faster and slower."""
    sr = sr or SR
    n = len(x)
    t = np.arange(n) / sr
    pos = np.arange(n) + depth * sr * np.sin(2 * np.pi * rate * t) + depth * 0.4 * sr * np.sin(2 * np.pi * 3.1 * t)
    pos = np.clip(pos, 0, n - 1)
    if x.ndim == 1:
        return np.interp(pos, np.arange(n), x)
    return np.stack([np.interp(pos, np.arange(n), x[:, c]) for c in range(x.shape[1])], axis=1)


# Mixing ---------------------------------------------------------------------------------

def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    shape = (n, 2) if any(p.ndim == 2 for p in parts) else (n,)
    out = np.zeros(shape)
    for p in parts:
        if out.ndim == 2 and p.ndim == 1:
            out[: len(p)] += p[:, None]
        else:
            out[: len(p)] += p
    return out


def place(buffer: np.ndarray, sound: np.ndarray, at: float, gain: float = 1.0, sr: int | None = None,
          pan: float | None = None) -> np.ndarray:
    """Adds a sound into a buffer at a time, growing the buffer if needed. Returns the buffer."""
    i = n_of(at, sr) if at > 0 else 0
    end = i + len(sound)
    if end > len(buffer):
        extra = np.zeros((end - len(buffer),) + buffer.shape[1:])
        buffer = np.concatenate([buffer, extra])
    s = sound * gain
    if buffer.ndim == 2 and s.ndim == 1:
        p = 0.0 if pan is None else pan
        left = math.cos((p + 1) * math.pi / 4)
        right = math.sin((p + 1) * math.pi / 4)
        buffer[i:end, 0] += s * left * 1.414
        buffer[i:end, 1] += s * right * 1.414
    else:
        buffer[i:end] += s
    return buffer


def pad_to(x: np.ndarray, seconds: float, sr: int | None = None) -> np.ndarray:
    n = n_of(seconds, sr)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros((n - len(x),) + x.shape[1:])])


def trim(x: np.ndarray, floor_db: float = -60, sr: int | None = None) -> np.ndarray:
    """Cuts the silent tail off a sound (keeps a short fade)."""
    level = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    peak = np.max(level) + 1e-9
    above = np.nonzero(level > peak * 10 ** (floor_db / 20))[0]
    if len(above) == 0:
        return x
    end = min(len(x), above[-1] + n_of(0.02, sr))
    return fade(x[:end], 0.0, 0.015, sr) if x.ndim == 1 else x[:end]


def normalize(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    peak = np.max(np.abs(x)) + 1e-9
    return x / peak * 10 ** (peak_db / 20)


def loop_seam(x: np.ndarray, length: float, sr: int | None = None) -> np.ndarray:
    """Folds what runs past `length` back over the start, so the sound loops without a seam."""
    n = n_of(length, sr)
    head = x[:n].copy()
    tail = x[n:]
    if len(tail):
        k = min(len(tail), n)
        head[:k] += tail[:k]
    return head


def crossfade_loop(x: np.ndarray, length: float, overlap: float = 1.0, sr: int | None = None) -> np.ndarray:
    """Makes a loop from a longer recording: its end fades into its start."""
    n, o = n_of(length, sr), n_of(overlap, sr)
    body = x[:n].copy()
    tail = x[n: n + o]
    curve = np.linspace(0, 1, len(tail))
    if body.ndim == 2:
        curve = curve[:, None]
    body[: len(tail)] = body[: len(tail)] * np.sqrt(curve) + tail * np.sqrt(1 - curve)
    return body


def write(path: str, x: np.ndarray, sr: int | None = None, quality: float = 0.6) -> None:
    import soundfile as sf

    x = np.clip(x, -1, 1).astype(np.float32)
    if path.endswith(".mp3"):
        sf.write(path, x, sr or SR, format="MP3", subtype="MPEG_LAYER_III")
    else:
        sf.write(path, x, sr or SR, format="OGG", subtype="VORBIS")
