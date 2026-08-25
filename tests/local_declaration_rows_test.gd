# EventForge - A LOCAL READS WHERE THE SHEET DECLARES ONE: AT THE TOP OF ITS EVENT.
#
# An event sheet declares a local at the top of the event that owns it and fills it in with an
# action, so a `var` line inside a body reads as those rows - the declaration up with the event's
# other locals, and, when the value has to be WORKED OUT, a `System ▸ Set x to …` action where the
# line actually sits. A line whose value already is a value needs no action and gets none.
#
# Display only: the row addresses the very statement it came from, and the file is untouched - which
# is what the byte check at the end of every case is for.
@tool
class_name LocalDeclarationRowsTest
extends RefCounted

const SOURCE_PATH: String = "user://eventforge_local_declaration_rows.gd"

const SOURCE: String = """extends Node

signal hit(damage: int)


func _on_hit(damage: int) -> void:
	var dealt: float = damage * 2
	var tag: String = name
	var hits := 3
	var label := "ready"
	hp -= dealt
"""


static func run() -> bool:
	var ok: bool = true
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var rows: Array = _rows(sheet)

	# ── The declaration rows, at the top of the event that owns them ──
	ok = _check("a worked-out number declares with the number's own starting value",
		_reading(rows, "dealt"), "Local number | dealt | = 0") and ok
	ok = _check("a worked-out text declares empty",
		_reading(rows, "tag"), "Local text | tag | = \"\"") and ok
	ok = _check("a value that is already a value rides on the declaration",
		_reading(rows, "hits"), "Local number | hits | = 3") and ok
	ok = _check("and so does a piece of text",
		_reading(rows, "label"), "Local text | label | = \"ready\"") and ok

	# ── The work stays where the line is, as the Set action it is ──
	var actions: PackedStringArray = _action_readings(rows)
	ok = _check("the work reads as the sheet's Set action",
		actions.has("System> Set dealt to damage * 2"), true) and ok
	ok = _check("and the same for the text",
		actions.has("System> Set tag to name"), true) and ok
	ok = _check("a declaration that needs no work leaves no action line behind",
		actions.has("System> Set hits to 3"), false) and ok

	# ── The file never moves ──
	ok = _check("reading it this way changes no byte",
		str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", "")), SOURCE) and ok
	ok = _authored_rows() and ok
	return ok


## An AUTHORED sheet reads the same way, and its declaration row still addresses the very action it
## came from - which is what keeps clicking, dragging and the row menu working on it.
static func _authored_rows() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.actions.append(_action("SetLocalVarTyped", {"name": "spare", "var_type": "int", "value": "2"}))
	event_row.actions.append(_action("SetLocalVarTyped", {"name": "total", "var_type": "float", "value": "spare"}))
	sheet.events.append(event_row)
	var rows: Array = _rows(sheet, false)
	ok = _check("an authored local reads as the same declaration row",
		_reading(rows, "spare"), "Local number | spare | = 2") and ok
	ok = _check("an authored local whose value is worked out declares empty-handed",
		_reading(rows, "total"), "Local number | total | = 0") and ok
	ok = _check("the declaration row is owned by its event",
		_row_for(rows, "total").get("owned", false), true) and ok
	ok = _check("and its spans point at that one action",
		_row_for(rows, "total").get("ace_index", -1), 1) and ok
	ok = _check("the work still reads where the line is",
		_action_readings(rows).has("System> Set total to spare"), true) and ok
	return ok


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] local_declaration_rows_test: %s" % label)
		return true
	print("[FAIL] local_declaration_rows_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## Every row of the sheet as {"uid", "text", "action_texts", "owned", "ace_index"}, spans built.
static func _rows(sheet: EventSheetResource, read_only: bool = true) -> Array:
	sheet.read_only = read_only
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var found: Array = []
	_walk(viewport._root_rows, viewport, found)
	viewport.free()
	return found


static func _walk(rows: Array, viewport: EventSheetViewport, found: Array) -> void:
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		var parts: PackedStringArray = PackedStringArray()
		var action_texts: PackedStringArray = PackedStringArray()
		var ace_index: int = -1
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			parts.append(span.text)
			var label: String = str(metadata.get("object_label", ""))
			if not label.is_empty():
				action_texts.append("%s> %s" % [label, span.text])
			if ace_index < 0:
				ace_index = int(metadata.get("ace_index", -1))
		found.append({
			"uid": row_data.row_uid,
			"text": " | ".join(parts),
			"action_texts": action_texts,
			"owned": row_data.source_resource is EventRow,
			"ace_index": ace_index
		})
		_walk(row_data.children, viewport, found)


## The declaration row that names `variable_name`, as {} when the reading holds none.
static func _row_for(rows: Array, variable_name: String) -> Dictionary:
	for row: Variant in rows:
		if not str((row as Dictionary).get("uid", "")).begins_with("local_declaration_"):
			continue
		var parts: PackedStringArray = str((row as Dictionary).get("text", "")).split(" | ")
		if parts.size() > 1 and parts[1] == variable_name:
			return row
	return {}


static func _reading(rows: Array, variable_name: String) -> String:
	return str(_row_for(rows, variable_name).get("text", ""))


## Every action cell of the whole sheet, as "Object> text".
static func _action_readings(rows: Array) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for row: Variant in rows:
		texts.append_array((row as Dictionary).get("action_texts", PackedStringArray()))
	return texts
