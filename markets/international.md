# Market: international

**The default market.** English-first, worldwide distribution. Selected automatically unless the
human names another market — see [`factory.json`](../factory.json).

> Figures marked **(verify)** move often; confirm in the store's own console before relying on
> them. Everything else is structural and changes rarely.

## 1. Stores in this market

| Store | Reach | When to pick it |
|---|---|---|
| **Google Play** | The default global Android store | Any Android game meant for a general audience. Highest reach, strictest process. |
| **itch.io** | Indie-focused, web + desktop + Android | Free to start, no review queue. The natural first release for a small game and for playtesting. |
| **Steam** | PC/desktop | Only if the game genuinely suits desktop. Has a per-title fee and a review process. |
| Amazon Appstore / Samsung Galaxy Store | Secondary Android | Cheap incremental reach; the same APK usually works. |
| F-Droid | FOSS Android | Only if the game is fully open-source with no proprietary blobs. |

Default plan for a new game: **itch.io first** (free, instant, real feedback), **Google Play** as the
main release, others opportunistically.

## 2. Account & fees

**Human-only.** An agent cannot create accounts, accept legal terms, pay fees or hold keys.

| Store | Cost | Notes |
|---|---|---|
| Google Play | One-time developer registration fee **(verify — historically $25)** | Identity verification required. Personal (non-organisation) accounts have additional pre-launch testing requirements **(verify current rules — these changed recently and are the most common surprise)**. |
| itch.io | Free | Account, then upload. No review. |
| Steam | Per-title **Steam Direct** fee **(verify — historically $100, recoupable after revenue threshold)** | Company/tax details required before payout. |

## 3. Package requirements

- **Google Play requires an AAB** (Android App Bundle), not an APK, for new apps and updates.
  Godot exports AAB from the same Android preset — set the export format accordingly.
- **Target API level**: Play enforces a rolling minimum for new/updated apps **(verify the current
  deadline)**. Godot 4.7's own template targets a recent SDK; check `aapt dump badging` output.
- **Play App Signing**: Google holds the app signing key; you keep an upload key. Losing the upload
  key is recoverable, unlike a self-managed key — a meaningful difference from the Iran market.
- ABIs: `arm64-v8a` + `armeabi-v7a`. `x86_64` is only needed for emulator/testing builds.
- Size: AAB compressed download limits are generous **(verify)** — a small 2D game is nowhere near.
- itch.io/Steam: plain zipped builds; no signing requirement.

## 4. Store assets

| Asset | Google Play | itch.io | Steam |
|---|---|---|---|
| Icon | 512×512 PNG, 32-bit | 315×250 cover recommended | 231×87 capsule + larger variants |
| Feature graphic | 1024×500 | — | header/hero art in several sizes |
| Screenshots | 2–8 per device type, min 320 px on the short side | any | 5+ at 1920×1080 recommended |
| Video | YouTube link | embed | trailer required in practice |

Sizes marked here are the long-stable ones; **verify counts and exact minimums in the console**, and
generate screenshots with `pipeline/make_screenshots.py` so they always match the shipped build.

## 5. Listing text

| Field | Limit |
|---|---|
| Title | 30 characters (Google Play) |
| Short description | 80 characters |
| Full description | 4000 characters |

English is the base language. Add localisations only when you can do them properly — a bad machine
translation reads worse than English to most players.

## 6. Compliance

- **Privacy policy URL is mandatory** on Google Play, even for a game that collects nothing.
- **Data safety declaration**: you must declare what is collected and shared. A fully offline game
  with an optional leaderboard still has to declare the leaderboard's data.
- **Content rating** via the IARC questionnaire; answer it honestly, it is quick.
- **Children/families**: if the game could appeal to children, extra policy applies (ads, data,
  design). Avoid targeting the family category unless you have deliberately designed for it.
- **GDPR/CCPA**: if you collect anything (even a nickname), have a lawful basis and a deletion path.
  The leaderboard in `server/` stores a random install id and a nickname — no personal data — which
  keeps this simple; keep it that way.
- Every Android permission needs justification; declare none unless a feature requires it.

## 7. Monetisation

- **Google Play Billing Library** for IAP; Play enforces a minimum library version on a rolling
  schedule **(verify)**. There is no Godot-official plugin — treat it exactly like the other stores:
  behind [`scripts/iap.gd`](../games/mergedrop/scripts/iap.gd), plugin loaded dynamically, money UI
  hidden when unavailable.
- **Service fee**: tiered, lower for the first tranche of annual revenue and for subscriptions
  **(verify current tiers)**.
- **Consumables must be consumed** or the SKU stays owned and cannot be re-bought — same rule
  everywhere.
- Loot boxes/gacha are *permitted* on Play but require **odds disclosure**, and some jurisdictions
  regulate them. This factory's standing rule is to sell fixed, known quantities anyway
  (GAME_BLUEPRINT §4) — simpler, honest, and portable to markets that ban them outright.
- itch.io: pay-what-you-want or fixed price, with a revenue share you choose. Steam: standard
  revenue share with volume tiers **(verify)**.

## 8. Localisation

- **English (en) is the default and is enough to launch.**
- If you localise, the highest-value additions for a small game are typically the largest mobile
  gaming markets — but only add a language you can maintain, including its store listing.
- Left-to-right, Gregorian calendar, Latin digits, standard number/date formats.
- Font: any Latin font with good coverage. Bundle an emoji fallback if the UI uses emoji —
  see the glyph-coverage test in [`test_fonts.gd`](../games/mergedrop/tests/test_fonts.gd).
- Do not assume a locale from the market. Use `factory.json → languages`.

## 9. Cultural design

**N/A — there is no single "international culture", and pretending otherwise produces bland games.**

The differentiator here must come from **mechanics, presentation or meta-game**, not from a
cultural ritual: a signature twist on the core loop, a distinctive art direction, a daily artifact
the player keeps, or a shared moment everyone experiences at once. See GAME_BLUEPRINT §3 for the
method; it works the same way, only the source material changes.

Avoid: national/religious symbolism used decoratively, humour that depends on one country's
context, and colour choices with strong local meanings you have not checked.

## 10. Rejection reasons, ranked

1. **Policy declarations that do not match the app** — data safety form, permissions, target audience.
2. **Missing or unreachable privacy policy.**
3. **Broken or misleading store listing** — screenshots that do not match the build, keyword spam.
4. **Crashes on review devices**, or a build that does not run on the reviewer's API level.
5. **Intellectual property** — art, fonts, music, or names you cannot prove you may use.

## 11. Submission checklist

**Agent-preparable:** AAB/APK built and verified, icon, feature graphic, screenshots from the real
build, listing text within limits, privacy-policy text, data-safety answers drafted, IARC answers
drafted, permission justifications, release notes, `releases/<slug>/SUBMISSION.md`.

**Human-only:** developer account and identity verification, the registration fee, hosting the
privacy policy at a public URL, accepting store agreements, uploading the build, creating IAP
products, and pressing publish.
