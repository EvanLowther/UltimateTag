#!/bin/bash
# One-time setup. Double-click in Finder, or run: ./scripts/setup.command
cd "$(dirname "$0")/.." || exit 1
export PATH="$HOME/.rokit/bin:$PATH"

if ! command -v rokit >/dev/null; then
  echo "Rokit is not installed. Install it from https://github.com/rojo-rbx/rokit then run this again."
  read -r -p "Press Return to close." _; exit 1
fi

rokit trust rojo-rbx/rojo JohnnyMorganz/StyLua Kampfkarren/selene lune-org/lune
rokit install || { read -r -p "rokit install failed. Press Return to close." _; exit 1; }
rojo --version
rojo plugin install && echo "Rojo plugin installed into Roblox Studio (restart Studio if it was open)."
[ -f UltimateTag.rbxlx ] || rojo build -o UltimateTag.rbxlx
echo
echo "Done. Next: double-click scripts/start.command"
read -r -p "Press Return to close." _
