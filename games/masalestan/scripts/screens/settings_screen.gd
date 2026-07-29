extends Control
## Settings: sound / music / vibration toggles, reset progress, about.

var shell: Control
var data := {}
var _confirming := false


func _ready() -> void:
	relayout()


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	_confirming = false
	var v := UI.vp()
	var cx := v.x / 2.0

	var title := UI.label("⚙ " + I18n.t("settings"), int(clampf(v.y * 0.04, 30, 52)))
	title.position = Vector2(cx - 300, v.y * 0.07)
	title.size = Vector2(600, 64)
	add_child(title)

	var bw := clampf(v.x * 0.7, 250, 380)
	var bh := clampf(v.y * 0.06, 52, 74)
	var y := v.y * 0.22
	var gap := bh + 18

	add_child(_toggle_btn("sound", Store.sound_on, Vector2(cx - bw / 2, y), Vector2(bw, bh)))
	add_child(_toggle_btn("music", Store.music_on, Vector2(cx - bw / 2, y + gap), Vector2(bw, bh)))
	add_child(_toggle_btn("vibration", Store.vibrate_on, Vector2(cx - bw / 2, y + 2 * gap), Vector2(bw, bh)))
	add_child(_toggle_btn("notifications", Store.notify_on, Vector2(cx - bw / 2, y + 3 * gap), Vector2(bw, bh)))
	if Store.notify_on:
		var hb := UI.button("%s: %s" % [I18n.t("notif_time"), I18n.digits(Store.notify_hour) + ":۰۰"],
			int(bh * 0.34), _cycle_hour, Vector2(bw * 0.72, bh * 0.8), Color("3a4160"))
		hb.position = Vector2(cx - bw * 0.36, y + 3 * gap + bh + 8)
		add_child(hb)
		if Notify.available():
			var fx := UI.button("🔔 " + I18n.t("notif_fix"), int(bh * 0.3), Notify.fix_delivery,
				Vector2(bw * 0.72, bh * 0.72), Color("3a4160"))
			fx.position = Vector2(cx - bw * 0.36, y + 3 * gap + bh * 1.9 + 14)
			add_child(fx)

	var reset := UI.button("🗑 " + I18n.t("reset_progress"), int(bh * 0.36), _on_reset,
		Vector2(bw, bh), Color("8a3040"))
	reset.name = "ResetBtn"
	reset.position = Vector2(cx - bw / 2, y + 4.6 * gap)
	add_child(reset)

	# About / privacy / credits — Bazaar requires a privacy policy and a sources
	# section reachable inside the app, even when nothing is collected.
	var info_y: float = y + 5.8 * gap
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(cx - bw / 2, info_y)
	scroll.size = Vector2(bw, maxf(120.0, v.y - info_y - bh - 60))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(bw, 0)
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	var ifs := int(clampf(v.y * 0.017, 13, 21))
	for section in [["about", "about_text"], ["support_contact", "support_text"], ["privacy", "privacy_text"], ["credits", "credits_text"]]:
		var h := UI.label(I18n.t(section[0]), ifs + 3, true, UI.accent())
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.custom_minimum_size = Vector2(bw, ifs * 2.0)
		col.add_child(h)
		var t := UI.label(I18n.t(section[1]), ifs, false, UI.MUTED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t.custom_minimum_size = Vector2(bw, 0)
		col.add_child(t)

	var back := UI.button("↩ " + I18n.t("back"), int(bh * 0.4),
		func(): shell.show_screen("menu"), Vector2(bw * 0.6, bh))
	back.position = Vector2(cx - bw * 0.3, v.y - bh - 40)
	add_child(back)


func _toggle_btn(key: String, state: bool, pos: Vector2, size: Vector2) -> Button:
	var txt := "%s: %s" % [I18n.t(key), I18n.t("on") if state else I18n.t("off")]
	var b := UI.button(txt, int(size.y * 0.36), func(): _flip(key),
		size, Color("3a6a48") if state else Color("3a4160"))
	b.position = pos
	return b


func _flip(key: String) -> void:
	match key:
		"sound": Store.sound_on = not Store.sound_on
		"music":
			Store.music_on = not Store.music_on
			Music.apply()
		"vibration":
			Store.vibrate_on = not Store.vibrate_on
			Sfx.vibrate(40)
		"notifications":
			Store.notify_on = not Store.notify_on
			if Store.notify_on:
				Notify.request_permission()
			Notify.sync()
	Store.save()
	Sfx.play("ui")
	relayout()


## Reminder hour cycles through evening slots people actually notice.
func _cycle_hour() -> void:
	var slots := [9, 12, 15, 18, 20, 21, 22]
	var i := slots.find(Store.notify_hour)
	Store.notify_hour = slots[(i + 1) % slots.size()] if i >= 0 else 20
	Store.save()
	Notify.sync()
	Sfx.play("ui")
	relayout()


func _on_reset() -> void:
	if not _confirming:
		_confirming = true
		var b: Button = get_node("ResetBtn")
		b.text = "❗ " + I18n.t("reset_confirm") + " — " + I18n.t("confirm")
		return
	Store.reset_progress()
	Sfx.play("gameover")
	relayout()


func on_back() -> bool:
	return false
