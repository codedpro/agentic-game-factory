extends Node
## Autoload "UI" — themes, fonts, juiced widget factories, responsive metrics.

const THEMES := {
	"classic": {
		"bg": Color("1c202e"), "panel": Color("272c3d"), "accent": Color("4f8cf0"),
		"tile": Color("3a4160"), "tile_hot": Color("4f8cf0"), "slot": Color("222738"),
	},
	"sunset": {
		"bg": Color("241a26"), "panel": Color("342331"), "accent": Color("ff8c5a"),
		"tile": Color("55374a"), "tile_hot": Color("ff8c5a"), "slot": Color("2c202e"),
	},
	"neon": {
		"bg": Color("0a0e14"), "panel": Color("131a24"), "accent": Color("00e5ff"),
		"tile": Color("1c2836"), "tile_hot": Color("00e5ff"), "slot": Color("101722"),
	},
	"garden": {
		"bg": Color("15241c"), "panel": Color("1f3328"), "accent": Color("6fcf6f"),
		"tile": Color("2a4434"), "tile_hot": Color("6fcf6f"), "slot": Color("1a2c21"),
	},
}
const MUTED := Color("8b93b0")
const GOLD := Color("f2c230")

var font_reg: FontFile
var font_bold: FontFile


func _ready() -> void:
	font_reg = load("res://assets/fonts/Vazirmatn-Regular.ttf")
	font_bold = load("res://assets/fonts/Vazirmatn-Bold.ttf")
	# Vazirmatn has no emoji glyphs; without this fallback every 🔮/🏆/⚙ renders as tofu.
	var emoji := load("res://assets/fonts/NotoEmoji-Regular.ttf")
	if emoji:
		font_reg.fallbacks = [emoji]
		font_bold.fallbacks = [emoji]


func theme() -> Dictionary:
	return THEMES.get(Store.theme_active, THEMES.classic)


func bg_color() -> Color:
	return theme().bg


func panel_color() -> Color:
	return theme().panel


func accent() -> Color:
	return theme().accent


func vp() -> Vector2:
	return get_viewport().get_visible_rect().size


## Single source of truth for the game screen's layout. pipeline/make_screenshots.py
## mirrors these numbers — update both together (it doubles as the layout oracle).
func board_metrics() -> Dictionary:
	var v := vp()
	var top_h: float = clampf(v.y * 0.085, 56, 90)          # HUD strip
	var wheel_d: float = minf(v.x * 0.82, v.y * 0.36)       # letter-wheel diameter
	var wheel_cy: float = v.y - wheel_d / 2.0 - 18          # wheel centre y
	var preview_h: float = clampf(v.y * 0.065, 44, 64)      # formed-word preview row
	var proverb_y: float = top_h + 10                       # proverb slots panel
	var proverb_h: float = wheel_cy - wheel_d / 2.0 - preview_h - proverb_y - 24
	var tile: float = clampf(wheel_d * 0.19, 40, 76)        # wheel letter tile
	return {"top_h": top_h, "wheel_d": wheel_d, "wheel_cx": v.x / 2.0,
		"wheel_cy": wheel_cy, "preview_h": preview_h, "proverb_y": proverb_y,
		"proverb_h": proverb_h, "tile": tile, "margin": 16.0}


func label(txt: String, size: int, bold := true, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", font_bold if bold else font_reg)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func button(txt: String, size: int, cb: Callable, minsize := Vector2.ZERO, bg := Color("3a4160")) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = bg.lightened(0.18)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	b.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.bg_color = bg.lightened(0.12)
	sb2.shadow_color = Color(bg.lightened(0.3), 0.35)
	sb2.shadow_size = 8
	b.add_theme_stylebox_override("hover", sb2)
	b.add_theme_stylebox_override("pressed", sb2)
	if minsize != Vector2.ZERO:
		b.custom_minimum_size = minsize
		b.size = minsize
		# A Button grows past custom_minimum_size to fit its text, which silently
		# overlaps neighbours in hand-positioned layouts. Clipping keeps the box exact.
		b.clip_text = true
	b.pressed.connect(cb)
	return b


## Decorative by default: a Panel defaults to MOUSE_FILTER_STOP, and inside a
## ScrollContainer that swallows the touch drag so the list refuses to scroll.
func panel(bg_c: Color = Color("272c3d"), radius := 20, interactive := false) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_c
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	return p


## Letter tile for the wheel and formed words. `hot` = selected/active state.
func tile(ch: String, size: float, hot := false, alpha := 1.0) -> Panel:
	var col: Color = theme().tile_hot if hot else theme().tile
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(size * 0.22))
	sb.set_border_width_all(maxi(2, int(size * 0.025)))
	sb.border_color = col.lightened(0.22)
	if hot:
		sb.shadow_color = Color(col, 0.55)
		sb.shadow_size = int(size * 0.1)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	p.size = Vector2(size, size)
	p.modulate.a = alpha
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(ch, int(size * 0.52))
	l.add_theme_color_override("font_outline_color", col.darkened(0.45))
	l.add_theme_constant_override("outline_size", maxi(2, int(size * 0.03)))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.name = "Ch"
	p.add_child(l)
	return p


