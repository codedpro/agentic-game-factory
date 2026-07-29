class_name Puzzle
extends RefCounted
## Pure logic for one مثلستان level — no scene dependencies, fully unit-testable.
## A level is one proverb played over 1..4 rounds; each round has a letter wheel
## covering 1..4 of the proverb's target words. Bonus words come from the shared
## dictionary and pay coins.

const ZWNJ := "‌"
const PUNCT := "،؟!.:؛«»()"

enum { HIT_TARGET, HIT_BONUS, HIT_DUP, HIT_INVALID }

var level: Dictionary = {}          # {id, text, meaning, rounds:[{targets, wheel}]}
var round_idx := 0
var solved: Dictionary = {}         # target word -> true (across ALL rounds)
var bonus_found: Dictionary = {}    # bonus word -> true
var revealed: Dictionary = {}       # target word -> int (letters revealed by hints)
var hints_used := 0
var done := false
var wheel_order: Array = []         # display permutation of current round's wheel
var rng := RandomNumberGenerator.new()

var _dict: Dictionary = {}          # word -> true, shared dictionary
var _all_targets: Dictionary = {}   # word -> round index


func _init(level_data: Dictionary = {}, word_set: Dictionary = {}, seed_val: int = -1) -> void:
	_dict = word_set
	if not level_data.is_empty():
		start(level_data, seed_val)


func start(level_data: Dictionary, seed_val: int = -1) -> void:
	level = level_data
	round_idx = 0
	solved = {}
	bonus_found = {}
	revealed = {}
	hints_used = 0
	done = false
	_all_targets = {}
	for i in rounds().size():
		for t in rounds()[i].targets:
			_all_targets[t] = i
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	_deal_wheel()


func rounds() -> Array:
	return level.get("rounds", [])


func current_round() -> Dictionary:
	if round_idx >= rounds().size():
		return {}
	return rounds()[round_idx]


func wheel() -> Array:
	return wheel_order


func _deal_wheel() -> void:
	wheel_order = []
	var r := current_round()
	if r.is_empty():
		return
	wheel_order = (r.wheel as Array).duplicate()
	shuffle_wheel()


## Free action; deterministic under seed. Never produces the alphabetical order
## the wheel ships in (that order telegraphs the words).
func shuffle_wheel() -> void:
	var n := wheel_order.size()
	for i in range(n - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = wheel_order[i]
		wheel_order[i] = wheel_order[j]
		wheel_order[j] = tmp


## Can `word` be assembled from the current wheel (each tile used at most once)?
func composable(word: String) -> bool:
	var avail := {}
	for ch in wheel_order:
		avail[ch] = avail.get(ch, 0) + 1
	for ch in word:
		if avail.get(ch, 0) <= 0:
			return false
		avail[ch] -= 1
	return true


## Submit a word formed on the wheel. Returns
## {kind, word, round_done, level_done, coins} — coins only for bonus words.
func submit(word: String) -> Dictionary:
	var res := {"kind": HIT_INVALID, "word": word, "round_done": false,
		"level_done": false, "coins": 0}
	if done or word.length() < 2 or not composable(word):
		return res
	if _all_targets.has(word):
		if solved.has(word):
			res.kind = HIT_DUP
			return res
		solved[word] = true
		res.kind = HIT_TARGET
		_advance_rounds(res)
		return res
	if _dict.has(word):
		if bonus_found.has(word):
			res.kind = HIT_DUP
			return res
		bonus_found[word] = true
		res.kind = HIT_BONUS
		res.coins = bonus_coins(word)
		return res
	return res


static func bonus_coins(word: String) -> int:
	return word.length() * 25


func _advance_rounds(res: Dictionary) -> void:
	if not _round_complete(round_idx):
		return
	res.round_done = true
	while round_idx < rounds().size() and _round_complete(round_idx):
		round_idx += 1
	if round_idx >= rounds().size():
		done = true
		res.level_done = true
	else:
		_deal_wheel()


func _round_complete(i: int) -> bool:
	for t in rounds()[i].targets:
		if not solved.has(t):
			return false
	return true


## Reveal one more letter of the first unsolved target in the current round.
## Returns the target word being hinted, or "" when nothing can be hinted.
## Auto-solves the word when every letter has been revealed.
func hint() -> String:
	var r := current_round()
	if r.is_empty() or done:
		return ""
	for t in r.targets:
		if solved.has(t):
			continue
		hints_used += 1
		revealed[t] = int(revealed.get(t, 0)) + 1
		# With only one letter left hidden the word is readable — count it solved.
		if int(revealed[t]) >= t.length() - 1:
			revealed[t] = t.length()
			solved[t] = true
			_advance_rounds({"round_done": false, "level_done": false})
		return t
	return ""


func solved_count() -> int:
	return solved.size()


func total_targets() -> int:
	return _all_targets.size()


## Display model for the proverb line. Splits the ORIGINAL text on spaces (ZWNJ and
## punctuation stay inside their token); a token is blanked while any of its
## sub-words is an unsolved target. `reveal` carries hint-revealed letter counts.
func display_tokens() -> Array:
	var out: Array = []
	for tok in level.get("text", "").split(" "):
		var subs := _sub_words(tok)
		var target_subs: Array = []
		for s in subs:
			if _all_targets.has(s):
				target_subs.append(s)
		var all_solved := true
		for s in target_subs:
			if not solved.has(s):
				all_solved = false
		var reveal := {}
		for s in target_subs:
			if revealed.has(s) and not solved.has(s):
				reveal[s] = revealed[s]
		out.append({"tok": tok, "target": not target_subs.is_empty(),
			"solved": all_solved, "subs": target_subs, "reveal": reveal})
	return out


static func _sub_words(tok: String) -> Array:
	var clean := tok
	for p in PUNCT:
		clean = clean.replace(p, " ")
	clean = clean.replace(ZWNJ, " ")
	var out: Array = []
	for s in clean.split(" ", false):
		out.append(s)
	return out


## Everything needed to resume mid-level (daily runs must survive interruption).
## RNG state and wheel permutation are cosmetic and intentionally not saved.
func snapshot() -> Dictionary:
	return {"id": level.get("id", ""), "round": round_idx,
		"solved": solved.keys(), "bonus": bonus_found.keys(),
		"revealed": revealed.duplicate(), "hints": hints_used, "done": done}


func restore(d: Dictionary) -> void:
	round_idx = 0
	solved = {}
	bonus_found = {}
	for w in d.get("solved", []):
		solved[w] = true
	for w in d.get("bonus", []):
		bonus_found[w] = true
	revealed = {}
	var rev: Dictionary = d.get("revealed", {})
	for k in rev:
		revealed[k] = int(rev[k])
	hints_used = int(d.get("hints", 0))
	done = bool(d.get("done", false))
	while round_idx < rounds().size() and _round_complete(round_idx):
		round_idx += 1
	if round_idx >= rounds().size():
		done = true
	else:
		_deal_wheel()
