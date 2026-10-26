# Godot EventSheets - the head of an opened PLAIN SCRIPT, read in the event-sheet grammar.
#
# A behavior pack introduces itself as one. Everybody else's .gd is a game script, and the head it
# used to show said "Script" and then listed GDScript type names: `Array[String] names = []`,
# `const SPEED = 300.0`, `PackedScene bullet_scene = preload("res://bullet.tscn")`. None of that is a
# sentence an event-sheet user reads. This test pins what replaced it, over two REAL hand-written
# fixtures (a fixture proves the shapes; only a real file proves the lens fires on one):
#
#   1. The file opens on ONE head bar: the name as written (its class_name, or its file name when it
#      declares none), what kind of script it is and what it extends, and its counts. Its own opening
#      sentence is the name's card, and a script no scene uses grows no scene note.
#   2. Collections say what they hold: "list of text", "list of numbers", "table". An empty one reads
#      "empty" rather than `[]` / `{}`.
#   3. A constant says so in the type chip itself ("constant number"), and a whole number written as
#      a float drops the tail GDScript needs and a reader does not.
#   4. A preloaded scene is an OBJECT: `Object bullet_scene = Bullet  scene · head_bullet.tscn`,
#      whichever row shape carried it - a typed `var` (a lifted variable) or a `const` (a preload
#      block, which used to stop the head dead one line in).
#   5. No folders the file does not have: the signals, the knobs and the variables read where the
#      file declares them, and an @export_group is the Inspector's own section around its knobs.
#   6. The covenant: pure view. Both fixtures still re-emit byte-identically.
#
# VALUES are pinned, not counts - a count would still pass if the rows said the wrong words in the
# right shape.
@tool
class_name OpenedScriptHeadTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
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
	var rows: Array = _all_rows(view)
	var head: EventRowData = _row_at(rows, 0)

	# The head is ONE bar: the name as written, what kind of script it is, what it extends, and the
	# counts. Nothing folds under it, and nothing else of the old head stack is drawn.
	ok = _check("an opened script opens on ONE head bar",
		_texts(head),
		"◆ | PlayerAvatar | Custom node · extends | CharacterBody2D | 7 variables | · | 1 event") and ok
	ok = _check("and the bar folds nothing", head.children.size(), 0) and ok
	ok = _check("the class it extends rides the head bar rather than a band of its own",
		_row_with_uid(rows, "sheet_head_extends_") == null, true) and ok
	ok = _check("there is no Include bar", _row_with_uid(rows, "pack_include_bar_") == null, true) and ok

	# The script's own opening sentence sits ABOVE class_name, where the importer's class-description
	# rule never looks - the head reads it off the prelude, and says it on the name's card.
	ok = _check("the file's own sentence is the name card's",
		str(Array(_card_of(head, "name").get("lines", [""]))[0]).begins_with(
			"A hand-written game script - not a behavior pack"), true) and ok
	ok = _check("and neither a band nor a comment row draws it",
		[_row_with_uid(rows, "sheet_head_description_"), _row_with_uid(rows, "head_description_row_")],
		[null, null]) and ok

	ok = _check("no invented bars: no Triggers, no settings folder, no Instance variables",
		_head_bar_titles(rows), "") and ok
	ok = _test_signals_read_as_triggers(view) and ok
	ok = _check("the @export_group is the Inspector's section, holding its knobs where the file has them",
		_section_members(rows, "variable_tree_group_Movement"), "move_speed, jump_height") and ok
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
## No class_name: the head bar names the file, as written.
static func _test_a_script_named_by_its_scene() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(PAD_PATH)
	var rows: Array = _all_rows(view)
	ok = _check("a script with no class_name is named by its file on the head bar",
		_texts(_row_at(rows, 0)),
		"◆ | opened_script_head_pad.gd | Script · extends | Node2D | 3 variables | · | 1 event") and ok
	ok = _check("and its card says where the file lives",
		str(_card_of(_row_at(rows, 0), "name").get("mono", "")), PAD_PATH) and ok
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
	var head: EventRowData = _row_with_uid(_all_rows(view), "sheet_head_bar_")
	ok = _check("a script no scene uses is named by its file",
		_texts(head), "◆ | no_such_script_head.gd | Script · extends | Node2D | 1 variable") and ok
	ok = _check("…and no scene note is invented", Array(_card_of(head, "name").get("notes", [])),
		["A script opened as a sheet: edit it here, and it stays plain GDScript. 0 events."]) and ok
	view.free()
	return ok


