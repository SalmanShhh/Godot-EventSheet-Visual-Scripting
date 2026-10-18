# Godot EventSheets - the Inspector Designer's "Shape this field" panel and its doors.
#
# A field is clicked in the Designer, and the panel beside it offers six kinds of choice, each tab
# naming the current one and listing only the options that fit the field's type. A choice is one
# rewrite of the lines that choice owns: choosing the default takes them out again, and the file is
# then byte for byte what it was. @tool comes and goes with Show when. Code typed by hand in the same
# shape reads back as the same choice; code in another shape is read, never rewritten.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P: String = "inspector_shape_test"
const SHAPE := preload("res://addons/eventsheet/editor/inspector_shape.gd")
const PANEL_PATH := "res://addons/eventsheet/editor/inspector_shape_panel.gd"
const GESTURES := preload("res://addons/eventsheet/editor/dock/variable_gestures.gd")
const LINK_PATH := "res://addons/eventsheet/editor/inspector/shape_link_inspector_plugin.gd"
const PROBE := "user://eventsheets_inspector_shape_probe.gd"
const ENEMY := "extends Resource\n\n@export_group(\"Stats\")\n@export var max_health: int = 100\n@export var has_shield: bool = true\n" \
	+ "@export var shield_amount: int = 3\n@export var attack: String = \"\"\n"


static func run() -> bool:
	var ok: bool = _options_fit_the_type()
	ok = _a_choice_rewrites_only_its_lines() and ok
	ok = _a_choice_says_what_else_it_moves() and ok
	ok = _show_when_brings_tool_and_takes_it_away() and ok
	ok = _the_panel() and ok
	ok = _the_designer() and ok
	ok = _a_click_never_frees_what_it_clicked() and ok
	ok = _the_designer_shows_groups_as_tabs() and ok
	ok = _hand_written_code() and ok
	ok = _the_doors() and ok
	ok = _a_shaped_script_still_loads_as_a_script() and ok
	return ok


static func _options_fit_the_type() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY)
	var entries: Array[Dictionary] = EventSheetInspectorDesignerDialog.collect_entries(sheet)
	var by_name: Dictionary = {}
	for entry: Dictionary in entries:
		by_name[entry["name"]] = entry
	var ids: Callable = func(category: String, var_name: String) -> Array:
		return SHAPE.options(category, by_name[var_name], entries).map(func(option: Dictionary) -> String: return str(option["id"]))
	var dialog_looks: Array = []
	for look: Dictionary in EventSheetInspectorLooks.for_type("int"):
		dialog_looks.append(str(look["id"]))
	var shape_looks: Array = SHAPE.options("look", by_name["max_health"], entries).filter(
		func(option: Dictionary) -> bool: return str(option["reason"]).is_empty() and str(option["id"]) != "default").map(
		func(option: Dictionary) -> String: return str(option["id"]))
	return SUPPORT.pins(P, [
		["a number can stay within limits but is never empty", ids.call("check", "max_health"), ["none", "clamp", "validate"]],
		["a word can be required", ids.call("check", "attack"), ["none", "required", "validate"]],
		["a field shows when a tick box of the script is on, never when it is its own",
			ids.call("show", "shield_amount"), ["always", "show_if:has_shield", "lock_unless:has_shield"]],
		["...and the tick box itself has no other tick box to follow", ids.call("show", "has_shield"), ["always", "show_if:"]],
		["the Look tab offers the Variable window's Inspector looks for the type", shape_looks, dialog_looks],
		["a bar stands on its defaults, a dropdown asks for its choices first",
			[SHAPE._stands_on_defaults("progress_bar", "int"), SHAPE._stands_on_defaults("number_choices", "int")], [true, false]],
		["every option says what it does", SHAPE.options("help", by_name["attack"], entries).map(func(option: Dictionary) -> String: return str(option["tip"])),
			["The ## comment above the variable, shown when hovering its name, as Godot does.",
				"A short sentence always shown above the field, for the one thing nobody should miss."]],
		["the groups show as sections or as tabs", SHAPE.group_styles().map(func(style: Dictionary) -> String: return str(style["id"])), ["sections", "tabs"]],
	])


