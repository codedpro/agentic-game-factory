extends Control
## Shop: themes, fal-card frames, repeatable consumables, and (when a store billing
## plugin is present) repeatable coin packs and a supporter tip.

var shell: Control
var data := {}
var _tab := "items"
var _msg: Label


func _ready() -> void:
	Economy.inventory_changed.connect(_on_changed)
	IAP.purchase_finished.connect(_on_iap)
	relayout()


func _exit_tree() -> void:
	if Economy.inventory_changed.is_connected(_on_changed):
		Economy.inventory_changed.disconnect(_on_changed)
	if IAP.purchase_finished.is_connected(_on_iap):
		IAP.purchase_finished.disconnect(_on_iap)


func _on_changed() -> void:
	relayout()


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	var v := UI.vp()
	var cx := v.x / 2.0
	UI.animate_bg(self, 4)
	var fs := int(clampf(v.y * 0.02, 15, 25))

	var title := UI.label("🎨 " + I18n.t("shop"), int(clampf(v.y * 0.036, 26, 46)))
	title.position = Vector2(cx - 300, v.y * 0.035)
	title.size = Vector2(600, 54)
	add_child(title)

	var coins := UI.label("🪙 " + I18n.digits(Store.coins), fs + 4, true, UI.GOLD)
	coins.position = Vector2(cx - 200, v.y * 0.035 + 56)
	coins.size = Vector2(400, fs * 2)
	add_child(coins)
	if Store.supporter_level > 0:
		var sup := UI.label("❤ " + I18n.t("supporter_badge") % I18n.digits(Store.supporter_level),
			fs - 2, false, Color("ff8fae"))
		sup.position = Vector2(cx - 200, v.y * 0.035 + 56 + fs * 2)
		sup.size = Vector2(400, fs * 1.6)
		add_child(sup)

	# --- tabs ---
	var tabs := [["items", I18n.t("tab_items")], ["themes", I18n.t("tab_themes")]]
	if IAP.available():
		tabs.append(["coins", I18n.t("tab_coins")])
	var tw: float = minf((v.x - 40) / tabs.size() - 8, 190)
	var tx: float = cx - (tabs.size() * (tw + 8) - 8) / 2.0
	var ty: float = v.y * 0.035 + 56 + fs * 3.4
	for t in tabs:
		var active: bool = _tab == t[0]
		var b := UI.button(t[1], fs - 1, func(): _switch(t[0]),
			Vector2(tw, fs * 2.4), UI.accent() if active else Color("3a4160"))
		b.position = Vector2(tx, ty)
		add_child(b)
		tx += tw + 8

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, ty + fs * 3.0)
	scroll.size = Vector2(v.x - 40, v.y - (ty + fs * 3.0) - clampf(v.y * 0.09, 78, 110))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(v.x - 40, 0)
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	match _tab:
		"items": _build_items(col, v, fs)
		"themes": _build_themes(col, v, fs)
		"coins": _build_coins(col, v, fs)

	var bh := clampf(v.y * 0.05, 46, 64)
	var back := UI.button("↩ " + I18n.t("back"), int(bh * 0.42),
		func(): shell.show_screen("menu"), Vector2(200, bh))
	back.position = Vector2(cx - 100, v.y - bh - 20)
	add_child(back)


func _switch(tab: String) -> void:
	_tab = tab
	Sfx.play("ui")
	relayout()


