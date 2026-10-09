#!/usr/bin/env bash
# Checks the Godot game before a push:
#   1. imports the project (catches parse errors in every script),
#   2. runs every department's headless tests,
#   3. boots the main scene for ten seconds of game time and fails on any script error.
# Usage: tools/godot-check.sh            (GODOT=/path/to/godot to override the binary)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp -d)"
status=0

echo "== import"
"$GODOT" --headless --path game --import >"$LOG/import.log" 2>&1
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR: .*\.gd" "$LOG/import.log" | grep -v "^$" ; then
  echo "import: script errors (full log: $LOG/import.log)"; status=1
else
  echo "import: ok"
fi

echo "== tests"
"$GODOT" --headless --fixed-fps 60 --path game res://tests/runner.tscn -- --all >"$LOG/tests.log" 2>&1
test_rc=$?
grep -E "^TEST|FAIL|RESULT|SCRIPT ERROR" "$LOG/tests.log"
if [ $test_rc -ne 0 ] || grep -q "SCRIPT ERROR" "$LOG/tests.log"; then
  echo "tests: failed (full log: $LOG/tests.log)"; status=1
fi

echo "== boot main scene, 600 frames"
"$GODOT" --headless --fixed-fps 60 --path game --quit-after 600 >"$LOG/boot.log" 2>&1
if grep -E "SCRIPT ERROR|ERROR:" "$LOG/boot.log"; then
  echo "boot: errors (full log: $LOG/boot.log)"; status=1
else
  echo "boot: ok"
fi

exit $status
