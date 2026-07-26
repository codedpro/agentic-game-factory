extends Node
## Autoload "Notify" — local reminder scheduling.
##
## Two halves, deliberately separated:
##  * the POLICY (this file's `plan()`) is pure GDScript and fully unit-tested — it decides
##    what a player should be reminded about, when, and when to stop bothering them;
##  * the PLATFORM half schedules those reminders with the OS through an Android plugin,
##    and is absent on desktop/CI, where `available()` is false and nothing is scheduled.
##
## Reminders are strictly about the player's own game state (a waiting fal, a streak about
## to break). No promotions, no ads — those are store-policy risks and simply rude.

## The scheduler addon (godot-mobile-plugins/godot-notification-scheduler). Loaded
## DYNAMICALLY: its NotificationScheduler/NotificationData classes only exist when the
## addon is installed, and a direct class reference would break every other build.
const SCHEDULER_PATH := "res://addons/NotificationSchedulerPlugin/NotificationScheduler.gd"
const DATA_PATH := "res://addons/NotificationSchedulerPlugin/model/NotificationData.gd"
const CHANNEL_PATH := "res://addons/NotificationSchedulerPlugin/model/NotificationChannel.gd"
const CHANNEL_ID := "daily_reminders"
const DAYS_AHEAD := 7            # schedule a week out: the app may not open again to re-sync
const QUIET_START := 0           # never fire between 00:00 and 08:00 local
const QUIET_END := 8
const STREAK_HOUR_OFFSET := 1    # streak warnings land a bit later than the gentle nudge
const MAX_HOUR := 22

var _plugin: Node = null           # NotificationScheduler instance
var _data_cls: GDScript = null
var _channel_cls: GDScript = null


func _ready() -> void:
	if OS.get_name() != "Android" or not ResourceLoader.exists(SCHEDULER_PATH):
		return
	var scheduler_cls: GDScript = load(SCHEDULER_PATH)
	_data_cls = load(DATA_PATH)
	_channel_cls = load(CHANNEL_PATH)
	if scheduler_cls == null or _data_cls == null or _channel_cls == null:
		return
	_plugin = scheduler_cls.new()
	add_child(_plugin)
	_plugin.initialize()
	if not _plugin.has_method("schedule"):
		_plugin = null
		return
	# Android 8+ refuses to post a notification without a channel.
	var ch = _channel_cls.new().set_id(CHANNEL_ID) \
		.set_name(I18n.t("notifications")) \
		.set_importance(_channel_cls.Importance.DEFAULT)
	_plugin.create_notification_channel(ch)
	request_permission()
	sync()


func available() -> bool:
	return _plugin != null


## Ask for POST_NOTIFICATIONS (Android 13+). Denial simply means no reminders — never an error.
func request_permission() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("has_post_notifications_permission") \
			and not _plugin.has_post_notifications_permission():
		_plugin.request_post_notifications_permission()


## Clamp an hour into the allowed waking window.
func _safe_hour(h: int) -> int:
	return clampi(h, QUIET_END, MAX_HOUR)


func _date_key(d: Dictionary) -> String:
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Minutes this device is ahead of UTC (Iran = +210). Godot's Time.* helpers are all UTC,
## so a "20:00" reminder computed naively would fire at 23:30 local in Tehran (LESSONS L31).
func _tz_bias_seconds() -> int:
	var tz := Time.get_time_zone_from_system()
	return int(tz.get("bias", 0)) * 60


## Absolute epoch for a LOCAL wall-clock hour on a local date.
func local_time_to_unix(date_key: String, hour: int) -> int:
	return int(Time.get_unix_time_from_datetime_string(date_key)) + hour * 3600 - _tz_bias_seconds()


## Local hour of an absolute epoch — the inverse, used by tests and the UI.
func unix_to_local_hour(at: int) -> int:
	return int(Time.get_datetime_dict_from_unix_time(at + _tz_bias_seconds()).hour)


## How many days in a row the player has been reminded without coming back.
## Used to back off rather than nag — an ignored reminder is a bad reminder.
func backoff_step(ignored: int) -> int:
	if ignored <= 2:
		return 1        # daily
	if ignored <= 5:
		return 2        # every other day
	if ignored <= 9:
		return 3
	return 7            # weekly at most


