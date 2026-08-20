@tool
class_name EventSheetEditorToolBar
extends RefCounted

# R33 - the four buttons an editor tool's Include bar carries, and what they do.
#
# A tool sheet is the one kind of sheet whose "play it" gesture is not Run Scene: an editor script is
# run from the script editor's File > Run, a plugin has to be ticked in Project Settings, and neither
# of those is anywhere near the sheet you just wrote. So the bar closes the loop where the writing
# happens - Run now, Reload, Output, Enable plugin - and writing a tool feels like writing a sheet.
#
# The split in this file is deliberate: everything the ROW BUILDER needs (which buttons this sheet
# gets, and what each says right now) is static and pure, so the bar is testable without an editor;
# everything that COMPILES OR RUNS anything is an instance method reaching back through the dock.
#
# How Output works, and why it is honest rather than magic: GDScript has no way to intercept `print`,
# so the tool's prints go where every print goes - the editor's Output panel, which also writes
# `user://logs/godot.log`. Run now therefore records the log file's LENGTH before it runs the tool and
# reads the bytes that appeared after, which is exactly "the editor Output filtered to this tool's
# prints" and nothing more. A run that produced no log delta says so rather than inventing lines.
#
# Enable plugin writes the `plugin.cfg` Godot needs beside the compiled script and ticks the plugin
# on. That is the whole registration: a Godot plugin IS a folder with a plugin.cfg plus an entry under
# `editor_plugins/enabled`, and doing it from here means a plugin sheet never has to be finished
# somewhere else. An already-registered plugin re-reads its cfg instead, which is what Reload is for.

## The button kinds, in bar order. Each is the `kind` its span carries and the branch the viewport's
## input handler switches on, so the name is a small frozen contract between the two files.
const KIND_RUN := "editor_tool_run"
const KIND_RELOAD := "editor_tool_reload"
const KIND_OUTPUT := "editor_tool_output"
const KIND_ENABLE := "editor_tool_enable"

## W9 / W10 / W11. The buttons the three TOOLING files carry. They share the `editor_tool_` prefix on
## purpose: that prefix is what the viewport's input handler already routes here, so a tooling file's
## bar is wired the moment its buttons exist. Frozen with the four above.
const KIND_TEST_RUN := "editor_tool_test_run"
const KIND_COMMAND_RUN := "editor_tool_command_run"
const KIND_PACK_BUILD := "editor_tool_pack_build"
const KIND_PACK_OPEN := "editor_tool_pack_open"

## What each check of the last headless run said, keyed by the test script's path and then by the
## check's label: {path: {label: true when it passed}}. Session state, never serialized - a fresh
## editor has run nothing, which is the truth, and every Check row starts uncoloured.
static var _checks_by_path: Dictionary = {}

## The words the last command-tool run was given after `--`, keyed by the tool's path, so pressing
## Run with arguments again offers what was typed last time rather than an empty field.
static var _arguments_by_path: Dictionary = {}

## The editor's own log, which is where a tool's prints land. Read-only here - nothing writes it.
const EDITOR_LOG_PATH := "user://logs/godot.log"

## What each tool script printed on its last Run now, keyed by the compiled script's path. Session
## state, never serialized: a fresh editor starts with an empty Output for every tool, which is the
## truth (nothing has run yet).
static var _output_by_path: Dictionary = {}

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## True for the sheets this bar belongs to: the tool family, whose host the Sheet Type dialog forces.
## Everything else (a Player sheet, an autoload, a pack) gets no buttons at all - a Run now that
## cannot run is worse than no Run now.
static func applies_to(sheet: EventSheetResource) -> bool:
	if sheet == null or not sheet.tool_mode:
		return false
	if sheet.host_class.strip_edges() in ["EditorScript", "EditorPlugin"]:
		return true
	# W17. The other editor shapes - a Properties bar add-on, an importer, a thumbnail maker, a
	# debugger panel, a context menu. They are never RUN (see runnable_sheet below), but Reload and
	# Output are exactly as useful on them: a reader edits one, reloads, and reads what it printed.
	return EventSheetScriptIntent.ADDON_HOSTS.has(sheet.host_class.strip_edges())


