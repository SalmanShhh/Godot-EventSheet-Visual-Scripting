# Godot EventSheets - what enabling the plugin costs, measured in a process that has never done it.
#
# Boot cost cannot be measured from inside the test suite. By the time any test runs, half the plugin
# is compiled and every registry is warm, so the same code that costs a second at editor start
# measures as zero. The only honest measurement is a FRESH process that does it once and says how
# long it took, which is what this script is: run it, it prints one line of numbers and quits.
#
#     $GODOT --headless --path . --script tests/cold_boot_probe.gd
#
# THREE NUMBERS, because they are three different promises:
#
#   closure_ms    - the work `_enter_tree` does. Loading plugin.gd compiles every class the file
#                   NAMES, which is the whole reason those references were moved to load-by-path;
#                   the rest is the objects the editor is handed (context menus, inspector plugins,
#                   export hooks, gizmos, the docked manual). This is what a project that never
#                   opens an event sheet pays, at every editor start, forever.
#
#   registries_ms - the once-per-session builds the first tab forces: every descriptor, the reverse
#                   index every lift matches against, the compiled matchers, the block kinds.
#                   Reported on its own because it is the half of a first open that no later tab
#                   pays, and therefore the half worth making smaller.
#
#   first_open_ms - those registries plus one real script opened as a sheet: the whole wait between
#                   clicking a sheet and reading it, on a session's first tab.
#
# And two more, measured in a SECOND fresh process the probe starts for itself, because the three
# above have already compiled half of what they would measure:
#
#   editor_load_ms  - loading the workspace editor script and nothing else: the compile of every
#                     class the editor names, which the first open of the workspace pays before a
#                     single object exists.
#
#   editor_build_ms - that load plus `.new()` on it: what the plugin's lazy editor build pays
#                     before the editor is handed to the main screen.
#
#   cached          - after that build, off the clock, the workspace opens a blank sheet and then
#                     FIRST_SHEET, and runs the picker's whole idle warm, as the first open in the
#                     editor does;
#                     then the heavy scripts in RUNTIME_HEAVY that this left compiled, or `none`.
#                     A VALUE, not a time: the static closure walk cannot see a helper the dock
#                     reaches by path at runtime, and this is the gate that can.
#
# What it deliberately leaves out: the three EditorPlugin registration calls (`add_context_menu_plugin`
# and friends), which need a live editor, and the import hook's `attach`, which needs
# EditorInterface. All four are engine bookkeeping over objects already built by then; the cost
# being measured is the building.
#
# A helper, not a test - it declares no `run`, and it is not named `*_test.gd`, so the suite's
# discovery never picks it up. `huge_project_budget_test.gd` runs it as a subprocess and pins the
# numbers it prints.
@tool
extends SceneTree

## The line the budget test parses. Kept on one line, with plain `key=value` pairs, so reading it
## back is a split rather than a parse.
const RESULT_PREFIX: String = "cold_boot"

## The workspace editor the plugin builds lazily on the first open, and the argument that makes this
## script measure ONLY that, in a process of its own.
const EDITOR_SCRIPT: String = "res://addons/eventforge/editor/event_sheet_editor.gd"
const EDITOR_ONLY_ARGUMENT: String = "--editor-only"

## The sheet resource the workspace opens on its first paint, by path for the reason above.
const SHEET_RESOURCE_SCRIPT: String = "res://addons/eventforge/resources/event_sheet.gd"
const PICKER_WARMUP_SCRIPT: String = "res://addons/eventsheet/editor/picker_warmup.gd"

## The scripts a click compiles and the first open of the workspace must not: the picker, the
## parameters and variable dialogs, the Doctor and the public API. Every script in the Manual's
## folder is added to these when the probe runs: the plugin builds the docked Manual at boot, but this
## process never boots the plugin, so the workspace compiling any of them is still a fault.
const RUNTIME_HEAVY: Array[String] = [
	"res://addons/eventsheet/editor/ace_picker.gd",
	"res://addons/eventsheet/editor/ace_params_dialog.gd",
	"res://addons/eventsheet/editor/variable_dialog.gd",
	"res://addons/eventforge/project_doctor.gd",
	"res://addons/eventsheet/api/eventsheets.gd",
	# And the dock helpers only a click reaches. Each is small, but each was built while the canvas
	# and the strip were being wired - a handler named as a bound method builds its helper on the
	# spot - and together they cost the first open about a second of compiling.
	"res://addons/eventsheet/editor/dock/ask_field.gd",
	"res://addons/eventsheet/editor/dock/function_dialog_glue.gd",
	"res://addons/eventsheet/editor/dock/sheet_head_actions.gd",
	"res://addons/eventsheet/editor/dock/navigate.gd",
	"res://addons/eventsheet/editor/dock/add_row_requests.gd",
	"res://addons/eventsheet/editor/dock/variable_grouping.gd",
]
const MANUAL_FOLDER: String = "res://addons/eventsheet/editor/docs/"

