extends SceneTree
## The game must be completely unharmed when the scoreboard is unreachable.
func _init():
	await process_frame
	var Online = root.get_node("Online")
	var Store = root.get_node("Store")
	Online.base_url = "http://127.0.0.1:59999"   # nothing listening
	Store.pending_scores = {}
	Store.nickname = "offline_player"
	Online.nickname = "offline_player"
	Online.submit(4242, "endless")
	await create_timer(3.0).timeout
	print("OFFLINE pending kept =", Store.pending_scores)
	print("OFFLINE online flag =", Online.online)
	Online.fetch_board("endless")
	var b = await Online.board_result
	print("OFFLINE board ok =", b[0], " (must be false, no crash)")
	Online.claim_nickname("someone")
	var n = await Online.nickname_result
	print("OFFLINE claim =", n)
	print("OFFLINE_OK")
	quit(0)
