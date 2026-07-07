# Pack builder - loot_table (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Loot Table: a weighted loot/reward ROLLER as an AUTOLOAD sheet (LootBox). Register tables of
## weighted entries once, then roll by id and react to what dropped. Ported from the Construct 3
## addon, Godot-native + beginner-friendly:
##  - Build tables with discrete typed ACEs (Create Table / Add Entry / Add Rare Entry / Add Table
##    Reference), NOT the escaped-JSON blobs the C3 version used.
##  - Real weighted picking via a seeded RandomNumberGenerator (deterministic when you Set Seed).
##  - Guarantees (a tag appears at least N times per multi-roll) and HARD pity (a tag is GUARANTEED
##    after N straight misses - what players actually expect from "pity", instead of C3's soft weight
##    doubling that only nudged the odds).
##  - Nested tables (an entry that rolls another table inline) via a typed reference, not a magic
##    "__table__" string.
## This is the full runtime engine, distinct from the plugin's small EnemyStats "loot table" drawer
## SHOWCASE (which is just a grid-edited Array field, no rolling).
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "LootBox"
	sheet.host_class = "Node"
	sheet.custom_class_name = "LootBoxAddon"
	sheet.addon_category = "Loot"
	sheet.addon_tags = PackedStringArray(["loot", "random"])
	var about: CommentRow = CommentRow.new()
	about.text = "Loot Table: register as the LootBox autoload, build weighted drop tables with Create Table + Add Entry, then Roll by id and react with On Roll Result (once per item) and On Roll Complete. Balance is editing weight numbers, not rewiring events. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Roll Result\")",
		"## @ace_category(\"Loot\")",
		"signal on_roll_result()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Roll Complete\")",
		"## @ace_category(\"Loot\")",
		"signal on_roll_complete()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Pity Triggered\")",
		"## @ace_category(\"Loot\")",
		"signal on_pity_triggered()",
		"",
		"# id -> {entries: Array of {kind:\"item\"|\"table\", ref, weight, quantity, tags:PackedStringArray}, guarantees: Array of {tag, minimum}}.",
		"var _tables: Dictionary = {}",
		"# table -> {tag -> {threshold, count}} - hard pity, guarantees a tag after N straight misses.",
		"var _pity: Dictionary = {}",
		"var _rng: RandomNumberGenerator = RandomNumberGenerator.new()",
		"var _last_seed: int = 0",
		"# Last-roll context (read via the getter expressions inside On Roll Result / On Roll Complete).",
		"var _roll_table: String = \"\"",
		"var _roll_item: String = \"\"",
		"var _roll_quantity: float = 0.0",
		"var _roll_tags: String = \"\"",
		"var _roll_index: int = 0",
		"var _roll_total: int = 0",
		"var _pity_ctx_table: String = \"\"",
		"var _pity_ctx_tag: String = \"\"",
		"var _pity_ctx_count: int = 0",
		"",
		"func _table(id: String) -> Dictionary:",
		"\tif not _tables.has(id):",
		"\t\t_tables[id] = {\"entries\": [], \"guarantees\": []}",
		"\treturn _tables[id]",
		"",
		"# Weighted pick over a list of entry dicts with positive weight (proportional to weight).",
		"func _weighted_pick(entries: Array) -> Dictionary:",
		"\tvar total: float = 0.0",
		"\tfor e: Dictionary in entries:",
		"\t\ttotal += maxf(e.weight, 0.0)",
		"\tif total <= 0.0:",
		"\t\treturn {}",
		"\tvar r: float = _rng.randf() * total",
		"\tfor e: Dictionary in entries:",
		"\t\tr -= maxf(e.weight, 0.0)",
		"\t\tif r <= 0.0:",
		"\t\t\treturn e",
		"\treturn entries[entries.size() - 1]",
		"",
		"# Draws one entry from a table, rolling a referenced sub-table inline (depth-limited).",
		"func _draw_one(table_id: String, depth: int) -> Array:",
		"\tif depth > 8 or not _tables.has(table_id):",
		"\t\treturn []",
		"\tvar eligible: Array = []",
		"\tfor e: Dictionary in _tables[table_id].entries:",
		"\t\tif e.weight > 0.0:",
		"\t\t\teligible.append(e)",
		"\tif eligible.is_empty():",
		"\t\treturn []",
		"\tvar picked: Dictionary = _weighted_pick(eligible)",
		"\tif picked.is_empty():",
		"\t\treturn []",
		"\tif picked.kind == \"table\":",
		"\t\treturn _draw_one(picked.ref, depth + 1)",
		"\treturn [{\"item\": picked.ref, \"quantity\": picked.quantity, \"tags\": picked.tags}]",
		"",
		"# Rolls `count` draws in one batch: guarantees + hard pity first, then weighted fill, then shuffle.",
		"func _roll_batch(table_id: String, count: int) -> void:",
		"\tif not _tables.has(table_id):",
		"\t\treturn",
		"\tvar t: Dictionary = _tables[table_id]",
		"\t_last_seed = int(_rng.seed)",
		"\tvar draws: int = maxi(count, 1)",
		"\tvar forced: Array = []",
		"\tfor g: Dictionary in t.guarantees:",
		"\t\tfor _i: int in int(g.minimum):",
		"\t\t\tforced.append(g.tag)",
		"\tif _pity.has(table_id):",
		"\t\tfor tag: String in _pity[table_id]:",
		"\t\t\tvar p: Dictionary = _pity[table_id][tag]",
		"\t\t\tif p.count >= p.threshold:",
		"\t\t\t\tforced.append(tag)",
		"\t\t\t\t_pity_ctx_table = table_id",
		"\t\t\t\t_pity_ctx_tag = tag",
		"\t\t\t\t_pity_ctx_count = p.count",
		"\t\t\t\ton_pity_triggered.emit()",
		"\t\t\t\tp.count = 0",
		"\tvar results: Array = []",
		"\tfor tag: String in forced:",
		"\t\tif results.size() >= draws:",
		"\t\t\tbreak",
		"\t\tvar tagged: Array = []",
		"\t\tfor e: Dictionary in t.entries:",
		"\t\t\tif e.kind == \"item\" and e.weight > 0.0 and tag in e.tags:",
		"\t\t\t\ttagged.append(e)",
		"\t\tif tagged.is_empty():",
		"\t\t\tcontinue",
		"\t\tvar e2: Dictionary = _weighted_pick(tagged)",
		"\t\tresults.append({\"item\": e2.ref, \"quantity\": e2.quantity, \"tags\": e2.tags})",
		"\tvar guard: int = 0",
		"\twhile results.size() < draws and guard < draws * 4:",
		"\t\tguard += 1",
		"\t\tvar drawn: Array = _draw_one(table_id, 0)",
		"\t\tif drawn.is_empty():",
		"\t\t\tbreak",
		"\t\tfor d: Dictionary in drawn:",
		"\t\t\tif results.size() < draws:",
		"\t\t\t\tresults.append(d)",
		"\tfor i: int in range(results.size() - 1, 0, -1):",
		"\t\tvar j: int = _rng.randi_range(0, i)",
		"\t\tvar tmp: Dictionary = results[i]",
		"\t\tresults[i] = results[j]",
		"\t\tresults[j] = tmp",
		"\tif _pity.has(table_id):",
		"\t\tfor tag: String in _pity[table_id]:",
		"\t\t\tvar got: bool = false",
		"\t\t\tfor d: Dictionary in results:",
		"\t\t\t\tif tag in (d.tags as PackedStringArray):",
		"\t\t\t\t\tgot = true",
		"\t\t\t\t\tbreak",
		"\t\t\t_pity[table_id][tag].count = 0 if got else int(_pity[table_id][tag].count) + 1",
		"\t_roll_total = results.size()",
		"\tfor i: int in range(results.size()):",
		"\t\tvar d: Dictionary = results[i]",
		"\t\t_roll_table = table_id",
		"\t\t_roll_item = str(d.item)",
		"\t\t_roll_quantity = float(d.quantity)",
		"\t\t_roll_tags = \",\".join(d.tags as PackedStringArray)",
		"\t\t_roll_index = i",
		"\t\ton_roll_result.emit()",
		"\ton_roll_complete.emit()"
	]))
	sheet.events.append(block)
	# Seed the RNG once so rolls vary between runs until the user calls Set Seed.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "_rng.randomize()"
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)

	# --- Build tables ---
	Lib.append_function(sheet, "create_table", "Create Table", "Loot", "Starts a fresh, empty loot table with this id (replaces any existing one).",
		[["table_id", "String"]],
		"_tables[table_id] = {\"entries\": [], \"guarantees\": []}")
	Lib.append_function(sheet, "add_entry", "Add Entry", "Loot", "Adds an item to a table with a relative weight (higher = likelier). Quantity 1, no tags.",
		[["table_id", "String"], ["item_id", "String"], ["weight", "float"]],
		"_table(table_id).entries.append({\"kind\": \"item\", \"ref\": item_id, \"weight\": maxf(weight, 0.0), \"quantity\": 1.0, \"tags\": PackedStringArray()})")
	Lib.append_function(sheet, "add_entry_full", "Add Rare Entry", "Loot", "Adds an item with a weight, a quantity, and comma-separated tags (tags drive guarantees + pity).",
		[["table_id", "String"], ["item_id", "String"], ["weight", "float"], ["quantity", "float"], ["tags", "String"]],
		"var tag_list: PackedStringArray = PackedStringArray()\nfor raw: String in tags.split(\",\", false):\n\tvar trimmed: String = raw.strip_edges()\n\tif not trimmed.is_empty():\n\t\ttag_list.append(trimmed)\n_table(table_id).entries.append({\"kind\": \"item\", \"ref\": item_id, \"weight\": maxf(weight, 0.0), \"quantity\": maxf(quantity, 1.0), \"tags\": tag_list})")
	Lib.append_function(sheet, "add_table_ref", "Add Table Reference", "Loot", "Adds an entry that rolls ANOTHER table inline when picked (shared common-loot pools). Depth-limited.",
		[["table_id", "String"], ["sub_table_id", "String"], ["weight", "float"]],
		"_table(table_id).entries.append({\"kind\": \"table\", \"ref\": sub_table_id, \"weight\": maxf(weight, 0.0), \"quantity\": 1.0, \"tags\": PackedStringArray()})")
	Lib.append_function(sheet, "set_guarantee", "Set Guarantee", "Loot", "Guarantees at least `minimum` drops carrying this tag in every multi-roll batch.",
		[["table_id", "String"], ["tag", "String"], ["minimum", "int"]],
		"_table(table_id).guarantees.append({\"tag\": tag, \"minimum\": maxi(minimum, 0)})")
	Lib.append_function(sheet, "set_pity", "Set Pity", "Loot", "Hard pity: after `threshold` rolls in a row WITHOUT a tagged drop, the next roll GUARANTEES one (and fires On Pity Triggered).",
		[["table_id", "String"], ["tag", "String"], ["threshold", "int"]],
		"if not _pity.has(table_id):\n\t_pity[table_id] = {}\n_pity[table_id][tag] = {\"threshold\": maxi(threshold, 1), \"count\": 0}")
	Lib.append_function(sheet, "reset_pity", "Reset Pity", "Loot", "Zeroes a tag's pity counter for a table.",
		[["table_id", "String"], ["tag", "String"]],
		"if _pity.has(table_id) and _pity[table_id].has(tag):\n\t_pity[table_id][tag].count = 0")
	Lib.append_function(sheet, "set_seed", "Set Seed", "Loot", "Makes rolls repeatable from a fixed seed (same seed = same sequence). Pass 0 to go back to random.",
		[["seed_value", "int"]],
		"if seed_value == 0:\n\t_rng.randomize()\nelse:\n\t_rng.seed = seed_value")

	# --- Data-driven: load a whole table from a Custom Resource (.tres) ---
	Lib.append_function(sheet, "load_from_resource", "Load From Resource", "Loot", "Loads a whole table from a Loot Table resource (a .tres you filled in the Inspector) - its name, entries, and pity - in one step. The data-driven alternative to Create Table plus a string of Add Entry actions.",
		[["loot_table", "Resource"]],
		"\n".join(PackedStringArray([
			"if loot_table == null:",
			"\tpush_warning(\"LootBox: Load From Resource was given no resource.\")",
			"\treturn",
			"var table_id: String = str(loot_table.get(\"table_name\"))",
			"if table_id.is_empty():",
			"\ttable_id = \"loot\"",
			"create_table(table_id)",
			"var rows: Variant = loot_table.get(\"entries\")",
			"if rows is Array:",
			"\tfor row: Variant in (rows as Array):",
			"\t\tif not (row is Dictionary):",
			"\t\t\tcontinue",
			"\t\tvar item: String = str((row as Dictionary).get(\"item\", \"\"))",
			"\t\tif item.is_empty():",
			"\t\t\tcontinue",
			"\t\tadd_entry_full(table_id, item, float((row as Dictionary).get(\"weight\", 1.0)), 1.0, str((row as Dictionary).get(\"tags\", \"\")))",
			"var pity_tag_value: String = str(loot_table.get(\"pity_tag\"))",
			"var pity_threshold_value: int = int(loot_table.get(\"pity_threshold\"))",
			"if not pity_tag_value.is_empty() and pity_threshold_value > 0:",
			"\tset_pity(table_id, pity_tag_value, pity_threshold_value)"
		])))

	# --- Rolling ---
	Lib.append_function(sheet, "roll", "Roll", "Loot", "Rolls the table once, firing On Roll Result then On Roll Complete.",
		[["table_id", "String"]],
		"_roll_batch(table_id, 1)")
	Lib.append_function(sheet, "roll_times", "Roll Times", "Loot", "Rolls the table `count` times in one batch (guarantees + pity apply across the batch), then shuffles.",
		[["table_id", "String"], ["count", "int"]],
		"_roll_batch(table_id, maxi(count, 1))")

	# --- Conditions ---
	_condition(sheet, "has_table", "Has Table", "Loot", "Whether a table with this id is registered.", [["table_id", "String"]],
		"return _tables.has(table_id)")
	_condition(sheet, "entry_has_tag", "Entry Has Tag", "Loot", "Whether any entry in a table carries the given tag.", [["table_id", "String"], ["tag", "String"]],
		"if not _tables.has(table_id):\n\treturn false\nfor e: Dictionary in _tables[table_id].entries:\n\tif tag in (e.tags as PackedStringArray):\n\t\treturn true\nreturn false")

	# --- Expressions: catalog ---
	_number(sheet, "table_count", "Table Count", "Loot", "How many tables are registered.", [],
		"return _tables.size()", TYPE_INT)
	_number(sheet, "entry_count", "Entry Count", "Loot", "How many entries a table has.", [["table_id", "String"]],
		"return int(_tables[table_id].entries.size()) if _tables.has(table_id) else 0", TYPE_INT)
	_number(sheet, "pity_count_of", "Pity Count", "Loot", "The current miss streak for a table's tag.", [["table_id", "String"], ["tag", "String"]],
		"return int(_pity[table_id][tag].count) if _pity.has(table_id) and _pity[table_id].has(tag) else 0", TYPE_INT)

	# --- Expressions: On Roll Result / Complete context ---
	_number(sheet, "roll_table", "Roll Table", "Loot", "The table that was rolled (inside On Roll Result / Complete).", [],
		"return _roll_table", TYPE_STRING)
	_number(sheet, "roll_item", "Roll Item", "Loot", "The item id that dropped (inside On Roll Result).", [],
		"return _roll_item", TYPE_STRING)
	_number(sheet, "roll_quantity", "Roll Quantity", "Loot", "The quantity of the dropped item (inside On Roll Result).", [],
		"return _roll_quantity", TYPE_FLOAT)
	_number(sheet, "roll_tags", "Roll Tags", "Loot", "Comma-separated tags of the dropped item (inside On Roll Result).", [],
		"return _roll_tags", TYPE_STRING)
	_number(sheet, "roll_index", "Roll Index", "Loot", "The 0-based position of this drop in the batch (inside On Roll Result).", [],
		"return _roll_index", TYPE_INT)
	_number(sheet, "total_rolls", "Total Rolls", "Loot", "How many items dropped in the last batch (inside On Roll Complete).", [],
		"return _roll_total", TYPE_INT)
	_number(sheet, "last_seed", "Last Seed", "Loot", "The seed used for the last roll (store it to replay the exact drop).", [],
		"return _last_seed", TYPE_INT)
	# --- Expressions: On Pity Triggered context ---
	_number(sheet, "pity_table", "Pity Table", "Loot", "The table whose pity fired (inside On Pity Triggered).", [],
		"return _pity_ctx_table", TYPE_STRING)
	_number(sheet, "pity_tag", "Pity Tag", "Loot", "The tag whose pity fired (inside On Pity Triggered).", [],
		"return _pity_ctx_tag", TYPE_STRING)
	_number(sheet, "pity_count", "Pity Count At Trigger", "Loot", "The miss streak when pity fired (inside On Pity Triggered).", [],
		"return _pity_ctx_count", TYPE_INT)

	return Lib.save_pack(sheet, "res://eventsheet_addons/loot_table/loot_table_addon")


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _number(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
