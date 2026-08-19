# EventSheet - the object model proved against REAL lifted rows, not against strings a test made up.
# Everything here opens tests/fixtures/objects_reading_fixture.gd the way the dock opens a .gd (a
# read-only preview) and then asserts what the resulting rows SAY, what the census finds, and what
# the object popup answers with.
#
# The load-bearing assertion is the last one: the fixture must re-emit byte for byte. The whole
# object model is display-only, so a lens that ever changed the file would show up there first.
@tool
class_name ObjectModelTest
extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/objects_reading_fixture.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _autoloads_read_as_globals() and passed
	passed = _packs_read_as_behaviours() and passed
	passed = _census_lists_every_object() and passed
	passed = _object_popup_rows() and passed
	passed = _round_trip_is_byte_identical() and passed
	return passed


## Opens the fixture as the dock does: a read-only preview, which is reading mode.
static func _open() -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	sheet.read_only = true
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	return view


static func _sheet() -> EventSheetResource:
	return GDScriptImporter.new().import_external(FIXTURE_PATH)


## Every row's cells as "object|text" pairs, one entry per span - the same reading the render
## harness prints, so a value pinned here is a value you can see in the image.
static func _row_cells(view: EventSheetViewport) -> PackedStringArray:
	var cells: PackedStringArray = PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		_collect_cells(view, entry.get("row"), cells)
	return cells


static func _collect_cells(view: EventSheetViewport, row_data: EventRowData, cells: PackedStringArray) -> void:
	if row_data == null:
		return
	view._row_builder._ensure_event_spans(row_data)
	for span: SemanticSpan in row_data.spans:
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		cells.append("%s|%s" % [str(metadata.get("object_label", "")), span.text])
	for child: EventRowData in row_data.children:
		_collect_cells(view, child, cells)


static func _has_cell(cells: PackedStringArray, needle: String) -> bool:
	for cell: String in cells:
		if cell == needle:
			return true
	return false


## N4 - a row reaching through a registered autoload names the autoload in the object column, with
## its "(global)" note, and leaves the bare member in the sentence. Both lanes: the action lane
## reads it through the shared grammar, the condition lane through a definition's display template,
## and the two must agree.
static func _autoloads_read_as_globals() -> bool:
	var passed: bool = true
	var cells: PackedStringArray = _row_cells(_open())
	passed = _check("an autoload's step names the autoload and the bare member",
		_has_cell(cells, "EventForgeBridge (global)|Add 1 to score"), true) and passed
	passed = _check("an autoload's test names the autoload and the bare member",
		_has_cell(cells, "EventForgeBridge (global)|score > 100"), true) and passed
	passed = _check("a call on an autoload names the autoload",
		_has_cell(cells, "EventForgeBridge (global)|Reset"), true) and passed
	passed = _check("the owner is no longer buried in the sentence as a possessive",
		_has_cell(cells, "System|event forge bridge's score > 100"), false) and passed
	# The note is a reading, never a name: the census still knows the object as the singleton.
	passed = _check("the singleton's own name carries no note",
		EventSheetViewportReadingRows.global_object_label("EventForgeBridge",
			{"EventForgeBridge": "res://x.gd"}), "EventForgeBridge (global)") and passed
	passed = _check("a name that is not an autoload is returned untouched",
		EventSheetViewportReadingRows.global_object_label("Player",
			{"EventForgeBridge": "res://x.gd"}), "Player") and passed
	return passed


## N4 - a pack node mounted under the script's own node hands its rows to that object, with the
## pack's display name as the leading chip.
static func _packs_read_as_behaviours() -> bool:
	var passed: bool = true
	var cells: PackedStringArray = _row_cells(_open())
	passed = _check("a call on a pack node reads under the object, behind the pack's chip",
		_has_cell(cells, "ObjectsReadingFixture|Health  Take damage   3"), true) and passed
	passed = _check("a pack whose class name is not its display name still reads by display name",
		_has_cell(cells, "ObjectsReadingFixture|FPS Controller  Do jump"), true) and passed
	passed = _check("the pack node no longer stands in for the object",
		_has_cell(cells, "Health|Take damage   3"), false) and passed
	# The index is derived from the packs themselves, so a shipped pack is known by every name a
	# row could call it by - its class, its folder, and its own display name.
	var index: Dictionary = EventSheetViewportReadingRows.behaviour_pack_index()
	passed = _check("a pack is known by its folder name", str(index.get("Health", "")), "Health") and passed
	passed = _check("a pack is known by its class name",
		str(index.get("FPSController", "")), "FPS Controller") and passed
	passed = _check("a node that names no pack resolves to nothing",
		EventSheetViewportReadingRows.behaviour_pack_of("Sprite2D", {}), "") and passed
	return passed


