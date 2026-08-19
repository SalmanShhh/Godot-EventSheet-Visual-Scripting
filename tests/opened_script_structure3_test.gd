# EventForge - the third batch of event-sheet habits Godot spells differently (M36/M37/M39/M42),
# pinned by VALUE on real fixture files rather than on hand-built resources:
#
#   M36  a For-each whose ENTIRE body is one `if` is the event-sheet picking, and reads as one event
#   M37  a `match` on a plain value reads as the if / else-if / else chain an event-sheet user knows
#   M39  instantiate + add_child (+ the first position) is the event-sheet single Create object
#   M42  a signal the Godot editor wired in the .tscn reads as the trigger it is
#
# All four are READINGS. The rows in the sheet, the GDScript that comes back out, and every byte of
# it are unchanged - which is the first thing asserted here, on both fixtures, because a reading that
# costs a file its round-trip is not a reading, it is a bug.
@tool
class_name OpenedScriptStructure3Test
extends RefCounted

const ARENA_PATH: String = "res://tests/fixtures/opened_script_structure3.gd"
const MENU_PATH: String = "res://tests/fixtures/opened_script_structure3_menu.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _round_trips() and ok
	ok = _scene_connections() and ok
	ok = _picking_grammar() and ok
	ok = _else_if_grammar() and ok
	ok = _rows() and ok
	return ok


