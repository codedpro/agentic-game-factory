extends GutTest
## Regression guards for the defects found in the v3 adversarial audit.
## Each test names the bug it prevents from coming back.


# ---------- board ----------
func test_garbage_overflow_game_over_is_not_cleared():
	# BUG: drop() reassigned game_over from _board_full(), wiping the overflow
	# game-over that _insert_garbage_row() had just set.
	var b := Board.new(3)
	# fill every column to the top except one cell, with unmergeable values
	var vals := [2, 8, 32, 128, 512, 2048, 8192]
	for c in Board.COLS:
		for r in Board.ROWS:
			b.grid[c][r] = vals[r] * (1 if c % 2 == 0 else 2)
	b.grid[0][Board.ROWS - 1] = 0        # one free landing cell
	b.next_value = 3                      # unmergeable sentinel
	b.drop(0)
	assert_true(b.game_over, "board full after the drop must end the game")


func test_garbage_row_pushes_game_over_when_a_column_overflows():
	var b := Board.new(5)
	for r in Board.ROWS:
		b.grid[2][r] = 2 << r
	b._insert_garbage_row()
	assert_true(b.game_over)


func test_garbage_row_is_resolved_not_left_unmerged():
	# BUG: the inserted row was never passed through _resolve(), leaving free
	# horizontal matches sitting on the settled board.
	var b := Board.new(11)
	for i in 60:
		var moved := false
		for c in Board.COLS:
			if b.can_drop(c):
				b.drop(c)
				moved = true
				break
		if not moved or b.game_over:
			break
		assert_eq(b._find_any_merge(), Vector2i(-1, -1),
			"an unresolved match was left on the board after drop %d" % i)


# ---------- store: streak / records ----------
func test_streak_increments_from_yesterdays_local_date():
	# BUG: "yesterday" came from UTC wall-clock minus 24h, so in UTC+3:30 any play
	# between 00:00 and 03:29 local compared today with today and reset the streak.
	var today := Time.get_date_string_from_system()
	var yesterday := Time.get_date_string_from_unix_time(
		int(Time.get_unix_time_from_datetime_string(today)) - 86400)
	Store.streak_last = yesterday
	Store.streak_count = 4
	Store.update_streak()
	assert_eq(Store.streak_count, 5, "consecutive day must extend the streak")
	assert_eq(Store.streak_last, today)


func test_streak_resets_after_a_gap():
	Store.streak_last = "2020-01-01"
	Store.streak_count = 9
	Store.update_streak()
	assert_eq(Store.streak_count, 1)


func test_best_score_ignores_daily_runs():
	# BUG: daily scores and mid-run submits polluted the endless best score.
	Store.best_score = 500
	Store.record_game_over(9999, "20260725")
	assert_eq(Store.best_score, 500, "a daily run must not set the endless record")


func test_tying_the_record_is_not_a_new_best():
	Store.best_score = 800
	var res := Store.record_game_over(800, "")
	assert_false(res.new_best, "equalling the record is not a new record")
	var res2 := Store.record_game_over(801, "")
	assert_true(res2.new_best)


func test_endless_run_is_recorded_in_top_scores():
	Store.top_scores = []
	Store.record_game_over(1234, "")
	assert_eq(Store.top_scores.size(), 1)
	assert_eq(Store.top_scores[0].s, 1234)


# ---------- store: durable save ----------
func test_corrupt_save_recovers_from_backup():
	# BUG: an unreadable save silently reset every field to defaults, and the next
	# write made that permanent.
	Store.coins = 4321
	Store.save()                      # writes save.cfg (+ .bak on the next save)
	Store.coins = 4322
	Store.save()                      # now a .bak exists with 4321
	var f := FileAccess.open(Store.PATH, FileAccess.WRITE)
	f.store_string("[game\nthis is not valid config")
	f.close()
	Store.coins = 0
	Store.load_data()
	assert_engine_error("ConfigFile parse error")   # expected: we corrupted it on purpose
	assert_gt(Store.coins, 0, "progress must be recovered from the backup, not wiped")


# ---------- missions ----------
func test_max_type_missions_record_progress():
	# BUG: m_score / m_tile / m_chain never wrote mn.progress, so the menu always
	# showed ۰/target for them.
	Missions.state = {"date": "20260725", "list": [
		{"id": "m_tile", "target": 128, "progress": 0, "reward": 60, "done": false}]}
	Missions.run_key = "20260725"
	Missions.report("tile", 64)
	assert_eq(Missions.state.list[0].progress, 64, "progress toward the tile goal must show")
	assert_false(Missions.state.list[0].done)
	Missions.report("tile", 32)
	assert_eq(Missions.state.list[0].progress, 64, "progress must not go backwards")
	Missions.report("tile", 128)
	assert_true(Missions.state.list[0].done)


func test_missions_do_not_reroll_mid_run():
	# BUG: ensure_today() inside report() replaced the whole mission list at local
	# midnight, discarding in-flight progress.
	Missions.state = {"date": "19990101", "list": [
		{"id": "m_merges", "target": 50, "progress": 30, "reward": 50, "done": false}]}
	Missions.run_key = "19990101"
	Missions.report("merge", 5)
	assert_eq(Missions.state.date, "19990101", "the run must keep the missions it started with")
	assert_eq(Missions.state.list[0].progress, 35)


# ---------- fal ----------
func test_daily_fal_is_idempotent_per_day():
	Store.fal_last_date = ""
	Store.fal_collected = []
	var first := Fal.grant_daily("20260725")
	assert_false(first.is_empty(), "first completion of the day grants a fal")
	var second := Fal.grant_daily("20260725")
	assert_true(second.is_empty(), "the same day must not grant twice")


func test_fal_grant_uses_the_key_it_is_given():
	Store.fal_last_date = ""
	var p := Fal.grant_daily("20260726")
	assert_eq(Store.fal_last_date, "20260726")
	assert_eq(p.id, Fal.by_id[Fal.daily_id("20260726")].id)


# ---------- one-shot game-over recording ----------
func test_game_over_records_exactly_once():
	# BUG: relayout() (fired by any viewport resize) re-ran _show_over(), which
	# re-recorded the finished game: inflated games_played, duplicate top-10 rows,
	# double mission credit.
	Store.first_run = false
	var sh = load("res://scripts/main.gd").new()
	add_child_autofree(sh)
	await wait_frames(2)
	sh.show_screen("game", {"autoplay": true})
	await wait_frames(2)
	var gs = sh.current
	# force a finished board
	var vals := [2, 8, 32, 128, 512, 2048, 8192]
	for c in Board.COLS:
		for r in Board.ROWS:
			gs.board.grid[c][r] = vals[r] * (1 if c % 2 == 0 else 2)
	gs.board.game_over = true
	var before: int = Store.games_played
	gs._record_over()
	gs._record_over()
	gs.relayout()
	await wait_frames(2)
	assert_eq(Store.games_played, before + 1,
		"a finished game must be recorded once no matter how often the screen rebuilds")
