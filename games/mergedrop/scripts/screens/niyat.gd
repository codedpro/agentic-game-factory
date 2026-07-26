class_name NiyatCeremony
extends Control
## The تفأل ritual: choose what is on your mind, then press and hold the closed divan
## until it opens. This is the moment the daily فال becomes an event rather than a popup.

signal opened(topic: String)

const TOPICS := ["topic_none", "topic_work", "topic_love", "topic_health",
	"topic_travel", "topic_choice"]
const HOLD_TIME := 1.6

var _topic := "topic_none"
var _held := 0.0
var _holding := false
var _done := false
var _ring: Panel
var _book: Panel
var _hold_lbl: Label
var _topic_btns: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	set_process(true)
	_build()


func _build() -> void:
	var v := UI.vp()
	var fs := int(clampf(v.y * 0.021, 16, 26))
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.09, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var title := UI.label("✨ " + I18n.t("niyat_title"), int(clampf(v.y * 0.035, 26, 44)),
		true, Economy.frame_color())
	title.position = Vector2(v.x / 2 - 300, v.y * 0.07)
	title.size = Vector2(600, 52)
	add_child(title)

	var hint := UI.label(I18n.t("niyat_hint"), fs - 2, false, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.position = Vector2(v.x / 2 - minf(v.x - 60, 480) / 2, v.y * 0.07 + 58)
	hint.size = Vector2(minf(v.x - 60, 480), fs * 3.2)
	add_child(hint)

	var tl := UI.label(I18n.t("niyat_topic"), fs - 1, true, UI.accent())
	tl.position = Vector2(v.x / 2 - 300, v.y * 0.24)
	tl.size = Vector2(600, fs * 1.8)
	add_child(tl)

	# topic chips, two per row
	var bw: float = minf((v.x - 60) / 2.0, 210)
	var bh: float = fs * 2.4
	var top: float = v.y * 0.24 + fs * 2.4
	for i in TOPICS.size():
		var key: String = TOPICS[i]
		var b := UI.button(I18n.t(key), fs - 3, func(): _pick(key), Vector2(bw, bh),
			UI.accent() if key == _topic else Color("3a4160"))
		b.position = Vector2(v.x / 2 - bw - 6 + (i % 2) * (bw + 12), top + (i / 2) * (bh + 10))
		add_child(b)
		_topic_btns.append({"key": key, "btn": b})

	# the closed divan
	var book_size: float = clampf(v.y * 0.17, 130, 210)
	_book = UI.panel(Color("241d38"), 18)
	_book.size = Vector2(book_size * 0.78, book_size)
	_book.position = Vector2(v.x / 2 - book_size * 0.39, v.y * 0.63)
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(3)
	sb.border_color = Economy.frame_color()
	sb.set_corner_radius_all(18)
	frame.add_theme_stylebox_override("panel", sb)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(frame)
	var orn := UI.label("۞", int(book_size * 0.34), true, Color(Economy.frame_color(), 0.9))
	orn.set_anchors_preset(Control.PRESET_FULL_RECT)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(orn)
	add_child(_book)

	# hold progress bar under the book
	var ring_w: float = minf(v.x - 80, 320)
	var track := UI.panel(Color("2a3040"), 10)
	track.size = Vector2(ring_w, 12)
	track.position = Vector2(v.x / 2 - ring_w / 2, v.y * 0.63 + book_size + 18)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	_ring = UI.panel(Economy.frame_color(), 10)
	_ring.size = Vector2(0, 12)
	_ring.position = track.position
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)

	_hold_lbl = UI.label(I18n.t("niyat_hold"), fs - 2, true, UI.MUTED)
	_hold_lbl.position = Vector2(v.x / 2 - 250, track.position.y + 22)
	_hold_lbl.size = Vector2(500, fs * 2)
	add_child(_hold_lbl)

	# the press target covers the book generously — it must be easy to hold
	var touch := Control.new()
	touch.position = _book.position - Vector2(30, 30)
	touch.size = _book.size + Vector2(60, 60)
	touch.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.gui_input.connect(_on_hold_input)
	add_child(touch)

	var pulse := _book.create_tween().set_loops()
	_book.pivot_offset = _book.size / 2
	pulse.tween_property(_book, "scale", Vector2(1.04, 1.04), 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_book, "scale", Vector2.ONE, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pick(key: String) -> void:
	_topic = key
	Sfx.play("ui")
	for e in _topic_btns:
		var sb: StyleBoxFlat = e.btn.get_theme_stylebox("normal")
		sb.bg_color = UI.accent() if e.key == key else Color("3a4160")


func _on_hold_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed
	elif event is InputEventScreenTouch:
		_holding = event.pressed
	if not _holding:
		_held = 0.0


func _process(delta: float) -> void:
	if _done or _ring == null:
		return
	if _holding:
		_held += delta
		if int(_held * 10) % 3 == 0:
			Sfx.vibrate(8)
	else:
		_held = maxf(0.0, _held - delta * 2.0)
	var t := clampf(_held / HOLD_TIME, 0.0, 1.0)
	var full: float = minf(UI.vp().x - 80, 320)
	_ring.size.x = full * t
	_book.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.35, 1.0), t)
	if t >= 1.0:
		_open()


func _open() -> void:
	_done = true
	set_process(false)
	Sfx.play("bigmerge")
	Sfx.vibrate(120)
	UI.burst(self, _book.position + _book.size / 2, Economy.frame_color(), 26)
	# Emit BEFORE the flourish: if this node is freed mid-animation (back button,
	# screen rebuild) the reveal must not be lost.
	opened.emit(_topic)
	var tw := _book.create_tween().set_parallel(true)
	tw.tween_property(_book, "scale", Vector2(1.5, 1.5), 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)
