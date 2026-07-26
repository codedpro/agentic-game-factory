class_name Board
extends RefCounted
## Pure game logic — no scene dependencies, fully unit-testable.
## Grid is grid[col][row] with row 0 at the BOTTOM. 0 = empty, STONE = unmergeable blocker.

const COLS := 5
const ROWS := 7
const STONE := -1
const DAILY_MOVES := 60
const DAILY_STONES := 7

var grid: Array = []
var score: int = 0
var highest: int = 2
var next_value: int = 2
var game_over := false
var mode := "endless"          # "endless" | "daily"
var level := 1
var moves_left := 0            # daily mode only
var drops_count := 0
var rng := RandomNumberGenerator.new()

# per-drop event data for UI:
var last_merges: Array = []    # [{pos, value, chain}]
var last_stones_broken := 0
var last_level_up := false
var value_seq: PackedInt32Array = PackedInt32Array()   # shared modes: fixed tile order
var seq_index := 0
var _chain := 0
var _drops_in_level := 0


func _init(seed_val: int = -1, game_mode: String = "endless") -> void:
	mode = game_mode
	reset(seed_val)


func reset(seed_val: int = -1) -> void:
	grid = []
	for c in COLS:
		var col: Array = []
		col.resize(ROWS)
		col.fill(0)
		grid.append(col)
	score = 0
	highest = 2
	game_over = false
	level = 1
	drops_count = 0
	_drops_in_level = 0
	last_merges = []
	last_stones_broken = 0
	last_level_up = false
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	value_seq = PackedInt32Array()
	seq_index = 0
	if mode == "daily":
		moves_left = DAILY_MOVES
		_place_daily_stones()
		_preroll_values()
	next_value = _roll_value()


## Daily boards start with a deterministic stone pattern (same for everyone that day).
func _place_daily_stones() -> void:
	var placed := 0
	while placed < DAILY_STONES:
		var c := rng.randi() % COLS
		var r := landing_row(c)
		if r >= 0 and r < 3:
			grid[c][r] = STONE
			placed += 1


func can_drop(col: int) -> bool:
	return not game_over and col >= 0 and col < COLS and grid[col][ROWS - 1] == 0


func landing_row(col: int) -> int:
	for r in ROWS:
		if grid[col][r] == 0:
			return r
	return -1


## Drops before the next garbage row arrives (endless mode pressure).
func level_length() -> int:
	return maxi(6, 13 - level)


func drops_until_garbage() -> int:
	return level_length() - _drops_in_level


## Drop the pending tile into a column. Returns true if the move was legal.
func drop(col: int) -> bool:
	if not can_drop(col):
		return false
	last_merges = []
	last_stones_broken = 0
	last_level_up = false
	_chain = 0
	drops_count += 1
	var row := landing_row(col)
	grid[col][row] = next_value
	_resolve(Vector2i(col, row))
	if mode == "endless":
		_drops_in_level += 1
		if _drops_in_level >= level_length() and not _board_full():
			level += 1
			_drops_in_level = 0
			last_level_up = true
			_insert_garbage_row()
			# The new row can create fresh matches; settle them before scoring the turn.
			if not game_over:
				_resolve(Vector2i(-1, -1))
	elif mode == "daily":
		moves_left -= 1
	next_value = _roll_value()
	# `or`, not `=`: _insert_garbage_row() may already have ended the game by
	# overflowing a column, and _board_full() alone would clear that flag.
	game_over = game_over or _board_full() or (mode == "daily" and moves_left <= 0)
	return true


## Push a new row up from the bottom. A column already full overflows -> game over.
func _insert_garbage_row() -> void:
	for c in COLS:
		if grid[c][ROWS - 1] != 0:
			game_over = true
			return
	var vals := [2, 4, 8]
	for c in COLS:
		for r in range(ROWS - 1, 0, -1):
			grid[c][r] = grid[c][r - 1]
		if level >= 2 and rng.randf() < 0.18:
			grid[c][0] = STONE
		else:
			grid[c][0] = vals[rng.rand_weighted(PackedFloat32Array([3, 3, 2]))]


func _resolve(start: Vector2i) -> void:
	var active := start
	while true:
		var recorded := last_merges.size()
		active = _gravity_track(active)
		# A merged tile can fall after merging; report where it actually ended up so the
		# particles, +score label and pop animation land on the tile, not one row above.
		if recorded > 0:
			last_merges[recorded - 1]["pos"] = active
		if _merge_at(active):
			continue
		active = _find_any_merge()
		if active.x < 0:
			break
		if not _merge_at(active):
			break
	_apply_gravity()


