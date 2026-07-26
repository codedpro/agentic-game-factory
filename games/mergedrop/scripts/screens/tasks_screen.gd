extends Control
## Task history — today plus the days behind it, so progress feels cumulative rather than
## resetting to nothing every morning.

var shell: Control
var data := {}


func _ready() -> void:
	relayout()


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	var v := UI.vp()
	var cx := v.x / 2.0
	var fs := int(clampf(v.y * 0.019, 14, 23))
	UI.animate_bg(self, 3)

	var hi := UI.icon("tasks", clampf(v.y * 0.042, 30, 52), UI.accent())
	hi.position = Vector2(cx + 150, v.y * 0.038)
	add_child(hi)
	var title := UI.label(I18n.t("missions"), int(clampf(v.y * 0.034, 25, 44)))
	title.position = Vector2(cx - 300, v.y * 0.035)
	title.size = Vector2(600, 54)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, v.y * 0.115)
	scroll.size = Vector2(v.x - 36, v.y - v.y * 0.115 - clampf(v.y * 0.095, 80, 112))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(v.x - 36, 0)
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	_day_card(col, v.x - 36, fs, I18n.t("tasks_today"), Missions.list_today(), true)

	var past := Missions.history()
	if past.is_empty():
		var empty := UI.label(I18n.t("tasks_history_empty"), fs, false, UI.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(v.x - 36, fs * 3.4)
		col.add_child(empty)
	else:
		for day in past:
			_day_card(col, v.x - 36, fs, _fa_date(str(day.get("d", ""))),
				day.get("items", []), false, int(day.get("done", 0)), int(day.get("total", 0)))

	var bh := clampf(v.y * 0.05, 46, 64)
	var back := UI.icon_button("history", I18n.t("back"), func(): shell.show_screen("menu"),
		Vector2(220, bh), Color("232a3d"), Color("aab4cc"))
	back.position = Vector2(cx - 110, v.y - bh - 20)
	add_child(back)


## Persian date when the Iran market's calendar is in use; ISO otherwise.
func _fa_date(iso: String) -> String:
	var p := iso.split("-")
	if p.size() != 3:
		return iso
	if I18n.locale == "fa":
		return Jalali.format(Jalali.from_gregorian(int(p[0]), int(p[1]), int(p[2])), false)
	return iso


func _day_card(col: VBoxContainer, w: float, fs: int, heading: String, items: Array,
		is_today: bool, done := -1, total := -1) -> void:
	if done < 0:
		done = 0
		for mn in items:
			if mn.get("done", false):
				done += 1
		total = items.size()

	var rows: int = maxi(1, items.size())
	var card := UI.panel(Color("1a2030") if is_today else Color("161b28"), 16)
	card.custom_minimum_size = Vector2(w, fs * 2.4 + rows * fs * 2.1 + fs * 0.8)
	col.add_child(card)

	var h := UI.label(heading, fs + 1, true, UI.accent() if is_today else Color.WHITE)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.position = Vector2(w * 0.35, fs * 0.5)
	h.size = Vector2(w * 0.6, fs * 1.7)
	card.add_child(h)

	var complete: bool = total > 0 and done >= total
	var badge := UI.label(I18n.t("tasks_done_count") % [I18n.digits(done), I18n.digits(total)],
		fs - 3, true, Color("9fe8c4") if complete else UI.MUTED)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.position = Vector2(12, fs * 0.5)
	badge.size = Vector2(w * 0.35, fs * 1.7)
	card.add_child(badge)

	var y: float = fs * 2.4
	for mn in items:
		var id: String = str(mn.get("id", ""))
		var mdone: bool = mn.get("done", false)
		var target: int = int(mn.get("target", 0))
		var progress: int = int(mn.get("progress", 0))
		var pct: float = clampf(float(progress) / maxf(1.0, float(target)), 0.0, 1.0)
		var track := UI.panel(Color("0f131e"), 9)
		track.size = Vector2(w - fs * 1.6, fs * 1.75)
		track.position = Vector2(fs * 0.8, y)
		card.add_child(track)
		if pct > 0.0:
			var fill := UI.panel(Color("2e7d5b") if mdone else Color(UI.accent(), 0.85), 9)
			fill.size = Vector2(track.size.x * pct, track.size.y)
			fill.position = track.position
			card.add_child(fill)
		var ic := UI.icon(Missions.icon_for(id), track.size.y * 0.66,
			Color("9fe8c4") if mdone else Color.WHITE)
		ic.position = Vector2(track.position.x + track.size.x - track.size.y * 0.82,
			track.position.y + track.size.y * 0.17)
		card.add_child(ic)
		var txt := "%s  (%s/%s)" % [Missions.desc(mn), I18n.digits(progress), I18n.digits(target)]
		var l := UI.label(txt, UI.fit_font_size(txt, track.size.x - track.size.y * 1.3, fs),
			true, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		l.add_theme_constant_override("outline_size", 4)
		l.position = Vector2(track.position.x + 10, track.position.y)
		l.size = Vector2(track.size.x - track.size.y * 1.25, track.size.y)
		card.add_child(l)
		y += fs * 2.1


func on_back() -> bool:
	return false
