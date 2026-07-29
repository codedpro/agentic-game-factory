extends Control
## Home — مثلستان's own dashboard (L69: not game #1's shell).
## Structure: ornamental header → the DAILY SCROLL CARD as the hero object (mascot
## perched beside it, speech bubble) → horizontal journey path of level medallions →
## two wide mode buttons → icon dock. Missions are a compact chip, not a panel.

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
	UI.themed_backdrop(self)

	var y := _build_header(v, cx, fs)
	y = _build_daily_card(v, cx, y, fs)
	y = _build_journey(v, cx, y, fs)
	_build_modes_and_dock(v, cx, y, fs)


## Ornamental header band: title flanked by ۞, settings/account at the corners,
## coins + streak chips beneath.
func _build_header(v: Vector2, cx: float, fs: int) -> float:
	var ts := int(clampf(v.y * 0.042, 30, 56))
	var title := UI.label("۞  مثلستان  ۞", ts, true, UI.theme().get("ink", UI.GOLD))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(cx - 300, v.y * 0.022)
	title.size = Vector2(600, ts * 1.4)
	add_child(title)

	var bs := fs * 2.1
	var gear := UI.icon_button("settings", "", func(): shell.show_screen("settings"),
		Vector2(bs, bs), Color(UI.panel_color(), 0.85), Color.WHITE)
	gear.position = Vector2(12, v.y * 0.03)
	add_child(gear)
	var acc := UI.icon_button("heart", "", func(): shell.show_screen("account"),
		Vector2(bs, bs), Color(UI.panel_color(), 0.85), Color("e08aa8"))
	acc.position = Vector2(v.x - bs - 12, v.y * 0.03)
	add_child(acc)

	var chip_y := v.y * 0.022 + ts * 1.5
	var chip_w: float = minf(v.x * 0.24, 150)
	var chip_h := fs * 1.9
	var cxs := cx - chip_w - 6
	_chip("coin", I18n.digits(Store.coins), UI.GOLD, Vector2(cxs, chip_y),
		Vector2(chip_w, chip_h), fs)
	_chip("streak", I18n.digits(Store.streak_count), Color("ff9d5c"),
		Vector2(cx + 6, chip_y), Vector2(chip_w, chip_h), fs)
	if Online.last_rank > 0:
		_chip("rank", I18n.digits(Online.last_rank), Color("7fd8ff"),
			Vector2(cx + chip_w + 18, chip_y), Vector2(chip_w * 0.8, chip_h), fs)
	return chip_y + chip_h + v.y * 0.014


func _chip(icon_name: String, txt: String, color: Color, pos: Vector2, size: Vector2, fs: int) -> void:
	var chip := UI.panel(Color(0, 0, 0, 0.35), 12)
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


