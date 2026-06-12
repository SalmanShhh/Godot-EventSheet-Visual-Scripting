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

# _can_handle fires on every Inspector refresh; sheet_for_script reads files, so
# results are memoized by script path + mtime (review catch).
static var _pairing_cache: Dictionary = {}

## The sheet behind this object's attached script, or "" (which also means
## "don't handle").
static func sheet_path_for(object: Object) -> String:
	if not (object is Node):
		return ""
	var script: Script = (object as Node).get_script() as Script
	if script == null or script.resource_path.is_empty():
		return ""
	var script_path: String = script.resource_path
	var mtime: int = int(FileAccess.get_modified_time(script_path))
	var cached: Variant = _pairing_cache.get(script_path)
	if cached is Dictionary and int((cached as Dictionary).get("mtime")) == mtime:
		return str((cached as Dictionary).get("sheet"))
	var sheet_path: String = EventSheetProjectDoctor.sheet_for_script(script_path)
	_pairing_cache[script_path] = {"mtime": mtime, "sheet": sheet_path}
	return sheet_path
