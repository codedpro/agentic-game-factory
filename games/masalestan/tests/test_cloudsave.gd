extends GutTest
## Merge semantics of the cloud backup — the part that must never lose progress.


func _local() -> Dictionary:
	return {"v": 1, "coins": 500, "best_score": 900, "campaign_index": 12,
		"goal_index": 2, "games_played": 30, "words_total": 80, "bonus_total": 5,
		"supporter_level": 0, "streak_count": 3, "streak_last": "2026-07-29",
		"masal_last_date": "14050507", "masal_collected": ["m001", "m002"],
		"achievements": ["masal1"], "themes_owned": ["classic", "sunset"],
		"frames_owned": ["classic"], "inventory": {"hint": 2},
		"daily_best": {"14050506": 700},
		"daily_log": [{"d": "2026-07-29", "id": "m003", "hints": 0, "words": 4}]}


func _remote() -> Dictionary:
	return {"v": 1, "coins": 900, "best_score": 400, "campaign_index": 5,
		"goal_index": 3, "games_played": 10, "words_total": 200, "bonus_total": 9,
		"supporter_level": 2, "streak_count": 9, "streak_last": "2026-07-20",
		"masal_last_date": "14050430", "masal_collected": ["m002", "m007"],
		"achievements": ["masal1", "words100"], "themes_owned": ["classic", "neon"],
		"frames_owned": ["classic", "lapis"], "inventory": {"hint": 5, "shield": 1},
		"daily_best": {"14050506": 300, "14050401": 800},
		"daily_log": [{"d": "2026-07-20", "id": "m009", "hints": 1, "words": 3}]}


func test_counters_take_the_max():
	var m := CloudSave.merged(_local(), _remote())
	assert_eq(int(m.coins), 900)
	assert_eq(int(m.best_score), 900)
	assert_eq(int(m.campaign_index), 12)
	assert_eq(int(m.words_total), 200)
	assert_eq(int(m.supporter_level), 2)


func test_collections_take_the_union():
	var m := CloudSave.merged(_local(), _remote())
	for id in ["m001", "m002", "m007"]:
		assert_true(id in m.masal_collected, id)
	assert_true("words100" in m.achievements)
	assert_true("neon" in m.themes_owned and "sunset" in m.themes_owned)
	assert_eq(int(m.inventory.hint), 5)
	assert_eq(int(m.inventory.shield), 1)


func test_streak_belongs_to_the_most_recent_player():
	var m := CloudSave.merged(_local(), _remote())
	assert_eq(str(m.streak_last), "2026-07-29", "local played later")
	assert_eq(int(m.streak_count), 3, "the older 9-day streak is history, not truth")
	var m2 := CloudSave.merged(_remote(), _local())
	assert_eq(str(m2.streak_last), "2026-07-29", "merge is symmetric on recency")
	assert_eq(int(m2.streak_count), 3)


func test_daily_best_merges_per_day():
	var m := CloudSave.merged(_local(), _remote())
	assert_eq(int(m.daily_best["14050506"]), 700)
	assert_eq(int(m.daily_best["14050401"]), 800)


func test_daily_log_unions_by_date():
	var m := CloudSave.merged(_local(), _remote())
	assert_eq((m.daily_log as Array).size(), 2)


func test_merge_with_empty_remote_changes_nothing_essential():
	var m := CloudSave.merged(_local(), {})
	assert_eq(int(m.coins), 500)
	assert_eq(m.masal_collected, ["m001", "m002"])
	assert_eq(str(m.streak_last), "2026-07-29")
	assert_eq(str(m.masal_last_date), "14050507")


func test_snapshot_apply_roundtrip():
	var saved := CloudSave.snapshot()
	var coins0 := Store.coins
	CloudSave.apply_merge({"coins": coins0 + 1234, "masal_collected": ["m999x"]})
	assert_eq(Store.coins, coins0 + 1234)
	assert_true("m999x" in Store.masal_collected)
	Store.coins = int(saved.coins)
	Store.masal_collected.erase("m999x")
	Store.save()
