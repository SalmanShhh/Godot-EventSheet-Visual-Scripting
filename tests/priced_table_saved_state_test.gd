# Godot EventSheets - Priced Table keeps its saved state exactly as it was.
#
# Entries are small PriceEntry records in memory and plain dictionaries in a save, under the same
# eight keys as always. The old form below was produced by the pack BEFORE the records existed: it
# must load, keep selling from the stock it was left with, and save again as the identical text.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "priced_table_saved_state_test"
const PACK := "res://eventsheet_addons/priced_table/priced_table_behavior.gd"
## Written by the pack before the change: a sword bought once, an unlimited potion, a locked key.
const OLD_STATE := '{"default_currency":"gold","entries":[{"currency":"gold","id":"sword","initial_stock":3,"label":"Iron Sword","price":25.5,"requires":"","stock":2,"unlocked":true},{"currency":"gold","id":"potion","initial_stock":-1,"label":"Potion, red","price":4.0,"requires":"","stock":-1,"unlocked":true},{"currency":"silver","id":"key","initial_stock":0,"label":"Gate key","price":0.0,"requires":"","stock":0,"unlocked":false}],"local_wallet":74.5,"table_name":""}'


static func run() -> bool:
	var script: GDScript = load(PACK)
	var restored: Node = script.new()
	restored.load_state(JSON.parse_string(OLD_STATE))
	var again: String = JSON.stringify(restored.save_state())
	var ok: bool = SUPPORT.pins(P, [
		["an old-form state loads every entry", restored.entry_count(), 3],
		["the stock it was left with survives", [restored.stock_of("sword"), restored.stock_of("potion")], [2, -1]],
		["a lock and a price survive", [restored.entry_is_unlocked("key"), restored.price_of("sword")], [false, 25.5]],
		["saving it again gives the identical text", again, OLD_STATE],
	])
	restored.buy("sword")
	ok = SUPPORT.pins(P, [
		["it keeps selling from the restored stock and wallet", [restored.stock_of("sword"), restored.local_wallet], [1, 49.0]],
	]) and ok
	restored.restock_all()
	ok = SUPPORT.pins(P, [["Restock All goes back to the stock the table shipped with", restored.stock_of("sword"), 3]]) and ok
	var sparse: Node = script.new()
	sparse.load_state({"entries": [{"id": "gem"}, "stray", {"label": "no id"}]})
	ok = SUPPORT.pins(P, [
		["a record missing keys reads the defaults, a stray element is dropped", sparse.entry_count(), 2],
		["and a missing stock is unlimited", sparse.stock_of("gem"), -1],
	]) and ok
	sparse.free()
	restored.free()
	return ok
