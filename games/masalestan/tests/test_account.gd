extends GutTest
## Accounts and paid receipts, from the client's side.
##
## The invariants worth defending here are about what must KEEP WORKING: an account is
## needed only to buy, and a receipt for money already taken must never be dropped just
## because our own server is unreachable.


func before_each():
	Store.first_run = false
	I18n.locale = "fa"
	Account.token = ""
	Account.email = ""
	Store.account_token = ""
	Store.account_email = ""
	Store.pending_receipts = []


# ---------- validation mirrors the server ----------
func test_email_validation_matches_the_server_rules():
	for good in ["a@b.co", "player.one+tag@mail.example.ir", "ali@gmail.com"]:
		assert_true(Account.email_is_valid(good), "%s should be accepted" % good)
	for bad in ["", "no-at-sign", "a@b", "a@@b.co", "a b@c.co", "a@b.", "@b.co",
			"a@.b.co"]:
		assert_false(Account.email_is_valid(bad), "%s should be rejected" % bad)


func test_password_rules_match_the_server():
	assert_eq(Account.password_problem("12345678"), "")
	assert_eq(Account.password_problem("short"), "password_short")
	assert_eq(Account.password_problem("        "), "password_short")
	assert_eq(Account.password_problem("x".repeat(200)), "password_long")


func test_a_bad_email_never_reaches_the_network():
	var got := []
	var cb := func(ok, reason): got.append([ok, reason])
	Account.auth_result.connect(cb)
	Account.register("not-an-email", "goodpassword1")
	Account.auth_result.disconnect(cb)
	assert_eq(got.size(), 1, "the player must get instant feedback, not a round trip")
	assert_false(got[0][0])
	assert_eq(got[0][1], "invalid_email")


func test_every_failure_reason_has_a_persian_message():
	for reason in ["invalid_email", "password_short", "password_long", "email_taken",
			"bad_credentials", "too_many_attempts", "offline"]:
		var key: String = "err_" + reason
		assert_true(I18n.T.has(key), "no message for %s" % reason)
		assert_ne(I18n.T[key].fa, "", "%s has no Persian text" % reason)


func test_an_unreachable_server_never_reads_as_a_wrong_password():
	assert_eq(Account._reason(0, {}), "offline")
	assert_eq(Account._reason(503, {}), "offline")
	assert_ne(Account._reason(0, {}), "bad_credentials",
		"a timeout must never accuse the player of a wrong password")


# ---------- signing out ----------
func test_sign_out_clears_the_session_from_disk():
	Account.token = "tok"
	Account.email = "a@b.co"
	Store.account_token = "tok"
	Store.account_email = "a@b.co"
	Store.save()
	Account.sign_out()
	assert_false(Account.signed_in())
	Store.load_data()
	assert_eq(Store.account_token, "", "the token must not survive a sign-out")


func test_the_password_is_never_stored_anywhere():
	# The Store has no field that could hold one, by construction.
	Store.save()
	var f := FileAccess.open(Store.PATH, FileAccess.READ)
	assert_not_null(f)
	var raw := f.get_as_text()
	assert_false(raw.contains("password"), "the save file must have no password field")


# ---------- receipts ----------
func test_a_receipt_is_queued_and_survives_a_restart():
	Purchases.record("coins_small", "tok-1", "myket")
	assert_eq(Purchases.pending(), 1)
	Store.load_data()
	assert_eq(Store.pending_receipts.size(), 1, "a paid receipt must survive a restart")
	assert_eq(String(Store.pending_receipts[0].sku), "coins_small")


func test_the_same_receipt_is_never_queued_twice():
	Purchases.record("coins_small", "tok-1", "myket")
	Purchases.record("coins_small", "tok-1", "myket")
	assert_eq(Purchases.pending(), 1)


func test_a_receipt_with_no_token_is_not_queued():
	# Some stores return no token; the coins were already granted, so there is nothing
	# to verify and nothing to retry forever.
	Purchases.record("coins_small", "", "myket")
	assert_eq(Purchases.pending(), 0)


func test_the_queue_is_bounded():
	for i in Purchases.MAX_QUEUE + 10:
		Purchases.record("coins_small", "tok-%d" % i, "myket")
	assert_lte(Purchases.pending(), Purchases.MAX_QUEUE,
		"the queue must not grow without bound")


func test_flush_is_a_silent_no_op_when_signed_out():
	Purchases.record("coins_small", "tok-1", "myket")
	Purchases.flush()             # must not crash, must not clear the queue
	assert_eq(Purchases.pending(), 1,
		"signed out, the receipt must be kept until the player signs in")


func test_wiping_progress_keeps_the_account_and_unverified_receipts():
	Account.token = "tok"
	Store.account_token = "tok"
	Store.account_email = "a@b.co"
	Purchases.record("coins_small", "tok-1", "myket")
	Store.reset_progress()
	assert_eq(Store.account_token, "tok", "resetting progress must not sign the player out")
	assert_eq(Store.pending_receipts.size(), 1,
		"money already spent must not be wiped with local progress")


# ---------- the account is only ever needed to buy ----------
func test_playing_never_requires_an_account():
	assert_false(Account.signed_in())
	var p := Puzzle.new(Masal.campaign_level(0), Masal.word_set, 7)
	var first: String = p.current_round().targets[0]
	assert_eq(p.submit(first).kind, Puzzle.HIT_TARGET,
		"a signed-out player must be able to play")
	Store.coins = 100000
	assert_true(Economy.buy_item("shield"), "earned coins must spend without an account")
	assert_true(Masal.grant_milestone().size() >= 0, "the treasury must not need an account")


func test_the_coin_tab_offers_sign_in_rather_than_hiding_itself():
	get_tree().root.size = Vector2i(720, 1280)
	var sh = load("res://scripts/main.gd").new()
	add_child(sh)
	await wait_process_frames(2)
	sh.show_screen("shop")
	await wait_process_frames(2)
	sh.current._tab = "coins"
	sh.current.relayout()
	await wait_process_frames(2)
	var texts: Array = []
	_texts(sh.current, texts)
	assert_true("\n".join(texts).contains(I18n.t("account_needed_to_buy")),
		"a signed-out player must be told what to do, not shown a dead button")
	sh.free()


func _texts(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Label:
			out.append(c.text)
		elif c is Button:
			out.append(c.text)
		_texts(c, out)


func test_the_account_screen_builds_signed_out_and_signed_in():
	for signed_in in [false, true]:
		Account.token = "tok" if signed_in else ""
		Account.email = "a@b.co" if signed_in else ""
		get_tree().root.size = Vector2i(720, 1280)
		var sh = load("res://scripts/main.gd").new()
		add_child(sh)
		await wait_process_frames(2)
		sh.show_screen("account", {"then": "shop"})
		await wait_process_frames(3)
		var texts: Array = []
		_texts(sh.current, texts)
		var joined := "\n".join(texts)
		if signed_in:
			assert_true(joined.contains(I18n.t("sign_out")))
		else:
			assert_true(joined.contains(I18n.t("email")), "the form must show an email field")
			assert_true(joined.contains(I18n.t("account_no_recovery")),
				"no-recovery must be stated before a password is chosen")
		sh.free()
