extends Node
## Autoload "Sfx" — pooled playback, pitch jitter, chain-aware merge sounds.

var _streams := {}
var _pool: Array = []
const POOL_SIZE := 10
const NAMES := ["drop", "drop2", "drop3", "merge", "merge2", "merge3",
	"bigmerge", "stone", "levelup", "coin", "ui", "gameover"]


func _ready() -> void:
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play(name: String, pitch: float = 1.0) -> void:
	if not Store.sound_on or not _streams.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = pitch * randf_range(0.96, 1.04)
			p.play()
			return


func play_drop() -> void:
	play(["drop", "drop2", "drop3"][randi() % 3])


func play_merge(chain: int, value: int) -> void:
	if value >= 256 or chain >= 4:
		play("bigmerge")
	elif chain >= 3:
		play("merge3", 1.0 + 0.05 * chain)
	elif chain == 2:
		play("merge2")
	else:
		play("merge")


func vibrate(ms: int = 25) -> void:
	if Store.vibrate_on:
		Input.vibrate_handheld(ms)