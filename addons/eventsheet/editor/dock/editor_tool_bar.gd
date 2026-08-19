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
	return sheet.host_class.strip_edges() in ["EditorScript", "EditorPlugin"]


## True when the sheet compiles to an EditorPlugin - the only kind that has a plugin to enable.
static func is_plugin_sheet(sheet: EventSheetResource) -> bool:
	return sheet != null and sheet.tool_mode and sheet.host_class.strip_edges() == "EditorPlugin"


## The bar's buttons as {kind, text}, in reading order. Static and value-driven so a test pins the
## exact words without building a viewport. `script_path` is the compiled script this sheet ships as
## ("" while the sheet is unsaved), and it only ever changes the Output count.
static func buttons_for(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var buttons: Array[Dictionary] = []
	if not applies_to(sheet):
		return buttons
	buttons.append({"kind": KIND_RUN, "text": "▶ " + EventSheetL10n.translate("Run now")})
	buttons.append({"kind": KIND_RELOAD, "text": "↻ " + EventSheetL10n.translate("Reload")})
	buttons.append({"kind": KIND_OUTPUT, "text": output_text(script_path)})
	if is_plugin_sheet(sheet):
		buttons.append({"kind": KIND_ENABLE, "text": EventSheetL10n.translate("Enable plugin")})
	return buttons


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
		_:
			return false
	return true


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
