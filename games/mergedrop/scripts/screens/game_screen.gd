extends Control
## Gameplay screen v3 — pressure levels, stones, missions, juice, dynamic music.

const BoardLogic = preload("res://scripts/board.gd")
const GOALS := [64, 128, 256, 512, 1024, 2048, 4096, 8192]
const UNDOS_PER_GAME := 3

var shell: Control
var data := {}

var board: Board
var daily := false
var daily_key := ""
var m := {}
var tiles_root: Control
var fx_root: Control
var touch_area: Control
var ghost: Panel
var col_hl: ColorRect
var score_val: Label
var best_val: Label
var goal_lbl: Label
var level_lbl: Label
var next_root: Control
var undo_btn: Button
var over_panel: Control
var danger_rect: Panel
var _shown_score := 0
var _busy := false
var _aim_col := -1
var _undo_snap := {}
var _undos_left := UNDOS_PER_GAME
var _autoplay := false
var _over_recorded := false
var _over_fal := {}
var _over_res := {}
var _over_coins := 0
var _touch_id := -1
var _danger_tw: Tween
var _shake_tw: Tween
var _toasts: Array = []


func _ready() -> void:
	_autoplay = data.get("autoplay", false)
	daily = data.get("daily", false)
	if daily:
		daily_key = Time.get_date_string_from_system().replace("-", "")
		board = BoardLogic.new(int(daily_key), "daily")
	else:
		board = BoardLogic.new()
	Missions.begin_run()
	Missions.mission_done.connect(_on_mission_done)
	relayout()
	Music.set_intensity(0.15)
	if Store.first_run and not daily:
		_show_tutorial()
	elif daily and Store.daily_best.get(daily_key, -1) == -1 and not _autoplay:
		_toast(I18n.t("daily_rules"), 2.6)


func _exit_tree() -> void:
	if Missions.mission_done.is_connected(_on_mission_done):
		Missions.mission_done.disconnect(_on_mission_done)


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	m = UI.board_metrics()
	var v := UI.vp()
	UI.animate_bg(self, 3)

	var score_title := UI.label(I18n.t("daily_short") if daily else I18n.t("score"),
		int(clampf(v.y * 0.021, 16, 28)), false, UI.MUTED)
	score_title.position = Vector2(v.x / 2 - 150, m.top_h * 0.08)
	score_title.size = Vector2(300, 30)
	add_child(score_title)
	score_val = UI.label(I18n.digits(board.score), int(clampf(v.y * 0.045, 34, 60)))
	score_val.position = Vector2(v.x / 2 - 150, m.top_h * 0.24)
	score_val.size = Vector2(300, m.top_h * 0.4)
	add_child(score_val)
	_shown_score = board.score

	var best_title := UI.label(I18n.t("best"), int(clampf(v.y * 0.017, 13, 22)), false, UI.MUTED)
	best_title.position = Vector2(16, m.top_h * 0.08)
	best_title.size = Vector2(130, 26)
	add_child(best_title)
	best_val = UI.label(_best_text(), int(clampf(v.y * 0.026, 20, 34)))
	best_val.position = Vector2(16, m.top_h * 0.3)
	best_val.size = Vector2(130, 36)
	add_child(best_val)

	level_lbl = UI.label(_level_text(), int(clampf(v.y * 0.022, 17, 28)), true, UI.accent())
	level_lbl.position = Vector2(v.x - 190, m.top_h * 0.08)
	level_lbl.size = Vector2(150, 34)
	add_child(level_lbl)

	var back := UI.button("↩", int(clampf(v.y * 0.024, 18, 30)), on_back)
	back.position = Vector2(v.x - 84, m.top_h * 0.4)
	add_child(back)

	goal_lbl = UI.label(_goal_text(), int(clampf(v.y * 0.019, 15, 25)), false, UI.GOLD)
	goal_lbl.position = Vector2(v.x / 2 - 300, m.top_h * 0.72)
	goal_lbl.size = Vector2(600, 30)
	add_child(goal_lbl)

	var bp := UI.panel(UI.panel_color(), 22)
	bp.position = Vector2(m.x0 - 12, m.top - 12)
	bp.size = Vector2(m.w + 24, m.h + 24)
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bp)

	danger_rect = UI.panel(Color(0, 0, 0, 0), 22)
	danger_rect.position = bp.position
	danger_rect.size = bp.size
	danger_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(danger_rect)

	col_hl = ColorRect.new()
	col_hl.color = Color(1, 1, 1, 0.07)
	col_hl.size = Vector2(m.tile, m.h)
	col_hl.visible = false
	col_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col_hl)

	tiles_root = Control.new()
	tiles_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tiles_root)
	fx_root = Control.new()
	fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_root)

	touch_area = Control.new()
	touch_area.position = Vector2(m.x0 - 12, m.top - 12)
	touch_area.size = Vector2(m.w + 24, m.h + 24)
	touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_area.gui_input.connect(_on_board_input)
	add_child(touch_area)

	var fy: float = m.top + m.h + 18
	var next_title := UI.label(I18n.t("next"), int(clampf(v.y * 0.017, 13, 22)), false, UI.MUTED)
	next_title.position = Vector2(v.x / 2 - 80, fy)
	next_title.size = Vector2(160, 26)
	add_child(next_title)
	next_root = Control.new()
	next_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(next_root)

	undo_btn = UI.button("⏪ %s (%s)" % [I18n.t("undo"), I18n.digits(_undos_left)],
		int(clampf(v.y * 0.019, 15, 24)), _on_undo)
	undo_btn.position = Vector2(16, fy + 6)
	undo_btn.visible = not daily
	add_child(undo_btn)
	_update_undo_btn()

	over_panel = null
	_render_board()
	if board.game_over:
		_show_over()


