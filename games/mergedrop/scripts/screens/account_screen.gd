extends Control
## Sign-in / sign-up. Reached only from the shop's coin tab, because an account is
## needed only to buy — the screen says so rather than making the player guess why a
## game suddenly wants an email.

var shell: Control
var data := {}

var _mode := "sign_up"        # "sign_up" | "sign_in"
var _email: LineEdit
var _password: LineEdit
var _msg: Label
var _busy_note: Label


func _ready() -> void:
	Account.auth_result.connect(_on_result)
	if Account.signed_in():
		_mode = "signed_in"
	relayout()


func _exit_tree() -> void:
	if Account.auth_result.is_connected(_on_result):
		Account.auth_result.disconnect(_on_result)


func relayout() -> void:
	for ch in get_children():
		ch.queue_free()
	var v := UI.vp()
	var cx := v.x / 2.0
	UI.animate_bg(self, 4)
	var fs := int(clampf(v.y * 0.02, 15, 25))

	var title := UI.title("heart", I18n.t("account"), int(clampf(v.y * 0.036, 26, 46)),
		Vector2(600, 54))
	title.position = Vector2(cx - 300, v.y * 0.04)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, v.y * 0.04 + 64)
	scroll.size = Vector2(v.x - 40, v.y - (v.y * 0.04 + 64) - clampf(v.y * 0.09, 78, 110))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(v.x - 40, 0)
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	if _mode == "signed_in":
		_build_signed_in(col, v.x - 40, fs)
	else:
		_build_form(col, v.x - 40, fs)

	var bh := clampf(v.y * 0.05, 46, 64)
	var back := UI.button("↩ " + I18n.t("back"), int(bh * 0.42),
		func(): shell.show_screen("shop"), Vector2(200, bh))
	back.position = Vector2(cx - 100, v.y - bh - 20)
	add_child(back)


func _note(col: VBoxContainer, w: float, fs: int, text: String, color: Color,
		bg: Color) -> void:
	var panel := UI.panel(bg, 14)
	panel.custom_minimum_size = Vector2(w, fs * 4.0)
	col.add_child(panel)
	var l := UI.label(text, fs - 3, false, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(l)


func _field(col: VBoxContainer, w: float, fs: int, label_key: String, hint_key: String,
		secret: bool) -> LineEdit:
	var box := UI.panel(Color("232a3d"), 14)
	box.custom_minimum_size = Vector2(w, fs * 5.4)
	col.add_child(box)
	var lab := UI.label(I18n.t(label_key), fs - 2, true, UI.MUTED)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.position = Vector2(14, fs * 0.5)
	lab.size = Vector2(w - 28, fs * 1.5)
	box.add_child(lab)
	var edit := LineEdit.new()
	edit.placeholder_text = I18n.t(hint_key)
	edit.secret = secret
	edit.max_length = 254 if not secret else 128
	edit.alignment = HORIZONTAL_ALIGNMENT_LEFT   # emails and passwords are LTR
	edit.add_theme_font_override("font", UI.font_bold)
	edit.add_theme_font_size_override("font_size", fs)
	edit.position = Vector2(16, fs * 2.3)
	edit.size = Vector2(w - 32, fs * 2.6)
	box.add_child(edit)
	return edit


func _build_form(col: VBoxContainer, w: float, fs: int) -> void:
	_note(col, w, fs, I18n.t("account_why"), Color("9fe8c4"), Color("1e2a24"))

	_email = _field(col, w, fs, "email", "email_hint", false)
	_password = _field(col, w, fs, "password", "password_hint", true)

	var primary_key := "sign_up" if _mode == "sign_up" else "sign_in"
	var go := UI.icon_button("heart", I18n.t(primary_key), _submit,
		Vector2(w, fs * 2.8), Color("2e7d5b"), Color.WHITE)
	col.add_child(go)

	var swap_key := "have_account" if _mode == "sign_up" else "no_account"
	var swap := UI.button(I18n.t(swap_key), fs - 3, _toggle_mode,
		Vector2(w, fs * 2.4), Color("3a4160"))
	col.add_child(swap)

	_msg = UI.label("", fs - 2, true, Color("ff8fae"))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(w, fs * 2.4)
	col.add_child(_msg)

	# Stated before the player chooses a password, not buried afterwards.
	if _mode == "sign_up":
		_note(col, w, fs, I18n.t("account_no_recovery"), Color("ffc76f"), Color("2a2230"))
	_note(col, w, fs, I18n.t("account_privacy"), UI.MUTED, Color("1b2030"))


func _build_signed_in(col: VBoxContainer, w: float, fs: int) -> void:
	_note(col, w, fs, I18n.t("signed_in_as") % Account.email, Color("9fe8c4"),
		Color("1e2a24"))
	if Purchases.pending() > 0:
		_note(col, w, fs, I18n.t("receipt_pending") % I18n.digits(Purchases.pending()),
			Color("ffc76f"), Color("2a2230"))
	var out := UI.button(I18n.t("sign_out"), fs - 2, _sign_out,
		Vector2(w, fs * 2.6), Color("6b4f9e"))
	col.add_child(out)
	_note(col, w, fs, I18n.t("account_privacy"), UI.MUTED, Color("1b2030"))


func _toggle_mode() -> void:
	_mode = "sign_in" if _mode == "sign_up" else "sign_up"
	Sfx.play("ui")
	relayout()


func _submit() -> void:
	if Account.busy():
		return
	var e := _email.text if _email != null else ""
	var p := _password.text if _password != null else ""
	if _msg != null:
		_msg.add_theme_color_override("font_color", UI.MUTED)
		_msg.text = I18n.t("working")
	if _mode == "sign_up":
		Account.register(e, p)
	else:
		Account.login(e, p)


func _on_result(ok: bool, reason: String) -> void:
	if ok:
		Sfx.play("coin")
		_mode = "signed_in"
		relayout()
		# Straight back to the shop: the player came here to buy, not to admire a form.
		if data.get("then", "") == "shop":
			shell.show_screen("shop")
		return
	Sfx.play("bad")
	if _msg == null:
		return
	_msg.add_theme_color_override("font_color", Color("ff8fae"))
	var key := "err_" + reason
	_msg.text = I18n.t(key) if I18n.T.has(key) else I18n.t("err_offline")


func _sign_out() -> void:
	Account.sign_out()
	_mode = "sign_in"
	Sfx.play("ui")
	relayout()
