extends GutTest
## Unit tests for the pure board logic.

var b: Board


func before_each():
	b = Board.new(42)


func _fill_col(col: int, cells: Array) -> void:
	for r in cells.size():
		b.grid[col][r] = cells[r]


func test_new_board_is_empty():
	for c in Board.COLS:
		for r in Board.ROWS:
			assert_eq(b.grid[c][r], 0)
	assert_eq(b.score, 0)
	assert_false(b.game_over)


func test_deterministic_with_seed():
	var b2 := Board.new(42)
	for i in 20:
		assert_eq(b.next_value, b2.next_value)
		b.drop(i % Board.COLS)
		b2.drop(i % Board.COLS)


func test_drop_lands_at_bottom():
	var v := b.next_value
	assert_true(b.drop(2))
	# tile either sits at (2,0) or merged upward — score tells us which
	if b.score == 0:
		assert_eq(b.grid[2][0], v)


func test_landing_row_stacks():
	_fill_col(0, [2, 4, 8])
	assert_eq(b.landing_row(0), 3)


func test_cannot_drop_in_full_column():
	_fill_col(1, [2, 4, 8, 16, 32, 64, 128])
	assert_false(b.can_drop(1))
	assert_false(b.drop(1))


func test_merge_two_equal_vertical():
	_fill_col(0, [4])
	b.next_value = 4
	b.drop(0)
	assert_eq(b.grid[0][0], 8)
	assert_eq(b.grid[0][1], 0)
	assert_eq(b.score, 8)


func test_merge_horizontal():
	_fill_col(0, [8])
	_fill_col(2, [8])
	b.next_value = 8
	b.drop(1)
	# landing tile at (1,0) has equal left and right neighbors -> 8 * 2^2 = 32
	assert_eq(b.grid[1][0], 32)
	assert_eq(b.grid[0][0], 0)
	assert_eq(b.grid[2][0], 0)
	assert_eq(b.score, 32)


func test_chain_cascade():
	# column 0: [4, 8] then drop 4 -> 4+4=8 at bottom, then 8+8=16 cascade
	_fill_col(0, [8, 4])
	b.next_value = 4
	b.drop(0)
	assert_eq(b.grid[0][0], 16)
	assert_eq(b.grid[0][1], 0)
	# score: first merge 8*1, cascade 16*2 = 40
	assert_eq(b.score, 40)
	assert_eq(b.last_merges.size(), 2)
	assert_eq(b.last_merges[1].chain, 2)


func test_gravity_after_merge():
	# col 0: [2, 16, 2] -- drop 2? can't force landing above; test gravity directly
	_fill_col(0, [2, 0, 4])
	b._apply_gravity()
	assert_eq(b.grid[0][0], 2)
	assert_eq(b.grid[0][1], 4)
	assert_eq(b.grid[0][2], 0)


func test_highest_updates():
	_fill_col(0, [16])
	b.next_value = 16
	b.drop(0)
	assert_eq(b.highest, 32)


func test_game_over_when_board_full():
	# fill everything with un-mergeable values except one top cell
	var vals := [2, 8, 32, 128, 512, 2048, 8192]
	for c in Board.COLS:
		for r in Board.ROWS:
			b.grid[c][r] = vals[r] * (1 if c % 2 == 0 else 2)
	b.grid[4][Board.ROWS - 1] = 0
	b.next_value = 3  # un-mergeable sentinel
	b.drop(4)
	assert_true(b.game_over)
	for c in Board.COLS:
		assert_false(b.can_drop(c))


func test_roll_value_range_early():
	for i in 200:
		var v := b._roll_value()
		assert_true(v in [2, 4, 8], "early values must be 2..8, got %d" % v)


func test_roll_value_cap_grows():
	b.highest = 512
	var seen := {}
	for i in 500:
		var v := b._roll_value()
		seen[v] = true
		assert_true(v >= 2 and v <= 64)
	assert_true(seen.has(16) or seen.has(32) or seen.has(64))


func test_values_always_powers_of_two():
	for i in 150:
		var cols := []
		for c in Board.COLS:
			if b.can_drop(c):
				cols.append(c)
		if cols.is_empty():
			break
		b.drop(cols[b.rng.randi() % cols.size()])
	for c in Board.COLS:
		for r in Board.ROWS:
			var v: int = b.grid[c][r]
			if v != 0:
				assert_true(v == Board.STONE or (v >= 2 and (v & (v - 1)) == 0),
					"not a power of 2 or stone: %d" % v)


func test_reset_clears_state():
	b.drop(0)
	b.drop(1)
	b.reset(7)
	assert_eq(b.score, 0)
	assert_false(b.game_over)
	for c in Board.COLS:
		for r in Board.ROWS:
			assert_eq(b.grid[c][r], 0)
