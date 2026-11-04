"""Uploads the exported sounds to Roblox with Open Cloud and records their asset ids.

Run it yourself, with your own API key in the environment (never paste the key anywhere else):

    export ROBLOX_API_KEY=...        # create.roblox.com > Open Cloud > API Keys, "Assets" read + write
    export ROBLOX_USER_ID=...        # your user id (the number in your profile's URL)
    python3 tools/sounds/upload.py build/sounds/upload

Ids land in tools/sounds/asset_ids.json ("swing": 1234567890, ...). Files already in it are
skipped, so it can be run again after a failure or after a sound is redone (delete its line to
upload it again). Only the Python standard library is used.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(__file__)
IDS = os.path.join(HERE, "asset_ids.json")
API = "https://apis.roblox.com/assets/v1"


def request(method: str, url: str, key: str, body: bytes | None = None, ctype: str | None = None) -> dict:
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{e.code} {e.reason}: {e.read().decode(errors='replace')[:400]}") from None


def upload(path: str, name: str, key: str, user: str) -> str:
    meta = {
        "assetType": "Audio",
        "displayName": name,
        "description": "Ultimate Tag sound",
        "creationContext": {"creator": {"userId": user}},
    }
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        data = f.read()
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n"
        f"Content-Type: application/json\r\n\r\n{json.dumps(meta)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
        f"Content-Type: audio/ogg\r\n\r\n"
    ).encode() + data + f"\r\n--{boundary}--\r\n".encode()
    op = request("POST", f"{API}/assets", key, body, f"multipart/form-data; boundary={boundary}")
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", f"{API}/operations/{op_id}", key)
    if not op.get("done"):
        raise RuntimeError("still processing after 2 minutes; run the script again later")
    if "error" in op:
        raise RuntimeError(json.dumps(op["error"]))
    return str(op["response"]["assetId"])


def main() -> None:
    folder = sys.argv[1] if len(sys.argv) > 1 else "build/sounds/upload"
    key = os.environ.get("ROBLOX_API_KEY")
    user = os.environ.get("ROBLOX_USER_ID")
    if not key or not user:
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_USER_ID first (see the top of this file).")
    ids = {}
    if os.path.exists(IDS):
        with open(IDS) as f:
            ids = json.load(f)
    with open(os.path.join(folder, "files.txt")) as f:
        files = [line.strip() for line in f if line.strip()]
    failed = 0
    for i, file in enumerate(files, 1):
        sid = file.removeprefix("UT_").removesuffix(".ogg")
        if sid in ids:
            continue
        try:
            ids[sid] = int(upload(os.path.join(folder, file), file.removesuffix(".ogg"), key, user))
            print(f"[{i}/{len(files)}] {sid}: {ids[sid]}")
        except Exception as e:  # keep going; a second run retries what failed
            failed += 1
            print(f"[{i}/{len(files)}] {sid}: FAILED {e}")
        with open(IDS, "w") as f:
            json.dump(dict(sorted(ids.items())), f, indent=1)
        time.sleep(0.5)
    print(f"done: {len(ids)} ids in {IDS}" + (f", {failed} failed (run again to retry)" if failed else ""))


if __name__ == "__main__":
    main()
