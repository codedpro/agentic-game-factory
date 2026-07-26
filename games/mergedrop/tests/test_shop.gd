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


func test_coin_packs_are_listed_without_a_billing_plugin():
	# The dev/desktop build has no store plugin. The packs must still be visible.
	assert_false(IAP.available(), "precondition: this build has no billing plugin")
	var sh = await _shop("coins")
	var texts: Array = []
	_texts(sh.current, texts)
	var joined := "\n".join(texts)
	for sku in IAP.PRODUCT_ORDER:
		assert_true(joined.contains(I18n.t("sku_" + sku)),
			"coin pack '%s' is missing from the shop" % sku)
	var amount: String = I18n.t("coins_amount") % I18n.digits(
		int(IAP.PRODUCTS.coins_small.coins))
	assert_true(joined.contains(amount), "the pack must state how many coins it grants")
	sh.free()


func test_unavailable_billing_explains_itself_and_disables_buying():
	var reason := IAP.unavailable_reason()
	assert_ne(reason, "", "precondition: billing is not configured in tests")
	assert_ne(I18n.t("iap_" + reason), "iap_" + reason,
		"reason '%s' has no player-facing explanation" % reason)
	var sh = await _shop("coins")
	var texts: Array = []
	_texts(sh.current, texts)
	assert_true("\n".join(texts).contains(I18n.t("iap_unavailable")),
		"an inert buy button with no explanation reads as a broken game")
	var buys: Array = []
	_buttons(sh.current, buys)
	for b in buys:
		if b.text == I18n.t("buy_now"):
			assert_true(b.disabled, "buying must be impossible while billing is unavailable")
	sh.free()


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


func _cards(node: Node, out: Array) -> void:
	for c in node.get_children():
		# a coin card is a panel tall enough to hold the fs grid, carrying a buy button
		if c is Control and not (c is Button):
			var has_buy := false
			for g in c.get_children():
				if g is Button:
					has_buy = true
			if has_buy and c.get_child_count() >= 3:
				out.append(c)
		_cards(c, out)


func test_card_contents_stay_inside_the_card_and_never_overlap():
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
		assert_gt(cards.size(), 0, "no coin cards were built at %s" % size)
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