## Each kind of choice writes its own lines, and its default takes exactly those lines out again.
static func _a_choice_rewrites_only_its_lines() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY)
	var rows: Array = [["the file opens and saves byte for byte", _emitted(sheet), ENEMY]]
	SHAPE.write(sheet, "max_health", "look", "progress_bar", {"max": "500"})
	var bar: String = _emitted(sheet)
	rows.append(["a bar with its limits is one line", _changed(ENEMY, bar),
		["@export var max_health: int = 100", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:500\") var max_health: int = 100"]])
	rows.append(["...and the panel shows the very line the file gets",
		bar.contains(SHAPE.code(sheet, "max_health", "look", "progress_bar")), true])
	SHAPE.write(sheet, "max_health", "check", "clamp")
	SHAPE.write(sheet, "attack", "help", "info", {"info": "Which attack it uses."})
	SHAPE.write(sheet, "attack", "check", "required")
	SHAPE.write(sheet, "attack", "button", "action", {"action": "pick_attack", "action_label": "Pick one"})
	var shaped: String = _emitted(sheet)
	rows.append(["a note, a must-fill and a button are three comment lines over the field",
		Array(shaped.substr(shaped.find("# @inspector_info")).split("\n").slice(0, 4)),
		["# @inspector_info Which attack it uses.", "# @inspector_required", "# @inspector_action pick_attack Pick one", "@export var attack: String = \"\""]])
	rows.append(["the file opens again as the same choices", _choices(_opened(shaped), "attack"), ["default", "group", "always", "required", "info", "action"]])
	rows.append(["...and saves byte for byte", _emitted(_opened(shaped)), shaped])
	for undo: Array in [["max_health", "check", "none"], ["attack", "button", "none"], ["attack", "check", "none"], ["attack", "help", "none"], ["max_health", "look", "default"]]:
		SHAPE.write(sheet, undo[0], undo[1], undo[2])
	rows.append(["choosing every default again gives back the file it was", _emitted(sheet), ENEMY])
	rows.append(["choosing what is already chosen changes nothing", SHAPE.write(sheet, "attack", "help", "none"), false])
	SHAPE.write_group_style(sheet, "tabs")
	SHAPE.write(sheet, "max_health", "layout", "side_by_side")
	SHAPE.write(sheet, "attack", "look", "function_choices", {"choices_function": "attack_names"})
	var shapes: String = _emitted(sheet)
	rows.append(["tabs, side by side and a list a function gives are one comment line each", _changed(ENEMY, shapes),
		["# @inspector_tabs", "# @inspector_side_by_side", "# @inspector_choices attack_names"]])
	rows.append(["...read back as the same choices", [SHAPE.group_style(_opened(shapes)), _choices(_opened(shapes), "max_health")[1], _choices(_opened(shapes), "attack")[0]],
		["tabs", "side_by_side", "function_choices"]])
	SHAPE.write_group_style(sheet, "sections")
	SHAPE.write(sheet, "max_health", "layout", "group")
	SHAPE.write(sheet, "attack", "look", "default")
	rows.append(["...and their defaults take them out again", _emitted(sheet), ENEMY])
	return SUPPORT.pins(P, rows)


