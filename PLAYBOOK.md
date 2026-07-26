# PLAYBOOK.md — master build guide for every factory game

This is the build procedure. **GAME_BLUEPRINT.md is the master plan** — it decides WHAT to build
(feature baseline, cultural hook, shop/monetisation, notifications, store policy, vetted idea
backlog); this file covers HOW. Read FACTORY.md → GAME_BLUEPRINT.md → this file → LESSONS.md.
Every rule in LESSONS.md is binding.

## 0. Product frame (Bazaar/Myket market)
- Persian-only UI, real Persian name, Persian digits everywhere, RTL-correct.
- Easy to learn in seconds (one-hand portrait), engaging for weeks (see Feature baseline).
- Free, offline, no ads in v1. Package id `ir.gamefactory.<slug>` (ASCII), APK label Persian.

## 1. Project setup (copy from games/mergedrop, it embodies all rules)
project.godot must have:
- `renderer/rendering_method="gl_compatibility"` (+ `.mobile` override)  [L2]
- `textures/vram_compression/import_etc2_astc=true`  [L7]
- `window/stretch/mode="canvas_items"`, `aspect="expand"`  [L4]
- portrait orientation, `emulate_touch_from_mouse=true`
- autoload stack: I18n → Store → UI → Sfx → Music (reuse mergedrop scripts as the base)

export_presets.cfg:
- Android ABIs: arm64 + armv7 + x86_64 for testable builds  [L1]
- `exclude_filter="addons/gut/*, tests/*"` on every preset  [L10]
- release keystore `<tools>/secrets/release.keystore`; bump version/code every build the user sees; grep for duplicate keys  [L13]

## 2. Architecture (what made iteration fast)
- Pure logic class (`board.gd` style): RefCounted, zero scene deps, seedable RNG,
  `snapshot()/restore()` for undo. ALL rules of the game live here → exhaustively unit-testable.
- Screens are code-built Controls under a thin `main.gd` shell (menu/game/settings/records),
  each with `relayout()`; shell re-calls it on viewport `size_changed`.  [L4]
- All sizes/positions derive from `UI.board_metrics()` / viewport fractions — no absolute 720×1280 constants.
- Input: one transparent touch Control with `gui_input` (tap + drag-aim + release-drop);
  everything decorative is `MOUSE_FILTER_IGNORE`.  [L3]
- Strings only via I18n.t(); numbers only via I18n.digits().

## 3. Feature baseline (minimum for "a real game")  [L11]
> Superseded in detail by **GAME_BLUEPRINT.md §1** — that list is authoritative and longer
> (duel, share cards, economy with unlimited consumables, notifications, cultural hook).
tutorial (first-run, 2-3 steps) · settings screen (sfx/music/vibration toggles, reset w/ confirm, about)
· goal ladder (progression) · achievements (~10, with unlock toasts) · records screen (top-10 + achievements)
· daily challenge (date-seeded, own best) · undo or mercy mechanic · juice: fall/merge tweens,
pitch-scaled sfx, floating score labels, haptics (`Input.vibrate_handheld`), music loop.

## 4. Assets
- SFX/music: numpy-generated wavs (see pipeline/gen_mergedrop_assets.py) — free, instant.
- AI art via 1xai (`FACTORY.md` has endpoint/models). Persian text in art: generate blank, stamp with PIL+Vazirmatn.  [L8]
- Icons: 512 store + 192 launcher + 1024 hi-res. Fonts: Vazirmatn only (covers FA+EN).

## 5. QA gates — all must pass before showing the user anything
1. `tests/test_scripts_load.gd` — recursive load of every .gd/.tscn, `can_instantiate()`  [L5]
2. Unit tests on the logic class: rules, edge cases, determinism-by-seed, invariants;
   bot test playing 100+ seeded games asserting invariants (no floating tiles, powers of two, reachable game over…)
3. `--autoplay` mode: bot drives the REAL UI (same handlers as touch) to game over ×3, prints AUTOPLAY_DONE  [L3]
4. `pipeline/check_game.sh <slug>` — import, tests, smoke run, autoplay, exports — ALL CHECKS PASSED
5. Long headless runs → log file, never rely on piped stdout  [L9]
6. Visually inspect generated art (Read the PNGs) before shipping them.

## 6. Release
- Exports: Android release APK (signed, verify with apksigner), Linux, Windows.
- `aapt dump badging`: check Persian `application-label`, correct versionCode.
- Persian store listing in `releases/<slug>/store_listing_fa.md` (name, short desc ≤80 chars, full desc, category, permissions=none).
- Milestone message to user: what to install, what changed, what to test.

## 7. After user feedback
Every mistake or user correction → new numbered entry in LESSONS.md + rule here if structural.
Update memory (game-factory-project) when direction changes.
