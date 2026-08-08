#!/usr/bin/env bash
# Install a build on a connected device/emulator and capture what it does at startup.
#
# This exists because the blank-screen class of bug is invisible everywhere else: unit
# tests pass, the desktop release build runs clean, and the APK exports fine. Only a real
# device shows it, and only logcat says why (Myket rejected 5.5 with a bare navy screen
# and no further detail — see LESSONS L71).
#
#   pipeline/device_log.sh mergedrop [myket|bazaar-iap|release|test-emulator]
#
# Enable USB debugging on the phone (Settings → Developer options), plug it in, accept
# the "allow debugging" prompt, then run this. Output lands in reports/.
set -uo pipefail

SLUG="${1:?usage: device_log.sh <game-slug> [variant]}"
VARIANT="${2:-myket}"
FACTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$FACTORY/pipeline/env.sh"
ADB="${ANDROID_SDK_ROOT:-$ANDROID_HOME}/platform-tools/adb"
PKG="ir.gamefactory.$SLUG"
APK=$(ls "$FACTORY/releases/$SLUG"/*"$VARIANT"*.apk 2>/dev/null | head -1)
OUT="$FACTORY/reports/device-$SLUG-$VARIANT-$(date +%Y%m%d-%H%M%S).log"

[ -f "$APK" ] || { echo "no APK matching '$VARIANT' in releases/$SLUG"; exit 1; }
"$ADB" get-state >/dev/null 2>&1 || {
	echo "No device. Check: USB debugging on, cable connected, 'allow debugging' accepted."
	"$ADB" devices; exit 1; }

echo "device : $("$ADB" shell getprop ro.product.model | tr -d '\r') / Android $("$ADB" shell getprop ro.build.version.release | tr -d '\r')"
echo "apk    : $(basename "$APK")"

# Uninstall first: a leftover install with a different signature or stale save data hides
# exactly the first-run problems a reviewer hits.
"$ADB" uninstall "$PKG" >/dev/null 2>&1
"$ADB" install -r "$APK" 2>&1 | tail -2

"$ADB" logcat -c
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "launched — capturing 20s of logcat…"
timeout 20 "$ADB" logcat -v time > "$OUT" 2>&1

echo
echo "=== crashes / exceptions ==="
grep -iE "FATAL|AndroidRuntime|SecurityException|Exception|godot.*error|SCRIPT ERROR" "$OUT" \
	| grep -v "^$" | head -25 || echo "  none found"
echo
echo "=== our app's own lines ==="
grep -iE "godot|$PKG|mergedrop" "$OUT" | head -25
echo
echo "full log: $OUT"
