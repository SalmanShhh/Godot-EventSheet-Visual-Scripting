# EventForge - the On Project Export bake step, end to end.
#
# The seam has two halves and this pins both:
#   1. The SHEET half. On Project Export is a real trigger: it resolves to its own plain handler,
#      carries the "runs once" tempo, compiles into an Editor Tool script as
#      `func _on_project_export(is_debug: bool, features: PackedStringArray)`, and lifts back out of a
#      GDScript-backed sheet from that exact header. Its three companion verbs (Write Version Stamp,
#      Export Is Debug, Export Has Feature) compile inside that handler, where `is_debug` and
#      `features` are in scope.
#      Both are trigger-SCOPED: they read the handler's own arguments, so they lift inside it and
#      nowhere else - `is_debug` is a bare identifier, and it must not claim `if is_debug:` in an
#      ordinary game script.
#   2. The PLUGIN half. The export hook finds the Editor Tool scripts that declared the handler -
#      recursing into subfolders, in sorted order, never into `addons` or `.godot` - and calls it with
#      the export's flags. Just as importantly it leaves everything else alone: a Node script is never
#      instantiated (it would leak an orphan node), and a file that merely QUOTES the header (this one
#      does, three lines down) is never even constructed, because reflection settles that before
#      `new()` is reached. A handler that awaits is reported as unfinished, because an export cannot
#      wait for one. The tool script it runs is a REAL file on disk, loaded and executed, and it
#      records the arguments it received so the flags are proven, not assumed.
@tool
class_name ProjectExportBakeTest
extends RefCounted

const EXPORT_TOOLS := preload("res://addons/eventforge/editor/export_tools_plugin.gd")
const CODEGEN := preload("res://addons/eventforge/compiler/action_codegen.gd")
const TEMP_DIR := "user://eventforge_export_bake_test"
const HANDLER_HEADER := "func _on_project_export(is_debug: bool, features: PackedStringArray) -> void:"


