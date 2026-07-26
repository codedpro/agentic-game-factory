# Market modules

Everything that differs between store ecosystems lives here, and **only** here: store specs,
billing SDKs, listing limits, compliance, localisation and cultural design. The rest of the
factory — [GAME_BLUEPRINT.md](../GAME_BLUEPRINT.md), [PLAYBOOK.md](../PLAYBOOK.md), the pipeline,
the game code — is market-agnostic and reads whichever module is selected.

That is the point: **adding or switching a market means one file, not a rewrite.**

## Selecting a market

The active markets live in [`factory.json`](../factory.json):

```jsonc
{ "markets": ["international"] }   // the default
```

Tell the agent which ecosystem to cover and it sets this field:

| You say | `markets` becomes | Module(s) read |
|---|---|---|
| *(nothing)* | `["international"]` | [international.md](international.md) |
| "target the Iran market" | `["iran"]` | [iran.md](iran.md) |
| "cover both" | `["international", "iran"]` | both |

**The default is international, English-first.** Persian text, Jalali dates, Cafe Bazaar/Myket
billing and Iranian cultural design are *not* applied unless the Iran module is selected — they
live entirely inside [iran.md](iran.md).

When more than one market is active, build one artifact per market rather than one build that tries
to satisfy every rule at once; the store-specific plugin gating in
[`pipeline/build_stores.sh`](../pipeline/build_stores.sh) exists for exactly this.

## Available modules

| Module | Stores | Language default | Status |
|---|---|---|---|
| [international.md](international.md) | Google Play, itch.io, Steam | English | **default** |
| [iran.md](iran.md) | Cafe Bazaar, Myket | Persian | proven — a game shipped through it |

## Adding a market

Copy [`_TEMPLATE.md`](_TEMPLATE.md) to `markets/<name>.md`, fill all 11 sections, add it to
`allowed` in `factory.json`, and add a row to the table above. Do not touch any other document —
if something market-specific has to go elsewhere, that is a bug in the split and belongs in an
issue instead.
