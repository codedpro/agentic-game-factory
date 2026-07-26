#!/bin/bash
# Full automated check of one game: import, unit tests, headless smoke-run, exports.
# Usage: pipeline/check_game.sh <slug> [--no-export]
set -uo pipefail
source "$(dirname "$0")/env.sh"
SLUG="${1:?usage: check_game.sh <slug>}"
GAME="$FACTORY/games/$SLUG"
REPORT="$FACTORY/reports/${SLUG}-$(date +%Y%m%d-%H%M%S).log"
cd "$GAME"

fail=0
step() { echo -e "\n=== $1 ===" | tee -a "$REPORT"; }

step "IMPORT"
$GODOT --headless --import . >>"$REPORT" 2>&1 || { echo IMPORT-FAILED | tee -a "$REPORT"; fail=1; }

step "UNIT TESTS"
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tee -a "$REPORT" | tail -6
grep -q "All tests passed" "$REPORT" || { echo TESTS-FAILED | tee -a "$REPORT"; fail=1; }

step "HEADLESS SMOKE RUN (600 frames)"
# benign exit-time leak warnings excluded; real script/runtime errors still fail
timeout 120 $GODOT --headless --path . --quit-after 600 2>&1 | tee -a "$REPORT" \
  | grep -viE "still in use at exit|instances were leaked" | grep -ciE "script error|ERROR" \
  | { read n; [ "$n" -gt 0 ] && { echo "RUNTIME-ERRORS:$n" | tee -a "$REPORT"; fail=1; } || echo "clean run"; }

step "AUTOPLAY (if supported)"
timeout 240 $GODOT --headless --path . -- --autoplay > /tmp/autoplay_check.log 2>&1
grep -q "AUTOPLAY_DONE" /tmp/autoplay_check.log \
  && echo "autoplay ok" | tee -a "$REPORT" \
  || { grep -q "AUTOPLAY" /tmp/autoplay_check.log || echo "autoplay not supported (skip)" | tee -a "$REPORT"; }
grep -E "SCRIPT ERROR" /tmp/autoplay_check.log | head -5 | tee -a "$REPORT" | grep -q . && fail=1

if [ "${2:-}" != "--no-export" ]; then
  mkdir -p "$FACTORY/releases/$SLUG"
  # Debug builds go to their own folder: exporting to the preset's path would
  # silently replace the SIGNED RELEASE artifact with a debug-signed one.
  DBG="$FACTORY/releases/$SLUG/debug"
  mkdir -p "$DBG"
  step "EXPORT ANDROID (debug)"
  timeout 300 $GODOT --headless --path . --export-debug "Android" "$DBG/$SLUG-debug.apk" >>"$REPORT" 2>&1
  [ -f "$DBG/$SLUG-debug.apk" ] && echo "APK ok: $(du -h "$DBG/$SLUG-debug.apk" | cut -f1)" | tee -a "$REPORT" \
    || { echo APK-MISSING | tee -a "$REPORT"; fail=1; }
  step "EXPORT LINUX (debug)"
  timeout 300 $GODOT --headless --path . --export-debug "Linux" "$DBG/$SLUG-debug.x86_64" >>"$REPORT" 2>&1 || fail=1
fi

step "RESULT"
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" | tee -a "$REPORT" || echo "CHECKS FAILED — see $REPORT" | tee -a "$REPORT"
exit $fail
