# Godot EventSheets - what an opened script says about ITSELF: how much of it reads as events, what
# its settings are limited to, and whether it is the project's global.
#
# Three readings ship here and each is pinned by VALUE, because a count would pass just as happily
# with the wrong words in the right shape:
#
#   P3  THE READING-COVERAGE CHIP. The share of an opened file that arrived as rows, and how many
#       script blocks the rest sits in. The number is measured by EventSheetReadingCoverage, which
#       is ALSO what tests/handwritten_lift_gate_test.gd measures with - so the last check here
#       pins that the chip's number and the gate's entry point agree on the same file. Two
#       implementations of "what still reads as code" would drift the moment either learned a new
#       row shape, and the gate would go on passing while the chip told a reader something else.
#
#   P7  THE INSPECTOR FACTS ON A SETTING ROW. A range and its step, an enum as a combo chip reading
#       its LABEL rather than its number, a 0-1 range as a percent, a file filter, a folder, a
#       multiline note, a colour with its word, and flags with their names. Read from what the
#       importer already stored, over a REAL hinted file rather than a hand-built sheet.
#
#   P10 AN AUTOLOAD READS AS THE PROJECT'S GLOBAL. Its Include bar says so, its knobs collapse into
#       one Global variables folder (on a global there is nothing for a second folder to mean), its
#       triggers say "this global fires", and the Objects rail names it the same way.
#
# And the covenant under all three: every word of it is a lens, so both fixtures still re-emit
# byte-identically.
@tool
class_name OpenedScriptFactsTest
extends RefCounted

const SETTINGS_PATH := "res://tests/fixtures/opened_script_settings.gd"
const COVERAGE_PATH := "res://tests/fixtures/opened_script_coverage.gd"
const PLAYER_PATH := "res://tests/fixtures/opened_script_head_player.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_coverage_chip() and ok
	ok = _test_parse_errors() and ok
	ok = _test_setting_facts() and ok
	ok = _test_autoload_head() and ok
	ok = _test_objects_rail() and ok
	ok = _test_round_trip() and ok
	return ok


# ── P3 ──


static func _test_coverage_chip() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet(COVERAGE_PATH)
	var coverage: Dictionary = EventSheetReadingCoverage.measure(sheet)
	ok = _check("the lines that stayed script blocks are counted", int(coverage.get("block_lines", -1)), 4) and ok
	ok = _check("and so are the blocks they sit in", int(coverage.get("block_rows", -1)), 2) and ok
	ok = _check("the share that reads as events is floored, never rounded up",
		int(coverage.get("percent", -1)), 73) and ok
	ok = _check("the chip says both halves in the sheet's words",
		EventSheetReadingCoverage.chip_text(sheet), "73% reads as events · 2 script blocks ▸") and ok
	ok = _check("and the chip is on the Include bar",
		_texts(_row_at(_open(COVERAGE_PATH).get_flat_rows(), 0)),
		"⇥ | CoverageSample | a | Node2D | · opened_script_coverage.gd | 73% reads as events · 2 script blocks ▸") and ok

	# The walk the click follows: the same blocks, in file order, so a click always lands on
	# something the chip actually counted.
	var blocks: Array[RawCodeRow] = EventSheetReadingCoverage.script_blocks(sheet)
	ok = _check("the click walks exactly the blocks the chip counted", blocks.size(), 2) and ok
	ok = _check("in file order",
		blocks[0].code.strip_edges().split("\n")[0] if not blocks.is_empty() else "",
		"@export var target: Node2D") and ok

	# A file that lifted completely drops the number: "100% reads as events, 0 script blocks" is a
	# sentence with nothing in it, and a reader would rightly wonder what the 0 was for.
	var lifted: EventSheetResource = _sheet(SETTINGS_PATH)
	ok = _check("a fully-lifted file just says the good news",
		EventSheetReadingCoverage.chip_text(lifted), "reads as events") and ok
	ok = _check("...and has no blocks to walk",
		EventSheetReadingCoverage.script_blocks(lifted).size(), 0) and ok

	# THE AGREEMENT. `block_line_count` is the entry point the corpus gate calls; `measure` is what
	# the chip shows. Same file, same number, one implementation.
	var walked: int = EventSheetReadingCoverage.block_line_count(sheet.events, true)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			walked += EventSheetReadingCoverage.block_line_count((function_entry as EventFunction).events, false)
	ok = _check("the chip's measure and the corpus gate's are the same number",
		walked, int(coverage.get("block_lines", -1))) and ok
	return ok


