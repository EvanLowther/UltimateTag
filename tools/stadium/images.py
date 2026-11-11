#!/usr/bin/env python3
"""Writes Tag Stadium's pictures (tools/stadium/art.py) as PNGs, ready for upload.py:

    python3 tools/stadium/images.py build/stadium

Writes <out>/png/<name>.png and <out>/files.txt (the PNGs, one per line).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art  # noqa: E402


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "build/stadium"
    os.makedirs(os.path.join(out, "png"), exist_ok=True)
    names = []
    for name, img in sorted(art.all_images().items()):
        img.save(os.path.join(out, "png", name + ".png"))
        names.append(name + ".png")
        print(f"{name}: {img.width} x {img.height}")
    with open(os.path.join(out, "files.txt"), "w") as f:
        f.write("\n".join(names) + "\n")
    print(f"wrote {len(names)} images to {out}/png")


if __name__ == "__main__":
    main()
