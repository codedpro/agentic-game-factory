extends GutTest
## Shop economy: repeatable consumables, cosmetics, streak shield, IAP safety.


func before_each():
	Store.coins = 0
	Store.inventory = {}
	Store.frames_owned = ["classic"]
	Store.frame_active = "classic"
	Store.supporter_level = 0


# ---------- consumables are repeatable forever ----------
func test_item_can_be_bought_repeatedly():
	var cost := Economy.item_cost("shield")
	var per: int = int(Economy.ITEMS.shield.amount)
	Store.coins = cost * 5
	for i in 5:
		assert_true(Economy.buy_item("shield"), "purchase %d must succeed" % i)
	assert_eq(Economy.count("shield"), per * 5, "each purchase must stack")
	assert_eq(Store.coins, 0)


func test_cannot_buy_without_coins():
	var broke := Economy.item_cost("shield") - 1
	Store.coins = broke
	assert_false(Economy.buy_item("shield"))
	assert_eq(Economy.count("shield"), 0)
	assert_eq(Store.coins, broke, "a failed purchase must not spend coins")


func test_hint_pack_grants_its_stated_amount():
	Store.coins = Economy.item_cost("hint")
	Economy.buy_item("hint")
	assert_eq(Economy.count("hint"), int(Economy.ITEMS.hint.amount))


func test_use_item_decrements_and_floors_at_zero():
	Store.coins = Economy.item_cost("shield")
	Economy.buy_item("shield")
	var n := Economy.count("shield")
	assert_true(Economy.use_item("shield"))
	assert_eq(Economy.count("shield"), n - 1)
	Store.inventory["shield"] = 0
	assert_false(Economy.use_item("shield"), "cannot use what you do not have")
	assert_eq(Economy.count("shield"), 0)


# ---------- the streak shield ----------
func test_shield_rescues_a_missed_day():
	var today := Time.get_date_string_from_system()
	var two_days_ago := Time.get_date_string_from_unix_time(
		int(Time.get_unix_time_from_datetime_string(today)) - 172800)
	Store.streak_last = two_days_ago
	Store.streak_count = 6
	Store.inventory = {"shield": 1}
	Store.streak_shield_used = false
	Store.update_streak()
	assert_eq(Store.streak_count, 7, "the shield must carry the streak through one missed day")
	assert_eq(Economy.count("shield"), 0, "the shield must be consumed")
	assert_true(Store.streak_shield_used, "the UI needs to know it was used")


func test_streak_breaks_without_a_shield():
	var today := Time.get_date_string_from_system()
	var two_days_ago := Time.get_date_string_from_unix_time(
		int(Time.get_unix_time_from_datetime_string(today)) - 172800)
	Store.streak_last = two_days_ago
	Store.streak_count = 6
	Store.inventory = {}
	Store.update_streak()
	assert_eq(Store.streak_count, 1)


func test_shield_does_not_cover_a_long_absence():
	Store.streak_last = "2020-01-01"
	Store.streak_count = 30
	Store.inventory = {"shield": 3}
	Store.update_streak()
	assert_eq(Store.streak_count, 1, "a shield covers ONE missed day, not a month")
	assert_eq(Economy.count("shield"), 3, "and must not be spent")


# ---------- treasury keys ----------
func test_key_unlocks_one_poem_and_is_consumed():
	Store.masal_collected = []
	Store.inventory = {"key": 2}
	var before := Masal.collected_count()
	var poem := Economy.use_key()
	assert_false(poem.is_empty())
	assert_eq(Masal.collected_count(), before + 1)
	assert_eq(Economy.count("key"), 1)


func test_key_is_not_eaten_when_collection_is_complete():
	Store.masal_collected = Masal.levels.map(func(l): return l.id)
	Store.inventory = {"key": 1}
	assert_false(Economy.key_is_useful())
	assert_true(Economy.use_key().is_empty())
	assert_eq(Economy.count("key"), 1, "a key with nothing to unlock must not be spent")


func test_daily_fal_is_never_purchasable():
	# The ritual must stay earned: nothing in the catalogue grants today's fal.
	for id in Economy.ITEMS:
		assert_ne(id, "daily_masal")
	for sku in IAP.PRODUCTS:
		assert_false(String(sku).contains("fal"),
			"real money must never buy the daily fal (%s)" % sku)


# ---------- cosmetics ----------
func test_frame_purchase_and_selection():
	Store.coins = int(Economy.FRAMES.lapis.cost)
	assert_true(Economy.buy_frame("lapis"))
	assert_true("lapis" in Store.frames_owned)
	assert_eq(Store.frame_active, "lapis")
	assert_eq(Economy.frame_color(), Economy.FRAMES.lapis.color)
	assert_false(Economy.buy_frame("lapis"), "cannot buy the same frame twice")


func test_default_frame_is_free_and_owned():
	assert_eq(int(Economy.FRAMES.classic.cost), 0)
	assert_true("classic" in Store.frames_owned)


