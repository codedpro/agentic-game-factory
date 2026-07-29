# Submission checklist — «مثلستان» → Cafe Bazaar + Myket

Store rules per [`markets/iran.md`](../../markets/iran.md) (verified July 2026).
**Bold = only you can do it** (identity/payment). Everything else is prepared.

## What is ready in this folder

| Requirement | Spec | Prepared file | Status |
|---|---|---|---|
| Package | APK ≤150 MB, targetSdk ≥32 (Myket: ≥34 from 23 Oct 2026) | `Masalestan-release.apk` (58 MB, v1.0 code 1, targetSdk 36, arm-only) | ✅ |
| Emulator test build | not for stores | `Masalestan-test-emulator.apk` (83 MB, adds x86_64) | ✅ |
| **Bazaar build** | Gradle + Poolakey billing + reminders + leaderboard | `Masalestan-bazaar-iap.apk` (59 MB) — carries `PAY_THROUGH_BAZAAR`, verified: Poolakey present (17 SDK refs), **zero** Myket refs | ✅ |
| **Myket build** | same game, no Bazaar billing | `Masalestan-myket.apk` (59 MB) — carries `ir.mservices.market.BILLING`, verified: our MIT Myket client present, **zero** Poolakey refs | ✅ |
| Signing | same key forever | release keystore, SHA-256 `1269074d…fb242` — **identical to بریز و بساز** (one studio key) | ✅ |
| Launcher icon | adaptive on Android 8+ | `icon_adaptive_fg/bg.png` (432²) bundled | ✅ |
| Store icon | PNG ≥512², ≤3 MB, plain square, = launcher icon | `../../games/masalestan/icon_store_1024.png` | ✅ |
| Header (سرصفحه) | PNG 5:2 ≥720×288 ≤1 MB | `screenshots/header_720x288.png` (226 KB) | ✅ |
| Promo | JPG 16:9 ≥1152×648 ≤1 MB | `screenshots/promo_1152x648.jpg` (151 KB) | ✅ |
| Screenshots | ≥1 (5–6 recommended) ≤1 MB each | `screenshots/01..05_*.jpg` (1080×1920, ≤290 KB) | ✅ |
| Persian name | ≤16 chars on device, = APK label | «مثلستان» (7) — matches `application-label` | ✅ |
| Short description | **≤60 chars** | «بازی کلمات با ضرب‌المثل‌های فارسی؛ هر روز یک مثل تازه» (52) | ✅ |
| Full description | — | `store_listing_fa.md` | ✅ |
| Privacy in-app | mandatory even when nothing is collected | Settings → حریم خصوصی | ✅ |
| Sources/credits | «ذکر منابع» compulsory | Settings → منابع و اعتبارات | ✅ |
| Content rating | listing must suit 4+ | word puzzle, no violence | ✅ |
| IAP products | create per panel, same ids | `iap_products.md` (5 consumables) | **panel step** |

## Permission justifications (write into the panel, one per permission)

`Masalestan-release.apk` declares only `INTERNET`. The store builds declare:

| Permission | Justification |
|---|---|
| `INTERNET` | ثبت اختیاری امتیاز در جدول جهانی؛ بازی بدون اینترنت هم کامل کار می‌کند |
| `POST_NOTIFICATIONS` | یادآوری روزانهٔ بازی که کاربر در تنظیمات روشن می‌کند |
| `RECEIVE_BOOT_COMPLETED` | زمان‌بندی دوبارهٔ یادآوری‌ها پس از روشن شدن دستگاه |
| `SCHEDULE_EXACT_ALARM` | رسیدن یادآوری در ساعت انتخابی کاربر |
| `WAKE_LOCK` | نمایش اعلان در لحظهٔ زمان‌بندی‌شده |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | فقط با دکمهٔ «یادآوری‌ها نمی‌رسند؟» در تنظیمات |
| `PAY_THROUGH_BAZAAR` (فقط بیلد بازار) | خرید درون‌برنامه‌ای از طریق کافه‌بازار |
| `ir.mservices.market.BILLING` (فقط بیلد مایکت) | خرید درون‌برنامه‌ای از طریق مایکت |

## Copyright — Bazaar's #1 rejection reason, pre-cleared

| Asset | Source / licence |
|---|---|
| ضرب‌المثل‌ها و معنی‌ها | Persian folk heritage (public domain); wording + meanings passed a 2-of-3 independent-model consensus (116/118 kept, 113 shipped) |
| Bonus-word dictionary | curated for this project; every word passed a 2-model validity check |
| Vazirmatn / Noto Emoji fonts | SIL OFL 1.1 |
| Godot Engine 4.7 | MIT |
| Music & SFX | generated from scratch (`pipeline/gen_masalestan_audio.py`) — no samples |
| Icon & art | AI-generated for this project + PIL composition; no third-party assets |
| Bazaar billing | Poolakey plugin (DexterFstone, MIT), vendored |
| Myket billing | self-authored MIT client (`addons/myket`), source in repo |

## Human-only steps, in order

1. In Pishkhan: create the app with package `ir.gamefactory.masalestan`, upload
   `Masalestan-bazaar-iap.apk`, paste texts from `store_listing_fa.md`, upload assets.
2. After the first upload, copy the **RSA public key** from the panel into
   `games/masalestan/scripts/iap.gd` (`PUBLIC_KEYS.bazaar`) — then one rebuild.
3. Create the 5 IAP products per `iap_products.md`.
4. Same flow on Myket with `Masalestan-myket.apk` (reserve the package id first;
   website field needs a real site — use `1xai.ir`).
5. Press publish. Review ≤3 business days (Thu/Fri excluded).

**Note on the IAP key:** until step 2's rebuild, purchases show as «خرید بعد از انتشار
در فروشگاه فعال می‌شود» — the shop stays visible with disabled buy buttons by design.