## True when pressing Run on this sheet would actually run something. An EditorScript runs on demand
## (that IS what it is for) and a plugin re-enters its tree; an add-on class has no entry point of its
## own - the editor calls it, and a Run now that cannot run is worse than no Run now.
static func runnable_sheet(sheet: EventSheetResource) -> bool:
	return sheet != null and sheet.host_class.strip_edges() in ["EditorScript", "EditorPlugin"]


## True when the sheet compiles to an EditorPlugin - the only kind that has a plugin to enable.
static func is_plugin_sheet(sheet: EventSheetResource) -> bool:
	return sheet != null and sheet.tool_mode and sheet.host_class.strip_edges() == "EditorPlugin"


## The bar's buttons as {kind, text}, in reading order. Static and value-driven so a test pins the
## exact words without building a viewport. `script_path` is the compiled script this sheet ships as
## ("" while the sheet is unsaved), and it only ever changes the Output count.
static func buttons_for(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var buttons: Array[Dictionary] = []
	if not applies_to(sheet):
		# W9/W10 - a file that is not an editor tool may still be a test sheet or a command
		# tool, whose own bar lives beside this one.
		return tool_file_buttons(sheet, script_path)
	if runnable_sheet(sheet):
		buttons.append({"kind": KIND_RUN, "text": "▶ " + EventSheetL10n.translate("Run now")})
	buttons.append({"kind": KIND_RELOAD, "text": "↻ " + EventSheetL10n.translate("Reload")})
	buttons.append({"kind": KIND_OUTPUT, "text": output_text(script_path)})
	if is_plugin_sheet(sheet):
		buttons.append({"kind": KIND_ENABLE, "text": EventSheetL10n.translate("Enable plugin")})
	return buttons


## W9 / W10 / W11. The bar a TOOLING file carries: a test runs, a command tool runs with arguments
## and shows what it printed, a pack recipe builds its pack and opens the built one beside it. Static
## and value-driven for the same reason the four above are - a test pins the exact words.
static func tool_file_buttons(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var buttons: Array[Dictionary] = []
	match tool_file_kind(sheet, script_path):
		EventSheetToolFiles.KIND_TEST_SHEET:
			buttons.append({"kind": KIND_TEST_RUN, "text": "%s ▸" % EventSheetL10n.translate("Run")})
		EventSheetToolFiles.KIND_COMMAND_TOOL:
			buttons.append({"kind": KIND_COMMAND_RUN,
				"text": "%s ▸" % EventSheetL10n.translate("Run with arguments…")})
			buttons.append({"kind": KIND_OUTPUT, "text": output_text(script_path)})
		EventSheetToolFiles.KIND_PACK_RECIPE:
			buttons.append({"kind": KIND_PACK_BUILD, "text": "%s ▸" % EventSheetL10n.translate("Build pack")})
			buttons.append({"kind": KIND_PACK_OPEN, "text": "%s ▸" % EventSheetL10n.translate("Open built pack")})
	return buttons


## Which of the three tooling shapes an opened sheet is, or "" for anything else. The path decides as
## much as the lines do (a test is a test because of where it lives), so it is passed through.
static func tool_file_kind(sheet: EventSheetResource, script_path: String = "") -> String:
	if sheet == null:
		return ""
	var path: String = script_path
	if path.strip_edges().is_empty():
		path = sheet.external_source_path
	return EventSheetToolFiles.kind_of(EventSheetToolFiles.lines_of_sheet(sheet), path)


## What the last headless run of `script_path` said about the check labelled `label`: true when it
## passed, false when it failed, and null when this test has not been run in this session - which is
## the state every Check row starts in and the one that colours nothing.
static func check_verdict(script_path: String, label: String) -> Variant:
	var verdicts: Dictionary = _checks_by_path.get(script_path, {})
	return verdicts.get(label, null)


## Records what one headless run said. Public so the run path and the tests use the same door.
static func record_checks(script_path: String, verdicts: Dictionary) -> void:
	_checks_by_path[script_path] = verdicts


## Forgets every recorded run, so one test's verdicts never colour another's.
static func clear_checks() -> void:
	_checks_by_path.clear()


## The verdicts a headless run's output states, as {label: passed}. The suite prints one `[PASS] …` or
## `[FAIL] …` line per check with the check's own label in it, so the label is what the two are joined
## by - the order they print in is not something a reader should have to rely on.
static func parse_check_verdicts(output: String, labels: PackedStringArray) -> Dictionary:
	var verdicts: Dictionary = {}
	for line: String in output.split("\n"):
		var text: String = line.strip_edges()
		var passed: bool = text.begins_with("[PASS]")
		if not passed and not text.begins_with("[FAIL]"):
			continue
		for label: String in labels:
			if not label.is_empty() and text.contains(label):
				verdicts[label] = passed
	return verdicts


## The one-off script a single test is run through: there is no filter flag on the suite runner, so
## running ONE test means a tiny main loop that loads it, calls `run()` and finishes with its verdict.
## Deterministic text - the same test always produces the same runner.
static func single_test_runner_source(test_path: String) -> String:
	return "\n".join(PackedStringArray([
		"@tool",
		"extends SceneTree",
		"",
		"",
		"func _init() -> void:",
		"\tvar script: Script = load(\"%s\")" % test_path,
		"\tvar passed: bool = bool(script.call(\"run\")) if script != null else false",
		"\tquit(0 if passed else 1)",
		""
	]))


## The Output button's words: the line count when this tool has run, and a plain "no output yet"
## when it has not. Never a bare "Output ▾" with nothing behind it - the arrow has to mean something.
static func output_text(script_path: String) -> String:
	var lines: PackedStringArray = output_lines(script_path)
	if lines.is_empty():
		return "%s ▾ %s" % [EventSheetL10n.translate("Output"), EventSheetL10n.translate("no output yet")]
	return "%s ▾ %d %s" % [EventSheetL10n.translate("Output"), lines.size(), EventSheetL10n.translate("lines")]


## What the tool at `script_path` printed on its last run, oldest first.
static func output_lines(script_path: String) -> PackedStringArray:
	return _output_by_path.get(script_path, PackedStringArray())


## Forgets every captured run. Called by the tests so one test's run never colours another's.
static func clear_output() -> void:
	_output_by_path.clear()


## The editor log's current length in bytes, or -1 when there is no log to read. Run now takes this
## before and after so Output shows the delta and nothing else.
static func log_length() -> int:
	if not FileAccess.file_exists(EDITOR_LOG_PATH):
		return -1
	var file: FileAccess = FileAccess.open(EDITOR_LOG_PATH, FileAccess.READ)
	if file == null:
		return -1
	var length: int = int(file.get_length())
	file.close()
	return length


## The log text written after `from_byte`, split into lines with the blank tail dropped. Returns an
## empty array when the log is unreadable or nothing was appended - both are "this run printed
## nothing", which is a fact worth showing rather than an error worth raising.
static func log_delta(from_byte: int) -> PackedStringArray:
	if from_byte < 0 or not FileAccess.file_exists(EDITOR_LOG_PATH):
		return PackedStringArray()
	var file: FileAccess = FileAccess.open(EDITOR_LOG_PATH, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	if from_byte > int(file.get_length()):
		# The editor rotated the log mid-run. Everything in the new file is this run's.
		from_byte = 0
	file.seek(from_byte)
	var appended: String = file.get_as_text()
	file.close()
	var lines: PackedStringArray = PackedStringArray()
	for line: String in appended.split("\n"):
		if not line.strip_edges().is_empty():
			lines.append(line)
	return lines


## Records what a run printed, so Output can show it. Public so the run path and the tests use the
## same door.
static func record_output(script_path: String, lines: PackedStringArray) -> void:
	_output_by_path[script_path] = lines


## The `plugin.cfg` text Godot needs beside an EditorPlugin script. Deterministic - the same sheet
## always produces the same bytes, so re-running Enable plugin never churns the file.
static func plugin_cfg_text(plugin_name: String, description: String, script_file: String) -> String:
	return "\n".join(PackedStringArray([
		"[plugin]",
		"",
		"name=\"%s\"" % plugin_name,
		"description=\"%s\"" % description.replace("\"", "'").replace("\n", " "),
		"author=\"\"",
		"version=\"1.0\"",
		"script=\"%s\"" % script_file,
		""
	]))


## The script this sheet ships as: the `.gd` a `.gd`-backed sheet already IS, or the sibling a `.tres`
## compiles to. "" while the sheet has never been saved, which is the one state the bar refuses to
## act in - there is nothing on disk to run, reload or register.
func script_path() -> String:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return ""
	if not sheet.external_source_path.is_empty():
		return sheet.external_source_path
	if not _dock._current_sheet_path.is_empty():
		return _dock._current_sheet_path.get_basename() + ".gd"
	return ""


## Dispatches one bar button. Returns true when the click was handled, so the viewport's input branch
## stays a one-liner and every "why did nothing happen" answer is written here, once.
func activate(kind: String) -> bool:
	match kind:
		KIND_RUN:
			run_now()
		KIND_RELOAD:
			reload()
		KIND_OUTPUT:
			show_output()
		KIND_ENABLE:
			enable_plugin()
		KIND_TEST_RUN:
			run_test()
		KIND_COMMAND_RUN:
			ask_for_arguments()
		KIND_PACK_BUILD:
			build_pack()
		KIND_PACK_OPEN:
			open_built_pack()
		_:
			return false
	return true


## W9. Run ▸ on a test sheet's bar: runs THIS test, headless, in a second copy of the very editor
## binary that is running now - which is exactly what the suite does, so a row that says it passed
## here passes there. Each Check row is then coloured from the `[PASS]` / `[FAIL]` lines the run
## printed, matched by the check's own label.
func run_test() -> void:
	var target: String = script_path()
	if target.is_empty():
		_dock._set_status("Save the sheet first - Run needs a test on disk to run.", true)
		return
	var runner_path: String = "user://eventforge_run_one_test.gd"
	var runner: FileAccess = FileAccess.open(runner_path, FileAccess.WRITE)
	if runner == null:
		_dock._set_status("Couldn't write the one-off runner this test would be run through.", true)
		return
	runner.store_string(single_test_runner_source(target))
	runner.close()
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", ProjectSettings.globalize_path(runner_path),
	]), output, true, false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(runner_path))
	var printed: String = "\n".join(PackedStringArray(output))
	record_output(target, _printed_lines(printed))
	record_checks(target, parse_check_verdicts(printed, check_labels()))
	_dock._refresh_after_edit()
	if exit_code == 0:
		_dock._set_status("%s passed." % target.get_file())
	else:
		_dock._set_status("%s failed - the checks that did not pass are marked on their rows." % target.get_file(), true)


