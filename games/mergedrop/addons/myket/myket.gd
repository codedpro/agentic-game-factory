@abstract
class_name MyketBilling
extends Object
## GDScript face of the Myket billing plugin.
##
## The API deliberately mirrors Poolakey (Cafe Bazaar) so a single `iap.gd` drives either
## store: same method names, same callback order. Only one of the two plugins is present in
## a given build — see pipeline/build_stores.sh.

const SINGLETON := "GodotMyketBilling"

static var _singleton: Object = null


static func _get_singleton() -> Object:
	if _singleton == null and Engine.has_singleton(SINGLETON):
		_singleton = Engine.get_singleton(SINGLETON)
	return _singleton


static func is_available() -> bool:
	return _get_singleton() != null


## Myket does not take the RSA key on the client the way Poolakey does — purchases are
## verified from the returned signature (or server-side). The key is accepted for API
## symmetry and passed through so a future verification step can use it.
static func open_connection(public_key: String, succeed: Callable, failed: Callable,
		disconnected: Callable) -> void:
	var s := _get_singleton()
	if s == null:
		failed.call("plugin missing")
		return
	_connect_once(s, "connection_succeed", func(): succeed.call())
	_connect_once(s, "connection_failed", func(msg): failed.call(str(msg)))
	_connect_once(s, "disconnected", func(): disconnected.call())
	s.openConnection(public_key)


static func close_connection() -> void:
	var s := _get_singleton()
	if s:
		s.closeConnection()


## succeed receives an Array of {sku, price, title, description}.
static func get_products(sku_ids: PackedStringArray, succeed: Callable, failed: Callable) -> void:
	var s := _get_singleton()
	if s == null:
		failed.call("plugin missing")
		return
	_connect_once(s, "products_received", func(json):
		var parsed = JSON.parse_string(str(json))
		var out: Array = []
		if parsed is Array:
			for item in parsed:
				var d = item if item is Dictionary else JSON.parse_string(str(item))
				if d is Dictionary:
					out.append({
						"sku": d.get("productId", ""),
						"price": d.get("price", ""),
						"title": d.get("title", ""),
						"description": d.get("description", ""),
					})
		succeed.call(out))
	s.getProducts(sku_ids)


## Callback order matches Poolakey exactly.
static func purchase_product(product_id: String, payload: String, _dynamic_price_token: String,
		flow_began: Callable, failed_to_begin: Callable, succeed: Callable,
		canceled: Callable, failed: Callable) -> void:
	var s := _get_singleton()
	if s == null:
		failed_to_begin.call("plugin missing")
		return
	_connect_once(s, "purchase_succeed", func(_sku, json):
		var d = JSON.parse_string(str(json))
		succeed.call(d if d is Dictionary else {}))
	_connect_once(s, "purchase_failed", func(_sku, msg): failed.call(str(msg)))
	_connect_once(s, "purchase_canceled", func(_sku): canceled.call())
	flow_began.call()
	s.purchase(product_id, payload)


## Consumables MUST be consumed or Myket keeps reporting the SKU as owned.
static func consume_product(purchase, succeed: Callable, failed: Callable) -> void:
	var s := _get_singleton()
	if s == null:
		failed.call("plugin missing")
		return
	var token := ""
	if purchase is Dictionary:
		token = str(purchase.get("purchaseToken", ""))
	elif purchase != null:
		token = str(purchase)
	if token == "":
		failed.call("no purchase token")
		return
	_connect_once(s, "consume_finished", func(_t, ok):
		if ok:
			succeed.call()
		else:
			failed.call("consume rejected"))
	s.consume(token)


static func _connect_once(s: Object, signal_name: String, cb: Callable) -> void:
	if not s.has_signal(signal_name):
		return
	for c in s.get_signal_connection_list(signal_name):
		s.disconnect(signal_name, c.callable)
	s.connect(signal_name, cb)