func _row(col: VBoxContainer, w: float, fs: int, icon: String, name: String, desc: String,
		owned_txt: String, btn_txt: String, btn_col: Color, cb: Callable, enabled := true) -> void:
	var card := UI.panel(UI.panel_color(), 16)
	card.custom_minimum_size = Vector2(w, fs * 6.2)
	col.add_child(card)
	var t := UI.label("%s %s" % [icon, name], fs + 1, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t.position = Vector2(14, 8)
	t.size = Vector2(w - 28, fs * 1.8)
	card.add_child(t)
	var d := UI.label(desc, fs - 3, false, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.position = Vector2(14, fs * 2.0)
	d.size = Vector2(w - 28, fs * 2.4)
	card.add_child(d)
	if owned_txt != "":
		var o := UI.label(owned_txt, fs - 3, true, UI.GOLD)
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		o.position = Vector2(14, fs * 4.3)
		o.size = Vector2(w * 0.5, fs * 1.6)
		card.add_child(o)
	var b := UI.button(btn_txt, fs - 2, cb, Vector2(w * 0.42, fs * 2.2), btn_col)
	b.position = Vector2(w * 0.05, fs * 4.0)
	b.disabled = not enabled
	b.modulate.a = 1.0 if enabled else 0.5
	card.add_child(b)


func _build_items(col: VBoxContainer, v: Vector2, fs: int) -> void:
	var w := v.x - 40
	for id in Economy.ITEMS:
		if id == "key" and not Economy.key_is_useful():
			continue
		var cost: int = Economy.item_cost(id)
		var have: int = Economy.count(id)
		_row(col, w, fs, I18n.t("item_%s_icon" % id), I18n.t("item_%s" % id),
			I18n.t("item_%s_desc" % id),
			I18n.t("owned") % I18n.digits(have) if have > 0 else "",
			"%s 🪙 %s" % [I18n.t("buy"), I18n.digits(cost)],
			Color("6b4f9e") if Economy.can_afford(cost) else Color("3a4160"),
			func(): _buy_item(id), Economy.can_afford(cost))
	var hint := UI.label(I18n.t("items_hint"), fs - 3, false, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(w, fs * 3)
	col.add_child(hint)


func _build_themes(col: VBoxContainer, v: Vector2, fs: int) -> void:
	var w := v.x - 40
	for id in Store.THEME_IDS:
		var owned: bool = id in Store.themes_owned
		var active: bool = Store.theme_active == id
		var cost: int = Store.THEME_COST[id]
		var btn := I18n.t("active") if active else (I18n.t("select") if owned
			else "%s 🪙 %s" % [I18n.t("buy"), I18n.digits(cost)])
		var c := Color("3a6a48") if active else (UI.accent() if owned else Color("6b4f9e"))
		_row(col, w, fs, "🎨", I18n.t("theme_" + id), I18n.t("theme_desc"),
			"", btn, c, func(): _on_theme(id), active or owned or Economy.can_afford(cost))
	for id in Economy.FRAMES:
		var owned: bool = id in Store.frames_owned
		var active: bool = Store.frame_active == id
		var cost: int = int(Economy.FRAMES[id].cost)
		var btn := I18n.t("active") if active else (I18n.t("select") if owned
			else "%s 🪙 %s" % [I18n.t("buy"), I18n.digits(cost)])
		var c := Color("3a6a48") if active else (UI.accent() if owned else Color("6b4f9e"))
		_row(col, w, fs, "🖼", I18n.t("frame_" + id), I18n.t("frame_desc"),
			"", btn, c, func(): _on_frame(id), active or owned or Economy.can_afford(cost))


func _build_coins(col: VBoxContainer, v: Vector2, fs: int) -> void:
	var w := v.x - 40
	for sku in IAP.PRODUCTS:
		var p: Dictionary = IAP.PRODUCTS[sku]
		var price := IAP.price(sku)
		var icon := "❤" if p.supporter > 0 else "🪙"
		_row(col, w, fs, icon, I18n.t("sku_" + sku), I18n.t("sku_%s_desc" % sku),
			"", price if price != "" else I18n.t("buy"), Color("3a6a48"),
			func(): IAP.purchase(sku))
	var note := UI.label(I18n.t("iap_note"), fs - 3, false, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(w, fs * 3)
	col.add_child(note)


# ---------- actions ----------

func _buy_item(id: String) -> void:
	if Economy.buy_item(id):
		Sfx.play("coin")
		_toast(I18n.t("bought"))
		relayout()
	else:
		_toast(I18n.t("not_enough"), true)


func _on_theme(id: String) -> void:
	if Store.theme_active == id:
		return
	if id in Store.themes_owned:
		Store.theme_active = id
		Store.save()
		Sfx.play("ui")
	elif Store.buy_theme(id):
		Sfx.play("coin")
	else:
		_toast(I18n.t("not_enough"), true)
		return
	shell.refresh_theme()
	relayout()


func _on_frame(id: String) -> void:
	if Store.frame_active == id:
		return
	if id in Store.frames_owned:
		Store.frame_active = id
		Store.save()
		Sfx.play("ui")
	elif Economy.buy_frame(id):
		Sfx.play("coin")
	else:
		_toast(I18n.t("not_enough"), true)
		return
	relayout()


func _on_iap(_sku: String, ok: bool, _msg: String) -> void:
	_toast(I18n.t("bought") if ok else I18n.t("purchase_failed"), not ok)
	relayout()


func _toast(txt: String, bad := false) -> void:
	var v := UI.vp()
	if _msg and is_instance_valid(_msg):
		_msg.queue_free()
	_msg = UI.label(txt, int(clampf(v.y * 0.021, 16, 26)), true,
		Color("e0455a") if bad else UI.GOLD)
	_msg.position = Vector2(v.x / 2 - 200, v.y - 118)
	_msg.size = Vector2(400, 38)
	_msg.z_index = 20
	add_child(_msg)
	var m := _msg
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(m):
			m.queue_free())


func on_back() -> bool:
	return false
