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
# Session restore is switched off the same way, in memory, for the length of the run. The tabs a
# workspace reopens come from `user://`, which every checkout of this project shares, so with it on
# the figure was whatever the LAST editor anyone closed had open: one run reopened a 2,000-line
# sheet on top of the open it was timing, the next reopened nothing, and the two read as a second
# apart for no change in the code. Off, the open is the same one sheet every time, and the saved
# session is neither read nor written.
#
# THE EDITOR'S OWN SCRIPT WALK decides whether a figure is the ordinary open. The editor keeps its
# documentation of a project's scripts in `.godot/editor/editor_script_doc_cache.res`: it reads and
# deletes that file at start and writes it back when it closes, and only once every script has been
# documented. An editor that finds no file (a first start on a project, or the start after a crash)
# runs a worker thread that loads EVERY script of the project, with no plugin involved at all. On this
# repository the walk outlasts any measuring run, so a tree that has only ever been measured never
# gets the file and has the walk every time. It takes the compile lock and reaches the plugin's scripts
# in folder order: such a run compiled 573 scripts in 22 s instead of 455 in 18 s, and which ones
# landed inside the open moved with the timing of a frame. It looked exactly like a door in the row
# build. The result line says `doc_walk=1` when the run had no file. With `-- no-doc-walk`
# this tool writes an empty file for the editor to read instead. The editor will then save a short
# list of documented scripts when this process quits, so whoever passes that takes the file away
# afterwards (the budget test does, when there was none before it ran).
#
# Run (NON-headless is the real figure; `--headless` works too and is what the budget test uses):
#   godot --editor --path . --script tools/measure_editor_boot.gd
#
# Prints one line, `editor boot: enable_ms=N first_open_ms=N tabs=N doc_walk=N heavy=N first_picker_ms=N
# api_after_picker=N`, and quits; exit 1 if either step could not be measured. `heavy` counts the
# scripts of HEAVY_SCRIPTS the first open compiled, and a second line, `editor boot heavy: ...`, names
# them. `first_picker_ms` is the first build of the picker straight after, the first click on Add, and
# `api_after_picker` says whether that click compiled the public API and everything it names. One process measures once - start it again for another sample.
# `tests/editor_boot_budget_test.gd` runs it as a subprocess and holds both numbers to a budget.
# The editor may segfault while it tears down after the line is printed; the line is the answer.
@tool
extends SceneTree

const PLUGIN_NAME: String = "eventforge"
const PLUGIN_SCRIPT: String = "res://addons/eventforge/plugin.gd"
## The workspace's own switch for reopening last session's tabs (see the header for why it is off).
const RESTORE_SESSION_SETTING: String = "eventsheets/editor/restore_session"
## The same ordinary sheet the bare-process probe opens, so the two sets of figures compare.
const FIRST_SHEET: String = "res://demo/showcase/boomer_level/boomer_level.gd"
## Open in the editor before the clock starts, as a scene almost always is when a sheet is opened. Rows
## ask things of the open scene that nothing asks without one: a comment row's doors listing its nodes
## once compiled the parameters dialog, the picker and the public API into the first open, and a
## measuring run with no scene open never saw it.
const FIRST_SCENE: String = "res://demo/showcase/boomer_level/boomer_level.tscn"
## Frames to wait for the editor to settle before the clock starts (first scan, layout).
const SETTLE_FRAMES: int = 30
## Give up on the open after this long, so a hang reports instead of holding the caller forever.
const OPEN_TIMEOUT_MS: int = 120000
## Where the editor keeps its documentation of the project's scripts (see the header).
const SCRIPT_DOC_CACHE: String = "res://.godot/editor/editor_script_doc_cache.res"
const PUBLIC_API_SCRIPT: String = "res://addons/eventsheet/api/eventsheets.gd"
## What a click compiles and the first open must not: the picker, the parameters and variable
## dialogs, the Doctor and its panel, and the public API that names them all.
const HEAVY_SCRIPTS: Array[String] = [
	"res://addons/eventsheet/editor/ace_picker.gd",
	"res://addons/eventsheet/editor/ace_params_dialog.gd",
	"res://addons/eventsheet/editor/variable_dialog.gd",
	"res://addons/eventforge/project_doctor.gd",
	"res://addons/eventsheet/editor/dock/project_doctor_panel.gd",
	PUBLIC_API_SCRIPT,
]

