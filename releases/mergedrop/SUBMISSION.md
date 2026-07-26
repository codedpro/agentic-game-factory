# Submission checklist — «بریز و بساز» → Cafe Bazaar + Myket

Requirements below were researched from Bazaar's developer docs and Myket's knowledge base
(July 2026). **Bold = only you can do it** (identity/payment). Everything else is prepared.

## What is ready in this folder

| Bazaar requirement | Spec | Prepared file | Status |
|---|---|---|---|
| Package | APK or AAB, **max 150 MB**, targetSdk ≥ 32 (Myket: ≥34 from 23 Oct 2026) | `MergeDrop-release.apk` (53 MB, v3.4 code 7, targetSdk 36, **arm-only** — stores reject x86_64) | ✅ |
| Emulator test build | not for stores | `MergeDrop-test-emulator.apk` (78 MB, adds x86_64 so PC emulators run it) | ✅ |
| **Bazaar build** | Gradle build + Poolakey billing + reminders + leaderboard | `MergeDrop-bazaar-iap.apk` (v5.2, code 13) — carries `PAY_THROUGH_BAZAAR` + `INTERNET`, verified to contain Poolakey and **zero** Myket references | ✅ |
| **Myket build** | same game, **no Bazaar billing** | `MergeDrop-myket.apk` (v5.2, code 13) — carries `ir.mservices.market.BILLING` + `INTERNET`, verified to contain **zero** Poolakey references | ✅ |
| Launcher icon | adaptive icon required on Android 8+ | `icon_adaptive_fg.png` + `icon_adaptive_bg.png` (432²) bundled in the APK | ✅ |
| Privacy policy | must be reachable **inside the app** even if nothing is collected | Settings → حریم خصوصی | ✅ |
| Sources/credits | «ذکر منابع استفاده شده در برنامه‌ها اجباری‌ست» | Settings → منابع و اعتبارات | ✅ |
| Signing | same key forever | `<tools>/secrets/release.keystore` (SHA-256 `1269074d…fb242`, password now in `tools/secrets/keystore.env`, no longer in the project file) | ✅ **back this up offsite** |
| Icon | PNG 1:1, ≥512×512, ≤3 MB, **plain square, no pre-rounded corners/shadow**, identical to launcher icon | `../../games/mergedrop/icon.png` (512²), `icon_store_1024.png` | ✅ |
| Header image (سرصفحه) | PNG, ratio 5:2, ≥720×288, ≤1 MB | `screenshots/header_720x288.png` (41 KB) | ✅ |
| Promo screenshot | JPG, 16:9, ≥1152×648, ≤1 MB | `screenshots/promo_1152x648.jpg` (44 KB) | ✅ |
| Screenshots | ≥1, 5–6 recommended, max 12, ≤1 MB each | `screenshots/01..07_*.png` (1080×1920, ≤900 KB each) | ✅ |
| Persian name | ≤100 chars, >16 truncates, **must equal on-device name** | «بریز و بساز» (11 chars) — matches APK label | ✅ |
| Short description | **≤60 chars** | «هر روز یک فال حافظ + پازل اعتیادآور ادغام اعداد» (47) | ✅ |
| Full description | — | `store_listing_fa.md` | ✅ |
| Permissions | every permission needs a written justification; unnecessary ones = top-4 rejection reason | Store build declares **none**. The IAP build adds only `PAY_THROUGH_BAZAAR` (justification: in-app purchases). Reminders will add `POST_NOTIFICATIONS` (justification: the daily play reminder the user switches on in Settings) | ✅ |
| Reminders | local only, user-disablable | Settings → یادآوری toggle + hour picker; no promotional content, backs off when ignored | ✅ |

### Permission justifications (Bazaar requires one per permission)

Only the full-feature build (`MergeDrop-bazaar-iap.apk`) declares any. Write these into the panel:

