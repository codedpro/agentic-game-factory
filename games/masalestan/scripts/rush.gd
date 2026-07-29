class_name Rush
extends RefCounted
## Pure logic for «مسابقه» — the timed pressure mode (the difficulty engine).
## Wraps a sequence of Puzzle levels under a shrinking time economy: every solved
## target refunds seconds, but the refund decays as proverbs are completed, so every
## run eventually starves and ends. No hints here — consumables are a solo-mode mercy.

const START_SECONDS := 90.0
const MAX_BANK := 120.0
const WORD_BONUS_BASE := 6.0
const WORD_BONUS_MIN := 1.5
const WORD_BONUS_DECAY := 0.45    # seconds lost per completed proverb
const PROVERB_BONUS_BASE := 8.0
const PROVERB_BONUS_DECAY := 0.8  # a flat completion bonus would fund steady play forever
const CHAIN_WINDOW := 8.0         # seconds between solves that keep the chain alive
const CHAIN_MAX := 5

var puzzle: Puzzle = null
var time_left := START_SECONDS
var score := 0
var completed := 0                # proverbs finished
var words_solved := 0
var chain := 1
var game_over := false
var rng := RandomNumberGenerator.new()

var _levels: Array = []
var _word_set: Dictionary = {}
var _order: Array = []
var _next := 0
var _since_solve := 1e9   # "long ago": the first solve must start the chain at 1


func _init(levels: Array = [], word_set: Dictionary = {}, seed_val: int = -1) -> void:
	_levels = levels
	_word_set = word_set
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	_order = range(_levels.size())
	for i in range(_order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = _order[i]
		_order[i] = _order[j]
		_order[j] = tmp
	if not _levels.is_empty():
		_load_next()


func _load_next() -> void:
	var idx: int = _order[_next % _order.size()]
	_next += 1
	puzzle = Puzzle.new(_levels[idx], _word_set, rng.randi())


## Seconds refunded per solved target word — decays with progress. This is the
## difficulty engine: past ~10 proverbs the refund is close to the floor and only
## flawless fast play survives.
func word_bonus() -> float:
	return maxf(WORD_BONUS_MIN, WORD_BONUS_BASE - WORD_BONUS_DECAY * completed)


## Completion refund decays to ZERO: with any flat completion bonus, a steady
## competent pace never starves and the run never ends (caught by test).
func proverb_bonus() -> float:
	return maxf(0.0, PROVERB_BONUS_BASE - PROVERB_BONUS_DECAY * completed)


## UI drives time through here (also lets tests simulate any pace deterministically).
func advance(dt: float) -> void:
	if game_over:
		return
	time_left -= dt
	_since_solve += dt
	if time_left <= 0.0:
		time_left = 0.0
		game_over = true


func submit(word: String) -> Dictionary:
	var out := {"kind": Puzzle.HIT_INVALID, "score_gain": 0, "time_gain": 0.0,
		"chain": chain, "level_done": false, "coins": 0}
	if game_over or puzzle == null:
		return out
	var res := puzzle.submit(word)
	out.kind = res.kind
	if res.kind == Puzzle.HIT_TARGET:
		if _since_solve <= CHAIN_WINDOW:
			chain = mini(chain + 1, CHAIN_MAX)
		else:
			chain = 1
		_since_solve = 0.0
		words_solved += 1
		var gain := word.length() * 20 * chain
		score += gain
		out.score_gain = gain
		out.time_gain = word_bonus()
		out.chain = chain
		if res.level_done:
			out.time_gain += proverb_bonus()
			completed += 1
			out.level_done = true
			score += 100 * chain
			out.score_gain += 100 * chain
			_load_next()
		time_left = minf(time_left + out.time_gain, MAX_BANK)
	elif res.kind == Puzzle.HIT_BONUS:
		out.coins = res.coins
		score += word.length() * 5
		out.score_gain = word.length() * 5
	return out
