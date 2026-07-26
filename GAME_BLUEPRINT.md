# GAME_BLUEPRINT.md — the master plan for every game this factory makes

**Read order at the start of any game session: FACTORY.md (toolchain) → this file (what to build
and why) → PLAYBOOK.md (how to build it) → LESSONS.md (56 binding rules from mistakes already made).**

Everything here was learned the expensive way on game #1 «بریز و بساز» — through user rejections,
a 14-agent adversarial audit, a 19-agent design panel, and market research on Cafe Bazaar/Myket.
**Do not re-derive, re-research or re-litigate any of it. Start from here.**

---

## 0. The one-paragraph brief

We make Persian-only, offline, free mobile games for **Cafe Bazaar + Myket**. The user has no
game-dev experience and is involved at exactly two gates: **concept approval** and **milestone
testing**. Every game must be easy to learn in seconds, get genuinely hard, give a reason to
return *tomorrow* that isn't the puzzle itself, and be culturally Iranian in a way a foreign
studio structurally cannot copy.

---

## 1. Feature baseline — a game is NOT shippable without these

Game #1 was rejected by the user twice for missing these. Treat as mandatory, not aspirational.

### Core
- One-hand portrait play, tap/drag input, learnable in under 10 seconds.
- **A difficulty engine that escalates** until every run ends (rising garbage, shrinking time,
  faster spawns). No pressure = "easy and boring" = rejected. Bot QA must show runs *dying*.
- A second mode with **at least two player-visible rule differences** from the first (not just a
  different seed — see LESSONS L14). Game #1: daily = 60 moves + preset obstacles + no undo.
- Undo or another mercy mechanic in the solo mode; never in shared/competitive modes.

### Retention scaffolding
- **Tutorial** on first run (2–3 steps, skippable by completion).
- **Daily challenge**: date-seeded, identical for the whole country, one attempt per day.
- **Daily missions** (3, date-seeded, from a pool) paying soft currency.
- **Streak** counting the *ritual* (the daily challenge), visible from day one, protectable by a
  purchasable shield. Never count "opened the app" as the streak.
- **Goal ladder** + **achievements** (~10) paying currency.
- **Records screen**: top-10 with Persian dates, achievement list.
- **Local reminders** (see §5).

### Companion character
A mascot that speaks to the player's ACTUAL state (streak at risk, record within reach, world rank,
comeback after days away) — priority-ordered, never random. Game #1: «جغد», an owl in a Persian
vest, on the menu with a speech bubble. Art generated at build time, background cut out with PIL.

### Global scoreboard (offline-first)
`server/scoreboard.py` on port 3000 serves every game (`/api/<game>/...`): unique nicknames,
best-kept-wins, per-mode boards, your own rank. The client (`scripts/online.gd`) queues scores in
the save file and flushes them when a network appears; with no server the game is unaffected.
Point a subdomain at the port. **This replaced the friend-duel**, which the user found unconvincing.

### Social / growth (offline-only)
- **Friend duel by pasteable code** — the only acquisition mechanic that works with no backend.
  A code carries `(seed, challenger_score)`; the friend plays the identical board; the comparison
  resolves locally. Read the clipboard on app open and *offer* the challenge — a "paste your code
  here" screen is where this feature dies.
- **Share cards**: one GIFT-shaped (something you give someone) and one BRAG-shaped (a
  spoiler-free result grid). Clipboard-first; the OS share sheet is a bonus, never the only path.

### Economy (see §4)
- Soft currency, unlimited consumables, cosmetics, and a repeatable supporter purchase.

### Cultural hook (the actual differentiator — see §3)
- Something a player would *tell another Iranian about*, embedded in the loop, not bolted on.

### Polish floor
Animated background, glow/bevel, particles on reward, screen shake on big events, count-up
numbers, pulsing CTAs, combo banners, chain-tiered SFX with pitch jitter, **two-stem music that
intensifies with pressure**, haptics. A flat UI reads as cheap and gets rejected.

---

## 2. Architecture that made all of this fast

Copy `games/mergedrop` structure. It is the reference implementation.

```
scripts/
  board.gd        # PURE logic: RefCounted, no scene deps, seedable RNG, snapshot()/restore()
  i18n.gd         # every user-visible string + Persian digits
  jalali.gd       # Gregorian<->Jalali, Persian dates, occasion() for Yalda/Nowruz
  store.gd        # persistence (atomic save + .bak), settings, records, inventory
  missions.gd     # date-seeded daily missions
  economy.gd      # coin catalogue, consumables, cosmetics
  iap.gd          # real-money billing behind available()
  notify.gd       # reminder POLICY (pure) + platform binding
  duel.gd         # challenge code encode/decode
  fal.gd          # the cultural content engine (game-specific)
  share.gd        # clipboard payloads
  ui_kit.gd       # themes, fonts, widget factories, responsive metrics
  sfx.gd, music.gd
  main.gd         # shell: screen routing, back-button, theme repaint
  screens/*.gd    # each with relayout(); rebuilt on viewport change
tools/            # dev-only, EXCLUDED from exports
tests/            # GUT
```

