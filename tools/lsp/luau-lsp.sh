#!/bin/sh
# Starts luau-lsp over stdio with the Roblox types and Rojo's sourcemap (kept up to date while it runs),
# for editors and agents' code intelligence. Speaks LSP on stdout, so everything else goes to stderr.
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
export PATH="$HOME/.rokit/bin:$PATH"
DIR="$ROOT/build/lsp"
TYPES="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau"
DOCS="https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/api-docs/en-us.json"
mkdir -p "$DIR"
[ -s "$DIR/globalTypes.None.d.luau" ] || curl -sfL -o "$DIR/globalTypes.None.d.luau" "$TYPES" >&2
[ -s "$DIR/en-us.json" ] || curl -sfL -o "$DIR/en-us.json" "$DOCS" >&2
cd "$ROOT" || exit 1
rojo sourcemap default.project.json -o sourcemap.json >&2
rojo sourcemap default.project.json -o sourcemap.json --watch >/dev/null 2>&1 &
WATCH=$!
trap 'kill $WATCH 2>/dev/null' EXIT INT TERM HUP
luau-lsp lsp --stdio --definitions=@roblox="$DIR/globalTypes.None.d.luau" --docs="$DIR/en-us.json"
