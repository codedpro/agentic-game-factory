extends GutTest
## Guards against parse errors in lazily-loaded scripts (screens etc.):
## a script that fails to parse would otherwise only explode when its screen opens.


func _collect(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var path := dir.path_join(f)
		if d.current_is_dir() and not f.begins_with("."):
			_collect(path, out)
		elif f.ends_with(".gd"):
			out.append(path)
		f = d.get_next()


func test_all_scripts_parse():
	var scripts: Array = []
	_collect("res://scripts", scripts)
	# tests/ too: GUT silently SKIPS a test file that fails to parse, so a broken
	# test file otherwise reports as "all tests passed" (LESSONS L25).
	_collect("res://tests", scripts)
	_collect("res://tools", scripts)
	assert_gt(scripts.size(), 5, "expected to find project scripts")
	for path in scripts:
		var s = load(path)
		assert_not_null(s, "failed to load " + path)
		if s != null:
			assert_true(s.can_instantiate(), "parse error in " + path)


func test_all_scenes_load():
	var scene = load("res://main.tscn")
	assert_not_null(scene)
	assert_true(scene.can_instantiate())
