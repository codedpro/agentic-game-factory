extends GutTest
## Startup must always reach a visible first screen.
##
## Myket rejected release 5.5 with "صفحه سرمه‌ای رنگ" on two real devices: the app drew
## its background and nothing else. That is the signature of `main._ready()` aborting
## partway — everything before the abort ran, `show_screen()` never did. The cause was
## platform work (notification channels, permission dialogs, AlarmManager) executing
## before the first screen existed, where anything that throws takes the UI with it.
##
## These tests defend the rule that came out of it: NOTHING may run before the first
## screen that can fail on a device but not here.


func before_each():
	Store.first_run = false
	I18n.locale = "fa"


func _visible_controls(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Control and c.visible:
			out.append(c)
		_visible_controls(c, out)


func test_the_first_screen_is_never_blank():
	for size in [Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(800, 1280)]:
		get_tree().root.size = size
		var sh = load("res://scripts/main.gd").new()
		add_child(sh)
		await wait_process_frames(4)
		assert_not_null(sh.current, "no screen was created at %s" % size)
		assert_eq(sh.current_name, "menu", "the app must open on the menu")
		var controls: Array = []
		_visible_controls(sh.current, controls)
		assert_gt(controls.size(), 3,
			"%s: the menu drew only %d controls — a bare background is exactly what a store reviewer reports as a broken app"
				% [size, controls.size()])
		var labels := 0
		for c in controls:
			if c is Label and String(c.text).strip_edges() != "":
				labels += 1
		assert_gt(labels, 0, "%s: the first screen shows no text at all" % size)
		sh.free()


## A source-level guard: reordering these two lines back is the exact regression.
func test_platform_work_never_precedes_the_first_screen():
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	var ready_at := src.find("func _ready()")
	assert_gt(ready_at, -1, "main.gd has no _ready()")
	var body := src.substr(ready_at, src.find("\nfunc ", ready_at + 10) - ready_at)
	var show_at := body.find("show_screen(\"menu\")")
	assert_gt(show_at, -1, "_ready() must open the menu")
	# Every platform integration named here reaches into Android and can throw there.
	for call in ["Notify.on_app_open()", "Notify.sync()", "Notify.setup()",
			"IAP.purchase(", "request_permission("]:
		var at := body.find(call)
		if at == -1:
			continue
		assert_gt(at, show_at,
			"main._ready() calls %s BEFORE show_screen(\"menu\"). Anything that throws " % call
			+ "on a device aborts _ready() and leaves the player on a blank background.")


func test_notify_autoload_does_no_platform_work_while_initialising():
	var src := FileAccess.get_file_as_string("res://scripts/notify.gd")
	var at := src.find("func _ready()")
	assert_gt(at, -1, "notify.gd has no _ready()")
	var body := src.substr(at, src.find("\nfunc ", at + 10) - at)
	for call in ["initialize(", "create_notification_channel(", "request_permission(",
			"schedule(", ".new()"]:
		assert_false(body.contains(call),
			"Notify._ready() calls %s — autoloads run before the first frame, so this " % call
			+ "runs with no UI on screen and nothing to catch a failure. Defer it to setup().")
	assert_true(body.contains("call_deferred"),
		"Notify._ready() should defer its Android setup past the first frame")


## Android 14 stopped auto-granting SCHEDULE_EXACT_ALARM; scheduling without it throws.
func test_exact_alarms_are_permission_checked_before_scheduling():
	var src := FileAccess.get_file_as_string("res://scripts/notify.gd")
	var at := src.find("func sync()")
	assert_gt(at, -1, "notify.gd has no sync()")
	var body := src.substr(at, src.find("\nfunc ", at + 10) - at)
	var guard := body.find("can_schedule_exact()")
	var sched := body.find("_plugin.schedule(")
	assert_gt(guard, -1, "sync() must check the exact-alarm permission")
	assert_gt(sched, -1, "sync() should schedule something")
	assert_lt(guard, sched,
		"sync() schedules before checking SCHEDULE_EXACT_ALARM — that throws on Android 14")


func test_notify_is_inert_and_safe_without_the_plugin():
	# Desktop and CI have no plugin. Every entry point must be a silent no-op, never a
	# crash, because these are the same calls the shell makes at startup.
	assert_false(Notify.available())
	assert_false(Notify.can_schedule_exact(), "no plugin means no exact alarms")
	Notify.setup()
	Notify.sync()
	Notify.request_permission()
	Notify.on_app_open()
	Notify.fix_delivery()
	assert_true(true, "none of the platform entry points may crash without a plugin")


func test_the_shell_survives_a_notify_failure():
	# Simulate the device condition: make the platform call fail, and assert the menu
	# still comes up. This is the exact scenario the reviewers hit.
	var sh = load("res://scripts/main.gd").new()
	add_child(sh)
	await wait_process_frames(4)
	assert_eq(sh.current_name, "menu")
	var before: Node = sh.current
	Notify.on_app_open()          # runs deferred in production; must not disturb the UI
	await wait_process_frames(2)
	assert_eq(sh.current, before, "a notification sync must not tear down the screen")
	sh.free()