## A typical first sheet: a showcase script of about seventy lines, the size most files really are.
## The heaviest open in the project has its own budget elsewhere; this one is about what the first
## tab of a session costs when the sheet itself is ordinary.
const FIRST_SHEET: String = "res://demo/showcase/boomer_level/boomer_level.gd"

## Everything `_enter_tree` reaches by path. Named here as strings for the same reason the plugin
## names them as strings: a class name in this file would compile its subtree before the clock
## starts, and the measurement would then miss the very thing it is measuring.
##
## THIS LIST HAS TO TRACK `_enter_tree`. A by-path load the plugin does and this list does not name
## is boot cost nothing measures - which is how the Feedback Player's Inspector plugin and the
## registry store below arrived unbudgeted. A `load()` inside a lambda is NOT one of these: the
## card schema and the step field are fetched the first time something asks for them, and a session
## that opens no Inspector never pays for either.
const BY_PATH_BOOT_OBJECTS: Array[String] = [
	"res://addons/eventforge/editor/export_tools_plugin.gd",
	"res://addons/eventforge/editor/import_tools_plugin.gd",
	"res://addons/eventforge/editor/instance_variables_inspector_plugin.gd",
	"res://addons/eventsheet/editor/inspector/drawing_prefab_inspector_plugin.gd",
	"res://addons/eventsheet/editor/inspector/feedback_player_inspector_plugin.gd",
	"res://addons/eventsheet/api/extension_registries.gd",
	"res://addons/eventsheet/editor/inspector/drawing_prefab_preview_generator.gd",
	"res://addons/eventsheet/editor/inspector/handle_plugin.gd",
	"res://addons/eventsheet/editor/drawing_canvas_gizmo.gd",
	"res://addons/eventsheet/editor/drawing_prefab_gizmo.gd",
	"res://addons/eventsheet/editor/drawing_prefab_3d_gizmo.gd",
	"res://addons/eventsheet/editor/behavior_gizmos.gd",
	"res://addons/eventsheet/editor/scene_events_overlay.gd",
	"res://addons/eventsheet/editor/docs/doc_dock.gd",
]

## The context menu, built once per editor slot - the Scene tree, the FileSystem, its Create New
## submenu and the script editor, which is four objects at every boot.
const CONTEXT_MENU_PLUGIN: String = "res://addons/eventforge/editor/context_menu_plugin.gd"
const CONTEXT_MENU_SLOTS: int = 4

## The other classes `_enter_tree` NAMES, and therefore compiles when plugin.gd loads. Constructed
## here by the same route the plugin constructs them, through the loaded script object rather than
## by name.
const NAMED_BOOT_OBJECTS: Array[String] = [
	"res://addons/eventforge/editor/sheet_edit_inspector_plugin.gd",
	"res://addons/eventforge/editor/export_integrity_plugin.gd",
	"res://addons/eventsheet/editor/live_values_debugger.gd",
	"res://addons/eventsheet/editor/attribute_drawers.gd",
]


func _init() -> void:
	if OS.get_cmdline_user_args().has(EDITOR_ONLY_ARGUMENT):
		print("%s %s" % [RESULT_PREFIX, _time_editor_build()])
		quit(0)
		return
	var closure_ms: float = _time_boot_closure()
	var registries_ms: float = _time_registries()
	var first_open_ms: float = registries_ms + _time_sheet_open()
	print("%s closure_ms=%.1f registries_ms=%.1f first_open_ms=%.1f %s" % [
		RESULT_PREFIX, closure_ms, registries_ms, first_open_ms, _editor_build_in_fresh_process()])
	quit(0)


## Loading plugin.gd and building every object `_enter_tree` builds.
func _time_boot_closure() -> float:
	var start_usec: int = Time.get_ticks_usec()
	var plugin: Script = load("res://addons/eventforge/plugin.gd")
	if plugin == null:
		push_error("[cold boot probe] the plugin script did not load")
		quit(1)
		return 0.0
	# The project settings the plugin declares. In-memory only (it never saves), so a probe run
	# leaves project.godot exactly as it found it.
	(load("res://addons/eventforge/settings.gd") as Object).call("register_all")
	# One context menu per editor slot, then one of everything else.
	for _slot in CONTEXT_MENU_SLOTS:
		_construct(CONTEXT_MENU_PLUGIN)
	for path: String in NAMED_BOOT_OBJECTS:
		_construct(path)
	for path: String in BY_PATH_BOOT_OBJECTS:
		_construct(path)
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