| Permission | Justification (Persian-ready) |
|---|---|
| `POST_NOTIFICATIONS` | نمایش یادآوری روزانهٔ بازی که کاربر خودش در تنظیمات روشن می‌کند |
| `RECEIVE_BOOT_COMPLETED` | زمان‌بندی دوبارهٔ یادآوری‌ها پس از روشن شدن دستگاه |
| `SCHEDULE_EXACT_ALARM` | رسیدن یادآوری در ساعتی که کاربر انتخاب کرده است |
| `WAKE_LOCK` | نمایش اعلان در لحظهٔ زمان‌بندی‌شده |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | فقط با زدن دکمهٔ «یادآوری‌ها نمی‌رسند؟» در تنظیمات، برای گوشی‌هایی که یادآوری را متوقف می‌کنند |
| `PAY_THROUGH_BAZAAR` | خرید درون‌برنامه‌ای از طریق کافه‌بازار |
| `INTERNET` | ثبت امتیاز در جدول جهانی (بازی بدون اینترنت هم کامل کار می‌کند) |

`MergeDrop-release.apk` declares **no permissions at all** — submit that one if you would rather
launch with neither purchases nor reminders.
| Content rating | must be suitable for 4+; ESRA rating only for scary/violent games | puzzle, no violence | ✅ |
| Video (optional) | Aparat link only, <10 min | not made | — |

## Copyright — Bazaar's #1 rejection reason, pre-cleared

| Asset | Source / licence |
|---|---|
| Poetry (حافظ، سعدی، مولانا، خیام، فردوسی، باباطاهر) | classical public domain; all 80 verses cleared by a 2-of-3 independent-model consensus (39 candidates rejected) |
| Vazirmatn font | SIL OFL 1.1 |
| Noto Emoji font | SIL OFL 1.1 |
| Godot Engine 4.7 | MIT |
| Music & sound effects | generated from scratch by this project (`pipeline/gen_audio_v2.py`) — no samples |
| Icon & art | AI-generated for this project + procedural drawing; no third-party assets |

## In-app purchases (prepared, needs your account to finish)

The shop works today on earned coins alone. Real-money purchases are wired behind an
abstraction and switch on once you complete these steps — **no code changes needed from you**.

**Why it needs you:** Bazaar only issues the RSA public key after a signed release build has
been uploaded to your panel, and only you can create the products.

1. Upload `MergeDrop-release.apk` to Pishkhan → your app → **«پرداخت درون‌برنامه‌ای»**.
2. Create **five** products, marked **consumable**, in BOTH panels. Every field each panel
   asks for — id, Persian category, Persian name, English name, Persian description and a
   suggested price — is ready to copy in **[`iap_products.md`](iap_products.md)**.

3. ✅ **Both RSA public keys are installed.** Bazaar's (1392-bit) and Myket's (1024-bit)
   are compiled into [`scripts/iap.gd`](../../games/mergedrop/scripts/iap.gd) and verified
   present in the shipped APKs. Each build selects its store at runtime by asking which
   native billing singleton exists, so the Bazaar APK never uses Myket's key or vice versa.
   Nothing further is needed from you here — once the five products exist in a panel, the
   buy buttons in that store's build are live.
4. ✅ **The IAP build already exists and is verified**: `MergeDrop-bazaar-iap.apk` (53 MB) is built
   with Godot's Gradle template + the Poolakey plugin, contains
   `com.farsitel.bazaar.permission.PAY_THROUGH_BAZAAR` and the Poolakey classes, and is signed with
   the same release certificate. It behaves identically to the plain build until a key is present:
   the «سکه» tab is always visible and lists every pack, but the buy buttons are disabled above a
   line explaining that purchases are not active yet — no dead button without an explanation. Either
   APK is safe to submit. Submit this one if you want IAP
   ready to switch on; submit `MergeDrop-release.apk` if you prefer to launch without purchases.
5. ✅ **Myket has its own build already** — `pipeline/build_stores.sh mergedrop` produces both and
   **fails if either store's billing leaks into the other's APK**. Nothing for you to do here.

