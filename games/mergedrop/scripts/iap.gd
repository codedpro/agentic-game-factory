extends Node
## Autoload "IAP" — Cafe Bazaar billing (Poolakey), behind a safe abstraction.
##
## The Poolakey addon is loaded DYNAMICALLY: referencing the `Poolakey` class directly
## would make this script fail to parse in any build without the addon, and the plugin
## only functions in a Gradle (custom build template) export anyway. With no plugin —
## desktop, headless CI, or the plain-template APK — `available()` is false, the shop
## hides the real-money tab, and the game stays fully playable offline.
##
## Setup that only the account owner can do (see releases/mergedrop/SUBMISSION.md):
##   1. Upload a signed release build to Pishkhan → app → «پرداخت درون‌برنامه‌ای».
##   2. Copy the RSA public key shown there into `user://iap_key.txt` or PUBLIC_KEY below.
##   3. Create one product per SKU in PRODUCTS with the same ids.

signal purchase_finished(sku: String, ok: bool, message: String)
signal ready_changed

## Per-store backends. Exactly one is present in a given build: the export pipeline gates
## each store's plugin on GF_STORE (see pipeline/build_stores.sh), because Bazaar and Myket
## each reject an APK carrying the other's billing permission.
const BAZAAR_ADDON := "res://addons/poolakey/poolakey.gd"
const MYKET_ADDON := "res://addons/myket/myket.gd"

## RSA public keys are issued per store, only after a build has been uploaded to that panel.
## Drop them in these files (or set the consts) — no key means the store tab stays hidden.
const KEY_FILES := {
	"bazaar": "user://iap_key_bazaar.txt",
	"myket": "user://iap_key_myket.txt",
}
const PUBLIC_KEYS := {
	"bazaar": "",
	"myket": "",
}

## Real-money catalogue. Every entry is CONSUMED after purchase, which is what makes
## these repeatable forever. SKUs must match the product ids created in the panel.
const PRODUCTS := {
	"coins_small":  {"coins": 500,  "supporter": 0},
	"coins_medium": {"coins": 1500, "supporter": 0},
	"coins_large":  {"coins": 4000, "supporter": 0},
	"supporter_tip": {"coins": 300, "supporter": 1},   # repeatable, cosmetic gratitude
}

var backend := ""              # "bazaar" | "myket" | "" when this build has no billing
var _api: GDScript = null      # the store's plugin script, loaded dynamically
var _connected := false
var _prices := {}
var _pending := ""


func _ready() -> void:
	if OS.get_name() != "Android":
		return
	# Both addon scripts may exist in the project, but only ONE store's native plugin is
	# compiled into a given APK — so ask the plugins which one is actually present.
	var bazaar: GDScript = load(BAZAAR_ADDON) if ResourceLoader.exists(BAZAAR_ADDON) else null
	var myket: GDScript = load(MYKET_ADDON) if ResourceLoader.exists(MYKET_ADDON) else null
	if myket != null and myket.is_available():
		backend = "myket"
		_api = myket
	elif bazaar != null and Engine.has_singleton("GodotPoolakey"):
		backend = "bazaar"
		_api = bazaar
	else:
		return
	var key := _public_key()
	if key == "":
		_api = null            # without the store's RSA key billing cannot work
		backend = ""
		return
	_api.open_connection(key,
		func() -> void:
			_connected = true
			_refresh_prices()
			ready_changed.emit(),
		func(_message: String) -> void:
			_connected = false,
		func() -> void:
			_connected = false)


func _public_key() -> String:
	if String(PUBLIC_KEYS.get(backend, "")) != "":
		return String(PUBLIC_KEYS[backend])
	var path := String(KEY_FILES.get(backend, ""))
	if path != "" and FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_as_text().strip_edges()
	return ""


## True only when a real billing backend is connected.
func available() -> bool:
	return _api != null and _connected


## Localised price for a SKU, or "" when unknown.
func price(sku: String) -> String:
	return str(_prices.get(sku, ""))


func _refresh_prices() -> void:
	if _api == null:
		return
	_api.get_products(PackedStringArray(PRODUCTS.keys()),
		func(products: Array) -> void:
			for p in products:
				_prices[p.sku] = p.price
			ready_changed.emit(),
		func(_message: String) -> void:
			pass)


## Begin a purchase. Always emits purchase_finished exactly once.
func purchase(sku: String) -> void:
	if not PRODUCTS.has(sku):
		purchase_finished.emit(sku, false, "unknown sku")
		return
	if not available():
		purchase_finished.emit(sku, false, "unavailable")
		return
	_pending = sku
	_api.purchase_product(sku, "", "",
		func() -> void: pass,                                   # flow began
		func(m: String) -> void: _fail(sku, m),                 # failed to begin
		func(purchase) -> void: _succeed(sku, purchase),        # succeeded
		func() -> void: _fail(sku, "canceled"),                 # user canceled
		func(m: String) -> void: _fail(sku, m))                 # failed


func _succeed(sku: String, purchase) -> void:
	_pending = ""
	_grant(sku)
	# Consuming is what allows the same SKU to be bought again — without it Bazaar
	# reports "already owned" on the second purchase.
	if _api and purchase != null:
		_api.consume_product(purchase, func() -> void: pass, func(_m: String) -> void: pass)
	purchase_finished.emit(sku, true, "")


func _fail(sku: String, message: String) -> void:
	_pending = ""
	purchase_finished.emit(sku, false, message)


func _grant(sku: String) -> void:
	var p: Dictionary = PRODUCTS.get(sku, {})
	if p.is_empty():
		return
	if p.coins > 0:
		Store.add_coins(p.coins)
	if p.supporter > 0:
		Store.supporter_level += p.supporter
		Store.save()
