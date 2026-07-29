extends Node
## Autoload "Music" — two synced stems; energy stem swells with game intensity.

var _calm: AudioStreamPlayer
var _energy: AudioStreamPlayer


func _ready() -> void:
	_calm = _mk_player("res://assets/sfx/music_calm.wav", -4.0)
	_energy = _mk_player("res://assets/sfx/music_energy.wav", -60.0)
	apply()


func _mk_player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	add_child(p)
	if ResourceLoader.exists(path):
		# Looping is authored in the .import (edit/loop_mode=1), but a stale import cache
		# silently ships a non-looping stream — the music then played once and stopped
		# forever. Enforce it here too, on a duplicate so the cached resource is untouched.
		var stream := load(path)
		if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			# loop_end is in FRAMES; data.size() is bytes of (possibly QOA) data, not frames.
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		p.stream = stream
	return p


func apply() -> void:
	if Store.music_on:
		if _calm.stream and not _calm.playing:
			_calm.play()
			_energy.play()
	else:
		_calm.stop()
		_energy.stop()


## intensity 0..1 — 0 = menu/early game (calm only), 1 = high level (full energy layer).
func set_intensity(x: float) -> void:
	x = clampf(x, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_energy, "volume_db", lerpf(-60.0, -3.0, x), 0.8)