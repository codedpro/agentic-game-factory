# LESSONS.md — mistake database (append-only)

Every entry: what happened → root cause → **RULE** all future builds must follow.
Read together with PLAYBOOK.md before building any game. Never repeat an entry here.

## L1 — Black screen on emulator (2026-07-25, MergeDrop v1)
Shipped arm64-v8a-only APK; user's PC emulator is x86_64 and its arm translation showed black screen forever.
**RULE:** Test/universal APKs always include `arm64-v8a + armeabi-v7a + x86_64`. Store builds may split per-ABI.

## L2 — Vulkan renderer black screen (2026-07-25, MergeDrop v1)
Godot "mobile" renderer = Vulkan; many emulators and cheap phones have broken Vulkan.
**RULE:** 2D games always use `renderer/rendering_method="gl_compatibility"` (+ `.mobile` override).

## L3 — Taps on the board did nothing (2026-07-25, MergeDrop v1)
A `Panel` under the play area had default `mouse_filter = STOP`, consuming clicks before
`_unhandled_input`. The QA bot called game logic directly, so automation never noticed the game was unplayable.
**RULE:** Input goes through a dedicated transparent Control with `gui_input`; every decorative
Control gets `mouse_filter = MOUSE_FILTER_IGNORE`. QA autoplay must drive the same code path a
finger does (at minimum the same handler the touch layer calls).

## L4 — Half the screen invisible (2026-07-25, MergeDrop v1)
UI hard-coded for exactly 720×1280 with `aspect="keep_width"`; on shorter/wider screens the bottom was cropped.
**RULE:** `stretch/aspect="expand"` + all layout computed at runtime from the real viewport
(`UI.board_metrics()` pattern) + rebuild on `size_changed`. Never hard-code positions to the base resolution.

## L5 — Parse errors hidden until a screen opens (2026-07-25, MergeDrop v2)
`var x := dict.key` fails type inference → parse error, but the script is lazily loaded, so tests
and smoke runs passed while the Play button was broken.
**RULE:** every game ships `tests/test_scripts_load.gd` that recursively `load()`s every .gd and
scene and asserts `can_instantiate()`. Use explicit types when reading Dictionary values (`var x: float = m.top`).

## L6 — GDScript name collisions (2026-07-25)
Helper named `_set()` silently shadowed `Object._set(StringName, Variant)` → whole test script refused to load.
**RULE:** never name members `_set/_get/_ready/_process/...`; watch GUT's "does not extend GutTest" warning — it usually means parse failure, not inheritance.

## L7 — Android export refuses without ETC2/ASTC (2026-07-25)
**RULE:** `textures/vram_compression/import_etc2_astc=true` in every project.godot from day one.

## L8 — AI image models write Western digits (2026-07-25)
Asked gpt-image-1 for Persian digits ۲/۴; got "2"/"4".
**RULE:** for any Persian text in art: generate the art blank, stamp the text with PIL + Vazirmatn.

## L9 — Timeout-killed processes look silent (2026-07-25)
Godot buffers stdout when piped; SIGTERM loses everything, wasting a debug cycle on "no output".
**RULE:** long headless runs redirect to a file (`> log 2>&1`) and are inspected after; use `printerr` for diagnostics.

## L10 — Test framework shipped inside release APK (2026-07-25)
**RULE:** every export preset carries `exclude_filter="addons/gut/*, tests/*"`.

## L11 — "A game" is not just a working mechanic (2026-07-25, user feedback)
v1 had only board + score and the user immediately rejected it as not a real game.
**RULE:** minimum feature bar for every release (see PLAYBOOK "Feature baseline") — tutorial,
settings (sound/music/vibration), goals/progression, achievements, records screen, daily challenge,
undo or comparable mercy mechanic, juice (animations/sfx/floating scores/haptics).

## L12 — Names must be genuinely Persian (2026-07-25, user feedback)
"MergeDrop"/transliterations rejected. Market is Bazaar/Myket.
**RULE:** every game gets a real Persian name (e.g. «بریز و بساز»), Persian APK label
(`package/name`), Persian store listing. Internal ids/folders stay ASCII.

## L13 — Version code discipline (2026-07-25)
Duplicate `version/code` keys nearly shipped a wrong version (last key wins in .cfg).
**RULE:** bump `version/code` on every APK the user might install; grep the preset for duplicate keys after edits.

