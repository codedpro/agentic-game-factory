extends Node
## Autoload "Account" — email + password sign-in, required only to BUY.
##
## Rules this file exists to enforce:
##  * An account is NEVER needed to play, score, collect a fal or use earned coins.
##    Everything except a real-money purchase works signed out and offline.
##  * Validation is mirrored from the server (server/accounts.py) so a typo is caught
##    without a round trip — the server remains the authority.
##  * The password is used once, to get a session token, and is never stored. What we
##    persist is the token, which the player can revoke by signing out.
##  * Email addresses are NOT verified (a product decision). One consequence has to be
##    honoured in the UI rather than hidden: there is no password recovery, so the
##    sign-up screen says so before the player picks a password.

signal auth_changed
signal auth_result(ok: bool, reason: String)

const MIN_PASSWORD := 8
const MAX_PASSWORD := 128

var email := ""
var token := ""
var _busy := false


func _ready() -> void:
	email = Store.account_email
	token = Store.account_token


func signed_in() -> bool:
	return token != ""


## Mirrors accounts.EMAIL_RE on the server: one @, a dot in the domain, no spaces.
func email_is_valid(value: String) -> bool:
	var e := value.strip_edges()
	if e.length() < 3 or e.length() > 254 or e.contains(" "):
		return false
	var at := e.find("@")
	if at <= 0 or at != e.rfind("@") or at == e.length() - 1:
		return false
	var domain := e.substr(at + 1)
	var dot := domain.find(".")
	return dot > 0 and dot < domain.length() - 1 and not domain.begins_with(".")


## "" when the password is acceptable, else the same reason string the server returns.
func password_problem(value: String) -> String:
	if value.strip_edges() == "" or value.length() < MIN_PASSWORD:
		return "password_short"
	if value.length() > MAX_PASSWORD:
		return "password_long"
	return ""


func busy() -> bool:
	return _busy


func register(new_email: String, password: String) -> void:
	_submit("register", new_email, password)


func login(new_email: String, password: String) -> void:
	_submit("login", new_email, password)


func _submit(action: String, new_email: String, password: String) -> void:
	if _busy:
		return
	var e := new_email.strip_edges()
	if not email_is_valid(e):
		auth_result.emit(false, "invalid_email")
		return
	var problem := password_problem(password)
	if problem != "":
		auth_result.emit(false, problem)
		return
	_busy = true
	Online.post_json("/api/%s/%s" % [Online.GAME, action],
		{"email": e, "password": password, "device_id": Online.device_id},
		func(ok: bool, code: int, data: Dictionary):
			_busy = false
			if ok and String(data.get("token", "")) != "":
				token = String(data.token)
				email = String(data.get("email", e))
				Store.account_token = token
				Store.account_email = email
				Store.save()
				auth_changed.emit()
				auth_result.emit(true, "")
				Purchases.flush()      # a queued receipt may now be verifiable
				return
			auth_result.emit(false, _reason(code, data)))


## Map a status code to a reason the UI can localise. An unreachable server must read as
## "we could not reach the server", never as "your password is wrong".
func _reason(code: int, data: Dictionary) -> String:
	var given := String(data.get("error", ""))
	if given != "":
		return given
	match code:
		0, -1: return "offline"
		401: return "bad_credentials"
		409: return "email_taken"
		429: return "too_many_attempts"
		_: return "offline"


## Sign out locally and, best-effort, drop the session server-side too.
func sign_out() -> void:
	var old := token
	token = ""
	email = ""
	Store.account_token = ""
	Store.account_email = ""
	Store.save()
	auth_changed.emit()
	if old != "":
		Online.post_json("/api/%s/logout" % Online.GAME, {"token": old},
			func(_ok, _code, _data): pass)
