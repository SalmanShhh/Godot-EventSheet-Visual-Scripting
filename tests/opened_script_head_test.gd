# Godot EventSheets - the head of an opened PLAIN SCRIPT, read in the event-sheet grammar (M34).
#
# A behavior pack introduces itself as one. Everybody else's .gd is a game script, and the head it
# used to show said "Script" and then listed GDScript type names: `Array[String] names = []`,
# `const SPEED = 300.0`, `PackedScene bullet_scene = preload("res://bullet.tscn")`. None of that is a
# sentence an event-sheet user reads. This test pins what replaced it, over two REAL hand-written
# fixtures (a fixture proves the shapes; only a real file proves the lens fires on one):
#
#   1. The Include bar names the OBJECT - its class_name when it has one, the ROOT NODE of the scene
#      it is attached to when it does not - then the class it is, then the two muted receipts (its
#      file, and that scene). A script no scene uses keeps its file name and grows no scene note.
#   2. Collections say what they hold: "list of text", "list of numbers", "table". An empty one reads
#      "empty" rather than `[]` / `{}`.
#   3. A constant says so in the type chip itself ("constant number"), and a whole number written as
#      a float drops the tail GDScript needs and a reader does not.
#   4. A preloaded scene is an OBJECT: `Object bullet_scene = Bullet  scene · head_bullet.tscn`,
#      whichever row shape carried it - a typed `var` (a lifted variable) or a `const` (a preload
#      block, which used to stop the head dead one line in).
#   5. Same folders as a pack: Triggers, Settings (per @export_group), Internal state - and they say
#      "script", not "pack", because that is what this file is.
#   6. The covenant: pure view. Both fixtures still re-emit byte-identically.
#
# VALUES are pinned, not counts - a count would still pass if the rows said the wrong words in the
# right shape.
@tool
class_name OpenedScriptHeadTest
extends RefCounted

const PLAYER_PATH := "res://tests/fixtures/opened_script_head_player.gd"
const PAD_PATH := "res://tests/fixtures/opened_script_head_pad.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_a_script_with_a_class_name() and ok
	ok = _test_a_script_named_by_its_scene() and ok
	ok = _test_a_script_no_scene_uses() and ok
	ok = _test_type_words() and ok
	ok = _test_round_trip() and ok
	return ok


## The whole head of the class_name fixture, row by row.
static func _test_a_script_with_a_class_name() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(PLAYER_PATH)
	var rows: Array = view.get_flat_rows()

	var bar: EventRowData = _row_at(rows, 0)
	ok = _check("an opened script opens on the Include bar",
		bar != null and bar.row_uid.begins_with("pack_include_bar_"), true) and ok
	ok = _check("the Include bar names the object, its class and its receipts",
		_texts(bar),
		"⇥ | PlayerAvatar | a | CharacterBody2D | · opened_script_head_player.gd · scene opened_script_head_player.tscn | reads as events") and ok
	ok = _check("it is not called an Addon Pack", _texts(bar).contains("Addon Pack"), false) and ok
	ok = _check("it wears the identity bar's presence",
		bar != null and is_equal_approx(bar.height_scale, 1.5), true) and ok

	# The script's own opening sentence sits ABOVE class_name, where the importer's class-description
	# rule never looks - it must still read as the comment bar rather than vanishing with the strip.
	var about: EventRowData = _row_at(rows, 1)
	ok = _check("the file's own sentence reads directly under the identity",
		about != null and about.row_type == EventRowData.RowType.COMMENT, true) and ok
	ok = _check("and it is the script's doc block",
		_texts(about).begins_with("A hand-written game script - not a behavior pack"), true) and ok

	ok = _check("the head bars read in file order",
		_head_bar_titles(rows), "Triggers | Movement | Instance variables") and ok
	ok = _check("the Triggers bar says a SCRIPT fires them",
		_texts(_bar_titled(rows, "Triggers")), "Triggers | this script fires - 3") and ok
	ok = _test_signals_read_as_triggers(view) and ok
	ok = _check("the @export_group is the settings bar",
		_texts(_bar_titled(rows, "Movement")), "Movement | 2 settings") and ok
	ok = _check("the one variable folder names the object it belongs to",
		_texts(_bar_titled(rows, "Instance variables")), "Instance variables | of PlayerAvatar") and ok
	view.free()
	return ok


