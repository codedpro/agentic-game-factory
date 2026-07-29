extends Node
## Autoload "Masal" — the USP: the verified proverb pool, the shared daily draw,
## the bonus-word dictionary and the گنجینه treasury.

var levels: Array = []           # ordered by difficulty (campaign order)
var by_id: Dictionary = {}
var word_set: Dictionary = {}    # word -> true (bonus dictionary)


func _ready() -> void:
	var f := FileAccess.open("res://assets/masal/masal.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary and parsed.get("levels") is Array:
			levels = parsed.levels
			for l in levels:
				by_id[l.id] = l
	var w := FileAccess.open("res://assets/masal/words_fa.json", FileAccess.READ)
	if w:
		var parsed = JSON.parse_string(w.get_as_text())
		if parsed is Dictionary and parsed.get("words") is Array:
			for word in parsed.words:
				word_set[word] = true


func campaign_level(index: int) -> Dictionary:
	if levels.is_empty():
		return {}
	return levels[clampi(index, 0, levels.size() - 1)]


func campaign_size() -> int:
	return levels.size()


## Deterministic proverb of the day — the same for every player (shared ritual).
## Walks a fixed shuffled permutation of the pool with a stride coprime to the pool
## size, so ANY n consecutive days hit every proverb exactly once (LESSONS L27).
func daily_id(date_key: String) -> String:
	return _walk(_day_number(date_key))


## The walk itself, by absolute day number — exposed for the sliding-window test.
func _walk(day: int) -> String:
	if levels.is_empty():
		return ""
	var ids: Array = by_id.keys()
	ids.sort()   # stable order before shuffling, so every device agrees
	var n := ids.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("masalestan-daily")
	for i in range(n - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var stride := _coprime_stride(n)
	return ids[posmod(day * stride, n)]


func daily_level(date_key: String) -> Dictionary:
	var id := daily_id(date_key)
	return by_id.get(id, {})


## Seed for the daily puzzle's wheel shuffle — date-derived so every player sees
## the identical arrangement (part of the "same puzzle for everyone" promise).
func daily_seed(date_key: String) -> int:
	return hash("masalestan-wheel-" + date_key)


static func _coprime_stride(n: int) -> int:
	if n <= 2:
		return 1
	for k in range(int(n / 2.0), n):
		if _gcd(k, n) == 1:
			return k
	return 1


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


func _day_number(date_key: String) -> int:
	if date_key.length() != 8:
		return 0
	return Jalali.day_number({"year": int(date_key.substr(0, 4)),
		"month": int(date_key.substr(4, 2)), "day": int(date_key.substr(6, 2))})


## Grant today's proverb into the treasury after finishing the daily challenge.
## Returns the level dict, or {} when today's was already granted.
func grant_daily(date_key: String) -> Dictionary:
	if Store.masal_last_date == date_key:
		return {}
	var id := daily_id(date_key)
	if id == "":
		return {}
	Store.masal_last_date = date_key
	Store.collect_masal(id)
	Store.save()
	return by_id[id]


## Record a finished daily in the ledger (one entry per day).
func log_daily(id: String, hints: int, words: int) -> void:
	var date := Time.get_date_string_from_system()
	for e in Store.daily_log:
		if e.get("d", "") == date:
			return
	Store.daily_log.append({"id": id, "d": date, "hints": hints, "words": words})
	if Store.daily_log.size() > 400:
		Store.daily_log = Store.daily_log.slice(Store.daily_log.size() - 400)
	Store.save()


func logged_today() -> bool:
	var today := Time.get_date_string_from_system()
	for e in Store.daily_log:
		if e.get("d", "") == today:
			return true
	return false


## Grant the next uncollected proverb for a reached goal milestone. Returns {} when
## the whole treasury is collected.
func grant_milestone() -> Dictionary:
	for l in levels:
		if not l.id in Store.masal_collected:
			Store.collect_masal(l.id)
			return l
	return {}


func collected_count() -> int:
	return Store.masal_collected.size()
