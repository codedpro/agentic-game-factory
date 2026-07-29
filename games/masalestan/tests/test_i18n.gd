extends GutTest
## Localization completeness and digit conversion.


func test_all_keys_have_both_locales():
	for key in I18n.T:
		assert_true(I18n.T[key].has("en"), "missing en: " + key)
		assert_true(I18n.T[key].has("fa"), "missing fa: " + key)
		assert_true(I18n.T[key]["en"].length() > 0)
		assert_true(I18n.T[key]["fa"].length() > 0)


func test_digits_en():
	I18n.locale = "en"
	assert_eq(I18n.digits(2048), "2048")


func test_digits_fa():
	I18n.locale = "fa"
	assert_eq(I18n.digits(2048), "۲۰۴۸")
	assert_eq(I18n.digits(0), "۰")
	I18n.locale = "en"


func test_toggle():
	I18n.locale = "en"
	I18n.toggle()
	assert_eq(I18n.locale, "fa")
	I18n.toggle()
	assert_eq(I18n.locale, "en")


func test_t_returns_localized():
	I18n.locale = "en"
	assert_eq(I18n.t("play"), "Journey")
	I18n.locale = "fa"
	assert_eq(I18n.t("play"), "سفرِ مثل‌ها")
	I18n.locale = "en"
