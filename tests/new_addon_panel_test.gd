# Godot EventSheets - the New behaviour and New global forms, and the Properties and actions window.
#
# The forms ask the familiar questions as described dropdowns, keep the chosen choice's sentence in
# view, say a name problem while it is typed, and only offer copies that fit (packs made for the same
# kind of object, or meant to be an autoload). Turning a global on is its row in Godot's own
# Project Settings > Globals > Autoload. The window lists what a sheet offers from the sheet itself.
@tool
class_name NewAddonPanelTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MEMBERS := preload("res://addons/eventsheet/editor/dock/own_members_window.gd")


static func run() -> bool:
	var ok: bool = true
	var host: Control = Control.new()
	var panel: EventSheetNewAddonPanel = EventSheetNewAddonPanel.new()
	panel.init(host)
	panel.open()
	ok = _check("a behaviour form asks what it works on, CharacterBody2D first offered",
		panel._kind_option.get_item_text(panel._kind_option.selected), "CharacterBody2D") and ok
	ok = _check("and keeps that choice's sentence in view under it",
		(panel._kind_option.get_parent().get_child(1) as Label).text,
		"A 2D character moved by code: it gets velocity and move_and_slide(), the usual choice for walking, patrolling, jumping.") and ok
	ok = _check("an empty name says nothing yet", panel._name_note.text, "") and ok
	panel._name_edit.text = "Node"
	panel._name_edit.text_changed.emit("Node")
	ok = _check("a clashing name is said as it is typed", panel._name_note.text,
		"\"Node\" can't be a name here - use letters, digits and underscores, starting with a letter, and not the name of a class that already exists.") and ok
	panel._name_edit.text = "FreshlyNamedThing"
	panel._name_edit.text_changed.emit("FreshlyNamedThing")
	ok = _check("a usable name clears it", panel._name_note.visible, false) and ok
	ok = _check("the line under the form says what Create makes", panel._path_label.text,
		"Makes res://eventsheet_addons/freshly_named_thing/freshly_named_thing.gd and opens it as a sheet.") and ok
	var starts: Array = _items(panel._start_option)
	ok = SUPPORT.pins("new_addon_panel_test", [
		["starts with Empty", starts[0], "Empty"],
		["offers copies of the packs made for a CharacterBody2D", starts.has("Copy of Platformer Movement"), true],
		["and none made for another kind", starts.has("Copy of Bullet"), false],
		["ends with the two ways from your own script", starts.slice(-2), ["From a script I wrote", "From the selected node"]],
	]) and ok
	panel._kind_option.select(1)
	panel._kind_option.item_selected.emit(1)
	ok = _check("changing what it works on changes the copies", _items(panel._start_option).has("Copy of Bullet"), true) and ok
	ok = _check("a shelf names the packs already on it", panel._shelf_option.get_item_tooltip(panel._shelf_option.selected).begins_with("Listed with "), true) and ok

	panel.open(true)
	ok = SUPPORT.pins("new_addon_panel_test", [
		["a global form asks script or scene", _items(panel._kind_option), ["Script", "Scene"]],
		["its picker heading leads with its own name", panel._shelf_option.get_item_text(0), "Its own name"],
		["it offers copies of the packs meant to be an autoload", _items(panel._start_option).has("Copy of Event Bus"), true],
		["and the global you already have", _items(panel._start_option).back(), "From an autoload I already have"],
	]) and ok
	ProjectSettings.set_setting("autoload/ZzPanelGlobal", "*res://zz_panel_global.gd")
	ok = _check("a global cannot take an autoload's name", EventSheetNewAddonPanel.name_problem("ZzPanelGlobal", true),
		"Project Settings > Globals already has an autoload called ZzPanelGlobal - pick another name.") and ok
	ProjectSettings.set_setting("autoload/ZzPanelGlobal", null)

	# Turning a global on and off is its row in Project Settings > Globals > Autoload.
	EventSheetNewAddonPanel.set_global_on("ZzPanelGlobal", "res://zz_panel_global.gd", true)
	ok = _check("on writes the autoload row", ProjectSettings.get_setting("autoload/ZzPanelGlobal", ""), "*res://zz_panel_global.gd") and ok
	ok = _check("which the window reads back", MEMBERS.global_name_for("res://zz_panel_global.gd"), "ZzPanelGlobal") and ok
	EventSheetNewAddonPanel.set_global_on("ZzPanelGlobal", "res://zz_panel_global.gd", false)
	ok = _check("off removes it", ProjectSettings.has_setting("autoload/ZzPanelGlobal"), false) and ok

	# The window's lists, read from a sheet.
	var sheet: EventSheetResource = EventSheetBehaviourAddonScaffold.behaviour_sheet("Patrol", "CharacterBody2D", "", "")
	sheet.external_source_path = "res://eventsheet_addons/patrol/patrol.gd"
	var speed: LocalVariable = LocalVariable.new()
	speed.name = "speed"
	speed.type_name = "float"
	speed.default_value = 120.0
	speed.exported = true
	speed.description = "pixels a second"
	var state: LocalVariable = LocalVariable.new()
	state.name = "current"
	state.type_name = "int"
	state.default_value = 0
	sheet.events.append(speed)
	sheet.events.append(state)
	var arrived: SignalRow = SignalRow.new()
	arrived.signal_name = "reached_point"
	arrived.trigger = true
	arrived.ace_name = "On reached point"
	sheet.events.append(arrived)
	var is_patrolling: EventFunction = EventFunction.new()
	is_patrolling.function_name = "is_patrolling"
	is_patrolling.expose_as_ace = true
	is_patrolling.return_type = TYPE_BOOL
	is_patrolling.return_type_name = "bool"
	is_patrolling.ace_display_name = "Is patrolling"
	sheet.functions.append(is_patrolling)
	var properties: Array[Dictionary] = MEMBERS.entries(sheet, "properties")
	ok = SUPPORT.pins("new_addon_panel_test", [
		["a behaviour's properties are its exported variables", properties.size(), 1],
		["each with its type, default and meaning", [properties[0]["name"], properties[0]["type"], properties[0]["value"], properties[0]["means"]],
			["speed", "float", "120.0", "pixels a second"]],
		["and the line it is in code", properties[0]["line"], "@export var speed: float = 120.0"],
		["a trigger is listed by its name", MEMBERS.entries(sheet, "triggers")[0]["label"], "On reached point"],
		["a condition says what it returns", MEMBERS.entries(sheet, "conditions")[0]["returns"], "bool"],
		["the behaviour is named as its class", MEMBERS.identity(sheet)["name"], "Patrol"],
		["and is not a global", MEMBERS.identity(sheet)["global"], false],
	]) and ok
	sheet.behavior_mode = false
	sheet.autoload_mode = true
	sheet.autoload_name = "GameState"
	ok = _check("a global's values are every variable but the constants", MEMBERS.entries(sheet, "properties").size(), 2) and ok
	ok = _check("each kind wears its own word", [MEMBERS.kind_word("action"), MEMBERS.kind_word("trigger")], ["Action", "Trigger"]) and ok
	host.free()
	return ok


static func _items(dropdown: OptionButton) -> Array:
	var out: Array = []
	for index: int in range(dropdown.item_count):
		out.append(dropdown.get_item_text(index))
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("new_addon_panel_test", label, actual, expected)
