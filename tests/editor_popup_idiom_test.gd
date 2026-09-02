@tool
class_name EditorPopupIdiomTest
extends RefCounted

# Two editor-source idioms that each caused a real, user-visible bug:
#
# 1. A popup positioned with get_global_mouse_position() opens far from the mouse. Canvas
#    coordinates are not screen coordinates, and a PopupMenu is a native window: the menu lands
#    offset by the editor window's own screen position (the "New from template" menu appeared at
#    the screen's bottom-left). The working form is get_screen_transform() * get_local_mouse_position()
#    (or DisplayServer.mouse_get_position()), which every other popup call site already uses.
#
# 2. get_project_metadata(..., null) prints an editor ERROR on a fresh project, because a missing
#    key with a null default has nothing to answer with. A non-null sentinel ("" here) keeps the
#    tri-state no-choice reading without the console noise.
#
# This sweep keeps both regressions out rather than testing the fix by hand each time.


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var offenders_popup: PackedStringArray = PackedStringArray()
	var offenders_metadata: PackedStringArray = PackedStringArray()
	for path: String in _editor_sources():
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if line.contains(".popup(") and line.contains("get_global_mouse_position()"):
				offenders_popup.append(path.get_file())
			if line.contains("get_project_metadata") and line.replace(" ", "").contains(",null)"):
				offenders_metadata.append(path.get_file())
	ok = _check("no popup positioned in canvas coordinates", offenders_popup, PackedStringArray()) and ok
	ok = _check("no project-metadata read with a null default", offenders_metadata, PackedStringArray()) and ok
	var fixed: String = FileAccess.get_file_as_string("res://addons/eventsheet/editor/dock/starter_templates.gd")
	ok = _check("the template menu uses the screen transform",
		fixed.contains("get_screen_transform() * _dock.get_local_mouse_position()"), true) and ok
	return ok


static func _editor_sources() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray(["res://addons/eventsheet/editor"])
	while not pending.is_empty():
		var dir_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var names: PackedStringArray = DirAccess.get_directories_at(dir_path)
		names.sort()
		for name: String in names:
			pending.append(dir_path.path_join(name))
		var files: PackedStringArray = DirAccess.get_files_at(dir_path)
		files.sort()
		for name: String in files:
			if name.ends_with(".gd"):
				found.append(dir_path.path_join(name))
	found.sort()
	return found


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("editor_popup_idiom_test", label, actual, expected)
