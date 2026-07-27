@tool
class_name EventSheetProviderRegistryGlue
extends RefCounted
# The dock's PROVIDER REGISTRATION glue, extracted from event_sheet_dock.gd: the
# public per-sheet provider-script API (add/remove/list), the auto-ACE source
# adoption, and the Manage Providers dialog behavior (list refresh + button
# handlers; the dialog is BUILT by dock/dock_ui_builder.gd). State stays on the
# dock; bodies moved verbatim behind the `_dock.` back-reference with one-line
# delegates keeping the public API and every signal target in place.

## The Kind dropdown's entries, in the order the range cell indexes them. Matches
## EventSheetProviderPreview.kind_label, which is what fills the BEFORE side of the diff.
const KIND_CHOICES: PackedStringArray = ["Action", "Condition", "Expression", "Trigger"]

## The annotation each Kind writes, keyed the way EventSheetACEAnnotationWriter expects.
const KIND_EDIT_KEYS: PackedStringArray = ["action", "condition", "expression", "trigger"]

## The param hints the curation editor offers. Not the whole vocabulary - any hint a provider can
## name is still writable by hand - just the ones worth a dropdown. "comparison" leads because it is
## the one that replaces six hand-typed operators with a word.
const PARAM_HINTS: PackedStringArray = ["", "comparison", "expression", "color", "variable_reference", "input_action"]

var _dock: Control = null
var _curate_confirm: ConfirmationDialog = null
var _curate_diff: CodeEdit = null
var _curate_pending: Array = []
## member -> {param_id -> {hint, options, default}}. Held aside from the Tree because a param spec
## has no cell to live in, and re-scanning after an apply must not silently drop pending edits.
var _param_specs: Dictionary = {}
var _param_dialog: ConfirmationDialog = null
var _param_rows: Array = []
var _param_member: String = ""
var _shim_dialog: ConfirmationDialog = null
var _shim_old_name: LineEdit = null


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
	# Roomier than the old list-only dialog: it now carries the "what it publishes" preview table too.
	_dock._provider_dialog.popup_centered(Vector2i(760, 640))


func refresh_provider_list() -> void:
	if _dock._provider_list == null:
		return
	_dock._provider_list.clear()
	for path in get_ace_provider_scripts():
		var sheet_index: int = _dock._provider_list.add_item(path)
		_dock._provider_list.set_item_metadata(sheet_index, {"taught": false, "path": str(path)})
	# Taught verbs (Sheet > Teach a Verb) are PROJECT-wide, not per-sheet - listed here so
	# Remove is also the un-teach: one dialog manages the whole custom vocabulary.
	for taught_path: Variant in ProjectSettings.get_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, PackedStringArray()):
		var taught_index: int = _dock._provider_list.add_item("%s  (taught project-wide)" % str(taught_path))
		_dock._provider_list.set_item_metadata(taught_index, {"taught": true, "path": str(taught_path)})


func on_provider_add_pressed() -> void:
	if _dock._provider_file_dialog != null:
		_dock._provider_file_dialog.popup_centered(Vector2i(720, 520))


## Browsing a script PREVIEWS it rather than registering it: the whole point of the preview is to see
## what joins the picker before it does. Registering is the explicit second click (on_provider_register).
## The public API (EventSheets.register_ace_provider) still registers outright - a caller in code is not
## previewing anything.
func on_provider_file_selected(path: String) -> void:
	preview_provider_script(path, true)


