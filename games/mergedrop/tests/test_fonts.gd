extends GutTest
## Guards against tofu boxes: every character the UI can display must have a glyph
## in Vazirmatn or its emoji fallback.

const UI_GLYPHS := "🔮🗓🏆⚙🎨🪙🔥✅🔒۞✨📜▶↩⏪✖🎯▫❗🗑🔊🔇×"


func _fonts() -> Array:
	return [UI.font_reg, UI.font_bold]


func test_fallback_font_installed():
	assert_gt(UI.font_reg.fallbacks.size(), 0, "emoji fallback missing on regular font")
	assert_gt(UI.font_bold.fallbacks.size(), 0, "emoji fallback missing on bold font")


func _has_glyph(f: FontFile, ch: String) -> bool:
	if f.has_char(ch.unicode_at(0)):
		return true
	for fb in f.fallbacks:
		if fb and fb.has_char(ch.unicode_at(0)):
			return true
	return false


func test_ui_symbols_have_glyphs():
	for f in _fonts():
		for i in UI_GLYPHS.length():
			var ch := UI_GLYPHS[i]
			assert_true(_has_glyph(f, ch), "no glyph for '%s' (U+%X)" % [ch, ch.unicode_at(0)])


func test_all_localized_strings_have_glyphs():
	for f in _fonts():
		for key in I18n.T:
			for loc in ["fa", "en"]:
				var s: String = I18n.T[key][loc]
				for i in s.length():
					var ch := s[i]
					if ch == "\n" or ch == " ":
						continue
					assert_true(_has_glyph(f, ch),
						"no glyph for '%s' (U+%X) in %s/%s" % [ch, ch.unicode_at(0), key, loc])


func test_persian_digits_have_glyphs():
	for f in _fonts():
		for d in I18n.FA_DIGITS:
			assert_true(_has_glyph(f, d), "missing Persian digit glyph " + d)


func test_poem_text_has_glyphs():
	for p in Fal.poems:
		var s: String = p.verse + p.interp + p.poet
		for i in s.length():
			var ch := s[i]
			if ch == "\n" or ch == " ":
				continue
			assert_true(_has_glyph(UI.font_bold, ch),
				"poem %s has unrenderable char '%s' (U+%X)" % [p.id, ch, ch.unicode_at(0)])
