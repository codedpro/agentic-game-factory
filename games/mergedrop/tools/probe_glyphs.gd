extends SceneTree
func _init():
	var reg: FontFile = load("res://assets/fonts/Vazirmatn-Regular.ttf")
	var emo: FontFile = load("res://assets/fonts/NotoEmoji-Regular.ttf")
	var cands := "۞٭◆◇■□●▪▨▩✦✧❁❋⁂←↩↪⟲↶⎌⏪✖✗✘×⊗⌫⏱⏳★☆✔✓⚑⌂"
	var ok := ""
	for i in cands.length():
		var ch := cands[i]
		var c := ch.unicode_at(0)
		if reg.has_char(c) or emo.has_char(c):
			ok += ch + " "
	print("HAVE: ", ok)
	quit(0)