## Merge all equal neighbors into cell p; adjacent stones shatter for bonus points.
func _merge_at(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= COLS or p.y < 0 or p.y >= ROWS:
		return false
	var v: int = grid[p.x][p.y]
	if v <= 0:
		return false
	var eq: Array = []
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var nc: int = p.x + d.x
		var nr: int = p.y + d.y
		if nc >= 0 and nc < COLS and nr >= 0 and nr < ROWS and grid[nc][nr] == v:
			eq.append(Vector2i(nc, nr))
	if eq.is_empty():
		return false
	for q in eq:
		grid[q.x][q.y] = 0
	var nv: int = v * (1 << eq.size())
	grid[p.x][p.y] = nv
	_chain += 1
	score += nv * _chain
	highest = maxi(highest, nv)
	last_merges.append({"pos": p, "value": nv, "chain": _chain})
	var footprint: Array = eq.duplicate()
	footprint.append(p)
	for cell in footprint:
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var nc: int = cell.x + d.x
			var nr: int = cell.y + d.y
			if nc >= 0 and nc < COLS and nr >= 0 and nr < ROWS and grid[nc][nr] == STONE:
				grid[nc][nr] = 0
				last_stones_broken += 1
				score += 25
	return true


## Apply gravity everywhere and return the new position of the tile at p.
func _gravity_track(p: Vector2i) -> Vector2i:
	var below := 0
	var valid: bool = p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS \
		and grid[p.x][p.y] != 0
	if valid:
		for r in p.y:
			if grid[p.x][r] != 0:
				below += 1
	_apply_gravity()
	return Vector2i(p.x, below) if valid else p


## First cell (bottom-up, left-right) that has an equal mergeable neighbor, or (-1,-1).
func _find_any_merge() -> Vector2i:
	for r in ROWS:
		for c in COLS:
			var v: int = grid[c][r]
			if v <= 0:
				continue
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var nc: int = c + d.x
				var nr: int = r + d.y
				if nc >= 0 and nc < COLS and nr >= 0 and nr < ROWS and grid[nc][nr] == v:
					return Vector2i(c, r)
	return Vector2i(-1, -1)


func _apply_gravity() -> void:
	for c in COLS:
		var vals: Array = []
		for r in ROWS:
			if grid[c][r] != 0:
				vals.append(grid[c][r])
		for r in ROWS:
			grid[c][r] = vals[r] if r < vals.size() else 0


func _board_full() -> bool:
	for c in COLS:
		if grid[c][ROWS - 1] == 0:
			return false
	return true


## Deep-copy state for undo. RNG state is intentionally not saved.
func snapshot() -> Dictionary:
	var g: Array = []
	for c in COLS:
		g.append(grid[c].duplicate())
	return {"grid": g, "score": score, "highest": highest, "next_value": next_value,
		"game_over": game_over, "level": level, "moves_left": moves_left,
		"drops_count": drops_count, "dil": _drops_in_level, "seq": seq_index}


func restore(d: Dictionary) -> void:
	grid = []
	for c in COLS:
		grid.append(d.grid[c].duplicate())
	score = d.score
	highest = d.highest
	next_value = d.next_value
	game_over = d.game_over
	level = d.level
	moves_left = d.moves_left
	drops_count = d.drops_count
	_drops_in_level = d.dil
	seq_index = int(d.get("seq", seq_index))
	last_merges = []
	last_stones_broken = 0
	last_level_up = false


## The shared daily board pre-rolls their whole tile sequence from the seed, with
## the difficulty cap keyed on the DROP INDEX rather than on `highest`. Deriving the cap
## from `highest` made two players on the same seed diverge as soon as their play did —
## which silently broke the promise that everyone plays the identical board.
func _preroll_values() -> void:
	value_seq = PackedInt32Array()
	for i in DAILY_MOVES + 8:
		var cap := 8
		if i >= 45:
			cap = 64
		elif i >= 28:
			cap = 32
		elif i >= 12:
			cap = 16
		value_seq.append(_weighted_value(cap))


func _weighted_value(cap: int) -> int:
	var vals: Array = []
	var v := 2
	while v <= cap:
		vals.append(v)
		v *= 2
	var weights := PackedFloat32Array()
	var w := 1.0
	for i in vals.size():
		weights.append(w)
		w *= 0.55
	return vals[rng.rand_weighted(weights)]


func _roll_value() -> int:
	if not value_seq.is_empty():
		var val: int = value_seq[mini(seq_index, value_seq.size() - 1)]
		seq_index += 1
		return val
	var cap := 8
	if highest >= 64:
		cap = mini(64, highest / 8)
	var vals: Array = []
	var v := 2
	while v <= cap:
		vals.append(v)
		v *= 2
	var weights := PackedFloat32Array()
	var w := 1.0
	for i in vals.size():
		weights.append(w)
		w *= 0.55
	return vals[rng.rand_weighted(weights)]