## The reminder plan for the next DAYS_AHEAD days.
## `now` is a datetime dict (local). Returns [{id, at, kind, title, body}] sorted by time.
func plan(now: Dictionary = {}) -> Array:
	var out: Array = []
	if not Store.notify_on:
		return out
	var n: Dictionary = now if not now.is_empty() else Time.get_datetime_dict_from_system()
	var today := _date_key(n)
	var played_today: bool = Store.streak_last == today
	var hour := _safe_hour(Store.notify_hour)
	var step := backoff_step(Store.notify_ignored)


	for day in range(0, DAYS_AHEAD + 1):
		if day % step != 0:
			continue
		# today only counts if the reminder hour has not already passed
		if day == 0 and (played_today or n.hour >= hour):
			continue
		var kind := "daily"
		var at_hour := hour
		if day == 0 and Store.streak_count >= 3:
			kind = "streak"
			at_hour = _safe_hour(hour + STREAK_HOUR_OFFSET)
		elif day >= 3:
			kind = "comeback"
		var at: int = local_time_to_unix(today, at_hour) + day * 86400
		out.append({
			"id": 1000 + day,
			"at": at,
			"kind": kind,
			"title": _title(kind),
			"body": _body(kind),
		})
	out.sort_custom(func(a, b): return a.at < b.at)
	return out


func _title(kind: String) -> String:
	match kind:
		"streak": return I18n.t("notif_streak_title") % I18n.digits(Store.streak_count)
		"comeback": return I18n.t("notif_comeback_title")
		_: return I18n.t("notif_daily_title")


func _body(kind: String) -> String:
	match kind:
		"streak":
			if int(Store.inventory.get("shield", 0)) > 0:
				return I18n.t("notif_streak_shield")
			return I18n.t("notif_streak_body")
		"comeback": return I18n.t("notif_comeback_body")
		_: return I18n.t("notif_daily_body")


## Push the current plan to the OS. Safe to call often; it replaces what was scheduled.
## There is no bulk cancel, but plan() uses deterministic ids so we can clear the range.
func sync() -> void:
	if not available():
		return
	for day in range(0, DAYS_AHEAD + 1):
		_plugin.cancel(1000 + day)
	if not Store.notify_on:
		return
	var now := int(Time.get_unix_time_from_system())
	for r in plan():
		var delay: int = int(r.at) - now
		if delay <= 0:
			continue
		# One-shot per reminder with an explicit delay: setRepeating() is inexact and would
		# drift the hour the player chose. sync() re-plans on every app open.
		var nd = _data_cls.new().set_id(int(r.id)) \
			.set_channel_id(CHANNEL_ID) \
			.set_title(String(r.title)) \
			.set_content(String(r.body)) \
			.set_delay(delay)
		_plugin.schedule(nd)


## "My reminders never arrive" helper. Aggressive OEM battery managers (MIUI, Samsung,
## Huawei) kill scheduled alarms, and Android 14+ denies exact alarms by default — both are
## fixable only by the user, through system dialogs. This is why the build declares the
## SCHEDULE_EXACT_ALARM and battery-optimization permissions; it is the only place they are used.
func fix_delivery() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("has_schedule_exact_alarm_permission") \
			and not _plugin.has_schedule_exact_alarm_permission():
		_plugin.request_schedule_exact_alarm_permission()
		return
	if _plugin.has_method("has_battery_optimizations_permission") \
			and not _plugin.has_battery_optimizations_permission():
		_plugin.request_battery_optimizations_permission()
		return
	if _plugin.has_method("open_app_info_settings"):
		_plugin.open_app_info_settings()


## Called when the player actually plays: clears the nagging counter and re-plans.
func on_played() -> void:
	if Store.notify_ignored != 0:
		Store.notify_ignored = 0
		Store.save()
	sync()


## Called on app start: if reminders fired since the last visit and the player still did
## not play those days, count them as ignored so the schedule backs off.
func on_app_open() -> void:
	var today := _date_key(Time.get_datetime_dict_from_system())
	if Store.notify_last_planned != "" and Store.notify_last_planned != today:
		if Store.streak_last != today:
			Store.notify_ignored += 1
		else:
			Store.notify_ignored = 0
	Store.notify_last_planned = today
	Store.save()
	sync()