## ---------------------------------------------------------------- icons

const ICON_DIR := "res://assets/icons/"
var _icon_cache := {}


## A tintable icon. Art is a white silhouette with alpha, so `color` fully controls it.
func icon(name: String, size: float, color := Color.WHITE) -> TextureRect:
	var tex := _icon_tex(name)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size = Vector2(size, size)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _icon_tex(name: String) -> Texture2D:
	if _icon_cache.has(name):
		return _icon_cache[name]
	var path := ICON_DIR + name + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icon_cache[name] = tex
	return tex


## A heading: text plus a real icon on the trailing (right) side, centred as one group.
## Replaces the old "emoji + space + text" prefix, which drew whatever glyph the emoji
## font happened to map (a coin rendered as a bank) and never matched the icon set.
func title(icon_name: String, txt: String, size: int, box: Vector2,
		color := Color.WHITE) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = box
	holder.size = box
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic_size: float = size * 1.1
	var gap: float = size * 0.4
	var text_w: float = font_bold.get_string_size(
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var group: float = minf(text_w + gap + ic_size, box.x)
	var left: float = (box.x - group) / 2.0
	var l := label(txt, size, true, color)
	l.position = Vector2(left, 0)
	l.size = Vector2(maxf(group - ic_size - gap, 1.0), box.y)
	holder.add_child(l)
	if has_icon(icon_name):
		var ic := icon(icon_name, ic_size, color)
		ic.position = Vector2(left + group - ic_size, (box.y - ic_size) / 2.0)
		holder.add_child(ic)
	return holder


func has_icon(name: String) -> bool:
	return _icon_tex(name) != null


## Largest font size at which `text` still fits `max_w`. Persian labels are long, and a
## clipped label is worse than a slightly smaller one (user feedback).
func fit_font_size(text: String, max_w: float, start_size: int, min_size := 11) -> int:
	var f := font_bold
	var s := start_size
	while s > min_size and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 1
	return s


## A button with a real icon and a label that always fits. This replaces emoji-in-text
## buttons: the icon sits in its own tinted chip and never competes with the text.
func icon_button(icon_name: String, text: String, cb: Callable, box: Vector2,
		bg := Color("232a3d"), accent_col := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.custom_minimum_size = box
	b.size = box
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var tint: Color = accent() if accent_col == Color.TRANSPARENT else accent_col

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(minf(box.y * 0.32, 20)))
	sb.set_border_width_all(2)
	sb.border_color = bg.lightened(0.14)
	sb.border_width_top = 3
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	b.add_theme_stylebox_override("normal", sb)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = bg.lightened(0.10)
	hov.border_color = tint
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(cb)

	var pad: float = box.y * 0.16
	var chip: float = box.y - pad * 2.0
	# icon chip on the trailing side (RTL-friendly: sits at the right edge)
	if has_icon(icon_name):
		var holder := panel(Color(0.05, 0.07, 0.12, 0.55), int(chip * 0.3))
		holder.size = Vector2(chip, chip)
		holder.position = Vector2(box.x - chip - pad, pad)
		b.add_child(holder)
		var ic := icon(icon_name, chip * 0.62, tint)
		ic.position = Vector2(chip * 0.19, chip * 0.19)
		holder.add_child(ic)

	var text_w: float = box.x - (chip + pad * 2.4 if has_icon(icon_name) else pad * 2.0) - pad
	var size := fit_font_size(text, text_w, int(box.y * 0.34))
	var l := label(text, size, true)
	l.position = Vector2(pad, 0)
	l.size = Vector2(text_w, box.y)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A label that cannot fit even at the smallest size wraps rather than overflowing.
	if font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > text_w:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(l)
	return b


## Soft drifting glow blobs — call on any screen for a living background.
func animate_bg(parent: Control, count := 5) -> void:
	var v := vp()
	var rngl := RandomNumberGenerator.new()
	for i in count:
		var blob := panel(Color(accent(), 0.05), 999)
		var s := rngl.randf_range(v.x * 0.3, v.x * 0.6)
		blob.size = Vector2(s, s)
		blob.position = Vector2(rngl.randf_range(-s / 2, v.x - s / 2),
			rngl.randf_range(-s / 2, v.y - s / 2))
		blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blob.z_index = -1
		parent.add_child(blob)
		var tw := blob.create_tween().set_loops()
		var target := blob.position + Vector2(rngl.randf_range(-90, 90), rngl.randf_range(-90, 90))
		tw.tween_property(blob, "position", target, rngl.randf_range(6.0, 11.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(blob, "position", blob.position, rngl.randf_range(6.0, 11.0))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## One-shot colored particle burst at a position.
func burst(parent: Control, at: Vector2, color: Color, amount := 14) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	parent.add_child(p)
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
