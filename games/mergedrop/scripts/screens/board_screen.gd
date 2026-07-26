extends Control
## Global scoreboard. Everything here degrades gracefully: with no network the screen still
## opens, shows the player's queued score, and never blocks or errors.

var shell: Control
var data := {}
var _rows: VBoxContainer
var _status: Label
var _nick_edit: LineEdit
var _mode := "endless"


func _ready() -> void:
	Online.board_result.connect(_on_board)
	Online.nickname_result.connect(_on_nickname)
	relayout()
	Online.fetch_board(_mode)


func _exit_tree() -> void:
	if Online.board_result.is_connected(_on_board):
		Online.board_result.disconnect(_on_board)
	if Online.nickname_result.is_connected(_on_nickname):
		Online.nickname_result.disconnect(_on_nickname)


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	var v := UI.vp()
	var cx := v.x / 2.0
	var fs := int(clampf(v.y * 0.02, 15, 25))
	UI.animate_bg(self, 4)

	var title := UI.label("🌍 " + I18n.t("leaderboard"), int(clampf(v.y * 0.036, 26, 46)))
	title.position = Vector2(cx - 300, v.y * 0.035)
	title.size = Vector2(600, 54)
	add_child(title)

	# mode switch
	var tw: float = minf((v.x - 60) / 2.0, 200)
	for i in 2:
		var m: String = ["endless", "daily"][i]
		var b := UI.button(I18n.t("play") if m == "endless" else I18n.t("daily_short"),
			fs - 2, func(): _switch(m), Vector2(tw, fs * 2.3),
			UI.accent() if _mode == m else Color("3a4160"))
		b.position = Vector2(cx - tw - 6 + i * (tw + 12), v.y * 0.035 + 58)
		add_child(b)

	var top: float = v.y * 0.035 + 58 + fs * 3.2
	if not Online.has_nickname():
		_build_nickname(cx, top, fs, v)
		top += fs * 9.0
	else:
		var who := UI.label("👤 " + Online.nickname, fs, true, UI.GOLD)
		who.position = Vector2(cx - 300, top)
		who.size = Vector2(600, fs * 1.8)
		add_child(who)
		top += fs * 2.2

	_status = UI.label(_status_text(), fs - 3, false, UI.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.position = Vector2(cx - 300, top)
	_status.size = Vector2(600, fs * 2.4)
	add_child(_status)
	top += fs * 2.8

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, top)
	scroll.size = Vector2(v.x - 40, v.y - top - clampf(v.y * 0.09, 78, 110))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(v.x - 40, 0)
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

	var bh := clampf(v.y * 0.05, 46, 64)
	var back := UI.button("↩ " + I18n.t("back"), int(bh * 0.42),
		func(): shell.show_screen("menu"), Vector2(200, bh))
	back.position = Vector2(cx - 100, v.y - bh - 20)
	add_child(back)


func _build_nickname(cx: float, top: float, fs: int, v: Vector2) -> void:
	var card := UI.panel(UI.panel_color(), 16)
	card.size = Vector2(minf(v.x - 40, 520), fs * 8.0)
	card.position = Vector2(cx - card.size.x / 2, top)
	add_child(card)
	var t := UI.label(I18n.t("nickname_hint"), fs - 2, false)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.position = Vector2(16, 10)
	t.size = Vector2(card.size.x - 32, fs * 2.6)
	card.add_child(t)
	_nick_edit = LineEdit.new()
	_nick_edit.placeholder_text = I18n.t("nickname")
	_nick_edit.max_length = 18
	_nick_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nick_edit.add_theme_font_override("font", UI.font_bold)
	_nick_edit.add_theme_font_size_override("font_size", fs)
	_nick_edit.position = Vector2(24, fs * 3.2)
	_nick_edit.size = Vector2(card.size.x - 48, fs * 2.4)
	card.add_child(_nick_edit)
	var go := UI.button(I18n.t("nickname_set"), fs - 2, _on_claim,
		Vector2(card.size.x * 0.55, fs * 2.4), UI.accent())
	go.position = Vector2(card.size.x * 0.225, fs * 5.9)
	card.add_child(go)


func _status_text() -> String:
	var bits: Array = []
	if not Online.online:
		bits.append(I18n.t("offline_note"))
	if not Store.pending_scores.is_empty():
		bits.append(I18n.t("pending_upload") % I18n.digits(Store.pending_scores.size()))
	if Online.last_rank > 0:
		bits.append(I18n.t("your_rank") % I18n.digits(Online.last_rank))
	elif Online.has_nickname():
		bits.append(I18n.t("unranked"))
	return "  •  ".join(bits)


func _switch(mode: String) -> void:
	_mode = mode
	Sfx.play("ui")
	relayout()
	Online.fetch_board(_mode)


func _on_claim() -> void:
	if _nick_edit == null:
		return
	var n := _nick_edit.text.strip_edges()
	if not Online.nickname_is_valid(n):
		_toast(I18n.t("nickname_invalid"), true)
		return
	Online.claim_nickname(n)


func _on_nickname(ok: bool, message: String) -> void:
	if ok:
		Sfx.play("coin")
		_toast(I18n.t("nickname_saved"))
		relayout()
		Online.fetch_board(_mode)
	elif message == "taken":
		_toast(I18n.t("nickname_taken"), true)
	elif message == "invalid":
		_toast(I18n.t("nickname_invalid"), true)
	else:
		_toast(I18n.t("offline_note"), true)


func _on_board(ok: bool, board: Dictionary) -> void:
	if _rows == null or not is_instance_valid(_rows):
		return
	for ch in _rows.get_children():
		ch.queue_free()
	if _status and is_instance_valid(_status):
		_status.text = _status_text()
	var v := UI.vp()
	var fs := int(clampf(v.y * 0.02, 15, 25))
	var top: Array = board.get("top", []) if ok else []
	if top.is_empty():
		var empty := UI.label(I18n.t("board_empty") if ok else I18n.t("offline_note"),
			fs, false, UI.MUTED)
		empty.custom_minimum_size = Vector2(v.x - 40, fs * 3)
		_rows.add_child(empty)
		return
	for e in top:
		var mine: bool = Online.has_nickname() and str(e.get("nickname", "")) == Online.nickname
		var row := UI.panel(UI.accent() if mine else UI.panel_color(), 12)
		row.custom_minimum_size = Vector2(0, fs * 2.4)
		var rank := int(e.get("rank", 0))
		var medal: String = ["🥇", "🥈", "🥉"][rank - 1] if rank <= 3 else I18n.digits(rank)
		var l := UI.label("%s   %s        %s" % [medal, str(e.get("nickname", "")),
			I18n.digits(int(e.get("score", 0)))], fs, mine)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.add_child(l)
		_rows.add_child(row)


func _toast(txt: String, bad := false) -> void:
	var v := UI.vp()
	var l := UI.label(txt, int(clampf(v.y * 0.021, 16, 26)), true,
		Color("e0455a") if bad else UI.GOLD)
	l.position = Vector2(v.x / 2 - 200, v.y - 120)
	l.size = Vector2(400, 38)
	l.z_index = 20
	add_child(l)
	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(l):
			l.queue_free())


func on_back() -> bool:
	return false
