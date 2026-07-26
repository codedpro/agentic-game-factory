extends GutTest
## Jalali calendar, repeat-free fal cycle, streak semantics, share payloads.


# ---------- Jalali ----------
func test_known_gregorian_jalali_pairs():
	# Nowruz 1405 and a mid-year date
	assert_eq(Jalali.from_gregorian(2026, 3, 21), [1405, 1, 1])
	assert_eq(Jalali.from_gregorian(2026, 7, 25), [1405, 5, 3])
	assert_eq(Jalali.from_gregorian(2025, 3, 21), [1404, 1, 1])
	assert_eq(Jalali.from_gregorian(2024, 12, 20), [1403, 9, 30])   # شب یلدا


func test_jalali_is_monotonic_over_a_year():
	var prev := -1
	for doy in range(0, 365):
		var unix := Time.get_unix_time_from_datetime_dict(
			{"year": 2026, "month": 1, "day": 1, "hour": 12, "minute": 0, "second": 0}) + doy * 86400
		var d := Time.get_datetime_dict_from_unix_time(int(unix))
		var j := Jalali.from_gregorian(d.year, d.month, d.day)
		assert_between(j[1], 1, 12, "month out of range")
		assert_between(j[2], 1, 31, "day out of range")
		var ordinal: int = j[0] * 10000 + j[1] * 100 + j[2]
		assert_gt(ordinal, prev, "jalali date went backwards at day %d" % doy)
		prev = ordinal


func test_occasion_detection():
	assert_eq(Jalali.occasion([1405, 1, 1]), "nowruz")
	assert_eq(Jalali.occasion([1403, 9, 30]), "yalda")
	assert_eq(Jalali.occasion([1405, 5, 3]), "")


func test_persian_date_formatting():
	I18n.locale = "fa"
	assert_eq(Jalali.format([1405, 5, 3]), "۳ مرداد ۱۴۰۵")


func test_day_number_advances_by_one():
	var a := Jalali.day_number({"year": 2026, "month": 7, "day": 25})
	var b := Jalali.day_number({"year": 2026, "month": 7, "day": 26})
	assert_eq(b - a, 1)


# ---------- fal cycle ----------
func _key(y: int, m: int, d: int) -> String:
	return "%04d%02d%02d" % [y, m, d]


func test_daily_fal_is_deterministic():
	assert_eq(Fal.daily_id("20260725"), Fal.daily_id("20260725"))


func test_daily_fal_never_repeats_within_a_cycle():
	var n := Fal.hafez_ids().size()
	assert_gt(n, 1, "need a pool to cycle")
	var seen := {}
	var unix := Time.get_unix_time_from_datetime_dict(
		{"year": 2026, "month": 7, "day": 25, "hour": 12, "minute": 0, "second": 0})
	for i in n:
		var d := Time.get_datetime_dict_from_unix_time(int(unix + i * 86400))
		var id := Fal.daily_id(_key(d.year, d.month, d.day))
		assert_false(seen.has(id), "fal '%s' repeated after %d days (pool %d)" % [id, i, n])
		seen[id] = true
	assert_eq(seen.size(), n, "a full cycle must show every verse exactly once")


func test_daily_fal_covers_pool_across_cycles():
	var n := Fal.hafez_ids().size()
	var seen := {}
	var unix := Time.get_unix_time_from_datetime_dict(
		{"year": 2026, "month": 1, "day": 1, "hour": 12, "minute": 0, "second": 0})
	for i in n * 3:
		var d := Time.get_datetime_dict_from_unix_time(int(unix + i * 86400))
		seen[Fal.daily_id(_key(d.year, d.month, d.day))] = true
	assert_eq(seen.size(), n)


# ---------- streak ----------
func test_streak_counts_daily_challenge_only():
	Store.streak_count = 0
	Store.streak_last = ""
	Store.record_game_over(100, "")            # endless run
	assert_eq(Store.streak_count, 0, "endless play must not build the ritual streak")
	Store.record_game_over(100, "20260725")    # daily run
	assert_eq(Store.streak_count, 1)


func test_streak_increments_only_once_per_day():
	Store.streak_count = 0
	Store.streak_last = ""
	Store.record_game_over(10, "20260725")
	var first := Store.streak_count
	Store.record_game_over(20, "20260725")
	assert_eq(Store.streak_count, first, "same day must not double-count")


# ---------- share ----------
func test_fal_share_text_contains_poem_and_date():
	I18n.locale = "fa"
	var poem: Dictionary = Fal.poems[0]
	var t: String = Share.fal_text(poem)
	assert_true(t.contains(poem.verse), "verse missing from share text")
	assert_true(t.contains(poem.poet))
	assert_true(t.contains(poem.interp))
	assert_true(t.contains(Jalali.format_today()), "Persian date missing")


func _is_grid_row(line: String) -> bool:
	if line.length() != Board.COLS:
		return false
	for i in line.length():
		if not Share.TIER.values().has(line[i]) and line[i] != "🟨":
			return false
	return true


func test_daily_share_grid_shape():
	var b := Board.new(20260725, "daily")
	for i in 6:
		for c in Board.COLS:
			if b.can_drop(c):
				b.drop(c)
				break
	var t: String = Share.daily_text(b.grid, b.score, 3)
	var rows: Array = Array(t.split("\n")).filter(func(l): return _is_grid_row(l))
	assert_eq(rows.size(), Board.ROWS, "grid must have one line per board row")
	for r in rows:
		assert_eq(r.length(), Board.COLS, "each grid row needs one cell per column")
	assert_true(t.contains(I18n.digits(b.score)))


func test_share_writes_clipboard():
	# headless CI has no clipboard; there share_text must degrade quietly, not crash
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		assert_false(Share.share_text("سلام تست"),
			"without a clipboard share_text must report failure instead of erroring")
		return
	assert_true(Share.share_text("سلام تست"), "clipboard round-trip failed")
	assert_eq(DisplayServer.clipboard_get(), "سلام تست")
