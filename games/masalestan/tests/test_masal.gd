extends GutTest
## Content integrity of the shipped proverb pool + the shared daily draw.

const LETTERS := "ابپتثجچحخدذرزژسشصضطظعغفقکگلمنوهیآ"


func test_pool_loaded_and_big_enough():
	assert_gt(Masal.levels.size(), 92, "daily cycle must exceed a season")
	assert_eq(Masal.levels.size(), Masal.by_id.size(), "ids must be unique")


func test_every_level_is_playable():
	for l in Masal.levels:
		assert_gt((l.rounds as Array).size(), 0, l.id)
		var total := 0
		for r in l.rounds:
			assert_gt((r.targets as Array).size(), 0, l.id)
			assert_true((r.wheel as Array).size() <= 8, l.id + ": wheel over 8 tiles")
			total += (r.targets as Array).size()
			# every target must be composable from its round's wheel
			var avail := {}
			for ch in r.wheel:
				avail[ch] = avail.get(ch, 0) + 1
			for t in r.targets:
				var need := {}
				for ch in t:
					need[ch] = need.get(ch, 0) + 1
				for ch in need:
					assert_true(int(avail.get(ch, 0)) >= int(need[ch]),
						"%s: '%s' needs %s×%d" % [l.id, t, ch, need[ch]])
		assert_gte(total, 2, l.id)


func test_targets_are_clean_persian():
	for l in Masal.levels:
		for r in l.rounds:
			for t in r.targets:
				assert_between(t.length(), 2, 6, l.id + ": " + t)
				for ch in t:
					assert_true(LETTERS.contains(ch),
						"%s: target '%s' has non-wheel letter '%s'" % [l.id, t, ch])


func test_every_target_appears_in_its_proverb():
	for l in Masal.levels:
		var p := Puzzle.new(l, Masal.word_set, 1)
		var in_text := {}
		for tok in p.display_tokens():
			for s in tok.subs:
				in_text[s] = true
		for r in l.rounds:
			for t in r.targets:
				assert_true(in_text.has(t), "%s: '%s' not a display token" % [l.id, t])


func test_every_target_is_in_the_dictionary():
	for l in Masal.levels:
		for r in l.rounds:
			for t in r.targets:
				assert_true(Masal.word_set.has(t), "dictionary missing " + t)


func test_meanings_present():
	for l in Masal.levels:
		assert_gt(str(l.meaning).length(), 10, l.id)
		assert_gt(str(l.text).length(), 5, l.id)


func test_daily_is_deterministic_and_shared():
	assert_eq(Masal.daily_id("14050101"), Masal.daily_id("14050101"))
	assert_eq(Masal.daily_seed("14050101"), Masal.daily_seed("14050101"))


## Stride-walk guarantee (L27): a sliding window of n consecutive days sees every
## proverb exactly once — tested over an arbitrary, cycle-misaligned window.
func test_daily_cycle_has_no_repeats():
	var n := Masal.levels.size()
	var seen := {}
	var base := Jalali.day_number({"year": 1405, "month": 3, "day": 17})
	for i in n:
		var id := Masal._walk(base + i)
		assert_false(seen.has(id), "repeat within one cycle at day %d" % i)
		seen[id] = true
	assert_eq(seen.size(), n)


func test_grant_daily_once_per_day():
	var saved_last := Store.masal_last_date
	var saved_coll := Store.masal_collected.duplicate()
	Store.masal_last_date = ""
	Store.masal_collected = []
	var l := Masal.grant_daily("14050101")
	assert_false(l.is_empty())
	assert_true(Masal.grant_daily("14050101").is_empty(), "second grant same day = {}")
	assert_eq(Store.masal_collected.size(), 1)
	Store.masal_last_date = saved_last
	Store.masal_collected = saved_coll
	Store.save()


func test_milestone_grants_uncollected_then_empty():
	var saved := Store.masal_collected.duplicate()
	Store.masal_collected = []
	for l in Masal.levels:
		Store.masal_collected.append(l.id)
	assert_true(Masal.grant_milestone().is_empty(), "full treasury grants nothing")
	Store.masal_collected = saved
	Store.save()
