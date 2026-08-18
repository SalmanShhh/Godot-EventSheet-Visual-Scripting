# EventSheet - the reading lenses proved against REAL lifted rows, not against strings a test
# made up. Everything here opens tests/fixtures/reading_lenses_fixture.gd the way the dock opens
# a .gd (a read-only preview) and then asserts what the resulting rows SAY.
#
# The load-bearing assertion is the last one: the fixture must re-emit byte for byte. Every lens
# in this file is display-only, so a lens that ever changed the file would show up there first.
@tool
class_name ReadingLensesRowsTest
extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/reading_lenses_fixture.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _reading_rows() and passed
	passed = _editing_rows() and passed
	passed = _round_trip_is_byte_identical() and passed
	passed = _guide_lines() and passed
	return passed


## Opens the fixture as the dock does: a read-only preview, which is reading mode.
static func _open(reading: bool) -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	sheet.read_only = reading
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(reading)
	return view


## Every row's text, one string per row, with each row's spans joined - the same reading the
## render harness prints, so a value pinned here is a value you can see in the image.
static func _row_texts(view: EventSheetViewport) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		view._row_builder._ensure_event_spans(row_data)
		var parts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			parts.append(span.text)
		texts.append(" | ".join(parts))
	return texts


static func _any_row_contains(texts: PackedStringArray, needle: String) -> bool:
	for text: String in texts:
		if text.contains(needle):
			return true
	return false


## M9, M10, M12, M16, M17, M20 on the rows the importer actually produced.
static func _reading_rows() -> bool:
	var passed: bool = true
	var view: EventSheetViewport = _open(true)
	var texts: PackedStringArray = _row_texts(view)

	# M9 - the private state var and the @export knob both read as words, with the knob taking
	# Godot's Inspector capitalisation.
	passed = _check("reading mode turns the humanized-names lens on",
		view.humanize_names_enabled(), true) and passed
	passed = _check("a private state var reads as words",
		_any_row_contains(texts, "coyote timer"), true) and passed
	passed = _check("the raw identifier is gone from the sentence",
		_any_row_contains(texts, "_coyote_timer ="), false) and passed

	# M10 - the property chain in the call arguments reads possessively.
	passed = _check("a property chain reads possessively",
		_any_row_contains(texts, "velocity X"), true) and passed

	# M12 - the inverted condition shows the mark, and the sentence lost the word.
	passed = _check("an inverted condition draws the mark", _any_row_contains(texts, "✕"), true) and passed
	passed = _check("an inverted condition's sentence drops the word not",
		_any_row_contains(texts, "not is_on_floor"), false) and passed

	# M16 - the call to the fixture's own add_look reads Construct's way, with the parameter
	# names supplying the argument labels.
	passed = _check("a known call reads Functions > Call", _any_row_contains(texts, "Call Add Look"), true) and passed
	passed = _check("call arguments are named by the parameters",
		_any_row_contains(texts, "x = velocity X"), true) and passed

	# M20 - the @onready node reference is an object declaration, not a variable row.
	passed = _check("an @onready node reads as an Object declaration",
		_any_row_contains(texts, "Object | hp_bar"), true) and passed
	passed = _check("the object declaration names its node", _any_row_contains(texts, "%HpBar"), true) and passed
	passed = _check("the object declaration names its class", _any_row_contains(texts, "ProgressBar"), true) and passed
	view.free()
	return passed


## The same file opened for AUTHORING keeps the raw names and the editable row shapes: the lenses
## must not leak into the surface where the rows are edited.
static func _editing_rows() -> bool:
	var passed: bool = true
	var view: EventSheetViewport = _open(false)
	var texts: PackedStringArray = _row_texts(view)
	passed = _check("an editable sheet leaves the humanized-names lens off",
		view.humanize_names_enabled(), false) and passed
	passed = _check("an editable sheet keeps the raw identifier",
		_any_row_contains(texts, "_coyote_timer"), true) and passed
	passed = _check("an editable sheet does not turn a variable into an Object row",
		_any_row_contains(texts, "Object | hp_bar"), false) and passed

	# M9's toggle is a real override in both directions: turning it ON while authoring works.
	view.humanize_names_override = 1
	passed = _check("the View toggle turns the lens on while authoring",
		view.humanize_names_enabled(), true) and passed
	view.humanize_names_override = 0
	view.set_reading_mode(true)
	passed = _check("the View toggle turns the lens off while reading",
		view.humanize_names_enabled(), false) and passed
	view.free()
	return passed


## The contract under every lens above: display-only means the bytes never move.
static func _round_trip_is_byte_identical() -> bool:
	var source: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	var compiled: Dictionary = SheetCompiler.new().compile(sheet)
	return _check("the fixture re-emits byte for byte", str(compiled.get("output", "")), source)


## M15 - the connector is geometry only: its trunks sit on the indent stops the layout already
## applied, and it reserves no width of its own.
static func _guide_lines() -> bool:
	var passed: bool = true
	var row_rect := Rect2(0.0, 0.0, 400.0, 28.0)
	passed = _check("a top-level row has no trunk to draw",
		EventSheetViewportGuideLines.trunk_x(row_rect, 0),
		float(EventSheetPalette.GUTTER_WIDTH) + 2.0) and passed
	passed = _check("each level steps by exactly one indent",
		EventSheetViewportGuideLines.trunk_x(row_rect, 2) - EventSheetViewportGuideLines.trunk_x(row_rect, 1),
		float(EventSheetPalette.INDENT_WIDTH)) and passed
	# Density shortens the elbow and nothing else, so a compact sheet keeps the same trunks.
	EventSheetPalette.set_row_density(1.0)
	var comfortable_reach: float = EventSheetViewportGuideLines.elbow_reach()
	EventSheetPalette.set_row_density(EventSheetPalette.COMPACT_ROW_DENSITY)
	var compact_reach: float = EventSheetViewportGuideLines.elbow_reach()
	var compact_trunk: float = EventSheetViewportGuideLines.trunk_x(row_rect, 1)
	EventSheetPalette.set_row_density(1.0)
	passed = _check("compact density shortens the elbow", compact_reach < comfortable_reach, true) and passed
	passed = _check("compact density leaves the trunk where the indent put it",
		compact_trunk, EventSheetViewportGuideLines.trunk_x(row_rect, 1)) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_lenses_rows_test: %s" % label)
		return true
	print("[FAIL] reading_lenses_rows_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
