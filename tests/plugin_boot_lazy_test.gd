# EventForge - plugin boot stays lazy (the fast-load contract)
#
# Enabling the plugin used to compile ~2 seconds of GDScript at EVERY editor boot, because the
# boot-path scripts (plugin.gd + the context-menu / inspector / export plugins it registers)
# named heavy classes - and naming a global class anywhere in a script compiles that class's
# whole dependency subtree (the importer, the compiler, the registry) the moment the script
# loads. Those references now load BY PATH at call time.
#
# This test pins the contract two ways, order-independently (millisecond pins would be flaky):
#   1. A source lint: the boot-path files must not name the heavy classes in CODE (comments are
#      fine - they create no compile dependency).
#   2. The lazy paths must exist and dispatch: a renamed file would otherwise only fail at
#      runtime, in the editor, on the exact click that needs it.
@tool
class_name PluginBootLazyTest
extends RefCounted

## file -> the class identifiers that must never appear in its code lines.
const FORBIDDEN := {
	"res://addons/eventforge/plugin.gd": [
		"EventSheetWorkflow", "EventSheetProjectDoctor", "EventSheetStarterTemplates",
		"EventSheetNewSheetDialog", "ACEParamInspectorPlugin", "SheetCompiler", "EditorParamStore",
	],
	"res://addons/eventforge/editor/context_menu_plugin.gd": [
		"EventSheetWorkflow", "EventSheetProjectDoctor",
	],
	"res://addons/eventforge/editor/sheet_edit_inspector_plugin.gd": [
		"EventSheetProjectDoctor",
	],
	"res://addons/eventforge/editor/export_integrity_plugin.gd": [
		"SheetCompiler", "EventSheetTemplates",
	],
}

## Every path the boot scripts lazily load - each must exist, or the deferred feature breaks
## at runtime on the exact click that needs it.
const LAZY_PATHS := [
	"res://addons/eventforge/editor/workflow_entry_points.gd",
	"res://addons/eventforge/project_doctor.gd",
	"res://addons/eventsheet/editor/dock/starter_templates.gd",
	"res://addons/eventsheet/editor/new_sheet_dialog.gd",
	"res://addons/eventsheet/editor/inspector/ace_param_inspector_plugin.gd",
	"res://addons/eventforge/compiler/sheet_compiler.gd",
	"res://addons/eventforge/sheet_templates.gd",
]


static func run() -> bool:
	var all_passed: bool = true

	# 1. Source lint: no heavy class names in the boot files' CODE lines.
	for path: String in FORBIDDEN:
		var code: String = _code_only(path)
		all_passed = _check("boot file readable: %s" % path.get_file(), code.is_empty(), false) and all_passed
		for identifier: String in (FORBIDDEN[path] as Array):
			all_passed = _check("%s never names %s in code" % [path.get_file(), identifier],
				code.contains(identifier), false) and all_passed

	# 2. The lazy targets exist and the load-by-path dispatch works.
	for lazy_path: String in LAZY_PATHS:
		all_passed = _check("lazy target exists: %s" % lazy_path.get_file(), ResourceLoader.exists(lazy_path), true) and all_passed
	var workflow: Script = load("res://addons/eventforge/editor/workflow_entry_points.gd")
	all_passed = _check("lazy static dispatch works (non-sheet path refused)",
		workflow.is_openable_as_sheet("res://not_a_sheet.txt"), false) and all_passed
	var doctor: Script = load("res://addons/eventforge/project_doctor.gd")
	all_passed = _check("lazy doctor dispatch works (unknown script has no sheet)",
		doctor.sheet_for_script("res://nope_never_generated.gd"), "") and all_passed

	return all_passed


## The file's code lines only - comment lines create no compile dependency, so docstrings may
## keep naming the classes they describe.
static func _code_only(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var code_lines: PackedStringArray = PackedStringArray()
	while not file.eof_reached():
		var line: String = file.get_line()
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		# Trailing comments after code: cut at the first # that is not inside a string. A cheap
		# heuristic (split on '#' when the prefix has an even number of quotes) covers this
		# codebase's style - no boot file embeds '#' inside a string on a code line.
		var hash_index: int = line.find("#")
		if hash_index >= 0 and line.left(hash_index).count("\"") % 2 == 0:
			line = line.left(hash_index)
		code_lines.append(line)
	return "\n".join(code_lines)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] plugin_boot_lazy_test: %s" % label)
		return true
	print("[FAIL] plugin_boot_lazy_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
