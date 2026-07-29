# Game Factory

> **This file documents the TOOLCHAIN only.** Start at [AGENTS.md](AGENTS.md), then
> [factory.json](factory.json) (which market), then [markets/](markets/) (store facts), then
> [GAME_BLUEPRINT.md](GAME_BLUEPRINT.md), [PLAYBOOK.md](PLAYBOOK.md) and [LESSONS.md](LESSONS.md).

Automated pipeline that produces, tests, and packages bilingual (English/Persian)
2D games for Android (Google Play), itch.io (PC), and later Steam.
Operated end-to-end by Claude; the user is only involved at two gates:
**concept approval** before a game is built, and **milestone testing** of near-final builds.

## Toolchain (all portable, no root)

| Tool | Location | Notes |
|------|----------|-------|
| Godot 4.7.1 | `<tools>/godot` | headless-capable; export templates in `~/.local/share/godot/export_templates/4.7.1.stable` |
| JDK 17 (Temurin) | `<tools>/jdk17` | needed for Android signing/build |
| Android SDK | `<tools>/android-sdk` | platform-tools, build-tools 34, platform android-34 |
| Debug keystore | `<tools>/debug.keystore` | pass `android`, alias `androiddebugkey` |
| GUT 9.6.1 | `templates/addons/gut` | unit test framework, copied into each game |
| Vazirmatn font | `assets/fonts/vazirmatn` | covers Persian + Latin in one family |

Source `pipeline/env.sh` in every shell before using the tools.
Editor settings with Android paths: `~/.config/godot/editor_settings-4.7.tres`.

## Directory layout

- `pipeline/` — automation scripts (see below)
- `templates/` — reusable pieces (GUT addon; game project template)
- `games/<slug>/` — one Godot project per game (`_smoke` is the pipeline test)
- `releases/<slug>/` — exported APK / Linux / Windows builds + store listing material
- `reports/` — automated test & QA reports per game/run
- `assets/` — shared fonts and CC0 asset packs (Kenney etc.)

## Verified commands (the pipeline's backbone)

```bash
source <repo>/pipeline/env.sh
cd games/<slug>
$GODOT --headless --import .                                   # (re)import resources — run after any asset change
$GODOT --headless --path . --quit-after 300                    # headless smoke-run N frames
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit   # unit tests
$GODOT --headless --path . --export-debug "Android"            # APK per export_presets.cfg
$GODOT --headless --path . --export-debug "Linux"
```

## Hard-won facts (do not rediscover)

- Android export **requires** `textures/vram_compression/import_etc2_astc=true` under `[rendering]` in project.godot.
- `adb: cannot connect to daemon` during export is harmless (no device attached).
- "No project icon specified" is a non-fatal warning; set a 192x192 icon before release anyway.
- Always run `--import` before tests/exports after adding files, or resources will be missing.
- No sudo on this machine; no GPU (no local screenshot rendering yet — visual QA needs
  xvfb + lavapipe from extracted .deb packages, TODO if/when needed).
- No X display: run everything `--headless`.

## Testing layers per game

1. **GUT unit tests** in `tests/` — game logic must be in plain, scene-independent scripts so it's testable.
2. **Bot-player harness** — a `tests/bot_play.gd` autoload/scene that simulates input and plays
   the game headless for thousands of frames, asserting: no crashes, no script errors,
   score progresses, game-over reachable, restart works.
3. **Release checks** — export succeeds for all targets, APK badging correct (`aapt dump badging`),
   version code bumped, both locales load, Persian strings render (font has glyphs).

## Publishing state

Store facts, fees, submission steps and billing SDKs live in the **market modules**
([`markets/`](markets/)) — not here. The default market is **international**.

Machine-local paths this toolchain expects:
- Release keystore: `<tools>/secrets/release.keystore` (password via env, see `pipeline/env.sh`).
  **Same signature forever** — a new key makes updates impossible for installed users.
- Image generation for art: an OpenAI-compatible endpoint configured in `<tools>/secrets/`.
- Screenshots: `pipeline/make_screenshots.py` renders real board states dumped by
  `games/<slug>/tools/dump_states.gd`, mirroring the game's own layout constants.


## Status log

- 2026-07-25: Factory bootstrapped. Full chain verified on `_smoke`: headless run, GUT tests pass, Linux binary runs, signed debug APK builds.
- 2026-07-25: **v3.2 «بریز و بساز»** — USP فال حافظ with repeat-free daily cycle, Jalali calendar
  (Yalda/Nowruz), clipboard share cards (fal gift + Wordle-style daily grid), emoji font fallback,
  layout-overlap fix + regression tests, 56 GUT tests, store screenshot pipeline
  (`pipeline/make_screenshots.py` — also serves as a layout oracle), Bazaar/Myket asset pack and
  `releases/mergedrop/SUBMISSION.md`.
- 2026-07-29: **«مثلستان» (masalestan) v1.0 milestone build done.** Game #2: آمیرزا-style
  letter-wheel word game where every level is a verified Persian proverb (113 levels,
  2-of-3 model consensus; 525-word bonus dictionary). Campaign + shared daily + timed rush,
  treasury, full feature baseline reused from the factory. 123 GUT tests green (35k asserts),
  autoplay bot drives the real UI through all three modes. 4 store APKs built and verified
  (billing separation proven by dex scan), screenshots + header/promo + SUBMISSION.md ready.
  Awaiting user milestone test.
- 2026-07-25: **MergeDrop v1.0 milestone build done.** Persian-only drop-merge puzzle.
  21 GUT tests green (incl. 120 bot-played games, 755k asserts); headless autoplay through real UI OK.
  Release-signed APK + Linux + Windows in `releases/mergedrop/`, AI-generated icon,
  Persian store listing written. Awaiting user milestone test, then screenshots + submission.