## A choice that cannot keep another tab's choice says so before it is made: a look with no limits
## takes Stay within limits with it, and Side by side is refused where the pair would not share a line.
static func _a_choice_says_what_else_it_moves() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY)
	SHAPE.write(sheet, "max_health", "check", "clamp")
	var limited: Dictionary = _entry(sheet, "max_health")
	var warned: Array = SHAPE.options("look", limited, EventSheetInspectorDesignerDialog.collect_entries(sheet)).filter(
		func(option: Dictionary) -> bool: return str(option["tip"]).ends_with(" It also turns Stay within limits off on the Check tab: with no limits left, there is nothing to stay within.")).map(
		func(option: Dictionary) -> String: return str(option["id"]))
	var unlimited: Array = SHAPE.options("look", _entry(_opened(ENEMY), "max_health"), []).filter(
		func(option: Dictionary) -> bool: return str(option["tip"]).contains("Stay within limits"))
	SHAPE.write(sheet, "max_health", "look", "default")
	var after_look: String = SHAPE.chosen("check", _entry(sheet, "max_health"))
	var rows: Array = [
		["with limits kept, the looks that hold no limits say they take the check with them", warned,
			["default", "number_choices", "flags", "layers", "table_row", "custom", "storage"]],
		["...and with no check chosen no look says so", unlimited, []],
		["the plain number, chosen first, takes the check as it said", after_look, "none"],
		["...so No check after it has nothing left to take", SHAPE.write(sheet, "max_health", "check", "none"), false],
		["...and the file is the one it was", _emitted(sheet), ENEMY],
	]
	var pairs: EventSheetResource = _opened("extends Resource

@export_group(\"Stats\")
@export var min_damage: int = 4
"
		+ "@export var max_damage: int = 9
@export var armour: float = 0.5
@export_group(\"Loot\")
@export var drop_row: int = 1
"
		+ "@export var has_shield: bool = true
")
	var entries: Array[Dictionary] = EventSheetInspectorDesignerDialog.collect_entries(pairs)
	var reasons: Array = entries.map(func(entry: Dictionary) -> String: return str(SHAPE.options("layout", entry, entries)[1]["reason"]))
	rows.append(["side by side takes two numbers of one group, and says why anything else stays two lines", reasons, [
		"", "",
		"The next field, drop_row, starts another group, so the two sit under different headings.",
		"Only two numbers share a line; this field and has_shield are drawn one per line.",
		"No field is declared after this one to share its line."]])
	return SUPPORT.pins(P, rows)


static func _entry(sheet: EventSheetResource, var_name: String) -> Dictionary:
	for candidate: Dictionary in EventSheetInspectorDesignerDialog.collect_entries(sheet):
		if candidate["name"] == var_name:
			return candidate
	return {}


static func _show_when_brings_tool_and_takes_it_away() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY)
	SHAPE.write(sheet, "shield_amount", "show", "show_if:has_shield")
	var hidden: String = _emitted(sheet)
	SHAPE.write(sheet, "shield_amount", "show", "lock_unless:has_shield")
	var locked: String = _emitted(sheet)
	SHAPE.write(sheet, "shield_amount", "show", "always")
	var tool_sheet: EventSheetResource = _opened("@tool\n" + ENEMY)
	SHAPE.write(tool_sheet, "shield_amount", "show", "show_if:has_shield")
	SHAPE.write(tool_sheet, "shield_amount", "show", "always")
	return SUPPORT.pins(P, [
		["Show when makes the script a @tool script", hidden.begins_with("@tool\n"), true],
		["...the tick box refreshes the Inspector", hidden.contains("@export var has_shield: bool = true:\n\tset(value):\n\t\thas_shield = value\n\t\tnotify_property_list_changed()\n"), true],
		["...and Godot's own _validate_property hides the field",
			hidden.contains("func _validate_property(property: Dictionary) -> void:\n\tif str(property.name) == \"shield_amount\" and not bool(has_shield):\n\t\tproperty.usage &= ~PROPERTY_USAGE_EDITOR"), true],
		["the panel's code is the file's own lines", SHAPE.code(_opened(ENEMY), "shield_amount", "show", "show_if:has_shield").split("\n")[0], "@tool"],
		["changing it to read-only changes one line: the setter and @tool stay", _changed(hidden, locked),
			["\t\tproperty.usage &= ~PROPERTY_USAGE_EDITOR", "\t\tproperty.usage |= PROPERTY_USAGE_READ_ONLY"]],
		["Always takes every line back, @tool included", _emitted(sheet), ENEMY],
		["a sheet that was a @tool sheet keeps its @tool", _emitted(tool_sheet), "@tool\n" + ENEMY],
	])


static func _the_panel() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY)
	var entries: Array[Dictionary] = EventSheetInspectorDesignerDialog.collect_entries(sheet)
	var panel: VBoxContainer = load(PANEL_PATH).new()
	var heard: Array = []
	panel.chose.connect(func(category: String, option_id: String, answers: Dictionary) -> void: heard.append([category, option_id, answers]))
	panel.show_field(sheet, entries[2], entries, "show")
	var rows: Array = [["each tab names its kind and the choice on it", Array(panel.tab_texts()),
		["Look\nPlain number", "Layout\nIn its group", "Show when\nAlways", "Check\nNo check", "Help\nHover text only", "Button\nNo button"]]]
	panel.pick("show_if:has_shield")
	rows.append(["an option that stands on its own is chosen at the click", heard.duplicate(true), [["show", "show_if:has_shield", {}]]])
	heard.clear()
	panel.show_field(sheet, entries[2], entries, "help")
	panel.pick("info")
	rows.append(["a note asks for its sentence first", [heard.duplicate(true), panel.shown_code()],
		[[], "@export var shield_amount: int = 3"]])
	panel.answer({"info": ""})
	rows.append(["...refuses an empty one", [heard.duplicate(true), panel.ask_note()], [[], "Fill this in first: it is what the choice writes."]])
	panel.answer({"info": "Blocks this much from every hit."})
	rows.append(["...and is chosen with it", heard, [["help", "info", {"info": "Blocks this much from every hit."}]]])
	panel.free()
	return SUPPORT.pins(P, rows)


## The Designer: a click picks a field, a choice goes to the dock's handler and the field wears it.
static func _the_designer() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY)
	var designer: EventSheetInspectorDesignerDialog = EventSheetInspectorDesignerDialog.new()
	var heard: Array = []
	designer.wire_editing(func(_entry: Dictionary) -> void: pass, func(_name: String) -> void: pass, func() -> EventSheetResource: return sheet)
	designer.wire_shaping(func(var_name: String, category: String, option_id: String, answers: Dictionary) -> bool:
		heard.append([var_name, category, option_id])
		return SHAPE.write(sheet, var_name, category, option_id, answers))
	designer.open_for_sheet(sheet, "shield_amount", "show")
	var rows: Array = [["the door's field is the one picked", [designer.picked_field(), designer.shape_panel().category()], ["shield_amount", "show"]]]
	designer.shape_panel().pick("show_if:has_shield")
	rows.append(["a choice is handed to the dock once", heard, [["shield_amount", "show", "show_if:has_shield"]]])
	rows.append(["...and the field wears it when the Designer comes back", designer.shape_panel().chosen_option(), "show_if:has_shield"])
	designer.pick_field("attack")
	rows.append(["clicking another field picks it, on the same kind of choice", [designer.picked_field(), designer.shape_panel().category()], ["attack", "show"]])
	rows.append(["the groups show as sections", designer.groups_dropdown().get_item_text(designer.groups_dropdown().selected), "Sections"])
	designer.free()
	return SUPPORT.pins(P, rows)