## Renders EventSheetProviderPreview.scan() into the dialog. Thin on purpose: every decision (kinds,
## labels, emitted code, which warnings fire) is made by the pure scan, which the suite pins - this only
## puts it on screen. `offer_register` shows the Register button for a script that is not registered yet.
func preview_provider_script(path: String, offer_register: bool) -> void:
	if _dock._provider_preview_tree == null:
		return
	# Param specs are per-script; carrying them to a different provider would write a hint onto a
	# member that merely shares a name. A re-scan of the SAME script keeps them, so the specs survive
	# the refresh that follows an apply.
	if str(_dock._provider_preview_path) != path:
		_param_specs.clear()
	_dock._provider_pending_path = path if offer_register else ""
	_dock._provider_preview_path = path
	_dock._provider_preview_tree.clear()
	for stale_warning: Node in _dock._provider_preview_warnings.get_children():
		stale_warning.queue_free()
	var scan: Dictionary = EventSheetProviderPreview.scan(path)
	_dock._provider_preview_scan = scan
	_dock._provider_preview_summary.text = "%s\n%s" % [path.get_file(), EventSheetProviderPreview.summary_line(scan)]
	for warning: Variant in scan.get("warnings", []):
		var warning_label: Label = EventSheetPopupUI.hint_label("! %s" % str((warning as Dictionary).get("text", "")))
		warning_label.add_theme_color_override("font_color", Color("#e0a33a"))
		_dock._provider_preview_warnings.add_child(warning_label)
	var root: TreeItem = _dock._provider_preview_tree.create_item()
	for entry: Variant in scan.get("entries", []):
		var row: Dictionary = entry
		var item: TreeItem = _dock._provider_preview_tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, true)
		item.set_editable(0, true)
		item.set_tooltip_text(0, "Unchecked writes `## @ace_hidden`, so this member stops publishing a verb.")
		# The kind dropdown is the point of curating: raw reflection reads an UNTYPED method as an
		# Action, and this changes it by annotation - the signature is never rewritten.
		item.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
		item.set_text(1, ",".join(KIND_CHOICES))
		item.set_range(1, maxf(0.0, float(KIND_CHOICES.find(str(row.get("kind_label", ""))))))
		item.set_editable(1, true)
		item.set_tooltip_text(1, "Which lane this verb belongs in. Changing it writes an annotation - your function signature is left alone.")
		item.set_text(2, str(row.get("label", "")))
		item.set_editable(2, true)
		item.set_text(3, _category_of(scan, row))
		item.set_editable(3, true)
		item.set_text(4, ", ".join(PackedStringArray(row.get("params", []))))
		# A method's template is baked when the row is applied, so it is empty at scan time. Say that
		# rather than showing a blank cell that reads like something failed.
		var emits: String = str(row.get("emits", ""))
		item.set_text(5, emits if not emits.is_empty() else "(built when you add the row)")
		item.set_tooltip_text(2, "%s - from %s `%s`" % [str(row.get("ace_id", "")), str(row.get("source", "")), str(row.get("member", ""))])
		item.set_metadata(0, row)
	var has_entries: bool = bool(scan.get("ok", false)) and not (scan.get("entries", []) as Array).is_empty()
	_dock._provider_register_button.visible = offer_register and has_entries
	# Curation edits the file, so it is offered for any previewed script - registered or not.
	if _dock._provider_curate_button != null:
		_dock._provider_curate_button.visible = has_entries
	if _dock._provider_params_button != null:
		_dock._provider_params_button.visible = has_entries
	if _dock._provider_shim_button != null:
		_dock._provider_shim_button.visible = has_entries


## The category the scan reported for a row, which is the BEFORE side of the Category column.
func _category_of(_scan: Dictionary, row: Dictionary) -> String:
	return str(row.get("category", ""))


## Reads the curation table and returns one edit per member the user actually CHANGED.
##
## Only differences are written: annotating every member with whatever reflection already inferred
## would bury the author's real decisions in a wall of comments that says nothing.
func collect_curation_edits() -> Array:
	var edits: Array = []
	if _dock._provider_preview_tree == null:
		return edits
	var item: TreeItem = _dock._provider_preview_tree.get_root()
	if item == null:
		return edits
	item = item.get_first_child()
	while item != null:
		var row: Dictionary = item.get_metadata(0) as Dictionary
		if row == null:
			item = item.get_next()
			continue
		var edit: Dictionary = {
			"source_kind": str(row.get("source", "method")),
			"member": str(row.get("member", ""))
		}
		var changed: bool = false
		if not item.is_checked(0):
			edit["hidden"] = true
			changed = true
		else:
			var kind_index: int = int(item.get_range(1))
			if kind_index >= 0 and kind_index < KIND_CHOICES.size() and KIND_CHOICES[kind_index] != str(row.get("kind_label", "")):
				edit["kind"] = KIND_EDIT_KEYS[kind_index]
				changed = true
			if item.get_text(2) != str(row.get("label", "")):
				edit["name"] = item.get_text(2)
				changed = true
			if item.get_text(3) != str(row.get("category", "")):
				edit["category"] = item.get_text(3)
				changed = true
		# Param specs live outside the Tree (a hint has no cell), so they fold in here. A member whose
		# ONLY change is a param spec still counts - that is the whole point of the param editor.
		var member: String = str(edit["member"])
		if not bool(edit.get("hidden", false)) and _param_specs.has(member):
			var specs: Dictionary = (_param_specs[member] as Dictionary).duplicate(true)
			if not specs.is_empty():
				edit["params"] = specs
				changed = true
		if changed and not member.is_empty():
			edits.append(edit)
		item = item.get_next()
	return edits


