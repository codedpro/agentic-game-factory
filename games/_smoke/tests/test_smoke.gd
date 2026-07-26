extends GutTest

func test_add():
	var main = load("res://main.gd").new()
	assert_eq(main.add(2, 3), 5)
	main.free()

func test_main_scene_loads():
	var scene = load("res://main.tscn")
	assert_not_null(scene)
	var inst = scene.instantiate()
	assert_not_null(inst)
	inst.free()
