@tool
class_name EventSheetThisEditorBar
extends RefCounted

# THE BAR ON A SHEET THAT IS PART OF THE RUNNING EDITOR.
#
# Opening the plugin's own source as a sheet is the honest dogfood, and it is also the one file a
# sheet can open where SAVING has a consequence no other file has: the editor you are looking at is
# built from it. So the bar says so, in this order:
#
#   ⇥ EventForgePlugin  editor plugin  [Enabled ●] [Reload ↻] [Output ▾] [plugin.cfg ▸]
#                                       part of this editor · read-only  [Edit anyway]
#
# READ-ONLY IS THE DEFAULT and Edit anyway is a door, not a warning: a file of the running editor
# opens the way every opened .gd already does (read-only until asked), and the first save through
# that door asks once whether to keep asking.
#
# THE ONE GUARD THAT MAKES THIS SURVIVABLE: a saved file that does not parse must NOT reload the
# plugin. The previous version stays loaded and the bar goes red. Without that, one typo takes the
# editor down mid-edit and the only way back is a restart with the broken file still on disk.
#
# Reload is disable-then-enable through the Editor object, which is the same pair of verbs a reader
# would otherwise walk to Project Settings ▸ Plugins to press by hand, and Output is the editor's own
# log filtered to what the reload printed - the same honest measurement the tool bar beside it makes.
#
# Everything the ROW BUILDER needs is static and pure, so the bar is pinned by a test without an
# editor; everything that RELOADS anything is an instance method reaching back through the dock.

## The chip kinds, in bar order. Each is the `kind` its span carries and the branch the viewport's
## input handler switches on, so the names are a small frozen contract between the two files.
const KIND_ENABLED := "this_editor_enabled"
const KIND_RELOAD := "this_editor_reload"
const KIND_OUTPUT := "this_editor_output"
const KIND_CFG := "this_editor_cfg"
const KIND_NOTE := "this_editor_note"
const KIND_EDIT_ANYWAY := "this_editor_edit_anyway"

## The plugin folder as Godot's enabled-plugins list spells it.
const PLUGIN_FOLDER := "eventforge"

## The plugin's own descriptor, and the five keys it holds. Read as setting rows rather than as text,
## because it is an INI of exactly five keys and the version row feeds Publish new version.
const PLUGIN_CFG_KEYS: PackedStringArray = ["name", "description", "author", "version", "script"]

## Whether the reader still wants the "this reloads the plugin" question before each save.
const KEEP_ASKING_KEY := "this_editor_save_keep_asking"

## What the last Reload printed, keyed by the plugin folder. Session state, never serialized.
static var _reload_output: PackedStringArray = PackedStringArray()

## Set when a reload was refused because the saved file does not parse - the red the bar wears until
## the next successful reload. Session state for the same reason.
static var _blocked_reason: String = ""

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## True for a sheet that IS one of the running editor's own files - and only in the editor's own
## repo, so a game that installed the plugin never sees any of this.
static func applies_to(sheet: EventSheetResource) -> bool:
	if sheet == null or not EventSheetThisEditor.is_editor_project():
		return false
	return EventSheetThisEditor.is_editor_source(str(sheet.external_source_path))


## True for the one file that IS the plugin - the only sheet that gets Enabled / Reload / plugin.cfg,
## because it is the only one with a plugin to enable, reload or describe.
static func is_plugin_sheet(sheet: EventSheetResource) -> bool:
	return applies_to(sheet) and str(sheet.external_source_path) == EventSheetThisEditor.PLUGIN_SCRIPT_PATH


## The bar's chips as {kind, text, muted}, in reading order. Static and value-driven so a test pins
## the exact words without building a viewport. `enabled` is the plugin list's live state, handed in
## rather than read here so the words are pinnable headless.
static func buttons_for(sheet: EventSheetResource, enabled: bool = true) -> Array[Dictionary]:
	var buttons: Array[Dictionary] = []
	if not applies_to(sheet):
		return buttons
	if is_plugin_sheet(sheet):
		buttons.append({"kind": KIND_ENABLED, "text": enabled_text(enabled), "muted": false})
		buttons.append({"kind": KIND_RELOAD, "text": "↻ " + EventSheetL10n.translate("Reload"), "muted": false})
		buttons.append({"kind": KIND_OUTPUT, "text": output_text(), "muted": false})
		buttons.append({"kind": KIND_CFG, "text": EventSheetL10n.translate("plugin.cfg") + " ▸", "muted": false})
	if not _blocked_reason.is_empty() and is_plugin_sheet(sheet):
		buttons.append({"kind": KIND_NOTE, "text": _blocked_reason, "muted": false, "error": true})
	buttons.append({"kind": KIND_NOTE, "text": note_text(sheet), "muted": true})
	if sheet.read_only:
		buttons.append({"kind": KIND_EDIT_ANYWAY, "text": EventSheetL10n.translate("Edit anyway"), "muted": false})
	return buttons


