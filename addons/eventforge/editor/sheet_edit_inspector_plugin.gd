# Godot EventSheets — the Inspector's "Edit Event Sheet" button
#
# Godot devs live in the Inspector: when the selected node's script is generated
# from a sheet (the pairing rule knows), one button jumps straight to the sheet —
# and quietly says "edit the sheet, not the script".
@tool
class_name EventSheetEditButtonPlugin
extends EditorInspectorPlugin

var open_sheet: Callable = Callable()  # Callable(sheet_path: String)

func _can_handle(object: Object) -> bool:
	return not sheet_path_for(object).is_empty()

func _parse_begin(object: Object) -> void:
	var sheet_path: String = sheet_path_for(object)
	if sheet_path.is_empty():
		return
	var button: Button = Button.new()
	button.text = "Edit Event Sheet"
	button.tooltip_text = "%s is generated from %s — edit the sheet, not the script." % [
		(object.get_script() as Script).resource_path.get_file() if object.get_script() != null else "the script", sheet_path.get_file()]
	button.pressed.connect(func() -> void:
		if open_sheet.is_valid():
			open_sheet.call(sheet_path))
	add_custom_control(button)

## The sheet behind this object's attached script, or "" (which also means
## "don't handle").
static func sheet_path_for(object: Object) -> String:
	if not (object is Node):
		return ""
	var script: Script = (object as Node).get_script() as Script
	if script == null or script.resource_path.is_empty():
		return ""
	return EventSheetProjectDoctor.sheet_for_script(script.resource_path)
