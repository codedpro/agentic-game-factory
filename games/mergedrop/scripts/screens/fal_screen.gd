extends Control
## The USP screen: today's Hafez fal + the poetry treasury (گنجینه).

var shell: Control
var data := {}
var _detail: Control


func _ready() -> void:
	relayout()
	if data.get("show_today", false):
		var today := Time.get_date_string_from_system().replace("-", "")
		if Store.fal_last_date == today:
			_reveal_today()


## Today's fal is opened through the تفأل ceremony the first time; afterwards it just opens.
func _reveal_today() -> void:
	var today := Time.get_date_string_from_system().replace("-", "")
	var poem: Dictionary = Fal.by_id[Fal.daily_id(today)]
	if Fal.logged_today():
		_show_poem(poem, true)
		return
	var ceremony := NiyatCeremony.new()
	ceremony.opened.connect(func(topic):
		Fal.log_fal(poem.id, topic)
		_show_poem(poem, true))
	add_child(ceremony)


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	var v := UI.vp()
	var cx := v.x / 2.0
	UI.animate_bg(self, 4)

	var title := UI.label("🔮 " + I18n.t("fal"), int(clampf(v.y * 0.038, 28, 50)))
	title.position = Vector2(cx - 300, v.y * 0.04)
	title.size = Vector2(600, 58)
	add_child(title)

	var today := Time.get_date_string_from_system().replace("-", "")
	var got_today := Store.fal_last_date == today
	var fs := int(clampf(v.y * 0.02, 15, 25))

	# today's fal card / locked hint
	var card := UI.panel(Color("2c2440"), 20)
	card.size = Vector2(clampf(v.x * 0.88, 300, 540), fs * 6.4)
	card.position = Vector2(cx - card.size.x / 2, v.y * 0.115)
	add_child(card)
	if got_today:
		var lt := UI.label("✨ " + I18n.t("fal_title"), fs + 2, true, UI.GOLD)
		lt.position = Vector2(0, 10)
		lt.size = Vector2(card.size.x, fs * 1.9)
		card.add_child(lt)
		var poem: Dictionary = Fal.by_id[Fal.daily_id(today)]
		var verse1: String = poem.verse.split("\n")[0]
		var pv := UI.label(verse1 + " …", fs, false)
		pv.position = Vector2(10, fs * 2.4)
		pv.size = Vector2(card.size.x - 20, fs * 1.9)
		card.add_child(pv)
		var open_btn := UI.button(I18n.t("fal_title"), fs,
			func(): _show_poem(poem, true), Vector2(card.size.x * 0.5, fs * 2.4), Color("6b4f9e"))
		open_btn.position = Vector2(card.size.x * 0.25, fs * 4.5 - 6)
		card.add_child(open_btn)
	else:
		var hint := UI.label(I18n.t("fal_locked"), fs, false, UI.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.position = Vector2(14, 8)
		hint.size = Vector2(card.size.x - 28, fs * 3.6)
		card.add_child(hint)
		var go := UI.button("🗓 " + I18n.t("daily_short"), fs,
			func(): shell.show_screen("game", {"daily": true}),
			Vector2(card.size.x * 0.5, fs * 2.4), Color("6b4f9e"))
		go.position = Vector2(card.size.x * 0.25, fs * 3.8)
		card.add_child(go)

	# ledger summary
	if Store.fal_log.size() > 0:
		var lg := UI.label("📖 " + I18n.t("ledger_count") % I18n.digits(Store.fal_log.size()),
			fs - 1, false, UI.MUTED)
		lg.position = Vector2(cx - 300, card.position.y + card.size.y - 4)
		lg.size = Vector2(600, fs * 1.8)
		add_child(lg)

	# treasury
	var th := UI.label("📜 %s (%s/%s)" % [I18n.t("treasury"),
		I18n.digits(Fal.collected_count()), I18n.digits(Fal.poems.size())],
		fs + 3, true, UI.GOLD)
	th.position = Vector2(cx - 300, card.position.y + card.size.y + (fs * 1.9 if Store.fal_log.size() > 0 else 14.0))
	th.size = Vector2(600, fs * 2)
	add_child(th)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, th.position.y + fs * 2.4)
	scroll.size = Vector2(v.x - 40, v.y - scroll.position.y - clampf(v.y * 0.1, 80, 120))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(v.x - 40, 0)
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	for p in Fal.poems:
		var got: bool = p.id in Store.fal_collected
		var row := UI.panel(Color("2c2440") if got else Color("1f1c2b"), 12)
		row.custom_minimum_size = Vector2(0, fs * 2.6)
		var txt: String = "📜 %s — %s" % [p.verse.split("\n")[0], p.poet] if got \
			else "🔒 ؟؟؟ — " + I18n.t("treasury_locked_hint")
		var l := UI.label(txt, fs, got, Color.WHITE if got else UI.MUTED)
		l.clip_text = true
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.add_child(l)
		if got:
			var b := Button.new()
			b.flat = true
			b.set_anchors_preset(Control.PRESET_FULL_RECT)
			# PASS, not the default STOP: a row-wide button that consumes the touch means
			# the ScrollContainer never sees the drag and the list refuses to scroll.
			b.mouse_filter = Control.MOUSE_FILTER_PASS
			b.pressed.connect(func(): _show_poem(p, false))
			row.add_child(b)
		col.add_child(row)

	var bh := clampf(v.y * 0.05, 46, 64)
	if Economy.key_is_useful():
		var keys := Economy.count("key")
		var kb := UI.button("🗝 %s (%s)" % [I18n.t("use_key"), I18n.digits(keys)],
			int(bh * 0.36), _on_use_key, Vector2(minf(v.x - 60, 300), bh * 0.9),
			Color("6b4f9e") if keys > 0 else Color("3a4160"))
		kb.position = Vector2(cx - minf(v.x - 60, 300) / 2, v.y - bh * 2.1 - 22)
		add_child(kb)
	var back := UI.button("↩ " + I18n.t("back"), int(bh * 0.42),
		func(): shell.show_screen("menu"), Vector2(200, bh))
	back.position = Vector2(cx - 100, v.y - bh - 22)
	add_child(back)


