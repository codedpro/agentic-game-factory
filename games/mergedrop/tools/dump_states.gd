extends SceneTree
## Headless tool: play real games with the real Board logic and dump representative
## board states to JSON so the store-screenshot composer renders authentic boards.
## Run: godot --headless --path . -s tools/dump_states.gd

const BoardLogic = preload("res://scripts/board.gd")
const OUT := "/home/claude/godot/reports/board_states.json"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 4242
	var states := {}

	# 1) early endless board — clean and readable ("learn in seconds")
	var b := BoardLogic.new(7)
	for i in 9:
		_drop_smart(b)
	states["early"] = _snap(b)

	# 2) mid game under pressure: several levels in, garbage + stones, board well filled
	states["pressure"] = _play_until(1234, "endless",
		func(bd): return bd.level >= 4 and _fill(bd) >= 18)

	# 3) skilled board showing a big tile
	states["big"] = _play_until(99, "endless",
		func(bd): return bd.highest >= 256 and _fill(bd) >= 16)

	# 4) daily challenge board (preset stones, moves spent)
	states["daily"] = _play_until(20260725, "daily",
		func(bd): return bd.moves_left <= 42 and _fill(bd) >= 15)

	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(states, "  "))
	f.close()
	for k in states:
		print("STATE %s: score=%d level=%d fill=%d" % [k, states[k].score, states[k].level,
			states[k].fill])
	print("STATES_WRITTEN ", OUT)
	quit(0)


## Play mixed smart/random games until `want` is satisfied; else return the fullest state seen.
func _play_until(seed_val: int, mode: String, want: Callable) -> Dictionary:
	var best := {}
	var best_fill := -1
	for attempt in 40:
		var bd: Board = BoardLogic.new(seed_val + attempt, mode)
		while not bd.game_over:
			if rng.randf() < 0.72:
				_drop_smart(bd)
			else:
				_drop_random(bd)
			if bd.game_over:
				break
			if want.call(bd):
				return _snap(bd)
			var fl := _fill(bd)
			if fl > best_fill:
				best_fill = fl
				best = _snap(bd)
	return best


func _fill(b: Board) -> int:
	var n := 0
	for c in Board.COLS:
		for r in Board.ROWS:
			if b.grid[c][r] != 0:
				n += 1
	return n


## Greedy: prefer a column whose landing neighbours match the next value.
func _drop_smart(b: Board) -> void:
	var best := -1
	var best_score := -999
	for c in Board.COLS:
		if not b.can_drop(c):
			continue
		var r := b.landing_row(c)
		var s := 0
		if r > 0 and b.grid[c][r - 1] == b.next_value:
			s += 10
		if c > 0 and r < Board.ROWS and b.grid[c - 1][r] == b.next_value:
			s += 8
		if c < Board.COLS - 1 and r < Board.ROWS and b.grid[c + 1][r] == b.next_value:
			s += 8
		s += (Board.ROWS - r)
		if s > best_score:
			best_score = s
			best = c
	if best >= 0:
		b.drop(best)


func _drop_random(b: Board) -> void:
	var cols: Array = []
	for c in Board.COLS:
		if b.can_drop(c):
			cols.append(c)
	if not cols.is_empty():
		b.drop(cols[rng.randi() % cols.size()])


func _snap(b: Board) -> Dictionary:
	return {"grid": b.grid, "score": b.score, "level": b.level, "next": b.next_value,
		"moves_left": b.moves_left, "mode": b.mode, "highest": b.highest, "fill": _fill(b)}
