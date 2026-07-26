extends GutTest
## Reminder POLICY. The platform half needs a device; this half decides what a player is
## told and when — including when to stop telling them, which is the part that gets an app
## uninstalled if it is wrong.


func before_each():
	Store.notify_on = true
	Store.notify_hour = 20
	Store.notify_ignored = 0
	Store.notify_last_planned = ""
	Store.streak_count = 0
	Store.streak_last = ""
	Store.inventory = {}
	I18n.locale = "fa"


func _now(hour := 10, day := 26) -> Dictionary:
	return {"year": 2026, "month": 7, "day": day, "hour": hour, "minute": 0, "second": 0,
		"weekday": 0, "dst": false}


func test_nothing_is_scheduled_when_reminders_are_off():
	Store.notify_on = false
	assert_eq(Notify.plan(_now()).size(), 0)


func test_a_week_is_scheduled_ahead():
	# The app may never be reopened to re-sync, so the schedule must reach into the future.
	var p := Notify.plan(_now())
	assert_gte(p.size(), 5, "should cover several days ahead")
	var span: int = int(p[p.size() - 1].at) - int(p[0].at)
	assert_gte(span, 5 * 86400, "the plan must span most of a week")


func test_reminders_never_land_in_the_quiet_hours():
	for h in [0, 3, 6, 23]:
		Store.notify_hour = h
		for r in Notify.plan(_now()):
			var local_hour := Notify.unix_to_local_hour(int(r.at))
			assert_between(local_hour, Notify.QUIET_END, Notify.MAX_HOUR,
				"scheduled at %02d:00 local with notify_hour=%d" % [local_hour, h])


func test_reminders_fire_at_the_chosen_LOCAL_hour():
	# Godot's Time helpers are UTC. Scheduling naively would fire a 20:00 reminder at
	# 23:30 in Tehran (UTC+3:30) — the same timezone trap that broke the streak.
	for h in [9, 15, 20, 22]:
		Store.notify_hour = h
		for r in Notify.plan(_now(8)):
			assert_eq(Notify.unix_to_local_hour(int(r.at)), h if r.kind != "streak" else h + 1,
				"reminder must land at the hour the player picked, in THEIR timezone")


func test_local_conversion_round_trips():
	for h in [9, 12, 20, 22]:
		assert_eq(Notify.unix_to_local_hour(Notify.local_time_to_unix("2026-07-26", h)), h)


func test_today_is_skipped_once_the_hour_has_passed():
	var late := Notify.plan(_now(22))
	for r in late:
		assert_gt(int(r.at), int(Time.get_unix_time_from_datetime_string("2026-07-26")) + 22 * 3600,
			"must not schedule a reminder in the past")


func test_no_reminder_today_if_already_played():
	Store.streak_last = "2026-07-26"
	var p := Notify.plan(_now(10))
	for r in p:
		var d := Time.get_datetime_dict_from_unix_time(int(r.at))
		assert_ne(d.day, 26, "someone who already played today must not be nudged today")


func test_streak_warning_replaces_the_gentle_nudge():
	Store.streak_count = 7
	var p := Notify.plan(_now(10))
	assert_eq(p[0].kind, "streak")
	assert_true(p[0].title.contains(I18n.digits(7)), "the streak length belongs in the title")


func test_streak_warning_mentions_a_shield_when_owned():
	Store.streak_count = 5
	Store.inventory = {"shield": 1}
	var p := Notify.plan(_now(10))
	assert_eq(p[0].body, I18n.t("notif_streak_shield"))


func test_short_streaks_get_the_gentle_nudge():
	Store.streak_count = 1
	assert_eq(Notify.plan(_now(10))[0].kind, "daily")


func test_later_days_use_comeback_wording():
	var kinds: Array = Notify.plan(_now(10)).map(func(r): return r.kind)
	assert_true(kinds.has("comeback"), "a player gone for days needs different words")


# ---------- the part that keeps us from becoming spam ----------
func test_backoff_widens_as_reminders_are_ignored():
	assert_eq(Notify.backoff_step(0), 1)
	assert_eq(Notify.backoff_step(2), 1)
	assert_eq(Notify.backoff_step(4), 2)
	assert_eq(Notify.backoff_step(8), 3)
	assert_eq(Notify.backoff_step(30), 7, "an unresponsive player gets at most a weekly nudge")


func test_ignored_player_receives_far_fewer_reminders():
	var attentive := Notify.plan(_now(10)).size()
	Store.notify_ignored = 12
	var ignored := Notify.plan(_now(10)).size()
	assert_lt(ignored, attentive, "we must nag an absent player less, not the same")
	assert_lte(ignored, 2)


func test_playing_resets_the_backoff():
	Store.notify_ignored = 6
	Notify.on_played()
	assert_eq(Store.notify_ignored, 0)


func test_reminders_are_uniquely_identified():
	var ids := {}
	for r in Notify.plan(_now(10)):
		assert_false(ids.has(r.id), "duplicate notification id %s would overwrite" % r.id)
		ids[r.id] = true


func test_every_reminder_has_real_localized_text():
	for r in Notify.plan(_now(10)):
		assert_gt(String(r.title).length(), 3, "empty title for %s" % r.kind)
		assert_gt(String(r.body).length(), 8, "empty body for %s" % r.kind)
		assert_false(String(r.title).begins_with("notif_"), "untranslated key leaked: " + r.title)
		assert_false(String(r.body).begins_with("notif_"), "untranslated key leaked: " + r.body)


func test_platform_is_absent_in_this_build():
	# No plugin on desktop/CI: sync() must be a harmless no-op rather than an error.
	assert_false(Notify.available())
	Notify.sync()
	pass_test("sync() without a plugin did not raise")
