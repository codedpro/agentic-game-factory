# Market: iran

Persian-language Android market served by local storefronts. **Not active by default** — select it
with `"markets": ["iran"]` in [`factory.json`](../factory.json). Everything Persian in this factory
lives in this file; core docs stay market-agnostic.

Proven: «بریز و بساز» (`games/mergedrop`) was built and packaged through this module end to end.

## 1. Stores in this market

| Store | Panel | Notes |
|---|---|---|
| **Cafe Bazaar** (کافه‌بازار) | pishkhan.cafebazaar.ir | The dominant Iranian Android store, ~40–50M users. Start here. |
| **Myket** (مایکت) | developer.myket.ir | Second store, no documented registration or annual fee. Worth doing — it is one extra build. |

Google Play is effectively unavailable to Iranian developers for paid distribution; treat these two
as the market.

## 2. Account & fees

**Human-only.** An agent cannot complete any of this.

- Cafe Bazaar: identity documents (کارت ملی scan, national code, 10-digit postcode). ⚠️ The mobile
  number must be registered to the **same national code**. Email and account type (شخصی/شرکتی) can
  **never** be changed afterwards. Annual fee **400,000 ریال (40,000 تومان)**; you may submit for
  review before paying but cannot publish. A support email different from the developer email is
  mandatory. Publisher review ≤12 h; app review ≤3 business days (Thu/Fri excluded).
- Myket: verification code → تفاهم‌نامه → اطلاعات محرمانه → SMS verification. Reserve the package id
  first. The website field must be a **real site** — Telegram/Instagram links are rejected.

## 3. Package requirements

- APK or AAB. **APK ≤ 150 MB.** ZIP/RAR rejected outright.
- `targetSdkVersion ≥ 32` (Bazaar). **Myket requires ≥ 34 for new apps and updates from 23 Oct 2026.**
- ABIs: `armeabi-v7a`, `arm64-v8a`, or "All". **x86_64 is not accepted** — but PC emulators need it,
  so keep a separate test build (see `pipeline/build_stores.sh`).
- Same signing key forever; losing it makes updates impossible.
- AAB needs Bazaar's offline `bundlesigner` (they refuse to hold your key).

## 4. Store assets

| Asset | Spec |
|---|---|
| Icon | PNG 1:1, ≥512×512, ≤3 MB. **Plain square** — Bazaar adds its own radius and shadow. Must match the launcher icon. |
| Header (تصویر سرصفحه) | PNG, 5:2, ≥720×288, ≤1 MB |
| Promo screenshot | JPG, 16:9, ≥1152×648, ≤1 MB |
| Screenshots | ≥1 (5–6 recommended, max 12), ≤1 MB each |
| Video | Aparat link only, **under 10 minutes** |

Ship **adaptive launcher icons** (432×432 foreground + background) or Android 8+ letterboxes the
icon and it stops matching the store listing.

## 5. Listing text

- App name ≤100 chars but **truncates past 16** on device; must equal the on-device name.
- **Short description ≤60 characters.**
- Persian is expected throughout, including Persian digits (۰۱۲۳۴۵۶۷۸۹).

## 6. Compliance

- **A privacy policy must be reachable inside the app**, even when nothing is collected.
- «ذکر منابع استفاده شده در برنامه‌ها اجباری‌ست» — a sources/credits screen is compulsory.
- Every permission needs a written justification; unnecessary permissions are a top-4 rejection reason.
- Notifications: advertising in notifications is a violation; permission must be requested and
  opt-out always available. Reminder-type notifications are an approved category.
- No ESRB-style widget; scary/violent games need an ESRA rating. Listing must suit 4+.

## 7. Monetisation

- **Cafe Bazaar**: Poolakey SDK. Permission `com.farsitel.bazaar.permission.PAY_THROUGH_BAZAAR`.
  Godot 4 wrapper vendored at `games/mergedrop/addons/poolakey` (DexterFstone, MIT). Requires
  Godot's **Gradle custom build** — no native plugin works with the prebuilt template. The RSA
  public key appears in the panel only after a release build is uploaded.
- **Myket**: legacy AIDL billing. Permission `ir.mservices.market.BILLING`, bind action
  `ir.mservices.market.InAppBillingService.BIND`, package `ir.mservices.market`, plus a `<queries>`
  entry for Android 11+. Myket's own library ships files with **no licence grant** — do not vendor
  it. Use `games/mergedrop/addons/myket` (written for this project, MIT, source included).
- **The two billing permissions must never coexist in one APK** — build one per store.
- **No gacha, loot boxes or randomised paid rewards**: Bazaar bans gambling outright with no
  loot-box carve-out. Sell fixed, known quantities.
- Revenue share ~15% up to ~1B تومان/yr (2021 figure — verify in the panel).
- Free vs paid is **immutable after publish**. Publish free with IAP.

## 8. Localisation

- Persian (fa), **right-to-left**, Persian digits everywhere.
- **Jalali (Shamsi) calendar** — `games/mergedrop/scripts/jalali.gd` does the conversion, formatting
  and Yalda/Nowruz detection.
- Font: **Vazirmatn** (SIL OFL) covers Persian + Latin; bundle **Noto Emoji** as a fallback or
  emoji render as tofu boxes.
- Times are local: Iran is UTC+3:30, so any UTC-based day-boundary logic breaks streaks and
  reminders for everyone playing between 00:00 and 03:29.

## 9. Cultural design

The differentiator is a **living daily ritual**, not a theme skin. Worked example: فال حافظ — the
game gifts a real Hafez verse daily, revealed through a «نیت» (intention) ceremony and collected in
a گنجینه treasury.

Rules that generalise:
- Frame culture **literary, never divinatory** — طالع‌بینی / پیشگویی / سرنوشت are store-risky and cheap.
- **Verify quoted cultural text with ≥2 independent sources/models.** 39 of 103 drafted verses were
  rejected and dropped.
- Earned, not given: gating the ritual behind play turns a utility into a daily loop.
- Unused hooks: شاهنامه, ضرب‌المثل‌ها, Persian music radif, خوشنویسی, بازی‌های محلی, معما و چیستان.
- Seasonal moments worth building for: **شب یلدا (21 Dec)** — the biggest fal night of the year and
  the best store-featuring pitch available — نوروز, چهارشنبه‌سوری.

## 10. Rejection reasons, ranked

1. **Copyright violations** — by a wide margin. Document every asset's licence.
2. Security / privacy violations (missing in-app privacy policy).
3. Technical defects, crashes, incomplete builds.
4. Unnecessary permissions.

## 11. Submission checklist

**Agent-preparable:** signed per-store APKs, icons (incl. adaptive), header, promo, screenshots,
Persian listing text within limits, in-app privacy + credits screens, permission justifications,
licence documentation, `releases/<slug>/SUBMISSION.md`.

**Human-only:** developer accounts and identity documents, the annual fee, the support email,
fetching each store's RSA public key, creating IAP products in the panels, and pressing publish.
