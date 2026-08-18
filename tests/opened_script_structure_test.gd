# EventSheet - the STRUCTURE an opened script is organised with, proved against real lifted rows.
#
# Four readings, all display-only over an unchanged file:
#   - `#region` / `#endregion` reads as a group bar, and nests.
#   - a comment whose text is a statement reads as a switched-off row; prose stays a note.
#   - a repeating Timer, and a while-true-await loop, both read as the beat they are.
#   - a base script of this project reads as an Include bar, and `super` as calling its verb.
#
# The load-bearing assertion is the last one: the fixture must re-emit byte for byte, which is what
# proves every reading above is a lens rather than an edit. The authoring half (a group added to a
# .gd writes the fences, and reopens as the same bar) is checked separately, on a temp file.
@tool
class_name OpenedScriptStructureTest
extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/opened_script_structure_fixture.gd"
const BASE_PATH := "res://tests/fixtures/opened_script_structure_base.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _region_groups() and passed
	passed = _disabled_comments() and passed
	passed = _every_x_seconds() and passed
	passed = _include_bar_and_super() and passed
	passed = _region_authoring_round_trip() and passed
	passed = _round_trip_is_byte_identical() and passed
	return passed


## Opens the fixture the way the dock opens a .gd: a read-only preview, which is reading mode.
static func _open() -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	sheet.read_only = true
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	return view


## Every row's text, one string per row, spans joined - the same reading the render harness prints,
## so a value pinned here is a value that can be seen in the image. Children are walked too.
static func _row_texts(view: EventSheetViewport) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		_collect_row_texts(view, entry.get("row"), texts)
	return texts


static func _collect_row_texts(view: EventSheetViewport, row_data: EventRowData, texts: PackedStringArray) -> void:
	if row_data == null:
		return
	view._row_builder._ensure_event_spans(row_data)
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(span.text)
	texts.append(" | ".join(parts))
	for child: EventRowData in row_data.children:
		_collect_row_texts(view, child, texts)


