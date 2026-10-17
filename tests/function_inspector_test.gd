@tool
extends RefCounted
# Godot EventSheets - a selected function edited in Godot's own Inspector, and the New Function window
# on the window kit. Pins the fields the Inspector is handed, that typed text waits until its field is
# left, and that each field writes exactly one change (and nothing when nothing changed); then the
# window's band, code name, title, help strip and IN CODE line.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "function_inspector_test"
const INSPECTOR_PATH := "res://addons/eventsheet/editor/dock/function_inspector.gd"


static func run() -> bool:
	return _test_inspector() and _test_window()


static func _test_inspector() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "take_damage"
	event_function.description = "Removes health."
	event_function.ace_category = "Player"
	event_function.expose_as_ace = true
	for spec: Array in [["amount", "int", ""], ["critical", "bool", "false"]]:
		var param: ACEParam = ACEParam.new()
		param.id = spec[0]
		param.type_name = spec[1]
		param.gdscript_default = spec[2]
		event_function.params.append(param)
	sheet.functions.append(event_function)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var inspector: RefCounted = load(INSPECTOR_PATH).new(dock, event_function)
	var shown: PackedStringArray = PackedStringArray()
	for property: Dictionary in inspector.get_property_list():
		if int(property.get("usage", 0)) & (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CATEGORY):
			shown.append(str(property.get("name", "")))
	var ok: bool = SUPPORT.pins(NAME, [
		["the Inspector's fields, in the design's order", shown.slice(shown.find("Function take_damage")),
			PackedStringArray(["Function take_damage", "Name", "Description", "Returns", "In Add Action", "Category",
				"Waits", "Shared", "Parameters/1/Name", "Parameters/1/Type", "Parameters/1/Default",
				"Parameters/2/Name", "Parameters/2/Type", "Parameters/2/Default", "Parameters/2/Move Up",
				"Parameters/Add Parameter"])],
		["the Inspector's own undo step is handed back to the funnel", inspector._dont_undo_redo(), true],
		["a parameter shows its name exactly as written", inspector.get("Parameters/1/Name"), "amount"],
		["Returns reads Nothing", inspector.get("Returns"), 0],
		["In Add Action reads the flag", inspector.get("In Add Action"), true],
		["a void function returns Nothing", load(INSPECTOR_PATH).return_word(event_function), "Nothing"],
		["a builtin return word is stored as its type", load(INSPECTOR_PATH).return_fields("float"), [TYPE_FLOAT, ""]],
		["Node rides in the type name", load(INSPECTOR_PATH).return_fields("Node"), [TYPE_MAX, "Node"]],
		["a project class is kept as written", load(INSPECTOR_PATH).return_fields("HealthPool"), [TYPE_MAX, "HealthPool"]],
		["a project class is offered as itself", load(INSPECTOR_PATH).type_words("HealthPool", false)[-1], "HealthPool"],
	])
	# Typed text is held until its field is left, then written once.
	inspector.hold("description", "Hurts a lot.")
	ok = SUPPORT.check(NAME, "a held description is not written yet", inspector.live_function().description, "Removes health.") and ok
	ok = SUPPORT.check(NAME, "but the field shows what was typed", inspector.get("Description"), "Hurts a lot.") and ok
	inspector.commit_pending()
	ok = SUPPORT.check(NAME, "leaving the field writes it", inspector.live_function().description, "Hurts a lot.") and ok
	inspector.set("Returns", 3)
	ok = SUPPORT.check(NAME, "the Returns field writes", CompilerSpellingsProbe.return_name(inspector.live_function()), "float") and ok
	inspector.set("Waits", true)
	ok = SUPPORT.check(NAME, "the Waits field writes is_async", inspector.live_function().is_async, true) and ok
	inspector.set("Parameters/2/Type", 2)
	ok = SUPPORT.check(NAME, "a parameter's Type field writes", inspector.live_function().params[1].type_name, "float") and ok
	inspector.set("Returns", 0)
	inspector.set("Waits", false)
	ok = SUPPORT.check(NAME, "the same return writes nothing", inspector.apply_returns("Nothing"), false) and ok
	ok = SUPPORT.check(NAME, "a new return writes", inspector.apply_returns("float"), true) and ok
	ok = SUPPORT.check(NAME, "the function now returns a float",
		CompilerSpellingsProbe.return_name(inspector.live_function()), "float") and ok
	ok = SUPPORT.check(NAME, "Waits writes is_async", inspector.apply_flag("waits", true), true) and ok
	ok = SUPPORT.check(NAME, "and the function waits", inspector.live_function().is_async, true) and ok
	ok = SUPPORT.check(NAME, "Shared writes is_static", inspector.apply_flag("shared", true), true) and ok
	ok = SUPPORT.check(NAME, "In Add Action off writes", inspector.apply_flag("in_add_action", false), true) and ok
	ok = SUPPORT.check(NAME, "and it is no longer listed", inspector.live_function().expose_as_ace, false) and ok
	ok = SUPPORT.check(NAME, "the same flag again writes nothing", inspector.apply_flag("shared", true), false) and ok
	ok = SUPPORT.check(NAME, "the description field writes", inspector.apply_field("description", "Hurts."), true) and ok
	ok = SUPPORT.check(NAME, "and is stored", inspector.live_function().description, "Hurts.") and ok
	ok = SUPPORT.check(NAME, "a required parameter cannot move behind a defaulted one",
		inspector.move_param(0, 1), false) and ok
	inspector.apply_param_default(0, "2")
	ok = SUPPORT.check(NAME, "a parameter default writes", inspector.live_function().params[0].gdscript_default, "2") and ok
	ok = SUPPORT.check(NAME, "now the parameters may swap", inspector.move_param(1, 0), true) and ok
	ok = SUPPORT.check(NAME, "and they did", [inspector.live_function().params[0].id, inspector.live_function().params[1].id],
		["critical", "amount"]) and ok
	inspector.apply_param_type(1, "float")
	ok = SUPPORT.check(NAME, "a parameter type writes", inspector.live_function().params[1].type_name, "float") and ok
	ok = SUPPORT.check(NAME, "a rename writes", inspector.apply_name("hurt"), true) and ok
	ok = SUPPORT.check(NAME, "and the fields follow the function by its new name", inspector.live_function() != null
		and inspector.live_function().function_name == "hurt", true) and ok
	dock.free()
	return ok


