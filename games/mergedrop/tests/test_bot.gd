extends GutTest
## Bot player: simulates many full games on the pure logic and asserts invariants.

const GAMES := 120
const MAX_DROPS := 600


func test_bot_plays_many_games():
	var total_score := 0
	var overs := 0
	for g in GAMES:
		var b := Board.new(1000 + g)
		var drops := 0
		while not b.game_over and drops < MAX_DROPS:
			var cols: Array = []
			for c in Board.COLS:
				if b.can_drop(c):
					cols.append(c)
			assert_false(cols.is_empty() and not b.game_over,
				"no legal moves but not game over (game %d)" % g)
			if cols.is_empty():
				break
			var ok: bool = b.drop(cols[b.rng.randi() % cols.size()])
			assert_true(ok, "legal drop refused")
			drops += 1
			# invariants after every move
			assert_true(b.score >= 0)
			for c in Board.COLS:
				var seen_empty := false
				for r in Board.ROWS:
					var v: int = b.grid[c][r]
					if v == 0:
						seen_empty = true
					else:
						assert_false(seen_empty, "floating tile at %d,%d (game %d)" % [c, r, g])
						assert_true(v == Board.STONE or ((v & (v - 1)) == 0 and v >= 2),
							"bad value %d" % v)
		if b.game_over:
			overs += 1
		total_score += b.score
	assert_gt(total_score, 0)
	# most random games should eventually die
	assert_gt(overs, GAMES / 2, "expected most random games to reach game over, got %d/%d" % [overs, GAMES])
	gut.p("bot: %d games, %d game-overs, avg score %d" % [GAMES, overs, total_score / GAMES])
