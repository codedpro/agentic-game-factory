# مثلستان (masalestan) — design

**Market:** iran (Bazaar + Myket) · **Language:** fa only · **Engine:** Godot 4.7
**Persian name:** «مثلستان» (7 chars — fits the 16-char device truncation)
**Package id:** `ir.gamefactory.masalestan`

Approved concept (user gate 1, 2026-07-29): آمیرزا-style letter-wheel word game where every
level is a real Persian ضرب‌المثل. Rides the #1 proven Iranian-made genre (آمیرزا 10M+ installs,
most-installed game on Cafe Bazaar) with a cultural USP no incumbent has: proverbs as the
content spine + the factory's daily-ritual muscle.

## Core loop — «سفرِ مثل» (campaign)

- A level = one proverb. Its content words (2–5 letters) are the hidden targets.
- Letter wheel at the bottom holds exactly the letters needed (5–8 unique letters).
  Drag (or tap-sequence) through letters to form a word; release submits.
- Found target words fill the proverb's blanked slots. All targets found → the proverb
  assembles word-by-word (animation) → **proverb card**: full text, معنی, and a short
  ریشه/کاربرد note → collected into the گنجینهٔ مثل‌ها.
- Valid Persian words from the wheel that are *not* targets pay coins (the «کوزهٔ واژه» jar,
  once per word per level).
- Mercy mechanics: free wheel shuffle; hint = reveal one letter of an unsolved word (coin
  consumable); no move limit, campaign is zen.

## Mode 2 — «مسابقه» (rush) — the difficulty engine [L14][L15]

Visible rule differences from campaign (≥2 required):
1. **Countdown timer** — starts 90s; each solved word adds time; the bonus shrinks every
   solved proverb (escalating pressure until the run *ends* — bot QA must show runs dying).
2. **No hints** — consumables disabled.
3. **Combo chain** — consecutive solves within N seconds multiply score; chain banner.
Score → global leaderboard (`/api/masalestan/rush`).

## Daily ritual — «مثلِ امروز» [the cultural hook]

- Date-seeded via stride walk over a fixed shuffled pool (stride coprime to pool size,
  L27); the same proverb for the whole country; one attempt/day; interrupted runs resume
  from snapshot (L40 — pause persists, never quits).
- Completing it reveals the day's proverb card **with its story** — earned, not given —
  plus a Wordle-style spoiler-free share grid (solved-word squares + time + streak) and a
  gift-shaped share card carrying the proverb itself.
- Streak counts the ritual only; streak shield purchasable; Jalali dates everywhere.

## Content

- **Pool:** ≥100 verified proverbs (daily cycle must exceed a season). Fields per entry:
  `id, text, words[] (targets), meaning, note, theme, difficulty`.
- Proverbs are folk heritage (no copyright), but wording + meanings are **verified by ≥2
  independent models** (L19); rejects dropped. No divinatory framing (market §9).
- **Bonus dictionary:** curated Persian word list (proverb words ∪ common 2–4 letter words),
  conservative — a rejected real word annoys, a fake accepted word embarrasses.
- Letter normalization: آ is distinct from ا; ء-forms avoided in targets; targets are
  single tokens (compounds split at ZWNJ; ZWNJ never appears in a target).

## Feature baseline (blueprint §1 — all mandatory)

Tutorial (first level, 3 steps) · settings (sfx/music/vibration, reminders + hour, privacy,
credits/منابع, reset) · goal ladder + ~10 achievements · records (top-10 rush + campaign
progress + achievements) · daily missions ×3 · mascot: «طوطی» a talking parrot in Persian
miniature style (state-driven speech, priority-ordered) · offline-first leaderboard ·
friend duel by pasteable code (same wheel, compare time/words) · share cards ·
notifications per blueprint §5 · economy per blueprint §4 (hint packs, streak shield,
mission reroll, wheel/card themes; 4 coin packs + supporter tip; ritual never for sale).

## Screens

menu (mascot + daily CTA) · campaign level select (chapter path) · game (wheel + slots) ·
proverb card reveal · rush · treasury/گنجینه (collection by theme chapter) · records ·
shop · settings · account (buy-only, blueprint §4b).

## Reused infra from mergedrop (proven)

ui_kit, i18n (strings rewritten), jalali, store (atomic saves), missions, economy, iap
(Poolakey/Myket dual build), notify, online, share, account/purchases, sfx/music autoloads,
test scaffolding (scripts_load, fonts, layout, ui_fit, scrolling), build_stores.sh flow.

## QA gates

Standard playbook §5 + game-specific: dictionary integrity test (every target composable
from its wheel; no duplicate letters shortage), daily fairness test (same seed → identical
puzzle regardless of play order), stride-cycle test over sliding windows, rush-pressure bot
test (runs must end), share-grid spoiler test (grid never contains the proverb text).