static func run() -> bool:
	var ok: bool = true

	# ── 1. The trigger resolves to its own handler ──
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProjectExport"
	var signature: Dictionary = TriggerResolver.resolve_trigger(event)
	ok = _check("On Project Export resolves to its handler", str(signature.get("function_name")), "_on_project_export") and ok
	ok = _check("the handler receives the export flags", str(signature.get("args")), "is_debug: bool, features: PackedStringArray") and ok
	ok = _check("it is not signal-backed (nothing to connect)", str(signature.get("signal_name")), "") and ok
	ok = _check("its tempo badge says it runs once", TriggerResolver.tempo_class_for("OnProjectExport"), TriggerResolver.TEMPO_ONCE) and ok

	# ── 2. The vocabulary ──
	var descriptors: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeToolingACEs.get_descriptors():
		descriptors[descriptor.ace_id] = descriptor
	# Re-pin: the Editor Tools vocabulary now sits on PAGES, and the two moments the editor calls
	# a tool without being asked (a file imported, an export starting) share one. Still under the
	# "Editor Tools" root, which is what the tool-sheet gate and the Editor object label test.
	ok = _check("On Project Export is on the Editor Tools import-and-export page",
		str((descriptors.get("OnProjectExport", ACEDescriptor.new()) as ACEDescriptor).category),
		"Editor Tools: Import & export") and ok
	ok = _check("Export Is Debug reads the flag verbatim",
		str((descriptors.get("ExportIsDebug", ACEDescriptor.new()) as ACEDescriptor).codegen_template), "is_debug") and ok
	ok = _check("Export Has Feature reads the preset's tags",
		str((descriptors.get("ExportHasFeature", ACEDescriptor.new()) as ACEDescriptor).codegen_template), "features.has({feature})") and ok
	ok = _check("the feature param offers the live tag list",
		_param_hint(descriptors.get("ExportHasFeature", null), "feature"), "feature_tag") and ok

	# ── 3. The whole event compiles into the handler ──
	var compile_result: Dictionary = _compile_bake_sheet()
	var compiled: String = str(compile_result.get("output", ""))
	ok = _check("the sheet compiles", bool(compile_result.get("success", false)), true) and ok
	# The handler must sit at FILE scope. `contains` alone cannot tell that: the same substring is
	# still there if the compiler ever emitted the header indented inside another function.
	ok = _check("the handler is declared at file scope", compiled.contains("\n%s\n" % HANDLER_HEADER), true) and ok
	ok = _check("the compiled tool is an editor script", compiled.contains("extends EditorScript"), true) and ok
	ok = _check("both flags guard the body",
		compiled.contains("\tif is_debug and features.has(\"mobile\"):"), true) and ok
	ok = _check("the version stamp is written", compiled.contains(".save(\"res://build_stamp.cfg\")"), true) and ok
	ok = _check("no plugin path leaks into the generated script", compiled.contains("res://addons/"), false) and ok
	ok = _check("nothing is preloaded from the plugin", compiled.contains("preload("), false) and ok

	# The one artefact this feature produces, handed to the engine rather than to `contains`: a tool
	# that does not parse is not a bake step, and the hook's own reflection must find the handler on
	# the compiled script - that is the join between the two halves.
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var compiled_path: String = TEMP_DIR + "/compiled_bake_tool.gd"
	_write_script(compiled_path, PackedStringArray([compiled]))
	var compiled_script: GDScript = load(compiled_path) as GDScript
	ok = _check("the compiled tool parses", compiled_script != null, true) and ok
	if compiled_script != null:
		ok = _check("and the export hook finds the handler on it by reflection",
			EXPORT_TOOLS._declares_hook(compiled_script), true) and ok

	# ── 4. The handler lifts back out of a GDScript-backed sheet ──
	ok = _check("the lifter recognises the handler header",
		str(EventSheetACELifter.LIFECYCLE_TRIGGERS.get(HANDLER_HEADER, "")), "OnProjectExport") and ok
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(compiled)
	var reopened_event: EventRow = _first_event(reopened)
	ok = _check("the compiled tool reopens as one event", reopened_event != null, true) and ok
	if reopened_event != null:
		ok = _check("on the On Project Export trigger", reopened_event.trigger_id, "OnProjectExport") and ok
		ok = _check("with both flag conditions back as rows",
			_condition_ids(reopened_event), "ExportIsDebug,ExportHasFeature") and ok

	# Both flag conditions read the HANDLER'S OWN ARGUMENTS, so they are only offered inside it.
	# `is_debug` is a bare identifier: admitted to the reverse index everywhere, it would claim
	# `if is_debug:` in any ordinary game script and label the row "the export is a debug build".
	var entries: Array = EventSheetACELifter._build_reverse_entries()
	ok = _check("inside its own handler, `is_debug` is the export condition",
		str(EventSheetACELifter._match_entry("is_debug", entries, "condition", true, "OnProjectExport").get("ace_id", "")),
		"ExportIsDebug") and ok
	# Elsewhere the generic readings win it back - which is the point: the row still says something
	# true about the line, instead of announcing an export flag inside a game script.
	ok = _check("in any other function it is just an expression that is true",
		str(EventSheetACELifter._match_entry("is_debug", entries, "condition", true, "OnProcess").get("ace_id", "")),
		"ExpressionIsTrue") and ok
	ok = _check("and a features.has(...) elsewhere is just a lookup",
		str(EventSheetACELifter._match_entry("features.has(\"mobile\")", entries, "condition", true, "OnReady").get("ace_id", "")),
		"DictHasKey") and ok

	# ── 5. Write Version Stamp, run for real ──
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var stamp_path: String = TEMP_DIR + "/build_stamp.cfg"
	var stamp: ACEDescriptor = descriptors.get("WriteVersionStamp", null)
	ok = _check("Write Version Stamp is registered", stamp != null, true) and ok
	if stamp != null:
		ok = _check("its emitted code bakes no timestamp",
			stamp.codegen_template.contains("Time.get_datetime_string_from_system(true)"), true) and ok
		_run_statements(CODEGEN._apply_template(stamp.codegen_template, {
			"uid": "3", "path": "\"%s\"" % stamp_path, "version": "\"1.4.2\"",
		}), "stamp")
		var written: ConfigFile = ConfigFile.new()
		ok = _check("the stamp file loads", written.load(stamp_path), OK) and ok
		ok = _check("the stamp records the version", str(written.get_value("build", "version", "")), "1.4.2") and ok
		ok = _check("the stamp records when it was written",
			str(written.get_value("build", "stamped_at", "")).length() >= 19, true) and ok

	# ── 6a. Discovery: declaring the handler IS the opt-in ──
	var discovery_dir: String = TEMP_DIR + "/discovery"
	DirAccess.make_dir_recursive_absolute(discovery_dir)
	var editor_tool_path: String = discovery_dir + "/bake_tool.gd"
	_write_script(editor_tool_path, PackedStringArray([
		"@tool", "extends EditorScript", "", "",
		HANDLER_HEADER,
		"\tprint(is_debug, features)",
	]))
	# An Editor Tool that never declared the trigger stays a File > Run chore.
	_write_script(discovery_dir + "/plain_tool.gd", PackedStringArray([
		"@tool", "extends EditorScript", "", "",
		"func _run() -> void:",
		"\tpush_error(\"a tool without the trigger must never be run as a bake step\")",
	]))
	# A tool in a SUBFOLDER, which is where a real project keeps them (res://tools/bake.gd). It is
	# also named so that alphabetical order and discovery order disagree - the walk always yields a
	# folder's own files before descending, so "apex" coming out first can only be the sort.
	var nested_dir: String = discovery_dir + "/apex"
	DirAccess.make_dir_recursive_absolute(nested_dir)
	var nested_tool_path: String = nested_dir + "/nested_tool.gd"
	_write_script(nested_tool_path, PackedStringArray([
		"@tool", "extends RefCounted", "", "",
		HANDLER_HEADER,
		"\tprint(is_debug, features)",
	]))
	ok = _check("the scan recurses into subfolders, and runs in sorted path order",
		", ".join(EXPORT_TOOLS.find_export_tools(discovery_dir)),
		"%s, %s" % [nested_tool_path, editor_tool_path]) and ok

	# ── 6c. The skipped roots, against the real project ──
	# `.godot` is the import cache and `addons` is plugin code (this plugin included): walking them
	# would read - and then construct - scripts that are nobody's bake step. The same scan proves the
	# walk really reached the project, by finding the one res:// file that mentions the handler.
	var project_hits: PackedStringArray = EXPORT_TOOLS.find_export_tools("res://")
	var skipped_root_hits: PackedStringArray = PackedStringArray()
	for hit: String in project_hits:
		if hit.begins_with("res://addons") or hit.begins_with("res://.godot"):
			skipped_root_hits.append(hit)
	ok = _check("no plugin or import-cache script is ever discovered", ", ".join(skipped_root_hits), "") and ok
	ok = _check("while the project itself is really walked",
		Array(project_hits).has("res://tests/project_export_bake_test.gd"), true) and ok

	# ── 6b. The fan-out: the handler runs and receives the export's real flags ──
	# The tool here is RefCounted-hosted rather than an EditorScript, because the engine only lets an
	# EditorScript be instantiated while an editor is running - true during every export, including
	# the headless one CI runs, but not in a plain `--script` suite. Same discovery, same call.
	var run_dir: String = TEMP_DIR + "/run"
	DirAccess.make_dir_recursive_absolute(run_dir)
	var receipt_path: String = TEMP_DIR + "/receipt.txt"
	var tool_path: String = run_dir + "/bake_tool.gd"
	_write_script(tool_path, PackedStringArray([
		"@tool", "extends RefCounted", "", "",
		HANDLER_HEADER,
		"\tvar file: FileAccess = FileAccess.open(\"%s\", FileAccess.WRITE)" % receipt_path,
		"\tfile.store_string(\"%s|%s\" % [str(is_debug), \",\".join(features)])",
		"\tfile.close()",
	]))
	# A node script carrying the same function must never be instantiated - new() on a Node leaks an
	# orphan into the editor, and a game script is not a bake step.
	_write_script(run_dir + "/node_with_handler.gd", PackedStringArray([
		"@tool", "extends Node", "", "",
		HANDLER_HEADER,
		"\tpush_error(\"a node script must never be run as a bake step\")",
	]))
	# Discovery is a TEXT match, so a file that merely quotes the header - this very test file does -
	# reaches the run. Nothing may be constructed to find that out: the _init here leaves a receipt,
	# and that receipt must never appear.
	var construction_path: String = TEMP_DIR + "/must_not_construct.txt"
	_write_script(run_dir + "/mentions_only.gd", PackedStringArray([
		"@tool", "extends RefCounted", "", "",
		"const HEADER := \"%s\"" % HANDLER_HEADER, "", "",
		"func _init() -> void:",
		"\tvar file: FileAccess = FileAccess.open(\"%s\", FileAccess.WRITE)" % construction_path,
		"\tfile.store_string(\"constructed\")",
		"\tfile.close()",
	]))

	var report: Dictionary = EXPORT_TOOLS.run_export_tools(PackedStringArray(["mobile", "etc"]), true, run_dir)
	var ran_scripts: PackedStringArray = report.get("scripts", PackedStringArray())
	ok = _check("one tool ran", int(report.get("ran", -1)), 1) and ok
	ok = _check("the node script and the text-only match were both refused", int(report.get("skipped", -1)), 2) and ok
	ok = _check("and neither of them was ever constructed", FileAccess.file_exists(construction_path), false) and ok
	ok = _check("the run is reported by path", ", ".join(ran_scripts), tool_path) and ok
	ok = _check("the tool received the export flags", FileAccess.get_file_as_string(receipt_path), "true|mobile,etc") and ok
	ok = _check("a synchronous tool finishes before the export continues", int(report.get("unfinished", -1)), 0) and ok

	# The flags are passed through, not hard-coded: a release export arrives as one.
	DirAccess.remove_absolute(receipt_path)
	EXPORT_TOOLS.run_export_tools(PackedStringArray(["windows"]), false, run_dir)
	ok = _check("a release export arrives as a release", FileAccess.get_file_as_string(receipt_path), "false|windows") and ok

	# ── 6d. A handler that awaits cannot be waited for ──
	# An export does not pause for a coroutine: the engine hands back a GDScriptFunctionState the
	# moment the handler suspends and the exporter carries on packaging files. Everything before the
	# await has run; everything after it has not, and may miss the build entirely. The hook has to say
	# so rather than count it as a clean run - silence here is a bake step that half happened.
	var await_dir: String = TEMP_DIR + "/awaits"
	DirAccess.make_dir_recursive_absolute(await_dir)
	var before_await_path: String = TEMP_DIR + "/before_await.txt"
	var after_await_path: String = TEMP_DIR + "/after_await.txt"
	_write_script(await_dir + "/awaiting_tool.gd", PackedStringArray([
		"@tool", "extends RefCounted", "", "",
		"signal never_fires", "", "",
		HANDLER_HEADER,
		"\tvar before: FileAccess = FileAccess.open(\"%s\", FileAccess.WRITE)" % before_await_path,
		"\tbefore.store_string(\"%s\" % is_debug)",
		"\tbefore.close()",
		"\tawait never_fires",
		"\tvar after: FileAccess = FileAccess.open(\"%s\", FileAccess.WRITE)" % after_await_path,
		"\tafter.store_string(\"packaged too late\")",
		"\tafter.close()",
	]))
	var await_report: Dictionary = EXPORT_TOOLS.run_export_tools(PackedStringArray(["web"]), false, await_dir)
	ok = _check("the work before the await did happen", FileAccess.get_file_as_string(before_await_path), "false") and ok
	ok = _check("the work after it did not", FileAccess.file_exists(after_await_path), false) and ok
	ok = _check("so the tool is reported as unfinished", int(await_report.get("unfinished", -1)), 1) and ok
	ok = _check("and not as skipped either - it did start", int(await_report.get("skipped", -1)), 0) and ok

	# Nothing to do in a project with no bake steps.
	var empty_root: String = TEMP_DIR + "/empty"
	DirAccess.make_dir_recursive_absolute(empty_root)
	ok = _check("a project with no bake steps runs nothing",
		int(EXPORT_TOOLS.run_export_tools(PackedStringArray(), false, empty_root).get("ran", -1)), 0) and ok

	_clear_temp_dirs()
	return ok


