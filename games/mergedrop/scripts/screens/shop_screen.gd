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

	var title := UI.title("shop", I18n.t("shop"), int(clampf(v.y * 0.036, 26, 46)),
		Vector2(600, 54))
	title.position = Vector2(cx - 300, v.y * 0.035)
	add_child(title)

	var coins := UI.title("coin", I18n.digits(Store.coins), fs + 4,
		Vector2(400, fs * 2), UI.GOLD)
	coins.position = Vector2(cx - 200, v.y * 0.035 + 56)
	add_child(coins)
	if Store.supporter_level > 0:
		var sup := UI.title("heart",
			I18n.t("supporter_badge") % I18n.digits(Store.supporter_level),
			fs - 2, Vector2(400, fs * 1.6), Color("ff8fae"))
		sup.position = Vector2(cx - 200, v.y * 0.035 + 56 + fs * 2)
		add_child(sup)

	# --- tabs ---
	var tabs := [["items", I18n.t("tab_items")], ["themes", I18n.t("tab_themes")],
		["coins", I18n.t("tab_coins")]]
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


## One catalogue row. `icon_name` is an icon ASSET name, never an emoji: the emoji font
## maps some symbols to unrelated glyphs, and mixing the two looks unfinished.
func _row(col: VBoxContainer, w: float, fs: int, icon_name: String, name: String, desc: String,
		owned_txt: String, btn_txt: String, btn_col: Color, cb: Callable, enabled := true,
		btn_icon := "coin") -> void:
	var card := UI.panel(UI.panel_color(), 16)
	card.custom_minimum_size = Vector2(w, fs * 6.2)
	col.add_child(card)
	var ic_size: float = fs * 1.9
	if UI.has_icon(icon_name):
		var ic := UI.icon(icon_name, ic_size, UI.accent())
		ic.position = Vector2(w - ic_size - 14, 10)
		card.add_child(ic)
	var t := UI.label(name, fs + 1, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t.position = Vector2(14, 8)
	t.size = Vector2(w - 28 - ic_size - 10, fs * 1.8)
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
		o.position = Vector2(w * 0.5, fs * 4.3)
		o.size = Vector2(w * 0.45, fs * 1.6)
		card.add_child(o)
	var b := UI.icon_button(btn_icon, btn_txt, cb, Vector2(w * 0.42, fs * 2.3), btn_col)
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
			"%s %s" % [I18n.t("buy"), I18n.digits(cost)],
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
			else "%s %s" % [I18n.t("buy"), I18n.digits(cost)])
		var c := Color("3a6a48") if active else (UI.accent() if owned else Color("6b4f9e"))
		_row(col, w, fs, "shop", I18n.t("theme_" + id), I18n.t("theme_desc"),
			"", btn, c, func(): _on_theme(id), active or owned or Economy.can_afford(cost))
	for id in Economy.FRAMES:
		var owned: bool = id in Store.frames_owned
		var active: bool = Store.frame_active == id
		var cost: int = int(Economy.FRAMES[id].cost)
		var btn := I18n.t("active") if active else (I18n.t("select") if owned
			else "%s %s" % [I18n.t("buy"), I18n.digits(cost)])
		var c := Color("3a6a48") if active else (UI.accent() if owned else Color("6b4f9e"))
		_row(col, w, fs, "frame", I18n.t("frame_" + id), I18n.t("frame_desc"),
			"", btn, c, func(): _on_frame(id), active or owned or Economy.can_afford(cost))