## Records one param's authored spec. An empty spec clears it, so unticking a hint really removes
## the annotation rather than writing an empty one.
func set_param_spec(member: String, param_id: String, spec: Dictionary) -> void:
	var member_specs: Dictionary = _param_specs.get(member, {})
	if spec.is_empty():
		member_specs.erase(param_id)
	else:
		member_specs[param_id] = spec
	if member_specs.is_empty():
		_param_specs.erase(member)
	else:
		_param_specs[member] = member_specs


func param_specs_for(member: String) -> Dictionary:
	return _param_specs.get(member, {})


## Opens the per-param editor for the selected verb: hint, options and starting value per parameter.
## The annotation writer already emits all three, so this is the missing authoring surface rather
## than new machinery.
func on_provider_params_pressed() -> void:
	if _dock._provider_preview_tree == null:
		return
	var item: TreeItem = _dock._provider_preview_tree.get_selected()
	if item == null:
		_dock._set_status("Select a verb first, then edit its parameters.")
		return
	var row: Dictionary = item.get_metadata(0) as Dictionary
	if row == null:
		return
	var param_ids: Array = row.get("params", [])
	if param_ids.is_empty():
		_dock._set_status("%s has no parameters to shape." % str(row.get("label", "")))
		return
	_param_member = str(row.get("member", ""))
	_build_param_dialog(str(row.get("label", "")), param_ids)


func _build_param_dialog(verb_label: String, param_ids: Array) -> void:
	if _param_dialog == null:
		_param_dialog = ConfirmationDialog.new()
		_param_dialog.ok_button_text = "Keep"
		_param_dialog.confirmed.connect(_collect_param_dialog)
		_dock.add_child(_param_dialog)
	for stale: Node in _param_dialog.get_children():
		if stale is MarginContainer:
			stale.queue_free()
	_param_rows.clear()
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.add_child(EventSheetPopupUI.hint_label("How each parameter should be filled in when someone drops this verb into a sheet.\nHint 'comparison' is the whole operator dropdown in one word. Options read as `value=Label`, separated by |."))
	var existing: Dictionary = param_specs_for(_param_member)
	for param_id: Variant in param_ids:
		var id_text: String = str(param_id)
		var spec: Dictionary = existing.get(id_text, {}) as Dictionary
		var card: VBoxContainer = EventSheetPopupUI.form_box()
		var hint_option: OptionButton = OptionButton.new()
		for hint_name: String in PARAM_HINTS:
			hint_option.add_item("(plain)" if hint_name.is_empty() else hint_name)
			hint_option.set_item_metadata(hint_option.item_count - 1, hint_name)
			if hint_name == str(spec.get("hint", "")):
				hint_option.select(hint_option.item_count - 1)
		var options_edit: LineEdit = LineEdit.new()
		options_edit.text = str(spec.get("options", ""))
		options_edit.placeholder_text = "low=Potato|med=Balanced|high=Ultra"
		var default_edit: LineEdit = LineEdit.new()
		default_edit.text = str(spec.get("default", ""))
		default_edit.placeholder_text = "what the row shows on drop"
		card.add_child(EventSheetPopupUI.form_row("Hint", hint_option))
		card.add_child(EventSheetPopupUI.form_row("Options", options_edit))
		card.add_child(EventSheetPopupUI.form_row("Starting value", default_edit))
		body.add_child(EventSheetPopupUI.titled_card(id_text, card))
		_param_rows.append({"id": id_text, "hint": hint_option, "options": options_edit, "default": default_edit})
	_param_dialog.add_child(EventSheetPopupUI.margined(body))
	_param_dialog.title = "Parameters of %s" % verb_label
	_param_dialog.popup_centered(Vector2i(560, 520))


