# Godot EventSheets - Priced Tables pack runtime behaviour.
#
# Loads the COMPILED Priced Table behavior and drives it treeless (signals still emit on a bare
# instance, so the triggers are counted for real): stocking from a PriceTableResource, the four
# refusal reasons, stock counting (limited, unlimited, restock, restock all), the unlock gate,
# live re-pricing, and - the point of the pack - the DECOUPLED wallet seam, proven against a stub
# purse that only answers balance()/spend() and against the local fallback number.
#
# What this file CANNOT reach: the seam's other two tiers, the wallet-group search and the
# /root/CurrencyLedger autoload. Both need is_inside_tree(), and a treeless suite has no main loop -
# so what is proven here is the explicit Use Wallet Node tier, the local-number fallback, and the
# contract guard that refuses a node missing either function.
@tool
class_name PricedTablePackTest
extends RefCounted

const PACK := "res://eventsheet_addons/priced_table/priced_table_behavior.gd"
const RESOURCE_PACK := "res://eventsheet_addons/price_table_resource/price_table_resource.gd"


## A purse that is not the Currency Ledger, not in any group, and knows nothing about this pack -
## it just answers the two functions the seam asks for. If the table can spend from THIS, it can
## spend from anything the contract describes.
class StubWallet:
	extends Node

	var purses: Dictionary = {"gold": 100.0, "gems": 3.0}
	var spent_currencies: Array = []
	var spent_amounts: Array = []

	func balance(currency: String) -> float:
		return float(purses.get(currency, 0.0))

	func spend(currency: String, amount: float) -> void:
		spent_currencies.append(currency)
		spent_amounts.append(amount)
		purses[currency] = float(purses.get(currency, 0.0)) - amount