## L14 — Game modes must differ visibly, not just by seed (2026-07-25, user feedback)
"Daily challenge" that only changed the RNG seed read as identical to normal play.
**RULE:** every mode needs at least two player-visible rule changes (e.g. move limit + preset
obstacles + no undo). If a screenshot of both modes looks the same, the mode doesn't exist.

## L15 — No pressure = boring (2026-07-25, user feedback)
With nothing threatening the player, the game was "easy and will be boring soon."
**RULE:** every game ships a difficulty engine that escalates (rising garbage, shrinking time,
faster spawns...) so every run eventually gets intense and ends. Bot QA must show runs *ending* from pressure.

## L16 — Audio must be layered and dynamic (2026-07-25, user feedback)
A quiet 16s ambient loop + 5 static sfx read as "no music, basic sounds."
**RULE:** music = synced stems mixed by game intensity, normalized loud enough; SFX = tiered by
event importance (chain level), multiple variants, random pitch jitter. Never one flat loop.

## L17 — Flat UI reads as cheap (2026-07-25, user feedback)
Plain colored rectangles = "interface is so basic."
**RULE:** minimum juice bar: animated background, glow/bevel on key elements, particles on
rewards, screen shake on big events, count-up numbers, pulsing CTAs, combo banners.

## L18 — Python urllib is blocked by some API gateways (2026-07-25)
1xai.ir returns 403 to default Python User-Agent; curl works.
**RULE:** always set a browser/curl User-Agent on scripted API calls; on errors, retry with
backoff and print the actual exception (silent `except: return None` wasted a full cycle).

## L19 — Verify cultural/literary content with independent models (2026-07-25)
4 of 21 draft poems failed cross-model authenticity checks and were cut.
**RULE:** any quoted cultural content (poetry, quotes, religious text) ships only after ≥2
independent AI models confirm authenticity. Getting حافظ wrong would destroy user trust permanently.

## L20 — Subagent workflows can hit account spend limits (2026-07-25)
All 8 workflow agents failed with "monthly spend limit"; main session kept working.
**RULE:** when workflows fail on spend limits, fall back to inline work + 1xai multi-model
cross-checks for the "independent perspectives" pattern, and tell the user how to re-enable (claude.ai/settings/usage).

## L21 — Buttons grow past their box and overlap (2026-07-25, MergeDrop v3)
Two half-width menu buttons were positioned side by side with `custom_minimum_size`, but a Godot
Button's minimum size is text + content margins, so the longer Persian labels made them expand and
overlap. Persian labels are longer than the English ones a developer eyeballs.
**RULE:** when hand-positioning a Button, also set `size` and `clip_text = true`, keep content
margins small, and ship `tests/test_layout.gd` — build every screen at 4 aspect ratios and assert
no two laid-out buttons intersect and none leaves the viewport. Verify the guard by deliberately
introducing an overlap once; a layout test that cannot fail is worthless.

## L22 — Emoji in UI text render as tofu (2026-07-25, MergeDrop v3)
Vazirmatn has no emoji glyphs and a FontFile has no automatic fallback, so 🔮/🏆/⚙ and even ↺ ✕ ❖
would have rendered as blank boxes on the phone.
**RULE:** bundle NotoEmoji and set `font.fallbacks = [emoji]` for every UI font; ship
`tests/test_fonts.gd` asserting every character of every localized string, UI symbol, Persian
digit and content file has a glyph in the font or its fallbacks. Probe candidate symbols before
using them — ↺ ✕ ❖ are absent, ⏪ ✖ ۞ are present (۞ is also the more authentic Persian ornament).

## L23 — A PIL screenshot composer doubles as a layout oracle (2026-07-25)
Rebuilding the game's layout math in Python to make store screenshots exposed the overlapping
buttons before any device test, because it applied the same "button width = max(text+margins, box)" rule.
**RULE:** keep `pipeline/make_screenshots.py` mirroring ui_kit.gd constants exactly, and re-render
after any layout change — a screenshot that looks wrong is a layout bug, not a drawing bug. Store
screenshots MUST match the shipped app; update the composer whenever the game's layout changes.

## L24 — Dev tools must not ship (2026-07-25)
`tools/dump_states.gd` and `tools/probe_glyphs.gd` write to absolute host paths.
**RULE:** export presets exclude `addons/gut/*, tests/*, tools/*`.

