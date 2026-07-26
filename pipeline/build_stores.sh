#!/bin/bash
# Build every store artifact for a game, each with the correct billing plugin.
#
# Why the GF_STORE env var: Godot 4 v2 Android export plugins inject their AAR (and its
# manifest permissions) into EVERY Android export — the `gradle_build/plugins/*` preset flag
# only governs legacy v1 plugins. Cafe Bazaar and Myket reject APKs carrying the other
# store's billing permission, so each store plugin is gated on this variable instead.
#
# Usage: pipeline/build_stores.sh <slug>
set -uo pipefail
source "$(dirname "$0")/env.sh"
SLUG="${1:?usage: build_stores.sh <slug>}"
GAME="$FACTORY/games/$SLUG"
OUT="$FACTORY/releases/$SLUG"
AAPT="$ANDROID_HOME/build-tools/34.0.0/aapt"
SIGNER="$ANDROID_HOME/build-tools/34.0.0/apksigner"
cd "$GAME"

fail=0
build() {   # preset, GF_STORE value, output file, permission that MUST be present ("" = none)
	local preset="$1" store="$2" out="$3" want="$4"
	echo -e "\n=== $preset (GF_STORE=$store)"
	GF_STORE="$store" timeout 900 $GODOT --headless --path . --export-release "$preset" \
		> "/tmp/build_${SLUG}_${preset}.log" 2>&1
	if [ ! -f "$OUT/$out" ]; then
		echo "MISSING $out — see /tmp/build_${SLUG}_${preset}.log"; fail=1; return
	fi
	$SIGNER verify "$OUT/$out" >/dev/null 2>&1 || { echo "UNSIGNED $out"; fail=1; }
	local perms
	perms=$($AAPT dump badging "$OUT/$out" 2>/dev/null | grep "uses-permission" || true)
	# each store must NOT carry the other's billing permission
	if [ "$store" = "myket" ] && grep -q "PAY_THROUGH_BAZAAR" <<<"$perms"; then
		echo "LEAK: Bazaar billing permission in the Myket build"; fail=1
	fi
	if [ "$store" = "bazaar" ] && grep -q "mservices.market.BILLING" <<<"$perms"; then
		echo "LEAK: Myket billing permission in the Bazaar build"; fail=1
	fi
	if [ -n "$want" ] && ! grep -q "$want" <<<"$perms"; then
		echo "MISSING PERMISSION $want in $out"; fail=1
	fi
	echo "ok: $(du -h "$OUT/$out" | cut -f1)  $(grep -c . <<<"$perms") permissions"
}

build "Android"       none    "MergeDrop-release.apk"       ""
build "AndroidTest"   none    "MergeDrop-test-emulator.apk" ""
build "AndroidBazaar" bazaar  "MergeDrop-bazaar-iap.apk"    "PAY_THROUGH_BAZAAR"
build "AndroidMyket"  myket   "MergeDrop-myket.apk"         "mservices.market.BILLING"

echo -e "\n=== RESULT"
[ $fail -eq 0 ] && echo "ALL STORE BUILDS OK" || echo "STORE BUILDS FAILED"
exit $fail
