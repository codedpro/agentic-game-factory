extends Node
## Autoload "Store" — persistent settings, records, achievements, economy, treasury.

const PATH := "user://save.cfg"
const ACH_IDS := ["masal1", "masal10", "masal40", "masal100", "words100",
	"words500", "bonus50", "chain5", "rush800", "daily1", "streak7", "treasury30"]
const THEME_IDS := ["classic", "sunset", "neon", "garden"]
const THEME_COST := {"classic": 0, "sunset": 3000, "neon": 5000, "garden": 8000}

var best_score := 0
var sound_on := true
var music_on := true
var vibrate_on := true
var first_run := true
var goal_index := 0
var games_played := 0
var achievements: Array = []
var top_scores: Array = []       # [{"s": int, "d": "yyyy-mm-dd"}] max 10
var daily_best: Dictionary = {}  # "yyyymmdd" -> int
var coins := 0
var themes_owned: Array = ["classic"]
var theme_active := "classic"
var streak_count := 0
var streak_last := ""            # yyyy-mm-dd of last played day
var masal_collected: Array = []  # proverb ids unlocked in the treasury
var masal_last_date := ""        # yyyymmdd of last daily proverb received
var daily_log: Array = []        # [{"id","d":"yyyy-mm-dd","hints":int,"words":int}] newest last
var campaign_index := 0          # levels of the سفر completed
var login_gift_day := ""         # yyyymmdd of the last daily-login coin gift
var daily_run: Dictionary = {}   # {"key": yyyymmdd, "snap": Puzzle.snapshot()} — resume an interrupted daily
var words_total := 0             # lifetime solved target words (achievements/missions)
var bonus_total := 0             # lifetime bonus words found
var inventory: Dictionary = {}   # consumable id -> count
var supporter_level := 0         # repeatable "حامی" purchases, cosmetic only
var notify_on := true
var notify_hour := 20            # local hour for the gentle daily nudge
var notify_ignored := 0          # consecutive reminders that did not bring the player back
var notify_last_planned := ""
var device_id := ""                 # random per-install id for the scoreboard; no personal data
var nickname := ""                  # unique global-scoreboard name
var pending_scores: Dictionary = {} # mode -> best score earned while offline
var account_email := ""             # sign-in identifier; required only to buy
var account_token := ""             # session token, NOT a password — the password is never stored
var pending_receipts: Array = []    # [{sku, t, store}] paid but not yet server-verified
var mission_history: Array = []     # [{d, done, total, items}] newest last, capped
var frames_owned: Array = ["classic"]
var frame_active := "classic"


