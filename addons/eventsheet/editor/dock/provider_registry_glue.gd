@tool
class_name EventSheetProviderRegistryGlue
extends RefCounted
# The dock's PROVIDER REGISTRATION glue: the public per-sheet provider-script API (add/remove/list),
# the auto-ACE source adoption, the question that keeps a renamed function's old name working, and the
# door to the window that lists what a script of yours gives sheets (built by dock/script_rows_window.gd,
# loaded by path). State stays on the dock behind the `_dock.` back-reference.

## The files this helper reaches BY PATH, at the moment something asks: naming one of these
## classes here would compile it, and everything it names, into the first open of a sheet.
const PROJECT_DOCTOR_PATH := "res://addons/eventforge/project_doctor.gd"
const PUBLISH_VERSION_PATH := "res://addons/eventsheet/editor/dock/publish_version_dialog.gd"
const SCRIPT_ROWS_WINDOW_PATH := "res://addons/eventsheet/editor/dock/script_rows_window.gd"
const EVENTSHEETS_API_PATH := "res://addons/eventsheet/api/eventsheets.gd"
const ANNOTATION_WRITER_PATH := "res://addons/eventsheet/ace/annotation_writer.gd"

var _dock: Control = null
## The window of "what a script gives sheets", made the first time it is asked for.
var _script_rows: RefCounted = null


func init(dock: Control) -> void:
	_dock = dock


func set_auto_ace_sources(sources: Array[Object]) -> void:
	_dock._manual_ace_sources = sources.duplicate()
	_dock._refresh_ace_registry()


## "Teach a Verb", the sharing half: this sheet's compiled .gd joins the project-wide
## provider scan (persisted in project settings), so every sheet's picker gains its
## published verbs - node-targeted at $<class name> and retargetable, exactly like a
## behavior pack's. The verb LIVES in its home sheet (correct self-semantics: the code
## runs on the node that owns it); teaching only publishes the vocabulary.
func share_verbs_with_project() -> bool:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return false
	if sheet.custom_class_name.strip_edges().is_empty():
		_dock._set_status("Teach a Verb needs a class name so other sheets can target the node - set one in Sheet > Sheet Type first.", true)
		return false
	var has_exposed: bool = false
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).expose_as_ace:
			has_exposed = true
			break
	if not has_exposed:
		_dock._set_status("No published functions to teach yet - right-click an event and Extract All Actions to Function first.", true)
		return false
	var sheet_path: String = str(_dock._current_sheet_path)
	if sheet_path.is_empty():
		_dock._set_status("Save the sheet first - Teach a Verb shares the compiled script on disk.", true)
		return false
	var output_path: String = load(PROJECT_DOCTOR_PATH).output_path_for(sheet_path)
	if not FileAccess.file_exists(output_path):
		_dock._set_status("Save the sheet first (compile-on-save writes %s) - Teach a Verb shares that script." % output_path.get_file(), true)
		return false
	var taught: PackedStringArray = PackedStringArray(ProjectSettings.get_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, PackedStringArray()))
	if not taught.has(output_path):
		taught.append(output_path)
		ProjectSettings.set_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, taught)
		# Persist only inside the real editor - headless tests exercise the in-memory
		# setting and must never rewrite the project file.
		if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
			ProjectSettings.save()
	_dock._refresh_ace_registry()
	_dock._set_status("Shared: %s's published functions are now in every sheet's picker. Each row acts on the node named $%s, which the row's On node field can change." % [sheet.custom_class_name.strip_edges(), sheet.custom_class_name.strip_edges()])
	return true


## Registers a GDScript file for the current sheet only: its annotated methods, signals and exported
## properties then appear in this sheet's picker and in no other sheet's. Sharing a sheet's own
## published functions with every sheet is `share_verbs_with_project`, which is a project setting.
func add_ace_provider_script(path: String) -> bool:
	if not _dock._ensure_sheet_for_editing():
		return false
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty() or _dock._current_sheet.ace_provider_scripts.has(clean_path):
		return false
	var probe: Object = _dock._instantiate_provider_script(clean_path)
	if probe == null:
		_dock._set_status("Not a usable ACE provider script: %s" % clean_path.get_file(), true)
		return false
	if probe is Node:
		(probe as Node).free()
	var changed: bool = _dock._perform_undoable_sheet_edit("Add ACE Provider", func() -> bool:
		_dock._current_sheet.ace_provider_scripts.append(clean_path)
		return true
	)
	if changed:
		_dock._refresh_ace_registry()
		refresh_provider_list()
		_dock._mark_dirty("Added ACE provider: %s" % clean_path.get_file())
	return changed


## Removes a registered custom-ACE provider script from the current sheet.
func remove_ace_provider_script(path: String) -> bool:
	if not _dock._ensure_sheet_for_editing():
		return false
	if not _dock._current_sheet.ace_provider_scripts.has(path):
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit("Remove ACE Provider", func() -> bool:
		_dock._current_sheet.ace_provider_scripts.erase(path)
		return true
	)
	if changed:
		_dock._refresh_ace_registry()
		refresh_provider_list()
		_dock._mark_dirty("Removed ACE provider: %s" % path.get_file())
	return changed


