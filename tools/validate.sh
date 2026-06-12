#!/bin/bash
# tools/validate.sh — the project's validate gate (the `pnpm validate` equivalent):
# format + lint + parse(+warnings-as-errors) + scene properties + smoke run.
# Steps 4–5 are godot-verify layers 1–2; layer 3 (render) needs a display and
# stays in the godot-verify skill.
#
# Usage (from the project root or anywhere):  tools/validate.sh
# Exit 0 = gate passed ("validate: OK").
set -u
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PATH="$HOME/.local/bin:$PATH"

GD_FILES=$(find . -name '*.gd' -not -path './.godot/*' -not -path './addons/*' | sed 's|^\./||')
if [ -z "$GD_FILES" ]; then
	echo "validate: FAIL setup — no .gd files found"
	exit 1
fi

fail() {
	echo "validate: FAIL $1"
	exit 1
}

# 1. format
# shellcheck disable=SC2086
if ! gdformat --check $GD_FILES; then
	fail "format — run: gdformat <file> on the files listed above"
fi
echo "validate: PASS format"

# 2. lint
# shellcheck disable=SC2086
if ! gdlint $GD_FILES; then
	fail "lint"
fi
echo "validate: PASS lint"

# 3. parse + analyzer warnings (escalated to errors by project.godot [debug]).
# --import first: rebuilds the global class cache so new class_name scripts resolve.
if ! "$GODOT" --headless --path . --import >/dev/null 2>&1; then
	fail "import — godot --import failed; run it manually to see the errors"
fi

for f in $GD_FILES; do
	out=$("$GODOT" --headless --path . --check-only --script "res://$f" 2>&1)
	status=$?
	if [ $status -ne 0 ] || echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|WARNING"; then
		echo "$out"
		fail "parse — $f"
	fi
done
echo "validate: PASS parse"

# 4. scene property validation (godot-verify layer 1)
if ! "$GODOT" --headless --path . --script tools/verify_scene.gd; then
	fail "scenes"
fi
echo "validate: PASS scenes"

# 5. smoke run (godot-verify layer 2) — any ERROR/WARNING line = failure
smoke=$("$GODOT" --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR|WARNING")
if [ -n "$smoke" ]; then
	echo "$smoke"
	fail "smoke"
fi
echo "validate: PASS smoke"

echo "validate: OK"