## ── the contract that outranks every reading ─────────────────────────────────────────────────────
static func _round_trips() -> bool:
	var ok: bool = true
	for path: String in [ARENA_PATH, MENU_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		var output: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
		ok = _check("%s comes back byte-identical" % path.get_file(), output, source) and ok
	return ok


## ── M42: the wiring lives in the .tscn, and the handler reads as the trigger it is ───────────────
static func _scene_connections() -> bool:
	var ok: bool = true
	var connections: Dictionary = EventSheetSceneConnections.for_script(MENU_PATH)
	var pressed: Dictionary = connections.get("_on_start_button_pressed", {}) as Dictionary
	ok = _check("the button's signal is found", str(pressed.get("signal", "")), "pressed") and ok
	ok = _check("the emitting node is named", str(pressed.get("source", "")), "StartButton") and ok
	ok = _check("the emitter's class comes from the scene", str(pressed.get("source_class", "")), "Button") and ok
	ok = _check("no connect line is claimed in the script", str(pressed.get("line", "")), "") and ok
	# A connection addressed to some OTHER node is that node's script's business, and a script no
	# scene root uses has no scene wiring at all.
	ok = _check("a script no scene root uses gets nothing",
		EventSheetSceneConnections.for_script("res://tests/fixtures/opened_script_head_pad.gd").is_empty(), true) and ok

	var sheet: EventSheetResource = GDScriptImporter.new().import_external(MENU_PATH)
	var triggers: Dictionary = {}
	for item: Variant in sheet.events:
		if item is EventRow:
			triggers[(item as EventRow).trigger_source_path] = (item as EventRow).trigger_id
	ok = _check("the button handler lifted as a signal trigger", str(triggers.get("StartButton", "")), "signal:pressed") and ok
	ok = _check("the timer handler lifted as the core timeout trigger", str(triggers.get("Countdown", "")), "OnTimeout") and ok
	ok = _check("neither handler stayed a plain helper function", sheet.functions.size(), 0) and ok
	return ok


## ── M36: which loops ARE picking, and what the note says ─────────────────────────────────────────
static func _picking_grammar() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	var builder: ViewportRowBuilder = viewport._row_builder
	ok = _check("a group walk names the group",
		builder._picking_source_note(PickFilter.CollectionKind.EXPRESSION,
			"get_tree().get_nodes_in_group(\"enemies\")"), "(group \"enemies\")") and ok
	ok = _check("the script's own children read as children",
		builder._picking_source_note(PickFilter.CollectionKind.EXPRESSION, "get_children()"), "(children)") and ok
	ok = _check("another object's children say whose",
		builder._picking_source_note(PickFilter.CollectionKind.EXPRESSION, "spawner.get_children()"),
		"(children of spawner)") and ok
	ok = _check("any other NAMED list is named as it is written",
		builder._picking_source_note(PickFilter.CollectionKind.EXPRESSION, "wave_members"), "(in wave_members)") and ok
	# `for i in 3:` is a count and `for x in build()` is a computation - neither is a set of instances,
	# and calling one "I (in 3)" would say something the code never did.
	ok = _check("a count is not a set of instances",
		builder._picking_source_note(PickFilter.CollectionKind.EXPRESSION, "3"), "") and ok
	ok = _check("a computed list is not either",
		builder._picking_source_note(PickFilter.CollectionKind.EXPRESSION, "build_wave()"), "") and ok
	# The object column names the thing, so the condition drops the loop's OWN possessive - and only
	# that one: a condition about a different object still has to say which.
	ok = _check("the picked object's possessive goes",
		ViewportRowBuilder._strip_picked_possessive("enemy's hp < 10", "Enemy"), "hp < 10") and ok
	ok = _check("another object's possessive stays",
		ViewportRowBuilder._strip_picked_possessive("player's hp < 10", "Enemy"), "player's hp < 10") and ok

	# A loop that filters, orders, caps or counts is doing work of its own, and a Repeat/While is not a
	# collection of instances at all - none of those may be swallowed into one picking row.
	var loop: EventRow = EventRow.new()
	var pick: PickFilter = PickFilter.new()
	pick.iterator_name = "enemy"
	pick.collection_value = "get_tree().get_nodes_in_group(\"enemies\")"
	loop.pick_filters.append(pick)
	loop.sub_events.append(EventRow.new())
	ok = _check("a plain group walk is picking", builder._picking_words(loop).get("object", ""), "Enemy") and ok
	pick.pick_first_n = 3
	ok = _check("a capped loop is not", builder._picking_words(loop).is_empty(), true) and ok
	pick.pick_first_n = 0
	pick.predicate_expression = "enemy.alive"
	ok = _check("a filtered loop is not", builder._picking_words(loop).is_empty(), true) and ok
	pick.predicate_expression = ""
	pick.collection_kind = PickFilter.CollectionKind.REPEAT
	ok = _check("a Repeat is not", builder._picking_words(loop).is_empty(), true) and ok
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	loop.actions.append(RawCodeRow.new())
	ok = _check("a body with a statement outside the if is not",
		builder._picking_words(loop).is_empty(), true) and ok

	# TWO independent ifs are two conditions, not one - merging them would hoist the second out of the
	# loop it runs in, which is the one thing this reading must never say. Only the first `if` and its
	# OWN else / elif arms merge, so the expansion is checked on built rows rather than on the words.
	loop.actions.clear()
	loop.sub_events.clear()
	var first_if: EventRow = EventRow.new()
	first_if.event_uid = "picking_first"
	first_if.conditions.append(ACECondition.new())
	var second_if: EventRow = EventRow.new()
	second_if.event_uid = "picking_second"
	second_if.conditions.append(ACECondition.new())
	loop.sub_events.append(first_if)
	loop.sub_events.append(second_if)
	loop.event_uid = "picking_loop"
	viewport.set_reading_mode(true)
	ok = _check("two independent ifs do not merge into the loop",
		builder._expand_picking_row(builder._build_event_row(loop, 0)).is_empty(), true) and ok
	# ...but the second sub-event being an ELSE arm of the first is exactly the shape that does.
	second_if.conditions.clear()
	second_if.else_mode = EventRow.ElseMode.ELSE
	ok = _check("an if with its own else merges",
		builder._expand_picking_row(builder._build_event_row(loop, 0)).size(), 2) and ok
	viewport.free()
	return ok


## ── M37: which matches read as a chain ───────────────────────────────────────────────────────────
static func _else_if_grammar() -> bool:
	var ok: bool = true
	ok = _check("a string pattern is plain", ViewportRowBuilder.is_plain_match_pattern("\"a\""), true) and ok
	ok = _check("several values are plain", ViewportRowBuilder.is_plain_match_pattern("\"a\", \"b\""), true) and ok
	ok = _check("an enum member is plain", ViewportRowBuilder.is_plain_match_pattern("State.PATROL"), true) and ok
	ok = _check("a number is plain", ViewportRowBuilder.is_plain_match_pattern("-3"), true) and ok
	ok = _check("the default is plain", ViewportRowBuilder.is_plain_match_pattern("_"), true) and ok
	# The shapes that say more than a chain can, and so keep the switch reading.
	ok = _check("a binding is not plain", ViewportRowBuilder.is_plain_match_pattern("var found"), false) and ok
	ok = _check("an array pattern is not plain", ViewportRowBuilder.is_plain_match_pattern("[a, b]"), false) and ok
	ok = _check("a dictionary pattern is not plain", ViewportRowBuilder.is_plain_match_pattern("{\"k\": v}"), false) and ok
	ok = _check("a call is not plain", ViewportRowBuilder.is_plain_match_pattern("pick()"), false) and ok
	return ok


## ── the rows a reader actually sees, by value ────────────────────────────────────────────────────
static func _rows() -> bool:
	var ok: bool = true
	var rows: PackedStringArray = _read_rows(ARENA_PATH)
	var joined: String = "\n".join(rows)
	# M42 - the two handlers lead with the node that emits, named and pictured from the scene.
	ok = _check("the button reads as its trigger",
		joined.contains("StartButton> On Pressed"), true) and ok
	ok = _check("the timer reads as its trigger",
		joined.contains("WaveTimer> On Timeout"), true) and ok
	# M36 - one event, the group as the object, the if as its condition, its body as the actions.
	ok = _check("the group loop and its if are ONE event",
		_row_containing(rows, "(group \"enemies\")"),
		"i2 [Enemy> (group \"enemies\") hp < 10 | enemy> Flee]") and ok
	ok = _check("an if/else inside a children loop keeps its Else",
		_row_containing(rows, "(children)"),
		"i2 [Child> (children) Is visible | child> Set invisible]") and ok
	# M37 - first case states the test, later cases are an Else carrying theirs, `_` is a plain Else.
	ok = _check("the first case states its test",
		_row_containing(rows, "difficulty = \"easy\""),
		"i2 [System> difficulty = \"easy\" | Set reward to 10]") and ok
	ok = _check("a multi-value case is an Else with an OR block",
		_row_containing(rows, "difficulty = \"normal\""),
		"i2 [System> Else | OR | System> difficulty = \"normal\" | OR | System> difficulty = \"hard\" | Set reward to 25]") and ok
	ok = _check("the default is a plain Else",
		_row_containing(rows, "Set reward to 0"),
		"i2 [System> Else | Set reward to 0]") and ok
	# M39 - three statements, one row, named after the scene's root and carrying the local name.
	# T22 re-pin: a property set on the way IN is part of making the thing, so it rides the same row as
	# a chip rather than following it as an action of its own.
	ok = _check("the spawn trio reads as one Create object",
		_row_containing(rows, "Create object"),
		"i2 [System> Create object Enemy at spawn point (as enemy)   speed = 40 | System> Add 1 to spawned | ⟡ Making an object and putting it somewhere]") and ok
	return ok


## Every row of an opened file as "i<indent> [<object>> <text> | ...]" - what a reader sees, in the
## order they see it, with the object column included because half of these readings ARE the object.
static func _read_rows(path: String) -> PackedStringArray:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	# Every bar folds closed by default and unfolding one reveals the next, so this runs until the
	# tree stops growing.
	for _pass: int in 4:
		for entry: Dictionary in viewport.get_flat_rows():
			var row_data: EventRowData = entry.get("row")
			if row_data != null and not row_data.row_uid.is_empty():
				viewport._fold_state[row_data.row_uid] = false
		viewport.set_sheet(sheet)
	var rows: PackedStringArray = PackedStringArray()
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		viewport._ensure_event_spans(row_data)
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			if span.text.strip_edges().is_empty():
				continue
			var object_label: String = str(span.metadata.get("object_label", ""))
			texts.append(("%s> " % object_label if not object_label.is_empty() else "") + span.text)
		rows.append("i%d [%s]" % [row_data.indent, " | ".join(texts)])
	viewport.free()
	return rows


## The one row holding `needle`, so a failure prints the row that IS there next to the one expected.
static func _row_containing(rows: PackedStringArray, needle: String) -> String:
	for row: String in rows:
		if row.contains(needle):
			return row
	return "<no row contains %s>" % needle


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] opened_script_structure3_test: %s" % label)
		return true
	print("[FAIL] opened_script_structure3_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