## Every check label the open test states, in file order - the labels the run's output is matched
## against, and the same list the head's check count is taken from.
func check_labels() -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for check: Dictionary in EventSheetToolFiles.checks(
			EventSheetToolFiles.lines_of_sheet(_dock._current_sheet)):
		labels.append(EventSheetToolFiles.bare_label(str(check.get("label", ""))))
	return labels


## The lines a spawned run printed, blank tail dropped - the same shape `log_delta` returns, so
## Output shows a spawned run and an in-process one identically.
static func _printed_lines(printed: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in printed.split("\n"):
		if not line.strip_edges().is_empty():
			lines.append(line)
	return lines


## W10. Run with arguments… ▸ : asks for the words that would follow `--` on the command line, then
## runs the tool headless in this same editor binary and files what it printed under Output.
func ask_for_arguments() -> void:
	var target: String = script_path()
	if target.is_empty():
		_dock._set_status("Save the sheet first - Run needs a tool on disk to run.", true)
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = EventSheetL10n.translate("Run with arguments…")
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"The words that would follow -- on the command line. This tool runs headless, in a second copy of this editor."), 480.0))
	var field: LineEdit = LineEdit.new()
	field.text = str(_arguments_by_path.get(target, ""))
	body.add_child(field)
	dialog.add_child(EventSheetPopupUI.margined(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("Arguments"), body)))
	dialog.confirmed.connect(func() -> void:
		_arguments_by_path[target] = field.text
		run_command_tool(target, field.text)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	_dock.add_child(dialog)
	dialog.popup_centered()


## Runs one command tool headless with the words given, and files what it printed under Output.
func run_command_tool(target: String, arguments: String) -> void:
	var command: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", ProjectSettings.globalize_path(target),
	])
	var typed: PackedStringArray = arguments.split(" ", false)
	if not typed.is_empty():
		command.append("--")
		command.append_array(typed)
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), command, output, true, false)
	var printed: PackedStringArray = _printed_lines("\n".join(PackedStringArray(output)))
	record_output(target, printed)
	_dock._refresh_after_edit()
	_dock._set_status("%s finished with code %d - %d line(s) in Output." % [target.get_file(), exit_code, printed.size()])


