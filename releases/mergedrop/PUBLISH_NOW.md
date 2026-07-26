# Publish «بریز و بساز» — do these in order

Everything below is prepared and verified. Only the steps marked **YOU** need a human.

## The two files to upload

| Store | File | Size |
|---|---|---|
| **Cafe Bazaar** | `MergeDrop-bazaar-iap.apk` | 55.8 MB |
| **Myket** | `MergeDrop-myket.apk` | 55.7 MB |

Both are v5.2 (versionCode 13), signed with the same certificate
(`SHA-256 1269074d…fb242`), arm64-v8a + armeabi-v7a, and verified to contain **only their own
store's billing** — 349 Poolakey references in the Bazaar build and zero in Myket's, and vice versa.

⚠️ **Do not swap them.** Each store rejects an APK carrying the other's billing permission.

## Store assets (in `screenshots/`)

| Asset | File | Meets |
|---|---|---|
| Icon 512×512 | `../../games/mergedrop/icon.png` | plain square, matches the launcher icon |
| Header 720×288 | `screenshots/header_720x288.png` | 5:2, 40 KB |
| Promo 1152×648 | `screenshots/promo_1152x648.jpg` | 16:9, 43 KB |
| Screenshots ×7 | `screenshots/0*.png` | 1080×1920, all under the 1 MB cap (includes `07_shop.png`, the coin packs) |

Screenshots were regenerated from the **current** build, so they match what a reviewer will see.

## Listing text

Copy from `store_listing_fa.md`:
- Name: **بریز و بساز** (11 chars — under the 16-char truncation limit)
- Short description (**≤60 chars**): «هر روز یک فال حافظ + پازل اعتیادآور ادغام اعداد»
- Full description: in the file, updated for v5.2 (leaderboard, task history, the owl).

## Permission justifications — paste these into the panel

| Permission | Justification (Persian) |
|---|---|
| `INTERNET` | ثبت امتیاز در جدول جهانی (بازی بدون اینترنت هم کامل کار می‌کند) |
| `POST_NOTIFICATIONS` | یادآوری روزانهٔ بازی که کاربر خودش در تنظیمات روشن می‌کند |
| `RECEIVE_BOOT_COMPLETED` | زمان‌بندی دوبارهٔ یادآوری‌ها پس از روشن شدن دستگاه |
| `SCHEDULE_EXACT_ALARM` | رسیدن یادآوری در ساعتی که کاربر انتخاب کرده است |
| `WAKE_LOCK` | نمایش اعلان در لحظهٔ زمان‌بندی‌شده |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | فقط با زدن دکمهٔ «یادآوری‌ها نمی‌رسند؟» در تنظیمات |
| `PAY_THROUGH_BAZAAR` / `ir.mservices.market.BILLING` | خرید درون‌برنامه‌ای |

## YOU — Cafe Bazaar

1. Register at **pishkhan.cafebazaar.ir**. ⚠️ Email and account type can never be changed.
2. Identity documents: کارت ملی scan, national code, 10-digit postcode. ⚠️ The mobile number must be
   registered to the **same national code**.
3. Pay the annual fee **400,000 ریال**, and give a **support email different from your developer email**.
4. Upload the APK, paste the listing text, upload icon + header + promo + screenshots.
5. Fill the permission justifications from the table above.
6. Review takes up to **3 business days** (Thursday/Friday don't count).
7. ⚠️ Publish as **free** — free-vs-paid is immutable after publishing.

## YOU — Myket

1. Register at **developer.myket.ir**, reserve the package id `ir.gamefactory.mergedrop`.
2. ⚠️ The website field must be a real site — Telegram/Instagram links are rejected. Use `1xai.ir`.
3. Upload `MergeDrop-myket.apk` with the same listing assets.

## In-app purchases — after the first upload

Both stores only issue the RSA public key once a build is uploaded.

1. Create the **five** products, marked **consumable**, in both panels. Ids, Persian
   categories, Persian + English names, Persian descriptions and suggested prices are all
   ready to copy in **[`iap_products.md`](iap_products.md)**.

2. ✅ **RSA public keys: done.** Both are already in the build and verified in the APKs.
   The buy buttons switch on by themselves as soon as each panel has the five products.

3. **Myket server-to-server key** — kept out of the repo at
   `<tools>/secrets/myket_access_key.txt`. It is only needed if we add server-side receipt
   validation; nothing today reads it, and no build contains it.

## Leaderboard

`mergedrop.1xai.ir` is live and serving. **Keep the server running** — if this machine reboots:

```bash
cd server && PORT=3000 python3 scoreboard.py
```

If it goes down the game simply queues scores and uploads them later; nothing breaks.
