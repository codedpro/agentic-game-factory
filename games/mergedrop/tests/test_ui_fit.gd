extends GutTest
## Guards the two failures the user actually hit: labels clipped inside buttons, and
## emoji standing in for icons.

const SCREENS := ["menu", "shop", "records", "fal", "settings", "board", "tasks"]
const REQUIRED_ICONS := ["play", "daily", "board", "fal", "shop", "records", "settings",
	"tasks", "history", "coin", "streak", "rank"]


func before_each():
	Store.first_run = false
	I18n.locale = "fa"


func test_every_required_icon_exists():
	for name in REQUIRED_ICONS:
		assert_true(UI.has_icon(name), "missing icon asset: %s.png" % name)


func test_fit_font_size_actually_fits():
	var long := "چالش روزانه و گنجینه شعر پارسی"
	for w in [120.0, 200.0, 320.0]:
		var s := UI.fit_font_size(long, w, 30)
		var measured: float = UI.font_bold.get_string_size(
			long, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		# Either it fits, or it bottomed out at the readability floor — in which case
		# icon_button() wraps the label instead of letting it overflow.
		assert_true(measured <= w + 1.0 or s <= 11,
			"text still %s px wide in a %s px box at size %s" % [measured, w, s])


func test_fit_font_size_never_returns_absurdly_small():
	assert_gte(UI.fit_font_size("بازی", 300.0, 30), 20, "a short label should keep its size")


func _labels(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Label:
			out.append(c)
		_labels(c, out)


func test_button_labels_are_not_clipped():
	for name in SCREENS:
		get_tree().root.size = Vector2i(720, 1280)
		var sh = load("res://scripts/main.gd").new()
		add_child(sh)
		await wait_process_frames(2)
		sh.show_screen(name)
		await wait_process_frames(3)
		var buttons: Array = []
		_collect_buttons(sh.current, buttons)
		for b in buttons:
			var labels: Array = []
			_labels(b, labels)
			for l in labels:
				if l.text.strip_edges() == "":
					continue
				var w: float = UI.font_bold.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT,
					-1, l.get_theme_font_size("font_size")).x
				var box: float = l.size.x if l.size.x > 0 else b.size.x
				assert_lte(w, box + 2.0,
					"%s: '%s' needs %s px in a %s px label — it will be clipped" %
					[name, l.text, int(w), int(box)])
		sh.free()


func _collect_buttons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_collect_buttons(c, out)


func test_no_emoji_left_in_menu_or_tasks_labels():
	# Icons are image assets now; emoji in a UI label means a missed conversion.
	var emoji := ["🪙", "🔥", "🌍", "🎯", "▶", "🗓", "🔮", "🎨", "🏆", "⚙", "📜", "✅"]
	for name in ["menu", "tasks"]:
		get_tree().root.size = Vector2i(720, 1280)
		var sh = load("res://scripts/main.gd").new()
		add_child(sh)
		await wait_process_frames(2)
		sh.show_screen(name)
		await wait_process_frames(3)
		var labels: Array = []
		_labels(sh.current, labels)
		for l in labels:
			if l.name == "OwlSays":
				continue          # character dialogue, not UI chrome
			for e in emoji:
				assert_false(l.text.contains(e),
					"%s still uses the emoji %s in '%s' — use UI.icon()" % [name, e, l.text])
		sh.free()
