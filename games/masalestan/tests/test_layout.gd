extends GutTest
## Layout regression guard: build every screen at several real device aspect ratios
## and assert laid-out buttons neither overlap nor leave the viewport. Catches the
## class of bug where a Button grows past its box to fit Persian text (LESSONS L21).

const SIZES := [
	Vector2i(720, 1280),   # 16:9 base
	Vector2i(1080, 2160),  # 18:9 tall
	Vector2i(1080, 2400),  # 20:9 very tall modern phone
	Vector2i(800, 1280),   # 16:10 short
]
const SCREENS := ["menu", "settings", "records", "shop", "masal", "board", "tasks"]


func before_each():
	Store.first_run = false
	I18n.locale = "fa"   # Persian labels are the longest — the strict case


## Visible, labelled buttons that the screen positions by hand.
## Buttons inside a ScrollContainer are skipped: they scroll, so extending past the
## viewport is correct, and invisible full-rect hit areas legitimately cover rows.
## An icon_button carries its caption in a child Label rather than Button.text, so the
## effective label is either.
func _button_caption(b: Button) -> String:
	if b.text.strip_edges() != "":
		return b.text.strip_edges()
	for c in b.get_children():
		if c is Label and c.text.strip_edges() != "":
			return c.text.strip_edges()
	return ""


func _laid_out_buttons(node: Node, out: Array, in_scroll := false) -> void:
	for c in node.get_children():
		var scrolled: bool = in_scroll or c is ScrollContainer
		if c is Button and c.visible and not scrolled and _button_caption(c) != "":
			out.append(c)
		_laid_out_buttons(c, out, scrolled)


func _rect(b: Button) -> Rect2:
	var sz: Vector2 = b.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		sz = b.get_combined_minimum_size()
	return Rect2(b.global_position, sz)


func _build(screen: String, size: Vector2i) -> Array:
	get_tree().root.size = size
	await wait_frames(2)
	var sh = load("res://scripts/main.gd").new()
	add_child(sh)
	await wait_frames(2)
	sh.show_screen(screen)
	await wait_frames(3)
	var btns: Array = []
	_laid_out_buttons(sh.current, btns)
	return [sh, btns, UI.vp()]


func test_no_overlapping_buttons():
	for size in SIZES:
		for name in SCREENS:
			var r = await _build(name, size)
			var sh = r[0]
			var btns: Array = r[1]
			assert_gt(btns.size(), 0, "%s @%s produced no buttons" % [name, size])
			for i in btns.size():
				for j in range(i + 1, btns.size()):
					var a := _rect(btns[i]).grow(-1.0)
					var b := _rect(btns[j]).grow(-1.0)
					assert_false(a.intersects(b),
						"%s @%s: '%s' %s overlaps '%s' %s" %
						[name, size, _button_caption(btns[i]), a, _button_caption(btns[j]), b])
			sh.free()


func test_buttons_stay_inside_viewport():
	for size in SIZES:
		for name in SCREENS:
			var r = await _build(name, size)
			var sh = r[0]
			var btns: Array = r[1]
			var v: Vector2 = r[2]
			for b in btns:
				var rect := _rect(b)
				assert_gte(rect.position.x, -2.0,
					"%s @%s: '%s' off left %s" % [name, size, _button_caption(b), rect])
				assert_lte(rect.position.x + rect.size.x, v.x + 2.0,
					"%s @%s: '%s' off right %s (vp %s)" % [name, size, _button_caption(b), rect, v])
				assert_lte(rect.position.y + rect.size.y, v.y + 2.0,
					"%s @%s: '%s' off bottom %s (vp %s)" % [name, size, _button_caption(b), rect, v])
			sh.free()


func after_all():
	get_tree().root.size = Vector2i(720, 1280)