func _best_text() -> String:
	if daily:
		return I18n.digits(int(Store.daily_best.get(daily_key, 0)))
	return I18n.digits(Store.best_score)


func _level_text() -> String:
	if daily:
		return I18n.t("moves") % I18n.digits(board.moves_left)
	return I18n.t("level") % I18n.digits(board.level)


func _goal_text() -> String:
	if daily:
		return ""
	if Store.goal_index >= GOALS.size():
		return ""
	return I18n.t("goal") % I18n.digits(GOALS[Store.goal_index])


func _cell_pos(c: int, r: int) -> Vector2:
	return Vector2(m.x0 + c * (m.tile + m.gap),
		m.top + (Board.ROWS - 1 - r) * (m.tile + m.gap))


func _render_board(merges: Array = []) -> void:
	for ch in tiles_root.get_children():
		ch.queue_free()
	var merge_pos := {}
	for mg in merges:
		merge_pos[mg.pos] = true
	for c in Board.COLS:
		for r in Board.ROWS:
			var val: int = board.grid[c][r]
			if val == 0:
				continue
			var t := UI.tile(val, m.tile)
			t.position = _cell_pos(c, r)
			tiles_root.add_child(t)
			if merge_pos.has(Vector2i(c, r)):
				t.pivot_offset = Vector2(m.tile / 2, m.tile / 2)
				t.scale = Vector2(1.32, 1.32)
				var tw := create_tween()
				tw.tween_property(t, "scale", Vector2.ONE, 0.18)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for ch in next_root.get_children():
		ch.queue_free()
	var nt := UI.tile(board.next_value, m.tile * 0.72)
	nt.position = Vector2(UI.vp().x / 2 - m.tile * 0.36, m.top + m.h + 44)
	nt.pivot_offset = Vector2(m.tile * 0.36, m.tile * 0.36)
	next_root.add_child(nt)
	var pulse := nt.create_tween().set_loops()
	pulse.tween_property(nt, "scale", Vector2(1.06, 1.06), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(nt, "scale", Vector2.ONE, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animate_score()
	best_val.text = _best_text()
	goal_lbl.text = _goal_text()
	level_lbl.text = _level_text()
	_update_danger()


func _animate_score() -> void:
	var target := board.score
	if target == _shown_score:
		score_val.text = I18n.digits(target)
		return
	var tw := create_tween()
	tw.tween_method(func(x): score_val.text = I18n.digits(int(x)),
		float(_shown_score), float(target), 0.35)
	_shown_score = target


func _update_danger() -> void:
	var danger := false
	for c in Board.COLS:
		if board.grid[c][Board.ROWS - 2] != 0:
			danger = true
			break
	var sb: StyleBoxFlat = danger_rect.get_theme_stylebox("panel")
	if danger and not board.game_over:
		sb.border_color = Color("e0455a")
		sb.set_border_width_all(3)
		sb.bg_color = Color(0, 0, 0, 0)
		danger_rect.modulate.a = 1.0
		if _danger_tw and _danger_tw.is_valid():
			_danger_tw.kill()
		_danger_tw = danger_rect.create_tween().set_loops(6)
		_danger_tw.tween_property(danger_rect, "modulate:a", 0.25, 0.4)
		_danger_tw.tween_property(danger_rect, "modulate:a", 1.0, 0.4)
	else:
		if _danger_tw and _danger_tw.is_valid():
			_danger_tw.kill()
		danger_rect.modulate.a = 1.0
		sb.set_border_width_all(0)


func shake(strength := 6.0) -> void:
	# Home is always ZERO: sampling the live position mid-shake re-captured the drifted
	# offset as home, so repeated shakes walked the board off centre.
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	tiles_root.position = Vector2.ZERO
	_shake_tw = tiles_root.create_tween()
	for i in 4:
		_shake_tw.tween_property(tiles_root, "position",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
	_shake_tw.tween_property(tiles_root, "position", Vector2.ZERO, 0.05)


# ---------- input ----------

func _col_from_local(p: Vector2) -> int:
	var x: float = p.x + touch_area.position.x - m.x0
	return clampi(int(x / (m.tile + m.gap)), 0, Board.COLS - 1)


func _on_board_input(event: InputEvent) -> void:
	if _busy or board.game_over or _autoplay:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_aim(_col_from_local(event.position))
		else:
			_release()
	elif event is InputEventMouseMotion and _aim_col >= 0:
		_aim(_col_from_local(event.position))
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _touch_id != -1:
				return          # a second finger must not steal the aim
			_touch_id = event.index
			_aim(_col_from_local(event.position))
		elif event.index == _touch_id:
			_touch_id = -1
			_release()
	elif event is InputEventScreenDrag and _aim_col >= 0 and event.index == _touch_id:
		_aim(_col_from_local(event.position))


func _aim(col: int) -> void:
	if col == _aim_col and ghost and is_instance_valid(ghost):
		return          # every drag sample was rebuilding the ghost tile
	_aim_col = col
	col_hl.visible = true
	col_hl.position = Vector2(m.x0 + col * (m.tile + m.gap), m.top)
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	if board.can_drop(col):
		ghost = UI.tile(board.next_value, m.tile, 0.35)
		ghost.position = _cell_pos(col, board.landing_row(col))
		fx_root.add_child(ghost)


func _release() -> void:
	var col := _aim_col
	_aim_col = -1
	col_hl.visible = false
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	if col >= 0:
		_do_drop(col)


func _do_drop(col: int) -> void:
	if _busy or not board.can_drop(col):
		return
	_busy = true
	if not daily:
		_undo_snap = board.snapshot()
	var value := board.next_value
	var target_r := board.landing_row(col)
	var fall := UI.tile(value, m.tile)
	fall.position = Vector2(_cell_pos(col, 0).x, m.top - m.tile - 6)
	tiles_root.add_child(fall)
	Sfx.play_drop()
	var tw := create_tween()
	tw.tween_property(fall, "position", _cell_pos(col, target_r), 0.11)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	var prev_highest := board.highest
	board.drop(col)
	var merges := board.last_merges
	var max_chain := 0
	var vib := 0
	for mg in merges:
		max_chain = maxi(max_chain, mg.chain)
		Sfx.play_merge(mg.chain, mg.value)
		vib = maxi(vib, 20 if mg.chain < 3 else 45)
		var p: Vector2i = mg.pos
		UI.burst(fx_root, _cell_pos(p.x, p.y) + Vector2(m.tile / 2, m.tile / 2),
			UI.theme().tiles.get(mg.value, UI.GOLD))
		Missions.report("merge", 1)
		Missions.report("tile", mg.value)
	if max_chain >= 2:
		Missions.report("chain", max_chain)
		_combo_banner(max_chain)
	if board.last_stones_broken > 0:
		Sfx.play("stone")
		vib = maxi(vib, 35)
		Missions.report("stone", board.last_stones_broken)
	if vib > 0:
		Sfx.vibrate(vib)   # Android's vibrate() REPLACES, so escalation needs one call
	if board.last_level_up:
		Sfx.play("levelup")
		shake(8.0)
		_toast(I18n.t("level") % I18n.digits(board.level))
		Music.set_intensity(clampf((board.level - 1) / 6.0, 0.15, 1.0))
	elif max_chain >= 3 or board.last_stones_broken > 0:
		shake(5.0)
	_render_board(merges)
	if not daily:
		_update_undo_btn()
	_spawn_score_fx(merges)
	_check_achievements(merges)
	_check_goal(prev_highest)
	if board.game_over:
		var fal_poem := _record_over()   # persist first: leaving during the pause lost the run
		await get_tree().create_timer(0.45).timeout
		_build_over_panel(fal_poem)
	_busy = false


func _combo_banner(chain: int) -> void:
	var v := UI.vp()
	var l := UI.label(I18n.t("combo") % I18n.digits(chain),
		int(clampf(v.y * 0.04, 30, 52)), true, UI.GOLD)
	l.position = Vector2(v.x / 2 - 250, m.top + m.h * 0.35)
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


func _spawn_score_fx(merges: Array) -> void:
	for mg in merges:
		var gained: int = mg.value * mg.chain
		var l := UI.label("+" + I18n.digits(gained), int(m.tile * 0.34), true, UI.GOLD)
		var p: Vector2i = mg.pos
		l.position = _cell_pos(p.x, p.y) + Vector2(0, -8)
		l.size = Vector2(m.tile, 30)
		l.z_index = 10
		fx_root.add_child(l)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(l, "position:y", l.position.y - m.tile * 0.8, 0.6)
		tw.tween_property(l, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(l.queue_free)


func _check_achievements(merges: Array) -> void:
	if merges.size() > 0:
		_try_ach("merge1")
	for mg in merges:
		if mg.value >= 2048: _try_ach("tile2048")
		if mg.value >= 1024: _try_ach("tile1024")
		if mg.value >= 256: _try_ach("tile256")
		if mg.value >= 64: _try_ach("tile64")
		if mg.chain >= 5: _try_ach("chain5")
		if mg.chain >= 3: _try_ach("chain3")
	if board.score >= 10000:
		_try_ach("score10k")


func _try_ach(id: String) -> void:
	if Store.unlock(id):
		Sfx.play("coin")
		_toast(I18n.t("ach_unlocked") % I18n.t("ach_" + id))


func _check_goal(prev_highest: int) -> void:
	if daily or Store.goal_index >= GOALS.size():
		return
	var goal: int = GOALS[Store.goal_index]
	if board.highest >= goal and prev_highest < goal:
		Store.goal_index += 1
		Store.save()
		Sfx.play("bigmerge")
		var poem := Fal.grant_milestone()
		if poem.is_empty():
			_toast(I18n.t("goal_done"))
		else:
			_toast(I18n.t("poem_unlocked"), 2.2)
		goal_lbl.text = _goal_text()


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
	p.position = Vector2((v.x - p.size.x) / 2, v.y - 140 - _toasts.size() * 72)
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


func _on_undo() -> void:
	if _busy or daily or _undo_snap.is_empty():
		return
	if _undos_left <= 0:
		# free undos spent: spend one purchased pack, which refills three
		if not Economy.use_item("undo"):
			return
		_undos_left = int(Economy.ITEMS.undo.amount)
		_toast(I18n.t("undo_extra"))
	board.restore(_undo_snap)
	_undo_snap = {}
	_undos_left -= 1
	_update_undo_btn()
	Sfx.play("ui")
	if over_panel and is_instance_valid(over_panel):
		over_panel.queue_free()
		over_panel = null
	_render_board()


func _update_undo_btn() -> void:
	var packs := Economy.count("undo")
	var label := I18n.digits(_undos_left)
	if _undos_left <= 0 and packs > 0:
		label = "+" + I18n.digits(packs)      # purchased packs still available
	undo_btn.text = "⏪ %s (%s)" % [I18n.t("undo"), label]
	undo_btn.disabled = _undo_snap.is_empty() or (_undos_left <= 0 and packs <= 0)
	undo_btn.modulate.a = 0.5 if undo_btn.disabled else 1.0


# ---------- game over / fal / tutorial / navigation ----------

## One-shot progression: safe to call once per finished game. Returns today's fal (daily mode).
func _record_over() -> Dictionary:
	if _over_recorded:
		return _over_fal
	_over_recorded = true
	Sfx.play("gameover")
	Sfx.vibrate(120)
	# Recompute the date at game over: a run started before midnight must credit the
	# day it ENDS, or the fal is granted for yesterday and today still reads as locked.
	var key := Time.get_date_string_from_system().replace("-", "") if daily else ""
	if daily:
		daily_key = key
	_over_res = Store.record_game_over(board.score, key)
	Notify.on_played()      # playing clears the nagging counter and re-plans reminders
	# Best-effort global submission: queued locally and uploaded whenever a network exists.
	Online.submit(board.score, "daily" if daily else "endless")
	Missions.report("score", board.score)
	Missions.report("game", 1)
	Store.flush()
	if Store.games_played >= 25:
		_try_ach("games25")
	_over_fal = {}
	if daily:
		_try_ach("daily1")
		# The fal is a daily-LOGIN gift now (see main.gd). Finishing the challenge pays
		# coins scaled by the run, and the run goes to the global board for a rank.
		var reward: int = clampi(200 + int(board.score / 6.0), 200, 3000)
		Store.add_coins(reward)
		_over_coins = reward
	return _over_fal


func _show_over() -> void:
	_build_over_panel(_record_over())


func _build_over_panel(fal_poem: Dictionary) -> void:
	if over_panel and is_instance_valid(over_panel):
		over_panel.queue_free()
	var res: Dictionary = _over_res
	over_panel = Control.new()
	over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_panel.add_child(dim)
	add_child(over_panel)
	var v := UI.vp()
	var cy := v.y * 0.24

	var title := UI.label(I18n.t("new_best") if res.new_best and not daily else I18n.t("game_over"),
		int(clampf(v.y * 0.045, 34, 60)))
	title.position = Vector2(v.x / 2 - 300, cy)
	title.size = Vector2(600, 70)
	over_panel.add_child(title)

	var sc := UI.label(I18n.digits(board.score), int(clampf(v.y * 0.065, 50, 88)), true, UI.GOLD)
	sc.position = Vector2(v.x / 2 - 300, cy + 80)
	sc.size = Vector2(600, 95)
	over_panel.add_child(sc)

	var sub: String
	if daily:
		sub = I18n.t("daily_best_today") % _best_text()
	else:
		sub = "%s: %s" % [I18n.t("best"), I18n.digits(Store.best_score)]
	var bl := UI.label(sub, int(clampf(v.y * 0.023, 18, 30)), false, UI.MUTED)
	bl.position = Vector2(v.x / 2 - 300, cy + 185)
	bl.size = Vector2(600, 36)
	over_panel.add_child(bl)


	var y := cy + 245
	if daily and _over_coins > 0:
		var cl := UI.label("🪙 +" + I18n.digits(_over_coins), int(clampf(v.y * 0.028, 20, 34)),
			true, UI.GOLD)
		cl.position = Vector2(v.x / 2 - 200, cy + 216)
		cl.size = Vector2(400, 40)
		over_panel.add_child(cl)
	if daily:
		var sw: float = minf(v.x - 80, 340)
		var sh_btn := UI.button("📤 " + I18n.t("share_result"), int(clampf(v.y * 0.021, 16, 26)),
			_share_daily, Vector2(sw, clampf(v.y * 0.052, 46, 64)), Color("3a6a48"))
		sh_btn.position = Vector2(v.x / 2 - sw / 2, y)
		over_panel.add_child(sh_btn)
		y += clampf(v.y * 0.052, 46, 64) + 14
	if daily and not fal_poem.is_empty():
		var fal_btn := UI.button("🔮 " + I18n.t("fal_today"), int(clampf(v.y * 0.024, 19, 30)),
			func(): shell.show_screen("fal", {"show_today": true}),
			Vector2(clampf(v.x * 0.7, 260, 420), clampf(v.y * 0.06, 52, 76)), Color("6b4f9e"))
		fal_btn.position = Vector2(v.x / 2 - fal_btn.custom_minimum_size.x / 2, y)
		fal_btn.pivot_offset = fal_btn.custom_minimum_size / 2
		over_panel.add_child(fal_btn)
		var pt := fal_btn.create_tween().set_loops()
		pt.tween_property(fal_btn, "scale", Vector2(1.05, 1.05), 0.6)
		pt.tween_property(fal_btn, "scale", Vector2.ONE, 0.6)
		y += clampf(v.y * 0.06, 52, 76) + 18

	var bw := clampf(v.x * 0.5, 200, 300)
	if not daily:   # the daily board is the same for everyone: one attempt per day
		var retry := UI.button(I18n.t("retry"), int(clampf(v.y * 0.028, 22, 36)), _on_retry,
			Vector2(bw, clampf(v.y * 0.065, 56, 84)), UI.accent())
		retry.position = Vector2(v.x / 2 - bw / 2, y)
		over_panel.add_child(retry)
		y += clampf(v.y * 0.065, 56, 84) + 16

	var menu := UI.button(I18n.t("menu"), int(clampf(v.y * 0.022, 17, 28)),
		func(): shell.show_screen("menu"), Vector2(bw * 0.8, clampf(v.y * 0.05, 44, 64)))
	menu.position = Vector2(v.x / 2 - bw * 0.4, y)
	over_panel.add_child(menu)



func _share_daily() -> void:
	Share.share_text(Share.daily_text(board.grid, board.score, Store.streak_count))
	Sfx.play("coin")
	_toast(I18n.t("copied"), 2.0)


func _on_retry() -> void:
	Sfx.play("ui")
	if daily:
		board = BoardLogic.new(int(daily_key), "daily")
	else:
		board.reset()
	_undos_left = UNDOS_PER_GAME
	_undo_snap = {}
	_over_recorded = false
	_over_fal = {}
	_over_res = {}
	_over_coins = 0
	if over_panel and is_instance_valid(over_panel):
		over_panel.queue_free()
		over_panel = null
	_update_undo_btn()
	Music.set_intensity(0.15)
	_shown_score = board.score
	_render_board()


## Returns true when the screen consumed the back press itself.
func on_back() -> bool:
	if over_panel and is_instance_valid(over_panel) and over_panel.visible:
		shell.show_screen("menu")
		return true
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


# ---------- automated QA ----------

func start_autoplay() -> void:
	_autoplay = true
	Store.first_run = false
	var plays := 0
	await get_tree().process_frame
	while plays < 3:
		while not board.game_over:
			var cols: Array = []
			for c in Board.COLS:
				if board.can_drop(c):
					cols.append(c)
			if cols.is_empty():
				break
			_do_drop(cols[randi() % cols.size()])
			await get_tree().create_timer(0.02).timeout
			while _busy:
				await get_tree().process_frame
		print("AUTOPLAY game %d over, mode=%s score=%d level=%d best=%d" %
			[plays, board.mode, board.score, board.level, Store.best_score])
		plays += 1
		if plays == 2 and not daily:
			# third run exercises the daily path
			daily = true
			daily_key = Time.get_date_string_from_system().replace("-", "")
			board = BoardLogic.new(int(daily_key), "daily")
			_undos_left = UNDOS_PER_GAME
			_over_recorded = false
			_over_fal = {}
			_over_res = {}
			relayout()
		else:
			_on_retry()
	print("AUTOPLAY_DONE fal_collected=%d coins=%d" % [Fal.collected_count(), Store.coins])
	get_tree().quit(0)