## A plain script's signals ARE its triggers - nothing publishes them and nothing has to. So each row
## reads the way every other trigger in the editor reads: the ➜ badge, `On <Signal>` in the words a
## reader uses, and the values it hands over as chips beside it. The row used to say `died | internal`,
## which named a distinction only a behavior pack has.
static func _test_signals_read_as_triggers(view: EventSheetViewport) -> bool:
	var ok: bool = true
	var signals: Array[EventRowData] = _signal_rows(view)
	ok = _check("the file's three signals are three rows", signals.size(), 3) and ok
	if signals.size() != 3:
		return false
	ok = _check("a declared signal reads as the trigger it is",
		_texts(signals[0]), "➜ | On Died") and ok
	ok = _check("a multi-word signal name reads in words",
		_texts(signals[1]), "➜ | On Picked Up Coin") and ok
	ok = _check("the values a signal passes are chips beside it",
		_texts(signals[2]), "➜ | On Hit | body") and ok
	ok = _check("and that payload is the SAME span shape a handler's trigger row draws",
		_span_kinds(signals[2]), "signal_row | signal_row | trigger_payload") and ok
	ok = _check("no signal row of a plain script says \"internal\"",
		_texts(signals[0]).contains("internal"), false) and ok
	return ok


## No class_name: the object is named after the root node of the scene the script drives.
static func _test_a_script_named_by_its_scene() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(PAD_PATH)
	var bar: EventRowData = _row_at(view.get_flat_rows(), 0)
	ok = _check("a script with no class_name is named by its scene's root node",
		_texts(bar),
		"⇥ | SpawnerPad | a | Node2D | · opened_script_head_pad.gd · scene opened_script_head_pad.tscn | reads as events") and ok
	view.free()
	return ok


## No class_name and no scene: the file name is the last thing left, and no scene note is invented.
static func _test_a_script_no_scene_uses() -> bool:
	var ok: bool = true
	var sheet := EventSheetResource.new()
	sheet.read_only = true
	sheet.host_class = "Node2D"
	sheet.external_source_path = "res://tests/fixtures/no_such_script_head.gd"
	var prelude := RawCodeRow.new()
	prelude.code = "extends Node2D\n"
	sheet.events.append(prelude)
	var knob := LocalVariable.new()
	knob.name = "speed"
	knob.type_name = "float"
	knob.default_value = 200.0
	knob.exported = true
	sheet.events.append(knob)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var bar: EventRowData = _row_at(view.get_flat_rows(), 0)
	ok = _check("a script no scene uses falls back to its file name",
		_texts(bar), "⇥ | no_such_script_head | a | Node2D | · no_such_script_head.gd | reads as events") and ok
	view.free()
	return ok