## A node that looks like a wallet but is missing spend() - the seam must skip it rather than
## call blindly and swallow the money.
class HalfWallet:
	extends Node

	func balance(_currency: String) -> float:
		return 9999.0


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("priced table pack loads + parses", script != null, true) and all_passed
	var resource_script: GDScript = load(RESOURCE_PACK)
	all_passed = _check("price table resource pack loads + parses", resource_script != null, true) and all_passed
	if script == null or resource_script == null:
		return all_passed

	# A blacksmith: a limited potion, an unlimited sword, a locked relic priced in gems, and a
	# blank-id row that must be skipped rather than stocked as "".
	var table: Resource = resource_script.new()
	table.table_name = "Blacksmith"
	table.default_currency = "gold"
	table.entries = [
		{"id": "potion", "label": "Small Potion", "price": 10.0, "currency": "", "stock": 2, "locked": false, "requires": ""},
		{"id": "sword", "label": "Iron Sword", "price": 50.0, "currency": "", "stock": -1, "locked": false, "requires": ""},
		{"id": "relic", "label": "Old Relic", "price": 2.0, "currency": "gems", "stock": 1, "locked": true, "requires": "needs the guild badge"},
		{"id": "", "label": "typo row", "price": 1.0, "currency": "", "stock": 1, "locked": false, "requires": ""}
	]

	var shop: Node = script.new()
	var seen: Dictionary = {"bought": [], "paid": [], "refused": []}
	shop.on_purchased.connect(func(entry_id: String, price: float) -> void:
		(seen.bought as Array).append(entry_id)
		(seen.paid as Array).append(price))
	shop.on_purchase_refused.connect(func(entry_id: String, reason: String) -> void: (seen.refused as Array).append("%s:%s" % [entry_id, reason]))
	shop.load_price_table(table)

	# --- What the table read off the resource ---
	all_passed = _check("the blank-id row is skipped", shop.entry_count(), 3) and all_passed
	all_passed = _check("the table name comes off the resource", shop.table_title(), "Blacksmith") and all_passed
	all_passed = _check("entries keep the table's order", shop.entry_id_at(1), "sword") and all_passed
	all_passed = _check("an out-of-range position is empty, not an error", shop.entry_id_at(9), "") and all_passed
	all_passed = _check("a price reads back", shop.price_of("potion"), 10.0) and all_passed
	all_passed = _check("an unknown id prices at -1, never free", shop.price_of("nope"), -1.0) and all_passed
	all_passed = _check("a blank currency cell inherits the table default", shop.currency_of("potion"), "gold") and all_passed
	all_passed = _check("a filled currency cell wins", shop.currency_of("relic"), "gems") and all_passed
	all_passed = _check("the label is what the player reads", shop.label_of("sword"), "Iron Sword") and all_passed
	all_passed = _check("the requirement note is handed back verbatim", shop.requirement_of("relic"), "needs the guild badge") and all_passed
	all_passed = _check("a ticked locked cell reads as not unlocked", shop.entry_is_unlocked("relic"), false) and all_passed
	all_passed = _check("an unticked locked cell sells straight away", shop.entry_is_unlocked("potion"), true) and all_passed
	all_passed = _check("stock reads off the grid", shop.stock_of("potion"), 2) and all_passed
	all_passed = _check("-1 stock stays unlimited", shop.stock_of("sword"), -1) and all_passed
	all_passed = _check("an unknown id has nothing to sell", shop.stock_of("nope"), 0) and all_passed

	# --- The fallback purse (no wallet node, no autoload, not even a tree) ---
	shop.set_local_wallet(30.0)
	all_passed = _check("the local purse is what the seam falls back to", shop.wallet_balance("gold"), 30.0) and all_passed
	all_passed = _check("30 gold cannot afford the 50 gold sword", shop.can_afford_entry("sword"), false) and all_passed
	all_passed = _check("30 gold can afford the 10 gold potion", shop.can_afford_entry("potion"), true) and all_passed

	shop.buy("potion")
	all_passed = _check("On Purchased fired with the entry's id", seen.bought, ["potion"]) and all_passed
	all_passed = _check("and carried what it cost", seen.paid, [10.0]) and all_passed
	all_passed = _check("the local purse was charged", shop.wallet_balance("gold"), 20.0) and all_passed
	all_passed = _check("limited stock counted down", shop.stock_of("potion"), 1) and all_passed
	all_passed = _check("the receipt outlives the handler", shop.last_purchased_id(), "potion") and all_passed
	all_passed = _check("and so does what it cost", shop.last_price_paid(), 10.0) and all_passed
	all_passed = _check("and the currency it was paid in", shop.last_currency_paid(), "gold") and all_passed

	# --- The four refusals, each with its own reason ---
	shop.buy("sword")
	all_passed = _check("an unaffordable buy is refused", seen.refused, ["sword:too expensive"]) and all_passed
	all_passed = _check("nothing was taken for it", shop.wallet_balance("gold"), 20.0) and all_passed
	all_passed = _check("the refusal reason is readable afterwards", shop.refused_reason(), "too expensive") and all_passed
	all_passed = _check("so is the refused entry", shop.refused_entry_id(), "sword") and all_passed

	shop.buy("relic")
	all_passed = _check("a locked entry is refused before any money is looked at", seen.refused, ["sword:too expensive", "relic:locked"]) and all_passed

	shop.buy("nope")
	all_passed = _check("an unknown id is refused as such", shop.refused_reason(), "unknown entry") and all_passed

	shop.buy("potion")
	all_passed = _check("the last potion sells", shop.stock_of("potion"), 0) and all_passed
	shop.buy("potion")
	all_passed = _check("a sold-out entry is refused", shop.refused_reason(), "out of stock") and all_passed
	all_passed = _check("and the sold-out buy took nothing", shop.wallet_balance("gold"), 10.0) and all_passed
	all_passed = _check("exactly four refusals, one per reason", (seen.refused as Array).size(), 4) and all_passed
	all_passed = _check("Entry In Stock agrees with the count", shop.entry_in_stock("potion"), false) and all_passed
	all_passed = _check("an unlimited entry is always in stock", shop.entry_in_stock("sword"), true) and all_passed

	# --- Unlocking, restocking, re-pricing ---
	shop.set_unlocked("relic", true)
	all_passed = _check("unlocking opens the entry", shop.entry_is_unlocked("relic"), true) and all_passed
	shop.restock("potion", 3)
	all_passed = _check("restocking adds to what is left", shop.stock_of("potion"), 3) and all_passed
	shop.restock("sword", 5)
	all_passed = _check("restocking leaves an unlimited entry alone", shop.stock_of("sword"), -1) and all_passed
	shop.restock_all()
	all_passed = _check("Restock All returns the shipped count", shop.stock_of("potion"), 2) and all_passed
	shop.set_price("sword", 5.0)
	all_passed = _check("re-pricing takes effect", shop.price_of("sword"), 5.0) and all_passed
	shop.set_price("sword", -3.0)
	all_passed = _check("a negative price clamps to free", shop.price_of("sword"), 0.0) and all_passed
	shop.set_stock("potion", 0)
	shop.set_stock("relic", 0)
	shop.set_stock("sword", 0)
	all_passed = _check("nothing left to sell reads as sold out", shop.is_sold_out(), true) and all_passed
	shop.set_stock("potion", -1)
	all_passed = _check("one unlimited entry is enough to reopen the shop", shop.is_sold_out(), false) and all_passed

	# --- The wallet seam: a stub purse that knows nothing about this pack ---
	var wallet: Node = StubWallet.new()
	var kiosk: Node = script.new()
	kiosk.load_price_table(table)
	kiosk.set_local_wallet(0.0)
	kiosk.use_wallet_node(wallet)
	all_passed = _check("the balance now comes from the wallet node", kiosk.wallet_balance("gold"), 100.0) and all_passed
	all_passed = _check("a second currency reads independently", kiosk.wallet_balance("gems"), 3.0) and all_passed
	all_passed = _check("the 50 gold sword is affordable from 100 gold", kiosk.can_afford_entry("sword"), true) and all_passed
	kiosk.buy("sword")
	all_passed = _check("the wallet node was charged, in its own currency", wallet.spent_currencies, ["gold"]) and all_passed
	all_passed = _check("for exactly the entry's price", wallet.spent_amounts, [50.0]) and all_passed
	all_passed = _check("the wallet node's balance moved", kiosk.wallet_balance("gold"), 50.0) and all_passed
	all_passed = _check("the local number was never touched", kiosk.local_wallet, 0.0) and all_passed
	kiosk.set_unlocked("relic", true)
	kiosk.buy("relic")
	all_passed = _check("a gems-priced entry spends gems", wallet.spent_currencies, ["gold", "gems"]) and all_passed
	all_passed = _check("at the gems price, not the gold one", wallet.spent_amounts, [50.0, 2.0]) and all_passed
	all_passed = _check("gems came out of the gems purse", kiosk.wallet_balance("gems"), 1.0) and all_passed

	# A node that answers only half the contract must be ignored, not called blindly.
	var half: Node = HalfWallet.new()
	kiosk.use_wallet_node(half)
	all_passed = _check("a half-implemented wallet is skipped for the local number", kiosk.wallet_balance("gold"), 0.0) and all_passed
	# Clearing has to be tested against a wallet the seam ACCEPTS, or the fall-back it is supposed to
	# prove was already in force: put the working purse back (50 gold left after the sword), then clear.
	kiosk.use_wallet_node(wallet)
	all_passed = _check("the working wallet reads again once it is put back", kiosk.wallet_balance("gold"), 50.0) and all_passed
	kiosk.use_wallet_node(null)
	all_passed = _check("clearing the wallet node falls back to the local number", kiosk.wallet_balance("gold"), 0.0) and all_passed

	# --- Building a table without a resource, and merging by id ---
	var kiosk2: Node = script.new()
	kiosk2.add_entry("tier1", "Sharper Blade", 25.0, "gold", 1)
	kiosk2.add_entry("tier2", "Sharper Still", 60.0, "gold", 1)
	all_passed = _check("Add Entry stocks a table with no resource at all", kiosk2.entry_count(), 2) and all_passed
	kiosk2.add_entry("tier1", "Sharper Blade", 20.0, "gold", 2)
	all_passed = _check("re-adding an id replaces rather than duplicates", kiosk2.entry_count(), 2) and all_passed
	all_passed = _check("the replacement's price is the live one", kiosk2.price_of("tier1"), 20.0) and all_passed
	all_passed = _check("and it kept its position in the table", kiosk2.entry_id_at(0), "tier1") and all_passed
	kiosk2.load_price_table(table)
	all_passed = _check("loading a table merges by id into the existing rows", kiosk2.entry_count(), 5) and all_passed
	kiosk2.clear_table()
	all_passed = _check("Clear Table empties it", kiosk2.entry_count(), 0) and all_passed
	all_passed = _check("an empty table counts as sold out", kiosk2.is_sold_out(), true) and all_passed

	# --- The save seam: the whole table travels, and the id index is rebuilt on the way back ---
	shop.set_local_wallet(42.0)
	var snapshot: Dictionary = shop.save_state()
	var restored: Node = script.new()
	restored.load_state(snapshot)
	all_passed = _check("the restored table has every entry", restored.entry_count(), 3) and all_passed
	all_passed = _check("the restored table keeps its name", restored.table_title(), "Blacksmith") and all_passed
	all_passed = _check("a restored price is addressable by id (the index was rebuilt)", restored.price_of("sword"), 0.0) and all_passed
	all_passed = _check("the restored stock is the one it was left with", restored.stock_of("potion"), -1) and all_passed
	all_passed = _check("the fallback purse travels too", restored.wallet_balance("gold"), 42.0) and all_passed

	all_passed = _check("the Priced Tables guide ships", FileAccess.file_exists("res://docs/Addons/Priced-Tables.md"), true) and all_passed

	wallet.free()
	half.free()
	restored.free()
	kiosk2.free()
	kiosk.free()
	shop.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] priced_table_pack_test: %s" % label)
		return true
	print("[FAIL] priced_table_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
