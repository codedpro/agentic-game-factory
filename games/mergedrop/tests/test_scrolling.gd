extends GutTest
## Guards the class of bug where a list silently refuses to scroll: any Control inside a
## ScrollContainer that CONSUMES input (MOUSE_FILTER_STOP) stops the container ever seeing
## the touch drag. Panels and Labels must be IGNORE; row-covering buttons must be PASS.

const SCREENS := ["shop", "records", "fal", "settings"]


func before_each():
	Store.first_run = false
	I18n.locale = "fa"


func _scroll_containers(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is ScrollContainer:
			out.append(c)
		_scroll_containers(c, out)


func _blockers(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Control and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			# A Button that fills its row would block dragging; small buttons are fine
			# because there is space beside them to start the drag.
			out.append(c)
		_blockers(c, out)


func test_scrollable_lists_are_draggable():
	for name in SCREENS:
		get_tree().root.size = Vector2i(720, 1280)
		var sh = load("res://scripts/main.gd").new()
		add_child(sh)
		await wait_process_frames(2)
		sh.show_screen(name)
		await wait_process_frames(3)
		var scrolls: Array = []
		_scroll_containers(sh.current, scrolls)
		for sc in scrolls:
			var blockers: Array = []
			_blockers(sc, blockers)
			for b in blockers:
				var w: float = b.size.x if b.size.x > 0 else b.get_combined_minimum_size().x
				assert_lt(w, sc.size.x * 0.9,
					"%s: '%s' (%s, width %s) spans the list and will swallow scroll drags" %
					[name, b.name, b.get_class(), w])
		sh.free()


func test_decorative_panels_never_consume_input():
	var p := UI.panel()
	assert_eq(p.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"UI.panel() must be decorative by default or every list stops scrolling")
	var interactive := UI.panel(Color.BLACK, 12, true)
	assert_eq(interactive.mouse_filter, Control.MOUSE_FILTER_STOP,
		"an explicitly interactive panel should still capture input")
