#!/bin/sh
# Every check before a commit: stylua, selene, the syntax check, mapcheck and a Rojo build.
# Prints only what failed (the end of that tool's output), or "checks ok".
cd "$(dirname "$0")/.." || exit 1
export PATH="$HOME/.rokit/bin:$PATH"
LOG=$(mktemp)
FAIL=0
run() {
	NAME=$1
	shift
	if ! "$@" >"$LOG" 2>&1; then
		echo "FAIL: $NAME"
		tail -n 40 "$LOG"
		FAIL=1
	fi
}
run stylua stylua src
run selene selene src
run syntax lune run tools/check-syntax.luau
run mapcheck python3 tools/mapcheck.py
run rojo rojo build -o build/check.rbxlx
rm -f "$LOG"
[ "$FAIL" = 0 ] && echo "checks ok"
exit "$FAIL"
