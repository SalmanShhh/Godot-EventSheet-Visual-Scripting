@tool
extends RefCounted
# Godot EventSheets - the quiet class head (the theme's inspector_class_head)
#
# A theme that heads the sheet as the Inspector heads a script draws ONE class head card - the icon,
# the bold name, the kind, "· extends" and the base, the share mark and who includes a shared sheet,
# the attached scene at the right - with no code echo, no "change…" word, no rows for the scene's
# facts and no "+ add" row. The pins hold:
#   1. the token is off by default, on in the Editor Native starter and its rule, and stated off in
#      every other shipped theme;
#   2. the card's words, paint and gestures on a shared sheet, and the same sheet in Classic Sheet
#      reading exactly as before;
#   3. the scene's facts (a sheet's spawns) leaving the canvas for the scene's hover, the scene's
#      click showing the file, and a fact that is a problem keeping its row.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_class_head_test"
const SHARED_BASE := "res://tests/fixtures/shared_sheets/fixture_damage_rules.gd"
const SHOOTER := "res://demo/showcase/platformer_shooter/platformer_shooter.gd"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const THEME_FOLDERS: PackedStringArray = ["res://addons/eventsheet/themes", "res://demo/themes"]
const NativeHeadMarks := preload("res://addons/eventsheet/editor/interaction/native_head_marks.gd")
const RowBuilder := preload("res://addons/eventsheet/editor/interaction/viewport_row_builder.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_token() and ok
	ok = _test_shared_sheet_card() and ok
	ok = _test_scene_facts() and ok
	return ok


static func _test_token() -> bool:
	var others: Array = []
	for folder: String in THEME_FOLDERS:
		for file_name: String in DirAccess.get_files_at(folder):
			var path: String = folder.path_join(file_name)
			if not file_name.ends_with("_theme.tres") or path == NATIVE_THEME:
				continue
			var text: String = FileAccess.get_file_as_string(path)
			if text.contains("inspector_variable_rows"):
				others.append([file_name, text.contains("inspector_class_head = false")])
	var all_off: bool = true
	for entry: Array in others:
		all_off = all_off and bool(entry[1])
	var built: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE)
	return SUPPORT.pins(TEST_NAME, [
		["off by default", EventSheetEventStyle.new().inspector_class_head, false],
		["the starter states it on",
			(load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style().inspector_class_head, true],
		["and so does the rule it is built by", built.get_event_style().inspector_class_head, true],
		["every other shipped theme states it off", [others.size() >= 11, all_off], [true, true]],
	])


static func _test_shared_sheet_card() -> bool:
	NativeHeadMarks.forget_includers()
	var native_view: EventSheetViewport = _view_of(SHARED_BASE, NATIVE_THEME)
	var head: EventRowData = _row_with_uid(native_view, "sheet_head_name_")
	var description: EventRowData = _row_with_uid(native_view, "sheet_head_description_")
	var event_style: EventSheetEventStyle = native_view.get_event_style()
	var name_segments: Array = _flag_of(head, "FixtureDamageRules", "bbcode_segments")
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the card reads the class, the kind, the base, the mark and who includes it - no code, no change…",
			_texts(head), "▣ | FixtureDamageRules | Script | · extends | Node | ⇆ | Included by Fixture Includer"],
		["the card's paint: the head grey inside a one-pixel edge, rounded like an event card",
			[head.custom_color, head.outline_color, head.outline_radius, head.outline_width],
			[event_style.head_bar_color, event_style.row_border_color, float(event_style.event_corner_radius), 1.0]],
		["the name is the one bold word", bool(name_segments[0]["bold"]), true],
		["the kind and the extends words change what kind of script it is",
			[_flag_of(head, "Script", "head_action"), _flag_of(head, "· extends", "head_action"),
				_flag_of(head, "Node", "head_action")], ["extends", "extends", "extends"]],
		["their hover says so", _flag_of(head, "· extends", "hover_note"),
			"Click to change what kind of script it is."],
		["the base is said in the faint colour", _flag_of(head, "Node", "text_color"),
			native_view._get_reading_style().muted_text_color],
		["who includes it is the italic aside", _flag_of(head, "Included by", "italic_note"), true],
		["the description keeps its line, without an echo or a wash",
			[_texts(description), description.custom_color.a],
			["## | A shared event sheet wired as the base: its events run in every script that extends it.", 0.0]],
		["no + add row", _row_with_uid(native_view, "sheet_head_add_") == null, true],
	])
	native_view.free()
	var classic_view: EventSheetViewport = _view_of(SHARED_BASE, CLASSIC_THEME)
	result = SUPPORT.pins(TEST_NAME, [
		["Classic Sheet keeps the band stack word for word",
			_texts(_row_with_uid(classic_view, "sheet_head_name_")),
			"▣ | FixtureDamageRules | Script | · extends | Node | change… | ⇆ | Included by Fixture Includer | class_name FixtureDamageRules"],
		["and its + add row", _texts(_row_with_uid(classic_view, "sheet_head_add_")), "+ add: icon · @tool · states"],
	]) and result
	classic_view.free()
	return result


static func _test_scene_facts() -> bool:
	var native_view: EventSheetViewport = _view_of(SHOOTER, NATIVE_THEME)
	var head: EventRowData = _row_with_uid(native_view, "sheet_head_name_")
	var spawns_left: bool = _row_with_uid(native_view, "sheet_head_spawns") == null
	native_view.free()
	var classic_view: EventSheetViewport = _view_of(SHOOTER, CLASSIC_THEME)
	var classic_spawns: String = _texts(_row_with_uid(classic_view, "sheet_head_spawns"))
	classic_view.free()
	return SUPPORT.pins(TEST_NAME, [
		["the head of a spawning sheet is the card alone", _texts(head),
			"▣ | PlatformerShooter | Script | · extends | Node2D | Scene | platformer_shooter.tscn"],
		["its spawns rows leave the canvas", spawns_left, true],
		["and are said in the scene's hover", _flag_of(head, "platformer_shooter.tscn", "hover_note"),
			"The scene this script is attached to.\nspawns shot.tscn\nspawns target.tscn"],
		["a click on the scene shows the file", _flag_of(head, "platformer_shooter.tscn", "head_action"),
			"spawns:res://demo/showcase/platformer_shooter/platformer_shooter.tscn"],
		["Classic Sheet keeps the spawns rows", classic_spawns.begins_with("spawns | shot.tscn | browse the scene | var "),
			true],
		["only a scene fact with nothing wrong moves to the hover",
			[RowBuilder.head_band_moves_to_hover({"kind": "spawns", "warning": false}),
				RowBuilder.head_band_moves_to_hover({"kind": "collisions", "warning": true}),
				RowBuilder.head_band_moves_to_hover({"kind": "description", "warning": false})],
			[true, false, false]],
	])


static func _view_of(path: String, theme_path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = false
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	return view


static func _row_with_uid(view: EventSheetViewport, prefix: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return row_data
	return null


static func _flag_of(row_data: EventRowData, prefix: String, key: String) -> Variant:
	for span: SemanticSpan in row_data.spans if row_data != null else []:
		if span.text.begins_with(prefix):
			return (span.metadata as Dictionary).get(key)
	return null


static func _texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(span.text)
	return " | ".join(parts)
