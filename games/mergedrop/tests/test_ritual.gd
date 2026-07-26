extends GutTest
## The تفأل ceremony and the fal ledger — the heart of the USP.


func before_each():
	Store.fal_log = []
	Store.fal_last_date = ""
	Store.fal_collected = []
	I18n.locale = "fa"


func test_ledger_records_the_verse_and_the_intention():
	Fal.log_fal("h01", "topic_love")
	assert_eq(Store.fal_log.size(), 1)
	assert_eq(Store.fal_log[0].id, "h01")
	assert_eq(Store.fal_log[0].t, "topic_love")
	assert_eq(Store.fal_log[0].d, Time.get_date_string_from_system())


func test_ledger_keeps_one_entry_per_day():
	Fal.log_fal("h01", "topic_work")
	Fal.log_fal("h02", "topic_love")
	assert_eq(Store.fal_log.size(), 1, "a day yields one fal, so one ledger entry")
	assert_eq(Store.fal_log[0].id, "h01", "the first reveal of the day is the real one")


func test_logged_today_reflects_the_ceremony():
	assert_false(Fal.logged_today(), "before the ceremony the fal is unrevealed")
	Fal.log_fal("h03")
	assert_true(Fal.logged_today(), "after it, opening the card must not re-run the ritual")


func test_previous_dates_powers_the_returning_verse_line():
	Store.fal_log = [
		{"id": "h07", "d": "2026-05-01", "t": "topic_none"},
		{"id": "h09", "d": "2026-06-01", "t": "topic_work"},
		{"id": "h07", "d": "2026-06-20", "t": "topic_love"},
	]
	var prev := Fal.previous_dates("h07")
	assert_eq(prev.size(), 2, "both earlier appearances count")
	assert_eq(prev[prev.size() - 1], "2026-06-20", "the most recent one is shown")
	assert_eq(Fal.previous_dates("h99").size(), 0)


func test_previous_dates_excludes_today():
	Fal.log_fal("h11", "topic_none")
	assert_eq(Fal.previous_dates("h11").size(), 0,
		"today's own entry must not read as 'this came to you before'")


func test_ledger_is_bounded():
	for i in 420:
		Store.fal_log.append({"id": "h01", "d": "2020-01-01", "t": "topic_none"})
	Fal.log_fal("h02", "topic_none")
	assert_lte(Store.fal_log.size(), 400, "the ledger must not grow without bound")


func test_ledger_survives_a_save_round_trip():
	Fal.log_fal("h05", "topic_travel")
	Store.save()
	Store.fal_log = []
	Store.load_data()
	assert_eq(Store.fal_log.size(), 1)
	assert_eq(Store.fal_log[0].t, "topic_travel")


func test_every_topic_has_a_localized_label():
	for key in NiyatCeremony.TOPICS:
		assert_true(I18n.T.has(key), "missing translation for %s" % key)
		assert_gt(I18n.t(key).length(), 1)


func test_ceremony_emits_the_chosen_topic():
	var c := NiyatCeremony.new()
	add_child_autofree(c)
	await wait_process_frames(2)
	var got := []
	c.opened.connect(func(topic): got.append(topic))
	c._pick("topic_health")
	c._open()
	await wait_process_frames(2)
	assert_eq(got.size(), 1, "opening the divan must report the intention")
	assert_eq(got[0], "topic_health")


func test_ceremony_requires_a_real_hold():
	var c := NiyatCeremony.new()
	add_child_autofree(c)
	await wait_process_frames(2)
	var opened := []
	c.opened.connect(func(_t): opened.append(1))
	c._holding = true
	c._process(NiyatCeremony.HOLD_TIME * 0.4)     # a brief tap
	assert_eq(opened.size(), 0, "a tap must not open the divan")
	c._holding = false
	c._process(1.0)                                # releasing rewinds the hold
	assert_almost_eq(c._held, 0.0, 0.001)
	c._holding = true
	c._process(NiyatCeremony.HOLD_TIME + 0.1)
	await wait_process_frames(2)
	assert_eq(opened.size(), 1, "a full hold opens it")


func test_daily_fal_grant_is_separate_from_the_reveal():
	# Earning the fal (finishing the challenge) and revealing it (the ceremony) are
	# distinct: the ledger stays empty until the player actually opens the divan.
	var poem := Fal.grant_daily("20260726")
	assert_false(poem.is_empty())
	assert_false(Fal.logged_today(), "granting must not silently count as revealing")
	Fal.log_fal(poem.id, "topic_none")
	assert_true(Fal.logged_today())
