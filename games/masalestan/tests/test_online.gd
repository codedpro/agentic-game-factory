extends GutTest
## The scoreboard is optional infrastructure: these tests pin the rules that keep it from
## ever harming a player who is offline or has no server.


func before_each():
	Store.pending_scores = {}
	Store.nickname = ""
	Online.nickname = ""
	Online.last_rank = 0


func test_device_id_is_generated_once_and_is_opaque():
	assert_gt(Online.device_id.length(), 15, "needs enough entropy to be unique")
	assert_eq(Online.device_id, Store.device_id, "must persist, not regenerate per launch")
	assert_false(Online.device_id.contains(" "))


func test_scores_are_queued_when_there_is_no_nickname():
	Online.submit(1500, "endless")
	assert_eq(int(Store.pending_scores.get("endless", 0)), 1500,
		"a score earned before signing up must not be lost")


func test_queue_keeps_the_best_score_per_mode():
	Online.submit(1000, "endless")
	Online.submit(400, "endless")
	assert_eq(int(Store.pending_scores["endless"]), 1000, "a worse run must not overwrite a better one")
	Online.submit(2500, "endless")
	assert_eq(int(Store.pending_scores["endless"]), 2500)


func test_modes_are_queued_separately():
	Online.submit(900, "endless")
	Online.submit(300, "daily")
	assert_eq(int(Store.pending_scores["endless"]), 900)
	assert_eq(int(Store.pending_scores["daily"]), 300)


func test_zero_and_negative_scores_are_ignored():
	Online.submit(0, "endless")
	Online.submit(-5, "endless")
	assert_true(Store.pending_scores.is_empty())


func test_queue_survives_a_save_round_trip():
	Online.submit(3200, "endless")
	Store.save()
	Store.pending_scores = {}
	Store.load_data()
	assert_eq(int(Store.pending_scores.get("endless", 0)), 3200)


func test_nickname_validation_matches_the_server_rules():
	assert_false(Online.nickname_is_valid(""))
	assert_false(Online.nickname_is_valid("a"))
	assert_false(Online.nickname_is_valid("x".repeat(19)))
	assert_true(Online.nickname_is_valid("رضا"))
	assert_true(Online.nickname_is_valid("player_1"))


func test_has_nickname_reflects_store():
	assert_false(Online.has_nickname())
	Online.nickname = "someone"
	assert_true(Online.has_nickname())


func test_flush_without_nickname_is_a_no_op():
	Online.submit(700, "endless")
	Online.flush()
	assert_eq(int(Store.pending_scores.get("endless", 0)), 700,
		"nothing may be dropped just because the player has no name yet")


func test_reset_progress_drops_unsent_scores_but_keeps_global_identity():
	# Resetting local progress must not orphan the player's leaderboard entry: the
	# nickname is registered server-side against this device and stays valid.
	Store.nickname = "someone"
	Online.nickname = "someone"
	Online.submit(500, "endless")
	var dev := Store.device_id
	Store.reset_progress()
	assert_true(Store.pending_scores.is_empty(), "unsent local scores are part of progress")
	assert_eq(Store.nickname, "someone", "the global name is identity, not progress")
	assert_eq(Store.device_id, dev, "the install id is not player data and should survive")