static func _test_window() -> bool:
	var parent: Node = Node.new()
	var dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	dialog.init_dialog(parent)
	dialog._name_edit.text = "Take Damage"
	dialog._refresh_studio()
	var probe: Dictionary = EventSheetPopupUI.probe_help_dialog(dialog._dialog)
	var undescribed: int = 0
	for index: int in dialog._usable_option.item_count:
		if dialog._usable_option.get_item_tooltip(index).is_empty():
			undescribed += 1
	var ok: bool = SUPPORT.pins(NAME, [
		["the band shows the row the sheet will draw", dialog._band_label.text, "ƒ  Function  On take_damage → nothing"],
		["the code name sits beside Name", dialog._code_name_label.text, "→ take_damage"],
		["the title carries the live name", dialog._dialog.title, "Create function take_damage"],
		["the kind is ONE dropdown", dialog._usable_option.item_count, 3],
		["every kind is described", undescribed, 0],
		["the window has one help strip", int(probe.get("strips", 0)), 1],
		["IN CODE is the line it writes", str(probe.get("in_code", "")), "func take_damage() -> void"],
	])
	dialog._usable_option.select(2)
	dialog._select_usable(2)
	ok = SUPPORT.check(NAME, "an Expression returns its value type in the band", dialog._band_label.text,
		"ƒ  Function  On take_damage → float") and ok
	parent.free()
	return ok


## The compiler's spelling of a function's return, without naming the preload in a test.
class CompilerSpellingsProbe:
	static func return_name(event_function: EventFunction) -> String:
		return SheetCompiler._function_return_type_name(event_function) if event_function != null else ""
