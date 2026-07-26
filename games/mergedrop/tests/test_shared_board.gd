extends GutTest
## The daily challenge and the friend duel both promise "everyone plays the identical
## board". These tests hold that promise honest — it is a fairness claim printed in the
## share text and on the store page.


func _play(seed: int, columns: Array) -> Array:
	## Play a board following a given column pattern; return the tile sequence seen.
	var b := Board.new(seed, "daily")
	var seen: Array = [b.next_value]
	for c in columns:
		var col: int = int(c) % Board.COLS
		if not b.can_drop(col):
			for alt in Board.COLS:
				if b.can_drop(alt):
					col = alt
					break
		if b.game_over or not b.can_drop(col):
			break
		b.drop(col)
		seen.append(b.next_value)
	return seen


func test_same_seed_same_tiles_even_when_play_diverges():
	# THE bug this guards: the cap used to derive from `highest`, so as soon as two
	# players merged differently they received different tiles on the same seed.
	var stubborn: Array = []
	var varied: Array = []
	for i in 40:
		stubborn.append(0)          # one player dumps everything in column 0
		varied.append(i % Board.COLS)  # the other spreads out and merges much more
	var a := _play(20260726, stubborn)
	var b := _play(20260726, varied)
	var n: int = mini(a.size(), b.size())
	assert_gt(n, 10, "both runs should last a while")
	for i in n:
		assert_eq(a[i], b[i],
			"tile %d differed (%s vs %s) — the shared board is not identical" % [i, a[i], b[i]])


func test_high_scoring_play_does_not_change_the_sequence():
	var b1 := Board.new(777, "daily")
	var b2 := Board.new(777, "daily")
	# force a big tile on one board only
	b2.grid[4][0] = 256
	b2.highest = 256
	var s1: Array = []
	var s2: Array = []
	for i in 30:
		for c in Board.COLS:
			if b1.can_drop(c):
				b1.drop(c)
				break
		for c in Board.COLS:
			if b2.can_drop(c):
				b2.drop(c)
				break
		s1.append(b1.next_value)
		s2.append(b2.next_value)
	assert_eq(s1, s2, "a player who already built a 256 must not get a different pool")


func test_sequence_covers_the_whole_daily():
	var b := Board.new(31337, "daily")
	assert_gte(b.value_seq.size(), Board.DAILY_MOVES,
		"the pre-rolled sequence must outlast the move limit")
	for v in b.value_seq:
		assert_true(v >= 2 and (v & (v - 1)) == 0, "bad pre-rolled value %d" % v)


func test_sequence_difficulty_ramps():
	var b := Board.new(4242, "daily")
	var early := 0
	var late := 0
	for i in 12:
		early = maxi(early, b.value_seq[i])
	for i in range(45, mini(60, b.value_seq.size())):
		late = maxi(late, b.value_seq[i])
	assert_lte(early, 8, "early drops stay gentle")
	assert_gt(late, early, "later drops must offer bigger tiles")


func test_endless_mode_keeps_its_adaptive_pool():
	# Endless is a solo mode: its pool should still follow the player's progress.
	var b := Board.new(9, "endless")
	assert_true(b.value_seq.is_empty(), "endless must not use a fixed sequence")


func test_undo_restores_the_sequence_position():
	var b := Board.new(555, "daily")
	for c in 3:
		if b.can_drop(c):
			b.drop(c)
	var snap := b.snapshot()
	var expected := b.next_value
	b.drop(0)
	b.drop(1)
	b.restore(snap)
	assert_eq(b.next_value, expected)
	assert_eq(b.seq_index, snap.seq, "restoring must rewind the tile sequence too")


func test_daily_boards_match_end_to_end_for_two_players():
	var seed := 20260726
	var mine := _play(seed, [0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0, 0, 1, 1])
	var theirs := _play(seed, [4, 4, 3, 3, 2, 2, 1, 1, 0, 0, 2, 3, 4, 0])
	var n: int = mini(mine.size(), theirs.size())
	for i in n:
		assert_eq(mine[i], theirs[i], "daily tile %d diverged between two players" % i)
