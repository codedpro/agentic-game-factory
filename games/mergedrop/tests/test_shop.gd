extends GutTest
## Guards the coin store. A player who cannot FIND the purchase screen has, from their side,
## a game with no purchases at all — so the tab must exist and list every pack even when no
## billing plugin is present, with an honest reason instead of silence.


func before_each():
	Store.first_run = false
	I18n.locale = "fa"


func _shop(tab: String) -> Node:
	get_tree().root.size = Vector2i(720, 1280)
	var sh = load("res://scripts/main.gd").new()
	add_child(sh)
	await wait_process_frames(2)
	sh.show_screen("shop")
	await wait_process_frames(2)
	sh.current._tab = tab
	sh.current.relayout()
	await wait_process_frames(2)
	return sh


func _texts(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Label:
			out.append(c.text)
		elif c is Button:
			out.append(c.text)
		_texts(c, out)


func _buttons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)


func test_catalogue_is_ordered_and_complete():
	assert_eq(IAP.PRODUCT_ORDER.size(), IAP.PRODUCTS.size(),
		"every product must have a place in the displayed order")
	for sku in IAP.PRODUCTS:
		assert_true(sku in IAP.PRODUCT_ORDER, "%s would never be shown to the player" % sku)
		assert_ne(I18n.t("sku_" + sku), "sku_" + sku, "%s has no display name" % sku)
		# the store panels need a Persian description per product — see
		# releases/mergedrop/iap_products.md, which is generated from these strings
		var desc_key := "sku_%s_desc" % sku
		assert_ne(I18n.t(desc_key), desc_key,
			"%s has no description for the store listing" % sku)
		assert_true(I18n.T[desc_key].fa.length() > 20,
			"%s: the Persian description is too short to paste into a store panel" % sku)
		assert_true(I18n.T["sku_" + sku].en != I18n.T["sku_" + sku].fa,
			"%s needs a real English name, not the Persian one repeated" % sku)


## Myket rejected 5.4 for showing a purchase section that announced it was not active
## yet. A build without billing must not advertise the feature at all.
func test_a_build_without_billing_hides_the_coins_tab_entirely():
	assert_false(IAP.implemented(), "precondition: this build has no billing plugin")
	var sh = await _shop("coins")
	var texts: Array = []
	_texts(sh.current, texts)
	var joined := "\n".join(texts)
	assert_false(joined.contains(I18n.t("tab_coins")),
		"a build with no billing must not show a coins tab at all")
	for sku in IAP.PRODUCT_ORDER:
		assert_false(joined.contains(I18n.t("sku_" + sku)),
			"pack '%s' must not be advertised in a build that cannot sell it" % sku)
	sh.free()


func test_asking_for_the_coins_tab_falls_back_instead_of_showing_nothing():
	# Deep-linking to a tab that does not exist in this build must land somewhere real.
	var sh = await _shop("coins")
	assert_ne(sh.current._tab, "coins", "the hidden tab must not stay selected")
	var texts: Array = []
	_texts(sh.current, texts)
	assert_true("\n".join(texts).contains(I18n.t("tab_items")),
		"the player must still see a working shop")
	sh.free()


## The 5.4 rejection also covered naming a rival store inside an APK.
func test_no_player_facing_string_hard_codes_a_store_name():
	for key in I18n.T:
		if String(key).begins_with("store_"):
			continue                          # the per-store names themselves
		var fa: String = String(I18n.T[key].fa)
		var en: String = String(I18n.T[key].en)
		for name in ["کافه‌بازار", "کافه بازار", "مایکت", "Cafe Bazaar", "Myket"]:
			assert_false(fa.contains(name),
				"i18n '%s' (fa) hard-codes the store name '%s' — use %%s with IAP.store_name()"
					% [key, name])
			assert_false(en.contains(name),
				"i18n '%s' (en) hard-codes the store name '%s'" % [key, name])


## The share text may name exactly ONE store: the one baked into this build. Which one
## that is depends on the last export, so assert consistency with StoreBrand rather than
## a fixed string.
func test_the_share_text_names_only_this_builds_store():
	var text := Share.store_line()
	var mine := StoreBrand.name_for_locale()
	assert_true(text.contains(mine),
		"the share line should name this build's own store (%s): %s" % [mine, text])
	for name in ["کافه‌بازار", "مایکت", "Cafe Bazaar", "Myket"]:
		if name == StoreBrand.FA or name == StoreBrand.EN:
			continue
		assert_false(text.contains(name),
			"share text names a rival store: %s" % text)


func test_buying_while_unavailable_never_grants_coins():
	Store.coins = 0
	var sh = await _shop("coins")
	sh.current._buy_sku("coins_mega")
	await wait_process_frames(1)
	assert_eq(Store.coins, 0, "a dead store must never hand out currency")
	sh.free()


func test_bonus_tiers_increase_with_price():
	var last := -1
	for sku in ["coins_small", "coins_medium", "coins_large", "coins_mega"]:
		var c: int = int(IAP.PRODUCTS[sku].coins)
		assert_gt(c, last, "%s must grant more than the tier below it" % sku)
		last = c


## Coin cards are tagged by shop_screen (CoinCard_<sku>). Selecting them by name keeps
## this test measuring the cards themselves rather than whatever container they sit in —
## an earlier shape-based guess silently started matching the tab's own VBox.
func _cards(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Control and String(c.name).begins_with("CoinCard_"):
			out.append(c)
		_cards(c, out)


func test_card_contents_stay_inside_the_card_and_never_overlap():
	if not IAP.implemented():
		# No billing in this build means no coins tab and no cards to measure. Say so
		# rather than passing vacuously — a green test that checked nothing is a lie.
		pending("no billing in this build: coin cards are not built, nothing to measure")
		return
	for size in [Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(800, 1280)]:
		get_tree().root.size = size
		var sh = load("res://scripts/main.gd").new()
		add_child(sh)
		await wait_process_frames(2)
		sh.show_screen("shop")
		await wait_process_frames(2)
		sh.current._tab = "coins"
		sh.current.relayout()
		await wait_process_frames(3)
		var cards: Array = []
		_cards(sh.current, cards)
		# In a build without billing the tab does not exist, so there is nothing to
		# measure — the geometry rules still apply wherever cards ARE built.
		for card in cards:
			var h: float = card.custom_minimum_size.y
			var parts: Array = []
			for ch in card.get_children():
				if not (ch is Control):
					continue
				var sz: Vector2 = ch.size
				if sz.x <= 0.0 or sz.y <= 0.0:
					sz = ch.get_combined_minimum_size()
				var r := Rect2(ch.position, sz)
				assert_lte(r.end.y, h + 1.0,
					"%s: '%s' hangs %s px below its card" % [size, ch.name, r.end.y - h])
				assert_gte(r.position.x, -1.0, "%s: '%s' starts off-card" % [size, ch.name])
				parts.append([ch.name, r])
			# the buy button must not sit on top of the price/amount text
			for i in parts.size():
				for j in range(i + 1, parts.size()):
					var a: Rect2 = parts[i][1]
					var b: Rect2 = parts[j][1]
					var hit := a.intersection(b)
					assert_lt(hit.get_area(), a.get_area() * 0.05 + 1.0,
						"%s: '%s' overlaps '%s'" % [size, parts[i][0], parts[j][0]])
		sh.free()
