#!/bin/sh
# Run from any working directory. Pass Godot arguments after this script's args.
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_EXECUTABLE=${GODOT_BIN:-godot}
if ! command -v "$GODOT_EXECUTABLE" >/dev/null 2>&1; then
  if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    GODOT_EXECUTABLE=/Applications/Godot.app/Contents/MacOS/Godot
  else
    echo "Godot 4 is required. Set GODOT_BIN to its executable." >&2
    exit 1
  fi
fi
exec "$GODOT_EXECUTABLE" --headless --path "$TASK_ROOT" -- --server "$@"
