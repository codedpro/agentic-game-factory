# Third-party components

Everything vendored in this repository keeps its original licence. Nothing with an unclear or
missing licence grant is included — that was a deliberate constraint, because copyright is the
most common rejection reason on the Iranian app stores this game ships to.

| Component | Where | Licence |
|---|---|---|
| Godot Engine 4.7 | build tool (not vendored) | MIT |
| GUT — Godot Unit Testing | `games/mergedrop/addons/gut` | MIT |
| Poolakey Godot plugin (Cafe Bazaar billing) | `games/mergedrop/addons/poolakey` | MIT |
| Notification Scheduler plugin | `games/mergedrop/addons/NotificationSchedulerPlugin` | MIT |
| GMP Shared (helper for the above) | `games/mergedrop/addons/GMPShared` | MIT |
| Vazirmatn font | `games/mergedrop/assets/fonts` | SIL Open Font License 1.1 |
| Noto Emoji font | `games/mergedrop/assets/fonts` | SIL Open Font License 1.1 |

## Written for this project (MIT, © 1xai Games Studio)

| Component | Where | Note |
|---|---|---|
| Myket billing plugin | `games/mergedrop/addons/myket` | Java + AIDL + GDScript, written from scratch. Myket's own billing library ships source files with no licence grant, so it is deliberately **not** used. Full source in `addons/myket/src`. |
| Scoreboard server | `server/` | dependency-free Python |
| Build & QA pipeline | `pipeline/` | headless Godot automation |
| Game code, art, music, SFX | `games/mergedrop` | music and sound effects synthesised with numpy; art generated for this project |

## Poetry

The classical Persian verses in `games/mergedrop/assets/fal/fal.json` (Hafez, Saadi, Rumi,
Khayyam, Ferdowsi, Baba Taher) are centuries old and in the public domain. Each verse was
cross-checked by multiple independent AI models before inclusion; candidates that failed that
check were discarded rather than shipped.
