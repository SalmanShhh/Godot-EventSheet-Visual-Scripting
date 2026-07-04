@tool
class_name EventSheetProviderRegistryGlue
extends RefCounted
# The dock's PROVIDER REGISTRATION glue, extracted from event_sheet_dock.gd: the
# public per-sheet provider-script API (add/remove/list), the auto-ACE source
# adoption, and the Manage Providers dialog behavior (list refresh + button
# handlers; the dialog is BUILT by dock/dock_ui_builder.gd). State stays on the
# dock; bodies moved verbatim behind the `_dock.` back-reference with one-line
# delegates keeping the public API and every signal target in place.

var _dock: Control = null


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
		_dock._set_status("No published verbs to teach yet - right-click an event and Extract All Actions to Function first.", true)
		return false
	var sheet_path: String = str(_dock._current_sheet_path)
	if sheet_path.is_empty():
		_dock._set_status("Save the sheet first - Teach a Verb shares the compiled script on disk.", true)
		return false
	var output_path: String = EventSheetProjectDoctor.output_path_for(sheet_path)
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
	_dock._set_status("Taught: %s's published verbs are now in every sheet's picker (node-targeted at $%s)." % [sheet.custom_class_name.strip_edges(), sheet.custom_class_name.strip_edges()])
	return true


## Registers a GDScript file as a custom-ACE provider on the current sheet. Its annotated
## methods/signals/exported properties then appear in the ACE picker.
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
		_dock._refresh_provider_list()
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
		_dock._refresh_provider_list()
		_dock._mark_dirty("Removed ACE provider: %s" % path.get_file())
	return changed


func get_ace_provider_scripts() -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	if _dock._current_sheet == null:
		return output
	for path: Variant in _dock._current_sheet.ace_provider_scripts:
		output.append(str(path))
	return output


func on_manage_ace_providers_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_dock._build_provider_dialog()
	_dock._refresh_provider_list()
	_dock._provider_dialog.popup_centered(Vector2i(560, 420))


func refresh_provider_list() -> void:
	if _dock._provider_list == null:
		return
	_dock._provider_list.clear()
	for path in get_ace_provider_scripts():
		_dock._provider_list.add_item(path)


func on_provider_add_pressed() -> void:
	if _dock._provider_file_dialog != null:
		_dock._provider_file_dialog.popup_centered(Vector2i(720, 520))


func on_provider_file_selected(path: String) -> void:
	add_ace_provider_script(path)


func on_provider_remove_pressed() -> void:
	if _dock._provider_list == null:
		return
	var selected: PackedInt32Array = _dock._provider_list.get_selected_items()
	if selected.is_empty():
		return
	remove_ace_provider_script(_dock._provider_list.get_item_text(selected[0]))
