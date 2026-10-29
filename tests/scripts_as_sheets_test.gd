@tool
extends RefCounted
# Godot EventSheets - a behaviour or a global opened as a sheet.
#
# Both are plain GDScript files, and opened as a sheet they read exactly in the order the file is
# written: the one head bar every sheet opens on, with a quiet kind word ("Behaviour", "Global
# (autoload)") where any other file says Script and no counts, and nothing the code does not have -
# no Settings / Verbs / How it works bands, no Helpers bar. Their facts and options are the card
# behind the file's name: the settings form, the script editor and the FileSystem. The toolbar
# carries a Sheet | Code | Side by side switch while one is open.
#
# Read off the shipped tree (the Sine pack is a behaviour; the Event Bus pack becomes a global the
# moment the project lists it as an autoload), and pinned by VALUE.

const SUPPORT := preload("res://tests/support.gd")
const P := "scripts_as_sheets_test"
const BEHAVIOUR := "res://eventsheet_addons/sine/sine_behavior.gd"
const GLOBAL := "res://eventsheet_addons/event_bus/event_bus_addon.gd"
const GLOBAL_SETTING := "autoload/EventBus"


static func run() -> bool:
	var passed: bool = true
	passed = _a_behaviour_reads_in_file_order() and passed
	passed = _a_global_says_what_it_is() and passed
	passed = _the_view_switch() and passed
	return passed


static func _a_behaviour_reads_in_file_order() -> bool:
	var rows: Array = _rows_of(BEHAVIOUR)
	var head: EventRowData = rows[0] if not rows.is_empty() else EventRowData.new()
	var name_span: SemanticSpan = _span_saying(head, "SineBehavior")
	var card: Dictionary = (name_span.metadata.get("head_card", {}) as Dictionary) if name_span != null else {}
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(BEHAVIOUR)
	return SUPPORT.pins(P, [
		["a pack's behaviour is read in file order", ViewportRowBuilder.reads_in_file_order(sheet), true],
		["it opens on its head bar: the name and that it is a behaviour", _words_of(head), "◆ SineBehavior Behaviour"],
		["one head bar, folding none of its lines away",
			[_uids_starting(rows, "sheet_head_bar_"), head.children.size()], [1, 0]],
		["no Helpers bar gathers its functions", _uids_starting(rows, "helpers_group_"), 0],
		["no Verbs band", _uids_starting(rows, "head_group_pack_verbs"), 0],
		["its host reads once, as the variable the file declares", [_uids_starting(rows, "sheet_head_host_"),
			rows.filter(func(row_data: EventRowData) -> bool:
				return row_data.source_resource is LocalVariable and (row_data.source_resource as LocalVariable).name == "host").size()],
			[0, 1]],
		["the functions read where the file has them, the last one last",
			_last_function_uid(rows), "define_fn_editor_preview_sample"],
		["the name's card says what it is and its facts",
			[str(card.get("subtitle", "")), str(Array(card.get("notes", [""]))[0])],
			["· Behaviour", "Works on Node2D · listed under Sine · 6 properties · 4 actions, 0 conditions, 0 triggers, 0 expressions"]],
		["and offers the file's options",
			Array(card.get("doors", [])), [["Behaviour settings…", "file_settings"],
				["Open in the script editor", "open_script_editor"], ["Show in FileSystem", "show_in_filesystem"]]],
		["any other script still says Script",
			ViewportRowBuilder.script_kind_word(EventSheetResource.new()), ""],
	])