## The type words, the values, the constant and the two preload shapes - each read where the file
## declares it.
static func _test_type_words() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(PLAYER_PATH)
	var read: PackedStringArray = PackedStringArray()
	for entry: Variant in _all_rows(view):
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data.row_uid.begins_with("variable_reading_") or row_data.row_uid.begins_with("preload_reading_"):
			read.append(_texts(row_data))
	ok = _check("the members read in file order", read.size(), 9) and ok
	ok = _check("a const preload reads as an Object row",
		read[0] if read.size() > 0 else "", "Object | PAD_SCENE | = | SpawnerPad | scene · opened_script_head_pad.tscn") and ok
	ok = _check("a constant says so in its type chip, and 300.0 reads 300",
		read[1] if read.size() > 1 else "", "x | Constant | number | MAX_SPEED | = | 300 | const MAX_SPEED := 300.0") and ok
	# The knob rows keep their doc comment, exactly as a pack's do.
	ok = _check("an @export knob reads type-word, name, value, description",
		read[2] if read.size() > 2 else "",
		"x | Instance | number | move_speed | ⚙ | = | 180 | How fast the avatar walks, in pixels per second. | @export var move_speed: float = 180.0") and ok
	ok = _check("a typed var holding a preload reads as an Object row too",
		read[4] if read.size() > 4 else "", "Object | bullet_scene | = | Bullet | scene · head_bullet.tscn") and ok
	ok = _check("Array[String] says what it holds, and [] reads empty",
		read[5] if read.size() > 5 else "", "x | Instance | list of text | names | = | empty | var names: Array[String] = []") and ok
	ok = _check("Array[int] says what it holds",
		read[6] if read.size() > 6 else "", "x | Instance | list of numbers | scores | = | empty | var scores: Array[int] = []") and ok
	ok = _check("a Dictionary is a table, and {} reads empty",
		read[7] if read.size() > 7 else "", "x | Instance | table | inventory | = | empty | var inventory: Dictionary = {}") and ok
	ok = _check("a plain float knob is unchanged",
		read[8] if read.size() > 8 else "", "x | Instance | number | _cooldown | = | 0 | var _cooldown: float = 0.0") and ok

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


## Every row of an opened file, parents before children, in the shape `get_flat_rows()` answers in -
## an Inspector section's strip holds its knobs as children, and a test of what they say must see them.
static func _all_rows(view: EventSheetViewport) -> Array:
	var found: Array = []
	_sweep_rows(view, view._root_rows, found)
	return found


static func _sweep_rows(view: EventSheetViewport, rows: Array, into: Array) -> void:
	for row_data: EventRowData in rows:
		view._row_builder._ensure_event_spans(row_data)
		into.append({"row": row_data})
		_sweep_rows(view, row_data.children, into)


static func _row_at(rows: Array, index: int) -> EventRowData:
	return (rows[index] as Dictionary).get("row") if index < rows.size() else null


## The first row whose uid opens with `prefix`, or null.
static func _row_with_uid(rows: Array, prefix: String) -> EventRowData:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return row_data
	return null


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
			view._row_builder._ensure_event_spans(row_data)
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


## The card behind one word of a head bar, by its id - {} when the bar has no such word.
static func _card_of(row_data: EventRowData, card_id: String) -> Dictionary:
	for span: SemanticSpan in row_data.spans if row_data != null else []:
		var card: Variant = (span.metadata as Dictionary).get("head_card") if span.metadata is Dictionary else null
		if card is Dictionary and str((card as Dictionary).get("id", "")) == card_id:
			return card
	return {}


## The variable names an Inspector section's strip holds, in order, "" when there is no such strip.
static func _section_members(rows: Array, uid_prefix: String) -> String:
	var strip: EventRowData = _row_with_uid(rows, uid_prefix)
	var names: PackedStringArray = PackedStringArray()
	for child: EventRowData in strip.children if strip != null else []:
		if child.source_resource is LocalVariable:
			names.append((child.source_resource as LocalVariable).name)
	return ", ".join(names)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("opened_script_head_test", label, actual, expected)