## The type words, the values, the constant and the two preload shapes.
static func _test_type_words() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(PLAYER_PATH)
	var internal_bar: EventRowData = _bar_titled(view.get_flat_rows(), "Instance variables")
	ok = _check("the Instance variables bar was found", internal_bar != null, true) and ok
	if internal_bar == null:
		view.free()
		return false
	var read: PackedStringArray = PackedStringArray()
	for child: EventRowData in internal_bar.children:
		read.append(_texts(child))
	ok = _check("a const preload reads as an Object row",
		read[0] if read.size() > 0 else "", "Object | PAD_SCENE | = | SpawnerPad | scene · opened_script_head_pad.tscn") and ok
	ok = _check("a constant says so in its type chip, and 300.0 reads 300",
		read[1] if read.size() > 1 else "", "x | Constant | number | MAX_SPEED | = | 300 | const MAX_SPEED := 300.0") and ok
	ok = _check("a typed var holding a preload reads as an Object row too",
		read[2] if read.size() > 2 else "", "Object | bullet_scene | = | Bullet | scene · head_bullet.tscn") and ok
	ok = _check("Array[String] says what it holds, and [] reads empty",
		read[3] if read.size() > 3 else "", "x | Instance | list of text | names | = | empty | var names: Array[String] = []") and ok
	ok = _check("Array[int] says what it holds",
		read[4] if read.size() > 4 else "", "x | Instance | list of numbers | scores | = | empty | var scores: Array[int] = []") and ok
	ok = _check("a Dictionary is a table, and {} reads empty",
		read[5] if read.size() > 5 else "", "x | Instance | table | inventory | = | empty | var inventory: Dictionary = {}") and ok
	ok = _check("a plain float knob is unchanged",
		read[6] if read.size() > 6 else "", "x | Instance | number | _cooldown | = | 0 | var _cooldown: float = 0.0") and ok

	# The knob rows keep their doc comment, exactly as a pack's do.
	var movement_bar: EventRowData = _bar_titled(view.get_flat_rows(), "Movement")
	ok = _check("an @export knob reads type-word, name, value, description",
		_texts(movement_bar.children[0]) if movement_bar != null and not movement_bar.children.is_empty() else "",
		"x | Instance | number | move_speed | ⚙ | = | 180 | How fast the avatar walks, in pixels per second. | @export var move_speed: float = 180.0") and ok

	# The vocabulary itself, at the seam the verb chips share - the readings that already shipped must
	# not have moved, and the collection words must be derived from the element type rather than listed.
	ok = _check("text is still text", ViewportRowBuilder.friendly_type_word("String"), "text") and ok
	ok = _check("a declared int is a whole number", ViewportRowBuilder.friendly_type_word("int"), "whole number") and ok
	ok = _check("a bare Array is still a list", ViewportRowBuilder.friendly_type_word("Array"), "list") and ok
	ok = _check("a Node class is an object", ViewportRowBuilder.friendly_type_word("Node2D"), "object") and ok
	ok = _check("PackedStringArray reads like Array[String]",
		ViewportRowBuilder.friendly_type_word("PackedStringArray"), "list of text") and ok
	ok = _check("PackedVector2Array holds vectors",
		ViewportRowBuilder.friendly_type_word("PackedVector2Array"), "list of vectors") and ok
	ok = _check("a Callable is a function", ViewportRowBuilder.friendly_type_word("Callable"), "function") and ok
	ok = _check("a Signal is a signal", ViewportRowBuilder.friendly_type_word("Signal"), "signal") and ok
	ok = _check("an Array of objects holds objects",
		ViewportRowBuilder.friendly_type_word("Array[Node2D]"), "list of objects") and ok
	# A Resource subclass keeps the author's own noun - "resource" would say strictly less.
	ok = _check("a Resource subclass keeps its class name",
		ViewportRowBuilder.friendly_type_word("EventSheetResource"), "EventSheetResource") and ok
	view.free()
	return ok


## The covenant: every word above is a lens. The bytes are untouched.
static func _test_round_trip() -> bool:
	var ok: bool = true
	for path: String in [PLAYER_PATH, PAD_PATH]:
		var source: String = FileAccess.open(path, FileAccess.READ).get_as_text()
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		sheet.read_only = true
		var view := EventSheetViewport.new()
		view.set_ace_registry(EventSheetACERegistry.new())
		view.set_sheet(sheet)
		view.set_reading_mode(true)
		view.get_flat_rows()
		var reemitted: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
		ok = _check("%s still re-emits byte-identically" % path.get_file(), reemitted == source, true) and ok
		view.free()
	return ok


static func _open(path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	return view


static func _row_at(rows: Array, index: int) -> EventRowData:
	return (rows[index] as Dictionary).get("row") if index < rows.size() else null


static func _texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(str(span.text))
	return " | ".join(parts)


## Every signal row of an opened file, in file order. Walked from the row TREE, not the flat list -
## the Triggers bar opens folded, so its rows are real and simply not on screen yet.
static func _signal_rows(view: EventSheetViewport) -> Array[EventRowData]:
	var found: Array[EventRowData] = []
	_sweep_signal_rows(view, view._root_rows, found)
	return found


static func _sweep_signal_rows(view: EventSheetViewport, rows: Array, found: Array[EventRowData]) -> void:
	for row_data: EventRowData in rows:
		if row_data.row_uid.begins_with("signal_"):
			view._ensure_event_spans(row_data)
			found.append(row_data)
		_sweep_signal_rows(view, row_data.children, found)


static func _span_kinds(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(str(span.metadata.get("kind", "")))
	return " | ".join(parts)


static func _head_bar_titles(rows: Array) -> String:
	var titles: PackedStringArray = PackedStringArray()
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null:
			continue
		if row_data.row_uid.begins_with("pack_triggers") or row_data.row_uid.begins_with("pack_settings_") \
				or row_data.row_uid.begins_with("pack_internal_state"):
			titles.append(str(row_data.spans[0].text))
	return " | ".join(titles)


static func _bar_titled(rows: Array, title: String) -> EventRowData:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null or row_data.spans.is_empty():
			continue
		if row_data.row_type == EventRowData.RowType.GROUP and str(row_data.spans[0].text) == title:
			return row_data
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] opened_script_head_test: %s" % label)
		return true
	print("[FAIL] opened_script_head_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
