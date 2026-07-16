## @ace_tags(loot, random)
## @ace_category("Loot")
@icon("res://eventsheet_addons/loot_table/icon.svg")
class_name LootBoxAddon
extends Node

## @ace_trigger
## @ace_name("On Roll Result")
## @ace_category("Loot")
signal on_roll_result
## @ace_trigger
## @ace_name("On Roll Complete")
## @ace_category("Loot")
signal on_roll_complete
## @ace_trigger
## @ace_name("On Pity Triggered")
## @ace_category("Loot")
signal on_pity_triggered

# id -> {entries: Array of {kind:"item"|"table", ref, weight, quantity, tags:PackedStringArray}, guarantees: Array of {tag, minimum}}.
var _tables: Dictionary = {}
# table -> {tag -> {threshold, count}} - hard pity, guarantees a tag after N straight misses.
var _pity: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_seed: int = 0
# Last-roll context (read via the getter expressions inside On Roll Result / On Roll Complete).
var _roll_table: String = ""
var _roll_item: String = ""
var _roll_quantity: float = 0.0
var _roll_tags: String = ""
var _roll_index: int = 0
var _roll_total: int = 0
var _pity_ctx_table: String = ""
var _pity_ctx_tag: String = ""
var _pity_ctx_count: int = 0
var _use_shared: bool = false

func _ready() -> void:
	_rng.randomize()

## @ace_action
## @ace_name("Create Table")
## @ace_category("Loot")
## @ace_description("Starts a fresh, empty loot table with this id (replaces any existing one).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.create_table({table_id})")
func create_table(table_id: String) -> void:
	_tables[table_id] = {"entries": [], "guarantees": []}

## @ace_action
## @ace_name("Add Entry")
## @ace_category("Loot")
## @ace_description("Adds an item to a table with a relative weight (higher = likelier). Quantity 1, no tags.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.add_entry({table_id}, {item_id}, {weight})")
func add_entry(table_id: String, item_id: String, weight: float) -> void:
	_table(table_id).entries.append({"kind": "item", "ref": item_id, "weight": maxf(weight, 0.0), "quantity": 1.0, "tags": PackedStringArray()})

## @ace_action
## @ace_name("Add Rare Entry")
## @ace_category("Loot")
## @ace_description("Adds an item with a weight, a quantity, and comma-separated tags (tags drive guarantees + pity).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.add_entry_full({table_id}, {item_id}, {weight}, {quantity}, {tags})")
func add_entry_full(table_id: String, item_id: String, weight: float, quantity: float, tags: String) -> void:
	var tag_list: PackedStringArray = PackedStringArray()
	for raw: String in tags.split(",", false):
		var trimmed: String = raw.strip_edges()
		if not trimmed.is_empty():
			tag_list.append(trimmed)
	_table(table_id).entries.append({"kind": "item", "ref": item_id, "weight": maxf(weight, 0.0), "quantity": maxf(quantity, 1.0), "tags": tag_list})

## @ace_action
## @ace_name("Add Table Reference")
## @ace_category("Loot")
## @ace_description("Adds an entry that rolls ANOTHER table inline when picked (shared common-loot pools). Depth-limited.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.add_table_ref({table_id}, {sub_table_id}, {weight})")
func add_table_ref(table_id: String, sub_table_id: String, weight: float) -> void:
	_table(table_id).entries.append({"kind": "table", "ref": sub_table_id, "weight": maxf(weight, 0.0), "quantity": 1.0, "tags": PackedStringArray()})

## @ace_action
## @ace_name("Set Guarantee")
## @ace_category("Loot")
## @ace_description("Guarantees at least `minimum` drops carrying this tag in every multi-roll batch.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.set_guarantee({table_id}, {tag}, {minimum})")
func set_guarantee(table_id: String, tag: String, minimum: int) -> void:
	_table(table_id).guarantees.append({"tag": tag, "minimum": maxi(minimum, 0)})

