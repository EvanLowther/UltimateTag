#!/bin/bash
# Daily start: opens VS Code and Roblox Studio on this project, then runs the Rojo sync server.
cd "$(dirname "$0")/.." || exit 1
export PATH="$HOME/.rokit/bin:$PATH"

[ -f UltimateTag.rbxlx ] || rojo build -o UltimateTag.rbxlx
open UltimateTag.code-workspace
open UltimateTag.rbxlx

echo "In Studio: Plugins > Rojo > set port to 34874 > Connect.   Stop the server with Ctrl+C."
rojo serve