## "Groups show as: Tabs" turns the Designer's own list into tabs too, as Godot's Inspector will draw it:
## a tab per group, only the open group's fields under it, and the tab follows the picked field.
static func _the_designer_shows_groups_as_tabs() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY + "@export_group(\"Loot\")\n@export var drop_row: int = 1\n")
	var designer: EventSheetInspectorDesignerDialog = EventSheetInspectorDesignerDialog.new()
	designer.wire_editing(func(_entry: Dictionary) -> void: pass, func(_name: String) -> void: pass, func() -> EventSheetResource: return sheet)
	designer.wire_shaping(func(var_name: String, category: String, option_id: String, answers: Dictionary) -> bool:
		if category == "groups":
			return SHAPE.write_group_style(sheet, option_id)
		return SHAPE.write(sheet, var_name, category, option_id, answers))
	designer.open_for_sheet(sheet, "max_health")
	var as_sections: Array = [designer.group_tabs(), Array(designer.shown_fields())]
	var groups: OptionButton = designer.groups_dropdown()
	for index: int in range(groups.item_count):
		if str(groups.get_item_metadata(index)) == "tabs":
			groups.select(index)
			groups.item_selected.emit(index)
	var as_tabs: Array = [designer.group_tabs(), Array(designer.shown_fields())]
	designer.pick_field("drop_row")
	designer.refresh()
	var on_loot: Array = [designer.group_tabs(), Array(designer.shown_fields())]
	designer.free()
	return SUPPORT.pins(P, [
		["groups shown as sections list every field, with no tabs", as_sections,
			[[], ["max_health", "has_shield", "shield_amount", "attack", "drop_row"]]],
		["as tabs: a tab per group, and only the open group's fields", as_tabs,
			[[["Stats", "Loot"], "Stats"], ["max_health", "has_shield", "shield_amount", "attack"]]],
		["...and the open tab follows the picked field", on_loot, [[["Stats", "Loot"], "Loot"], ["drop_row"]]],
	])


