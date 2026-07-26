extends Node
## Autoload "Missions" — three date-seeded daily missions with coin rewards.

signal mission_done(mission: Dictionary)

const POOL := [
	{"id": "m_score", "targets": [1500, 2500, 4000], "reward": 60},   # score X in one game
	{"id": "m_merges", "targets": [30, 50, 80], "reward": 50},        # N merges today
	{"id": "m_stones", "targets": [3, 5, 8], "reward": 70},           # break N stones today
	{"id": "m_tile", "targets": [64, 128, 256], "reward": 60},        # make tile V
	{"id": "m_games", "targets": [2, 3, 5], "reward": 50},            # play N games
	{"id": "m_chain", "targets": [2, 3, 4], "reward": 70},            # chain of X
]

# state = {"date": "yyyymmdd", "list": [{id, target, progress, reward, done}]}
var state: Dictionary = {}


func ensure_today() -> void:
	var today := Time.get_date_string_from_system().replace("-", "")
	if state.get("date", "") == today:
		return
	# archive the day that just ended before replacing it, so the player can look back
	if state.has("date") and state.has("list"):
		_archive(state)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(today)
	var pool := POOL.duplicate()
	var list: Array = []
	for i in 3:
		var pick: Dictionary = pool.pop_at(rng.randi() % pool.size())
		var tier: int = rng.randi() % pick.targets.size()
		list.append({"id": pick.id, "target": pick.targets[tier],
			"progress": 0, "reward": pick.reward, "done": false})
	state = {"date": today, "list": list}
	Store.save_soon()


## Keep a rolling record of past days: date, how many were completed, and what they were.
func _archive(day: Dictionary) -> void:
	var date: String = str(day.get("date", ""))
	if date == "":
		return
	for e in Store.mission_history:
		if str(e.get("d", "")) == date:
			return                      # already archived
	var list: Array = day.get("list", [])
	var done := 0
	var items: Array = []
	for mn in list:
		if mn.get("done", false):
			done += 1
		items.append({"id": mn.get("id", ""), "target": mn.get("target", 0),
			"progress": mn.get("progress", 0), "done": mn.get("done", false)})
	Store.mission_history.append({"d": date, "done": done, "total": list.size(), "items": items})
	if Store.mission_history.size() > 60:
		Store.mission_history = Store.mission_history.slice(Store.mission_history.size() - 60)


## Past days, newest first.
func history() -> Array:
	var h: Array = Store.mission_history.duplicate()
	h.reverse()
	return h


## Which icon represents a mission type.
func icon_for(id: String) -> String:
	match id:
		"m_score": return "records"
		"m_merges": return "play"
		"m_stones": return "streak"
		"m_tile": return "coin"
		"m_games": return "daily"
		"m_chain": return "rank"
	return "tasks"


func list_today() -> Array:
	ensure_today()
	return state.list


## The mission day is captured once per run so a session crossing local midnight
## keeps its missions instead of re-rolling and discarding in-flight progress.
var run_key := ""


func begin_run() -> void:
	ensure_today()
	run_key = state.get("date", "")


## Report a gameplay event; returns missions completed by this event.
## kinds: score (value=score of finished game), merge (+n), stone (+n),
##        tile (value=merged tile), game (+1), chain (value=chain length)
func report(kind: String, value: int) -> void:
	if run_key == "" or state.get("date", "") != run_key:
		ensure_today()
		if run_key == "":
			run_key = state.get("date", "")
	for mn in state.list:
		if mn.done:
			continue
		var hit := false
		match [kind, mn.id]:
			["score", "m_score"]:
				mn.progress = maxi(mn.progress, value)
				hit = mn.progress >= mn.target
			["merge", "m_merges"]:
				mn.progress += value
				hit = mn.progress >= mn.target
			["stone", "m_stones"]:
				mn.progress += value
				hit = mn.progress >= mn.target
			["tile", "m_tile"]:
				mn.progress = maxi(mn.progress, value)
				hit = mn.progress >= mn.target
			["game", "m_games"]:
				mn.progress += value
				hit = mn.progress >= mn.target
			["chain", "m_chain"]:
				mn.progress = maxi(mn.progress, value)
				hit = mn.progress >= mn.target
		if hit:
			mn.done = true
			mn.progress = mn.target
			Store.add_coins(mn.reward)
			mission_done.emit(mn)
	Store.save_soon()


## Swap one of today's missions for a different one (costs a "reroll" consumable).
func reroll(index: int) -> bool:
	ensure_today()
	if index < 0 or index >= state.list.size() or state.list[index].done:
		return false
	if not Economy.use_item("reroll"):
		return false
	var used: Array = state.list.map(func(m): return m.id)
	var choices := POOL.filter(func(p): return not p.id in used)
	if choices.is_empty():
		choices = POOL
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick: Dictionary = choices[rng.randi() % choices.size()]
	var tier: int = rng.randi() % pick.targets.size()
	state.list[index] = {"id": pick.id, "target": pick.targets[tier],
		"progress": 0, "reward": pick.reward, "done": false}
	Store.save()
	return true


func desc(mn: Dictionary) -> String:
	var t: String = I18n.digits(mn.target)
	match mn.id:
		"m_score": return I18n.t("m_score") % t
		"m_merges": return I18n.t("m_merges") % t
		"m_stones": return I18n.t("m_stones") % t
		"m_tile": return I18n.t("m_tile") % t
		"m_games": return I18n.t("m_games") % t
		"m_chain": return I18n.t("m_chain") % t
	return mn.id
