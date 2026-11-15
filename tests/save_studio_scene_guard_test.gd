# EventSheets - Save Studio's "Keep them in a scene" never writes over a file of that name. It wrote
# res://save_system.tscn without looking, replacing whatever the reader had there and re-pointing the
# SaveSystem global with no undo.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "save_studio_scene_guard_test"
const SCENE := "user://save_studio_scene_guard_probe.tscn"
const KEY := "autoload/SaveSystem"


static func run() -> bool:
	var had: bool = ProjectSettings.has_setting(KEY)
	var before: Variant = ProjectSettings.get_setting(KEY, "")
	var file: FileAccess = FileAccess.open(SCENE, FileAccess.WRITE)
	file.store_string("the reader's own file\n")
	file.close()
	ProjectSettings.set_setting(KEY, "*res://addons/eventsheet/editor/dock/save_studio.gd")
	var refused: String = EventSheetSaveStudio.make_settings_scene(SCENE)
	var kept: String = FileAccess.get_file_as_string(SCENE)
	var global_after: String = str(ProjectSettings.get_setting(KEY, ""))
	# The global already runs that very file: nothing to do, nothing written.
	ProjectSettings.set_setting(KEY, "*" + SCENE)
	var already: String = EventSheetSaveStudio.make_settings_scene(SCENE)
	var kept_again: String = FileAccess.get_file_as_string(SCENE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE))
	if had:
		ProjectSettings.set_setting(KEY, before)
	else:
		ProjectSettings.set_setting(KEY, null)
	return SUPPORT.pins(P, [
		["an existing file is refused by name", refused.contains(SCENE), true],
		["and the reader is told what to do", refused.contains("Rename or delete that file"), true],
		["and it is not written over", kept, "the reader's own file\n"],
		["and the global is not re-pointed", global_after, "*res://addons/eventsheet/editor/dock/save_studio.gd"],
		["a file the global already runs asks for nothing", already, ""],
		["and is not written over either", kept_again, "the reader's own file\n"],
	])