## The coin store. Always shown: if billing is not ready the packs are still listed with a
## plain explanation, because an invisible tab reads as "there is no way to buy coins".
func _build_coins(col: VBoxContainer, v: Vector2, fs: int) -> void:
	var w := v.x - 40
	var reason := IAP.unavailable_reason()
	if reason != "":
		var warn := UI.panel(Color("2a2230"), 14)
		warn.custom_minimum_size = Vector2(w, fs * 4.2)
		col.add_child(warn)
		var wl := UI.label("%s\n%s" % [I18n.t("iap_unavailable"), I18n.t("iap_" + reason)],
			fs - 2, false, Color("ffc76f"))
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.set_anchors_preset(Control.PRESET_FULL_RECT)
		warn.add_child(wl)

	# Two columns per card: the action on the left (tag badge above the buy button), the
	# product on the right (name, amount, bonus badge, coin icon). Keeping them in separate
	# x-ranges is what stops the price sitting on top of the coin amount.
	for sku in IAP.PRODUCT_ORDER:
		var p: Dictionary = IAP.PRODUCTS.get(sku, {})
		if p.is_empty():
			continue
		var supporter: bool = int(p.get("supporter", 0)) > 0
		var tag := String(p.get("tag", ""))
		var accent := Color("ff8fae") if supporter else (
			Color("ffc76f") if tag == "best" else UI.GOLD)
		var h: float = fs * 6.4
		var card := UI.panel(Color("2b3350") if tag != "" else Color("232a3d"), 16)
		card.custom_minimum_size = Vector2(w, h)
		col.add_child(card)

		# --- left column: what the player does ---
		var btn_w: float = minf(w * 0.42, fs * 8.0)
		if tag != "":
			var tb := UI.panel(accent, 10)
			tb.size = Vector2(btn_w, fs * 1.5)
			tb.position = Vector2(fs * 0.8, fs * 0.6)
			card.add_child(tb)
			var tl := UI.label(I18n.t("tag_" + tag), fs - 4, true, Color("161b28"))
			tl.set_anchors_preset(Control.PRESET_FULL_RECT)
			tb.add_child(tl)
		var price := IAP.price(sku)
		var btn_txt: String = price if price != "" else I18n.t("buy_now")
		var buy := UI.icon_button("cart", btn_txt, func(): _buy_sku(sku),
			Vector2(btn_w, fs * 2.4),
			Color("2e7d5b") if reason == "" else Color("3a4160"), Color.WHITE)
		buy.position = Vector2(fs * 0.8, fs * 3.0 if tag != "" else (h - fs * 2.4) / 2.0)
		buy.disabled = reason != ""
		buy.modulate.a = 1.0 if reason == "" else 0.55
		card.add_child(buy)

		# --- right column: what the player gets ---
		var ic_size: float = fs * 2.2
		var ic := UI.icon("heart" if supporter else "coin", ic_size, accent)
		ic.position = Vector2(w - fs * 0.8 - ic_size, fs * 1.0)
		card.add_child(ic)

		var col_x: float = fs * 0.8 + btn_w + fs * 0.8
		var col_w: float = w - col_x - fs * 0.8 - ic_size - fs * 0.4
		var name_l := UI.label(I18n.t("sku_" + sku),
			UI.fit_font_size(I18n.t("sku_" + sku), col_w, fs), true, Color.WHITE)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_l.position = Vector2(col_x, fs * 0.6)
		name_l.size = Vector2(col_w, fs * 1.6)
		card.add_child(name_l)

		var amount := I18n.t("coins_amount") % I18n.digits(int(p.get("coins", 0)))
		var amt := UI.label(amount, UI.fit_font_size(amount, col_w, fs + 4), true, accent)
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amt.position = Vector2(col_x, fs * 2.4)
		amt.size = Vector2(col_w, fs * 2.0)
		card.add_child(amt)

		var bonus := int(p.get("bonus", 0))
		if bonus > 0:
			var bw: float = fs * 6.0
			var bb := UI.panel(Color("2e7d5b"), 10)
			bb.size = Vector2(bw, fs * 1.4)
			bb.position = Vector2(w - fs * 0.8 - bw, fs * 4.6)
			card.add_child(bb)
			var bl := UI.label(I18n.t("bonus_badge") % I18n.digits(bonus), fs - 4, true)
			bl.set_anchors_preset(Control.PRESET_FULL_RECT)
			bb.add_child(bl)

	var note := UI.label(I18n.t("iap_note"), fs - 3, false, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(w, fs * 3)
	col.add_child(note)


func _buy_sku(sku: String) -> void:
	if IAP.unavailable_reason() != "":
		_toast(I18n.t("iap_unavailable"), true)
		return
	IAP.purchase(sku)


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
