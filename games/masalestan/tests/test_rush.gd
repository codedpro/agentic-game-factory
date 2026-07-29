extends GutTest
## The timed mode's pressure math: refunds decay, chains multiply, runs must die.

const DICT := {"بار": true}

func _levels() -> Array:
	var out: Array = []
	for i in 6:
		out.append({"id": "r%d" % i, "text": "باد برد", "meaning": "x",
			"rounds": [{"targets": ["باد", "برد"], "wheel": ["ا", "ب", "د", "ر"]}]})
	return out


func test_solving_refunds_time_and_scores():
	var r := Rush.new(_levels(), DICT, 5)
	var t0 := r.time_left
	r.advance(10.0)
	assert_almost_eq(r.time_left, t0 - 10.0, 0.001)
	var res: Dictionary = r.submit(r.puzzle.current_round().targets[0])
	assert_eq(res.kind, Puzzle.HIT_TARGET)
	assert_gt(float(res.time_gain), 0.0)
	assert_gt(int(res.score_gain), 0)


func test_chain_multiplier_grows_and_resets():
	var r := Rush.new(_levels(), DICT, 5)
	var first: Dictionary = r.submit(r.puzzle.current_round().targets[0])
	assert_eq(int(first.chain), 1)
	r.advance(2.0)   # inside the chain window
	var second: Dictionary = r.submit(r.puzzle.current_round().targets[1])
	assert_eq(int(second.chain), 2)
	# completing the level loaded the next one; waiting past the window resets
	r.advance(Rush.CHAIN_WINDOW + 1.0)
	var third: Dictionary = r.submit(r.puzzle.current_round().targets[0])
	assert_eq(int(third.chain), 1)


func test_word_bonus_decays_with_progress():
	var r := Rush.new(_levels(), DICT, 5)
	var early := r.word_bonus()
	r.completed = 10
	assert_lt(r.word_bonus(), early)
	r.completed = 1000
	assert_almost_eq(r.word_bonus(), Rush.WORD_BONUS_MIN, 0.001)


func test_time_bank_capped():
	var r := Rush.new(_levels(), DICT, 5)
	r.time_left = Rush.MAX_BANK - 0.5
	r.submit(r.puzzle.current_round().targets[0])
	assert_true(r.time_left <= Rush.MAX_BANK)


func test_game_over_stops_everything():
	var r := Rush.new(_levels(), DICT, 5)
	r.advance(1000.0)
	assert_true(r.game_over)
	assert_eq(r.time_left, 0.0)
	var res: Dictionary = r.submit("باد")
	assert_eq(res.kind, Puzzle.HIT_INVALID)
	assert_eq(int(res.score_gain), 0)


## The difficulty engine's core promise (L15): at ANY fixed pace, a run eventually
## ends, because refunds decay below the time each word costs.
func test_runs_die_at_fixed_pace():
	var r := Rush.new(_levels(), DICT, 5)
	var solves := 0
	while not r.game_over and solves < 500:
		r.advance(4.0)   # a steady, competent 4 s per word
		if r.game_over:
			break
		var target := ""
		for t in r.puzzle.current_round().targets:
			if not r.puzzle.solved.has(t):
				target = t
				break
		r.submit(target)
		solves += 1
	assert_true(r.game_over, "steady play must eventually starve the clock")
	assert_gt(solves, 10, "but not instantly — early bonuses outpace 4 s/word")


func test_deterministic_level_order_by_seed():
	var a := Rush.new(_levels(), DICT, 11)
	var b := Rush.new(_levels(), DICT, 11)
	assert_eq(a.puzzle.level.id, b.puzzle.level.id)
	assert_eq(a.puzzle.wheel(), b.puzzle.wheel())
