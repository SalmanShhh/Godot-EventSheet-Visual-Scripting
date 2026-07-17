# EventForge - multi-line enums lift into the enum BLOCK (user rule: a mappable construct never
# rests as a verbatim code blob; GDScript blocks are an explicit choice only). EnumRow.multiline
# + trailing_comma remember the written shape, the enum kind emits it back byte-exactly, and the
# importer's kind dispatch consumes the whole block into one editable row. Pins: emission per
# shape, the lift recovering members with explicit values + the comma style, a full-file
# round-trip, single-line behavior unchanged, and the shapes that must STILL refuse (space
# indentation, an unclosed block).
@tool
class_name MultilineEnumTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind("enum")
	ok = _check(ok, kind != null, "the enum kind is registered")

	# ---- emission: both shapes from the same row ----
	var enum_row: EnumRow = EnumRow.new()
	enum_row.enum_name = "State"
	enum_row.members = PackedStringArray(["IDLE", "RUN = 5", "HURT = 9"])
	ok = _check(ok, kind.emit_lines(enum_row) == PackedStringArray(["enum State { IDLE, RUN = 5, HURT = 9 }"]), "single-line shape unchanged")
	enum_row.multiline = true
	enum_row.trailing_comma = true
	ok = _check(ok, kind.emit_lines(enum_row) == PackedStringArray(["enum State {", "\tIDLE,", "\tRUN = 5,", "\tHURT = 9,", "}"]), "multi-line shape with trailing comma")
	enum_row.trailing_comma = false
	ok = _check(ok, kind.emit_lines(enum_row) == PackedStringArray(["enum State {", "\tIDLE,", "\tRUN = 5,", "\tHURT = 9", "}"]), "multi-line shape without trailing comma")

	# ---- the lift recovers shape, values, and comma style ----
	var source_lines: PackedStringArray = PackedStringArray(["enum Phase {", "\tINTRO,", "\tBOSS = 10,", "\tOUTRO,", "}"])
	var claim: Dictionary = kind.lift(source_lines, 0)
	ok = _check(ok, int(claim.get("consumed", 0)) == 5, "the whole block is consumed (got %s)" % str(claim.get("consumed")))
	var lifted: EnumRow = claim.get("resource") as EnumRow
	ok = _check(ok, lifted != null and lifted.multiline and lifted.trailing_comma, "shape flags recovered")
	ok = _check(ok, lifted != null and lifted.members == PackedStringArray(["INTRO", "BOSS = 10", "OUTRO"]), "members keep explicit values (got %s)" % (str(lifted.members) if lifted != null else "<none>"))

	var no_trailing: Dictionary = kind.lift(PackedStringArray(["enum Tier {", "\tFREE,", "\tPRO", "}"]), 0)
	var no_trailing_row: EnumRow = no_trailing.get("resource") as EnumRow
	ok = _check(ok, no_trailing_row != null and not no_trailing_row.trailing_comma, "the no-trailing-comma style is remembered")

	# ---- refusals: shapes the emitter can't reproduce stay verbatim ----
	ok = _check(ok, kind.lift(PackedStringArray(["enum Bad {", "    SPACES,", "}"]), 0).is_empty(), "space indentation refuses (stays a code block)")
	ok = _check(ok, kind.lift(PackedStringArray(["enum Open {", "\tA,"]), 0).is_empty(), "an unclosed block refuses")

	# ---- the covenant: a whole script holding a multi-line enum round-trips AND re-lifts ----
	var source: String = "\n".join(PackedStringArray([
		"class_name MlEnumFixture",
		"extends Node",
		"",
		"enum State {",
		"\tIDLE,",
		"\tRUN = 5,",
		"\tHURT = 9,",
		"}",
		"",
		"var mode: int = State.IDLE",
		""
	]))
	ok = _check(ok, EventSheets.round_trips(source), "a file with a multi-line enum round-trips byte-exactly")
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(source)
	var found: EnumRow = null
	for entry: Variant in sheet.events:
		if entry is EnumRow:
			found = entry as EnumRow
	ok = _check(ok, found != null and found.multiline and found.enum_name == "State", "the opened file carries an editable enum BLOCK, not a code blob")

	return ok


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
