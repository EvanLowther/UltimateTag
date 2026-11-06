"""Renders every sound (all variants) as OGG into an output folder, with a manifest.json.

    python3 tools/sounds/make_sounds.py build/sounds [id ...]

The audition page plays these files; the picked variants get uploaded to Roblox and their
asset ids go in Config.Sounds.
"""

from __future__ import annotations

import json
import multiprocessing as mp
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))

import core  # noqa: E402,F401  (registers sounds)
import maps  # noqa: E402,F401
import station  # noqa: E402,F401
import victories  # noqa: E402,F401
from registry import SOUNDS, VICTORIES  # noqa: E402
import numpy as np  # noqa: E402

from synth import SR, hp, trim, write  # noqa: E402


def level(x: np.ndarray, peak_db: float, sr: int) -> np.ndarray:
    """No DC, peaks at most at peak_db (with headroom for the OGG encoder), and roughly even
    loudness: quiet, spread-out sounds are raised toward the same RMS as the rest."""
    x = hp(x, 25, 1, sr) if x.ndim == 1 else np.stack([hp(x[:, c], 25, 1, sr) for c in range(x.shape[1])], axis=1)
    pk = float(np.max(np.abs(x))) + 1e-9
    rms = float(np.sqrt(np.mean(x ** 2))) + 1e-9
    target_rms = 10 ** ((-16.5 + peak_db + 1) / 20)
    target_pk = 10 ** ((min(peak_db, -1.5)) / 20)
    return x * min(target_pk / pk, target_rms / rms)

OUT = "build/sounds"


def render(index: int) -> list[dict]:
    try:
        return _render(index)
    except Exception as e:  # report every broken sound at once, not just the first
        import traceback
        print(f"FAILED {SOUNDS[index].id}: {e}\n{traceback.format_exc(limit=-3)}")
        return []


def _render(index: int) -> list[dict]:
    s = SOUNDS[index]
    sr = s.sr or SR
    files = []
    for v, (letter, label) in enumerate(s.variants):
        result = s.fn(v)
        parts = result if isinstance(result, dict) else {"main": result}
        for part, x in parts.items():
            if not s.loop:
                x = trim(x, -62, sr)
            x = level(x, s.level, sr)
            name = f"{s.id}_{letter}.ogg" if part == "main" else f"{s.id}_{part}_{letter}.ogg"
            write(os.path.join(OUT, name), x, sr)
            # An MP3 copy for the audition page (every browser plays MP3; the game uses the OGG).
            write(os.path.join(OUT, "web", name.replace(".ogg", ".mp3")), x, sr)
            files.append({"variant": letter, "part": part, "file": name,
                          "seconds": round(len(x) / sr, 3)})
    return files


def main() -> None:
    global OUT
    if len(sys.argv) > 1:
        OUT = sys.argv[1]
    only = set(sys.argv[2:])
    os.makedirs(os.path.join(OUT, "web"), exist_ok=True)
    used = {c[0] for v in VICTORIES if not v.skip for c in v.cues}
    skipped = {c[0] for v in VICTORIES if v.skip for c in v.cues} - used
    indices = [i for i, s in enumerate(SOUNDS) if s.id not in skipped and (not only or s.id in only)]
    started = time.time()
    with mp.get_context("fork").Pool(min(8, os.cpu_count() or 4)) as pool:
        results = pool.map(render, indices)
    rendered = dict(zip(indices, results))
    manifest_path = os.path.join(OUT, "manifest.json")
    old = {}
    if only and os.path.exists(manifest_path):
        with open(manifest_path) as f:
            old = {s["id"]: s for s in json.load(f)["sounds"]}
    sounds = []
    for i, s in enumerate(SOUNDS):
        if i in rendered:
            entry = {"id": s.id, "group": s.group, "name": s.name, "desc": s.desc, "where": s.where,
                     "loop": s.loop, "demo": s.demo,
                     "variants": [{"letter": l, "label": lab} for l, lab in s.variants],
                     "files": rendered[i]}
        else:
            entry = old.get(s.id)
        if entry and s.id not in skipped:
            sounds.append(entry)
    manifest = {
        "sounds": sounds,
        "victories": [{"id": v.id, "name": v.name, "rarity": v.rarity, "length": v.length,
                       "cues": [{"sound": c[0], "at": c[1], "gain": c[2]} for c in v.cues]}
                      for v in VICTORIES if not v.skip],
    }
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=1)
    total = sum(os.path.getsize(os.path.join(OUT, n)) for n in os.listdir(OUT) if n.endswith(".ogg"))
    print(f"{len(indices)} sounds, {sum(len(r) for r in results)} files, {total / 1e6:.1f} MB, {time.time() - started:.1f} s")


if __name__ == "__main__":
    main()
