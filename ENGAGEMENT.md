# ENGAGEMENT.md — innovation & retention plan for «بریز و بساز»

## The USP (shipped in v3): فال حافظ + گنجینه شعر
**The claim no other game can make:** «تنها بازی‌ای که هر روز یک فال حافظ واقعی به تو هدیه می‌دهد»
*(the only game that gifts you a real Hafez fortune every day).*

Why it's undeniable for the Bazaar/Myket audience: فال حافظ is a living daily ritual in Iran
(Yalda night, fortune cards, streetside fal sellers). No merge/puzzle game — Iranian or global —
ties gameplay to it. It creates a *reason to open the game every single day that isn't about the puzzle*.

Mechanics shipped:
- Finish the daily challenge (۶۰ moves, date-seeded stones, same for the whole country) → receive
  **today's فال** — same poem for everyone that day = shared ritual, water-cooler effect.
- Endless-mode goal milestones unlock famous verse cards → **گنجینه (treasury)** collection screen.
- **80 verses** (56 Hafez + Saadi/Rumi/Khayyam/Ferdowsi/Baba Taher), each **cross-verified by a
  2-of-3 consensus of independent models** — 39 of 103 drafted candidates were rejected and dropped.
  Never ship an unverified poem (trust is the product).
- The daily fal walks a fixed shuffled pool with a **stride coprime to the pool size**, so every
  56-day window shows each Hafez verse exactly once — no repeats for ~2 months.

## Retention loops shipped in v3
1. **Ritual loop (daily):** daily challenge → فال + streak counter (🔥 روزهای پیاپی) + 3 daily missions.
2. **Economy loop:** missions/achievements → coins → theme shop (4 tile palettes) → visible personalization.
3. **Skill loop:** level pressure (garbage rows, stones) makes every run tense; goal ladder + treasury poems reward mastery.
4. **Sensory loop:** two-stem music that intensifies with level, chain-tiered SFX with pitch variation,
   particles, screen shake, combo banners, danger pulse, animated backgrounds.

## Shipped since (v3.3)
- **Share cards** (biggest growth gap per research): clipboard-first «کپی و ارسال فال» gift card,
  and a Wordle-style daily result grid — everyone plays the identical date-seeded board, so the
  comparison is meaningful. No permissions, no backend; Android share sheet attempted best-effort.
- **Persian (Jalali) calendar** everywhere, with Yalda/Nowruz greetings on the fal card.
- Streak now counts the RITUAL (daily challenge completed), is visible from day one, and survives
  the UTC/local midnight bug.

## Shipped in v4 — engagement & economy

**چالش دوستانه (offline friend duel)** — the acquisition mechanic the research said was missing.
A challenge is a 12-character code (`BB-XXXX-XXXX-XXXX`) carrying the board seed *and* the
challenger's score, so the comparison resolves entirely on-device: no server, no account, no
permissions. The friend plays the identical 60-move board and sees «بردی!»/«این بار دوستت برد»,
then sends their own result back — the loop repeats by itself. The menu reads the clipboard on
open and offers the challenge, because a "paste your code here" screen is where this feature
normally dies. Codes use a Crockford alphabet (no I/L/O/U), carry a checksum and a version tag,
so a mistyped or forwarded-and-mangled code is rejected instead of starting a bogus duel.

**Shop with genuinely repeatable purchases** (`economy.gd` + `iap.gd`):
- Real money → **coin packs** and a repeatable **«حمایت از بازی»** supporter tip (stacking ❤ badge).
- Coins → four **unlimited consumables**: بستهٔ برگرد (+3 undos), سپر روزهای پیاپی (protects the
  streak through one missed day), کلید گنجینه (unlocks one treasury verse), تعویض مأموریت.
- Coins → one-off cosmetics: 4 tile themes + 4 فال-card frames.
- **Nothing is pay-to-win and the daily فال is never purchasable** — the ritual stays earned.
  A test asserts no catalogue entry can grant it.
