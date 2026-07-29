extends Control
## Gameplay screen — the letter wheel, the proverb slots, three modes:
## campaign («سفرِ مثل‌ها»), daily («مثلِ امروز», one shared attempt) and rush («مسابقه»).

const FREE_HINTS_FIRST_RUN := 3

var shell: Control
var data := {}

var puzzle: Puzzle
var rush: Rush = null
var mode := "campaign"           # "campaign" | "daily" | "rush"
var daily_key := ""
var m := {}
var proverb_root: Control
var preview_root: Control
var wheel_root: Control
var fx_root: Control
var touch_area: Control
var timer_bar: Panel
var timer_fill: Panel
var hud_val: Label
var hint_btn: Button
var over_panel: Control
var card_panel: Control

var _tiles: Array = []           # wheel tile Panels, index-aligned with puzzle.wheel()
var _sel: Array = []             # selected wheel indices, in order
var _busy := false
var _autoplay := false
var _touch_id := -1
var _dragging := false
var _over_recorded := false
var _daily_clean: Array = []     # per-target true=no hint, in solve order (share grid)
var _shake_tw: Tween
var _toasts: Array = []
var _rush_paused := false
var _mascot: TextureRect
var _bubble: Panel
var _last_say := -1e9
var _wrong_streak := 0
var _hurry_said := false
var _just_solved := ""           # the word whose slots celebrate on this render (L73)


func _ready() -> void:
	_autoplay = data.get("autoplay", false)
	if data.get("daily", false):
		mode = "daily"
	elif data.get("rush", false):
		mode = "rush"
	Missions.begin_run()
	Missions.mission_done.connect(_on_mission_done)
	_start_mode()
	relayout()
	Music.set_intensity(0.5 if mode == "rush" else 0.15)
	if Store.first_run and mode == "campaign":
		Store.inventory["hint"] = Economy.count("hint") + FREE_HINTS_FIRST_RUN
		_show_tutorial()
	elif mode == "daily" and not _autoplay and not Masal.logged_today():
		_toast(I18n.t("daily_rules"), 3.0)
	elif mode == "rush" and not _autoplay:
		_toast(I18n.t("rush_rules"), 3.0)


func _start_mode() -> void:
	match mode:
		"daily":
			daily_key = Time.get_date_string_from_system().replace("-", "")
			puzzle = Puzzle.new(Masal.daily_level(daily_key), Masal.word_set,
				Masal.daily_seed(daily_key))
			# a phone call must never burn the one daily attempt — resume the snapshot
			if Store.daily_run.get("key", "") == daily_key:
				puzzle.restore(Store.daily_run.get("snap", {}))
			_daily_clean = []
		"rush":
			rush = Rush.new(Masal.levels, Masal.word_set)
			puzzle = rush.puzzle
		_:
			puzzle = Puzzle.new(Masal.campaign_level(Store.campaign_index), Masal.word_set)


func _exit_tree() -> void:
	if Missions.mission_done.is_connected(_on_mission_done):
		Missions.mission_done.disconnect(_on_mission_done)
	_persist_daily()


func _persist_daily() -> void:
	if mode == "daily" and puzzle and not puzzle.done:
		Store.daily_run = {"key": daily_key, "snap": puzzle.snapshot()}
		Store.save_soon()


func _process(delta: float) -> void:
	if mode != "rush" or rush == null or rush.game_over or _rush_paused or _busy:
		return
	if _autoplay:
		return                    # the bot advances time itself, deterministically
	rush.advance(delta)
	_update_timer()
	if rush.time_left < 15.0 and not _hurry_said and not rush.game_over:
		_hurry_said = true
		_mascot_say("char_g_hurry", true)
	elif rush.time_left > 25.0:
		_hurry_said = false
	if rush.game_over:
		_on_rush_over()


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	_tiles = []
	_sel = []
	m = UI.board_metrics()
	var v := UI.vp()
	UI.animate_bg(self, 3)
	_build_hud(v)

	proverb_root = Control.new()
	proverb_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(proverb_root)
	preview_root = Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview_root)
	wheel_root = Control.new()
	wheel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wheel_root)
	fx_root = Control.new()
	fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_root)

	touch_area = Control.new()
	touch_area.position = Vector2(0, m.wheel_cy - m.wheel_d / 2.0 - 8)
	touch_area.size = Vector2(v.x, m.wheel_d + 16)
	touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_area.gui_input.connect(_on_wheel_input)
	add_child(touch_area)

	over_panel = null
	card_panel = null
	_build_mascot()
	_render_proverb()
	_render_wheel()
	_render_preview()
	if mode == "rush" and rush and rush.game_over:
		_build_over_panel()
	if Masal.has_image(str(puzzle.level.get("id", ""))) and not _autoplay:
		_mascot_say("char_g_pic")


