# Godot EventSheets - a variable whose type the file never wrote reads `any`, and says it starts on
# nothing when no value is written. On an Inspector-style row a variable that spells the engine's own
# `Variant` keeps the word, and a typed one keeps its type.
@tool
class_name UntypedVariableReadingTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "untyped_variable_reading_test"


static func run() -> bool:
	var rows: Array = []
	for inspector_style: bool in [true, false]:
		var seen: Dictionary = _read(inspector_style)
		var look: String = "inspector rows" if inspector_style else "sentence rows"
		var types: Dictionary = seen["types"]
		var notes: Dictionary = seen["notes"]
		rows.append(["%s: an untyped variable reads any" % look, types.get("score", "(none)"), "any"])
		rows.append(["%s: the untyped blank variable says it has no starting value" % look, notes.get("score", false), true])
		rows.append(["%s: a variable with no type word at all reads any too" % look, types.get("bare", "(none)"), "any"])
		rows.append(["%s: a typed variable with a value has no such note" % look, notes.get("lives", false), false])
		if inspector_style:
			rows.append(["%s: a variable written as Variant keeps the word" % look, types.get("anything", "(none)"), "Variant"])
			rows.append(["%s: a typed variable keeps its type" % look, types.get("lives", "(none)"), "int"])
			rows.append(["%s: a Variant variable is not told it has none" % look, notes.get("anything", false), false])
	return SUPPORT.pins(P, rows)


static func _read(inspector_style: bool) -> Dictionary:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	style.get_event_style().inspector_variable_rows = inspector_style
	sheet.editor_style = style
	sheet.events.append(_variable("score", "Variant", null, true, true))
	sheet.events.append(_variable("bare", "", null, true))
	sheet.events.append(_variable("anything", "Variant", null, true))
	sheet.events.append(_variable("lives", "int", 3, false))
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var types: Dictionary = {}
	var notes: Dictionary = {}
	for entry: Variant in viewport.get_flat_rows():
		var row: EventRowData = (entry as Dictionary).get("row") as EventRowData
		if row == null:
			continue
		var owner_name: String = ""
		for span: EventSheetSemanticSpan in row.spans:
			if bool((span.metadata as Dictionary).get("variable_name_span", false)):
				owner_name = span.text
		if owner_name.is_empty():
			continue
		for span: EventSheetSemanticSpan in row.spans:
			if bool((span.metadata as Dictionary).get("variable_type_span", false)):
				types[owner_name] = span.text
			if span.text == "no starting value":
				notes[owner_name] = true
	editor.free()
	return {"types": types, "notes": notes}


static func _variable(name: String, type_name: String, value: Variant, blank: bool, untyped: bool = false) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = name
	variable.type_name = type_name
	variable.default_value = value
	variable.no_default = blank
	variable.untyped = untyped
	return variable
