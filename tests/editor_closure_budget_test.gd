# EventForge - what the first open of the workspace compiles stays inside its budget.
#
# The plugin builds its workspace editor lazily, by loading `event_sheet_editor.gd` by path on the
# first sheet open, and in GDScript a global class named anywhere in a file's code compiles that
# class - and every class it names in turn - the moment the file loads. So the first open pays for
# the whole set of files the editor reaches by name. That set grew quietly from 183 files to 558
# (about 249,000 lines, close to twenty seconds of compile) one reasonable-looking name at a time,
# because nothing measured it; it now stands at the figures pinned below.
#
# This test measures it the way the closure tool does - the same static walk, comments and strings
# blanked, by-path loads not followed - and fails when the set grows more than three percent past
# the measured figure. On failure it prints the files that hold the most of the set in, which is the
# list of doors a newly added name has to be moved behind (a `load()` of the script's path at the
# call site, or a small leaf file that names nothing).
#
# The walk is the closure tool's own, preloaded rather than copied, so the test and the tool can
# never disagree about what the first open compiles. Comparing COUNTS here is deliberate: the set is
# the thing being budgeted, and a timing pin of the same fact would flap with the machine's load.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "editor_closure_budget_test"
const Closure := preload("res://tools/measure_editor_closure.gd")

## The closure measured when this budget was set (files, lines), from the default root.
const MEASURED_FILES: int = 338
const MEASURED_LINES: int = 165938
## How far past the measured figure the closure may grow before the test fails, in percent. Room for
## ordinary growth of the files already in the set; not room for a new subtree.
const HEADROOM_PERCENT: int = 3


static func run() -> bool:
	var graph: Dictionary = Closure.build_graph(Closure.ADDONS_ROOT, Closure.DEFAULT_ROOT)
	var edges: Dictionary = graph["edges"]
	var lines: Dictionary = graph["lines"]
	var closure: PackedStringArray = Closure.reach(edges, Closure.DEFAULT_ROOT, "")
	var total_lines: int = 0
	for path: String in closure:
		total_lines += int(lines[path])
	var line_budget: int = MEASURED_LINES * (100 + HEADROOM_PERCENT) / 100
	var file_budget: int = MEASURED_FILES * (100 + HEADROOM_PERCENT) / 100
	print("  [closure] first open compiles %d files, %d lines (budget %d files, %d lines)" % [
		closure.size(), total_lines, file_budget, line_budget])
	var within: bool = total_lines <= line_budget and closure.size() <= file_budget
	if not within:
		_print_hubs(graph, closure)
	return SUPPORT.pins(TEST_NAME, [
		["the editor script is in its own closure", closure.has(Closure.DEFAULT_ROOT), true],
		["the walk found the workspace base", closure.has("res://addons/eventsheet/editor/event_sheet_dock.gd"), true],
		["the first open compiles no more lines than its budget", total_lines <= line_budget, true],
		["the first open compiles no more files than its budget", closure.size() <= file_budget, true],
		# The heavy classes the first open must not compile. Each one is reached by path at the click
		# that needs it; a name in code anywhere in the set puts it, and what it names, back.
		["the Project Doctor is not compiled by the first open",
			closure.has("res://addons/eventforge/project_doctor.gd"), false],
		["the picker dialog is not compiled by the first open",
			closure.has("res://addons/eventsheet/editor/ace_picker.gd"), false],
		["the parameters dialog is not compiled by the first open",
			closure.has("res://addons/eventsheet/editor/ace_params_dialog.gd"), false],
		["the variable dialog is not compiled by the first open",
			closure.has("res://addons/eventsheet/editor/variable_dialog.gd"), false],
		["the public API is not compiled by the first open",
			closure.has("res://addons/eventsheet/api/eventsheets.gd"), false],
		["no file of the Manual is compiled by the first open",
			Array(closure).filter(func(path: String) -> bool:
				return path.begins_with("res://addons/eventsheet/editor/docs/")), []],
	])


## The files holding the most of the closure in, as the closure tool lists them - only on failure,
## since each figure is a full walk of its own.
static func _print_hubs(graph: Dictionary, closure: PackedStringArray) -> void:
	var chain: PackedStringArray = Closure.base_chain(graph, Closure.DEFAULT_ROOT)
	print("  [closure] over budget; the files that hold the most of it in:")
	for hub: Dictionary in Closure.hubs(graph["edges"], graph["lines"], Closure.DEFAULT_ROOT, closure, chain):
		print("  [closure]   %8d lines %4d files  %s" % [hub["lines"], hub["files"], hub["path"]])
