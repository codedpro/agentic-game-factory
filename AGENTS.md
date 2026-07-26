# AGENTS.md — start here

You are the developer. This repository is a **factory**: it contains the procedures, guardrails and
tooling for an AI agent to take a game from concept to a signed, store-ready build without a human
writing code.

## Reading order

1. **This file** — how the factory runs.
2. **[`factory.json`](factory.json)** — what you are building *for*. Read it before anything else.
3. **[`markets/<selected>.md`](markets/)** — the only place store facts live: package limits, asset
   dimensions, listing rules, billing SDKs, compliance, language, cultural expectations.
4. **[`GAME_BLUEPRINT.md`](GAME_BLUEPRINT.md)** — what every game must ship, and why.
5. **[`PLAYBOOK.md`](PLAYBOOK.md)** — how to build it.
6. **[`LESSONS.md`](LESSONS.md)** — 61 numbered rules from real failures. Every one is binding.

## The market switch — the one thing to get right

```jsonc
// factory.json
{ "markets": ["international"] }
```

**The default is `international`, English-first.** Do not add another language, a non-Gregorian
calendar, a locale-specific billing SDK or culture-specific design unless a market module asking
for it is selected.

| If the human says | Set `markets` to | Then read |
|---|---|---|
| nothing about markets | `["international"]` | [markets/international.md](markets/international.md) |
| "for Iran" / "Cafe Bazaar" / "Myket" / "Persian" | `["iran"]` | [markets/iran.md](markets/iran.md) |
| "both" / "worldwide and Iran" | `["international","iran"]` | both, and build one artifact per market |

Changing market = editing `factory.json` and reading a different module. **Never fork a document,
never copy market facts into the blueprint or a game, never assume a locale from a market name.**
If something market-specific will not fit in a module, that is a bug in the split — say so.

## What the human decides, and when

They are involved at exactly two gates:

1. **Concept approval** — show the concept before building.
2. **Milestone testing** — hand over an installable build with what changed and what to test.

Everything between is yours. Account creation, store fees, identity documents, signing-key custody
and pressing "publish" are **human-only** — a market module's §11 lists these explicitly.

## The loop

```
concept → approval → pure logic + tests → screens → assets → feature baseline
        → QA gates → store package → milestone build → feedback → LESSONS.md
```

Quality gates before a human ever sees a build (details in PLAYBOOK §5):

```bash
pipeline/check_game.sh <slug>     # import, unit tests, smoke run, autoplay bot, exports
pipeline/build_stores.sh <slug>   # one artifact per market/store, with leakage checks
```

## Non-negotiables

- **Put all game rules in a pure, scene-free class** so they can be tested headlessly. That single
  decision is why 146 tests run with no display and no device.
- **Platform features hide behind `available()`** — billing, notifications, network. Missing plugin
  means the feature is invisible, never a crash.
- **Renderers are idempotent**; one-shot progression is latched separately.
- **Verify the artifact, not the config.** Inspect the built package; a silent gate failure looks
  exactly like success.
- **Every new failure becomes a numbered rule in LESSONS.md.** That file is the reason the second
  game is cheaper than the first.

## Worked example

`games/mergedrop` is a complete game built through this factory for the Iran market — the reference
implementation for every pattern above. Read it as an example, not as a template to copy verbatim:
its language, calendar and stores come from its market module, not from the factory.