## N10 - the census is every object the file uses, once each, in rail order.
static func _census_lists_every_object() -> bool:
	var passed: bool = true
	var census: Array = EventSheetViewportReadingRows.object_census(_sheet())
	var labels: PackedStringArray = PackedStringArray()
	var kinds: PackedStringArray = PackedStringArray()
	for entry: Dictionary in census:
		labels.append(str(entry.get("label", "")))
		kinds.append(str(entry.get("kind", "")))
	passed = _check("the rail lists every object the file uses, the script's own first",
		", ".join(labels),
		"ObjectsReadingFixture, hp_bar, Sprite2D, Health, FPSController, EventForgeBridge, enemies, HeadBullet") and passed
	passed = _check("each object is listed under the kind it is",
		", ".join(kinds),
		"script, node, node, behaviour, behaviour, autoload, group, scene") and passed
	# The notes are what a reader actually reads in the rail.
	var notes: Dictionary = {}
	for entry: Dictionary in census:
		notes[str(entry.get("label", ""))] = EventSheetViewportReadingRows.object_note(entry)
	passed = _check("the script's own object says so, with the class it is",
		str(notes.get("ObjectsReadingFixture", "")), "this script · CharacterBody2D") and passed
	passed = _check("a declared node says its path, its class and how many rows use it",
		str(notes.get("hp_bar", "")), "%HpBar · ProgressBar · 2 rows") and passed
	passed = _check("a behaviour says which pack it is",
		str(notes.get("Health", "")), "$Health · Health · 1 row") and passed
	passed = _check("an autoload says it is one",
		str(notes.get("EventForgeBridge", "")), "autoload (global) · 2 rows") and passed
	passed = _check("a group says it is one", str(notes.get("enemies", "")), "group · 1 row") and passed
	passed = _check("a preloaded scene is an object too",
		str(notes.get("HeadBullet", "")), "scene · 1 row") and passed
	# A doc comment that MENTIONS an object is prose, not use - the fixture's own header names one.
	passed = _check("a node named only in a comment is not an object",
		Array(labels).has("Node"), false) and passed
	return passed


## N10 - what the object popup answers with, and which of its buttons can do what it says.
static func _object_popup_rows() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = _sheet()
	var health: Dictionary = EventSheetObjectProperties.find_entry(sheet, "Health")
	var lines: PackedStringArray = PackedStringArray()
	for row: Dictionary in EventSheetObjectProperties.property_rows(health, "Player.tscn"):
		lines.append("%s=%s" % [str(row.get("label", "")), str(row.get("value", ""))])
	passed = _check("a behaviour's popup names the pack, the path with its scene, and the verbs used",
		" | ".join(lines),
		"Type=Health | Path=$Health in Player.tscn | Rows=Take damage · 1 row") and passed
	# An autoload is found by the name it READS under too - the "(global)" note is a reading, and a
	# click on the label must not fall through because the label wears it.
	var global_entry: Dictionary = EventSheetObjectProperties.find_entry(sheet, "EventForgeBridge (global)")
	passed = _check("an object label wearing its global note still finds its object",
		str(global_entry.get("label", "")), "EventForgeBridge") and passed
	passed = _check("an object the file no longer uses answers with nothing",
		EventSheetObjectProperties.find_entry(sheet, "NotHere").is_empty(), true) and passed
	# Select in scene only means something when there is a path AND a scene holding it.
	passed = _check("a node in a known scene can be selected there",
		EventSheetObjectProperties.can_select_in_scene(health, "Player.tscn"), true) and passed
	passed = _check("with no scene open there is nothing to select in",
		EventSheetObjectProperties.can_select_in_scene(health, ""), false) and passed
	passed = _check("a group is a name, not a node, so it cannot be selected in a scene",
		EventSheetObjectProperties.can_select_in_scene(
			EventSheetObjectProperties.find_entry(sheet, "enemies"), "Player.tscn"), false) and passed
	# The rail's own line for an entry, which is what the render shows.
	passed = _check("the rail line is the object's name and its note",
		EventSheetObjectsPanel.entry_text(health), "Health  $Health · Health · 1 row") and passed
	return passed


## The contract: everything above is display-only, so re-emitting the fixture untouched must
## reproduce it byte for byte.
static func _round_trip_is_byte_identical() -> bool:
	var original: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	var sheet: EventSheetResource = _sheet()
	var emitted: String = str(SheetCompiler.new().compile(sheet).get("output", ""))
	return _check("the fixture re-emits byte for byte", emitted, original)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] object model: %s" % label)
		return true
	print("[FAIL] object model: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
