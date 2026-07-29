extends Node
## Autoload "Economy" — coin catalogue and spending.
##
## Design rules:
##  * Nothing here makes the daily مثل purchasable — the ritual must stay earned.
##  * Consumables are convenience/content, never power over other players.
##  * Every consumable is repeatable forever, so a player who wants to keep spending can.

signal inventory_changed
signal purchased(id: String)

## Repeatable coin purchases.
const ITEMS := {
	"hint":   {"cost": 1200, "amount": 12},  # each reveals one letter of a hidden word
	"shield": {"cost": 2500, "amount": 10},  # each covers one missed day
	"key":    {"cost": 4000, "amount": 10},  # each unlocks one treasury proverb
	"reroll": {"cost": 1500, "amount": 10},  # each swaps one of today's missions
}

## One-off cosmetics for the مثل card.
const FRAMES := {
	"classic":   {"cost": 0,     "color": Color("f2c230")},
	"turquoise": {"cost": 6000,  "color": Color("3fb8b0")},
	"rosewater": {"cost": 6000,  "color": Color("e08aa8")},
	"lapis":     {"cost": 9000,  "color": Color("6f8cf0")},
}


func item_cost(id: String) -> int:
	return int(ITEMS.get(id, {}).get("cost", 0))


func count(id: String) -> int:
	return int(Store.inventory.get(id, 0))


func can_afford(cost: int) -> bool:
	return Store.coins >= cost


## Buy a repeatable consumable with coins.
func buy_item(id: String) -> bool:
	if not ITEMS.has(id):
		return false
	var cost: int = ITEMS[id].cost
	if not can_afford(cost):
		return false
	Store.coins -= cost
	Store.inventory[id] = count(id) + int(ITEMS[id].amount)
	Store.save()
	inventory_changed.emit()
	purchased.emit(id)
	return true


## Spend one unit. Returns false when the player has none.
func use_item(id: String) -> bool:
	if count(id) <= 0:
		return false
	Store.inventory[id] = count(id) - 1
	Store.save()
	inventory_changed.emit()
	return true


func buy_frame(id: String) -> bool:
	if not FRAMES.has(id) or id in Store.frames_owned:
		return false
	var cost: int = FRAMES[id].cost
	if not can_afford(cost):
		return false
	Store.coins -= cost
	Store.frames_owned.append(id)
	Store.frame_active = id
	Store.save()
	purchased.emit(id)
	return true


func frame_color() -> Color:
	return FRAMES.get(Store.frame_active, FRAMES.classic).color


## Consume a treasury key: unlocks one uncollected proverb. Returns the level or {}.
func use_key() -> Dictionary:
	if count("key") <= 0:
		return {}
	var level := Masal.grant_milestone()
	if level.is_empty():
		return {}                 # nothing left to unlock — don't eat the key
	use_item("key")
	return level


## True while there is still something a key could unlock.
func key_is_useful() -> bool:
	return Masal.collected_count() < Masal.levels.size()