### About the Myket billing client

Myket only publishes a legacy AIDL-based billing library, and that library's own source files
carry **no licence grant** — shipping it (or any Godot plugin that pulls it in) would be exactly
the copyright exposure that is Bazaar's and Myket's top rejection reason. So the Myket client in
this build is **written from scratch for this project** (MIT, source included at
`games/mergedrop/addons/myket/src/`): it binds Myket's documented billing service directly, which
is the integration path Myket's own developer docs describe. No third-party billing code ships.

⚠️ **What is still untestable here:** the purchase dialog itself can only be exercised on a real
device that has Myket (or Bazaar) installed, signed in, with the app published and the products
created. I have verified the plugin compiles, is packaged, declares the right permission and
`<queries>` entry, and that the game degrades cleanly when billing is absent — but the first real
purchase must be tried on your device.

**Deliberately avoided:** no loot boxes, no gacha, no randomised paid rewards. Bazaar bans
gambling-style monetisation and has no published loot-box exemption, so every purchase here is a
fixed, known quantity. Nothing sold affects fairness against other players, and the daily فال can
never be bought.

## Publishing to BOTH stores

Each store rejects an APK that carries the other's billing permission, so the pipeline builds
**one APK per store from one codebase**: `pipeline/build_stores.sh mergedrop` produces all four
artifacts and **fails the build if either store's billing permission leaks into the other's APK**.

| Store | Upload this file | Billing | Verified in the APK |
|---|---|---|---|
| Cafe Bazaar | `MergeDrop-bazaar-iap.apk` (54 MB) | Poolakey | `PAY_THROUGH_BAZAAR`, 349 Poolakey refs, **0 Myket refs** |
| Myket | `MergeDrop-myket.apk` (54 MB) | our own Myket client | `ir.mservices.market.BILLING`, Myket client present, **0 Poolakey refs** |

Use the **same package name** (`ir.gamefactory.mergedrop`), the **same keystore**, and the same
`versionCode` discipline on both. Products are created separately in each panel but keep the same
ids (`coins_small`, `coins_medium`, `coins_large`, `coins_mega`, `supporter_tip`) so one build
serves both.

## Your steps

### Cafe Bazaar
1. Register at **pishkhan.cafebazaar.ir** (password ≥8 chars with an uppercase + a digit).
   ⚠️ The account **email and account type (شخصی/شرکتی) can never be changed** — choose carefully.
2. Upload identity docs: کارت ملی scan (colour, full page), national code, 10-digit postcode, address.
   ⚠️ The mobile number you enter **must be registered to the same national code**.
3. Accept the developer contract, then pay the **annual fee: 400,000 ریال (40,000 تومان)**.
   You may submit for review before paying, but cannot publish until it's active.
4. Provide a **support email different from your developer email** (mandatory).
5. Create the app → upload `MergeDrop-release.apk` → paste listing text from `store_listing_fa.md`
   → upload icon, header, screenshots, promo.
6. Review takes **up to 3 business days** (Thu/Fri don't count); allow ~4 h after approval to appear.

⚠️ Choose **free** now — the pricing model (free vs paid) is **immutable after publishing**, and
paid + in-app purchases cannot be combined.

### Myket
1. Register at **developer.myket.ir** (verification code → تفاهم‌نامه → اطلاعات محرمانه → اطلاعات نمایشی → SMS). No registration or annual fee documented.
2. Reserve the package id `ir.gamefactory.mergedrop` (رزرو شناسه).
3. ⚠️ The website field must be a **real site** — Telegram/Instagram links are rejected. Leave empty if you have none.
4. Review ≤3 business days. **Myket requires targetSdk ≥ 34 for new apps and updates from 23 Oct 2026** — this build is 36.
5. Use the same signed APK and the same keystore as Bazaar.

## After launch
Watch: D1/D7 retention, daily-challenge participation, fal-screen opens, streak length.
Roadmap and next features: `../../ENGAGEMENT.md`.