func get_ace_provider_scripts() -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	if _dock._current_sheet == null:
		return output
	for path: Variant in _dock._current_sheet.ace_provider_scripts:
		output.append(str(path))
	return output


## Opens the window that lists what a script of yours gives sheets. Loaded by path, so the first open of
## a sheet never compiles it. `path` picks the script it opens on ("" opens on the first one in use).
func on_manage_ace_providers_requested(path: String = "") -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	if _script_rows == null:
		_script_rows = load(SCRIPT_ROWS_WINDOW_PATH).new()
	_script_rows.open(_dock, path)


## Redraws the window's list of scripts after one was added, removed or un-taught.
func refresh_provider_list() -> void:
	if _script_rows != null and _script_rows.window() != null:
		_script_rows.open_refresh()


## The Keep old events working question. Renaming a function changes the action's identity, so
## sheets that already use it break - silently, because the old call is baked into each row and
## still compiles. Naming what it used to be called shows the exact stand-in that would be added
## before anything is written, and the button stays greyed until there is one to add.
func open_shim_question(path: String, new_member: String) -> ConfirmationDialog:
	# One line ending, so the added lines are exactly the text after the file's own.
	var source: String = FileAccess.get_file_as_string(path).replace("\r\n", "\n")
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = EventSheetL10n.translate("the previous function name")
	var dialog: ConfirmationDialog = load(_dock.SMALL_PROMPT_PATH).open(_dock, {
		"title": EventSheetL10n.translate("Keep old events working?"),
		"body": EventSheetPopupUI.form_row(EventSheetL10n.translate("Used to be"), edit),
		"note": EventSheetL10n.translate("Adds this small function to the script and hides it from the picker. Nothing existing is edited."),
		"glyph": "i",
		"main": EventSheetL10n.translate("Keep them working"),
		"cancel": EventSheetL10n.translate("No thanks"),
		"on_main": func() -> void: on_provider_keep_old_name(edit.text.strip_edges(), path, new_member),
	})
	var sync: Callable = func(typed: String) -> void:
		var old_name: String = typed.strip_edges()
		var shim: Dictionary = load(ANNOTATION_WRITER_PATH).forwarding_shim(source, old_name, new_member)
		var can_add: bool = bool(shim.get("ok", false))
		load(_dock.SMALL_PROMPT_PATH).set_code(dialog,
			str(shim["source"]).substr(source.length()).strip_edges() if can_add else "")
		(dialog.find_child("Say", true, false) as Label).text = \
			EventSheetL10n.translate("You renamed %s to %s. Events that still say %s can keep working.") % [old_name, new_member, old_name] if can_add \
			else EventSheetL10n.translate("Type the name %s had before, and events that still say it keep working.") % new_member if old_name.is_empty() \
			else str(shim.get("reason", ""))
		dialog.get_ok_button().disabled = not can_add
	edit.text_changed.connect(sync)
	sync.call("")
	return dialog


## Keeps a function that has been RENAMED working for sheets that already use it.
##
## Name the function under its NEW name and what it used to be called; a deprecated forwarding shim of
## the old name is appended. Nothing existing is edited. This exists because a rename fails SILENTLY
## otherwise: the compiler prefers the template baked onto a row over any registry lookup, so an
## orphaned row still emits the old call, compiles clean, and breaks at game runtime.
func on_provider_keep_old_name(old_member: String, path: String = "", new_member: String = "") -> void:
	if path.strip_edges().is_empty() or new_member.is_empty():
		_dock._set_status("Select the function under its new name first.", true)
		return
	var result: Dictionary = load(EVENTSHEETS_API_PATH).keep_old_verb_working(path, old_member, new_member)
	if not bool(result.get("ok", false)):
		_dock._set_status(str(result.get("reason", "Could not add the shim.")), true)
		return
	_dock._set_status("Added a deprecated %s() that forwards to %s() - sheets using the old action keep working, and it is hidden from the picker."
		% [old_member, new_member])
	refresh_provider_list()


var _publish_version: RefCounted = null


## Sheet > Publish New Version...: the window lives in its own file, loaded by path on first use.
func open_publish_version_dialog() -> void:
	if _publish_version == null:
		_publish_version = load(PUBLISH_VERSION_PATH).new()
	_publish_version.open_publish_version_dialog(_dock)


## The un-teach: removes a taught script from the project-wide vocabulary (the inverse
## of share_verbs_with_project). Settings only - the sheet and its verbs are untouched.
func unteach_provider(path: String) -> void:
	var taught: PackedStringArray = PackedStringArray(ProjectSettings.get_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, PackedStringArray()))
	var index: int = taught.find(path)
	if index < 0:
		return
	taught.remove_at(index)
	ProjectSettings.set_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, taught if not taught.is_empty() else null)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		ProjectSettings.save()
	_dock._refresh_ace_registry()
	refresh_provider_list()
	_dock._set_status("Un-taught %s - its actions left the project-wide picker (the sheet itself is untouched)." % path.get_file())