## The hero object: today's proverb as a sealed scroll card. The parrot sits beside
## it with a live line; tapping the card starts (or opens) the daily.
func _build_daily_card(v: Vector2, cx: float, top: float, fs: int) -> float:
	var today := Time.get_date_string_from_system().replace("-", "")
	var done := Store.masal_last_date == today
	var card_w: float = minf(v.x - 28, 560)
	var card_h: float = clampf(v.y * 0.21, 150, 220)
	var card := UI.panel(UI.panel_color(), 22)
	card.size = Vector2(card_w, card_h)
	card.position = Vector2(cx - card_w / 2, top)
	add_child(card)
	var frame := UI.panel(Color(0, 0, 0, 0), 22)
	var fsb: StyleBoxFlat = frame.get_theme_stylebox("panel")
	fsb.set_border_width_all(2)
	fsb.border_color = Color(UI.theme().get("ink", UI.GOLD), 0.55)
	frame.position = card.position
	frame.size = card.size
	add_child(frame)

	# mascot perched at the card's left edge, bobbing
	var mh: float = card_h * 0.92
	var portrait := Char.portrait(done)
	var mw := 0.0
	if portrait:
		var tex := TextureRect.new()
		tex.texture = portrait
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		mw = mh * 0.8
		tex.size = Vector2(mw, mh)
		tex.position = Vector2(card.position.x - 8, top - mh * 0.28)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.z_index = 2
		add_child(tex)
		var bob := tex.create_tween().set_loops()
		bob.tween_property(tex, "position:y", tex.position.y - 6, 1.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(tex, "position:y", tex.position.y, 1.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var pad := fs * 0.9
	var tx := mw * 0.55 + pad
	var head := UI.title("daily", I18n.t("daily"), fs + 4,
		Vector2(card_w - tx - pad, fs * 1.8), UI.GOLD)
	head.position = Vector2(tx, pad * 0.7)
	card.add_child(head)

	var date_l := UI.label(Jalali.format_today(false), fs - 2, false, UI.MUTED)
	date_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_l.position = Vector2(tx, pad * 0.7 + fs * 1.9)
	date_l.size = Vector2(card_w - tx - pad, fs * 1.5)
	card.add_child(date_l)

	var line := Char.menu_line()
	var say := UI.label(Char.text(line), fs - 1, false)
	say.name = "OwlSays"          # dialogue: emoji allowed here, unlike UI chrome
	say.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.position = Vector2(tx, pad * 0.7 + fs * 3.4)
	say.size = Vector2(card_w - tx - pad, fs * 3.2)
	card.add_child(say)

	var bw: float = card_w * 0.52
	var bh: float = clampf(v.y * 0.052, 44, 62)
	var cta_text: String = I18n.t("daily_best_today") if done else I18n.t("daily_short")
	var cta := UI.icon_button("daily", cta_text,
		func(): shell.show_screen("masal" if done else "game",
			{"show_today": true} if done else {"daily": true}),
		Vector2(bw, bh), UI.accent() if not done else Color("3a6a48"), Color.WHITE)
	cta.position = Vector2(card_w - bw - pad, card_h - bh - pad * 0.7)
	card.add_child(cta)
	if not done:
		cta.pivot_offset = Vector2(bw / 2, bh / 2)
		var pulse := cta.create_tween().set_loops()
		pulse.tween_property(cta, "scale", Vector2(1.04, 1.04), 0.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(cta, "scale", Vector2.ONE, 0.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# compact missions chip at the card's bottom-left
	var mn_done := 0
	var mn_all := Missions.list_today()
	for mn in mn_all:
		if mn.done:
			mn_done += 1
	var chip := UI.icon_button("tasks", I18n.t("tasks_done_count") %
		[I18n.digits(mn_done), I18n.digits(mn_all.size())],
		func(): shell.show_screen("tasks"),
		Vector2(card_w - bw - pad * 2.4, bh * 0.82), Color(0, 0, 0, 0.3), UI.accent())
	chip.position = Vector2(pad * 0.7, card_h - bh * 0.82 - pad * 0.8)
	card.add_child(chip)
	return top + card_h + v.y * 0.016


## The journey: a horizontal band of level medallions around the player's position.
## Tapping the active one continues the campaign.
func _build_journey(v: Vector2, cx: float, top: float, fs: int) -> float:
	var band_h: float = clampf(v.y * 0.14, 100, 150)
	var band := UI.panel(Color(0, 0, 0, 0.25), 18)
	band.position = Vector2(14, top)
	band.size = Vector2(v.x - 28, band_h)
	add_child(band)
	var head := UI.label(I18n.t("play"), fs + 1, true, Color.WHITE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.position = Vector2(14, 8)
	head.size = Vector2(band.size.x - 28, fs * 1.6)
	band.add_child(head)

	var idx := Store.campaign_index
	var total := Masal.campaign_size()
	var med: float = band_h * 0.44
	var gap: float = med * 0.42
	var count := 5
	var row_w: float = count * med + (count - 1) * gap
	var x0: float = (band.size.x + row_w) / 2.0 - med   # RTL: first at the right
	var my: float = band_h * 0.36
	for k in count:
		var li := idx - 1 + k      # one behind the player, then ahead
		var mx: float = x0 - k * (med + gap)
		var reached := li < idx
		var active := li == idx
		var col: Color = UI.accent() if active else (Color("3a6a48") if reached else Color(0, 0, 0, 0.4))
		var medal := UI.panel(col, int(med / 2))
		medal.position = Vector2(mx, my)
		medal.size = Vector2(med, med)
		band.add_child(medal)
		if li >= 0 and li < total:
			var t := UI.label(I18n.digits(li + 1), int(med * (0.42 if li < 99 else 0.34)),
				true, Color.WHITE if (active or reached) else UI.MUTED)
			t.position = Vector2(mx, my)
			t.size = Vector2(med, med)
			band.add_child(t)
		if active:
			medal.pivot_offset = Vector2(med / 2, med / 2)
			var pw := medal.create_tween().set_loops()
			pw.tween_property(medal, "scale", Vector2(1.1, 1.1), 0.7)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			pw.tween_property(medal, "scale", Vector2.ONE, 0.7)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# the whole band is one big "continue" button
	var go := Button.new()
	go.flat = true
	go.set_anchors_preset(Control.PRESET_FULL_RECT)
	go.mouse_filter = Control.MOUSE_FILTER_PASS
	go.pressed.connect(func(): shell.show_screen("game"))
	band.add_child(go)
	var sub := UI.label("%s / %s" % [I18n.digits(idx), I18n.digits(total)], fs - 2,
		false, UI.MUTED)
	sub.position = Vector2(14, band_h - fs * 1.7)
	sub.size = Vector2(band.size.x - 28, fs * 1.5)
	band.add_child(sub)
	return top + band_h + v.y * 0.016


## Two wide mode buttons + a dock of small destinations.
func _build_modes_and_dock(v: Vector2, cx: float, top: float, fs: int) -> void:
	var avail: float = v.y - top - 20
	var bw: float = minf(v.x - 28, 560)
	var bh: float = clampf(avail * 0.30, 52, 86)
	var half: float = (bw - 12) / 2.0
	var rush_btn := UI.icon_button("rush", I18n.t("rush"),
		func(): shell.show_screen("game", {"rush": true}),
		Vector2(half, bh), Color("7a3b4d"), Color("ffb27f"))
	rush_btn.position = Vector2(cx + 6, top)
	add_child(rush_btn)
	var tre := UI.icon_button("fal", "%s (%s)" % [I18n.t("masal"),
		I18n.digits(Masal.collected_count())],
		func(): shell.show_screen("masal"),
		Vector2(half, bh), Color(UI.panel_color(), 1.0), Color("c39bf5"))
	tre.position = Vector2(cx - half - 6, top)
	add_child(tre)

	var dock_y := top + bh + clampf(avail * 0.06, 8, 18)
	var items := [
		["board", I18n.t("leaderboard"), Color("7fd8ff"), func(): shell.show_screen("board")],
		["shop", I18n.t("shop"), Color("ffc76f"), func(): shell.show_screen("shop")],
		["records", I18n.t("records"), Color("9fe8c4"), func(): shell.show_screen("records")],
	]
	var dw: float = (bw - 24) / 3.0
	var dh: float = clampf(avail * 0.24, 46, 74)
	for i in items.size():
		var it: Array = items[i]
		var b := UI.icon_button(it[0], it[1], it[3], Vector2(dw, dh),
			Color(0, 0, 0, 0.35), it[2])
		b.position = Vector2(cx - bw / 2 + i * (dw + 12), dock_y)
		add_child(b)


func on_back() -> bool:
	return false
