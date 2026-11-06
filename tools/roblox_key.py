"""The owner's Roblox Open Cloud API key and user id, for the upload scripts (tools/icons,
tools/sounds).

The key comes from ROBLOX_API_KEY if it's set, else from the macOS Keychain. The first time,
the script asks for it (typing hidden) and saves it in the Keychain, so it's never typed again;
it never goes in the repo, a file or a command line. `--forget-key` on an upload script removes
the saved key (after making a new one on Roblox, say), and the next run asks again.
"""

import getpass
import os
import subprocess
import sys

SERVICE = "UltimateTag Roblox API key"
ACCOUNT = "open-cloud"
OWNER_USER_ID = "2371363134"  # SurfyAlmond12, who owns the uploads; ROBLOX_USER_ID overrides it


def _security(args: list, stdin: str | None = None) -> subprocess.CompletedProcess | None:
    try:
        return subprocess.run(["security", *args], input=stdin, capture_output=True, text=True)
    except FileNotFoundError:  # not a Mac
        return None


def _saved() -> str | None:
    result = _security(["find-generic-password", "-s", SERVICE, "-a", ACCOUNT, "-w"])
    if result and result.returncode == 0 and result.stdout.strip():
        return result.stdout.strip()
    return None


def _save(key: str) -> bool:
    if '"' in key or "\\" in key or "\n" in key:
        return False
    # Sent through `security -i` on its input, so the key never shows in a process list.
    command = f'add-generic-password -U -s "{SERVICE}" -a "{ACCOUNT}" -w "{key}"\n'
    result = _security(["-i"], command)
    return bool(result and result.returncode == 0)


def forget_key() -> None:
    result = _security(["delete-generic-password", "-s", SERVICE, "-a", ACCOUNT])
    print("Saved key removed." if result and result.returncode == 0 else "No saved key.")


def api_key() -> str:
    key = os.environ.get("ROBLOX_API_KEY") or _saved()
    if key:
        return key
    if not sys.stdin.isatty():
        sys.exit("No API key: set ROBLOX_API_KEY, or run this in a terminal to be asked for it.")
    key = getpass.getpass("Roblox API key (paste it, then Enter; it won't show): ").strip()
    if not key:
        sys.exit("No key given.")
    if _save(key):
        print("Saved in your Mac's Keychain; you won't be asked again.")
    return key


def user_id() -> str:
    return os.environ.get("ROBLOX_USER_ID") or OWNER_USER_ID
