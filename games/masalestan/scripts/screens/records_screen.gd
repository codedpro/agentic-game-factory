extends Control
## Records: top-10 scores, today's daily best, achievements list.

var shell: Control
var data := {}


func _ready() -> void:
	relayout()


## Stored dates are ISO ("2026-07-25"); the Persian-only UI shows them as Jalali.
func _fa_date(iso: String) -> String:
	var p := iso.split("-")
	if p.size() != 3:
		return iso
	return Jalali.format(Jalali.from_gregorian(int(p[0]), int(p[1]), int(p[2])), false)


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	var v := UI.vp()
	var cx := v.x / 2.0

	var title := UI.label("🏆 " + I18n.t("records"), int(clampf(v.y * 0.04, 30, 52)))
	title.position = Vector2(cx - 300, v.y * 0.05)
	title.size = Vector2(600, 60)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, v.y * 0.13)
	scroll.size = Vector2(v.x - 48, v.y * 0.72)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(v.x - 48, 0)
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	var fs := int(clampf(v.y * 0.021, 16, 26))
	var head1 := UI.label(I18n.t("top_scores"), fs + 4, true, UI.GOLD)
	col.add_child(head1)

	var today := Time.get_date_string_from_system().replace("-", "")
	if Store.daily_best.has(today):
		var d := UI.label("🗓 " + I18n.t("daily_best_today"), fs, false)
		col.add_child(d)

	if Store.top_scores.is_empty():
		col.add_child(UI.label(I18n.t("empty_scores"), fs, false, UI.MUTED))
	else:
		for i in Store.top_scores.size():
			var e: Dictionary = Store.top_scores[i]
			var row := UI.panel(UI.panel_color(), 12)
			row.custom_minimum_size = Vector2(0, fs * 2.2)
			var l := UI.label("%s.  %s        %s" % [I18n.digits(i + 1), I18n.digits(e.s),
				_fa_date(String(e.d))], fs, i == 0)
			l.set_anchors_preset(Control.PRESET_FULL_RECT)
			row.add_child(l)
			col.add_child(row)

	col.add_child(UI.label(" ", fs, false))
	var head2 := UI.label(I18n.t("achievements"), fs + 4, true, UI.GOLD)
	col.add_child(head2)
	for id in Store.ACH_IDS:
		var got := Store.has_ach(id)
		var row := UI.panel(UI.panel_color() if got else Color("20242f"), 12)
		row.custom_minimum_size = Vector2(0, fs * 2.2)
		var mark := "✅" if got else "🔒"
		var l := UI.label("%s  %s" % [mark, I18n.t("ach_" + id)], fs, got,
			Color.WHITE if got else UI.MUTED)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.add_child(l)
		col.add_child(row)

	var bh := clampf(v.y * 0.055, 48, 68)
	var back := UI.button("↩ " + I18n.t("back"), int(bh * 0.4),
		func(): shell.show_screen("menu"), Vector2(220, bh))
	back.position = Vector2(cx - 110, v.y - bh - 28)
	add_child(back)


func on_back() -> bool:
	return false
