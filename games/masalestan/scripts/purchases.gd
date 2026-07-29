extends Node
## Autoload "Purchases" — server-side receipt validation, offline-tolerant.
##
## The rule that drives every decision here: **the player has already been charged.**
## The store took their money before we ever see the receipt, so the only acceptable
## failure mode is granting coins we cannot yet verify. Refusing a paying customer
## because our own server is down is the one outcome that must never happen.
##
##   store says purchased -> grant immediately, queue the receipt
##   our server confirms  -> drop it from the queue, done
##   our server says fake -> drop it from the queue (already granted once; the ledger
##                           on the server records the attempt) and stop retrying
##   our server unreachable -> keep it queued and try again later, forever
##
## The queue survives restarts in `Store.pending_receipts`, so a purchase made on a
## plane is still reconciled a week later.

signal verified(sku: String, ok: bool)

const MAX_QUEUE := 50

var _busy := false


func _ready() -> void:
	IAP.purchase_finished.connect(_on_purchase)
	flush.call_deferred()


## Record a receipt for verification. Called with whatever the store handed back.
func record(sku: String, purchase_token: String, store: String) -> void:
	if purchase_token.strip_edges() == "":
		return                    # nothing to verify against; the grant already happened
	var queue: Array = Store.pending_receipts
	for item in queue:
		if String(item.get("t", "")) == purchase_token:
			return                # already queued
	queue.append({"sku": sku, "t": purchase_token, "store": store})
	while queue.size() > MAX_QUEUE:
		queue.pop_front()
	Store.pending_receipts = queue
	Store.save()
	flush()


func _on_purchase(sku: String, ok: bool, message: String) -> void:
	if not ok:
		return
	# `message` carries the store's purchase token when the plugin provides one.
	record(sku, message, IAP.backend)


func pending() -> int:
	return Store.pending_receipts.size()


## Try to verify the oldest queued receipt. Silent no-op when signed out or offline.
func flush() -> void:
	if _busy or not Account.signed_in() or Store.pending_receipts.is_empty():
		return
	_busy = true
	var item: Dictionary = Store.pending_receipts[0]
	Online.post_json("/api/%s/verify_purchase" % Online.GAME,
		{
			"token": Account.token,
			"store": String(item.get("store", "")),
			"product_id": String(item.get("sku", "")),
			"purchase_token": String(item.get("t", "")),
			"device_id": Online.device_id,
		},
		func(_ok: bool, code: int, data: Dictionary):
			_busy = false
			var settled := false
			if code >= 200 and code < 300:
				settled = true                       # confirmed, or a known replay
			elif code == 402:
				settled = true                       # the store denies it; stop retrying
			elif code == 401:
				# our session expired: keep the receipt, it is not the player's fault
				settled = false
			# 503 / 0 / anything else: unreachable, keep it and try again later
			if settled:
				var queue: Array = Store.pending_receipts
				if not queue.is_empty():
					queue.pop_front()
				Store.pending_receipts = queue
				Store.save()
				verified.emit(String(item.get("sku", "")), code != 402)
				if not queue.is_empty():
					flush())