- Billing is behind an abstraction: with no store plugin present `IAP.available()` is false, the
  real-money tab simply doesn't render, and the game stays fully playable offline.

## Shipped in v4.0 — the تفأل ritual itself

**نیت (intention) ceremony.** The daily fal is no longer a popup. You choose what is on your mind
(کار و درس / دل و عشق / سلامتی / سفر / یک تصمیم / همین روزم), then **press and hold** the closed
divan while a gold bar fills, with a faint haptic pulse — and it opens with light and particles.
This mirrors the real act of تفأل, where the intention comes before the book is opened.

**دفتر فال (the ledger).** Every fal you receive is recorded with its Jalali date and the intention
you held. When a verse returns to you months later the card says so: «این بیت پیش‌تر هم به تو رسیده
بود — ۳ مرداد ۱۴۰۵». Over a year the ledger becomes a diary of what you were thinking about, which
is the kind of thing a player cannot get back if they uninstall.

**Fairness the claim depends on.** Shared boards (daily + duel) now pre-roll their entire tile
sequence from the seed with difficulty keyed to the drop index. Previously the pool widened with
YOUR biggest tile, so two players on the "identical" board diverged as soon as they played
differently — the promise «چیدمان امروز برای همه یکی است» was false. A test now plays one seed two
different ways and asserts the sequences match.

## Shipped in v4.1 — reminders that bring players back

Local reminders (no server, no push). The **policy is pure, unit-tested GDScript**; the OS
scheduling sits behind `Notify.available()` so desktop/CI builds simply schedule nothing.

Three messages, all about the player's own state — never promotions:
1. **Gentle nudge** at a user-chosen hour (default ۲۰:۰۰): «فال امروزت منتظر توست ✨»
2. **Streak warning** when the streak is ≥۳ and today is unplayed — and it knows if they own a
   shield: «سپر داری، ولی حیف است خرجش کنی».
3. **Comeback** wording after several days away: «گنجینه‌ات منتظر توست».

The rules that keep this from becoming spam (all tested):
- Quiet hours 00:00–08:00, nothing after 22:00.
- Scheduled **7 days ahead**, because the app may never reopen to re-sync.
- **Backs off when ignored**: daily → every 2nd day → every 3rd → weekly. Playing resets it.
- Never nudges someone who already played today.
- Settings toggle + hour picker; on by default, one tap to silence.

## Roadmap (not yet built)
- **v3.x polish:** share-a-fal as an IMAGE (currently text), poem-of-the-week notification,
  seasonal Yalda/Nowruz fal sets, more verified poems (target 150+).
- **Season engine (چله / مهرگان / یلدا)** — the design panel's top recommendation and the next
  build: a dated سفره of N nights, each daily challenge lights one, cumulative (never consecutive)
  milestones, two «شب مهمان» makeup tokens, earned-only seasonal themes/frames/verses. Prove it on
  مهرگان (۱۰–۱۶ مهر ۱۴۰۵ / 2–8 Oct 2026) so the engine is debugged and installed before یلدا.
- **Resume an interrupted run** (`user://run.cfg`) so a phone call never costs the day's attempt.
- **محفل (pass-the-phone hot-seat)** with a persistent friend-group table — offline دورهمی play.
- **فال به نیت دوست** — take a fal on someone else's behalf, name-seeded so they can verify it.
- Weekly country-wide leaderboard (needs a small backend), Bazaar leaderboard APIs.
- **v4 content:** more themes (سنتی/کاشی‌کاری palette), board skins, tile merge trails,
  AI-generated (build-time) miniature art backgrounds for poem cards.
- **Monetization (only after retention proves out):** cosmetic themes via Bazaar IAP (Poolakey),
  optional "حامی بازی" supporter pack. Never pay-to-win, never ads-on-fal.

## KPIs to watch after launch
D1 retention ≥ 35%, D7 ≥ 15% (casual benchmarks); daily-challenge participation ≥ 50% of DAU;
fal-screen open rate; streak length distribution; theme purchase rate.