## A real click on an option row, on Choose, or on ▲ redraws the very control that was clicked. Freeing
## a control while it is still handling its own click fails in Godot ("Object is locked") and leaves
## it orphaned, so the choice waits until the click is handled: the control is still in place after it.
static func _a_click_never_frees_what_it_clicked() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY)
	var designer: EventSheetInspectorDesignerDialog = EventSheetInspectorDesignerDialog.new()
	var heard: Array = []
	designer.wire_editing(func(_entry: Dictionary) -> void: pass, func(var_name: String) -> void: heard.append(["up", var_name]),
		func() -> EventSheetResource: return sheet)
	designer.wire_shaping(func(var_name: String, category: String, option_id: String, answers: Dictionary) -> bool:
		heard.append([var_name, category, option_id])
		return SHAPE.write(sheet, var_name, category, option_id, answers))
	designer.open_for_sheet(sheet, "shield_amount", "show")
	var panel: VBoxContainer = designer.shape_panel()
	var list: Node = panel.get("_list")
	var row: Control = list.get_child(1) as Control
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	row.gui_input.emit(click)
	var after_row: Array = [is_instance_valid(row) and row.get_parent() == list, heard.duplicate()]
	designer.pick_field("shield_amount", "help")
	panel.pick("info")
	var asks: Node = panel.get("_asks")
	var choose: Button = asks.get_child(asks.get_child_count() - 1) as Button
	choose.pressed.emit()
	var after_choose: Array = [is_instance_valid(choose) and choose.get_parent() == asks, heard.duplicate()]
	var up: Button = null
	for button: Node in designer.find_children("*", "Button", true, false):
		if (button as Button).text == "▲" and not (button as Button).disabled:
			up = button as Button
	up.pressed.emit()
	var after_up: bool = is_instance_valid(up) and up.get_parent() != null
	designer.free()
	return SUPPORT.pins(P, [
		["a clicked option row is still in its list when the click is handled", after_row, [true, []]],
		["...and so is a pressed Choose", after_choose, [true, []]],
		["...and a pressed ▲", after_up, true],
	])


## Code typed by hand: the same shape reads as the same choice, another shape is the reader's own.
static func _hand_written_code() -> bool:
	var source: String = "@tool\nextends Resource\n\n@export var has_shield: bool = true:\n\tset(value):\n\t\thas_shield = value\n\t\tnotify_property_list_changed()\n" \
		+ "@export var shield_amount: int = 3\n@export var armour: int = 2\n\n" \
		+ "func _validate_property(property: Dictionary) -> void:\n\tif property.name == \"shield_amount\" and not has_shield:\n\t\tproperty.usage = PROPERTY_USAGE_NO_EDITOR\n" \
		+ "\tif property.name in [\"armour\"] and has_shield:\n\t\tproperty.usage |= PROPERTY_USAGE_READ_ONLY\n"
	var sheet: EventSheetResource = _opened(source)
	var reading: Dictionary = SHAPE.reading(sheet)
	var entries: Array[Dictionary] = EventSheetInspectorDesignerDialog.collect_entries(sheet)
	var panel: VBoxContainer = load(PANEL_PATH).new()
	panel.show_field(sheet, entries[1], entries, "show")
	var same_shape: Array = [panel.chosen_option(), panel.read_only()]
	panel.show_field(sheet, entries[2], entries, "look")
	var heard: Array = []
	panel.chose.connect(func(category: String, option_id: String, _answers: Dictionary) -> void: heard.append(option_id))
	panel.pick("slider")
	var own_shape: Array = [panel.read_only(), heard, panel.ask_note()]
	panel.free()
	return SUPPORT.pins(P, [
		["the file opens and saves byte for byte", _emitted(sheet), source],
		["a _validate_property written the same way reads as Show when", reading.get("shield_amount"), {"show": "show_if:has_shield"}],
		["...and the panel shows it chosen, read from the code", same_shape, ["show_if:has_shield", false]],
		["a field the code shapes some other way is the reader's own", reading.get("armour"), {"own": "_validate_property"}],
		["...read-only in the panel: nothing is rewritten behind the reader's back", own_shape,
			[true, [], "shaped by your own code: edit it in the script"]],
	])