## L25 — GUT silently skips test files that fail to parse (2026-07-25)
A broken test file made the suite report "All tests passed" while the file never ran.
**RULE:** `tests/test_scripts_load.gd` must recursively load `scripts/`, `tests/` AND `tools/`
and assert `can_instantiate()`. Also: `String.split()` returns PackedStringArray (no `.filter`) —
wrap in `Array(...)`; and multi-line boolean expressions need the operator on the *previous* line.

## L26 — Headless has no clipboard/display features (2026-07-25)
`DisplayServer.clipboard_get()` errors under the headless driver, so a share feature "failed" in CI
while being fine on device.
**RULE:** guard platform features (`DisplayServer.has_feature(...)`) and have tests assert graceful
degradation rather than success when the feature is absent.

## L27 — Independent daily draws repeat far sooner than they feel like they should (2026-07-25)
"A real fal every day" drew independently from 16 verses → a repeat inside ~5 days (birthday
paradox); a per-cycle reshuffle still repeated across cycle boundaries.
**RULE:** for date-seeded daily content, index a fixed shuffled pool with a stride coprime to the
pool size (`ids[(day * stride) % n]`). Any n consecutive days then hit every item exactly once.
Test it over a sliding window, not just one aligned cycle. Also keep the pool big enough that a
full cycle exceeds a season.

## L28 — Store rules that shape the build (Bazaar, verified July 2026)
targetSdk ≥ 32; APK ≤ 150 MB; icon must be a PLAIN square (Bazaar adds radius/shadow) and identical
to the launcher icon; header 720×288 PNG 5:2 ≤1 MB; promo 1152×648 JPG 16:9 ≤1 MB; screenshots ≤1 MB;
Persian short description **≤60 chars**; free-vs-paid is immutable after publish; unnecessary
permissions are a top-4 rejection reason and **copyright is #1** — document every asset's licence.
**RULE:** check these before building store assets, and keep `releases/<slug>/SUBMISSION.md` current.

## L29 — Looping tweens must be bound to the node they animate (2026-07-25, audit)
`create_tween().set_loops()` called on the SCREEN to pulse a per-frame-rebuilt tile leaked one
infinite tween per render; when its target was freed the engine logged "Infinite loop detected".
**RULE:** bind looping tweens to the animated node (`node.create_tween()`), or keep a reference and
`kill()` the previous one. GUT fails tests on unexpected engine errors — treat those as real bugs.

## L30 — Rebuild-on-resize must never carry side effects (2026-07-25, audit)
`relayout()` ended with `if game_over: _show_over()`, and `_show_over()` also *recorded* the game.
Any viewport resize re-recorded it: inflated games_played, duplicate top-10 rows, double coins.
**RULE:** split one-shot progression (`_record_over()`, latched by a bool) from pure rebuilding
(`_build_over_panel()`). Renderers must be idempotent; persistence happens exactly once, and
BEFORE any cosmetic `await` (leaving during the pause otherwise loses the run).

## L31 — Godot's Time helpers are UTC; day boundaries must use the LOCAL date (2026-07-25, audit)
Streak "yesterday" was `unix_time_from_system() - 86400`, so in Iran (UTC+3:30) every session
between 00:00 and 03:29 local compared today with today and silently reset the streak.
**RULE:** derive neighbouring days from the local date string
(`Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system()) - 86400`).
Also: capture a run's day key ONCE at start for missions, but recompute it at game over for
awards, or a run crossing midnight credits the wrong day.

## L32 — Saves must be atomic, and a corrupt save must not wipe progress (2026-07-25, audit)
`if cf.load(PATH) != OK: return` left every field at defaults and the next write made it permanent.
**RULE:** write to `.tmp`, keep the previous file as `.bak`, then rename; on load failure fall back
to `.bak` before defaults. Coalesce frequent writes behind a dirty flag (`save_soon()` +
`call_deferred` flush) — missions were writing the whole config ~12× per tile drop.

## L33 — Multi-touch must track the owning finger (2026-07-25, audit)
Touch handlers ignored `event.index`, so a second finger anywhere on the board moved the aim and
the tile dropped in the wrong column.
**RULE:** store the touch index that began the gesture and ignore every other index until release.

