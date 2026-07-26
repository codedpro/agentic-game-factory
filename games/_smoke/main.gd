extends Node

func add(a: int, b: int) -> int:
	return a + b

func _ready() -> void:
	print("SMOKE_OK add(2,3)=", add(2, 3))
	if OS.has_feature("headless_quit"):
		get_tree().quit(0)
