extends GutTest
## Pure rules of one proverb level: submission, rounds, hints, resume, display.

const DICT := {"بار": true, "باد": true, "برد": true, "دار": true, "شود": true}

# Synthetic 2-round level: round 1 wheel ابدر covers باد/برد, round 2 covers می‌شود's شود.
func _level() -> Dictionary:
	return {"id": "t1", "text": "باد برد و می‌شود", "meaning": "آزمایشی",
		"rounds": [
			{"targets": ["باد", "برد"], "wheel": ["ا", "ب", "د", "ر"]},
			{"targets": ["شود"], "wheel": ["د", "و", "ش"]},
		]}


func test_target_solving_and_round_advance():
	var p := Puzzle.new(_level(), DICT, 7)
	assert_eq(p.round_idx, 0)
	var r := p.submit("باد")
	assert_eq(r.kind, Puzzle.HIT_TARGET)
	assert_false(r.round_done)
	r = p.submit("برد")
	assert_eq(r.kind, Puzzle.HIT_TARGET)
	assert_true(r.round_done)
	assert_false(r.level_done)
	assert_eq(p.round_idx, 1)
	r = p.submit("شود")
	assert_true(r.level_done)
	assert_true(p.done)


func test_bonus_words_pay_once():
	var p := Puzzle.new(_level(), DICT, 7)
	var r := p.submit("بار")            # in DICT, composable from ابدر, not a target
	assert_eq(r.kind, Puzzle.HIT_BONUS)
	assert_eq(r.coins, Puzzle.bonus_coins("بار"))
	assert_gt(r.coins, 0)
	r = p.submit("بار")
	assert_eq(r.kind, Puzzle.HIT_DUP)
	assert_eq(r.coins, 0)


func test_invalid_and_uncomposable_words():
	var p := Puzzle.new(_level(), DICT, 7)
	assert_eq(p.submit("دار").kind, Puzzle.HIT_BONUS)
	assert_eq(p.submit("شود").kind, Puzzle.HIT_INVALID,
		"round-2 target is not composable from the round-1 wheel")
	assert_eq(p.submit("خیال").kind, Puzzle.HIT_INVALID)
	assert_eq(p.submit("ب").kind, Puzzle.HIT_INVALID, "single letters never count")


func test_composable_respects_letter_counts():
	var p := Puzzle.new({"id": "t2", "text": "درد", "meaning": "x",
		"rounds": [{"targets": ["درد"], "wheel": ["د", "د", "ر"]}]}, DICT, 3)
	assert_true(p.composable("درد"))
	assert_false(p.composable("دردد"))


func test_duplicate_target_reports_dup():
	var p := Puzzle.new(_level(), DICT, 7)
	p.submit("باد")
	assert_eq(p.submit("باد").kind, Puzzle.HIT_DUP)


func test_hint_reveals_then_autosolves():
	var p := Puzzle.new(_level(), DICT, 7)
	var w := p.hint()
	assert_eq(w, "باد")
	assert_eq(int(p.revealed["باد"]), 1)
	p.hint()
	assert_true(p.solved.has("باد"), "revealing all-but-none left → word auto-solves")
	assert_eq(p.hints_used, 2)
	# hint the rest of the level away; rounds must advance and finish
	for i in 8:
		p.hint()
	assert_true(p.done)


func test_wheel_deterministic_by_seed():
	var a := Puzzle.new(_level(), DICT, 42)
	var b := Puzzle.new(_level(), DICT, 42)
	assert_eq(a.wheel(), b.wheel())
	var c := Puzzle.new(_level(), DICT, 43)
	# not asserting inequality (43 may legally shuffle identically); wheel content must match regardless
	var sa: Array = a.wheel().duplicate()
	var sc: Array = c.wheel().duplicate()
	sa.sort()
	sc.sort()
	assert_eq(sa, sc)


func test_snapshot_restore_roundtrip():
	var p := Puzzle.new(_level(), DICT, 7)
	p.submit("باد")
	p.submit("بار")
	p.hint()   # reveals a letter of برد
	var snap := p.snapshot()
	var q := Puzzle.new(_level(), DICT, 9)
	q.restore(snap)
	assert_true(q.solved.has("باد"))
	assert_true(q.bonus_found.has("بار"))
	assert_eq(int(q.revealed.get("برد", 0)), 1)
	assert_eq(q.round_idx, 0)
	q.submit("برد")
	q.submit("شود")
	assert_true(q.done)


func test_restore_past_finished_rounds():
	var p := Puzzle.new(_level(), DICT, 7)
	p.submit("باد")
	p.submit("برد")
	var q := Puzzle.new(_level(), DICT, 1)
	q.restore(p.snapshot())
	assert_eq(q.round_idx, 1)
	assert_false(q.done)


func test_display_tokens_blank_and_reveal():
	var p := Puzzle.new(_level(), DICT, 7)
	var toks := p.display_tokens()
	assert_eq(toks.size(), 4)                      # باد / برد / و / می‌شود
	assert_true(toks[0].target)
	assert_false(toks[0].solved)
	assert_false(toks[2].target, "stopword و is never a target")
	assert_true(toks[3].target, "شود inside می‌شود makes the token a target")
	p.submit("باد")
	toks = p.display_tokens()
	assert_true(toks[0].solved)
	assert_false(toks[3].solved)


func test_solved_counts():
	var p := Puzzle.new(_level(), DICT, 7)
	assert_eq(p.total_targets(), 3)
	p.submit("باد")
	assert_eq(p.solved_count(), 1)
