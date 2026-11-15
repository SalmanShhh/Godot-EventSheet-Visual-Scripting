@tool
class_name SheetPublishDefaultTest
extends RefCounted

# Godot EventSheets - a new function of a named sheet starts ticked "Other sheets can use this".
#
# Only the New Function tick's STARTING state flips, and only on a sheet with a class name (another
# sheet can only reach a node it can name). The resource default, old .tres sheets and the emitted
# bytes stay exactly as they were: a function loaded from disk keeps whatever it saved.

const SUPPORT := preload("res://tests/support.gd")
const DIALOG_PATH: String = "res://addons/eventsheet/editor/function_dialog.gd"
const MISSING: String = "<not written yet>"


static func run() -> bool:
	var named: EventSheetResource = EventSheetResource.new()
	named.custom_class_name = "Hero"
	var unnamed: EventSheetResource = EventSheetResource.new()
	var dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	var host: Node = Node.new()
	dialog.init_dialog(host)
	var label: String = dialog._expose_check.text
	host.free()
	return SUPPORT.pins("sheet_publish_default_test", [
		["the resource default is untouched", EventFunction.new().expose_as_ace, false],
		["a named sheet's new function starts ticked", str(_starts(named)), "true"],
		["an unnamed sheet's does not", str(_starts(unnamed)), "false"],
		["the tick says what it does", label, "Other sheets can use this"],
	])


static func _starts(sheet: EventSheetResource) -> Variant:
	var script: GDScript = load(DIALOG_PATH)
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == "starts_published":
			return script.call("starts_published", sheet)
	return MISSING