var _frames: int = 0
var _step: String = "settle"
var _started_usec: int = 0
var _enable_ms: float = -1.0
var _first_open_ms: float = -1.0
var _workspace: Object = null
var _enabled_setting: Variant = null
var _restore_setting: Variant = null
var _project_file: PackedByteArray = PackedByteArray()
var _doc_walk: bool = false
var _scene_opened_at: int = 0


func _init() -> void:
	_enabled_setting = ProjectSettings.get_setting("editor_plugins/enabled")
	_project_file = FileAccess.get_file_as_bytes("res://project.godot")
	ProjectSettings.set_setting("editor_plugins/enabled", PackedStringArray())
	_restore_setting = ProjectSettings.get_setting(RESTORE_SESSION_SETTING)
	ProjectSettings.set_setting(RESTORE_SESSION_SETTING, false)
	_note_the_script_walk()
	process_frame.connect(_on_frame)


## Whether the editor is about to walk every script, and with `no-doc-walk`, an empty file so it does not.
func _note_the_script_walk() -> void:
	if FileAccess.file_exists(SCRIPT_DOC_CACHE):
		return
	_doc_walk = true
	if not OS.get_cmdline_user_args().has("no-doc-walk"):
		return
	DirAccess.make_dir_recursive_absolute(SCRIPT_DOC_CACHE.get_base_dir())
	var empty: Resource = Resource.new()
	empty.set_meta("classes", [])
	_doc_walk = ResourceSaver.save(empty, SCRIPT_DOC_CACHE) != OK


func _on_frame() -> void:
	_frames += 1
	match _step:
		"settle":
			if _frames < SETTLE_FRAMES or EditorInterface.get_resource_filesystem().is_scanning():
				return
			EditorInterface.open_scene_from_path(FIRST_SCENE)
			_scene_opened_at = _frames
			_step = "scene"
		"scene":
			if _frames < _scene_opened_at + SETTLE_FRAMES:
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
	ProjectSettings.set_setting(RESTORE_SESSION_SETTING, _restore_setting)
	_restore_project_file()
	if not problem.is_empty():
		print("editor boot: could not measure - %s" % problem)
	else:
		var heavy: PackedStringArray = PackedStringArray()
		for path: String in HEAVY_SCRIPTS:
			if ResourceLoader.has_cached(path):
				heavy.append(path)
		var picker_started: int = Time.get_ticks_usec()
		_workspace.get("_ace_picker")
		var picker_ms: float = float(Time.get_ticks_usec() - picker_started) / 1000.0
		print("editor boot: enable_ms=%d first_open_ms=%d tabs=%d doc_walk=%d heavy=%d first_picker_ms=%d api_after_picker=%d" % [
			roundi(_enable_ms), roundi(_first_open_ms), (_workspace.get("_open_tabs") as Array).size(), 1 if _doc_walk else 0, heavy.size(),
			roundi(picker_ms), 1 if ResourceLoader.has_cached(PUBLIC_API_SCRIPT) else 0])
		print("editor boot heavy: %s" % ", ".join(heavy))
	quit.call_deferred(1 if not problem.is_empty() else 0)


func _finalize() -> void:
	_restore_project_file()


func _restore_project_file() -> void:
	if _project_file.is_empty() or FileAccess.get_file_as_bytes("res://project.godot") == _project_file:
		return
	var file: FileAccess = FileAccess.open("res://project.godot", FileAccess.WRITE)
	if file != null:
		file.store_buffer(_project_file)
