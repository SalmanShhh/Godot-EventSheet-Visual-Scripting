# EventForge - the reading core does not name the heavy classes it only borrows from.
#
# The canvas, the row builder, the grammar and the fact scanners all load on the first sheet open,
# and in GDScript naming a global class anywhere in a file's code compiles that class - and all it
# names - when the file loads. They used to name the picker dialog for a theme icon, the compiler
# for two constants and a type spelling, the lifter for a handful of statics, the parameter and
# variable dialogs and the Manual for one hover or drop each, and the public API for answers that
# live elsewhere. Each of those now has a leaf of its own or is reached by path at the call site.
#
# Pinned three ways:
#   1. The compile-time graph (the closure tool's own static walk, comments and strings blanked)
#      has no edge from these files to those classes - a name creeping back fails here, not as
#      thirty seconds on somebody's first open.
#   2. The leaves are the ONE source: the picker's old entry points and the compiler's constants
#      answer exactly what the leaves answer.
#   3. Every by-path door exists and answers through the loaded script as through the class.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "reading_core_lazy_test"
const Closure := preload("res://tools/measure_editor_closure.gd")
const ReadingDoors := preload("res://addons/eventsheet/editor/interaction/reading_doors.gd")
const CompilerSpellings := preload("res://addons/eventforge/compiler/compiler_spellings.gd")
const DockRegistry := preload("res://addons/eventsheet/api/dock_registry.gd")

const PICKER := "res://addons/eventsheet/editor/ace_picker.gd"
const COMPILER := "res://addons/eventforge/compiler/sheet_compiler.gd"
const LIFTER := "res://addons/eventforge/importer/ace_lifter.gd"
const API := "res://addons/eventsheet/api/eventsheets.gd"
const PARAMS_DIALOG := "res://addons/eventsheet/editor/ace_params_dialog.gd"
const VARIABLE_DIALOG := "res://addons/eventsheet/editor/variable_dialog.gd"
const DOC_REFERENCE := "res://addons/eventsheet/editor/docs/doc_reference.gd"
const INTERACTION := "res://addons/eventsheet/editor/interaction/"

## file -> the heavy scripts it must not reach at compile time.
const FORBIDDEN := {
	INTERACTION + "viewport_row_builder.gd": [PICKER, COMPILER, LIFTER],
	INTERACTION + "sentence_grammar.gd": [COMPILER, LIFTER],
	INTERACTION + "viewport_reading_rows.gd": [PICKER, COMPILER],
	INTERACTION + "native_row_marks.gd": [PICKER],
	INTERACTION + "lift_reading.gd": [COMPILER, LIFTER],
	INTERACTION + "migration_plan.gd": [COMPILER, LIFTER],
	INTERACTION + "code_echo.gd": [COMPILER],
	INTERACTION + "group_facts.gd": [COMPILER],
	INTERACTION + "mode_facts.gd": [COMPILER],
	INTERACTION + "state_facts.gd": [COMPILER],
	INTERACTION + "multiplayer_findings.gd": [API],
	INTERACTION + "scene_verbs.gd": [API],
	INTERACTION + "spawn_facts.gd": [API],
	"res://addons/eventsheet/editor/scene_events_facts.gd": [LIFTER],
	"res://addons/eventsheet/editor/event_sheet_viewport.gd": [API, PARAMS_DIALOG, VARIABLE_DIALOG, DOC_REFERENCE],
	"res://addons/eventsheet/editor/ace_icons.gd": [PICKER, COMPILER, LIFTER, API],
	"res://addons/eventforge/compiler/compiler_spellings.gd": [COMPILER, LIFTER, API],
	INTERACTION + "reading_doors.gd": [COMPILER, LIFTER, API, PARAMS_DIALOG, VARIABLE_DIALOG, DOC_REFERENCE],
}