## @ace_action
## @ace_name("Set Pity")
## @ace_category("Loot")
## @ace_description("Hard pity: after `threshold` rolls in a row WITHOUT a tagged drop, the next roll GUARANTEES one (and fires On Pity Triggered).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.set_pity({table_id}, {tag}, {threshold})")
func set_pity(table_id: String, tag: String, threshold: int) -> void:
	if not _pity.has(table_id):
		_pity[table_id] = {}
	_pity[table_id][tag] = {"threshold": maxi(threshold, 1), "count": 0}

## @ace_action
## @ace_name("Reset Pity")
## @ace_category("Loot")
## @ace_description("Zeroes a tag's pity counter for a table.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.reset_pity({table_id}, {tag})")
func reset_pity(table_id: String, tag: String) -> void:
	if _pity.has(table_id) and _pity[table_id].has(tag):
		_pity[table_id][tag].count = 0

## @ace_action
## @ace_name("Set Seed")
## @ace_category("Loot")
## @ace_description("Makes rolls repeatable from a fixed seed (same seed = same sequence). Pass 0 to go back to random.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.set_seed({seed_value})")
func set_seed(seed_value: int) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

## @ace_action
## @ace_name("Use Advanced Random")
## @ace_category("Loot")
## @ace_description("When on, rolls draw from the shared AdvancedRandom autoload instead of this pack's own generator, so one seed drives your whole game's randomness. When off (the default) it uses its own seed. Needs the Advanced Random pack installed (it safely falls back to the local generator if not).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.use_advanced_random({enabled})")
func use_advanced_random(enabled: bool) -> void:
	_use_shared = enabled

## @ace_action
## @ace_name("Load From Resource")
## @ace_category("Loot")
## @ace_description("Loads a whole table from a Loot Table resource (a .tres you filled in the Inspector) - its name, entries, and pity - in one step. The data-driven alternative to Create Table plus a string of Add Entry actions.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.load_from_resource({loot_table})")
func load_from_resource(loot_table: Resource) -> void:
	if loot_table == null:
		push_warning("LootBox: Load From Resource was given no resource.")
		return
	var table_id: String = str(loot_table.get("table_name"))
	if table_id.is_empty():
		table_id = "loot"
	create_table(table_id)
	var rows: Variant = loot_table.get("entries")
	if rows is Array:
		for row: Variant in (rows as Array):
			if not (row is Dictionary):
				continue
			var item: String = str((row as Dictionary).get("item", ""))
			if item.is_empty():
				continue
			add_entry_full(table_id, item, float((row as Dictionary).get("weight", 1.0)), 1.0, str((row as Dictionary).get("tags", "")))
	var pity_tag_value: String = str(loot_table.get("pity_tag"))
	var pity_threshold_value: int = int(loot_table.get("pity_threshold"))
	if not pity_tag_value.is_empty() and pity_threshold_value > 0:
		set_pity(table_id, pity_tag_value, pity_threshold_value)

## @ace_action
## @ace_name("Roll")
## @ace_category("Loot")
## @ace_description("Rolls the table once, firing On Roll Result then On Roll Complete.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.roll({table_id})")
func roll(table_id: String) -> void:
	_roll_batch(table_id, 1)

## @ace_action
## @ace_name("Roll Times")
## @ace_category("Loot")
## @ace_description("Rolls the table `count` times in one batch (guarantees + pity apply across the batch), then shuffles.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.roll_times({table_id}, {count})")
func roll_times(table_id: String, count: int) -> void:
	_roll_batch(table_id, maxi(count, 1))

## @ace_condition
## @ace_name("Has Table")
## @ace_category("Loot")
## @ace_description("Whether a table with this id is registered.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.has_table({table_id})")
func has_table(table_id: String) -> bool:
	return _tables.has(table_id)

## @ace_condition
## @ace_name("Entry Has Tag")
## @ace_category("Loot")
## @ace_description("Whether any entry in a table carries the given tag.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.entry_has_tag({table_id}, {tag})")
func entry_has_tag(table_id: String, tag: String) -> bool:
	if not _tables.has(table_id):
		return false
	for e: Dictionary in _tables[table_id].entries:
		if tag in (e.tags as PackedStringArray):
			return true
	return false

