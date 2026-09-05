# Godot EventSheets - what enabling the plugin costs, measured in a process that has never done it.
#
# Boot cost cannot be measured from inside the test suite. By the time any test runs, half the plugin
# is compiled and every registry is warm, so the same code that costs a second at editor start
# measures as zero. The only honest measurement is a FRESH process that does it once and says how
# long it took, which is what this script is: run it, it prints two numbers and quits.
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
	var closure_ms: float = _time_boot_closure()
	var registries_ms: float = _time_registries()
	var first_open_ms: float = registries_ms + _time_sheet_open()
	print("%s closure_ms=%.1f registries_ms=%.1f first_open_ms=%.1f" % [
		RESULT_PREFIX, closure_ms, registries_ms, first_open_ms])
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
