# Market: <name>

> Copy this file to `markets/<name>.md` and fill every section. Adding a market means adding
> **one file** — never editing GAME_BLUEPRINT.md, PLAYBOOK.md or any game. Core docs reference
> markets generically; anything market-specific that leaks into them is a bug.
>
> Keep the section numbering and order identical across modules so the agent can rely on it.

## 1. Stores in this market
Which storefronts, their URLs, rough reach, and when you would pick each.

## 2. Account & fees
What a human must do (identity, payment, contracts), costs, and what an agent cannot do for them.

## 3. Package requirements
Format (APK/AAB/exe), size caps, minimum/target platform versions, ABIs, signing rules.

## 4. Store assets
Icon, screenshots, feature graphic, promo video — exact dimensions, counts and file limits.

## 5. Listing text
Title / short description / full description length limits; required languages; banned wording.

## 6. Compliance
Permissions policy, privacy policy, content rating, data-safety disclosures, age gating.

## 7. Monetisation
IAP SDK and integration path, revenue share, payout, what monetisation is banned here.

## 8. Localisation
Languages, text direction, calendar, number and currency formats, font coverage.

## 9. Cultural design
What makes a game feel native here, and what to avoid. Write "N/A" if the market has no specific
expectation — do not invent one.

## 10. Rejection reasons, ranked
The things that actually get builds rejected, most common first.

## 11. Submission checklist
Split explicitly into **agent-preparable** and **human-only** steps.
