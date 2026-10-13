# Godot EventSheets - what enabling the plugin and opening the first sheet cost INSIDE A REAL EDITOR.
#
# `tests/cold_boot_probe.gd` times the same two promises from a bare `--script` process, which has
# no editor around it: no EditorInterface, no docks, no main screen. This tool runs inside the editor
# itself and times them the way a person meets them:
#
#   enable_ms     - EditorInterface.set_plugin_enabled(true) on an editor that booted WITHOUT the
#                   plugin, through the next frame: loading plugin.gd (and everything it names),
#                   `_enter_tree`, and the docked manual handed to the editor.
#   first_open_ms - the plugin's own open door on FIRST_SHEET, through the frame its lift lands:
#                   the lazy workspace build, the once-per-session registries, the raw pass and the
#                   worker-thread lift. The wait between clicking a sheet and reading its events.
#
# The plugin is kept out of the boot by blanking `editor_plugins/enabled` in memory before the
# editor reads it, so the enable is cold: nothing of the plugin is compiled when the clock starts.
# Enabling it puts the same one entry back, so project.godot is left as it was.
#
# Run (NON-headless is the real figure; `--headless` works too and is what the budget test uses):
#   godot --editor --path . --script tools/measure_editor_boot.gd
#
# Prints one line, `editor boot: enable_ms=N first_open_ms=N`, and quits; exit 1 if either step
# could not be measured. One process measures once - start it again for another sample.
# `tests/editor_boot_budget_test.gd` runs it as a subprocess and holds both numbers to a budget.
# The editor may segfault while it tears down after the line is printed; the line is the answer.
@tool
extends SceneTree

const PLUGIN_NAME: String = "eventforge"
const PLUGIN_SCRIPT: String = "res://addons/eventforge/plugin.gd"
## The same ordinary sheet the bare-process probe opens, so the two sets of figures compare.
const FIRST_SHEET: String = "res://demo/showcase/boomer_level/boomer_level.gd"
## Frames to wait for the editor to settle before the clock starts (first scan, layout).
const SETTLE_FRAMES: int = 30
## Give up on the open after this long, so a hang reports instead of holding the caller forever.
const OPEN_TIMEOUT_MS: int = 120000

var _frames: int = 0
var _step: String = "settle"
var _started_usec: int = 0
var _enable_ms: float = -1.0
var _first_open_ms: float = -1.0
var _workspace: Object = null
var _enabled_setting: Variant = null
var _project_file: PackedByteArray = PackedByteArray()


func _init() -> void:
	_enabled_setting = ProjectSettings.get_setting("editor_plugins/enabled")
	_project_file = FileAccess.get_file_as_bytes("res://project.godot")
	ProjectSettings.set_setting("editor_plugins/enabled", PackedStringArray())
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	match _step:
		"settle":
			if _frames < SETTLE_FRAMES or EditorInterface.get_resource_filesystem().is_scanning():
				return
			_step = "enabled"
			_started_usec = Time.get_ticks_usec()
			EditorInterface.set_plugin_enabled(PLUGIN_NAME, true)
		"enabled":
			_enable_ms = _elapsed_ms()
			var plugin: Node = _find_plugin()
			if plugin == null:
				_finish("the plugin did not enter the tree")
				return
			_step = "opening"
			_started_usec = Time.get_ticks_usec()
			plugin.call("_open_sheet_in_workspace", FIRST_SHEET)
			_workspace = plugin.get("_event_sheet_editor")
			if _workspace == null:
				_finish("the workspace was not built")
		"opening":
			if _elapsed_ms() > OPEN_TIMEOUT_MS:
				_finish("the open did not finish in %d ms" % OPEN_TIMEOUT_MS)
			elif (_workspace.get("_sheet_io") as Object).get("_open_job") == null:
				_first_open_ms = _elapsed_ms()
				# An open that bailed early would also leave no job behind; only the right sheet on
				# screen makes the figure the wait it claims to be.
				var shown: String = str(_workspace.get("_current_sheet_path"))
				_finish("" if shown == FIRST_SHEET else "the workspace shows %s, not the sheet" % shown)


func _elapsed_ms() -> float:
	return float(Time.get_ticks_usec() - _started_usec) / 1000.0


## The plugin's EditorPlugin node: the editor adds every enabled plugin under its own root.
func _find_plugin() -> Node:
	for node: Node in root.find_children("*", "EditorPlugin", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path == PLUGIN_SCRIPT:
			return node
	return null


## The editor writes project settings on its own schedule, and it may have written the blanked
## plugin list; the setting goes back in memory and the file goes back byte for byte.
func _finish(problem: String) -> void:
	process_frame.disconnect(_on_frame)
	ProjectSettings.set_setting("editor_plugins/enabled", _enabled_setting)
	_restore_project_file()
	if not problem.is_empty():
		print("editor boot: could not measure - %s" % problem)
	else:
		print("editor boot: enable_ms=%d first_open_ms=%d" % [roundi(_enable_ms), roundi(_first_open_ms)])
	quit.call_deferred(1 if not problem.is_empty() else 0)


func _finalize() -> void:
	_restore_project_file()


func _restore_project_file() -> void:
	if _project_file.is_empty() or FileAccess.get_file_as_bytes("res://project.godot") == _project_file:
		return
	var file: FileAccess = FileAccess.open("res://project.godot", FileAccess.WRITE)
	if file != null:
		file.store_buffer(_project_file)