# ---------- mission reroll ----------
func test_reroll_swaps_a_mission_and_costs_an_item():
	Missions.state = {}
	Missions.ensure_today()
	Store.inventory = {"reroll": 1}
	var before: String = Missions.state.list[0].id
	assert_true(Missions.reroll(0))
	assert_eq(Economy.count("reroll"), 0)
	assert_ne(Missions.state.list[0].id, before, "the mission must actually change")
	assert_eq(Missions.state.list[0].progress, 0)


func test_reroll_without_an_item_fails():
	Missions.state = {}
	Missions.ensure_today()
	Store.inventory = {}
	assert_false(Missions.reroll(0))


# ---------- IAP safety ----------
func test_iap_unavailable_without_a_plugin():
	# The offline/dev build has no billing plugin; the shop must degrade, not crash.
	assert_false(IAP.available())
	assert_eq(IAP.price("coins_small"), "")


func test_iap_purchase_without_plugin_reports_failure():
	var got := []
	var cb := func(sku, ok, msg): got.append([sku, ok])
	IAP.purchase_finished.connect(cb)
	IAP.purchase("coins_small")
	IAP.purchase_finished.disconnect(cb)
	assert_eq(got.size(), 1)
	assert_false(got[0][1], "no plugin means the purchase must fail cleanly")
	assert_eq(Store.coins, 0, "and must never grant coins")


func test_every_iap_product_grants_something():
	for sku in IAP.PRODUCTS:
		var p: Dictionary = IAP.PRODUCTS[sku]
		assert_true(p.coins > 0 or p.supporter > 0, "%s grants nothing" % sku)


func test_supporter_purchase_is_repeatable_and_cosmetic():
	Store.supporter_level = 0
	IAP._grant("supporter_tip")
	IAP._grant("supporter_tip")
	assert_eq(Store.supporter_level, 2, "supporting again must stack the badge")
	assert_eq(Store.coins, int(IAP.PRODUCTS.supporter_tip.coins) * 2)


# ---------- persistence ----------
func test_inventory_and_cosmetics_survive_a_save_round_trip():
	Store.coins = 777
	Store.inventory = {"shield": 2, "key": 1}
	Store.supporter_level = 3
	Store.frames_owned = ["classic", "lapis"]
	Store.frame_active = "lapis"
	Store.save()
	Store.coins = 0
	Store.inventory = {}
	Store.supporter_level = 0
	Store.frames_owned = ["classic"]
	Store.frame_active = "classic"
	Store.load_data()
	assert_eq(Store.coins, 777)
	assert_eq(Economy.count("shield"), 2)
	assert_eq(Store.supporter_level, 3)
	assert_eq(Store.frame_active, "lapis")


# ---------- task history ----------
func test_finished_day_is_archived_when_the_day_rolls_over():
	Store.mission_history = []
	Missions.state = {"date": "20260101", "list": [
		{"id": "m_merges", "target": 50, "progress": 50, "reward": 50, "done": true},
		{"id": "m_stones", "target": 5, "progress": 2, "reward": 70, "done": false}]}
	Missions.run_key = ""
	Missions.ensure_today()          # a different day: the old one must be archived
	assert_eq(Store.mission_history.size(), 1, "yesterday must be kept, not discarded")
	var day: Dictionary = Store.mission_history[0]
	assert_eq(day.d, "20260101")
	assert_eq(int(day.done), 1)
	assert_eq(int(day.total), 2)
	assert_eq(day.items.size(), 2, "the tasks themselves are kept, not just a count")


func test_a_day_is_never_archived_twice():
	Store.mission_history = []
	Missions.state = {"date": "20260101", "list": [
		{"id": "m_games", "target": 3, "progress": 3, "reward": 50, "done": true}]}
	Missions.run_key = ""
	Missions.ensure_today()
	var n := Store.mission_history.size()
	Missions.state = {"date": "20260101", "list": Missions.state.list}
	Missions.ensure_today()
	assert_eq(Store.mission_history.size(), n, "re-rolling must not duplicate a day")


func test_history_is_bounded_and_newest_first():
	Store.mission_history = []
	for i in 70:
		Store.mission_history.append({"d": "2026010%d" % i, "done": 0, "total": 3, "items": []})
	Missions.state = {"date": "20251231", "list": [
		{"id": "m_games", "target": 2, "progress": 0, "reward": 50, "done": false}]}
	Missions.run_key = ""
	Missions.ensure_today()
	assert_lte(Store.mission_history.size(), 60, "history must not grow without bound")
	var h := Missions.history()
	assert_eq(h[0].d, Store.mission_history[Store.mission_history.size() - 1].d,
		"history() returns newest first for display")


func test_history_survives_a_save_round_trip():
	Store.mission_history = [{"d": "20260101", "done": 2, "total": 3, "items": []}]
	Store.save()
	Store.mission_history = []
	Store.load_data()
	assert_eq(Store.mission_history.size(), 1)
	assert_eq(int(Store.mission_history[0].done), 2)


func test_every_mission_type_has_an_icon():
	for m in Missions.POOL:
		var name: String = Missions.icon_for(m.id)
		assert_true(UI.has_icon(name), "mission %s maps to missing icon %s" % [m.id, name])