var _dirty := false
var load_failed := false
var streak_shield_used := false   # set when a shield rescued the streak, for the UI


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cf := ConfigFile.new()
	var err := cf.load(PATH)
	if err != OK:
		# A truncated/corrupt save must not silently wipe progress: try the backup
		# before falling back to defaults (audit finding).
		if FileAccess.file_exists(PATH) and cf.load(PATH + ".bak") == OK:
			push_warning("save.cfg unreadable (%d) — recovered from backup" % err)
		else:
			load_failed = FileAccess.file_exists(PATH)
			return
	best_score = cf.get_value("game", "best_score", 0)
	sound_on = cf.get_value("game", "sound_on", true)
	music_on = cf.get_value("game", "music_on", true)
	vibrate_on = cf.get_value("game", "vibrate_on", true)
	first_run = cf.get_value("game", "first_run", true)
	goal_index = cf.get_value("game", "goal_index", 0)
	games_played = cf.get_value("game", "games_played", 0)
	achievements = cf.get_value("game", "achievements", [])
	top_scores = cf.get_value("game", "top_scores", [])
	daily_best = cf.get_value("game", "daily_best", {})
	coins = cf.get_value("game", "coins", 0)
	themes_owned = cf.get_value("game", "themes_owned", ["classic"])
	theme_active = cf.get_value("game", "theme_active", "classic")
	streak_count = cf.get_value("game", "streak_count", 0)
	streak_last = cf.get_value("game", "streak_last", "")
	masal_collected = cf.get_value("game", "masal_collected", [])
	masal_last_date = cf.get_value("game", "masal_last_date", "")
	daily_log = cf.get_value("game", "daily_log", [])
	campaign_index = cf.get_value("game", "campaign_index", 0)
	login_gift_day = cf.get_value("game", "login_gift_day", "")
	daily_run = cf.get_value("game", "daily_run", {})
	words_total = cf.get_value("game", "words_total", 0)
	bonus_total = cf.get_value("game", "bonus_total", 0)
	inventory = cf.get_value("game", "inventory", {})
	supporter_level = cf.get_value("game", "supporter_level", 0)
	notify_on = cf.get_value("game", "notify_on", true)
	notify_hour = cf.get_value("game", "notify_hour", 20)
	notify_ignored = cf.get_value("game", "notify_ignored", 0)
	notify_last_planned = cf.get_value("game", "notify_last_planned", "")
	device_id = cf.get_value("game", "device_id", "")
	nickname = cf.get_value("game", "nickname", "")
	pending_scores = cf.get_value("game", "pending_scores", {})
	account_email = cf.get_value("game", "account_email", "")
	account_token = cf.get_value("game", "account_token", "")
	pending_receipts = cf.get_value("game", "pending_receipts", [])
	mission_history = cf.get_value("game", "mission_history", [])
	frames_owned = cf.get_value("game", "frames_owned", ["classic"])
	frame_active = cf.get_value("game", "frame_active", "classic")
	I18n.locale = cf.get_value("game", "locale", "fa")
	var m: Dictionary = cf.get_value("game", "missions", {})
	if not m.is_empty():
		Missions.state = m


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "best_score", best_score)
	cf.set_value("game", "sound_on", sound_on)
	cf.set_value("game", "music_on", music_on)
	cf.set_value("game", "vibrate_on", vibrate_on)
	cf.set_value("game", "first_run", first_run)
	cf.set_value("game", "goal_index", goal_index)
	cf.set_value("game", "games_played", games_played)
	cf.set_value("game", "achievements", achievements)
	cf.set_value("game", "top_scores", top_scores)
	cf.set_value("game", "daily_best", daily_best)
	cf.set_value("game", "coins", coins)
	cf.set_value("game", "themes_owned", themes_owned)
	cf.set_value("game", "theme_active", theme_active)
	cf.set_value("game", "streak_count", streak_count)
	cf.set_value("game", "streak_last", streak_last)
	cf.set_value("game", "masal_collected", masal_collected)
	cf.set_value("game", "masal_last_date", masal_last_date)
	cf.set_value("game", "daily_log", daily_log)
	cf.set_value("game", "campaign_index", campaign_index)
	cf.set_value("game", "login_gift_day", login_gift_day)
	cf.set_value("game", "daily_run", daily_run)
	cf.set_value("game", "words_total", words_total)
	cf.set_value("game", "bonus_total", bonus_total)
	cf.set_value("game", "inventory", inventory)
	cf.set_value("game", "supporter_level", supporter_level)
	cf.set_value("game", "notify_on", notify_on)
	cf.set_value("game", "notify_hour", notify_hour)
	cf.set_value("game", "notify_ignored", notify_ignored)
	cf.set_value("game", "notify_last_planned", notify_last_planned)
	cf.set_value("game", "device_id", device_id)
	cf.set_value("game", "nickname", nickname)
	cf.set_value("game", "pending_scores", pending_scores)
	cf.set_value("game", "account_email", account_email)
	cf.set_value("game", "account_token", account_token)
	cf.set_value("game", "pending_receipts", pending_receipts)
	cf.set_value("game", "mission_history", mission_history)
	cf.set_value("game", "frames_owned", frames_owned)
	cf.set_value("game", "frame_active", frame_active)
	cf.set_value("game", "missions", Missions.state)
	cf.set_value("game", "locale", I18n.locale)
	# Write to a temp file first, keep the previous file as .bak, then swap — a crash
	# mid-write can then never destroy the only copy.
	var tmp := PATH + ".tmp"
	if cf.save(tmp) != OK:
		push_warning("could not write save file")
		return
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, PATH + ".bak")
	DirAccess.rename_absolute(tmp, PATH)
	_dirty = false
	# best-effort cloud backup; throttled inside, no-op signed out (L72)
	if has_node("/root/CloudSave"):
		get_node("/root/CloudSave").push_soon()