func _on_use_key() -> void:
	if Economy.count("key") <= 0:
		shell.show_screen("shop")
		return
	var poem := Economy.use_key()
	if poem.is_empty():
		return
	Sfx.play("coin")
	relayout()
	_show_poem(poem, false)


## Returns true when the poem overlay consumed the back press.
func on_back() -> bool:
	if _detail and is_instance_valid(_detail):
		_detail.queue_free()
		_detail = null
		return true
	return false


## Full-screen ornate poem card.
func _show_poem(poem: Dictionary, is_daily_fal: bool) -> void:
	if _detail and is_instance_valid(_detail):
		_detail.queue_free()
	var v := UI.vp()
	_detail = Control.new()
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.z_index = 25
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.09, 0.93)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.add_child(dim)
	add_child(_detail)

	var fs := int(clampf(v.y * 0.023, 18, 29))
	var card := UI.panel(Color("241d38"), 24)
	card.size = Vector2(minf(v.x - 40, 560), clampf(v.y * 0.56, 420, 620))
	card.position = Vector2((v.x - card.size.x) / 2, (v.y - card.size.y) / 2 - 20)
	_detail.add_child(card)
	# ornate double border
	for pad_i in [0, 8]:
		var frame := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(2 if pad_i > 0 else 3)
		sb.border_color = Color(UI.GOLD, 0.85 if pad_i == 0 else 0.4)
		sb.set_corner_radius_all(24 - pad_i)
		frame.add_theme_stylebox_override("panel", sb)
		frame.position = Vector2(pad_i, pad_i)
		frame.size = card.size - Vector2(pad_i * 2, pad_i * 2)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
	# corner ornaments
	for corner in [Vector2(26, 26), Vector2(card.size.x - 26, 26),
			Vector2(26, card.size.y - 26), Vector2(card.size.x - 26, card.size.y - 26)]:
		var d := UI.label("۞", int(fs * 1.1), true, Color(UI.GOLD, 0.7))
		d.position = corner - Vector2(14, 14)
		d.size = Vector2(28, 28)
		card.add_child(d)

	var head := UI.label(("✨ " + I18n.t("fal_title")) if is_daily_fal else "📜 " + poem.poet,
		fs + 4, true, UI.GOLD)
	head.position = Vector2(0, card.size.y * 0.07)
	head.size = Vector2(card.size.x, fs * 2)
	card.add_child(head)

	var occ := Jalali.occasion()
	var date_txt := Jalali.format_today()
	if is_daily_fal and occ != "":
		date_txt = I18n.t(occ) + " — " + date_txt
	var date_lbl := UI.label(date_txt, fs - 5, false, Color(UI.GOLD, 0.75))
	date_lbl.position = Vector2(0, card.size.y * 0.07 + fs * 1.9)
	date_lbl.size = Vector2(card.size.x, fs * 1.3)
	card.add_child(date_lbl)

	var verse := UI.label(poem.verse, fs + 2, true)
	verse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verse.position = Vector2(24, card.size.y * 0.235)
	verse.size = Vector2(card.size.x - 48, card.size.y * 0.265)
	card.add_child(verse)

	var extra := ""
	if is_daily_fal:
		var prev: Array = Fal.previous_dates(poem.id)
		if prev.size() > 0:
			var p := String(prev[prev.size() - 1]).split("-")
			if p.size() == 3:
				extra = I18n.t("verse_returned") % Jalali.format(
					Jalali.from_gregorian(int(p[0]), int(p[1]), int(p[2])), false)
	if extra != "":
		var rl := UI.label(extra, fs - 6, false, Color(Economy.frame_color(), 0.85))
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.position = Vector2(24, card.size.y * 0.5 + fs * 1.5)
		rl.size = Vector2(card.size.x - 48, fs * 2.2)
		card.add_child(rl)

	var poet := UI.label("— " + poem.poet, fs - 2, false, UI.MUTED)
	poet.position = Vector2(0, card.size.y * 0.5)
	poet.size = Vector2(card.size.x, fs * 1.6)
	card.add_child(poet)

	var interp_head := UI.label(I18n.t("fal_interp"), fs - 1, true, UI.accent())
	interp_head.position = Vector2(0, card.size.y * 0.59)
	interp_head.size = Vector2(card.size.x, fs * 1.6)
	card.add_child(interp_head)
	var interp := UI.label(poem.interp, fs - 1, false)
	interp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interp.position = Vector2(24, card.size.y * 0.66)
	interp.size = Vector2(card.size.x - 48, card.size.y * 0.28)
	card.add_child(interp)

	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.7, 0.7)
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	Sfx.play("bigmerge")

	var by := card.position.y + card.size.y + 16
	var share_w: float = minf(v.x - 80, 340)
	var share := UI.button("📤 " + I18n.t("share_fal"), fs - 3, func(): _share(poem),
		Vector2(share_w, fs * 2.4), Color("3a6a48"))
	share.position = Vector2((v.x - share_w) / 2, by)
	_detail.add_child(share)

	var close := UI.button("✖ " + I18n.t("back"), fs - 3, func(): _detail.queue_free(),
		Vector2(180, fs * 2.4))
	close.position = Vector2((v.x - 180) / 2, by + fs * 2.4 + 12)
	_detail.add_child(close)


func _share(poem: Dictionary) -> void:
	Share.share_text(Share.fal_text(poem))
	Sfx.play("coin")
	var v := UI.vp()
	var t := UI.panel(Color("3a6a48"), 14)
	t.size = Vector2(minf(v.x - 60, 460), 60)
	t.position = Vector2((v.x - t.size.x) / 2, v.y - 110)
	t.z_index = 40
	var l := UI.label(I18n.t("copied"), int(clampf(v.y * 0.02, 16, 24)))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(l)
	_detail.add_child(t)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(t, "modulate:a", 0.0, 0.3)
	tw.tween_callback(t.queue_free)
