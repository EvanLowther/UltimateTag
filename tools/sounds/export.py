"""Gathers the picked sounds into one folder for upload to Roblox.

    python3 tools/sounds/make_sounds.py build/sounds
    python3 tools/sounds/export.py build/sounds build/sounds/upload

Each picked sound (and each part of a compound one, like the 3-2-1 beep and its GO) becomes
UT_<id>[_<part>].ogg. Each victory is mixed into one track, UT_victory_<name>.ogg, from its cues
exactly as on the Sound Board, so a victory is one upload and one Sound in the game.
"""

from __future__ import annotations

import json
import os
import shutil
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
from synth import SR, write  # noqa: E402

HERE = os.path.dirname(__file__)


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else "build/sounds"
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(src, "upload")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    with open(os.path.join(HERE, "picks.json")) as f:
        picks = {k: v for k, v in json.load(f).items() if not k.startswith("_")}
    with open(os.path.join(src, "manifest.json")) as f:
        manifest = json.load(f)
    sounds = {s["id"]: s for s in manifest["sounds"]}
    names = []
    for sid, letter in picks.items():
        if letter is None:
            print(f"not picked yet: {sid}")
            continue
        for f in sounds[sid]["files"]:
            if f["variant"] != letter:
                continue
            name = f"UT_{sid}.ogg" if f["part"] == "main" else f"UT_{sid}_{f['part']}.ogg"
            shutil.copy(os.path.join(src, f["file"]), os.path.join(out, name))
            names.append(name)
    for v in manifest["victories"]:
        track = np.zeros(0)
        for cue in v["cues"]:
            x, sr = sf.read(os.path.join(src, sounds[cue["sound"]]["files"][0]["file"]))
            assert sr == SR
            if x.ndim == 2:
                x = x.mean(axis=1)
            at = int(round(cue["at"] * SR))
            if at + len(x) > len(track):
                track = np.concatenate([track, np.zeros(at + len(x) - len(track))])
            track[at: at + len(x)] += x * cue["gain"]
        # A soft limiter in place of the board's compressor: loud overlaps round off, quiet parts stay.
        peak = np.max(np.abs(track))
        if peak > 0.89:
            track = np.tanh(track / peak * 1.6) / np.tanh(1.6) * 0.89
        name = "UT_victory_" + v["id"].removeprefix("victory_") + ".ogg"
        write(os.path.join(out, name), track)
        names.append(name)
    with open(os.path.join(out, "files.txt"), "w") as f:
        f.write("\n".join(names) + "\n")
    print(f"{len(names)} files in {out}")


if __name__ == "__main__":
    main()