## W11. Build pack ▸ : runs THIS recipe's `build()` and nothing else, so a reader changing one pack
## never waits for the other ninety-four.
func build_pack() -> void:
	var target: String = script_path()
	if target.is_empty():
		_dock._set_status("Save the recipe first - Build pack runs the recipe on disk.", true)
		return
	var recipe: Script = ResourceLoader.load(target, "Script", ResourceLoader.CACHE_MODE_IGNORE) as Script
	if recipe == null:
		_dock._set_status("Couldn't build %s to run it." % target.get_file(), true)
		return
	var before: int = log_length()
	var built: bool = bool(recipe.call(EventSheetToolFiles.RECIPE_ENTRY_NAME))
	record_output(target, log_delta(before))
	EditorInterface.get_resource_filesystem().scan()
	_dock._refresh_after_edit()
	if built:
		_dock._set_status("Built %s." % built_pack_path(_dock._current_sheet).get_base_dir().get_file())
	else:
		_dock._set_status("%s did not build - Output has what it printed." % target.get_file(), true)


## W11. Open built pack ▸ : opens the pack this recipe emits, beside the recipe, for the comparison
## the drift gate makes in one direction and a reader makes in the other.
func open_built_pack() -> void:
	var built: String = built_pack_path(_dock._current_sheet)
	if built.is_empty() or not FileAccess.file_exists(built):
		_dock._set_status("This recipe has not been built yet - press Build pack first.", true)
		return
	_dock._load_sheet_from_path(built)