static func _a_global_says_what_it_is() -> bool:
	var had: bool = ProjectSettings.has_setting(GLOBAL_SETTING)
	ProjectSettings.set_setting(GLOBAL_SETTING, "*" + GLOBAL)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(GLOBAL)
	var rows: Array = _rows_of(GLOBAL)
	if not had:
		ProjectSettings.set_setting(GLOBAL_SETTING, null)
	var head: EventRowData = rows[0] if not rows.is_empty() else EventRowData.new()
	return SUPPORT.pins(P, [
		["a global's kind word", ViewportRowBuilder.script_kind_word(sheet), "Global (autoload)"],
		["it opens on its head bar: the name and that it is a global", _words_of(head), "◆ EventBusPackAddon Global (autoload)"],
		["its Autoload entry is said in the name's hover, not as a row", _uids_starting(rows, "sheet_head_autoload"), 0],
		["the hover says how it loads",
			ViewportRowBuilder.script_facts_card(sheet).get_slice("\n", 1).get_slice(" · ", 0),
			"loaded before the first scene as EventBus"],
	])


static func _the_view_switch() -> bool:
	var switch: EventSheetPopupUI.ViewSwitch = EventSheetPopupUI.ViewSwitch.new()
	var heard: Array = []
	switch.view_chosen.connect(func(view: String) -> void: heard.append(view))
	var texts: Array = []
	for child: Node in switch.get_children():
		texts.append((child as Button).text)
	var rows: Array = [
		["it reads Sheet | Code | Side by side", texts, ["Sheet", "Code", "Side by side"]],
		["it opens on Sheet", switch.view, "sheet"],
	]
	(switch.buttons["both"] as Button).pressed.emit()
	rows.append(["pressing Side by side says so", heard, ["both"]])
	switch.choose("code", false)
	rows.append(["a quiet choice from code says nothing", heard, ["both"]])
	switch.free()
	# The dock: the toolbar carries the switch while a behaviour is open, and the three views are the
	# code panel and the rows shown, hidden or side by side.
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(BEHAVIOUR)
	sheet.read_only = true
	dock.setup(sheet)
	dock._refresh_title_strip()
	var dock_switch: Node = dock._toolbar.find_child("EventSheetViewSwitch", true, false)
	rows.append(["the toolbar carries the switch for a behaviour", dock_switch != null and (dock_switch as Control).visible, true])
	dock._code_panel_glue.set_sheet_view("code")
	rows.append(["Code shows the code and hides the rows", [dock.is_code_panel_visible(), dock._scroll.visible], [true, false]])
	dock._code_panel_glue.set_sheet_view("both")
	rows.append(["Side by side shows both", [dock.is_code_panel_visible(), dock._scroll.visible], [true, true]])
	dock._code_panel_glue.set_sheet_view("sheet")
	rows.append(["Sheet shows the rows alone", [dock.is_code_panel_visible(), dock._scroll.visible], [false, true]])
	dock.setup(EventSheetResource.new())
	dock._refresh_title_strip()
	# Every open sheet reads either way now, so a plain sheet keeps the switch too.
	rows.append(["a sheet that is neither keeps the switch", (dock_switch as Control).visible if dock_switch != null else false, true])
	dock.free()
	return SUPPORT.pins(P, rows)


# ── reading the shipped files ───────────────────────────────────────────────────────────────────


## One file opened the way opening it opens it: read-only, through the shipped row builder.
static func _rows_of(path: String) -> Array:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	if sheet == null:
		return []
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	var rows: Array = viewport._root_rows.duplicate()
	viewport.free()
	return rows


static func _words_of(row_data: EventRowData) -> String:
	var words: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		if not span.text.strip_edges().is_empty():
			words.append(span.text.strip_edges())
	return " ".join(words)


static func _span_saying(row_data: EventRowData, text: String) -> SemanticSpan:
	for span: SemanticSpan in row_data.spans:
		if span.text == text and span.metadata is Dictionary:
			return span
	return null


static func _uids_starting(rows: Array, prefix: String) -> int:
	var found: int = 0
	for row_data: EventRowData in rows:
		if row_data.row_uid.begins_with(prefix):
			found += 1
		found += _uids_starting(row_data.children, prefix)
	return found


static func _last_function_uid(rows: Array) -> String:
	var last: String = ""
	for row_data: EventRowData in rows:
		if row_data.row_uid.begins_with("define_fn_"):
			last = row_data.row_uid
	return last