## @ace_expression
## @ace_name("Table Count")
## @ace_category("Loot")
## @ace_description("How many tables are registered.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.table_count()")
func table_count() -> int:
	return _tables.size()

## @ace_expression
## @ace_name("Entry Count")
## @ace_category("Loot")
## @ace_description("How many entries a table has.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.entry_count({table_id})")
func entry_count(table_id: String) -> int:
	return int(_tables[table_id].entries.size()) if _tables.has(table_id) else 0

## @ace_expression
## @ace_name("Pity Count")
## @ace_category("Loot")
## @ace_description("The current miss streak for a table's tag.")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.pity_count_of({table_id}, {tag})")
func pity_count_of(table_id: String, tag: String) -> int:
	return int(_pity[table_id][tag].count) if _pity.has(table_id) and _pity[table_id].has(tag) else 0

## @ace_expression
## @ace_name("Roll Table")
## @ace_category("Loot")
## @ace_description("The table that was rolled (inside On Roll Result / Complete).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.roll_table()")
func roll_table() -> String:
	return _roll_table

## @ace_expression
## @ace_name("Roll Item")
## @ace_category("Loot")
## @ace_description("The item id that dropped (inside On Roll Result).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.roll_item()")
func roll_item() -> String:
	return _roll_item

## @ace_expression
## @ace_name("Roll Quantity")
## @ace_category("Loot")
## @ace_description("The quantity of the dropped item (inside On Roll Result).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.roll_quantity()")
func roll_quantity() -> float:
	return _roll_quantity

## @ace_expression
## @ace_name("Roll Tags")
## @ace_category("Loot")
## @ace_description("Comma-separated tags of the dropped item (inside On Roll Result).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.roll_tags()")
func roll_tags() -> String:
	return _roll_tags

## @ace_expression
## @ace_name("Roll Index")
## @ace_category("Loot")
## @ace_description("The 0-based position of this drop in the batch (inside On Roll Result).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.roll_index()")
func roll_index() -> int:
	return _roll_index

## @ace_expression
## @ace_name("Total Rolls")
## @ace_category("Loot")
## @ace_description("How many items dropped in the last batch (inside On Roll Complete).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.total_rolls()")
func total_rolls() -> int:
	return _roll_total

## @ace_expression
## @ace_name("Last Seed")
## @ace_category("Loot")
## @ace_description("The seed used for the last roll (store it to replay the exact drop).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.last_seed()")
func last_seed() -> int:
	return _last_seed

## @ace_expression
## @ace_name("Pity Table")
## @ace_category("Loot")
## @ace_description("The table whose pity fired (inside On Pity Triggered).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.pity_table()")
func pity_table() -> String:
	return _pity_ctx_table

## @ace_expression
## @ace_name("Pity Tag")
## @ace_category("Loot")
## @ace_description("The tag whose pity fired (inside On Pity Triggered).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.pity_tag()")
func pity_tag() -> String:
	return _pity_ctx_tag

## @ace_expression
## @ace_name("Pity Count At Trigger")
## @ace_category("Loot")
## @ace_description("The miss streak when pity fired (inside On Pity Triggered).")
## @ace_icon("res://eventsheet_addons/loot_table/icon.svg")
## @ace_codegen_template("LootBox.pity_count()")
func pity_count() -> int:
	return _pity_ctx_count

func _rand_float() -> float:
	# Randomness source: the shared AdvancedRandom autoload when Use Advanced Random is on and the
	# pack is installed, otherwise this pack's own seeded generator (the default - unchanged behaviour).
	if _use_shared and is_inside_tree():
		var shared: Node = get_node_or_null("/root/AdvancedRandom")
		if shared != null:
			return shared.random_value()
	return _rng.randf()

func _rand_int(minimum: int, maximum: int) -> int:
	if _use_shared and is_inside_tree():
		var shared: Node = get_node_or_null("/root/AdvancedRandom")
		if shared != null:
			return shared.random_int(minimum, maximum)
	return _rng.randi_range(minimum, maximum)