func _collect_param_dialog() -> void:
	for entry: Dictionary in _param_rows:
		var spec: Dictionary = {}
		var hint_option: OptionButton = entry["hint"]
		var hint_value: String = str(hint_option.get_item_metadata(hint_option.selected)) if hint_option.selected >= 0 else ""
		if not hint_value.is_empty():
			spec["hint"] = hint_value
		var options_text: String = (entry["options"] as LineEdit).text.strip_edges()
		if not options_text.is_empty():
			spec["options"] = options_text
		var default_text: String = (entry["default"] as LineEdit).text.strip_edges()
		if not default_text.is_empty():
			spec["default"] = default_text
		set_param_spec(_param_member, str(entry["id"]), spec)
	_dock._set_status("Parameter shapes recorded - press Curate Script to write them.")


## Asks what the selected verb USED to be called, then shims it.
func on_provider_shim_pressed() -> void:
	if _dock._provider_preview_tree == null or _dock._provider_preview_tree.get_selected() == null:
		_dock._set_status("Select the verb under its new name first.")
		return
	if _shim_dialog == null:
		_shim_dialog = ConfirmationDialog.new()
		_shim_dialog.title = "Keep the old name working"
		_shim_dialog.ok_button_text = "Add Shim"
		var body: VBoxContainer = EventSheetPopupUI.form_box()
		body.add_child(EventSheetPopupUI.hint_label("Renaming a function changes the verb's identity, so sheets that already use it break - silently, because the old call is baked into each row and still compiles.
Name what this function used to be called and a deprecated stand-in is added that forwards to it. Nothing existing is edited."))
		_shim_old_name = LineEdit.new()
		_shim_old_name.placeholder_text = "the previous function name"
		body.add_child(EventSheetPopupUI.form_row("Used to be", _shim_old_name))
		_shim_dialog.add_child(EventSheetPopupUI.margined(body))
		_shim_dialog.confirmed.connect(func() -> void: on_provider_keep_old_name(_shim_old_name.text.strip_edges()))
		_dock.add_child(_shim_dialog)
	_shim_old_name.text = ""
	_shim_dialog.popup_centered(Vector2i(520, 240))


## Keeps a verb that has been RENAMED working for sheets that already use it.
##
## Select the verb under its NEW name and name what it used to be called; a deprecated forwarding
## shim of the old name is appended. Nothing existing is edited. This exists because a rename fails
## SILENTLY otherwise: the compiler prefers the template baked onto a row over any registry lookup,
## so an orphaned row still emits the old call, compiles clean, and breaks at game runtime.
func on_provider_keep_old_name(old_member: String) -> void:
	var path: String = str(_dock._provider_preview_path)
	var item: TreeItem = _dock._provider_preview_tree.get_selected() if _dock._provider_preview_tree != null else null
	if path.strip_edges().is_empty() or item == null:
		_dock._set_status("Select the verb under its new name first.", true)
		return
	var row: Dictionary = item.get_metadata(0) as Dictionary
	if row == null or str(row.get("source", "")) != "method":
		_dock._set_status("Only a method can carry a forwarding shim.", true)
		return
	var result: Dictionary = EventSheets.keep_old_verb_working(path, old_member, str(row.get("member", "")))
	if not bool(result.get("ok", false)):
		_dock._set_status(str(result.get("reason", "Could not add the shim.")), true)
		return
	_dock._set_status("Added a deprecated %s() that forwards to %s() - sheets using the old verb keep working, and it is hidden from the picker."
		% [old_member, str(row.get("member", ""))])
	preview_provider_script(path, false)


## Shows what will be written before anything is written. The wizard edits a file the user owns,
## so the last step is always "here are the exact lines" rather than a silent save.
func on_provider_curate_pressed() -> void:
	var path: String = str(_dock._provider_preview_path)
	if path.strip_edges().is_empty():
		return
	_curate_pending = collect_curation_edits()
	if _curate_pending.is_empty():
		_dock._set_status("Nothing to curate - change a Publish box, Kind, Verb or Category first.")
		return
	_ensure_curate_confirm()
	_curate_diff.text = curation_diff_text(_curate_pending)
	_curate_confirm.title = "Curate %s" % path.get_file()
	_curate_confirm.popup_centered(Vector2i(720, 460))


## A human-readable preview of the comment lines each member will gain.
func curation_diff_text(edits: Array) -> String:
	var blocks: PackedStringArray = PackedStringArray()
	for entry: Variant in edits:
		var edit: Dictionary = entry
		var lines: PackedStringArray = PackedStringArray()
		lines.append("%s %s" % [str(edit.get("source_kind", "")), str(edit.get("member", ""))])
		for annotation: String in EventSheetACEAnnotationWriter.annotation_lines(edit):
			lines.append("  + %s" % annotation)
		blocks.append("\n".join(lines))
	return "\n\n".join(blocks)


func _ensure_curate_confirm() -> void:
	if _curate_confirm != null:
		return
	_curate_confirm = ConfirmationDialog.new()
	_curate_confirm.ok_button_text = "Write Annotations"
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.add_child(EventSheetPopupUI.hint_label("These comment lines are added above the members named below.\nNothing else in the file changes - no signature, no body - and a backup is taken first (Tools > Sheet Backups)."))
	_curate_diff = CodeEdit.new()
	_curate_diff.editable = false
	_curate_diff.custom_minimum_size = Vector2(0, 260)
	_curate_diff.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EventSheetPopupUI.configure_code_editor(_curate_diff)
	body.add_child(_curate_diff)
	_curate_confirm.add_child(EventSheetPopupUI.margined(body))
	_curate_confirm.confirmed.connect(_apply_curation)
	_dock.add_child(_curate_confirm)


func _apply_curation() -> void:
	var path: String = str(_dock._provider_preview_path)
	var result: Dictionary = EventSheets.curate_provider(path, _curate_pending)
	if not bool(result.get("ok", false)):
		_dock._set_status(str(result.get("reason", "Could not curate the script.")), true)
		return
	var skipped: Array = result.get("skipped", [])
	var message: String = "Curated %s - %d member%s annotated." % [
		path.get_file(), int(result.get("changed", 0)), "" if int(result.get("changed", 0)) == 1 else "s"]
	if not skipped.is_empty():
		# A member renamed between the scan and the apply. Say which, rather than reporting a
		# clean success for a partial write.
		message += " Not found: %s." % ", ".join(PackedStringArray(skipped))
	_dock._set_status(message, not skipped.is_empty())
	_curate_pending = []
	# Re-scan so the table shows what the file NOW publishes - the proof the write landed.
	preview_provider_script(path, false)


## Commits the previewed script to this sheet's providers.
func on_provider_register_pressed() -> void:
	var pending: String = _dock._provider_pending_path
	if pending.strip_edges().is_empty():
		return
	if add_ace_provider_script(pending):
		preview_provider_script(pending, false)


func on_provider_remove_pressed() -> void:
	if _dock._provider_list == null:
		return
	var selected: PackedInt32Array = _dock._provider_list.get_selected_items()
	if selected.is_empty():
		return
	var entry: Variant = _dock._provider_list.get_item_metadata(selected[0])
	if entry is Dictionary and bool((entry as Dictionary).get("taught", false)):
		unteach_provider(str((entry as Dictionary).get("path", "")))
		return
	remove_ace_provider_script(_dock._provider_list.get_item_text(selected[0]))


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
	_dock._set_status("Un-taught %s - its verbs left the project-wide picker (the sheet itself is untouched)." % path.get_file())