## Coalesce many rapid writes (missions fire several per drop) into one flush.
func save_soon() -> void:
	if _dirty:
		return
	_dirty = true
	_flush.call_deferred()


func _flush() -> void:
	if _dirty:
		save()


func flush() -> void:
	if _dirty:
		save()


func submit_score(s: int) -> bool:
	if s > best_score:
		best_score = s
		return true
	return false


func update_streak() -> void:
	var today := Time.get_date_string_from_system()
	if streak_last == today:
		return
	# Derive "yesterday" from the LOCAL date, not from wall-clock minus 24h: Godot's
	# unix-time helpers are UTC, so in Iran (UTC+3:30) every session between 00:00 and
	# 03:29 local produced today's own date and silently reset the streak (audit finding).
	var yesterday := Time.get_date_string_from_unix_time(
		int(Time.get_unix_time_from_datetime_string(today)) - 86400)
	if streak_last == yesterday:
		streak_count += 1
	else:
		# one missed day can be covered by a purchased shield
		var day_before := Time.get_date_string_from_unix_time(
			int(Time.get_unix_time_from_datetime_string(today)) - 172800)
		if streak_last == day_before and int(inventory.get("shield", 0)) > 0:
			inventory["shield"] = int(inventory["shield"]) - 1
			streak_count += 1
			streak_shield_used = true
		else:
			streak_count = 1
	streak_last = today


## Call once at game over. daily_key = "yyyymmdd" or "" for endless mode.
## The streak counts DAILY-CHALLENGE days only — it must mean "did the ritual",
## not merely "opened the app" (research finding).
func record_game_over(s: int, daily_key := "") -> Dictionary:
	games_played += 1
	if daily_key != "":
		update_streak()
	# best_score means "best finished ENDLESS run" — daily scores have their own board,
	# and a tie is not a new record (strict >).
	var new_best := daily_key == "" and s > best_score and s > 0
	if daily_key == "":
		best_score = maxi(best_score, s)
		top_scores.append({"s": s, "d": Time.get_date_string_from_system()})
		top_scores.sort_custom(func(a, b): return a.s > b.s)
		if top_scores.size() > 10:
			top_scores.resize(10)
	else:
		daily_best[daily_key] = maxi(int(daily_best.get(daily_key, 0)), s)
	save()
	return {"new_best": new_best}


func add_coins(n: int) -> void:
	coins += n
	save_soon()


func buy_theme(id: String) -> bool:
	if id in themes_owned or not id in THEME_IDS or coins < THEME_COST[id]:
		return false
	coins -= THEME_COST[id]
	themes_owned.append(id)
	theme_active = id
	save()
	return true


func unlock(id: String) -> bool:
	if id in achievements or not id in ACH_IDS:
		return false
	achievements.append(id)
	add_coins(500)
	return true


func has_ach(id: String) -> bool:
	return id in achievements


func collect_masal(id: String) -> bool:
	if id in masal_collected:
		return false
	masal_collected.append(id)
	save()
	return true


func reset_progress() -> void:
	best_score = 0
	goal_index = 0
	games_played = 0
	achievements = []
	top_scores = []
	daily_best = {}
	coins = 0
	themes_owned = ["classic"]
	theme_active = "classic"
	streak_count = 0
	streak_last = ""
	masal_collected = []
	masal_last_date = ""
	daily_log = []
	campaign_index = 0
	words_total = 0
	bonus_total = 0
	daily_run = {}
	login_gift_day = ""
	inventory = {}
	supporter_level = 0
	notify_on = true
	notify_hour = 20
	notify_ignored = 0
	notify_last_planned = ""
	# Local progress resets; the global identity does NOT — device_id and nickname stay
	# valid server-side, so the player keeps their leaderboard name. Unsent scores are
	# part of the reset progress and are dropped.
	pending_scores = {}
	# The account and any receipt still awaiting verification are deliberately NOT reset:
	# the player paid real money, and wiping local progress must not cost them that.
	frames_owned = ["classic"]
	frame_active = "classic"
	first_run = true
	Missions.state = {}
	save()