## The once-per-session registries the first tab forces.
##
## Every plugin class here is reached BY PATH as well, and that is not style: naming one as a type
## anywhere in this file would compile its whole subtree the moment the probe script loads, which is
## before the boot clock above ever starts. The measurement would then be of a plugin that was
## already half compiled, and it would look wonderful.
func _time_registries() -> float:
	var start_usec: int = Time.get_ticks_usec()
	(load("res://addons/eventforge/importer/open_job.gd") as Object).call("warm_registries")
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


## The editor build, asked of a second fresh process. By now this one has compiled the importer,
## the lifter and every registry the editor names, so timing the editor here would leave most of
## its compile off the clock. Answers the child's `key=value` pairs, or -1 for both when it printed
## none, which the budget reads as a failure rather than as free.
func _editor_build_in_fresh_process() -> String:
	var output: Array = []
	var arguments: PackedStringArray = PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--",
		EDITOR_ONLY_ARGUMENT])
	OS.execute(OS.get_executable_path(), arguments, output, true)
	for chunk: Variant in output:
		for line: String in str(chunk).split("\n"):
			if line.begins_with(RESULT_PREFIX + " editor_load_ms="):
				return line.trim_prefix(RESULT_PREFIX + " ").strip_edges()
	return "editor_load_ms=-1 editor_build_ms=-1"


## Loading the workspace editor and building one, timed apart: the compile alone, then the compile
## plus the construction. The plugin's settings are declared first, as `_enter_tree` has always
## done by the time a workspace opens, and that is kept off the clock.
func _time_editor_build() -> String:
	(load("res://addons/eventforge/settings.gd") as Object).call("register_all")
	var start_usec: int = Time.get_ticks_usec()
	var editor_script: Script = load(EDITOR_SCRIPT)
	var loaded_usec: int = Time.get_ticks_usec()
	if editor_script == null or not editor_script.can_instantiate():
		push_error("[cold boot probe] the workspace editor did not load")
		return "editor_load_ms=-1 editor_build_ms=-1"
	var editor: Variant = editor_script.new()
	var built_usec: int = Time.get_ticks_usec()
	var timings: String = "editor_load_ms=%.1f editor_build_ms=%.1f" % [
		float(loaded_usec - start_usec) / 1000.0, float(built_usec - start_usec) / 1000.0]
	if editor is Node:
		(editor as Node).call("setup", load(SHEET_RESOURCE_SCRIPT).new())
		# And the ordinary first sheet opened through the workspace's own door, because a blank sheet
		# has no rows to read: the Doctor and the variable dialog both rode in on the reading of real
		# rows - the script list the share index asks for, a variable's default value - and a blank
		# sheet never asked either question.
		(editor as Node).call("_load_sheet_from_path", FIRST_SHEET)
		(load(PICKER_WARMUP_SCRIPT) as Object).call("warm_now")
		var cached: PackedStringArray = PackedStringArray()
		for path: String in runtime_heavy_paths():
			if ResourceLoader.has_cached(path):
				cached.append(path)
		timings += " cached=%s" % (",".join(cached) if not cached.is_empty() else "none")
		(editor as Node).free()
	return timings


## RUNTIME_HEAVY plus every script of the Manual folder. Static so the budget test names the same set.
static func runtime_heavy_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray(RUNTIME_HEAVY)
	for file: String in DirAccess.get_files_at(MANUAL_FOLDER):
		if file.get_extension() == "gd":
			paths.append(MANUAL_FOLDER + file)
	return paths


## One ordinary sheet, opened through the registries above.
func _time_sheet_open() -> float:
	var start_usec: int = Time.get_ticks_usec()
	var importer: Variant = load("res://addons/eventforge/importer/gdscript_importer.gd").new()
	var sheet: Variant = importer.call("import_external", FIRST_SHEET, false)
	if sheet != null:
		(load("res://addons/eventforge/importer/ace_lifter.gd") as Object).call("attempt_lift",
			sheet, FileAccess.get_file_as_string(FIRST_SHEET))
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


## Loads one boot script and builds it if it can be built here.
##
## The LOAD is nearly all of the cost, and it always happens - that is the compile boot pays. The
## construction is skipped for the editor-only bases (a dock, an inspector plugin, a resource
## preview generator), which the engine refuses to instantiate outside a running editor. Skipping is
## honest: what those classes cost at boot is their compile, and that is already on the clock.
## A Node is freed at once rather than left to a queue this process never runs; anything else is
## RefCounted and releases itself.
func _construct(path: String) -> void:
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		push_error("[cold boot probe] boot object did not load: %s" % path)
		return
	if not ClassDB.can_instantiate(script.get_instance_base_type()):
		return
	var built: Variant = script.new()
	if built is Node:
		(built as Node).free()
