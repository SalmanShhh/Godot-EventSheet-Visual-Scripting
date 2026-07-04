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