**Non-negotiable patterns**
1. **All rules live in a pure, scene-free class.** That is what makes 100+ tests possible with no device.
2. **Platform features hide behind `available()`** (IAP, notifications, clipboard). Absent plugin →
   feature invisible, game fully playable. Load plugin scripts *dynamically*; a direct `class_name`
   reference makes the build fail without the addon.
3. **Renderers are idempotent.** `relayout()` may run at any time (resize); one-shot progression
   (recording a game, granting a reward) lives in latched functions, never in a renderer.
4. **Everything sized from the live viewport.** No constant tuned to 720×1280.
5. **Hand-positioned Buttons get `size` + `clip_text`**, or Persian labels overflow and overlap.
6. **Looping tweens bind to the node they animate** — otherwise they leak and, in release builds
   (where Godot's guard is compiled out), can hang the game.
7. **Shared/seeded boards pre-roll their whole sequence** with difficulty keyed to move index, never
   to player state, or "everyone plays the same board" is a lie.

---

## 3. The cultural hook — how to pick one

Game #1's USP: **فال حافظ**. Finish the daily challenge → receive that day's real Hafez verse with a
تعبیر on an ornate card, dated in the Persian calendar; goal milestones unlock more verses into a
گنجینه collection; a نیت (intention) press-and-hold ceremony precedes the reveal; a دفتر فال ledger
remembers every fal and tells you when a verse returns to you.

**Why it works, generalised:**
- It is a **living daily ritual** in the target culture, not a theme skin.
- It is **earned, not given** — every standalone fal app hands it over on tap; gating it behind a
  skill challenge converts a 30-second utility into a daily loop.
- It **accumulates** — a collection 40 verses deep cannot be restarted elsewhere.
- It creates a **shared national moment** (same verse for everyone that day) → conversation → shares.
- It owns a **search-intent gap**: fal apps sit in برنامه/سرگرمی, we sit in بازی.

**Candidate hooks for future games** (not yet used): شاهنامه storytelling, ضرب‌المثل‌ها, Persian music
radif, خوشنویسی, تقویم/مناسبت‌ها, آشپزی ایرانی, بازی‌های محلی (گل یا پوچ، هفت‌سنگ، الک‌دولک), معما و چیستان.

**Rules**
- Frame it **literary/cultural, never divinatory**. Ban طالع‌بینی/پیشگویی/سرنوشت from all copy — it is
  both store-risky and cheap.
- **Verify every quoted cultural text with ≥2 independent AI models** before shipping (LESSONS L19).
  On game #1, 39 of 103 drafted verses failed and were dropped.
- Pool must be big enough that a full cycle exceeds a season, and the daily draw must walk a fixed
  shuffled pool with a **stride coprime to the pool size** so no item repeats within one cycle.
- The ritual content is **never purchasable**. Ever.

---

## 4. Shop & monetisation — decided, do not redesign

**Structure** (game #1 reference, `economy.gd` + `iap.gd`):

| Layer | Examples | Repeatable? |
|---|---|---|
| Real money → soft currency | coin packs ×3 | ♾ yes |
| Real money → gratitude | «حمایت از بازی» supporter tip, stacking ❤ badge | ♾ yes |
| Coins → consumables | undo pack, streak shield, treasury key, mission reroll | ♾ yes |
| Coins → cosmetics | tile themes, card frames | one-off each |

**Hard rules**
- **No gacha, no loot boxes, no randomised paid rewards.** Bazaar bans gambling outright and
  publishes no loot-box carve-out. Sell fixed, known quantities only.
- **Nothing pay-to-win** and nothing that affects a shared/competitive board.
- **The ritual content is never for sale** — ship a test that asserts no catalogue entry grants it.
- Free vs paid is **immutable after publish** on Bazaar. Always publish free with IAP.
- Consumables **must be `consume`d** after purchase or the store reports "already owned" and the
  SKU can never be bought again.

**Myket IAP integration (solved, reusable)**
- Myket publishes only a legacy AIDL billing library with **no licence grant** — do not vendor it,
  and do not use plugins that depend on it (LESSONS L50).
- Ship `games/mergedrop/addons/myket` instead: our own MIT plugin (Java + AIDL + GDScript face
  mirroring Poolakey's API). Copy it to the next game as-is.
- Permission `ir.mservices.market.BILLING`, bind action `ir.mservices.market.InAppBillingService.BIND`,
  package `ir.mservices.market`, plus a `<queries>` entry (Android 11+ or the bind silently fails).
- Myket panel: reserve the package id first, then the app box exposes the public key. Products
  carry a consumable flag set at creation; consumables must be consumed to be re-buyable.

**Bazaar IAP integration (solved, reusable)**
- SDK: **Poolakey**. Godot 4 plugin: `DexterFstone/godot-poolakey` (Asset Library 3525) — already
  vendored at `games/mergedrop/addons/poolakey`.
- Requires **Godot's Gradle build** (`use_gradle_build=true`) — no native plugin works with the
  prebuilt template. Install template by extracting `export_templates/<ver>/android_source.zip`
  into `android/build/`, `chmod +x android/build/gradlew`, write `android/.build_version` + `.gdignore`.
- **Set `compress_native_libraries=true`** or the APK balloons 53 MB → 147 MB (LESSONS L44).
- The **RSA public key** appears in Pishkhan only after a release build is uploaded — the user must
  fetch it. Until then `IAP.available()` is false and the money UI hides itself.
- **Bazaar and Myket billing permissions cannot coexist in one APK** → two builds, produced by
  `pipeline/build_stores.sh <slug>`. Each store's plugin is gated inside its vendored `plugin.gd`
  on `GF_STORE`, because a v2 export plugin otherwise injects itself into every Android export
  (LESSONS L49). The script asserts no cross-store leakage and refuses to pass if it finds any.
- Revenue share was ~15% up to ~1B تومان/yr (2021 figure) — verify live in the panel.

---

## 5. Notifications — policy decided, do not redesign

Local only (no server, no push, no Firebase). The POLICY lives in pure GDScript (`notify.gd`) and is
unit-tested; the platform half schedules with the OS and is absent on desktop/CI.

**What we send** — only about the player's own state:
1. **Gentle daily nudge** — "your fal is waiting", at a user-chosen hour (default 20:00).
2. **Streak warning** — when the streak is ≥3 and today is unplayed; mentions their shield if owned.
3. **Comeback** — different wording after several days away.

**What we never send:** ads, promotions, other games, fake urgency, anything not about this player.

**Rules baked into `plan()`**
- Quiet hours: nothing between 00:00 and 08:00; nothing after 22:00.
- Schedule **7 days ahead** — the app may never reopen to re-sync.
- **Back off when ignored**: daily → every 2nd day → every 3rd → weekly. An ignored reminder is a
  bad reminder and a fast path to uninstall.
- Playing resets the backoff; a player who already played today is never nudged that day.
- User toggle + hour picker in Settings, on by default but one tap to silence.
- Android 13+ needs the `POST_NOTIFICATIONS` runtime permission; treat denial as "feature off".
- **Plugin**: `godot-mobile-plugins/godot-notification-scheduler` v6 (v2 architecture, survives
  reboot via its own BootReceiver, uses `setExactAndAllowWhileIdle` with graceful fallback). Vendored
  at `games/mergedrop/addons/NotificationSchedulerPlugin`. Needs the Gradle build, like Poolakey.
  Create a channel once before scheduling; there is no bulk cancel, so use deterministic ids.
- Ship a Settings action that requests exact-alarm + battery-optimisation exemption — it fixes the
  real MIUI/Samsung "alarms get killed" problem AND justifies the permissions the plugin adds.
- **Times are LOCAL.** Convert with the timezone bias
  (`unix_of(date) + hour*3600 - Time.get_time_zone_from_system().bias*60`) and test the round trip —
  a naive UTC computation fires a 20:00 reminder at 23:30 in Tehran (LESSONS L46).

---

## 6. Store compliance — Cafe Bazaar + Myket (researched, current as of July 2026)

Full detail in `releases/<slug>/SUBMISSION.md`. The build-shaping essentials:

- **targetSdk ≥ 32** (Myket: ≥34 for new apps/updates from 23 Oct 2026). APK ≤ **150 MB**.
- Store APK is **arm-only** (armeabi-v7a + arm64-v8a). x86_64 is not accepted — but PC emulators
  need it, so keep a separate `AndroidTest` preset for the user's testing.
- Icon: **plain square** PNG ≥512² (Bazaar adds its own radius/shadow), identical to the launcher
  icon; ship **adaptive** icons (432² fg/bg) or Android 8+ letterboxes it.
- Header 720×288 PNG 5:2 ≤1 MB; promo 1152×648 JPG 16:9 ≤1 MB; screenshots ≤1 MB each.
- Persian short description **≤60 chars**; app name ≤16 chars before truncation; the store name must
  equal the on-device name.
- **In-app privacy policy and a منابع/اعتبارات (credits) screen are mandatory**, even collecting nothing.
- **Copyright is Bazaar's #1 rejection reason** — document every asset's licence in SUBMISSION.md.
- Declare **no permissions** unless truly needed; unnecessary permissions are a top-4 rejection reason.
- Annual fee 400,000 ریال; review ≤3 business days (Thu/Fri excluded).

---

## 7. Testing — the layers that caught real bugs

Target 100+ tests before the user ever sees a build. Every layer below caught defects on game #1:

1. **`test_scripts_load.gd`** — recursively `load()` every `.gd` in `scripts/`, `tests/`, `tools/`
   and assert `can_instantiate()`. GUT silently *skips* unparseable test files, so without this a
   broken test reports "all passed".
2. **`test_fonts.gd`** — every character of every localized string, UI symbol, Persian digit and
   content file must have a glyph in the font or its fallback. Emoji need a bundled Noto Emoji
   fallback or they render as tofu boxes.
3. **`test_layout.gd`** — build every screen at 4 aspect ratios; assert no two laid-out buttons
   intersect and none leaves the viewport. **Verify the guard fails when you inject an overlap.**
4. **Pure-logic tests** on the rules class: edge cases, determinism by seed, invariants.
5. **Bot test** playing 100+ seeded games asserting invariants hold every move.
6. **Shared-board fairness test**: play one seed two different ways, assert identical sequences.
7. **`--autoplay` mode** driving the REAL UI (the same handlers a finger triggers) to game over.
8. **Policy tests** for economy, notifications, ledger — cheap, and they encode product decisions.
9. **Regression tests named after each fixed bug.**
10. `pipeline/check_game.sh <slug>` — import, tests, smoke run, autoplay, exports. Debug exports go
    to `releases/<slug>/debug/`; never let QA overwrite a release-signed artifact.

Also: `pipeline/make_screenshots.py` mirrors `ui_kit.gd` and doubles as a **layout oracle** — it
caught overlapping buttons before any device test. Keep it in sync after every layout change.

---

## 8. Idea backlog — vetted by a 19-agent design panel, ready to pull from

Ranked ideas already generated and judged for retention/uniqueness/feasibility/cultural fit. **Pull
from here instead of brainstorming again.**

**Highest value, not yet built:**
- **Season engine (موتور مناسبت‌ها)** — a dated سفره of N nights on the Jalali calendar; each daily
  challenge lights one; **cumulative** (never consecutive) milestones; two «شب مهمان» makeup tokens;
  earned-only seasonal themes/frames/content, year-tagged rather than confiscated. Anchor dates live
  in a baked JSON table (**never compute equinoxes at runtime**). Prove it on a small season
  (مهرگان) before the big one (**یلدا, 21 Dec 2026 — the single best store-featuring pitch of the
  year; ship by early December for the 3-business-day review**).
- **Resume an interrupted run** (`user://run.cfg`) — a phone call must never cost the day's attempt.
- **محفل (pass-the-phone hot-seat)** with a persistent friend-group table — offline دورهمی play.
- **فال به نیت دوست / gift-a-fal** — draw on someone else's behalf, name-seeded so they can verify it.
- **Volley codes + rival ledger** — turn one duel paste into an ongoing thread with a running record.
- **Chaptered collection** — poet/theme chapters with seals and illumination that evolves as you fill it.
- **Poet commemoration days** tied to the Persian calendar.
- **Share-as-image** (currently text) — needs FileProvider + gradle build.
- Chaharshanbe Suri fire-night mode; Nowruz 13-day season.

---

## 9. The build sequence for game #2 (do it in this order)

1. Read FACTORY.md → this file → PLAYBOOK.md → LESSONS.md.
2. Pick genre + cultural hook (§3). Show the user the concept. **Wait for approval.**
3. Copy `games/mergedrop` as the skeleton; strip game-specific logic, keep the autoload stack,
   ui_kit, i18n, store, missions, economy, iap, notify, duel, share, tests scaffolding.
4. Build the pure rules class + its tests first. Then the difficulty engine.
5. Build screens with `relayout()`; run `test_layout.gd` early.
6. Generate audio (`pipeline/gen_audio_v2.py` pattern) and art (1xai; blank art + PIL-stamped Persian).
7. Wire the cultural hook + verify all quoted content by multi-model consensus.
8. Feature baseline (§1), economy (§4), notifications (§5).
9. `check_game.sh`, screenshots, store assets, SUBMISSION.md.
10. Milestone build to the user. Then adversarial audit workflow before submission.

---

## 10. Things the user has told us (standing instructions)

- Persian-only, Bazaar/Myket, easy to play, deeply engaging.
- The user does not want to be involved except concept approval and milestone testing.
- Every game needs something **no other game in the world has**, and a real reason to choose it.
- Shop with **infinitely purchasable** items connected to Bazaar billing.
- **Notifications to bring users back**, like a real app.
- Learn from mistakes; never rediscover them — that is what LESSONS.md and this file are for.
