# EventForge - a switch inside a function, as a user writes one: its head, its branches, the
# question a branch asks before it moves on, and the steps under that question, each read as the
# same line reads anywhere else on the sheet - object column first, never a bare line of code and
# never a trigger arrow on a question that is not a trigger.
@tool
class_name MatchBranchGuardsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "match_branch_guards_test"
const PATH: String = "res://tests/fixtures/match_branch_guards.gd"
const MEMBER_STEPS: String = "res://tests/fixtures/match_member_steps.gd"


static func run() -> bool:
	var source: String = FileAccess.get_file_as_string(PATH)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PATH)
	var output: String = str(SheetCompiler.compile(sheet, PATH).get("output", ""))
	var rows: PackedStringArray = _read_rows(PATH)
	return SUPPORT.pins(NAME, [
		["the file still comes back byte for byte", output, source],
		["the switch on its own line is a System line", _row_containing(rows, "match state"), "i1 [System> match state]"],
		["a branch states its test", _row_containing(rows, "is IDLE"), "i2 [state> is IDLE]"],
		["a branch's question names its object and reads in the sheet's words, its step names System",
			_row_containing(rows, "> 10"), "i3 [System> |velocity.x| > 10 | state> go to RUN]"],
		["a function the object answers reads as the object's own question, with no trigger arrow",
			_row_containing(rows, "Is on floor"), "i3 [match_branch_guards> Is on floor | state> go to IDLE]"],
		["no line under the switch is left without an object", _bare_lines(rows), PackedStringArray()],
	]) and _member_steps()


## A step that sets one of the object's own variables reads under the object, as the same line reads
## anywhere else on the sheet - never under System because it sits in a switch branch.
static func _member_steps() -> bool:
	var rows: PackedStringArray = _read_rows(MEMBER_STEPS)
	return SUPPORT.pins(NAME, [
		["the file still comes back byte for byte",
			str(SheetCompiler.compile(GDScriptImporter.new().import_external(MEMBER_STEPS), MEMBER_STEPS).get("output", "")),
			FileAccess.get_file_as_string(MEMBER_STEPS)],
		["a guarded branch's steps on the object's own variables name the object",
			_row_containing(rows, "wait_left ≤ 0"),
			"i2 [System> wait_left ≤ 0 | match_member_steps> Set direction to -direction | match_member_steps> Set wait_left to 2]"],
		["and so does an unguarded branch's step", _row_containing(rows, "is WALKING"), "i1 [System> mode is WALKING | match_member_steps> Subtract dt from wait_left]"],
	])


## Every row of an opened file as "i<indent> [<object>> <text> | ...]", the object column included,
## with the marks a line leads with (the trigger arrow, the red cross) spelled as words.
static func _read_rows(path: String) -> PackedStringArray:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
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
		viewport._row_builder._ensure_event_spans(row_data)
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			if span.text.strip_edges().is_empty() or str(span.metadata.get("kind", "")) == "add_action":
				continue
			var style: String = str(span.metadata.get("badge_style", ""))
			if style == "trigger":
				texts.append("<trigger>")
				continue
			if style == "negated":
				texts.append("<inverted>")
				continue
			var object_label: String = str(span.metadata.get("object_label", ""))
			texts.append(("%s> " % object_label if not object_label.is_empty() else "") + span.text)
		rows.append("i%d [%s]" % [row_data.indent, " | ".join(texts)])
	viewport.free()
	return rows


## The rows below the switch head with a cell that names no object.
static func _bare_lines(rows: PackedStringArray) -> PackedStringArray:
	var bare: PackedStringArray = PackedStringArray()
	var inside: bool = false
	for row: String in rows:
		if row.contains("match state"):
			inside = true
			continue
		if not inside:
			continue
		var cells: String = row.substr(row.find("[") + 1).trim_suffix("]")
		for cell: String in cells.split(" | "):
			if not cell.contains("> ") and not cell.begins_with("<"):
				bare.append(row)
				break
	return bare


static func _row_containing(rows: PackedStringArray, needle: String) -> String:
	for row: String in rows:
		if row.contains(needle):
			return row
	return "<no row contains %s>\n%s" % [needle, "\n".join(rows)]