## The live-state chip. A word beside the mark, because a lone ● says nothing to a reader who has not
## been told what it means.
static func enabled_text(enabled: bool) -> String:
	return "%s ●" % EventSheetL10n.translate("Enabled") if enabled \
		else "%s ○" % EventSheetL10n.translate("Disabled")


## The muted line that says what this file is and what reading it costs.
static func note_text(sheet: EventSheetResource) -> String:
	if sheet != null and not sheet.read_only:
		return EventSheetL10n.translate("part of this editor · editing it reloads the plugin")
	return EventSheetL10n.translate("part of this editor · read-only")


## The Output chip's words: the line count when a reload has printed something, and a plain "no
## output yet" when it has not - never a bare arrow with nothing behind it.
static func output_text() -> String:
	if _reload_output.is_empty():
		return "%s ▾ %s" % [EventSheetL10n.translate("Output"), EventSheetL10n.translate("no output yet")]
	return "%s ▾ %d %s" % [EventSheetL10n.translate("Output"), _reload_output.size(),
		EventSheetL10n.translate("lines")]


## What the last reload printed, and the two doors the tests use to set and clear it.
static func output_lines() -> PackedStringArray:
	return _reload_output


static func record_output(lines: PackedStringArray) -> void:
	_reload_output = lines


static func clear_state() -> void:
	_reload_output = PackedStringArray()
	_blocked_reason = ""


## The red the bar wears while a reload is refused, and the door a test reads it through.
static func blocked_reason() -> String:
	return _blocked_reason


## The words a refused reload puts on the bar. Pinned as a value so the one message a reader sees at
## the worst moment cannot drift.
static func blocked_text(error_count: int) -> String:
	var errors: String = EventSheetL10n.translate("1 error") if error_count == 1 \
		else EventSheetL10n.translate("%d errors") % error_count
	return "%s - %s" % [errors, EventSheetL10n.translate("the plugin was NOT reloaded, the running one is still the old one")]


## The question the first save through Edit anyway asks. One sentence about what happens, one about
## what survives it, so "Continue?" is answerable without knowing how plugins load.
static func save_question() -> String:
	return EventSheetL10n.translate(
		"This file is part of the editor you are using. Saving reloads the plugin (your open sheets are kept). Continue?")


