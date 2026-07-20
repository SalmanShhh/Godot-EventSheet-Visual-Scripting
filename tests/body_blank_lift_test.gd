# EventForge - blank-line-preserving reverse-lift INSIDE a function body (opened-file path).
#
# Idiomatic hand-written GDScript uses blank lines between statements to separate paragraphs of logic. Before
# this fix a single internal blank made _parse_body bail on the whole body, so the ENTIRE function reverted to
# a gray verbatim RawCode wall - a paragraph-formatted .gd opened as walls of code instead of events. The
# lifter now records each internal blank run and stamps it (transient meta __source_body_blanks) on the next
# body row/action; the compiler re-emits the exact spacing as truly-empty lines. So a normal documented
# function finally BECOMES clean condition/action rows, and the whole-file byte-verify still gates it (a shape
# that cannot reproduce degrades to today's verbatim wall, never a corrupted file).
@tool
class_name BodyBlankLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# The core win: a lifecycle body with a blank between two statements. Before the fix this reverted the
	# whole function to a raw wall (0 event rows); now it lifts to an OnReady event AND round-trips byte-exact.
	var p1: String = "extends Node\n\n\nfunc _ready() -> void:\n\thealth = 5\n\n\tvisible = true\n"
	ok = _check("single internal blank lifts to a structured body", _structured(p1), true) and ok
	ok = _check("single internal blank round-trips byte-identically", _roundtrip(p1), true) and ok

	# A run of TWO blanks between statements re-emits both empty lines.
	var p2: String = "extends Node\n\n\nfunc _ready() -> void:\n\ta_call()\n\n\n\tb_call()\n"
	ok = _check("two consecutive blanks lift", _structured(p2), true) and ok
	ok = _check("two consecutive blanks round-trip byte-identically", _roundtrip(p2), true) and ok

	# A blank BEFORE a nested block re-emits above the block's `if` header.
	var p3: String = "extends Node\n\n\nfunc _ready() -> void:\n\tx = 1\n\n\tif ready_flag:\n\t\ty = 2\n"
	ok = _check("blank before a nested if lifts", _structured(p3), true) and ok
	ok = _check("blank before a nested if round-trips byte-identically", _roundtrip(p3), true) and ok

	# A blank as the LAST line of a nested block belongs to the OUTER scope (it precedes the dedented
	# statement). The inner parser must rewind so the outer body owns and re-emits it - the trailing-blank case.
	var p4: String = "extends Node\n\n\nfunc _ready() -> void:\n\tif ready_flag:\n\t\ta_call()\n\n\tb_call()\n"
	ok = _check("blank at the end of a nested block lifts (outer owns it)", _structured(p4), true) and ok
	ok = _check("blank at the end of a nested block round-trips byte-identically", _roundtrip(p4), true) and ok

	# The abstraction win in full: a blank between two ACE-liftable statements (Set Property) reads as two
	# real action rows with spacing between them, not a code cell - and reproduces byte-for-byte.
	var p5: String = "extends Node\n\n\nfunc _ready() -> void:\n\tself.modulate = Color.RED\n\n\tself.visible = true\n"
	ok = _check("blank between two Set Property action rows lifts", _structured(p5), true) and ok
	ok = _check("blank between two Set Property action rows round-trips byte-identically", _roundtrip(p5), true) and ok

	# A hand-written helper function (lifts as a sheet EventFunction) with an internal blank.
	var p6: String = "extends Node\n\n\nfunc setup_world() -> void:\n\tvar a := 1\n\n\tvar b := 2\n"
	ok = _check("helper function with an internal blank lifts", _functions(p6) >= 1, true) and ok
	ok = _check("helper function with an internal blank round-trips byte-identically", _roundtrip(p6), true) and ok

	# Two lifecycle triggers, each with its own internal blank: the body counts are independent and none
	# leaks across the function boundary.
	var multi: String = "extends Node\n\n\nfunc _ready() -> void:\n\thealth = 5\n\n\tvisible = true\n\n\nfunc _process(delta: float) -> void:\n\trotation += delta\n\n\tposition.x += 1.0\n"
	ok = _check("multi-trigger with per-body blanks lifts both", _event_rows(multi) >= 2, true) and ok
	ok = _check("multi-trigger with per-body blanks round-trips byte-identically", _roundtrip(multi), true) and ok

	# The no-blank companion must behave EXACTLY as before (no meta stamped): still lifts, still round-trips.
	var control: String = "extends Node\n\n\nfunc _ready() -> void:\n\thealth = 5\n\tvisible = true\n"
	ok = _check("no-blank body still lifts", _structured(control), true) and ok
	ok = _check("no-blank body still round-trips byte-identically", _roundtrip(control), true) and ok

	# Fail-safe 1: a WHITESPACE-only "blank" line (a stray tab) can not reproduce as a truly-empty line, so the
	# body must degrade to the verbatim wall and still round-trip exactly - never corrupt the stray whitespace.
	var whitespace_blank: String = "extends Node\n\n\nfunc _ready() -> void:\n\ta_call()\n\t\n\tb_call()\n"
	ok = _check("whitespace-only blank degrades safely (verbatim round-trip)", _roundtrip(whitespace_blank), true) and ok

	# Fail-safe 2: a blank followed by an irreducible statement (no ACE, no template) still round-trips - the
	# body reverts to verbatim, preserving the source (including its blank) exactly. `flags |= 2` has no ACE.
	var irreducible: String = "extends Node\n\n\nfunc _ready() -> void:\n\tvisible = false\n\n\tflags |= 2\n"
	ok = _check("irreducible-after-blank body round-trips (verbatim fallback)", _roundtrip(irreducible), true) and ok

	# Exact re-emission pin (house rule: pin the VALUE, the exact string - not a count). The single-blank body
	# must re-emit character-for-character, blank line included.
	ok = _check("single-blank body re-emits the exact source string", _recompile(p1), p1) and ok

	return ok


## True when the import produced a STRUCTURED function (at least one lifted event or sheet function) with no
## `func …` verbatim wall left among the top-level rows - i.e. the body became rows, not a code cell.
static func _structured(source: String) -> bool:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var has_structure: bool = false
	if not imported.functions.is_empty():
		has_structure = true
	for row: Variant in imported.events:
		if row is EventRow:
			has_structure = true
		if row is RawCodeRow and (row as RawCodeRow).code.begins_with("func "):
			return false  # a verbatim function wall means the body did NOT lift
	return has_structure


## Number of lifted sheet functions (0 means helpers stayed raw blocks).
static func _functions(source: String) -> int:
	return GDScriptImporter.new().import_external_source(source).functions.size()


## Number of top-level EventRow rows (0 means the file reverted to raw blocks).
static func _event_rows(source: String) -> int:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var count: int = 0
	for row: Variant in imported.events:
		if row is EventRow:
			count += 1
	return count


## Import the source, recompile through the external path, and return the emitted text.
static func _recompile(source: String) -> String:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://body_blank_rt.gd"
	return str(SheetCompiler.compile(imported, "user://body_blank_rt.gd").get("output", ""))


## Whether the import + recompile reproduced the source byte-for-byte.
static func _roundtrip(source: String) -> bool:
	return _recompile(source) == source


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] body_blank_lift_test: %s" % label)
		return true
	print("[FAIL] body_blank_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