static func run() -> bool:
	var graph: Dictionary = Closure.build_graph("res://addons/", Closure.DEFAULT_ROOT)
	var edges: Dictionary = graph["edges"]
	var rows: Array = []
	for path: String in FORBIDDEN:
		rows.append(["%s is in the graph" % path.get_file(), edges.has(path), true])
		var reached: PackedStringArray = edges.get(path, PackedStringArray())
		for heavy: String in (FORBIDDEN[path] as Array):
			rows.append(["%s never names %s" % [path.get_file(), heavy.get_file()], reached.has(heavy), false])
	# Every Doctor section, and the Doctor itself, registers and lists scripts through the Doctor
	# rather than through the public API that forwards to it.
	var doctor_files: int = 0
	for path: String in edges:
		if path.begins_with("res://addons/eventforge/") and path.get_file().ends_with("doctor.gd"):
			doctor_files += 1
			rows.append(["%s never names the public API" % path.get_file(),
				(edges[path] as PackedStringArray).has(API), false])
	rows.append(["the Doctor sections were found", doctor_files > 20, true])

	# 2. One source.
	rows.append(["the picker's icon table is the leaf's", ACEPickerDialog.CATEGORY_EDITOR_ICONS,
		EventSheetACEIcons.CATEGORY_EDITOR_ICONS])
	rows.append(["the picker's separator is the leaf's", ACEPickerDialog.SUBCATEGORY_SEPARATOR, ": "])
	rows.append(["a category icon name answers through the picker as through the leaf",
		ACEPickerDialog.category_icon_name("Variables: Array"), EventSheetACEIcons.category_icon_name("Variables: Array")])
	rows.append(["and splits the same way", ACEPickerDialog.split_subcategory("Variables: Array"),
		PackedStringArray(["Variables", "Array"])])
	rows.append(["the role dot is one cached texture", ACEPickerDialog.kind_dot(ACEDefinition.ACEType.CONDITION),
		EventSheetACEIcons.kind_dot(ACEDefinition.ACEType.CONDITION)])
	rows.append(["no editor theme headless, so no icon", EventSheetACEIcons.editor_icon("Node"), null])
	rows.append(["the helper prefix is the compiler's", SheetCompiler.SHARED_HELPER_PREFIX,
		CompilerSpellings.SHARED_HELPER_PREFIX])
	rows.append(["the helper prefix, spelled", CompilerSpellings.SHARED_HELPER_PREFIX, "__eventsheets_"])
	rows.append(["the travelled member is the compiler's", SheetCompiler.TRAVELLED_MEMBER,
		CompilerSpellings.TRAVELLED_MEMBER])
	rows.append(["the travelled member, spelled", CompilerSpellings.TRAVELLED_MEMBER, "_travelled"])
	var typed: EventFunction = EventFunction.new()
	typed.return_type = TYPE_INT
	var named: EventFunction = EventFunction.new()
	named.return_type_name = " Node2D "
	var variant: EventFunction = EventFunction.new()
	variant.return_type = TYPE_MAX
	for probe: Array in [[EventFunction.new(), "void"], [typed, "int"], [named, "Node2D"], [variant, "Variant"]]:
		rows.append(["the compiler spells a return type as the leaf does (%s)" % probe[1],
			SheetCompiler._function_return_type_name(probe[0]), CompilerSpellings.function_return_type_name(probe[0])])
		rows.append(["and that spelling is %s" % probe[1], CompilerSpellings.function_return_type_name(probe[0]), probe[1]])

	# 3. The doors.
	for door: Array in [[ReadingDoors.compiler(), COMPILER], [ReadingDoors.lifter(), LIFTER],
			[ReadingDoors.api(), API], [ReadingDoors.params_dialog(), PARAMS_DIALOG],
			[ReadingDoors.variable_dialog(), VARIABLE_DIALOG], [ReadingDoors.doc_reference(), DOC_REFERENCE],
			[ReadingDoors.doctor(), "res://addons/eventforge/project_doctor.gd"], [ReadingDoors.picker_dialog(), PICKER],
			[ReadingDoors.engine_reference(), "res://addons/eventsheet/editor/docs/doc_engine_reference.gd"],
			[ReadingDoors.pattern_manual(), "res://addons/eventsheet/editor/docs/doc_patterns.gd"],
			[ReadingDoors.doc_tracks(), "res://addons/eventsheet/editor/docs/doc_tracks.gd"],
			[ReadingDoors.doc_library(), "res://addons/eventsheet/editor/docs/doc_library.gd"],
			[ReadingDoors.doc_figures(), "res://addons/eventsheet/editor/docs/doc_figures.gd"]]:
		var script: Script = door[0] as Script
		rows.append(["door opens on %s" % str(door[1]).get_file(),
			script.resource_path if script != null else "", door[1]])
	rows.append(["a lifter constant reads through the door", ReadingDoors.lifter().CORE_SIGNAL_TRIGGERS,
		EventSheetACELifter.CORE_SIGNAL_TRIGGERS])
	rows.append(["a lifter static answers through the door", ReadingDoors.lifter()._is_balanced_expression("(a)"),
		EventSheetACELifter._is_balanced_expression("(a)")])
	rows.append(["a compiler static answers through the door", ReadingDoors.compiler().guard_token("Enemy AI"),
		SheetCompiler.guard_token("Enemy AI")])
	rows.append(["the variable dialog's default parse through the door",
		ReadingDoors.variable_dialog()._parse_default("Vector2", "Vector2(1, 2)"),
		VariableDialog._parse_default("Vector2", "Vector2(1, 2)")])
	rows.append(["the Doctor's shadowing rule through the door",
		ReadingDoors.doctor().shadowed_member_class(null, "position"),
		EventSheetProjectDoctor.shadowed_member_class(null, "position")])
	rows.append(["and it names the host it shadows", ReadingDoors.doctor().shadowed_member_class(null, "name"), "Node"])
	rows.append(["the picker's fuzzy match through the door", ReadingDoors.picker_dialog().fuzzy_match("stm", "set_timer"),
		ACEPickerDialog.fuzzy_match("stm", "set_timer")])
	rows.append(["a parameters dialog constant reads through the door",
		ReadingDoors.params_dialog().VARIABLE_REFERENCE_HINT, ACEParamsDialog.VARIABLE_REFERENCE_HINT])
	rows.append(["the engine reference's credit line through the door", ReadingDoors.engine_reference().CREDIT_LINE,
		EventSheetDocEngineReference.CREDIT_LINE])
	rows.append(["the figure reader's mode through the door", ReadingDoors.doc_figures().MODE_FIGURE,
		EventSheetDocFigures.MODE_FIGURE])
	# The simple verbs: the API owns the list and the workspace's vocabulary reads it from the leaf, so
	# a verb registered through the API must be the very object the leaf holds, and clearing the API's
	# list must clear what the leaf hands the registry.
	var registered: ACEDefinition = EventSheets.register_simple_ace({"id": "zz_door_probe", "kind": "action",
		"display_name": "Door probe", "template": "pass"})
	var held: Array = DockRegistry.simple_aces()
	rows.append(["a simple verb registered through the API is held by the leaf", held.has(registered), true])
	rows.append(["the leaf holds the API's own list", is_same(held, EventSheets.simple_aces()), true])
	EventSheets.simple_aces().erase(registered)
	rows.append(["and taking it off the API's list takes it off the leaf's",
		DockRegistry.simple_aces().has(registered), false])
	# The Properties bar's field factory is built with the workspace; the parameters dialog it builds
	# its fields in waits for the first field, so building the workspace does not compile the dialog.
	var factory: EventSheetParamFieldFactory = EventSheetParamFieldFactory.new()
	rows.append(["the field factory holds no dialog until a field is asked for", factory._built_dialog, null])
	var built: Dictionary = factory.build({"id": "speed", "type_name": "float", "hint": ""}, "3.5")
	rows.append(["the first field builds the dialog and a field in it", [factory._built_dialog != null,
		built.get("field") is Control], [true, true]])
	rows.append(["and the field reads back what it was given", factory.value_of(built.get("field") as Control), "3.5"])
	if built.get("control") is Node:
		(built.get("control") as Node).free()
	if factory._built_dialog is Node:
		(factory._built_dialog as Node).free()
	rows.append(["the scene readers answer an absent sheet with nothing",
		[EventSheetSceneReplication.synced_of_sheet(null).size(), EventSheetSceneReplication.spawners_of_sheet(null).size()],
		[0, 0]])
	rows.append(["and the public API forwards to them",
		[EventSheets.synced_properties(null).size(), EventSheets.spawners_of(null).size()], [0, 0]])
	rows.append(["the typed reading keeps dictionaries and drops the rest",
		EventSheetSceneReplication.typed_entries([{"name": "hp"}, 3, "x"]), [{"name": "hp"}]])
	return SUPPORT.pins(TEST_NAME, rows)