## L34 — Compressed audio breaks byte-based loop math (2026-07-25, plan review)
`stream.loop_end = stream.data.size() / 2` assumes 16-bit PCM. Godot's WAV importer defaults to
**QOA compression**, so that played 7.8 s of a 38.4 s track — ~80% of the music never played — and
it mutated the shared cached resource.
**RULE:** author looping in the `.wav.import` (`edit/loop_mode=1`) and just `load()` the stream.
Never compute sample counts from `data.size()`.

## L35 — Godot's infinite-tween guard is DEBUG-only (2026-07-25, plan review)
An infinite `set_loops()` tween bound to a screen while animating a child that gets freed logs
"Infinite loop detected" in debug — but that guard is inside `#ifdef DEBUG_ENABLED`, so a **release
build hangs**. It survived on the daily game-over screen (the USP path) after two earlier passes.
**RULE:** grep for every `create_tween().set_loops()` after any UI change and confirm each is bound
to the node it animates. Treat debug-only warnings as release-hang candidates, not noise.

## L36 — Store builds and emulator builds need different ABIs (2026-07-25)
Bazaar/Myket accept only armeabi-v7a / arm64-v8a / All, but PC emulators need x86_64 (L1).
**RULE:** ship two presets — a store preset (arm only; 53 MB vs 78 MB here) and an `AndroidTest`
preset with x86_64 for the user's emulator. Never send the store the test APK.

## L37 — Keep signing secrets out of the project (2026-07-25)
`keystore/release_password` sat in plaintext in `export_presets.cfg`.
**RULE:** blank those preset fields and export with `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`
sourced from `tools/secrets/keystore.env`. After any signing change, re-check the certificate
SHA-256 matches previous releases — a different key permanently breaks updates for installed users.

## L38 — Iranian stores mandate in-app privacy + sources (2026-07-25)
Bazaar's #1 and #2 rejection reasons are copyright and privacy. A privacy policy must be reachable
INSIDE the app even when nothing is collected, and «ذکر منابع استفاده شده» is compulsory.
**RULE:** every game ships Settings → حریم خصوصی and Settings → منابع و اعتبارات listing every
asset licence. Also verify export presets set adaptive launcher icons (432² fg/bg), or Android 8+
letterboxes the icon and it stops matching the store icon.

## L39 — A QA script must never write to release artifact paths (2026-07-25)
`check_game.sh` ran `--export-debug "Android"` with no output path, so Godot used the preset's
`export_path` and silently replaced the **release-signed** APK with a debug-signed one. The file
kept its name and looked fine.
**RULE:** debug/QA exports always take an explicit path under `releases/<slug>/debug/`. Before
handing an APK to anyone, verify `apksigner verify --print-certs` shows the RELEASE certificate
SHA-256, not the debug key.

## L40 — NOTIFICATION_APPLICATION_PAUSED must never quit (2026-07-26, design review)
I handled pause like a close request and called `get_tree().quit()`. On Android that fires for an
incoming call, a notification pull, or Home — so any interruption killed the run and, because the
daily challenge is one attempt per day, burned the player's attempt and their streak.
**RULE:** `NOTIFICATION_APPLICATION_PAUSED` → persist only. Only `NOTIFICATION_WM_CLOSE_REQUEST`
may quit. Ideally also snapshot the in-progress run so it can resume.

## L41 — "Everyone plays the identical board" is a claim that needs a test (2026-07-26)
The daily/duel board seeded its RNG deterministically, but `_roll_value()` derived the difficulty
cap from `highest` — so two players on the same seed got DIFFERENT tiles the moment their play
diverged. The share text promised «چیدمان امروز برای همه یکی است»; it was false.
**RULE:** for any shared/seeded board, pre-roll the whole sequence at reset with difficulty keyed
on the DROP INDEX, never on player state, and ship a test that plays the same seed two different
ways and asserts identical tile sequences. Verify the test fails without the fix.

## L42 — Bazaar IAP: what is actually required (2026-07-26, researched)
Official SDK is **Poolakey**; a maintained Godot 4 plugin exists (DexterFstone/godot-poolakey,
Asset Library 3525) which injects an AAR + JitPack dependency — so it **only works with Godot's
Gradle/custom build template**, not the prebuilt one. The RSA public key appears in Pishkhan only
after a release build is uploaded. Consumables must be `consume`d or the store reports
"already owned" and the SKU cannot be re-bought. Bazaar and Myket billing permissions must not
coexist in one APK — ship two builds.
**RULE:** put billing behind an abstraction that reports `available() == false` when the plugin or
key is missing, load the plugin script dynamically (a direct `class_name` reference breaks the
build without the addon), and hide money UI rather than showing dead buttons.