## The `.gd` a recipe emits: the base path it hands `save_pack`, plus the extension a pack ships
## with. "" when the recipe never says where it saves.
static func built_pack_path(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var base: String = EventSheetToolFiles.recipe_pack_id(EventSheetToolFiles.lines_of_sheet(sheet))
	return "" if base.is_empty() else "%s.gd" % base


## Run now (Ctrl+Shift+X). Compiles the sheet to its script, builds it, and calls `_run()` - the same
## entry point the script editor's File > Run invokes, so a tool behaves identically either way.
## Prints are captured from the editor log delta and land in Output.
func run_now() -> void:
	var target: String = script_path()
	if target.is_empty():
		_dock._set_status("Save the sheet first - Run now needs a script on disk to run.", true)
		return
	if is_plugin_sheet(_dock._current_sheet):
		_dock._set_status("A plugin runs when it is enabled, not on demand - use Enable plugin, then Reload after each change.", true)
		return
	var compile_result: Dictionary = SheetCompiler.compile(_dock._current_sheet, target)
	if not bool(compile_result.get("success", false)):
		_dock._set_status("This tool doesn't compile yet, so there is nothing to run. (%s)" % ", ".join(PackedStringArray(compile_result.get("errors", []))), true)
		return
	var script: Script = ResourceLoader.load(target, "Script", ResourceLoader.CACHE_MODE_IGNORE) as Script
	if script == null or not script.can_instantiate():
		_dock._set_status("Couldn't build %s to run it." % target.get_file(), true)
		return
	var before: int = log_length()
	var instance: Object = script.new() as Object
	if instance == null:
		# EditorScript can only be built while an editor is running - say that rather than a blank fail.
		_dock._set_status("An editor tool can only run inside the Godot editor.", true)
		return
	instance.call("_run")
	var printed: PackedStringArray = log_delta(before)
	record_output(target, printed)
	_dock._refresh_after_edit()
	if printed.is_empty():
		_dock._set_status("Ran %s. It printed nothing." % target.get_file())
	else:
		_dock._set_status("Ran %s - %d line(s) in Output." % [target.get_file(), printed.size()])


## Reload: re-reads the compiled script from disk (and, for a registered plugin, re-registers it) so
## a change takes effect without toggling the plugin off and on again in Project Settings.
func reload() -> void:
	var target: String = script_path()
	if target.is_empty():
		_dock._set_status("Save the sheet first - Reload re-reads the script on disk.", true)
		return
	var compile_result: Dictionary = SheetCompiler.compile(_dock._current_sheet, target)
	if not bool(compile_result.get("success", false)):
		_dock._set_status("This tool doesn't compile yet, so the old script is still what is loaded. (%s)" % ", ".join(PackedStringArray(compile_result.get("errors", []))), true)
		return
	var script: Script = ResourceLoader.load(target, "Script", ResourceLoader.CACHE_MODE_IGNORE) as Script
	if script != null:
		script.reload(true)
	var folder: String = plugin_folder_name(target)
	if not folder.is_empty() and is_plugin_sheet(_dock._current_sheet) and EditorInterface.is_plugin_enabled(folder):
		# Off and straight back on is the only way to make the editor build a fresh plugin instance -
		# and it is exactly what a reader would otherwise do by hand in Project Settings.
		EditorInterface.set_plugin_enabled(folder, false)
		EditorInterface.set_plugin_enabled(folder, true)
		_dock._set_status("Reloaded %s and re-registered the plugin." % target.get_file())
		return
	_dock._set_status("Reloaded %s from disk." % target.get_file())


## Output: the editor's Output panel filtered to this tool's prints - the lines the log gained while
## Run now was running, and nothing else.
func show_output() -> void:
	var target: String = script_path()
	var lines: PackedStringArray = output_lines(target)
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = EventSheetL10n.translate("Output")
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	if lines.is_empty():
		body.add_child(EventSheetPopupUI.hint_label(
			EventSheetL10n.translate("Nothing yet. Press Run now and this fills with what the tool printed."), 480.0))
	else:
		var log_view: TextEdit = TextEdit.new()
		log_view.editable = false
		log_view.text = "\n".join(lines)
		log_view.custom_minimum_size = Vector2(520.0, 260.0)
		body.add_child(log_view)
	dialog.add_child(EventSheetPopupUI.margined(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("What this tool printed"), body)))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	_dock.add_child(dialog)
	dialog.popup_centered()


