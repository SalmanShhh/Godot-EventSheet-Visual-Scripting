# EventSheets - the plugin never replaces a project setting the person already has.
#
# Save Studio's "keep the settings in a scene" re-pointed the SaveSystem global without looking. Every
# place that writes a global asks the guard first: a name that already loads something else is theirs.
# The settings the plugin does write are one step of Godot's own undo.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "global_names_guard_test"
const GUARD_PATH: String = "res://addons/eventsheet/editor/dock/autoload_guard.gd"
const KEY: String = "autoload/GuardProbeGlobal"
const SCENE: String = "user://global_names_guard_probe.tscn"


static func run() -> bool:
	var guard: GDScript = load(GUARD_PATH)
	var had: bool = ProjectSettings.has_setting(KEY)
	var before: Variant = ProjectSettings.get_setting(KEY, "")
	ProjectSettings.set_setting(KEY, "*res://their_own_global.gd")
	var held: String = guard.held_elsewhere("GuardProbeGlobal", SCENE)
	var same: String = guard.held_elsewhere("GuardProbeGlobal", "res://their_own_global.gd")
	var absent: String = guard.held_elsewhere("GuardProbeGlobalNobodyHas", SCENE)
	var next_name: String = guard.free_name("GuardProbeGlobal")
	var next_was_free: bool = not ProjectSettings.has_setting("autoload/%s" % next_name)
	# Save Studio: the file does not exist yet, the global is the reader's, so nothing is written or re-pointed.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE))
	var refused: String = EventSheetSaveStudio.make_settings_scene(SCENE, "GuardProbeGlobal")
	var global_after: String = str(ProjectSettings.get_setting(KEY, ""))
	var wrote_file: bool = FileAccess.file_exists(SCENE)
	# A free name goes through, and is one step of undo (recorded on a plain UndoRedo here, so it runs the do half).
	var made: String = EventSheetSaveStudio.make_settings_scene(SCENE, next_name)
	var made_key: String = "autoload/%s" % next_name
	var made_value: String = str(ProjectSettings.get_setting(made_key, ""))
	var ok: bool = SUPPORT.pins(P, [
		["a global that loads something else is reported with where it points", held, "res://their_own_global.gd"],
		["a global that already loads the target is not a clash", same, ""],
		["a name nobody has is not a clash", absent, ""],
		["the offered name is free", next_was_free, true],
		["the offered name keeps the first and numbers it", next_name, "GuardProbeGlobal2"],
		["Save Studio refuses and names the existing path", refused.contains("res://their_own_global.gd"), true],
		["and says the global is not replaced", refused.contains("not replaced"), true],
		["the reader's global still points where it did", global_after, "*res://their_own_global.gd"],
		["and no scene file was written for the refused name", wrote_file, false],
		["a free name is accepted", made, ""],
		["and the global goes to the scene", made_value, "*" + SCENE],
	])
	ProjectSettings.set_setting(made_key, null)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE))
	if had:
		ProjectSettings.set_setting(KEY, before)
	else:
		ProjectSettings.set_setting(KEY, null)
	return ok