## L43 — Avoid randomised paid rewards on Iranian stores (2026-07-26)
Bazaar's content rules ban gambling/betting outright and publish no loot-box carve-out.
**RULE:** sell fixed, known quantities only — no gacha, no random paid unlocks. Keep the ritual
content (the daily fal) permanently unbuyable so monetisation can never look like paying for luck.

## L44 — Godot's Gradle build ships UNCOMPRESSED native libs by default (2026-07-26)
The first `use_gradle_build=true` APK was **147 MB** against Bazaar's 150 MB cap, while the
prebuilt-template APK of the same game was 53 MB. Cause: `gradle_build/compress_native_libraries=false`
leaves `libgodot_android.so` (~70 MB per ABI) stored, not deflated.
**RULE:** set `compress_native_libraries=true` for store builds and check the APK size after ANY
switch to the Gradle pipeline. Also: `--install-android-build-template` can hang headless — the
equivalent is extracting `export_templates/<ver>/android_source.zip` into `android/build/`, then
`chmod +x android/build/gradlew` (zip extraction drops the execute bit) and writing
`android/.build_version` + `android/.gdignore`.

## L45 — Reminders must back off, not repeat (2026-07-26)
A daily reminder that keeps firing at a player who has stopped playing is the fastest route to an
uninstall and to store complaints.
**RULE:** notification policy lives in pure, unit-tested GDScript separate from the platform binding:
quiet hours (00:00–08:00, none after 22:00), schedule 7 days ahead (the app may never reopen to
re-sync), widen the interval as reminders go unanswered (daily → 2nd day → 3rd → weekly), reset on
play, never nudge someone who already played today, and ship a user toggle + hour picker. Content is
only ever about the player's own state — never promotions.

## L46 — Scheduling a LOCAL hour needs the timezone bias (2026-07-26)
`Time.get_unix_time_from_datetime_string(date) + hour*3600` yields a UTC instant, so a reminder the
player set for 20:00 would have fired at 23:30 in Tehran (UTC+3:30) — inside quiet hours. Same trap
as the streak bug (L31), one layer down.
**RULE:** convert local→epoch as `unix_of(date) + hour*3600 - Time.get_time_zone_from_system().bias*60`,
expose the inverse, and test the ROUND TRIP (`unix_to_local_hour(local_time_to_unix(d, h)) == h`)
plus "the reminder lands at the hour the player picked, in THEIR timezone". Never assert on a UTC
hour when the product promise is a local one.

