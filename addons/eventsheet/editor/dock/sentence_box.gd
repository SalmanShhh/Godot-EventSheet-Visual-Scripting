@tool
extends RefCounted
# "How should this read?": the small box that writes the sentence of one function of a script of yours
# into the script itself (`## @ace_display_template("...")` above the function), so every row that uses
# it, in every sheet, reads the new way.
#
# The decisions are static and pure so a test asks them without a window: what the sentence will read as
# (made on a COPY of the definition - definitions are shared and immutable for the whole session), which
# slot a sentence names that the function does not have, and whether the script may be written at all
# (never a file the plugin ships, never a script with changes not yet saved in Godot's script editor).
#
# Loaded by path by the places that open it (a placed row's menu, the picker, the scripts window), so the
# first open of a sheet never compiles it. No class_name.

const SHIPPED_SCRIPTS_PATH := "res://addons/eventsheet/ace/shipped_scripts.gd"
const EVENTSHEETS_API_PATH := "res://addons/eventsheet/api/eventsheets.gd"
const SCANNER_PATH := "res://addons/eventsheet/ace/project_scanner.gd"


## What `sentence` reads as for this function, each slot filled with the row's starting value. Made on a
## copy: the shared definition is never touched.
static func preview(definition: ACEDefinition, sentence: String) -> String:
	var copy: ACEDefinition = definition.copy()
	copy.metadata["display_template"] = sentence
	return copy.format_display()


## A plain sentence naming the first `{slot}` the function has no such parameter for, or "" when every
## slot in the sentence is one it has.
static func finding_for(definition: ACEDefinition, sentence: String) -> String:
	var known: PackedStringArray = PackedStringArray()
	for index: int in definition.parameters.size():
		var parameter: Variant = definition.parameters[index]
		if parameter is Dictionary and not str((parameter as Dictionary).get("id", "")).is_empty():
			known.append(str((parameter as Dictionary).get("id", "")))
	var slots: RegEx = RegEx.new()
	slots.compile("\\{([^{}]*)\\}")
	for found: RegExMatch in slots.search_all(sentence):
		var slot: String = found.get_string(1)
		if known.has(slot) or (slot.is_valid_int() and int(slot) < definition.parameters.size()):
			continue
		var have: String = ", ".join(known) if not known.is_empty() else EventSheetL10n.translate("none")
		return EventSheetL10n.translate("There is no slot called %s here. This function has: %s.") % ["{%s}" % slot, have]
	return ""


## "" when `script_path` may be written, else the plain reason it may not. `unsaved` is the set of scripts
## with changes not yet saved in Godot's script editor ({path: true}).
static func writable_reason(script_path: String, unsaved: Dictionary = {}) -> String:
	if load(SHIPPED_SCRIPTS_PATH).is_shipped(script_path):
		return EventSheetL10n.translate("%s belongs to a behaviour that ships with the plugin, so how its rows read is changed in the behaviour itself.") % script_path.get_file()
	if unsaved.has(script_path):
		return EventSheetL10n.translate("%s has changes you have not saved in Godot's script editor. Save it there first, so nothing you typed is lost.") % script_path.get_file()
	return ""


## Every script open in Godot's script editor whose text has changes not yet saved: {path: true}.
static func unsaved_scripts() -> Dictionary:
	var unsaved: Dictionary = {}
	if not Engine.is_editor_hint():
		return unsaved
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	if script_editor == null:
		return unsaved
	var scripts: Array[Script] = script_editor.get_open_scripts()
	var editors: Array[ScriptEditorBase] = script_editor.get_open_script_editors()
	for index: int in mini(scripts.size(), editors.size()):
		var code: Control = editors[index].get_base_editor()
		if code is TextEdit and (code as TextEdit).get_version() != (code as TextEdit).get_saved_version():
			unsaved[scripts[index].resource_path] = true
	return unsaved


## The script file a definition's class comes from, or "" when it comes from no script (a builtin row).
## Reads the project's class list and the taught scripts; nothing is loaded.
static func script_path_for(definition: ACEDefinition) -> String:
	var owner_class: String = str(definition.metadata.get("reflect_class", definition.provider_id))
	if owner_class.is_empty() or str(definition.metadata.get("source_kind", "")).is_empty():
		return ""
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if str(info.get("class", "")) == owner_class:
			return str(info.get("path", ""))
	for taught: Variant in ProjectSettings.get_setting("eventsheets/vocabulary/taught_provider_scripts", PackedStringArray()):
		if load(SCANNER_PATH).class_name_for_path(str(taught)) == owner_class:
			return str(taught)
	for registered: Variant in EventForgeBridgeRuntime.get_registered_provider_scripts():
		if load(SCANNER_PATH).class_name_for_path(str(registered)) == owner_class:
			return str(registered)
	return ""


