extends Control
## Main menu — hero art, the owl companion, and one clear primary action.

var shell: Control
var data := {}


func _ready() -> void:
	Missions.ensure_today()
	Music.set_intensity(0.0)
	relayout()
	Online.fetch_board("rush")   # so the parrot can mention a world rank


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	var v := UI.vp()
	var cx := v.x / 2.0
	var fs := int(clampf(v.y * 0.02, 15, 25))

	_build_backdrop(v)
	var y := _build_chips(v, fs)
	y = _build_hero(v, cx, y, fs)
	y = _build_missions(v, cx, y, fs)
	_build_actions(v, cx, y)   # fills the remaining height rather than leaving a gap


## Painted hero art behind everything, with a scrim so text stays readable on it.
func _build_backdrop(v: Vector2) -> void:
	var art := "res://assets/art/hero_bg.png"
	if ResourceLoader.exists(art):
		var tex := TextureRect.new()
		tex.texture = load(art)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tex)
	var scrim := ColorRect.new()
	scrim.color = Color(UI.bg_color(), 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _chip(icon_name: String, txt: String, color: Color, pos: Vector2, size: Vector2, fs: int) -> void:
	var chip := UI.panel(Color("161b28"), 12)
	chip.size = size
	chip.position = pos
	add_child(chip)
	var ic := UI.icon(icon_name, size.y * 0.56, color)
	ic.position = Vector2(size.x - size.y * 0.78, size.y * 0.22)
	chip.add_child(ic)
	var l := UI.label(txt, UI.fit_font_size(txt, size.x - size.y, fs), true, Color.WHITE)
	l.position = Vector2(6, 0)
	l.size = Vector2(size.x - size.y * 0.9, size.y)
	chip.add_child(l)


func _build_chips(v: Vector2, fs: int) -> float:
	var h: float = fs * 2.2
	var w: float = minf(v.x * 0.27, 165)
	_chip("coin", I18n.digits(Store.coins), UI.GOLD, Vector2(14, 16), Vector2(w, h), fs)
	if Store.streak_count >= 1:
		_chip("streak", I18n.digits(Store.streak_count), Color("ff9d5c"),
			Vector2(14 + w + 8, 16), Vector2(w * 0.76, h), fs)
	if Online.last_rank > 0:
		_chip("rank", I18n.digits(Online.last_rank), Color("7fd8ff"),
			Vector2(v.x - w - 14, 16), Vector2(w, h), fs)
	return 16 + h + 8


## Title, the owl, and a speech bubble that reacts to the player's real state.
func _build_hero(v: Vector2, cx: float, top: float, fs: int) -> float:
	var title := UI.label(I18n.t("title"), int(clampf(v.y * 0.05, 36, 70)))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 8)
	title.position = Vector2(cx - 320, top)
	title.size = Vector2(640, clampf(v.y * 0.072, 52, 90))
	add_child(title)
	var y: float = top + title.size.y

	var best := UI.label("%s: %s" % [I18n.t("best"), I18n.digits(Store.best_score)],
		int(clampf(v.y * 0.022, 16, 28)), true, UI.GOLD)
	best.position = Vector2(cx - 320, y)
	best.size = Vector2(640, fs * 1.7)
	add_child(best)
	y += fs * 2.0

	var line := Char.menu_line()
	var owl_h: float = clampf(v.y * 0.14, 100, 200)
	var owl_w: float = 0.0
	var portrait := Char.portrait(int(line.get("mood", 0)) == Char.Mood.CHEER)
	if portrait:
		var tex := TextureRect.new()
		tex.texture = portrait
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		owl_w = owl_h * 0.95
		tex.size = Vector2(owl_w, owl_h)
		tex.position = Vector2(v.x - owl_w - 10, y)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tex)
		var bob := tex.create_tween().set_loops()
		bob.tween_property(tex, "position:y", tex.position.y - 7, 1.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(tex, "position:y", tex.position.y, 1.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var bw: float = maxf(160.0, v.x - owl_w - 36)
	var bubble := UI.panel(Color("2b3350"), 16)
	bubble.size = Vector2(bw, owl_h * 0.66)
	bubble.position = Vector2(14, y + owl_h * 0.14)
	add_child(bubble)
	var say := UI.label(Char.text(line), fs, false)
	say.name = "OwlSays"          # dialogue: emoji are allowed here, unlike UI chrome
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble.add_child(say)
	return y + owl_h + 8


## Tasks panel: solid plate for contrast, one icon per task, a real progress bar, and a
## button into the history of past days.
func _build_missions(v: Vector2, cx: float, top: float, _fs: int) -> float:
	var mp_w: float = clampf(v.x * 0.92, 300, 552)
	var mfs := int(clampf(v.y * 0.018, 14, 22))
	var head: float = mfs * 2.6
	var row_h: float = mfs * 2.5
	var mp := UI.panel(Color("1a2030"), 18)
	mp.size = Vector2(mp_w, head + row_h * 3 + mfs * 0.7)
	mp.position = Vector2(cx - mp_w / 2, top)
	add_child(mp)

	var hb_w: float = mp_w * 0.38
	var hb := UI.icon_button("history", I18n.t("tasks_history"),
		func(): shell.show_screen("tasks"), Vector2(hb_w, mfs * 1.9),
		Color("232c42"), Color("7fd8ff"))
	hb.position = Vector2(mfs * 0.7, mfs * 0.45)
	mp.add_child(hb)

	var hi := UI.icon("tasks", mfs * 1.4, UI.accent())
	hi.position = Vector2(mp_w - mfs * 2.0, mfs * 0.6)
	mp.add_child(hi)
	# title occupies only the space the button does not, so the two can never collide
	var title_x: float = mfs * 0.7 + hb_w + mfs * 0.6
	var mt := UI.label(I18n.t("missions"),
		UI.fit_font_size(I18n.t("missions"), mp_w - title_x - mfs * 2.4, mfs + 2), true, Color.WHITE)
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mt.position = Vector2(title_x, mfs * 0.5)
	mt.size = Vector2(mp_w - title_x - mfs * 2.4, mfs * 1.9)
	mp.add_child(mt)

	var my: float = head
	for mn in Missions.list_today():
		var done: bool = mn.done
		var pct: float = clampf(float(mn.progress) / maxf(1.0, float(mn.target)), 0.0, 1.0)
		var track := UI.panel(Color("0f131e"), 10)
		track.size = Vector2(mp_w - mfs * 1.6, row_h - mfs * 0.55)
		track.position = Vector2(mfs * 0.8, my)
		mp.add_child(track)
		if pct > 0.0:
			var fill := UI.panel(Color("2e7d5b") if done else UI.accent(), 10)
			fill.size = Vector2(track.size.x * pct, track.size.y)
			fill.position = track.position
			mp.add_child(fill)
		var ic := UI.icon(Missions.icon_for(mn.id), track.size.y * 0.66,
			Color("9fe8c4") if done else Color.WHITE)
		ic.position = Vector2(track.position.x + track.size.x - track.size.y * 0.82,
			track.position.y + track.size.y * 0.17)
		mp.add_child(ic)
		var txt := "%s  (%s/%s)" % [Missions.desc(mn), I18n.digits(mn.progress),
			I18n.digits(mn.target)]
		var row := UI.label(txt, UI.fit_font_size(txt, track.size.x - track.size.y * 1.3, mfs),
			true, Color.WHITE)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		row.add_theme_constant_override("outline_size", 4)
		row.position = Vector2(track.position.x + 10, track.position.y)
		row.size = Vector2(track.size.x - track.size.y * 1.25, track.size.y)
		mp.add_child(row)
		my += row_h
	return top + mp.size.y + clampf(v.y * 0.018, 10, 24)


func _build_actions(v: Vector2, cx: float, top: float) -> void:
	var bw: float = clampf(v.x * 0.7, 250, 380)
	# grow the buttons to consume the space left under the missions panel
	var avail: float = maxf(220.0, v.y - top - 24)
	var bh: float = clampf(avail * 0.2, 54, 96)
	var play := UI.icon_button("play", I18n.t("play"), func(): shell.show_screen("game"),
		Vector2(bw, bh), UI.accent(), Color.WHITE)
	play.position = Vector2(cx - bw / 2, top)
	play.pivot_offset = Vector2(bw / 2, bh / 2)
	add_child(play)
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.03, 1.03), 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# secondary actions on a 2-column grid — icon-led so each is scannable
	var gw: float = (bw - 12) / 2.0
	var gh: float = clampf((avail - bh - 24) / 4.0 - 10, 42, 84)
	var rows := [
		["daily", I18n.t("daily_short"), Color("6fb3ff"), func(): shell.show_screen("game", {"daily": true})],
		["rush", I18n.t("rush"), Color("ff9d5c"), func(): shell.show_screen("game", {"rush": true})],
		["fal", I18n.t("masal"), Color("c39bf5"), func(): shell.show_screen("masal")],
		["board", I18n.t("leaderboard"), Color("7fd8ff"), func(): shell.show_screen("board")],
		["shop", I18n.t("shop"), Color("ffc76f"), func(): shell.show_screen("shop")],
		["records", I18n.t("records"), Color("9fe8c4"), func(): shell.show_screen("records")],
		["settings", I18n.t("settings"), Color("aab4cc"), func(): shell.show_screen("settings")],
		["heart", I18n.t("account"), Color("e08aa8"), func(): shell.show_screen("account")],
	]
	var y: float = top + bh + 14
	for i in rows.size():
		var r: Array = rows[i]
		var b := UI.icon_button(r[0], r[1], r[3], Vector2(gw, gh), Color("232a3d"), r[2])
		b.position = Vector2(cx - bw / 2 + (i % 2) * (gw + 12), y + int(i / 2) * (gh + 10))
		add_child(b)


func on_back() -> bool:
	return false