## L47 — An Android plugin's manifest permissions land in YOUR APK (2026-07-26)
Adding the notification scheduler silently added `SCHEDULE_EXACT_ALARM`, `WAKE_LOCK` and
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` through Gradle manifest merging — permissions I never
called. Unnecessary permissions are one of Bazaar's top rejection reasons.
**RULE:** after adding any Android plugin, run `aapt dump badging` and diff the permission list.
For each new permission either (a) use it somewhere real and user-initiated, or (b) remove the
plugin/feature. Write a per-permission justification into SUBMISSION.md. Here the fix was a
Settings action «یادآوری‌ها نمی‌رسند؟» that requests exact-alarm and battery-optimisation
exemptions — which also solves the real MIUI/Samsung problem of killed alarms.

## L48 — Write platform bindings against the REAL plugin API, never an imagined one (2026-07-26)
`notify.gd`'s first platform half guessed singleton names and a `schedule(id, at, title, body)`
signature. The actual plugin exposes a `NotificationScheduler` node with builder objects
(`NotificationData.new().set_id().set_channel_id().set_delay()`), per-id `cancel()` and no bulk
cancel, and needs `create_notification_channel()` before anything posts.
**RULE:** download and read the plugin's shipped `.gd`/source before writing the binding. Keep the
POLICY layer pure and separately tested so a wrong binding costs a rewrite of ~40 lines, not the
feature. Deterministic notification ids make "no bulk cancel" a non-issue.

## L49 — Godot v2 Android export plugins inject into EVERY Android export (2026-07-26)
Setting `gradle_build/plugins/GodotPoolakey=false` on the Myket preset did nothing: that flag only
governs legacy v1 plugins. A v2 `EditorExportPlugin` adds its AAR — and every permission in that
AAR's manifest — to any Android export while the addon is enabled in the project. The Myket APK
therefore shipped `com.farsitel.bazaar.permission.PAY_THROUGH_BAZAAR`, which Myket rejects.
**RULE:** gate each store plugin inside the vendored `plugin.gd`
(`OS.get_environment("GF_STORE") == "bazaar"` → else return empty arrays from
`_get_android_libraries()`/`_get_android_dependencies()`), export through
`pipeline/build_stores.sh` which sets the variable per preset, and have that script FAIL when a
store's permission or classes leak into the other store's APK (`aapt dump badging` + a dex string
scan). Verify by counting SDK references in both APKs — 349 vs 0 is the proof, not the intent.

## L50 — Myket billing: write the client, don't vendor one (2026-07-26)
Myket ships only a legacy AIDL billing library whose original source files carry **no licence
header and no repo LICENSE**; the one MIT-licensed Godot plugin for Myket still pulls that library
in as a Gradle dependency, so the shipped APK would contain unlicensed code — the exact copyright
exposure that is the #1 store rejection reason.
**RULE:** for Myket, ship a self-authored client (ours: `addons/myket`, MIT, ~250 lines of Java +
a 5-method AIDL declaration + a GDScript face that mirrors the Poolakey API so one `iap.gd` drives
both stores). Keep the plugin source in the repo next to the AAR so licensing is auditable.
Build facts that worked: `org.godotengine:godot:4.7.1.stable` on Maven Central (compileOnly),
compileSdk 36 / minSdk 24 / Java 17 / AGP 8.6.1, `buildFeatures { aidl true }`, reuse Godot's own
`android/build/gradlew` wrapper.

## L51 — EditorExportPreset has no get_name() in Godot 4.7 (2026-07-26)
The documented trick of gating a v2 export plugin on `get_export_preset().get_name()` throws
"Nonexistent function 'get_name'", and the failure is silent in the export log — the AAR is simply
never added and the APK ships without the feature.
**RULE:** gate store plugins on an environment variable set by the build script, and make the
build script PROVE the outcome by inspecting the finished APK (permission present + SDK class
strings counted in the dex), rather than trusting that the gate fired.

## L52 — Panels inside a ScrollContainer silently kill scrolling (2026-07-26, user report)
`UI.panel()` returned a Panel at its default `MOUSE_FILTER_STOP`, so every card in the shop and
treasury ate the touch and the lists refused to scroll. Row-wide invisible Buttons did the same.
**RULE:** decorative controls are `MOUSE_FILTER_IGNORE` (now the default in `UI.panel()`); a button
that spans a list row must be `MOUSE_FILTER_PASS` so the drag still reaches the container. Ship
`tests/test_scrolling.gd`, which builds every screen and fails when anything wide enough to cover a
row consumes input.

## L53 — Godot's WAV importer: loop_mode 1 means DISABLED (2026-07-26, user report)
`edit/loop_mode=1` in the `.import` reads like "on" but the enum is
0=Detect, 1=Disabled, 2=Forward — so the music played once and never again, and the runtime
`loop_mode` was 0 while the import file "said" looping was enabled.
**RULE:** use `edit/loop_mode=2` for looping music, delete `.godot/imported/<file>*` to force the
reimport (editing the .import alone does not), and keep a runtime guard that flips a duplicated
stream to LOOP_FORWARD if it ever arrives unlooped. Verify by printing `stream.loop_mode` — not by
listening once.

## L54 — Offline-first online features (2026-07-26)
A global scoreboard must never be able to break a game that is meant to work offline.
**RULE:** all networking sits in one autoload with best-effort semantics: scores are queued in the
save file (best-per-mode), flushed on the next successful contact, every failure is silent, and the
server URL is overridable via `user://server.txt` so a build never has to be rebuilt to move hosts.
Test BOTH paths headlessly — against a live local server AND against a dead port — and assert the
queue survives, no crash occurs, and the UI still opens. Server: `server/scoreboard.py`, one
process for every game (`/api/<game>/...`), unique nicknames, best-kept-wins so a later worse run
cannot lower a standing rank.