## The engine's own parse errors, mapped to the head: how many, and what they cost. A script that
## does not parse does not run, and saying so is worth more than any styling.
static func _test_parse_errors() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet(COVERAGE_PATH)
	ok = _check("a file that compiles says nothing about errors",
		EventSheetReadingCoverage.parse_error_text(sheet), "") and ok
	sheet.set_meta("__parse_errors", [
		{"line": 4, "message": "Identifier \"max_hp\" not declared in the current scope."},
		{"line": 9, "message": "Unexpected \"Indent\" in class body."}
	])
	ok = _check("two errors read as two, and say what it costs",
		EventSheetReadingCoverage.parse_error_text(sheet),
		"2 errors - the game will not run this script") and ok
	sheet.set_meta("__parse_errors", [{"line": 4, "message": "boom"}])
	ok = _check("and one reads as one",
		EventSheetReadingCoverage.parse_error_text(sheet),
		"1 error - the game will not run this script") and ok
	return ok


# ── P7 ──


static func _test_setting_facts() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(SETTINGS_PATH)
	var rows: Array = view.get_flat_rows()
	var movement: EventRowData = _bar_titled(rows, "Movement")
	var look: EventRowData = _bar_titled(rows, "Look")
	ok = _check("the two settings folders were found", movement != null and look != null, true) and ok
	if movement == null or look == null:
		view.free()
		return false
	ok = _check("a range says its limits and its step",
		_texts(movement.children[0]),
		"Instance number | speed | Inspector | = | 5 | 0 to 20, step 0.5 | How fast it walks, in pixels per second.") and ok
	ok = _check("a fixed set of choices is a combo, reading its label instead of its number",
		_texts(movement.children[1]), "Instance combo | mode | Inspector | = | Walk | Walk / Run / Fly") and ok
	ok = _check("a 0-to-1 range reads as a percent",
		_texts(movement.children[2]), "Instance number | grip | Inspector | = | 50%") and ok
	ok = _check("a file knob says it is a file, and what it accepts",
		_texts(look.children[0]), "Instance file | portrait | Inspector | = | \"\" | *.png") and ok
	ok = _check("a directory knob says folder",
		_texts(look.children[1]), "Instance folder | shot_folder | Inspector | = | \"\"") and ok
	ok = _check("a multiline text knob says so",
		_texts(look.children[2]), "Instance text | intro_text | Inspector | = | \"\" | multiline") and ok
	ok = _check("a colour reads as its word",
		_texts(look.children[3]), "Instance color | tint | Inspector | = | white | #ffffff") and ok
	ok = _check("and it carries the swatch that IS the fact",
		_swatch(look.children[3]), Color.WHITE) and ok
	ok = _check("a bit field says flags, and names the bits",
		_texts(look.children[4]), "Instance flags | elements | Inspector | = | 0 | Fire / Water / Wind") and ok

	# The facts themselves, at the seam - so a caller other than the row builder reads the same.
	var colour_variable := LocalVariable.new()
	colour_variable.type_name = "Color"
	colour_variable.default_value = "Color(0.2, 0.4, 0.3, 1)"
	colour_variable.expression_default = true
	ok = _check("a colour nobody has a word for reads as its hex",
		str(EventSheetSettingFacts.facts(colour_variable).get("value_text", "")), "#33664d") and ok
	ok = _check("black is a word", EventSheetSettingFacts.colour_word(Color.BLACK), "black") and ok
	ok = _check("and an odd green is not", EventSheetSettingFacts.colour_word(Color(0.31, 0.44, 0.29)), "") and ok
	view.free()
	return ok


