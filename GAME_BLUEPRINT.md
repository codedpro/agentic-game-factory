# GAME_BLUEPRINT.md — the master plan for every game this factory makes

**Read order: [AGENTS.md](AGENTS.md) → [factory.json](factory.json) (which market) →
[markets/&lt;selected&gt;.md](markets/) (store facts) → this file (what to build) →
[PLAYBOOK.md](PLAYBOOK.md) (how) → [LESSONS.md](LESSONS.md) (56 binding rules).**

This file is **market-agnostic**. Anything specific to a store ecosystem — listing limits, billing
SDKs, compliance, language, cultural design — lives in a market module and nowhere else. The
default market is **international (English-first)**; nothing here assumes a locale.

Everything below was learned the expensive way shipping a real game: user rejections, a 14-agent
adversarial audit, a 19-agent design panel, and store research. **Do not re-derive it.**

---

## 0. The one-paragraph brief

An AI agent designs, builds, tests and packages complete offline-capable mobile games end to end.
The human is involved at exactly two gates: **concept approval** and **milestone testing**. Every
game must be learnable in seconds, become genuinely hard, and give a reason to return *tomorrow*
that is not the core loop itself. Which stores it targets, which language it speaks and which
cultural hook it uses all come from the selected market module — read
[`factory.json`](factory.json) first, then [`markets/`](markets/).

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

## 3. The cultural / identity hook — how to pick one

> Market-specific hooks (and whether the market expects one at all) are defined in
> [`markets/<selected>.md` §9](markets/). The international default expects **no** cultural
> hook — there the differentiator must come from mechanics, presentation or meta-game instead.
> What follows is the method, plus the worked example that produced it.

Worked example (Iran module): **فال حافظ**. Finish the daily challenge → receive that day's real Hafez verse with a
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

**For an international game**, the equivalent of a cultural hook is a **signature mechanic or
ritual that is yours**: a daily artifact the player keeps, a collection that cannot be restarted
elsewhere, a shared-with-everyone moment. Same structural properties, no locale required.

**Rules**
- If a market module names cultural material, treat it as **content with provenance**, not decoration.
- **Verify every quoted real-world text (poetry, quotes, history) with ≥2 independent sources**
  before shipping (LESSONS L19). In the worked example 39 of 103 candidates failed and were dropped.
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
- **No gacha, no loot boxes, no randomised paid rewards.** Some markets ban gambling-style
  monetisation outright with no loot-box carve-out, and others require odds disclosure — selling
  fixed, known quantities is compliant everywhere and is simply the honest option. Check
  [`markets/<selected>.md` §7](markets/).
- **Nothing pay-to-win** and nothing that affects a shared/competitive board.
- **The ritual content is never for sale** — ship a test that asserts no catalogue entry grants it.
- Some stores freeze the free-vs-paid choice at publish (see the market module §7). Publishing free with IAP keeps every option open.
- Consumables **must be `consume`d** after purchase or the store reports "already owned" and the
  SKU can never be bought again.

**Store billing (the reusable pattern — the SDKs themselves are in the market module §7)**
- Put billing behind an abstraction (`scripts/iap.gd`) that reports `available() == false` when the
  plugin or key is missing, and **hide the money UI** rather than showing dead buttons.
- **Load the store plugin dynamically.** A direct `class_name` reference makes the build fail
  wherever the addon is absent.
- Native plugins require Godot's **Gradle custom build**, not the prebuilt export template. Set
  `compress_native_libraries=true` or the APK balloons (53 MB → 147 MB in one measured case).
- **Consumables must be consumed** or the store reports "already owned" and the SKU can never be
  re-bought — that is what makes repeat purchases work.
- **One build per store.** A store's billing permission must never appear in another store's
  artifact; `pipeline/build_stores.sh` gates each plugin and fails the build on leakage.
- Never vendor a billing library whose licence you cannot verify — write a thin client instead
  (`games/mergedrop/addons/myket` is a worked example of doing exactly that).


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

## 6. Store compliance

**Lives entirely in the market module** — see [`markets/<selected>.md`](markets/) sections 3–6 and
10 for package limits, asset dimensions, listing text limits, permissions, privacy and the ranked
rejection reasons. Nothing store-specific belongs in this file.

What is universal:
- Ship the **smallest** artifact that works, and check its size against the market's cap.
- Every permission needs a written justification, or drop the feature.
- Document every asset's licence; copyright is the most common rejection reason in every market.
- Verify the built artifact rather than trusting the build config — inspect the package.


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

## 10. Standing instructions

- **Default to the international market, English-first.** Only apply a locale's language, calendar,
  billing and cultural design when its market module is selected in `factory.json`.
- The user does not want to be involved except concept approval and milestone testing.
- Every game needs something **no other game in the world has**, and a real reason to choose it.
- Never fork a document to describe a different market — add or edit a market module instead.
- Shop with **infinitely purchasable** items connected to the market's billing SDK.
- **Notifications to bring users back**, like a real app.
- Learn from mistakes; never rediscover them — that is what LESSONS.md and this file are for.
