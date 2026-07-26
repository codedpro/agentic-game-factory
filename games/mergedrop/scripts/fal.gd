extends Node
## Autoload "Fal" — the USP: daily Hafez fortune + Persian poetry treasury.

var poems: Array = []          # loaded from res://assets/fal/fal.json
var by_id: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open("res://assets/fal/fal.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Array:
			poems = parsed
			for p in poems:
				by_id[p.id] = p


func hafez_ids() -> Array:
	return poems.filter(func(p): return p.poet == "حافظ").map(func(p): return p.id)


## Deterministic fal of the day — same for every player (shared ritual).
## Walks a shuffled permutation of the pool so no verse repeats until every one has
## been seen; independent per-day draws collided within a week (research finding).
func daily_id(date_key: String) -> String:
	var ids := hafez_ids()
	if ids.is_empty():
		return ""
	ids.sort()   # stable order before shuffling, so every device agrees
	var n := ids.size()
	var day := _day_number(date_key)
	# Fixed shuffle of the pool (same on every device)...
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("beriz-o-besaz-fal")
	for i in range(n - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	# ...walked by a stride coprime with the pool size. Because gcd(stride, n) == 1,
	# ANY n consecutive days hit every verse exactly once — a per-cycle reshuffle
	# instead repeated verses across the cycle boundary (caught by tests).
	var stride := _coprime_stride(n)
	return ids[posmod(day * stride, n)]


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


## Grant today's fal after finishing the daily challenge. Returns poem or {}.
func grant_daily(date_key: String) -> Dictionary:
	if Store.fal_last_date == date_key:
		return {}
	var id := daily_id(date_key)
	if id == "":
		return {}
	Store.fal_last_date = date_key
	Store.collect_fal(id)
	Store.save()
	return by_id[id]


## Record a revealed fal in the ledger with the intention the player held.
func log_fal(id: String, topic := "topic_none") -> void:
	var date := Time.get_date_string_from_system()
	for e in Store.fal_log:
		if e.get("d", "") == date:
			return                      # one ledger entry per day
	Store.fal_log.append({"id": id, "d": date, "t": topic})
	if Store.fal_log.size() > 400:
		Store.fal_log = Store.fal_log.slice(Store.fal_log.size() - 400)
	Store.save()


## Earlier ledger entries for a verse, excluding today — powers "this verse returned".
func previous_dates(id: String) -> Array:
	var today := Time.get_date_string_from_system()
	var out: Array = []
	for e in Store.fal_log:
		if e.get("id", "") == id and e.get("d", "") != today:
			out.append(e.d)
	return out


func logged_today() -> bool:
	var today := Time.get_date_string_from_system()
	for e in Store.fal_log:
		if e.get("d", "") == today:
			return true
	return false


## Grant the next uncollected poem for a reached goal milestone. Returns poem or {}.
func grant_milestone() -> Dictionary:
	for p in poems:
		if not p.id in Store.fal_collected:
			Store.collect_fal(p.id)
			return p
	return {}


func collected_count() -> int:
	return Store.fal_collected.size()
