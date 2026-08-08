extends Node
## Autoload "Share" — clipboard-first sharing (no permissions, no backend).
## Two share objects: a GIFT (today's proverb with its meaning — something you pass
## to someone) and a BRAG (daily-challenge result as a spoiler-free square grid).

## No store is named here: a shared message travels far beyond the store it came from,
## and «از بازار یا مایکت بگیر» ships a rival's name in both builds (L69).
const STORE_LINE := "بازی «مثلستان» را جست‌وجو کن و رایگان نصب کن"


func masal_text(level: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("📜 مثلِ امروز — " + Jalali.format_today())
	lines.append("")
	lines.append("«" + str(level.get("text", "")) + "»")
	lines.append("")
	lines.append("یعنی: " + str(level.get("meaning", "")))
	lines.append("")
	lines.append("مثلِ امروزت را هم باز کن ✨ " + STORE_LINE)
	return "\n".join(lines)


## Spoiler-free result grid: one square per target word in solve order —
## 🟩 solved clean, 🟨 needed a hint. The proverb itself must never appear here
## (the recipient still has to play for it).
func daily_text(clean_flags: Array, bonus_words: int, streak: int) -> String:
	var lines := PackedStringArray()
	lines.append("🗓 مثلِ امروزِ مثلستان — " + Jalali.format_today(false))
	var row := ""
	for clean in clean_flags:
		row += "🟩" if clean else "🟨"
	lines.append(row)
	if bonus_words > 0:
		lines.append("💎 " + I18n.digits(bonus_words) + " واژهٔ پنهان")
	if streak > 1:
		lines.append("🔥 " + I18n.digits(streak) + " روز پیاپی")
	lines.append("")
	lines.append("مثل امروز برای همه یکی است — تو حدسش می‌زنی؟")
	lines.append(STORE_LINE)
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