## The first EventRow in a reopened sheet, or null - the lift keeps trailing function/comment rows
## as their own resources, so the events cannot simply be indexed.
static func _first_event(sheet: EventSheetResource) -> EventRow:
	if sheet == null:
		return null
	for row: Variant in sheet.events:
		if row is EventRow:
			return row as EventRow
	return null


## An event's conditions as "AceId,AceId" - a dropped or misattributed row reads as a plain diff.
static func _condition_ids(event: EventRow) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for condition: Variant in event.conditions:
		if condition is ACECondition:
			ids.append(str((condition as ACECondition).ace_id))
	return ",".join(ids)


## An Editor Tool sheet whose export bake step is gated on both flags and writes a version stamp.
static func _compile_bake_sheet() -> Dictionary:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProjectExport"
	var is_debug: ACECondition = ACECondition.new()
	is_debug.provider_id = "Core"
	is_debug.ace_id = "ExportIsDebug"
	event.conditions.append(is_debug)
	var has_feature: ACECondition = ACECondition.new()
	has_feature.provider_id = "Core"
	has_feature.ace_id = "ExportHasFeature"
	has_feature.params = {"feature": "\"mobile\""}
	event.conditions.append(has_feature)
	var write_stamp: ACEAction = ACEAction.new()
	write_stamp.provider_id = "Core"
	write_stamp.ace_id = "WriteVersionStamp"
	write_stamp.params = {"path": "\"res://build_stamp.cfg\"", "version": "\"1.0.0\"", "uid": "9"}
	event.actions.append(write_stamp)
	sheet.events.append(event)
	return SheetCompiler.compile(sheet, "")