## plugin.cfg as setting rows: [{key, value}] in the file's own order, for the five keys it holds.
## Pure, so a test pins the rows from a fixture string.
static func cfg_setting_rows(text: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("[") or not stripped.contains("="):
			continue
		var key: String = stripped.get_slice("=", 0).strip_edges()
		if not key in PLUGIN_CFG_KEYS:
			continue
		var value: String = stripped.substr(stripped.find("=") + 1).strip_edges()
		if value.begins_with("\"") and value.ends_with("\"") and value.length() >= 2:
			value = value.substr(1, value.length() - 2)
		rows.append({"key": key, "value": value})
	return rows


## One setting row's sentence, in the words every other setting row in the sheet uses.
static func cfg_row_text(row: Dictionary) -> String:
	var kind: String = EventSheetL10n.translate("file") if str(row.get("key", "")) == "script" \
		else EventSheetL10n.translate("text")
	return "%s %s %s = %s" % [EventSheetL10n.translate("setting"), kind,
		str(row.get("key", "")), str(row.get("value", ""))]


## Whether the save question is still being asked. Off means the reader answered "Always".
static func keep_asking() -> bool:
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return false
	return bool(settings.call("get_project_metadata", "eventsheets", KEEP_ASKING_KEY, true))


static func set_keep_asking(asking: bool) -> void:
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", KEEP_ASKING_KEY, asking)


## An answer forced by a test or a preview harness, or -1 for "ask the editor". Neither of those runs
## has a plugin list behind it, and a picture of the bar saying Disabled would be a picture of the
## harness rather than of the editor.
static var _enabled_override: int = -1


static func set_enabled_override(state: int) -> void:
	_enabled_override = state


## Whether the plugin is ticked on right now. False headless, where there is no plugin list to ask.
static func is_plugin_enabled() -> bool:
	if _enabled_override >= 0:
		return _enabled_override == 1
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return false
	return EditorInterface.is_plugin_enabled(PLUGIN_FOLDER)


## Dispatches one bar chip. Returns true when the click was handled, so the viewport's input branch
## stays a one-liner and every "why did nothing happen" answer is written here, once.
func activate(kind: String) -> bool:
	match kind:
		KIND_ENABLED:
			_dock._set_status("The plugin is on. Project Settings ▸ Plugins is where it goes off - turning the editor off from inside itself is the one thing this bar will not do.")
		KIND_RELOAD:
			reload()
		KIND_OUTPUT:
			show_output()
		KIND_CFG:
			show_cfg()
		KIND_EDIT_ANYWAY:
			edit_anyway()
		_:
			return false
	return true


## Edit anyway: the same unlock every read-only preview has, said in this file's own terms.
func edit_anyway() -> void:
	if _dock._current_sheet == null:
		return
	_dock._current_sheet.read_only = false
	_dock._refresh_after_edit()
	_dock._set_status("Editing a file of the running editor. Saving it reloads the plugin - a file that does not parse is not reloaded at all.")


## Reload: off and straight back on, which is the only way the editor builds a fresh plugin instance,
## and exactly what a reader would otherwise do by hand in Project Settings.
##
## The parse check comes FIRST and refuses the whole thing on a single error. A reload of a file that
## does not parse leaves no plugin loaded at all, and no dock to fix it from.
func reload(source_path: String = "") -> void:
	var checked: String = source_path
	if checked.is_empty():
		checked = str(_dock._current_sheet.external_source_path) if _dock._current_sheet != null \
			else EventSheetThisEditor.PLUGIN_SCRIPT_PATH
	var errors: Array = EventSheetParseErrors.check_file(checked)
	if not errors.is_empty():
		_blocked_reason = blocked_text(errors.size())
		_dock._refresh_after_edit()
		_dock._set_status("%s Fix the error and press Reload again." % _blocked_reason, true)
		return
	_blocked_reason = ""
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var before: int = EventSheetEditorToolBar.log_length()
	EditorInterface.set_plugin_enabled(PLUGIN_FOLDER, false)
	EditorInterface.set_plugin_enabled(PLUGIN_FOLDER, true)
	record_output(EventSheetEditorToolBar.log_delta(before))
	_dock._set_status("Reloaded the plugin. Output has what it printed.")


## Output: the editor's own log filtered to what the reload printed, and nothing else.
func show_output() -> void:
	var lines: PackedStringArray = output_lines()
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = EventSheetL10n.translate("Output")
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	if lines.is_empty():
		body.add_child(EventSheetPopupUI.hint_label(
			EventSheetL10n.translate("Nothing yet. Press Reload and this fills with what the plugin printed as it came back."), 480.0))
	else:
		var log_view: TextEdit = TextEdit.new()
		log_view.editable = false
		log_view.text = "\n".join(lines)
		log_view.custom_minimum_size = Vector2(520.0, 260.0)
		body.add_child(log_view)
	dialog.add_child(EventSheetPopupUI.margined(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("What the reload printed"), body)))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	_dock.add_child(dialog)
	dialog.popup_centered()


## plugin.cfg ▸: the five keys as setting rows. The version row is the one that matters - it is the
## same number Publish new version bumps, so a plugin is bumped by the gesture that bumps a pack.
func show_cfg() -> void:
	var rows: Array[Dictionary] = cfg_setting_rows(
		FileAccess.get_file_as_string(EventSheetThisEditor.PLUGIN_CFG_PATH))
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = EventSheetL10n.translate("Plugin settings")
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	if rows.is_empty():
		body.add_child(EventSheetPopupUI.hint_label(
			EventSheetL10n.translate("This plugin has no descriptor to read."), 420.0))
	for row: Dictionary in rows:
		var value_field: LineEdit = LineEdit.new()
		value_field.text = str(row.get("value", ""))
		value_field.editable = false
		body.add_child(EventSheetPopupUI.form_row(str(row.get("key", "")), value_field))
	body.add_child(EventSheetPopupUI.hint_label(
		EventSheetL10n.translate("Sheet ▸ Publish new version bumps the version row, the same way it bumps a behavior pack."), 420.0))
	dialog.add_child(EventSheetPopupUI.margined(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("Plugin settings"), body)))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	_dock.add_child(dialog)
	dialog.popup_centered()
