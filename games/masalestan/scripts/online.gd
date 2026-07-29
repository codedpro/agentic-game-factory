extends Node
## Autoload "Online" — global scoreboard sync.
##
## The game is offline-first and MUST stay fully playable with no network and no server:
## every call here is best-effort, every failure is silent, and nothing ever blocks play.
## Scores earned offline are queued and flushed on the next successful contact.

signal nickname_result(ok: bool, message: String)
signal board_result(ok: bool, data: Dictionary)
signal sync_state_changed

const GAME := "masalestan"
## Point a subdomain at the scoreboard (port 3000). Override at runtime via
## `user://server.txt` so a build never has to be rebuilt to move servers.
const DEFAULT_BASE := "https://mergedrop.1xai.ir"   # one server serves every game, per-game routes
const OVERRIDE_FILE := "user://server.txt"
const TIMEOUT := 8.0

var base_url := DEFAULT_BASE
var device_id := ""
var nickname := ""
var last_rank := 0
enum Net { UNKNOWN, ONLINE, OFFLINE }
var state: int = Net.UNKNOWN   # nothing has been attempted yet — not the same as offline
var online := false            # last contact succeeded
var _busy := false


func _ready() -> void:
	var f := FileAccess.open(OVERRIDE_FILE, FileAccess.READ)
	if f:
		var u := f.get_as_text().strip_edges()
		if u != "":
			base_url = u
	device_id = Store.device_id
	if device_id == "":
		device_id = _new_device_id()
		Store.device_id = device_id
		Store.save()
	nickname = Store.nickname
	# Establish connectivity early so the UI never shows a guess, and drain anything
	# earned offline. Both are best-effort and never block play.
	ping.call_deferred()
	flush.call_deferred()


## Cheap connectivity probe against the server's health endpoint.
func ping() -> void:
	_request(HTTPClient.METHOD_GET, "/healthz", {}, func(_ok, _code, _data): pass)


func _new_device_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var out := ""
	for i in 24:
		out += chars[rng.randi() % chars.length()]
	return out


func has_nickname() -> bool:
	return nickname.strip_edges() != ""


## Nickname rules mirror the server so the player gets instant feedback offline.
func nickname_is_valid(n: String) -> bool:
	var t := n.strip_edges()
	return t.length() >= 2 and t.length() <= 18 and not t.contains("\n")


func _request(method: int, path: String, body: Dictionary, cb: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	http.request_completed.connect(func(result, code, _headers, data):
		var ok: bool = result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
		var parsed = {}
		if data.size() > 0:
			var j = JSON.parse_string(data.get_string_from_utf8())
			if j is Dictionary:
				parsed = j
		var was := state
		online = result == HTTPRequest.RESULT_SUCCESS
		state = Net.ONLINE if online else Net.OFFLINE
		if was != state:
			sync_state_changed.emit()
		cb.call(ok, code, parsed)
		http.queue_free())
	var url := base_url + path
	var err: int
	if method == HTTPClient.METHOD_POST:
		err = http.request(url, ["Content-Type: application/json"], method, JSON.stringify(body))
	else:
		err = http.request(url, [], method)
	if err != OK:
		online = false
		state = Net.OFFLINE
		sync_state_changed.emit()
		cb.call(false, 0, {})
		http.queue_free()


## Reusable JSON POST for the account and purchase modules. Same offline semantics as
## every other call here: the callback always fires, failure is never fatal.
func post_json(path: String, body: Dictionary, cb: Callable) -> void:
	_request(HTTPClient.METHOD_POST, path, body, cb)


## Claim a unique nickname. Emits nickname_result; the game continues either way.
func claim_nickname(n: String) -> void:
	var t := n.strip_edges()
	if not nickname_is_valid(t):
		nickname_result.emit(false, "invalid")
		return
	_request(HTTPClient.METHOD_POST, "/api/%s/nickname" % GAME,
		{"device_id": device_id, "nickname": t},
		func(ok: bool, code: int, data: Dictionary):
			if ok:
				nickname = str(data.get("nickname", t))
				Store.nickname = nickname
				Store.save()
				nickname_result.emit(true, "")
				flush()
			elif code == 409:
				nickname_result.emit(false, "taken")
			else:
				nickname_result.emit(false, "offline"))


## Record a score for later upload; uploads immediately if possible.
func submit(score: int, mode := "rush") -> void:
	if score <= 0:
		return
	var pending: Dictionary = Store.pending_scores
	if int(pending.get(mode, 0)) < score:
		pending[mode] = score
		Store.pending_scores = pending
		Store.save()
	flush()


## Push every queued best score. Silent no-op when offline or without a nickname.
func flush() -> void:
	if _busy or not has_nickname() or Store.pending_scores.is_empty():
		return
	_busy = true
	var modes: Array = Store.pending_scores.keys()
	var mode: String = str(modes[0])
	var score: int = int(Store.pending_scores[mode])
	_request(HTTPClient.METHOD_POST, "/api/%s/score" % GAME,
		{"device_id": device_id, "score": score, "mode": mode},
		func(ok: bool, _code: int, data: Dictionary):
			_busy = false
			if not ok:
				return                      # keep it queued for next time
			last_rank = int(data.get("rank", 0))
			var p: Dictionary = Store.pending_scores
			p.erase(mode)
			Store.pending_scores = p
			Store.save()
			sync_state_changed.emit()
			if not p.is_empty():
				flush())


func fetch_board(mode := "rush", limit := 50) -> void:
	_request(HTTPClient.METHOD_GET,
		"/api/%s/board?mode=%s&limit=%d&device_id=%s" % [GAME, mode, limit, device_id], {},
		func(ok: bool, _code: int, data: Dictionary):
			if ok and data.has("you") and data.you is Dictionary:
				last_rank = int(data.you.get("rank", last_rank))
			board_result.emit(ok, data))
