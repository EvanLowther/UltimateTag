#!/usr/bin/env python3
"""Uploads Tag Stadium's pictures to Roblox with Open Cloud and writes their image ids for the game.

Run it yourself (it uses your saved API key, like the icons: tools/roblox_key.py):

    python3 tools/stadium/images.py build/stadium
    python3 tools/stadium/upload.py build/stadium

Ids land in tools/stadium/asset_ids.json and the image ids in src/shared/MapImages.luau, which the
game reads: any Texture, Decal or ImageLabel on a map with an `Image` attribute gets that image
(client/StadiumWorld). Until then the map shows plain colours. Pictures already uploaded are
skipped, so it can be run again after a failure. To redo one: change it in art.py, render, delete
its line from asset_ids.json and run this again. Only the Python standard library is used (the
upload itself is tools/icons/upload.py's).
"""

from __future__ import annotations

import importlib.util
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
IDS = os.path.join(HERE, "asset_ids.json")
LUAU = os.path.join(ROOT, "src", "shared", "MapImages.luau")

sys.path.insert(0, TOOLS)
import roblox_key  # noqa: E402

_spec = importlib.util.spec_from_file_location("icon_upload", os.path.join(TOOLS, "icons", "upload.py"))
icon_upload = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(icon_upload)


def write_luau(ids: dict) -> None:
    lines = [
        "--!strict",
        "-- Uploaded map pictures by name (written by tools/stadium/upload.py; don't edit by hand).",
        "-- A Texture, Decal or ImageLabel on a map with an `Image` attribute shows the one named.",
        "return {",
    ]
    for name, entry in sorted(ids.items()):
        if entry.get("image"):
            lines.append(f'\t{name} = "rbxassetid://{entry["image"]}",')
    lines.append("} :: { [string]: string }")
    with open(LUAU, "w") as f:
        f.write("\n".join(lines) + "\n")


def main() -> None:
    folder = sys.argv[1] if len(sys.argv) > 1 else "build/stadium"
    key = roblox_key.api_key()
    user = roblox_key.user_id()
    ids: dict = json.load(open(IDS)) if os.path.exists(IDS) else {}
    with open(os.path.join(folder, "files.txt")) as f:
        files = [line.strip() for line in f if line.strip()]
    failed = 0
    for i, file in enumerate(files, 1):
        name = file.removesuffix(".png")
        entry = ids.setdefault(name, {})
        try:
            if "decal" not in entry:
                entry["decal"] = icon_upload.upload(os.path.join(folder, "png", file), f"UT_{name}", key, user)
            if "image" not in entry:
                entry["image"] = icon_upload.image_of(entry["decal"], key)
            print(f"[{i}/{len(files)}] {name}: image {entry['image']}")
        except Exception as e:  # keep going; a second run retries what failed
            failed += 1
            print(f"[{i}/{len(files)}] {name}: FAILED {e}")
        if not entry:
            del ids[name]
        with open(IDS, "w") as f:
            json.dump(dict(sorted(ids.items())), f, indent=1)
        time.sleep(0.3)
    write_luau(ids)
    ready = sum(1 for e in ids.values() if e.get("image"))
    print(f"done: {ready} of {len(files)} pictures have images (src/shared/MapImages.luau)")
    if failed:
        print(f"{failed} failed: run it again to retry.")


if __name__ == "__main__":
    main()
