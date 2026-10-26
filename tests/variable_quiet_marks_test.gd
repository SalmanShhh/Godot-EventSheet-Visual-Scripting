# EventForge - in the look a new user gets, a variable row reads `int beat = 0` with ONE mark (the
# Inspector eye); its `##` note and what its other marks would say move to the name's hover. Editor
# Native, which draws the note and the tiles, keeps them.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "variable_quiet_marks_test"
const CAROUSEL := "res://demo/showcase/carousel/showcase_carousel.gd"


static func run() -> bool:
	var quiet: Dictionary = _beat_row(true)
	var native: Dictionary = _beat_row(false)
	return SUPPORT.pins(P, [
		["the default look's route asks for the quiet marks", _default_route_quiet(), true],
		["beat wears one mark, the Inspector eye", quiet["badges"], PackedStringArray(["inspector"])],
		["and no trailing note", quiet["note"], ""],
		["its note is the name's hover", quiet["hover"].contains("Beats elapsed."), true],
		["what the range mark said is in the hover too",
			quiet["hover"].contains("Kept between limits in the Inspector (@export_range)."), true],
		["Editor Native keeps every tile", native["badges"], PackedStringArray(["inspector", "range", "tooltip"])],
		["and the trailing note", native["note"], "Beats elapsed."],
	])


static func _default_route_quiet() -> bool:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetEditorThemeDeriver.read_variables_inspector_style(style.get_event_style())
	return style.get_event_style().variable_quiet_marks


static func _beat_row(quiet: bool) -> Dictionary:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(CAROUSEL)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	style.get_event_style().inspector_variable_rows = true
	style.get_event_style().variable_quiet_marks = quiet
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var found: Dictionary = {"badges": PackedStringArray(), "note": "", "hover": ""}
	for row_data: EventRowData in view._root_rows:
		var is_beat: bool = false
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if bool(metadata.get("variable_name_span", false)) and span.text == "beat":
				is_beat = true
				found["badges"] = PackedStringArray(metadata.get("variable_badges", PackedStringArray()))
				found["hover"] = str(metadata.get("hover_note", ""))
		if not is_beat:
			continue
		for span: SemanticSpan in row_data.spans:
			if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("variable_doc_note", false)):
				found["note"] = span.text
		break
	view.free()
	return found