## شکرک lives in the game too (L70): docked at the lower-left of the proverb panel,
## reacting to real events through _mascot_say (priority = whoever calls, throttled).
func _build_mascot() -> void:
	_mascot = null
	_bubble = null
	var portrait := Char.portrait(false)
	if portrait == null:
		return
	var v := UI.vp()
	var mh: float = clampf(v.y * 0.085, 56, 104)
	_mascot = TextureRect.new()
	_mascot.texture = portrait
	_mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_mascot.size = Vector2(mh * 0.8, mh)
	_mascot.position = Vector2(m.margin - 2, m.proverb_y + m.proverb_h - mh + 6)
	_mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mascot.z_index = 5
	add_child(_mascot)
	var bob := _mascot.create_tween().set_loops()
	bob.tween_property(_mascot, "position:y", _mascot.position.y - 4, 1.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_mascot, "position:y", _mascot.position.y, 1.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _mascot_say(key: String, force := false) -> void:
	if _mascot == null or not is_instance_valid(_mascot) or _autoplay:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _last_say < 6.0:
		return
	_last_say = now
	if _bubble and is_instance_valid(_bubble):
		_bubble.queue_free()
	var v := UI.vp()
	var fs := int(clampf(v.y * 0.017, 13, 20))
	var txt := I18n.t(key)
	var bw: float = minf(UI.font_bold.get_string_size(txt,
		HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x + fs * 2.2, v.x * 0.6)
	_bubble = UI.panel(Color("2b3350"), 12)
	_bubble.size = Vector2(bw, fs * 2.4)
	_bubble.position = Vector2(_mascot.position.x + _mascot.size.x * 0.7,
		_mascot.position.y - fs * 2.0)
	_bubble.z_index = 6
	add_child(_bubble)
	var l := UI.label(txt, fs, false)
	l.name = "OwlSays"           # dialogue node: emoji exempt from the chrome test
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubble.add_child(l)
	_bubble.modulate.a = 0.0
	var tw := _bubble.create_tween()
	tw.tween_property(_bubble, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.4)
	tw.tween_property(_bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_bubble.queue_free)


func _build_hud(v: Vector2) -> void:
	var fs := int(clampf(v.y * 0.021, 16, 26))
	var title_txt := ""
	match mode:
		"daily": title_txt = I18n.t("daily")
		"rush": title_txt = I18n.t("rush")
		_: title_txt = I18n.t("level_n") % I18n.digits(Store.campaign_index + 1)
	var title := UI.label(title_txt, fs, true, UI.accent())
	title.position = Vector2(v.x / 2 - 200, m.top_h * 0.12)
	title.size = Vector2(400, m.top_h * 0.42)
	add_child(title)

	hud_val = UI.label(_hud_text(), int(fs * 0.95), true, UI.GOLD)
	hud_val.position = Vector2(14, m.top_h * 0.12)
	hud_val.size = Vector2(v.x * 0.32, m.top_h * 0.42)
	hud_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(hud_val)

	var back := UI.button("⏪", fs, func(): on_back(), Vector2(m.top_h * 0.62, m.top_h * 0.52))
	back.position = Vector2(v.x - m.top_h * 0.62 - 12, m.top_h * 0.14)
	add_child(back)

	if mode == "rush":
		timer_bar = UI.panel(Color("0f131e"), 8)
		timer_bar.position = Vector2(14, m.top_h * 0.66)
		timer_bar.size = Vector2(v.x - 28, m.top_h * 0.24)
		add_child(timer_bar)
		timer_fill = UI.panel(UI.accent(), 8)
		timer_fill.position = timer_bar.position
		timer_fill.size = timer_bar.size
		add_child(timer_fill)
		_update_timer()
	else:
		var prog := UI.label(_progress_text(), int(fs * 0.85), false, UI.MUTED)
		prog.name = "Progress"
		prog.position = Vector2(v.x / 2 - 200, m.top_h * 0.58)
		prog.size = Vector2(400, m.top_h * 0.34)
		add_child(prog)


func _hud_text() -> String:
	match mode:
		"rush":
			return I18n.digits(rush.score if rush else 0)
		"daily":
			return "🔥 " + I18n.digits(Store.streak_count) if Store.streak_count > 0 \
				else "🪙 " + I18n.digits(Store.coins)
		_:
			return "🪙 " + I18n.digits(Store.coins)


func _progress_text() -> String:
	return I18n.t("words_found") % [I18n.digits(puzzle.solved_count()),
		I18n.digits(puzzle.total_targets())]


func _update_hud() -> void:
	if hud_val and is_instance_valid(hud_val):
		hud_val.text = _hud_text()
	var prog := get_node_or_null("Progress")
	if prog:
		prog.text = _progress_text()


func _update_timer() -> void:
	if not (timer_fill and is_instance_valid(timer_fill)):
		return
	var pct: float = clampf(rush.time_left / Rush.MAX_BANK, 0.0, 1.0)
	timer_fill.size.x = timer_bar.size.x * pct
	# RTL: anchor the fill to the right edge so it drains leftwards
	timer_fill.position.x = timer_bar.position.x + timer_bar.size.x * (1.0 - pct)
	var sb: StyleBoxFlat = timer_fill.get_theme_stylebox("panel")
	sb.bg_color = Color("e0455a") if rush.time_left < 15.0 else UI.accent()
	Music.set_intensity(clampf(1.2 - rush.time_left / Rush.START_SECONDS, 0.3, 1.0))


# ---------- proverb rendering ----------

## Break one display token into parts: visible text runs and hidden target words.
func _token_parts(tok: Dictionary) -> Array:
	var parts: Array = []
	var rest: String = tok.tok
	if not tok.target:
		return [{"text": rest}]
	while rest.length() > 0:
		var best_i := -1
		var best_w := ""
		for w in tok.subs:
			var i := rest.find(w)
			if i >= 0 and (best_i < 0 or i < best_i):
				best_i = i
				best_w = w
		if best_i < 0:
			parts.append({"text": rest})
			break
		if best_i > 0:
			parts.append({"text": rest.substr(0, best_i)})
		parts.append({"word": best_w})
		rest = rest.substr(best_i + best_w.length())
	return parts


## Lay the proverb out right-to-left with wrapping; hidden targets are letter boxes.
## The token block is centred vertically in the panel (top-aligning left half the
## panel empty — caught by the screenshot oracle).
func _render_proverb() -> void:
	for ch in proverb_root.get_children():
		ch.queue_free()
	var v := UI.vp()
	var fs := int(clampf(v.y * 0.026, 19, 32))
	var box: float = clampf(v.x * 0.052, 26, 40)
	var gap := 4.0
	var margin: float = m.margin + 6
	var line_h: float = box + 14
	var lines := _count_lines(fs, box, gap, margin, v)
	var panel := UI.panel(Color(UI.panel_color(), 0.65), 20)
	panel.position = Vector2(m.margin - 6, m.proverb_y)
	panel.size = Vector2(v.x - (m.margin - 6) * 2, m.proverb_h)
	proverb_root.add_child(panel)

	# picture-guess levels: the illustration IS the clue, drawn above the slots
	var img_h := 0.0
	var img := Masal.image(str(puzzle.level.get("id", "")))
	if img != null:
		img_h = minf(m.proverb_h - lines * line_h - 28, m.proverb_h * 0.62)
		if img_h > 70:
			var tr := TextureRect.new()
			tr.texture = img
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = Vector2(panel.size.x - 24, img_h - 8)
			tr.position = Vector2(panel.position.x + 12, m.proverb_y + 10)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			proverb_root.add_child(tr)
		else:
			img_h = 0.0

	var x := v.x - margin          # RTL: start at the right edge
	var y: float = m.proverb_y + img_h \
		+ maxf(12.0, (m.proverb_h - img_h - lines * line_h) / 2.0)

	for tok in puzzle.display_tokens():
		var widgets: Array = []      # [[width, Control-builder args], ...] for this token
		var tok_w := 0.0
		for part in _token_parts(tok):
			if part.has("text"):
				var t_str: String = part.text
				var w := UI.font_bold.get_string_size(t_str, HORIZONTAL_ALIGNMENT_CENTER,
					-1, fs).x + 4
				widgets.append({"kind": "text", "s": t_str, "w": w})
				tok_w += w
			else:
				var word: String = part.word
				var w2: float = word.length() * (box + gap)
				var solved: bool = puzzle.solved.has(word)
				widgets.append({"kind": "word", "s": word, "w": w2, "solved": solved})
				tok_w += w2
		tok_w += 10                  # inter-token space
		if x - tok_w < margin:       # wrap
			x = v.x - margin
			y += line_h
		# lay this token's parts right-to-left
		for wd in widgets:
			x -= wd.w
			if wd.kind == "text":
				var l := UI.label(wd.s, fs, true, Color.WHITE)
				l.position = Vector2(x, y)
				l.size = Vector2(wd.w, box)
				proverb_root.add_child(l)
			else:
				_word_slot(wd.s, wd.solved, Vector2(x, y), box, gap, fs)
		x -= 10
	# one-shot: a resize re-render must not re-celebrate (renderers stay idempotent, L30)
	_just_solved = ""


## Dry-run of the wrap loop: how many lines will the proverb occupy?
func _count_lines(fs: int, box: float, gap: float, margin: float, v: Vector2) -> int:
	var x := v.x - margin
	var lines := 1
	for tok in puzzle.display_tokens():
		var tok_w := 10.0
		for part in _token_parts(tok):
			if part.has("text"):
				tok_w += UI.font_bold.get_string_size(part.text,
					HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x + 4
			else:
				tok_w += part.word.length() * (box + gap)
		if x - tok_w < margin:
			x = v.x - margin
			lines += 1
		x -= tok_w
	return lines


## One hidden/solved word as letter boxes, first letter at the RIGHT.
## A freshly solved word celebrates: per-letter pop + staggered colour bursts (L73).
func _word_slot(word: String, solved: bool, pos: Vector2, box: float, gap: float, fs: int) -> void:
	var shown: int = int(puzzle.revealed.get(word, 0))
	var celebrate := solved and word == _just_solved
	var fx_colors := [UI.accent(), UI.GOLD, UI.theme().get("ink", UI.GOLD)]
	for i in word.length():
		var bx := pos.x + (word.length() - 1 - i) * (box + gap)
		var cell := UI.panel(UI.accent().darkened(0.25) if solved else UI.theme().slot, 8)
		cell.position = Vector2(bx, pos.y)
		cell.size = Vector2(box, box)
		proverb_root.add_child(cell)
		if solved or i < shown:
			var l := UI.label(word[i], int(box * 0.62), true,
				Color.WHITE if solved else UI.GOLD)
			l.position = Vector2(bx, pos.y)
			l.size = Vector2(box, box)
			proverb_root.add_child(l)
			if celebrate:
				l.pivot_offset = Vector2(box / 2, box / 2)
				l.scale = Vector2(0.2, 0.2)
				var lt := l.create_tween()
				lt.tween_interval(i * 0.05)
				lt.tween_property(l, "scale", Vector2(1.3, 1.3), 0.12)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				lt.tween_property(l, "scale", Vector2.ONE, 0.1)
		if celebrate:
			cell.pivot_offset = Vector2(box / 2, box / 2)
			cell.scale = Vector2(1.25, 1.25)
			var ct := cell.create_tween()
			ct.tween_interval(i * 0.05)
			ct.tween_property(cell, "scale", Vector2.ONE, 0.16)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var burst_at := Vector2(bx + box / 2, pos.y + box / 2)
			var bt := create_tween()
			bt.tween_interval(i * 0.05)
			bt.tween_callback(func():
				if fx_root and is_instance_valid(fx_root):
					UI.burst(fx_root, burst_at, fx_colors[i % fx_colors.size()], 10))


# ---------- wheel ----------

func _render_wheel() -> void:
	for ch in wheel_root.get_children():
		ch.queue_free()
	_tiles = []
	var wheel: Array = puzzle.wheel()
	var n := wheel.size()
	if n == 0:
		return
	var c := Vector2(m.wheel_cx, m.wheel_cy)
	var disc := UI.panel(Color(UI.panel_color(), 0.8), int(m.wheel_d / 2.0))
	disc.position = c - Vector2(m.wheel_d, m.wheel_d) / 2.0
	disc.size = Vector2(m.wheel_d, m.wheel_d)
	wheel_root.add_child(disc)
	var r: float = m.wheel_d / 2.0 - m.tile * 0.62
	for i in n:
		var ang := -PI / 2.0 + TAU * i / n
		var t := UI.tile(wheel[i], m.tile)
		t.position = c + Vector2(cos(ang), sin(ang)) * r - Vector2(m.tile, m.tile) / 2.0
		t.pivot_offset = Vector2(m.tile, m.tile) / 2.0
		wheel_root.add_child(t)
		_tiles.append(t)

	# Side buttons live on the preview row, at the screen margins — inside the wheel
	# area they overlapped the outer tiles (caught by the screenshot oracle).
	var bs := int(clampf(UI.vp().y * 0.021, 16, 26))
	var by: float = m.wheel_cy - m.wheel_d / 2.0 - m.preview_h - 8
	var shuffle := UI.button("🔀", bs, _on_shuffle, Vector2(m.tile * 0.95, m.preview_h * 0.9))
	shuffle.position = Vector2(m.margin, by)
	wheel_root.add_child(shuffle)
	if mode != "rush":
		hint_btn = UI.button("💡 " + I18n.digits(Economy.count("hint")), bs, _on_hint,
			Vector2(m.tile * 1.35, m.preview_h * 0.9))
		hint_btn.position = Vector2(UI.vp().x - m.margin - m.tile * 1.35, by)
		wheel_root.add_child(hint_btn)


func _render_preview() -> void:
	for ch in preview_root.get_children():
		ch.queue_free()
	var word := _current_word()
	if word.is_empty():
		return
	var v := UI.vp()
	var s: float = clampf(m.preview_h * 0.9, 34, 54)
	var gap := 5.0
	var total: float = word.length() * (s + gap)
	var x0 := (v.x + total) / 2.0 - s   # RTL: first letter rightmost
	var y: float = m.wheel_cy - m.wheel_d / 2.0 - m.preview_h - 8
	for i in word.length():
		var t := UI.tile(word[i], s, true)
		t.position = Vector2(x0 - i * (s + gap), y)
		preview_root.add_child(t)


func _current_word() -> String:
	var w := ""
	for idx in _sel:
		w += puzzle.wheel()[idx]
	return w


# ---------- input: drag through letters or tap them; release/tap-out submits ----------

func _tile_at(global_pos: Vector2) -> int:
	for i in _tiles.size():
		var t: Panel = _tiles[i]
		if not is_instance_valid(t):
			continue
		var center: Vector2 = t.position + Vector2(m.tile, m.tile) / 2.0
		if center.distance_to(global_pos) <= m.tile * 0.62:
			return i
	return -1


func _on_wheel_input(event: InputEvent) -> void:
	if _busy or _autoplay or (rush and rush.game_over) or puzzle.done:
		return
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = event.position + touch_area.position
		if event.pressed:
			_begin_drag(pos)
		else:
			_end_drag()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_id != -1:
				return              # a second finger must not steal the gesture
			_touch_id = event.index
			_begin_drag(event.position + touch_area.position)
		elif event.index == _touch_id:
			_touch_id = -1
			_end_drag()
		return
	if event is InputEventMouseMotion and _dragging:
		_extend_drag(event.position + touch_area.position)
	elif event is InputEventScreenDrag and _dragging and event.index == _touch_id:
		_extend_drag(event.position + touch_area.position)


func _begin_drag(pos: Vector2) -> void:
	var i := _tile_at(pos)
	_dragging = true
	if i >= 0:
		_select_tile(i)


func _extend_drag(pos: Vector2) -> void:
	var i := _tile_at(pos)
	if i >= 0:
		_select_tile(i)


func _end_drag() -> void:
	_dragging = false
	if _sel.size() >= 2:
		_commit_word()
	else:
		_clear_selection()


## Adding a tile to the current word — shared by finger, mouse and the QA bot.
func _select_tile(i: int) -> void:
	if i in _sel:
		# dragging back onto the previous tile unwinds one step (standard wheel UX)
		if _sel.size() >= 2 and _sel[_sel.size() - 2] == i:
			var last: int = _sel.pop_back()
			_paint_tile(last, false)
			_render_preview()
		return
	_sel.append(i)
	_paint_tile(i, true)
	# tactile spark right under the finger (L73)
	if fx_root and is_instance_valid(fx_root) and i < _tiles.size() and is_instance_valid(_tiles[i]):
		UI.burst(fx_root, _tiles[i].position + Vector2(m.tile, m.tile) / 2.0, UI.accent(), 5)
	Sfx.play("ui")
	_render_preview()


func _paint_tile(i: int, hot: bool) -> void:
	if i < 0 or i >= _tiles.size() or not is_instance_valid(_tiles[i]):
		return
	var old: Panel = _tiles[i]
	var t := UI.tile(puzzle.wheel()[i], m.tile, hot)
	t.position = old.position
	t.pivot_offset = old.pivot_offset
	wheel_root.add_child(t)
	_tiles[i] = t
	old.queue_free()
	if hot:
		t.scale = Vector2(1.15, 1.15)
		var tw := t.create_tween()
		tw.tween_property(t, "scale", Vector2.ONE, 0.12)


func _clear_selection() -> void:
	for i in _sel:
		_paint_tile(i, false)
	_sel = []
	_render_preview()


func _commit_word() -> void:
	var word := _current_word()
	_clear_selection()
	_submit_word(word)


## The one path every submission takes (finger, mouse, bot).
func _submit_word(word: String) -> void:
	if _busy:
		return
	_busy = true
	var res: Dictionary
	if mode == "rush":
		res = rush.submit(word)
		puzzle = rush.puzzle
	else:
		res = puzzle.submit(word)
	match int(res.kind):
		Puzzle.HIT_TARGET:
			_wrong_streak = 0
			_just_solved = word
			_float_label("✓ " + word, UI.GOLD)
			Sfx.play_merge(2, 64)
			Sfx.vibrate(25)
			Store.words_total += 1
			Missions.report("word", 1)
			_check_word_achievements()
			if mode == "daily":
				# clean = the player typed it with no letters revealed by hints
				_daily_clean.append(int(puzzle.revealed.get(word, 0)) == 0)
				_persist_daily()
			if mode == "rush":
				_update_timer()
				if int(res.chain) >= 2:
					_combo_banner(int(res.chain))
					Missions.report("chain", int(res.chain))
					if int(res.chain) >= 3:
						_mascot_say("char_g_chain")
				if res.level_done:
					Missions.report("level", 1)
			_update_hud()
			if mode != "rush" and res.level_done:
				_mascot_say("char_g_done", true)
				_fx_celebrate()
				_on_level_done()
			elif mode != "rush" and res.round_done:
				_mascot_say("char_g_round")
				_next_round_flourish()
			else:
				_render_proverb()
			if mode == "rush" and res.level_done:
				_fx_celebrate()
		Puzzle.HIT_BONUS:
			_wrong_streak = 0
			_mascot_say("char_g_bonus")
			_fx_coins(int(res.coins))
			Sfx.play("coin")
			Store.bonus_total += 1
			Store.add_coins(int(res.coins))
			Missions.report("bonus", 1)
			if Store.bonus_total >= 50:
				_try_ach("bonus50")
			_toast(I18n.t("bonus_found") % I18n.digits(int(res.coins)), 1.2)
			_update_hud()
			if mode == "daily":
				_persist_daily()
		Puzzle.HIT_DUP:
			_toast(I18n.t("already_found"), 0.9)
		_:
			if word.length() >= 2:
				Sfx.play("stone")
				shake(4.0)
				_toast(I18n.t("not_a_word"), 0.9)
				_wrong_streak += 1
				if _wrong_streak >= 3:
					_wrong_streak = 0
					_mascot_say("char_g_wrong3")
	_busy = false


func _check_word_achievements() -> void:
	if Store.words_total >= 500:
		_try_ach("words500")
	elif Store.words_total >= 100:
		_try_ach("words100")


func _next_round_flourish() -> void:
	Sfx.play("levelup")
	_render_proverb()
	_render_wheel()
	_render_preview()
	shake(3.0)


# ---------- level completion / proverb card ----------

func _on_level_done() -> void:
	Sfx.play("bigmerge")
	Sfx.vibrate(60)
	_render_proverb()
	Missions.report("level", 1)
	var level := puzzle.level
	var was_new := false
	if mode == "campaign":
		Store.campaign_index += 1
		if Store.campaign_index >= 1:
			_try_ach("masal1")
		if Store.campaign_index >= 10:
			_try_ach("masal10")
		if Store.campaign_index >= 40:
			_try_ach("masal40")
		if Store.campaign_index >= 100:
			_try_ach("masal100")
		was_new = Store.collect_masal(str(level.id))
		Store.add_coins(150)
		Store.save()
	elif mode == "daily":
		_record_daily_over()
	if Store.masal_collected.size() >= 30:
		_try_ach("treasury30")
	await get_tree().create_timer(0.5).timeout
	_build_card_panel(level, was_new)


## One-shot daily progression, latched (L30): streak, grant, ledger, missions, upload.
func _record_daily_over() -> void:
	if _over_recorded:
		return
	_over_recorded = true
	var key := Time.get_date_string_from_system().replace("-", "")
	daily_key = key   # a run crossing midnight credits the day it ENDS
	Masal.grant_daily(key)
	Masal.log_daily(str(puzzle.level.id), puzzle.hints_used, puzzle.solved_count())
	var score := _daily_score()
	Store.record_game_over(score, key)
	Store.daily_run = {}
	_try_ach("daily1")
	if Store.streak_count >= 7:
		_try_ach("streak7")
	var reward: int = 400 + puzzle.bonus_found.size() * 50
	Store.add_coins(reward)
	Missions.report("daily", 1)
	Notify.on_played()
	Online.submit(score, "daily")
	Store.flush()


func _daily_score() -> int:
	return maxi(50, puzzle.total_targets() * 100 - puzzle.hints_used * 100
		+ puzzle.bonus_found.size() * 50)


## The proverb card: the completed مثل, its meaning, share + next actions.
func _build_card_panel(level: Dictionary, newly_collected: bool) -> void:
	if card_panel and is_instance_valid(card_panel):
		card_panel.queue_free()
	card_panel = Control.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.add_child(dim)
	add_child(card_panel)
	var v := UI.vp()
	var pw: float = minf(v.x - 36, 560)
	var ph: float = clampf(v.y * 0.62, 420, 620)
	var p := UI.panel(Color("2c3350"), 24)
	p.size = Vector2(pw, ph)
	p.position = Vector2((v.x - pw) / 2.0, (v.y - ph) / 2.0)
	card_panel.add_child(p)
	var frame := UI.panel(Color(0, 0, 0, 0), 24)
	var fsb: StyleBoxFlat = frame.get_theme_stylebox("panel")
	fsb.set_border_width_all(3)
	fsb.border_color = Economy.frame_color()
	frame.position = p.position
	frame.size = p.size
	card_panel.add_child(frame)

	var fs := int(clampf(v.y * 0.024, 18, 30))
	var y := ph * 0.05
	var head := UI.label(I18n.t("daily_done_title") if mode == "daily" else I18n.t("masal_unlocked") if newly_collected else I18n.t("level_n") % I18n.digits(Store.campaign_index),
		fs, true, UI.GOLD)
	head.position = Vector2(20, y)
	head.size = Vector2(pw - 40, fs * 1.8)
	p.add_child(head)
	y += fs * 2.2

	var txt := UI.label("«" + str(level.text) + "»", int(fs * 1.15))
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.position = Vector2(20, y)
	txt.size = Vector2(pw - 40, ph * 0.26)
	p.add_child(txt)
	y += ph * 0.27

	var mh := UI.label(I18n.t("masal_meaning"), int(fs * 0.85), true, UI.accent())
	mh.position = Vector2(20, y)
	mh.size = Vector2(pw - 40, fs * 1.4)
	p.add_child(mh)
	y += fs * 1.6
	var meaning := UI.label(str(level.meaning), int(fs * 0.92), false)
	meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meaning.position = Vector2(20, y)
	meaning.size = Vector2(pw - 40, ph * 0.22)
	p.add_child(meaning)
	y = ph - clampf(v.y * 0.052, 46, 64) * 2.5 - 20

	var bw2: float = pw * 0.44
	var bh: float = clampf(v.y * 0.052, 46, 64)
	if mode == "daily":
		var sh_btn := UI.button("📤 " + I18n.t("share_result"), int(fs * 0.85), _share_daily,
			Vector2(bw2, bh), Color("3a6a48"))
		sh_btn.position = Vector2(pw / 2 - bw2 - 6, y)
		p.add_child(sh_btn)
		var gift := UI.button("📜 " + I18n.t("share_masal"), int(fs * 0.85),
			func(): _share_masal(level), Vector2(bw2, bh), Color("6b4f9e"))
		gift.position = Vector2(pw / 2 + 6, y)
		p.add_child(gift)
	else:
		var next_btn := UI.button("▶ " + I18n.t("retry" if puzzle.done else "play"),
			int(fs * 0.9), _on_next_level, Vector2(bw2, bh), UI.accent())
		next_btn.text = "▶"
		next_btn.position = Vector2(pw / 2 - bw2 - 6, y)
		p.add_child(next_btn)
		var gift2 := UI.button("📜 " + I18n.t("share_masal"), int(fs * 0.85),
			func(): _share_masal(level), Vector2(bw2, bh), Color("6b4f9e"))
		gift2.position = Vector2(pw / 2 + 6, y)
		p.add_child(gift2)
	y += bh + 12
	var menu_btn := UI.button(I18n.t("menu"), int(fs * 0.85),
		func(): shell.show_screen("menu"), Vector2(pw * 0.5, bh * 0.9))
	menu_btn.position = Vector2(pw * 0.25, y)
	p.add_child(menu_btn)


func _on_next_level() -> void:
	Sfx.play("ui")
	if card_panel and is_instance_valid(card_panel):
		card_panel.queue_free()
		card_panel = null
	_start_mode()
	relayout()


# ---------- rush game over ----------

func _on_rush_over() -> void:
	if _over_recorded:
		return
	_over_recorded = true
	Sfx.play("gameover")
	Sfx.vibrate(120)
	Music.set_intensity(0.1)
	var res := Store.record_game_over(rush.score, "")
	Missions.report("rush", rush.score)
	if rush.score >= 800:
		_try_ach("rush800")
	Online.submit(rush.score, "rush")
	Notify.on_played()
	Store.flush()
	_build_over_panel(res.get("new_best", false))


func _build_over_panel(new_best := false) -> void:
	if over_panel and is_instance_valid(over_panel):
		over_panel.queue_free()
	over_panel = Control.new()
	over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_panel.add_child(dim)
	add_child(over_panel)
	var v := UI.vp()
	var cy := v.y * 0.22

	var title := UI.label(I18n.t("new_best") if new_best else I18n.t("game_over"),
		int(clampf(v.y * 0.045, 34, 60)))
	title.position = Vector2(v.x / 2 - 300, cy)
	title.size = Vector2(600, 70)
	over_panel.add_child(title)

	var sc := UI.label(I18n.digits(rush.score), int(clampf(v.y * 0.065, 50, 88)), true, UI.GOLD)
	sc.position = Vector2(v.x / 2 - 300, cy + 80)
	sc.size = Vector2(600, 95)
	over_panel.add_child(sc)

	var stats := "%s: %s   ⛓ ×%s" % [I18n.t("best"), I18n.digits(Store.best_score),
		I18n.digits(rush.chain)]
	var bl := UI.label(stats, int(clampf(v.y * 0.023, 18, 30)), false, UI.MUTED)
	bl.position = Vector2(v.x / 2 - 300, cy + 185)
	bl.size = Vector2(600, 36)
	over_panel.add_child(bl)

	var y := cy + 250
	var bw: float = clampf(v.x * 0.5, 200, 300)
	var retry := UI.button(I18n.t("retry"), int(clampf(v.y * 0.028, 22, 36)), _on_retry,
		Vector2(bw, clampf(v.y * 0.065, 56, 84)), UI.accent())
	retry.position = Vector2(v.x / 2 - bw / 2, y)
	over_panel.add_child(retry)
	y += clampf(v.y * 0.065, 56, 84) + 16
	var menu := UI.button(I18n.t("menu"), int(clampf(v.y * 0.022, 17, 28)),
		func(): shell.show_screen("menu"), Vector2(bw * 0.8, clampf(v.y * 0.05, 44, 64)))
	menu.position = Vector2(v.x / 2 - bw * 0.4, y)
	over_panel.add_child(menu)


func _on_retry() -> void:
	Sfx.play("ui")
	_over_recorded = false
	if over_panel and is_instance_valid(over_panel):
		over_panel.queue_free()
		over_panel = null
	rush = Rush.new(Masal.levels, Masal.word_set)
	puzzle = rush.puzzle
	Music.set_intensity(0.5)
	relayout()


# ---------- shared bits ----------

func _on_shuffle() -> void:
	if _busy:
		return
	_clear_selection()
	puzzle.shuffle_wheel()
	Sfx.play("ui")
	_render_wheel()


func _on_hint() -> void:
	if _busy or mode == "rush" or puzzle.done:
		return
	if Economy.count("hint") <= 0:
		_toast(I18n.t("no_hints"), 1.6)
		shell.show_screen("shop")
		return
	var was_solved := puzzle.solved.duplicate()
	var w := puzzle.hint()
	if w == "":
		return
	Economy.use_item("hint")
	Sfx.play("coin")
	_mascot_say("char_g_hint")
	_toast(I18n.t("hint_used"), 0.9)
	if mode == "daily":
		if puzzle.solved.has(w) and not was_solved.has(w):
			_daily_clean.append(false)   # auto-solved by hints → not a clean square
		_persist_daily()
	if puzzle.done and mode != "rush":
		_on_level_done()
	else:
		_render_proverb()
		_render_wheel()
	if hint_btn and is_instance_valid(hint_btn):
		hint_btn.text = "💡 " + I18n.digits(Economy.count("hint"))


## Floating feedback label rising from the preview row.
func _float_label(txt: String, color: Color) -> void:
	if fx_root == null or not is_instance_valid(fx_root):
		return
	var v := UI.vp()
	var fs := int(clampf(v.y * 0.026, 20, 32))
	var l := UI.label(txt, fs, true, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(v.x / 2 - 200, m.wheel_cy - m.wheel_d / 2.0 - m.preview_h - fs * 2.2)
	l.size = Vector2(400, fs * 1.6)
	l.z_index = 12
	fx_root.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - fs * 2.4, 0.7)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


## Bonus coins: golden sparkles at the preview + a flying reward label toward the HUD.
func _fx_coins(coins: int) -> void:
	if fx_root == null or not is_instance_valid(fx_root):
		return
	var at := Vector2(UI.vp().x / 2.0, m.wheel_cy - m.wheel_d / 2.0 - m.preview_h * 0.5)
	UI.burst(fx_root, at, UI.GOLD, 16)
	UI.burst(fx_root, at + Vector2(30, -10), Color("ffe08a"), 10)
	_float_label("🪙 +" + I18n.digits(coins), UI.GOLD)


## Proverb complete: layered colour bursts sweeping the proverb panel + shake.
func _fx_celebrate() -> void:
	if fx_root == null or not is_instance_valid(fx_root):
		return
	var v := UI.vp()
	var cols := [UI.accent(), UI.GOLD, UI.theme().get("ink", UI.GOLD),
		Color("ff8c5a"), Color("c39bf5")]
	for i in 5:
		var at := Vector2(v.x * (0.2 + 0.15 * i),
			m.proverb_y + m.proverb_h * (0.3 + 0.12 * (i % 3)))
		var tw := create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_callback(func():
			if fx_root and is_instance_valid(fx_root):
				UI.burst(fx_root, at, cols[i % cols.size()], 18))
	shake(6.0)
	Sfx.vibrate(45)


func _combo_banner(chain: int) -> void:
	var v := UI.vp()
	# the chain heats up: gold → orange → red → violet → cyan
	var heat := [UI.GOLD, Color("ffa14e"), Color("ff5e5e"), Color("c96bff"), Color("55e0ff")]
	var l := UI.label(I18n.t("combo") % I18n.digits(chain),
		int(clampf(v.y * 0.04, 30, 52)), true, heat[clampi(chain - 1, 0, heat.size() - 1)])
	l.position = Vector2(v.x / 2 - 250, m.proverb_y + m.proverb_h * 0.4)
	l.size = Vector2(500, 70)
	l.pivot_offset = Vector2(250, 35)
	l.scale = Vector2(0.3, 0.3)
	l.z_index = 15
	fx_root.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func shake(strength := 6.0) -> void:
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	wheel_root.position = Vector2.ZERO
	_shake_tw = wheel_root.create_tween()
	for i in 4:
		_shake_tw.tween_property(wheel_root, "position",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
	_shake_tw.tween_property(wheel_root, "position", Vector2.ZERO, 0.05)


func _try_ach(id: String) -> void:
	if Store.unlock(id):
		Sfx.play("coin")
		_toast(I18n.t("ach_unlocked") % I18n.t("ach_" + id))


func _on_mission_done(mn: Dictionary) -> void:
	Sfx.play("coin")
	_toast(I18n.t("mission_done") % I18n.digits(mn.reward))


func _toast(txt: String, dur := 1.6) -> void:
	var v := UI.vp()
	var p := UI.panel(Color("3a4160"), 14)
	var l := UI.label(txt, int(clampf(v.y * 0.02, 16, 24)))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(l)
	p.size = Vector2(minf(v.x - 40, 520), 64)
	p.position = Vector2((v.x - p.size.x) / 2, v.y - 150 - _toasts.size() * 72)
	p.z_index = 20
	p.modulate.a = 0.0
	add_child(p)
	_toasts.append(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(dur)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_toasts.erase(p)
		p.queue_free())


func _share_daily() -> void:
	Share.share_text(Share.daily_text(_daily_clean, puzzle.bonus_found.size(),
		Store.streak_count))
	Sfx.play("coin")
	_toast(I18n.t("copied"), 2.0)


func _share_masal(level: Dictionary) -> void:
	Share.share_text(Share.masal_text(level))
	Sfx.play("coin")
	_toast(I18n.t("copied"), 2.0)


func on_back() -> bool:
	_persist_daily()
	Store.flush()
	Store.save()
	shell.show_screen("menu")
	return true


func _show_tutorial() -> void:
	var steps := ["tutorial_1", "tutorial_2", "tutorial_3"]
	var idx := [0]
	var v := UI.vp()
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var p := UI.panel(Color("2c3350"), 22)
	p.size = Vector2(minf(v.x - 48, 560), clampf(v.y * 0.32, 260, 340))
	p.position = Vector2((v.x - p.size.x) / 2, (v.y - p.size.y) / 2)
	ov.add_child(p)
	var txt := UI.label(I18n.t(steps[0]), int(clampf(v.y * 0.023, 18, 28)), false)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.position = Vector2(20, 24)
	txt.size = Vector2(p.size.x - 40, p.size.y - 130)
	p.add_child(txt)
	var btn := UI.button(I18n.t("tutorial_ok"), int(clampf(v.y * 0.023, 18, 28)), func():
		idx[0] += 1
		if idx[0] < steps.size():
			txt.text = I18n.t(steps[idx[0]])
		else:
			Store.first_run = false
			Store.save()
			ov.queue_free()
	, Vector2(p.size.x * 0.5, 60), UI.accent())
	btn.position = Vector2(p.size.x * 0.25, p.size.y - 84)
	p.add_child(btn)
	ov.z_index = 30
	add_child(ov)


# ---------- automated QA: drives the SAME handlers a finger does ----------

func start_autoplay() -> void:
	_autoplay = true
	Store.first_run = false
	await get_tree().process_frame
	# 1) campaign: solve two levels through the real submission path
	for lvl in 2:
		while not puzzle.done:
			var target := _bot_next_target()
			if target == "":
				break
			_submit_word(target)
			await get_tree().process_frame
		print("AUTOPLAY campaign level done idx=%d coins=%d" %
			[Store.campaign_index, Store.coins])
		# the proverb card appears on a 0.5 s timer; don't wait for it — advance directly
		if puzzle.done:
			_on_next_level()
		await get_tree().process_frame
	# 2) daily: play today's puzzle to completion
	mode = "daily"
	_over_recorded = false
	_start_mode()
	relayout()
	await get_tree().process_frame
	while not puzzle.done:
		var t2 := _bot_next_target()
		if t2 == "":
			break
		_submit_word(t2)
		await get_tree().process_frame
	print("AUTOPLAY daily done streak=%d collected=%d" %
		[Store.streak_count, Store.masal_collected.size()])
	# 3) rush: play at a fixed pace until the clock kills the run (L15 proof)
	mode = "rush"
	_over_recorded = false
	rush = Rush.new(Masal.levels, Masal.word_set, 424242)
	puzzle = rush.puzzle
	relayout()
	await get_tree().process_frame
	var guard := 0
	while not rush.game_over and guard < 2000:
		guard += 1
		rush.advance(4.0)
		if rush.game_over:
			break
		var t3 := _bot_next_target()
		if t3 == "":
			rush.advance(1000.0)
			break
		_submit_word(t3)
		puzzle = rush.puzzle
		if guard % 10 == 0:
			await get_tree().process_frame
	_on_rush_over()
	print("AUTOPLAY rush over score=%d completed=%d words=%d" %
		[rush.score, rush.completed, rush.words_solved])
	print("AUTOPLAY_DONE collected=%d coins=%d words_total=%d" %
		[Store.masal_collected.size(), Store.coins, Store.words_total])
	get_tree().quit(0)


func _bot_next_target() -> String:
	for t in puzzle.current_round().get("targets", []):
		if not puzzle.solved.has(t):
			return t
	return ""