## Opens the box on `definition`. `host` is any node in the editor to parent the window to. `on_written` is called with the sentence to say once the
## script was written; `open_behaviour` with the path of a shipped behaviour the reader chose to open.
static func open(host: Node, definition: ACEDefinition, on_written: Callable = Callable(),
		open_behaviour: Callable = Callable(), script_path: String = "") -> Window:
	var path: String = script_path if not script_path.is_empty() else script_path_for(definition)
	if path.is_empty():
		return _refuse(host, EventSheetL10n.translate("This row does not come from a script of yours, so there is no script to write its words into."), "", Callable())
	var reason: String = writable_reason(path, unsaved_scripts())
	if not reason.is_empty():
		var shipped: bool = load(SHIPPED_SCRIPTS_PATH).is_shipped(path)
		return _refuse(host, reason, path if shipped else "", open_behaviour)
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("How should this read?"),
		Vector2i(460, 0), host, EventSheetL10n.translate("Done"))
	var window: ConfirmationDialog = parts["window"]
	var form: VBoxContainer = parts["box"]
	var edit: LineEdit = LineEdit.new()
	edit.text = str(definition.metadata.get("display_template", definition.display_name))
	edit.select_all()
	edit.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(380.0), 0.0)
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("How should this read in other sheets?"), edit))
	var reads_as: Label = Label.new()
	reads_as.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Reads as"), reads_as))
	var note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new()
	form.add_child(note)
	form.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Kept in %s. Every row that uses it follows.") % path.get_file()))
	var refresh: Callable = func(_typed: String = "") -> void:
		var finding: String = finding_for(definition, edit.text)
		reads_as.text = preview(definition, edit.text) if finding.is_empty() else ""
		note.say(finding, EventSheetPopupUI.TONE_WARNING)
		window.get_ok_button().disabled = not finding.is_empty()
	edit.text_changed.connect(refresh)
	edit.text_submitted.connect(func(_text: String) -> void:
		if not window.get_ok_button().disabled:
			window.get_ok_button().pressed.emit())
	window.confirmed.connect(func() -> void:
		var edits: Array = [{"source_kind": str(definition.metadata.get("source_kind", "method")),
			"member": str(definition.metadata.get("source_name", "")), "display_template": edit.text.strip_edges()}]
		var result: Dictionary = load(EVENTSHEETS_API_PATH).curate_provider(path, edits)
		var said: String = EventSheetL10n.translate("Written to %s: %s") % [path.get_file(), edit.text.strip_edges()] \
			if bool(result.get("ok", false)) else str(result.get("reason", ""))
		if on_written.is_valid():
			on_written.call(said, bool(result.get("ok", false)))
		window.queue_free())
	window.canceled.connect(func() -> void: window.queue_free())
	refresh.call()
	EventSheetWindowPlacement.popup_centered(window, Vector2i(480, 220))
	edit.grab_focus()
	return window


## The refusal: says why in a small window, and for a shipped behaviour offers to open it.
static func _refuse(host: Node, sentence: String, behaviour_path: String, open_behaviour: Callable) -> Window:
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("How should this read?"),
		Vector2i(460, 0), host, EventSheetL10n.translate("Open the behaviour") if not behaviour_path.is_empty() and open_behaviour.is_valid() else "")
	var form: VBoxContainer = parts["box"]
	var window: Window = parts["window"]
	form.add_child(EventSheetPopupUI.hint_label(sentence))
	if window is ConfirmationDialog:
		(window as ConfirmationDialog).confirmed.connect(func() -> void:
			open_behaviour.call(behaviour_path)
			window.queue_free())
		(window as ConfirmationDialog).canceled.connect(func() -> void: window.queue_free())
		EventSheetWindowPlacement.popup_centered(window, Vector2i(480, 160))
		return window
	# Nothing to open: a plain window with the one sentence.
	window.close_requested.connect(func() -> void: window.queue_free())
	EventSheetWindowPlacement.popup_centered(window, Vector2i(480, 160))
	return window



## The right-click on a placed row: opens the box for the definition the clicked cell reads through.
static func row_requested(dock: Control, lane: String) -> void:
	var ace: Resource = dock._row_edit_ops._context_ace_resource(lane)
	if ace == null:
		return
	var definition: ACEDefinition = definition_for(dock._ace_registry, str(ace.get("provider_id")), str(ace.get("ace_id")))
	if definition == null:
		dock._set_status(EventSheetL10n.translate("This row does not come from a script of yours, so there is no script to write its words into."), true)
		return
	open(dock, definition, func(said: String, ok: bool) -> void:
		dock._set_status(said, not ok),
		func(behaviour_path: String) -> void: dock._navigate.open_or_focus(behaviour_path))


## A row's definition: the registry's when it has one, otherwise the script's own reading of it (a class
## of the project's whose rows the picker lists without registering them).
static func definition_for(registry: Object, provider_id: String, ace_id: String) -> ACEDefinition:
	if registry != null:
		var found: ACEDefinition = registry.find_definition(provider_id, ace_id)
		if found != null:
			return found
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if str(info.get("class", "")) != provider_id:
			continue
		var script: Script = load(str(info.get("path", "")))
		if script == null:
			return null
		for candidate: ACEDefinition in load("res://addons/eventsheet/ace/script_reader.gd").definitions_for(provider_id, script, ""):
			if candidate.id == ace_id:
				return candidate
	return null
