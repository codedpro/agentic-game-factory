extends Node
## Autoload "Share" — clipboard-first sharing (no permissions, no backend).
## Two share objects: a GIFT (your fal, how Iranians actually pass Hafez around)
## and a BRAG (daily-challenge result with a spoiler-free board grid).

## Shared text must never name a store other than the one this build ships to — a
## rival's name inside an APK is a rejection (LESSONS L69). Naming the player's OWN
## store is also better copy: whoever receives this already has that app installed.
func store_line() -> String:
	return I18n.t("share_store_line") % IAP.store_name()

# board value -> emoji tier for the shared grid (never rendered in-app, only copied)
const TIER := {0: "⬜", -1: "⬛", 2: "🟦", 4: "🟧", 8: "🟥", 16: "🟪", 32: "🟩", 64: "🟫"}


func fal_text(poem: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("🔮 فال حافظ من — " + Jalali.format_today())
	lines.append("")
	lines.append(poem.verse)
	lines.append("— " + poem.poet)
	lines.append("")
	lines.append("تعبیر: " + poem.interp)
	lines.append("")
	lines.append("فال امروزت را هم بگیر ✨ " + store_line())
	return "\n".join(lines)


func daily_text(grid: Array, score: int, streak: int) -> String:
	var lines := PackedStringArray()
	lines.append("🗓 چالش روزانه بریز و بساز — " + Jalali.format_today(false))
	lines.append("امتیاز من: " + I18n.digits(score))
	lines.append("")
	# top row first so the picture reads like the screen
	for r in range(Board.ROWS - 1, -1, -1):
		var row := ""
		for c in Board.COLS:
			var v: int = grid[c][r]
			row += TIER.get(v, "🟨") if v < 128 else "🟨"
		lines.append(row)
	lines.append("")
	if streak > 1:
		lines.append("🔥 " + I18n.digits(streak) + " روز پیاپی")
	lines.append("چیدمان امروز برای همه یکی است — تو چند می‌گیری؟")
	lines.append(store_line())
	return "\n".join(lines)


## Copy to clipboard, then offer the Android share sheet when available.
## Returns true if the text reached the clipboard (false on servers without one,
## e.g. headless CI — callers must not treat that as an error).
func share_text(text: String) -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		_try_android_share(text)
		return false
	DisplayServer.clipboard_set(text)
	_try_android_share(text)
	return DisplayServer.clipboard_get() == text


func _try_android_share(text: String) -> void:
	if OS.get_name() != "Android":
		return
	# Best-effort ACTION_SEND; clipboard already succeeded, so failure is harmless.
	if not Engine.has_singleton("JavaClassWrapper"):
		return
	var JCW = Engine.get_singleton("JavaClassWrapper")
	var Intent = JCW.wrap("android.content.Intent")
	if Intent == null:
		return
	var intent = Intent.new()
	intent.setAction(Intent.ACTION_SEND)
	intent.setType("text/plain")
	intent.putExtra(Intent.EXTRA_TEXT, text)
	var activity = Engine.get_singleton("AndroidRuntime") if Engine.has_singleton("AndroidRuntime") else null
	if activity:
		activity.startActivity(Intent.createChooser(intent, "ارسال"))
