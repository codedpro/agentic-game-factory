extends GutTest
## v3 mechanics: garbage rows, stones, daily mode, missions, fal data.

var b: Board


func before_each():
	b = Board.new(42)


func test_garbage_row_shifts_up():
	b.grid[0][0] = 4
	b.grid[0][1] = 16
	b._insert_garbage_row()
	assert_eq(b.grid[0][1], 4)
	assert_eq(b.grid[0][2], 16)
	for c in Board.COLS:
		assert_true(b.grid[c][0] != 0, "bottom row must be filled")


func test_garbage_overflow_ends_game():
	for r in Board.ROWS:
		b.grid[2][r] = 2 << r  # full column, unmergeable ladder
	b._insert_garbage_row()
	assert_true(b.game_over)


func test_level_up_after_level_length():
	var needed := b.level_length()
	var dropped := 0
	while dropped < needed:
		for c in Board.COLS:
			if b.can_drop(c):
				b.drop(c)
				dropped += 1
				break
	assert_eq(b.level, 2)
	assert_true(b.last_level_up)


func test_stone_never_merges():
	b.grid[0][0] = Board.STONE
	b.next_value = 2
	b.drop(0)
	# tile stacks on the stone, no merge with it
	assert_eq(b.grid[0][0], Board.STONE)
	assert_eq(b.grid[0][1], 2)


func test_stone_breaks_next_to_merge():
	b.grid[0][0] = Board.STONE
	b.grid[1][0] = 4
	b.next_value = 4
	b.drop(1)
	# 4+4 merge at (1,0); adjacent stone at (0,0) shatters
	assert_eq(b.grid[0][0], 0)
	assert_eq(b.last_stones_broken, 1)
	assert_eq(b.grid[1][0], 8)
	assert_eq(b.score, 8 + 25)


func test_daily_has_preset_stones_and_move_limit():
	var d := Board.new(20260725, "daily")
	var stones := 0
	for c in Board.COLS:
		for r in Board.ROWS:
			if d.grid[c][r] == Board.STONE:
				stones += 1
	assert_eq(stones, Board.DAILY_STONES)
	assert_eq(d.moves_left, Board.DAILY_MOVES)


func test_daily_deterministic():
	var a := Board.new(20260725, "daily")
	var c := Board.new(20260725, "daily")
	assert_eq(a.grid, c.grid)
	assert_eq(a.next_value, c.next_value)


func test_daily_ends_after_moves():
	var d := Board.new(20260725, "daily")
	var moves := 0
	while not d.game_over and moves < Board.DAILY_MOVES + 5:
		for c in Board.COLS:
			if d.can_drop(c):
				d.drop(c)
				moves += 1
				break
		if moves >= Board.DAILY_MOVES + 5:
			break
	assert_true(d.game_over)
	assert_lte(moves, Board.DAILY_MOVES)


func test_daily_no_garbage_rows():
	var d := Board.new(20260725, "daily")
	for i in 20:
		for c in Board.COLS:
			if d.can_drop(c):
				d.drop(c)
				break
	assert_eq(d.level, 1, "daily mode must not level up / insert garbage")


func test_missions_roll_three_and_progress():
	Missions.state = {}
	Missions.ensure_today()
	var list := Missions.list_today()
	assert_eq(list.size(), 3)
	var ids := list.map(func(mn): return mn.id)
	assert_eq(ids.size(), 3)
	# same-day re-roll is a no-op
	var before := str(Missions.state)
	Missions.ensure_today()
	assert_eq(str(Missions.state), before)


func test_fal_data_valid():
	assert_gt(Fal.poems.size(), 0, "fal.json must load")
	for p in Fal.poems:
		assert_true(p.has("id") and p.has("poet") and p.has("verse") and p.has("interp"))
		assert_gt(String(p.verse).length(), 10)
	assert_gt(Fal.hafez_ids().size(), 0, "need Hafez poems for the daily fal")


func test_fal_daily_deterministic_and_grantable():
	var id1 := Fal.daily_id("20260725")
	var id2 := Fal.daily_id("20260725")
	assert_eq(id1, id2)
	assert_true(Fal.by_id.has(id1))


func test_snapshot_restore_v3_fields():
	b.drop(0)
	b.drop(1)
	var snap := b.snapshot()
	var level := b.level
	var drops := b.drops_count
	b.drop(2)
	b.restore(snap)
	assert_eq(b.level, level)
	assert_eq(b.drops_count, drops)
