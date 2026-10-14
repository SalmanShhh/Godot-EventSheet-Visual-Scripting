@tool
extends RefCounted
# Godot EventSheets - the find windows say where a hit is and what they can do with it. The Command
# Palette's prefix modes are tabs (the pasted error line one of them), Find in Project names the
# event each match sits in, and Find Repeated Rows says why a run cannot become a function beside
# the greyed-out button, before it is pressed.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "find_windows_test"
const PALETTE_PATH := "res://addons/eventsheet/editor/dock/command_palette.gd"
const PROJECT_FIND_PATH := "res://addons/eventsheet/editor/dock/project_find.gd"


static func run() -> bool:
	var ok: bool = _palette_tabs()
	ok = _project_find_names_the_event() and ok
	ok = _repeated_rows_say_why() and ok
	return ok


static func _palette_tabs() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	var palette: RefCounted = load(PALETTE_PATH).new()
	palette.init(editor)
	palette._build_command_palette_window()
	palette._command_palette_search.text = "add"
	palette._choose_command_palette_mode(1)
	var typed_sheets: String = palette._command_palette_search.text
	palette._choose_command_palette_mode(2)
	var typed_symbols: String = palette._command_palette_search.text
	palette._choose_command_palette_mode(4)
	var waiting: Array = [palette._command_palette_search.text, palette._command_palette_tabs.current_tab,
		palette._command_palette_list.item_count]
	palette._refresh_command_palette("Error at res://player.gd:42")
	var pasted_tab: int = palette._command_palette_tabs.current_tab
	var ok: bool = SUPPORT.pins(NAME, [
		["a plain query is the Commands tab", palette.mode_of("add event"), 0],
		["# is the Sheets tab", palette.mode_of("#player"), 1],
		["@ is the Symbols tab", palette.mode_of("@speed"), 2],
		["? is the Docs tab", palette.mode_of("?tween"), 3],
		["a pasted error line is its own tab", palette.mode_of("E 0:00 res://player.gd:42 - boom"), 4],
		["clicking Sheets types its prefix before the words", typed_sheets, "#add"],
		["clicking Symbols swaps the prefix, keeping the words", typed_symbols, "@add"],
		["the Error line tab empties the field and waits for the paste", waiting, ["", 4, 0]],
		["a paste lands on the Error line tab", pasted_tab, 4],
		["the window runs with Run", palette._command_palette_window.ok_button_text, "Run"],
	])
	editor.free()
	return ok


static func _project_find_names_the_event() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var loose: CommentRow = CommentRow.new()
	loose.text = "tune zq_find_probe here"
	sheet.events.append(loose)
	for index: int in range(2):
		var event: EventRow = EventRow.new()
		event.event_uid = "probe_%d" % index
		var code: RawCodeRow = RawCodeRow.new()
		code.code = "print(%d)" % index if index == 0 else "velocity.x = zq_find_probe"
		event.actions.append(code)
		sheet.events.append(event)
	var script: GDScript = load(PROJECT_FIND_PATH)
	var found: Array = script.find_in_project("zq_find_" + "probe", PackedStringArray(),
		{"user://find_windows_probe.tres": sheet})
	var places: Array = found.map(func(entry: Dictionary) -> String: return script.where_in_sheet(entry))
	return SUPPORT.pins(NAME, [
		["each match names the event it sits in, by its margin number", places, ["-", "2"]],
		["a closed script's match names its line", script.where_in_sheet({"line": 7}), "line 7"],
	])


static func _repeated_rows_say_why() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	for site: int in range(2):
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnProcess"
		var local: LocalVariable = LocalVariable.new()
		local.name = "bonus"
		local.type_name = "int"
		event.local_variables.append(local)
		for text: String in ["bonus", "\"tail\""]:
			var action: ACEAction = ACEAction.new()
			action.provider_id = "Core"
			action.ace_id = "print"
			action.codegen_template = "print({text})"
			action.params = {"text": text}
			event.actions.append(action)
		sheet.events.append(event)
	editor.setup(sheet)
	var panel: EventSheetRepeatedRows = EventSheetRepeatedRows.new()
	panel.init(editor)
	panel.refresh()
	var before: Array = [panel.make_verb_button.disabled, panel.reason_note.visible]
	panel.tree.get_root().get_first_child().select(0)
	var ok: bool = SUPPORT.pins(NAME, [
		["nothing picked: the button waits and nothing is said", before, [true, false]],
		["a run that needs parameters keeps the button greyed", panel.make_verb_button.disabled, true],
		["…and says why beside it", panel.reason_note.visible, true],
		["the strip names the events the run sits in", panel.this_row.text, "Events 1, 2 run the same 2 action(s)."],
	])
	editor.free()
	return ok