## Enable plugin: writes the plugin.cfg Godot needs beside the compiled script and ticks the plugin
## on. Both halves are idempotent - an unchanged cfg is not rewritten, and an already-enabled plugin
## is left alone - so pressing this twice is a no-op rather than a churned file.
func enable_plugin() -> void:
	var target: String = script_path()
	if target.is_empty():
		_dock._set_status("Save the sheet first - a plugin is a folder with a script and a plugin.cfg in it.", true)
		return
	var folder: String = plugin_folder_name(target)
	if folder.is_empty():
		_dock._set_status("A plugin has to live in its own folder under res://addons/ - save this sheet there first.", true)
		return
	var compile_result: Dictionary = SheetCompiler.compile(_dock._current_sheet, target)
	if not bool(compile_result.get("success", false)):
		_dock._set_status("This plugin doesn't compile yet, so it was not enabled. (%s)" % ", ".join(PackedStringArray(compile_result.get("errors", []))), true)
		return
	var plugin_name: String = _dock._current_sheet.custom_class_name.strip_edges()
	if plugin_name.is_empty():
		plugin_name = folder.capitalize()
	var cfg_path: String = target.get_base_dir().path_join("plugin.cfg")
	var wanted: String = plugin_cfg_text(plugin_name, _dock._current_sheet.class_description, target.get_file())
	if not FileAccess.file_exists(cfg_path) or FileAccess.get_file_as_string(cfg_path) != wanted:
		var file: FileAccess = FileAccess.open(cfg_path, FileAccess.WRITE)
		if file == null:
			_dock._set_status("Couldn't write %s." % cfg_path, true)
			return
		file.store_string(wanted)
		file.close()
		EditorInterface.get_resource_filesystem().scan()
	if EditorInterface.is_plugin_enabled(folder):
		_dock._set_status("%s is already enabled - use Reload to pick up your changes." % plugin_name)
		return
	EditorInterface.set_plugin_enabled(folder, true)
	_dock._refresh_after_edit()
	_dock._set_status("%s is on. Project Settings ▸ Plugins can switch it off again." % plugin_name)


## Where a compiled plugin script's folder sits relative to res://addons, as Godot's enabled-plugins
## list spells it ("res://addons/<folder>/plugin.cfg" -> "<folder>"). "" when the script does not
## live under res://addons at all, which is the one case Enable plugin cannot help with.
static func plugin_folder_name(script_path: String) -> String:
	var directory: String = script_path.get_base_dir()
	if not directory.begins_with("res://addons/"):
		return ""
	return directory.trim_prefix("res://addons/")
