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

const SUPPORT := preload("res://tests/support.gd")
## file -> the class identifiers that must never appear in its code lines.
const FORBIDDEN := {
	"res://addons/eventforge/plugin.gd": [
		"EventSheetWorkflow", "EventSheetProjectDoctor", "EventSheetStarterTemplates",
		"EventSheetNewSheetDialog", "ACEParamInspectorPlugin", "SheetCompiler", "EditorParamStore",
		# The documentation surface. Naming any of these at boot would pull the guide corpus, the
		# Markdown parser and (through the browser) the whole viewport and registry subtree into
		# every editor start, for a window most sessions never open.
		"EventSheetDocBrowser", "EventSheetDocPageView", "EventSheetDocLibrary",
		"EventSheetDocMarkdown", "EventSheetDocWindow", "EventSheetDocSearch",
		"EventSheetDocAceReference", "EventSheetDocFigures", "EventSheetDocExplain",
		"EventSheetDocPanel", "EventSheetDocFigure",
		# The Manual's derived half - the reference pages, the glossary, the reading position and
		# the usage counts - pulls the same subtree through the vocabulary registry.
		"EventSheetDocReference", "EventSheetDocGlossary", "EventSheetDocHistory",
		"EventSheetDocUsage", "EventSheetDocHelpTarget",
		# The Manual's batch-7 half - the tutorials, What's new, the page feedback and the per-locale
		# corpus - reaches the same parser and page model. One name shorter than it was: the Manual's
		# temporary practice sandbox was removed from the plugin.
		"EventSheetDocTutorials", "EventSheetDocWhatsNew",
		"EventSheetDocFeedback", "EventSheetDocLocale",
		# The Help DOCK is the sharpest case: add_dock takes an INSTANCE, so this node really is
		# constructed at every boot. It is loaded by path and stays an empty container until the
		# reader opens it - naming the class here would undo that by compiling its subtree anyway.
		"EventSheetDocDock",
	],
	# The dock itself is on the boot path (it is constructed there), so it obeys the same rule as
	# plugin.gd: everything it shows is reached by path on first reveal, never named in code.
	"res://addons/eventsheet/editor/docs/doc_dock.gd": [
		"EventSheetDocBrowser", "EventSheetDocPageView", "EventSheetDocLibrary",
		"EventSheetDocMarkdown", "EventSheetDocSearch", "EventSheetDocExplain",
		"EventSheetDocPanel", "EventSheetDocFigure", "EventSheetPalette", "EventSheetPopupUI",
		"EventSheetL10n", "EventSheetViewport", "EventSheetSnippet",
		"EventSheetDocReference", "EventSheetDocGlossary", "EventSheetDocHistory",
		"EventSheetDocUsage", "EventSheetDocHelpTarget",
		"EventSheetDocTutorials", "EventSheetDocWhatsNew",
		"EventSheetDocFeedback", "EventSheetDocLocale",
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
	# The export bake step registers at editor boot like the integrity hook, so it stays on plain
	# engine classes (DirAccess / FileAccess / Script) and never names a plugin class.
	"res://addons/eventforge/editor/export_tools_plugin.gd": [
		"SheetCompiler", "EventSheetWorkflow", "EventSheetProjectFind", "EventSheetTemplates",
	],
	# The Inspector drawer plugin is registered in _enter_tree and add_inspector_plugin takes an
	# INSTANCE, so both of these load at every editor start - which makes them boot files, and the
	# reason the compiler crept back onto the boot path once already: drawer_widgets named
	# SheetCompiler for three table-enum schema helpers, and that one name carried the compiler's
	# whole subtree into every session. They reach it by path through a cached accessor instead.
	"res://addons/eventsheet/editor/attribute_drawers.gd": [
		"SheetCompiler", "EventSheetWorkflow", "EventSheetProjectDoctor", "EventSheetViewport",
	],
	"res://addons/eventsheet/editor/drawer_widgets.gd": [
		"SheetCompiler", "EventSheetWorkflow", "EventSheetProjectDoctor", "EventSheetViewport",
	],
	# The Live Values bridge is constructed eagerly in _enter_tree (the transport has to be live
	# before the workspace opens), so it is a boot file too: the hit-count store it resets on every
	# new Run is reached by path, never named.
	"res://addons/eventsheet/editor/live_values_debugger.gd": [
		"EventSheetTraceHitCounts", "EventSheetTraceTimings", "EventSheetWhyPanel",
		"EventSheetViewport",
	],
	# The import hook is attached in _enter_tree like the export ones, so it is a boot file too. It
	# deliberately carries no class_name and names no plugin class; without a row here, nothing said so.
	"res://addons/eventforge/editor/import_tools_plugin.gd": [
		"SheetCompiler", "EventSheetWorkflow", "EventSheetProjectDoctor", "EventSheetViewport",
	],
}

## Every boot file, and the READING classes none of them may name.
##
## The reading layer is the plugin's heaviest subtree - the row builder, the grammar and the fact
## scanners between them reach the registry, the importer and the whole viewport - and it grew a lot
## of new entry points. Any ONE of these names in a boot file compiles all of it into every editor
## start, exactly the way the compiler crept back in through a drawer helper once already. They are
## listed separately from FORBIDDEN only so one list covers every boot file at once.
const READING_SUBTREE := [
	"EventSheetViewportReadingRows", "ViewportRowBuilder", "EventSheetSentence",
	"EventSheetObjectFacts", "EventSheetSignalFanout", "EventSheetInputMapFacts",
	"EventSheetEditorToolCensus", "EventSheetSettingFacts", "EventSheetLocalScope",
	"EventSheetVariableSentence", "EventSheetReadingCoverage", "EventSheetObjectThumbnails",
	"EventSheetPropertiesBar", "EventSheetFindResultsBar", "EventSheetTextListing",
	"EventSheetEditorToolBar", "EventSheetGlobalVariables", "EventSheetInstanceVariableTable",
	"EventSheetReplaceObject", "EventSheetParamFieldFactory",
	"EventSheetSceneSheet", "EventSheetParseErrors",
]

## Every path a deferred feature is reached through - each must exist, or the feature breaks at
## runtime on the exact click that needs it, with the whole suite green.
const LAZY_PATHS := [
	# Built on first open by the dock, never at boot: the documentation browser reaches the guide
	# bundle, the parser and a figure viewport, and a session that never opens it pays nothing.
	# Registered with add_dock at boot and loaded BY PATH there, so a rename would break the Help
	# dock's registration in the editor while the whole suite stayed green.
	"res://addons/eventsheet/editor/docs/doc_dock.gd",
	"res://addons/eventsheet/editor/docs/doc_browser.gd",
	"res://addons/eventsheet/editor/docs/doc_library.gd",
	"res://addons/eventsheet/editor/docs/doc_search.gd",
	"res://addons/eventsheet/editor/docs/doc_ace_reference.gd",
	"res://addons/eventsheet/editor/docs/doc_figures.gd",
	"res://addons/eventforge/editor/workflow_entry_points.gd",
	"res://addons/eventforge/project_doctor.gd",
	"res://addons/eventsheet/editor/dock/starter_templates.gd",
	"res://addons/eventsheet/editor/new_sheet_dialog.gd",
	"res://addons/eventsheet/editor/inspector/ace_param_inspector_plugin.gd",
	"res://addons/eventforge/compiler/sheet_compiler.gd",
	"res://addons/eventforge/sheet_templates.gd",
	"res://addons/eventforge/editor/export_tools_plugin.gd",
	# The debugger lenses and the Run Tests panel: all three are reached by a load() of a string
	# literal, so a rename would break the exact click that needs them - hit counts would quietly
	# stop resetting per Run, the Why panel would open onto nothing - with the suite still green.
	"res://addons/eventsheet/editor/trace_hit_counts.gd",
	"res://addons/eventsheet/editor/docs/doc_why_panel.gd",
	"res://addons/eventsheet/editor/dock/test_report_panel.gd",
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

	# 1b. The same lint for the reading subtree, over every boot file.
	for boot_path: String in FORBIDDEN:
		var boot_code: String = _code_only(boot_path)
		for reading_class: String in READING_SUBTREE:
			all_passed = _check("%s never names %s in code" % [boot_path.get_file(), reading_class],
				boot_code.contains(reading_class), false) and all_passed

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
	return SUPPORT.check("plugin_boot_lazy_test", label, actual, expected)
