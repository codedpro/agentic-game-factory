extends SceneTree
## End-to-end check against the local scoreboard.
func _init():
	var f = FileAccess.open("user://server.txt", FileAccess.WRITE)
	f.store_string("http://127.0.0.1:3000"); f.close()
	await process_frame
	var Online = root.get_node("Online")
	Online.base_url = "http://127.0.0.1:3000"
	print("device_id len=", Online.device_id.length())
	Online.claim_nickname("بازیکن_تست")
	var res = await Online.nickname_result
	print("claim ok=", res)
	Online.submit(7777, "endless")
	await create_timer(2.0).timeout
	print("pending after submit=", root.get_node("Store").pending_scores, " rank=", Online.last_rank)
	Online.fetch_board("endless")
	var b = await Online.board_result
	print("board ok=", b[0], " entries=", b[1].get("top", []).size(), " you=", b[1].get("you"))
	quit(0)