func _table(id: String) -> Dictionary:
	if not _tables.has(id):
		_tables[id] = {"entries": [], "guarantees": []}
	return _tables[id]

func _weighted_pick(entries: Array) -> Dictionary:
	# Weighted pick over a list of entry dicts with positive weight (proportional to weight).
	var total: float = 0.0
	for e: Dictionary in entries:
		total += maxf(e.weight, 0.0)
	if total <= 0.0:
		return {}
	var r: float = _rand_float() * total
	for e: Dictionary in entries:
		r -= maxf(e.weight, 0.0)
		if r <= 0.0:
			return e
	return entries[entries.size() - 1]

func _draw_one(table_id: String, depth: int) -> Array:
	# Draws one entry from a table, rolling a referenced sub-table inline (depth-limited).
	if depth > 8 or not _tables.has(table_id):
		return []
	var eligible: Array = []
	for e: Dictionary in _tables[table_id].entries:
		if e.weight > 0.0:
			eligible.append(e)
	if eligible.is_empty():
		return []
	var picked: Dictionary = _weighted_pick(eligible)
	if picked.is_empty():
		return []
	if picked.kind == "table":
		return _draw_one(picked.ref, depth + 1)
	return [{"item": picked.ref, "quantity": picked.quantity, "tags": picked.tags}]

func _roll_batch(table_id: String, count: int) -> void:
	# Rolls `count` draws in one batch: guarantees + hard pity first, then weighted fill, then shuffle.
	if not _tables.has(table_id):
		return
	var t: Dictionary = _tables[table_id]
	_last_seed = int(_rng.seed)
	var draws: int = maxi(count, 1)
	var forced: Array = []
	for g: Dictionary in t.guarantees:
		for _i: int in int(g.minimum):
			forced.append(g.tag)
	if _pity.has(table_id):
		for tag: String in _pity[table_id]:
			var p: Dictionary = _pity[table_id][tag]
			if p.count >= p.threshold:
				forced.append(tag)
				_pity_ctx_table = table_id
				_pity_ctx_tag = tag
				_pity_ctx_count = p.count
				on_pity_triggered.emit()
				p.count = 0
	var results: Array = []
	for tag: String in forced:
		if results.size() >= draws:
			break
		var tagged: Array = []
		for e: Dictionary in t.entries:
			if e.kind == "item" and e.weight > 0.0 and tag in e.tags:
				tagged.append(e)
		if tagged.is_empty():
			continue
		var e2: Dictionary = _weighted_pick(tagged)
		results.append({"item": e2.ref, "quantity": e2.quantity, "tags": e2.tags})
	var guard: int = 0
	while results.size() < draws and guard < draws * 4:
		guard += 1
		var drawn: Array = _draw_one(table_id, 0)
		if drawn.is_empty():
			break
		for d: Dictionary in drawn:
			if results.size() < draws:
				results.append(d)
	for i: int in range(results.size() - 1, 0, -1):
		var j: int = _rand_int(0, i)
		var tmp: Dictionary = results[i]
		results[i] = results[j]
		results[j] = tmp
	if _pity.has(table_id):
		for tag: String in _pity[table_id]:
			var got: bool = false
			for d: Dictionary in results:
				if tag in (d.tags as PackedStringArray):
					got = true
					break
			_pity[table_id][tag].count = 0 if got else int(_pity[table_id][tag].count) + 1
	_roll_total = results.size()
	for i: int in range(results.size()):
		var d: Dictionary = results[i]
		_roll_table = table_id
		_roll_item = str(d.item)
		_roll_quantity = float(d.quantity)
		_roll_tags = ",".join(d.tags as PackedStringArray)
		_roll_index = i
		on_roll_result.emit()
	on_roll_complete.emit()

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"pity": _pity.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_pity = (state.get("pity", {}) as Dictionary).duplicate(true)

# Loot Table: register as the LootBox autoload, build weighted drop tables with Create Table + Add Entry, then Roll by id and react with On Roll Result (once per item) and On Roll Complete. Balance is editing weight numbers, not rewiring events. This pack is an event sheet - extend it by editing it.