# ── P10 ──


static func _test_autoload_head() -> bool:
	var ok: bool = true
	var view: EventSheetViewport = _open(SETTINGS_PATH, true)
	var rows: Array = view.get_flat_rows()
	ok = _check("an autoload's Include bar names the singleton and says what that means",
		_texts(_row_at(rows, 0)),
		"⇥ | Game | autoload (global) · opened_script_settings.gd | reads as events") and ok
	var globals: EventRowData = _bar_titled(rows, "Global variables")
	ok = _check("its knobs read as ONE Global variables folder", globals != null, true) and ok
	ok = _check("holding every one of them", globals.children.size() if globals != null else -1, 8) and ok
	ok = _check("and the per-group / Instance variables split is gone",
		_bar_titled(rows, "Movement") == null and _bar_titled(rows, "Instance variables") == null, true) and ok
	view.free()

	var firing: EventSheetViewport = _open(PLAYER_PATH, true)
	ok = _check("a global's triggers say a GLOBAL fires them",
		_texts(_bar_titled(firing.get_flat_rows(), "Triggers")), "Triggers | this global fires - 3") and ok
	firing.free()
	return ok


## The rail answers "what is in this file" - and when the file IS the project's global, it says so
## about the file itself, in the same words its Include bar and every other sheet's rows use for it.
static func _test_objects_rail() -> bool:
	var ok: bool = true
	var panel := EventSheetObjectsPanel.new()
	panel.set_sheet(_sheet(SETTINGS_PATH, true))
	var entries: Array = panel.entries()
	ok = _check("the rail lists the global itself", entries.is_empty(), false) and ok
	if not entries.is_empty():
		ok = _check("under the singleton's own name, as a global",
			EventSheetObjectsPanel.entry_text(entries[0] as Dictionary), "Game  autoload (global) · Node2D · 1 row") and ok
	# An ordinary script is untouched by any of that.
	var plain := EventSheetObjectsPanel.new()
	plain.set_sheet(_sheet(SETTINGS_PATH))
	var plain_entries: Array = plain.entries()
	ok = _check("an ordinary script still reads as itself",
		EventSheetObjectsPanel.entry_text(plain_entries[0] as Dictionary) if not plain_entries.is_empty() else "",
		"TunedKnobs  this script · Node2D") and ok
	panel.free()
	plain.free()
	return ok


## The covenant: all of it is a lens. The bytes are untouched.
static func _test_round_trip() -> bool:
	var ok: bool = true
	for path: String in [SETTINGS_PATH, COVERAGE_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		var view: EventSheetViewport = _open(path)
		var reemitted: String = str(SheetCompiler.compile(view._sheet, path).get("output", ""))
		ok = _check("%s still re-emits byte-identically" % path.get_file(), reemitted == source, true) and ok
		view.free()
	return ok


# ── Helpers ──


static func _sheet(path: String, as_autoload: bool = false) -> EventSheetResource:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	if as_autoload:
		# The importer reads this off ProjectSettings; the fixture is not registered as an autoload
		# (registering one would change the project for every other test), so the sheet is told
		# what a registered file's import would have told it.
		sheet.autoload_mode = true
		sheet.autoload_name = "Game"
	return sheet


static func _open(path: String, as_autoload: bool = false) -> EventSheetViewport:
	var sheet: EventSheetResource = _sheet(path, as_autoload)
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


static func _swatch(row_data: EventRowData) -> Variant:
	if row_data == null:
		return null
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary and (span.metadata as Dictionary).get("swatch_color") is Color:
			return (span.metadata as Dictionary)["swatch_color"]
	return null


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
		print("[PASS] opened_script_facts_test: %s" % label)
		return true
	print("[FAIL] opened_script_facts_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