## Runs emitted statements for real: written to a script file and loaded, so what runs is exactly
## what a compiled sheet would run.
static func _run_statements(statements: String, name: String) -> void:
	var lines: PackedStringArray = PackedStringArray(["@tool", "extends RefCounted", "", "", "static func go() -> void:"])
	for line: String in statements.split("\n"):
		lines.append("\t" + line)
	var script_path: String = TEMP_DIR + "/%s_probe.gd" % name
	_write_script(script_path, lines)
	var script: GDScript = load(script_path) as GDScript
	if script != null:
		script.call("go")


static func _write_script(path: String, lines: PackedStringArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


static func _param_hint(descriptor: ACEDescriptor, param_id: String) -> String:
	if descriptor == null:
		return "<missing descriptor>"
	for param: ACEParam in descriptor.params:
		if param.id == param_id:
			return str(param.hint)
	return "<missing>"


static func _clear_temp_dirs() -> void:
	for folder: String in [TEMP_DIR + "/empty", TEMP_DIR + "/discovery/apex", TEMP_DIR + "/discovery", TEMP_DIR + "/awaits", TEMP_DIR + "/run", TEMP_DIR]:
		var dir: DirAccess = DirAccess.open(folder)
		if dir == null:
			continue
		for entry: String in dir.get_files():
			DirAccess.remove_absolute(folder + "/" + entry)
		DirAccess.remove_absolute(folder)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] project_export_bake_test: %s" % label)
		return true
	print("[FAIL] project_export_bake_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
