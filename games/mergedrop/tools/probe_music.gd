extends SceneTree
func _init():
	await process_frame
	await process_frame
	var s = load("res://assets/sfx/music_calm.wav")
	print("stream class: ", s.get_class() if s else "NULL")
	if s is AudioStreamWAV:
		print("  loop_mode=", s.loop_mode, " loop_end=", s.loop_end, " len=", s.get_length())
	var p = AudioStreamPlayer.new()
	get_root().add_child(p)
	p.stream = s
	p.play()
	await process_frame
	print("playing=", p.playing, " bus=", p.bus, " audio driver=", AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?")
	print("bus count=", AudioServer.bus_count, " master volume db=", AudioServer.get_bus_volume_db(0), " muted=", AudioServer.is_bus_mute(0))
	quit(0)
