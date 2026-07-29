extends Node
## Autoload "CloudSave" — best-effort progress backup for signed-in players (L72).
##
## Rules:
##  * The game NEVER depends on this: signed out or offline, nothing here runs or blocks.
##  * Merge, don't overwrite: counters take the max, collections take the union, so a
##    fresh device restoring an account can never destroy newer local progress.
##  * Every network failure is silent. The next Store.save() will try again.

const PUSH_INTERVAL := 90.0     # seconds between pushes at most
const SAVE_VERSION := 1

var _last_push := -1e9
var _busy := false
var _pending := false


func _ready() -> void:
	Account.auth_changed.connect(_on_auth_changed)


## Called from Store.save() — cheap when signed out; throttled when signed in.
func push_soon() -> void:
	if not Account.signed_in():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_push < PUSH_INTERVAL:
		_pending = true
		return
	_push()


func flush() -> void:
	if Account.signed_in():
		_push()


func _push() -> void:
	if _busy or not Account.signed_in():
		return
	_busy = true
	_pending = false
	_last_push = Time.get_ticks_msec() / 1000.0
	Online.post_json("/api/%s/save" % Online.GAME,
		{"token": Account.token, "save": snapshot()},
		func(_ok: bool, _code: int, _data: Dictionary):
			_busy = false
			if _pending:
				push_soon())


## Signing in pulls the account's save, merges it into local progress, then pushes
## the merged result back — so both devices converge on the best of each.
func _on_auth_changed() -> void:
	if not Account.signed_in():
		return
	Online.post_json("/api/%s/save?token=%s" % [Online.GAME, Account.token], {},
		func(ok: bool, _code: int, data: Dictionary):
			if ok and data.get("save") is Dictionary:
				apply_merge(data.save)
			_push())


func snapshot() -> Dictionary:
	return {
		"v": SAVE_VERSION,
		"coins": Store.coins,
		"best_score": Store.best_score,
		"campaign_index": Store.campaign_index,
		"goal_index": Store.goal_index,
		"games_played": Store.games_played,
		"words_total": Store.words_total,
		"bonus_total": Store.bonus_total,
		"supporter_level": Store.supporter_level,
		"streak_count": Store.streak_count,
		"streak_last": Store.streak_last,
		"masal_last_date": Store.masal_last_date,
		"masal_collected": Store.masal_collected.duplicate(),
		"achievements": Store.achievements.duplicate(),
		"themes_owned": Store.themes_owned.duplicate(),
		"frames_owned": Store.frames_owned.duplicate(),
		"inventory": Store.inventory.duplicate(),
		"daily_best": Store.daily_best.duplicate(),
		"daily_log": Store.daily_log.duplicate(),
	}


## Merge `remote` into the live Store using restore-safe semantics, then persist.
func apply_merge(remote: Dictionary) -> void:
	var m := merged(snapshot(), remote)
	Store.coins = int(m.coins)
	Store.best_score = int(m.best_score)
	Store.campaign_index = int(m.campaign_index)
	Store.goal_index = int(m.goal_index)
	Store.games_played = int(m.games_played)
	Store.words_total = int(m.words_total)
	Store.bonus_total = int(m.bonus_total)
	Store.supporter_level = int(m.supporter_level)
	Store.streak_count = int(m.streak_count)
	Store.streak_last = str(m.streak_last)
	Store.masal_last_date = str(m.masal_last_date)
	Store.masal_collected = m.masal_collected
	Store.achievements = m.achievements
	Store.themes_owned = m.themes_owned
	Store.frames_owned = m.frames_owned
	Store.inventory = m.inventory
	Store.daily_best = m.daily_best
	Store.daily_log = m.daily_log
	Store.save()


## Pure merge — unit-tested headlessly. Counters: max. Collections: union.
## Streak: whichever side played more recently keeps its pair.
static func merged(local: Dictionary, remote: Dictionary) -> Dictionary:
	var out := local.duplicate(true)
	for k in ["coins", "best_score", "campaign_index", "goal_index", "games_played",
			"words_total", "bonus_total", "supporter_level"]:
		out[k] = maxi(int(local.get(k, 0)), int(remote.get(k, 0)))
	for k in ["masal_collected", "achievements", "themes_owned", "frames_owned"]:
		var merged_list: Array = Array(local.get(k, [])).duplicate()
		for id in remote.get(k, []):
			if not id in merged_list:
				merged_list.append(id)
		out[k] = merged_list
	var inv: Dictionary = {}
	for src in [local.get("inventory", {}), remote.get("inventory", {})]:
		for k in src:
			inv[k] = maxi(int(inv.get(k, 0)), int(src[k]))
	out.inventory = inv
	var best: Dictionary = {}
	for src in [local.get("daily_best", {}), remote.get("daily_best", {})]:
		for k in src:
			best[k] = maxi(int(best.get(k, 0)), int(src[k]))
	out.daily_best = best
	# streak: the side with the LATER streak_last is the truth (ISO dates compare)
	if str(remote.get("streak_last", "")) > str(local.get("streak_last", "")):
		out.streak_last = remote.streak_last
		out.streak_count = int(remote.get("streak_count", 0))
	elif str(remote.get("streak_last", "")) == str(local.get("streak_last", "")):
		out.streak_count = maxi(int(local.get("streak_count", 0)),
			int(remote.get("streak_count", 0)))
	out.masal_last_date = str(maxi(int("0" + str(local.get("masal_last_date", ""))),
		int("0" + str(remote.get("masal_last_date", "")))))
	if out.masal_last_date == "0":
		out.masal_last_date = ""
	# daily ledger: union by date, local wins a conflict, newest last, capped
	var by_date := {}
	for e in remote.get("daily_log", []):
		if e is Dictionary and e.has("d"):
			by_date[e.d] = e
	for e in local.get("daily_log", []):
		if e is Dictionary and e.has("d"):
			by_date[e.d] = e
	var dates := by_date.keys()
	dates.sort()
	var log: Array = []
	for d in dates:
		log.append(by_date[d])
	if log.size() > 400:
		log = log.slice(log.size() - 400)
	out.daily_log = log
	return out
