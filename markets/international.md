# Market: international

**The default market.** English-first, worldwide distribution. Selected automatically unless the
human names another market — see [`factory.json`](../factory.json).

> **Verification status.** Checked against each store's own documentation in **July 2026**. Google
> Play changed a lot in the first half of 2026 (fees, developer verification, billing library).
> Anything still unconfirmed is marked **(unverified)** — treat those as "check the console", not
> as fact.

## 1. Stores in this market

| Store | Reach | When to pick it |
|---|---|---|
| **Google Play** | The default global Android store | Any Android game meant for a general audience. Highest reach, strictest process. |
| **itch.io** | Indie-focused, web + desktop + Android | Free to start, no review queue. The natural first release for a small game and for playtesting. |
| **Steam** | PC/desktop | Only if the game genuinely suits desktop. Has a per-title fee and a review process. |
| **Samsung Galaxy Store** | Secondary Android | Cheap incremental reach; the same APK usually works. Revenue share moved to **80/20 in the developer's favour on 15 May 2025**. |
| ~~Amazon Appstore~~ | **dead** | Amazon **shut down its Android app store on 20 August 2025**. Do not build for it. |
| F-Droid | FOSS Android | Only if the game is fully open-source with no proprietary blobs. |

Default plan for a new game: **itch.io first** (free, instant, real feedback), **Google Play** as the
main release, others opportunistically.

## 2. Account & fees

**Human-only.** An agent cannot create accounts, accept legal terms, pay fees or hold keys.

| Store | Cost | Notes |
|---|---|---|
| Google Play | **US$25, one-time** (not annual) | Card must be in the developer's legal name; **prepaid cards are rejected**. Account type is chosen once: **Personal** (government ID + device verification) or **Organization** (needs a **D-U-N-S number** and a verified website). |
| itch.io | **Free** — no account, listing or per-project fee | Choose a payment mode: direct (your PayPal/Stripe, you are merchant of record and handle VAT) or **itch Payouts** (itch is merchant of record and remits VAT; tax interview required or a **30% US withholding** default applies; **$5** minimum, **7-day** hold, first payout reviewed in **10–14 days**). |
| Steam | **US$100 per title** (Steam Direct), recoupable at **US$1,000** adjusted gross revenue *(recoupment threshold unverified)* | Company/tax identity and a tax interview before payout. Store-presence review **1–5 days** *(unverified)*. |

### The Google Play testing gate — plan around this

Personal accounts **created after 13 November 2023** must run a closed test with **at least 12
testers opted in continuously for 14 days** before the production track unlocks. (Google reduced
this from 20 to 12 on **11 December 2024**.)

- **Organization accounts are exempt** — if the human can register as an organization, this
  single choice removes the biggest scheduling obstacle to shipping.
- The 14 days must be *continuous*; dropping below 12 opted-in testers resets the clock.
- Closed and open testing still work throughout, so the agent can keep building and iterating.

### Android developer verification (from 2026)

Apps must be registered by a verified developer to install on certified devices — enforced
**30 September 2026** in **Brazil, Indonesia, Singapore and Thailand**, global from 2027. Google
states ~99% of Play apps are auto-registered, but **anything distributed outside Play** (a direct
APK download, an itch.io build) must be registered manually. This affects the loose per-store APKs
this factory produces.

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
- **Steam cannot take an Android APK.** A Steam SKU is a new platform target — desktop export,
  keyboard/mouse/gamepad input, windowing and options — not another upload script.

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
  **But do declare what you actually use**: a game with any server call needs
  `android.permission.INTERNET`, or Android blocks it silently (LESSONS L60).

## 7. Monetisation

- **Google Play Billing Library** for IAP; Play enforces a minimum library version on a rolling
  schedule **(verify)**. There is no Godot-official plugin — treat it exactly like the other stores:
  behind [`scripts/iap.gd`](../games/mergedrop/scripts/iap.gd), plugin loaded dynamically, and the
  money UI **shown but disabled with a stated reason** when billing is unavailable — never hidden
  (GAME_BLUEPRINT §4).
- **Service fee**: tiered, lower for the first tranche of annual revenue and for subscriptions
  **(verify current tiers)**.
- **Consumables must be consumed** or the SKU stays owned and cannot be re-bought — same rule
  everywhere.
- Loot boxes/gacha are *permitted* on Play but require **odds disclosure**, and some jurisdictions
  regulate them. This factory's standing rule is to sell fixed, known quantities anyway
  (GAME_BLUEPRINT §4) — simpler, honest, and portable to markets that ban them outright.
- **itch.io**: creator-set revenue share, **0–100%**, default **10%** to itch (taken before
  processor fees). Pay-what-you-want supported.
- **Steam**: standard revenue share with volume tiers *(current tiers unverified)*.

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
privacy policy at a public URL, accepting store agreements, the tax interview, creating IAP
products, taking payouts, and pressing publish.

### itch.io is the one storefront an agent can drive end to end

After a one-time human setup (account, payment mode, **creating the project page**, minting an API
key), `butler` needs no interactive login — so build → upload → publish is fully automatable:

```bash
export BUTLER_API_KEY=...            # from itch.io/user/settings/api-keys
butler push <build> studio/game:android --userversion 1.4.0 --if-changed
butler status studio/game
```

`butler` uploads files to an **existing** page; it cannot create the page. That is the boundary.
