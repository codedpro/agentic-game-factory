# Third-party components

Everything vendored in this repository keeps its original licence. Nothing with an unclear or
missing licence grant is included — that was a deliberate constraint, because copyright is the
most common rejection reason on the Iranian app stores this game ships to.

| Component | Where | Licence |
|---|---|---|
| Godot Engine 4.7 | build tool (not vendored) | MIT |
| GUT — Godot Unit Testing (© Butch Wesley) | `games/mergedrop/addons/gut` | MIT |
| Godot Poolakey plugin — Cafe Bazaar billing (© 2024 DexterFstone); wraps Cafe Bazaar's own Poolakey SDK | `games/mergedrop/addons/poolakey` | MIT |
| Notification Scheduler plugin (© Godot Mobile Plugins / cengiz-pz) | `games/mergedrop/addons/NotificationSchedulerPlugin` | MIT |
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
Khayyam, Ferdowsi, Baba Taher) are centuries old and in the public domain. Attribution and wording were screened by agreement
between several independent AI models before inclusion, and candidates that failed were discarded
rather than shipped. That is a filter, not scholarship — corrections are welcome via an issue.
Licence details verified July 2026; check for yourself before relying on them.