static func _the_doors() -> bool:
	var sheet: EventSheetResource = _opened(ENEMY)
	var row: EventRowData = EventRowData.new()
	row.variable_row = true
	row.source_resource = GESTURES.member(sheet, "max_health")
	var span: SemanticSpan = SemanticSpan.new()
	span.metadata = {"kind": "variable", "variable_name": "max_health", "variable_scope": "tree"}
	row.spans.append(span)
	var script_path: String = "user://eventsheets_shape_link_enemy.gd"
	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	file.store_string("class_name ShapeLinkProbeStats\n" + ENEMY)
	file.close()
	var stats: Resource = Resource.new()
	stats.set_script(load(script_path))
	var plain: Resource = Resource.new()
	var addon_owned: Resource = Resource.new()
	addon_owned.set_script(load("res://addons/eventsheet/editor/inspector_looks.gd"))
	var link: GDScript = load(LINK_PATH)
	var undo: EventSheetEditorTest.FakeEditorUndoRedoManager = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(undo)
	dock.setup(_opened(ENEMY))
	row.source_resource = GESTURES.member(dock._current_sheet, "max_health")
	dock._variable_gestures.run_link("shape", row)
	var opened_on: String = dock._inspector_designer_dialog.picked_field()
	dock._designer_shape_field("shield_amount", "show", "show_if:has_shield", {})
	var shaped: String = _emitted(dock._current_sheet)
	var shield_row: EventRowData = EventRowData.new()
	shield_row.variable_row = true
	shield_row.source_resource = GESTURES.member(dock._current_sheet, "shield_amount")
	var shield_span: SemanticSpan = SemanticSpan.new()
	shield_span.metadata = {"kind": "variable", "variable_name": "shield_amount", "variable_scope": "tree"}
	shield_row.spans.append(shield_span)
	var shown_when: String = str(GESTURES.strip_for(shield_row, dock._current_sheet).get("text", ""))
	dock._designer_shape_field("shield_amount", "show", "lock_unless:has_shield", {})
	shield_row.source_resource = GESTURES.member(dock._current_sheet, "shield_amount")
	var locked_when: String = str(GESTURES.strip_for(shield_row, dock._current_sheet).get("text", ""))
	undo.undo()
	undo.undo()
	var undone: String = _emitted(dock._current_sheet)
	dock.free()
	return SUPPORT.pins(P, [
		["the strip's door opens the Designer with that field picked", opened_on, "max_health"],
		["a choice through the dock is ONE undo step, @tool and all", [shaped.begins_with("@tool\n"), undone], [true, ENEMY]],
		["the strip under a field shown only when a switch is on says so", shown_when, "shield_amount: shown only when has_shield is on."],
		["...and under one read-only while it is off", locked_when, "shield_amount: read-only when has_shield is off."],
		["a selected exported variable's strip offers the Designer first", Array(GESTURES.strip_for(row, sheet).get("links", [])), ["shape", "properties"]],
		["...in these words", GESTURES.link_label("shape"), "Shape in the Inspector…"],
		["a resource whose script is a sheet gets the link", link.sheet_for(stats), script_path],
		["...naming its class as the script does", link.link_text(stats), "Shape ShapeLinkProbeStats…"],
		["a resource with no script, or another addon's, is left to Godot", [link.sheet_for(plain), link.sheet_for(addon_owned)], ["", ""]],
	])


## Shape a field of a script, then make a resource of that script, the Godot way: the script's path
## still loads the script. The sheet open on it is a reading of the file, never the file's resource, so
## an edit through the undo funnel must not take the script's path over.
static func _a_shaped_script_still_loads_as_a_script() -> bool:
	var script_path: String = "user://eventsheets_shape_still_a_script.gd"
	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	file.store_string(ENEMY)
	file.close()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(script_path)
	var opened: String = dock._current_sheet_path
	dock._designer_shape_field("shield_amount", "show", "show_if:has_shield", {})
	var loaded: Resource = load(script_path)
	var stats: Resource = Resource.new()
	if loaded is Script:
		stats.set_script(loaded)
	var tabs_before: int = dock._open_tabs.size()
	dock.open_designer_for(script_path)
	var through_link: Array = [dock._open_tabs.size() - tabs_before, dock._current_sheet.has_meta(SHAPE.TOOL_META),
		_emitted(dock._current_sheet).begins_with("@tool\n")]
	dock.free()
	return SUPPORT.pins(P, [
		["the script is open as a sheet", opened, script_path],
		["the Inspector's link to a sheet already open shows that tab, edits and all, not a second read",
			through_link, [0, true, true]],
		["after a choice, its path still loads a script, not the sheet", loaded is Script, true],
		["...so a resource can still be given it", stats.get_script() == loaded, true],
	])


static func _choices(sheet: EventSheetResource, var_name: String) -> Array:
	var entry: Dictionary = {}
	for candidate: Dictionary in EventSheetInspectorDesignerDialog.collect_entries(sheet):
		if candidate["name"] == var_name:
			entry = candidate
	return Array(SHAPE.CATEGORIES).map(func(category: String) -> String: return SHAPE.chosen(category, entry))


## The lines of `before` that `after` lost, then the lines it gained, in order.
static func _changed(before: String, after: String) -> Array:
	var old: PackedStringArray = before.split("\n")
	var new: PackedStringArray = after.split("\n")
	var lost: Array = Array(old).filter(func(line: String) -> bool: return not new.has(line))
	var gained: Array = Array(new).filter(func(line: String) -> bool: return not old.has(line))
	return lost + gained


static func _opened(source: String) -> EventSheetResource:
	var file: FileAccess = FileAccess.open(PROBE, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	return GDScriptImporter.new().import_external(PROBE)


static func _emitted(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, PROBE).get("output", ""))