static func _first_row_containing(view: EventSheetViewport, needle: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var found: EventRowData = _find_row(view, entry.get("row"), needle)
		if found != null:
			return found
	return null


static func _find_row(view: EventSheetViewport, row_data: EventRowData, needle: String) -> EventRowData:
	if row_data == null:
		return null
	view._row_builder._ensure_event_spans(row_data)
	for span: SemanticSpan in row_data.spans:
		if span.text.contains(needle):
			return row_data
	for child: EventRowData in row_data.children:
		var found: EventRowData = _find_row(view, child, needle)
		if found != null:
			return found
	return null


static func _any_row_contains(texts: PackedStringArray, needle: String) -> bool:
	for text: String in texts:
		if text.contains(needle):
			return true
	return false


## N1 - the two fence lines read as one group bar carrying the name and a count, and a region
## written inside another region nests inside its bar.
static func _region_groups() -> bool:
	var passed: bool = true
	var view: EventSheetViewport = _open()
	var texts: PackedStringArray = _row_texts(view)
	passed = _check("a region reads as a named group bar with its count",
		_any_row_contains(texts, "Movement | 2 events"), true) and passed
	passed = _check("a one-event region counts in the singular",
		_any_row_contains(texts, "Combat | 1 event"), true) and passed
	var movement: EventRowData = _first_row_containing(view, "Movement")
	passed = _check("the bar wears the group row type",
		movement != null and movement.row_type == EventRowData.RowType.GROUP, true) and passed
	# The nested region is a CHILD of the one around it, never a sibling.
	var combat: EventRowData = _first_row_containing(view, "Combat")
	var nested_found: bool = false
	if combat != null:
		for child: EventRowData in combat.children:
			if _find_row(view, child, "Death") != null:
				nested_found = true
	passed = _check("a region inside a region nests inside its bar", nested_found, true) and passed
	view.free()
	return passed


## N2 - a comment that is a statement reads as a switched-off row; a comment that is prose does not.
static func _disabled_comments() -> bool:
	var passed: bool = true
	var view: EventSheetViewport = _open()
	var texts: PackedStringArray = _row_texts(view)
	passed = _check("a commented-out assignment reads as a switched-off row",
		_any_row_contains(texts, "disabled | Set x to 0"), true) and passed
	passed = _check("a commented-out branch reads as a switched-off row",
		_any_row_contains(texts, "disabled | if hp <= 0: hp = 10"), true) and passed
	passed = _check("prose keeps its own words", _any_row_contains(texts, "TODO: add coyote time"), true) and passed
	passed = _check("prose is not called disabled",
		_any_row_contains(texts, "disabled | TODO"), false) and passed
	# The classifier itself, at its edges: an assignment-shaped SENTENCE is still a sentence.
	passed = _check("a statement is recognised as code",
		CommentRow.code_text("velocity.x = 0.0"), "velocity.x = 0.0") and passed
	passed = _check("a call is recognised as code", CommentRow.code_text("die()"), "die()") and passed
	passed = _check("a sentence with an equals sign is not code",
		CommentRow.code_text("Speed = how fast the player runs"), "") and passed
	passed = _check("a note is not code", CommentRow.code_text("the player is hit here"), "") and passed
	# The switch itself: what the enable/disable gesture reads off an action row. A comment holding a
	# statement hands back the line to uncomment; a note and a real action hand back nothing.
	var note := CommentRow.new()
	note.text = "hp = 0"
	passed = _check("a code comment offers its line back",
		ViewportRowBuilder.commented_out_code(note), "hp = 0") and passed
	var prose := CommentRow.new()
	prose.text = "the player is hit here"
	passed = _check("a note offers nothing to switch on",
		ViewportRowBuilder.commented_out_code(prose), "") and passed
	var live := RawCodeRow.new()
	live.code = "hp = 0"
	passed = _check("a live statement is not a switched-off row",
		ViewportRowBuilder.commented_out_code(live), "") and passed
	view.free()
	return passed


## N3 - both spellings of a repeating beat, and the one-shot Timer that is not one.
static func _every_x_seconds() -> bool:
	var passed: bool = true
	var view: EventSheetViewport = _open()
	var texts: PackedStringArray = _row_texts(view)
	passed = _check("a repeating Timer's handler reads as the beat",
		_any_row_contains(texts, "Every 2 seconds (SpawnTimer)"), true) and passed
	passed = _check("a one-shot Timer's handler keeps On Timeout",
		_any_row_contains(texts, "On Timeout"), true) and passed
	passed = _check("a while-true await loop reads as the beat",
		_any_row_contains(texts, "Every 0.5 seconds"), true) and passed
	passed = _check("the await beat says it only runs while the loop does",
		_any_row_contains(texts, "(while running)"), true) and passed
	# The loop reader on its own: only the exact repeating shape claims a body.
	passed = _check("a plain helper is not a beat",
		ViewportRowBuilder.await_loop_seconds("func helper() -> void:\n\thp += 1"), "") and passed
	view.free()
	return passed


## N12 - the base script reads as an Include bar, and `super` as calling that include.
static func _include_bar_and_super() -> bool:
	var passed: bool = true
	var view: EventSheetViewport = _open()
	var texts: PackedStringArray = _row_texts(view)
	passed = _check("the head names the base script as an include",
		_any_row_contains(texts, "Include | opened_script_structure_base.gd | - open as a sheet"), true) and passed
	passed = _check("super._ready() runs the include's own trigger",
		_any_row_contains(texts, "▸ run its On Ready"), true) and passed
	passed = _check("super.take_damage(x) calls the include's verb",
		_any_row_contains(texts, "▸ Call Take Damage  amount"), true) and passed
	# The bar carries the path it opens, which is what makes clicking it a jump.
	var include_row: EventRowData = _first_row_containing(view, "open as a sheet")
	var carried_path: String = ""
	if include_row != null:
		for span: SemanticSpan in include_row.spans:
			if span.metadata is Dictionary and (span.metadata as Dictionary).has("include_path"):
				carried_path = str((span.metadata as Dictionary)["include_path"])
	passed = _check("the include bar carries the file it opens", carried_path, BASE_PATH) and passed
	# The class-name spelling of the same thing resolves through the project's own class list.
	var by_class := EventSheetResource.new()
	by_class.host_class = "OpenedScriptStructureBase"
	passed = _check("extends <ProjectClass> resolves to its file",
		ViewportRowBuilder.base_script_path(by_class), BASE_PATH) and passed
	var engine_base := EventSheetResource.new()
	engine_base.host_class = "Node2D"
	passed = _check("extends <EngineClass> is no include",
		ViewportRowBuilder.base_script_path(engine_base), "") and passed
	view.free()
	return passed


## N1 authoring symmetry: a group added to a .gd sheet is written as the fence pair, and the file
## reopens with that same bar - the round trip a person actually makes.
static func _region_authoring_round_trip() -> bool:
	var authored_path: String = "user://eventsheets_region_authoring.gd"
	var source: String = "extends Node\n\n\nfunc _ready() -> void:\n\tpass\n"
	var writer: FileAccess = FileAccess.open(authored_path, FileAccess.WRITE)
	writer.store_string(source)
	writer.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(authored_path)
	var opener := CustomBlockRow.new()
	opener.kind_id = "region"
	opener.fields = {"label": "Setup", "is_end": false}
	var closer := CustomBlockRow.new()
	closer.kind_id = "region"
	closer.fields = {"label": "", "is_end": true}
	sheet.events.insert(0, opener)
	sheet.events.insert(sheet.events.size(), closer)
	var written: String = str(SheetCompiler.new().compile(sheet, authored_path).get("output", ""))
	var passed: bool = true
	passed = _check("a group on a .gd sheet writes the opening fence",
		written.contains("#region Setup"), true) and passed
	passed = _check("a group on a .gd sheet writes the closing fence",
		written.contains("#endregion"), true) and passed
	# Reopened, the fences are the same bar again - which is what "the group survived" means.
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(authored_path)
	reopened.read_only = true
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(reopened)
	view.set_reading_mode(true)
	passed = _check("the authored group reopens as its bar",
		_any_row_contains(_row_texts(view), "Setup"), true) and passed
	view.free()
	return passed


## The contract under every reading above: display-only means the bytes never move.
static func _round_trip_is_byte_identical() -> bool:
	var source: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	var compiled: Dictionary = SheetCompiler.new().compile(sheet)
	return _check("the fixture re-emits byte for byte", str(compiled.get("output", "")), source)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] opened_script_structure_test: %s" % label)
		return true
	print("[FAIL] opened_script_structure_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
