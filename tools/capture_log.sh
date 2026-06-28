#!/bin/bash
# tools/capture_log.sh — run a scene headless for N seconds and capture all stdout/stderr.
# Agents read the logfile with the Read tool and search for expected/unexpected strings.
# Display NOT required — headless OK (reads text output, not GPU render).
#
# Usage:
#   tools/capture_log.sh [scene.tscn] [seconds] [logfile]
#
# Args (all optional):
#   scene.tscn  res://-relative path to scene (default: project main scene)
#               pass "" to use default
#   seconds     integer; how long Godot runs before --quit-after kills it (default: 5)
#   logfile     destination path for captured output (default: .godot/capture_log_last.txt)
#
# Output (wrapper's own stdout):
#   CAPTURE-LOG: OK   — <scene> -> <logfile> (N lines)
#   CAPTURE-LOG: FAIL — <reason>
# Exit 0 = OK, 1 = fail.
#
# See library/tools/game-observe.md for rationale and typical invocations.
set -u
cd "$(dirname "$0")/.." || exit 1

SCENE_ARG="${1:-}"
SECONDS_ARG="${2:-5}"
LOGFILE="${3:-.godot/capture_log_last.txt}"

# Resolve the engine binary (same logic as validate.sh).
resolve_engine() {
	if [ -n "${GODOT:-}" ]; then
		printf '%s' "$GODOT"
		return 0
	fi
	for name in godot redot blazium; do
		if command -v "$name" >/dev/null 2>&1; then
			command -v "$name"
			return 0
		fi
	done
	for p in \
		/Applications/Godot.app/Contents/MacOS/Godot \
		/Applications/Redot.app/Contents/MacOS/Redot \
		/Applications/Blazium.app/Contents/MacOS/Blazium \
		/usr/local/bin/godot /usr/bin/godot; do
		if [ -x "$p" ]; then
			printf '%s' "$p"
			return 0
		fi
	done
	return 1
}

if ! GODOT="$(resolve_engine)"; then
	echo "CAPTURE-LOG: FAIL — no engine binary found; set GODOT=/path/to/godot"
	exit 1
fi

# Validate seconds is a positive integer.
if ! echo "$SECONDS_ARG" | grep -qE '^[0-9]+$'; then
	echo "CAPTURE-LOG: FAIL — seconds must be a positive integer, got: $SECONDS_ARG"
	exit 1
fi

# Build the scene label (for output) and the optional scene arg.
if [ -n "$SCENE_ARG" ]; then
	SCENE_LABEL="$SCENE_ARG"
	SCENE_FLAG="res://$SCENE_ARG"
else
	SCENE_LABEL="(main scene)"
	SCENE_FLAG=""
fi

# Ensure the logfile directory exists.
LOG_DIR="$(dirname "$LOGFILE")"
if [ -n "$LOG_DIR" ] && [ "$LOG_DIR" != "." ]; then
	mkdir -p "$LOG_DIR"
fi

# Run Godot headless and tee all output to the logfile.
if [ -n "$SCENE_FLAG" ]; then
	"$GODOT" --headless --path . "$SCENE_FLAG" --quit-after "$SECONDS_ARG" 2>&1 | tee "$LOGFILE"
else
	"$GODOT" --headless --path . --quit-after "$SECONDS_ARG" 2>&1 | tee "$LOGFILE"
fi

# Count lines captured.
LINE_COUNT=0
if [ -f "$LOGFILE" ]; then
	LINE_COUNT=$(wc -l < "$LOGFILE" | tr -d ' ')
fi

if [ "$LINE_COUNT" -gt 0 ]; then
	echo "CAPTURE-LOG: OK — $SCENE_LABEL -> $LOGFILE ($LINE_COUNT lines)"
	exit 0
else
	echo "CAPTURE-LOG: FAIL — logfile empty or not created: $LOGFILE"
	exit 1
fi
