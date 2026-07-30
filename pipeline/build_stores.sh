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
# Output filename comes from the preset's own export_path — no per-game hardcoding.
apk_for() {
	awk -F'"' -v p="$1" '$0 ~ "^name=" {n=$2} n==p && /export_path/ {print $2}' \
		export_presets.cfg | xargs basename
}

build() {   # preset, GF_STORE value, permission that MUST be present ("" = none)
	local preset="$1" store="$2" want="$3"
	local out
	out="$(apk_for "$preset")"
	echo -e "\n=== $preset (GF_STORE=$store)"
	# Bake in ONLY this store's display name, so no rival name exists in the APK.
	python3 "$FACTORY/pipeline/gen_store_brand.py" "$GAME" "${store:-none}" || { fail=1; return; }
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
	# A game that talks to a server must declare INTERNET, or Android blocks every
	# request and the client can only report "offline" (see LESSONS L60).
	if [ -f "$GAME/scripts/online.gd" ] && ! grep -q "android.permission.INTERNET" <<<"$perms"; then
		echo "MISSING android.permission.INTERNET — networking will silently fail"; fail=1
	fi
	# No APK may NAME a competing store to the player. Myket rejected 5.4 because a
	# hard-coded "کافه‌بازار" shipped inside the Myket build (LESSONS L69). The check
	# reads the exported script bytecode, which Godot stores zstd-compressed.
	if [ "$store" = "myket" ] || [ "$store" = "bazaar" ]; then
		if ! python3 "$FACTORY/pipeline/check_store_names.py" "$OUT/$out" "$store"; then
			fail=1
		fi
	fi
	echo "ok: $(du -h "$OUT/$out" | cut -f1)  $(grep -c . <<<"$perms") permissions"
}

build "Android"       none    ""
build "AndroidTest"   none    ""
build "AndroidBazaar" bazaar  "PAY_THROUGH_BAZAAR"
build "AndroidMyket"  myket   "mservices.market.BILLING"

# Leave the working tree store-neutral: the generated brand is build output, and a
# stale one makes test runs depend on whichever export happened to go last.
python3 "$FACTORY/pipeline/gen_store_brand.py" "$GAME" none >/dev/null

echo -e "\n=== RESULT"
[ $fail -eq 0 ] && echo "ALL STORE BUILDS OK" || echo "STORE BUILDS FAILED"
exit $fail
