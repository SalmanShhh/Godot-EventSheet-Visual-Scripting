@tool
class_name EventSheetCodePanelGlue
extends RefCounted
# The dock's SIDE-PANEL glue, extracted from event_sheet_dock.gd to keep that file
# maintainable. Two closely-linked panels live here:
#
#   - the GDSCRIPT PROVENANCE panel: recompiling the sheet into the read-only
#     CodeEdit, sheet-row -> generated-line highlighting via the source map (and the
#     reverse: clicking a code line selects its sheet row), the Functions overview
#     list with its context menu, plus the raw-GDScript block edit dialog's lint /
#     completion / confirm flow,
#   - the OPEN SHEETS panel: refresh, show/hide + collapse handling, and its
#     per-project shown/collapsed preferences.
#
# All widget references and panel state stay ON THE DOCK; this layer only owns the
# behavior. Bodies were moved VERBATIM with member access rewritten through the
# `_dock.` back-reference; the dock keeps one-line delegates (several of these are
# signal targets wired by name) so nothing else changed.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## ── Open Sheets panel (the left in-workspace pane) ──────────────────────────────────────
## Push the current open-tab snapshot into the panel (on every _dock.open_tabs_changed + on build).
func refresh_open_sheets_panel() -> void:
	if _dock._open_sheets_panel == null:
		return
	var state: Dictionary = _dock.get_open_sheets_state()
	_dock._open_sheets_panel.set_state(state.get("open", []), int(state.get("active", -1)), state.get("recent", []))


## View ▸ Open Sheets Panel: show/hide the whole left pane (remembered per project).
func toggle_open_sheets_panel(view_popup: PopupMenu) -> void:
	if _dock._open_sheets_panel == null:
		return
	_dock._open_sheets_panel.visible = not _dock._open_sheets_panel.visible
	if view_popup != null:
		view_popup.set_item_checked(view_popup.get_item_index(13), _dock._open_sheets_panel.visible)
	_dock._save_open_sheets_panel_prefs()


## The panel collapsed to / expanded from a strip: snap the split divider to match, and remember it.
func refresh_anatomy_panel() -> void:
	if _dock._anatomy_panel != null:
		_dock._anatomy_panel.refresh(_dock._current_sheet)


func on_open_sheets_panel_collapsed(collapsed: bool) -> void:
	if _dock._workspace_body != null:
		_dock._workspace_body.split_offset = 26 if collapsed else 200
	# The whole left rail narrows to the strip - the Functions/Anatomy panels can't fit, so they follow.
	if _dock._anatomy_panel != null:
		_dock._anatomy_panel.visible = not collapsed
	if _dock._functions_panel != null:
		_dock._functions_panel.visible = not collapsed
	_dock._save_open_sheets_panel_prefs()


## Per-project editor metadata for the panel's shown/collapsed state (survives editor restarts).
func read_open_sheets_panel_prefs() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var meta: Variant = EditorInterface.get_editor_settings().get_project_metadata("eventsheets", _dock._OPEN_SHEETS_PANEL_META, {})
		if meta is Dictionary:
			return meta
	return {}


func save_open_sheets_panel_prefs() -> void:
	if not (Engine.is_editor_hint() and Engine.has_singleton("EditorInterface")):
		return
	EditorInterface.get_editor_settings().set_project_metadata("eventsheets", _dock._OPEN_SHEETS_PANEL_META, {
		"shown": _dock._open_sheets_panel != null and _dock._open_sheets_panel.visible,
		"collapsed": _dock._open_sheets_panel != null and _dock._open_sheets_panel.is_collapsed(),
	})


## Apply the remembered shown/collapsed state when the workspace is built.
func apply_open_sheets_panel_prefs() -> void:
	if _dock._open_sheets_panel == null:
		return
	var prefs: Dictionary = _dock._read_open_sheets_panel_prefs()
	_dock._open_sheets_panel.visible = bool(prefs.get("shown", true))
	_dock._open_sheets_panel.set_collapsed(bool(prefs.get("collapsed", false)))
	if _dock._anatomy_panel != null:
		_dock._anatomy_panel.visible = not bool(prefs.get("collapsed", false))
	if _dock._functions_panel != null:
		_dock._functions_panel.visible = not bool(prefs.get("collapsed", false))
	_dock._refresh_open_sheets_panel()


func toggle_code_panel() -> void:
	_dock._ensure_code_panel()
	_dock._side_panel.visible = not _dock._side_panel.visible
	_dock._split.dragger_visibility = (
		SplitContainer.DRAGGER_VISIBLE if _dock._side_panel.visible else SplitContainer.DRAGGER_HIDDEN_COLLAPSED
	)
	if _dock._side_panel.visible:
		_dock._refresh_code_panel()


## Adopts the editor's code-editor look on a CodeEdit (the GDScript panel): the same
## monospace code font + size the script editor uses, plus the built-in minimap and
## current-line highlight - so the panel reads as part of Godot, not a foreign box.
## No-op headless (no editor theme/settings).
func apply_editor_code_settings(code_edit: CodeEdit) -> void:
	code_edit.minimap_draw = true
	code_edit.highlight_current_line = true
	code_edit.draw_tabs = true
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme != null and editor_theme.has_font("source", "EditorFonts"):
		code_edit.add_theme_font_override("font", editor_theme.get_font("source", "EditorFonts"))
		if editor_theme.has_font_size("source_size", "EditorFonts"):
			code_edit.add_theme_font_size_override("font_size", editor_theme.get_font_size("source_size", "EditorFonts"))


## Recompiles the current sheet into the panel (text + source map) and re-highlights.
func refresh_code_panel() -> void:
	if _dock._code_edit == null or _dock._side_panel == null or not _dock._side_panel.visible:
		return
	_dock._refresh_functions_list()
	if _dock._current_sheet == null:
		_dock._code_edit.text = ""
		_dock._code_source_map = []
		_dock._code_panel_highlight = Vector2i(-1, -1)
		return
	var compile_result: Dictionary = SheetCompiler.compile(_dock._current_sheet, "user://eventforge_code_panel_preview.gd")
	_dock._code_edit.text = str(compile_result.get("output", ""))
	_dock._code_source_map = compile_result.get("source_map", [])
	_dock._code_panel_highlight = Vector2i(-1, -1)
	_dock._update_code_panel_highlight()


## Repopulates the Functions overview list from the active sheet (signature + an ✦ for ACE-exposed
## functions). Cheap; runs whenever the side panel refreshes (i.e. on any edit while it's open).
func refresh_functions_list() -> void:
	if _dock._functions_list == null:
		return
	_dock._functions_list.clear()
	var count: int = 0
	if _dock._current_sheet != null:
		for function_resource: Variant in _dock._current_sheet.functions:
			if function_resource is EventFunction:
				_dock._functions_list.add_item(_dock._format_function_signature(function_resource as EventFunction))
				count += 1
	if _dock._functions_panel != null:
		_dock._functions_panel.set_count(count)  # the collapsed header still tells the sheet's weight


## "name(a, b)" plus a trailing ✦ when the function is exposed as an ACE (a reusable action/condition/
## expression in other sheets) - the at-a-glance signature shown in the Functions list.
func format_function_signature(function: EventFunction) -> String:
	var param_ids: PackedStringArray = PackedStringArray()
	for param_variant: Variant in function.params:
		if param_variant is ACEParam:
			param_ids.append((param_variant as ACEParam).id)
	var signature: String = "%s(%s)" % [function.function_name, ", ".join(param_ids)]
	return (signature + "  ✦") if function.expose_as_ace else signature


## Right-click a function to delete it (the list is otherwise read-only - editing is via the rows).
func on_functions_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT or _dock._functions_menu == null:
		return
	_dock._functions_list.select(index)
	_dock._functions_menu.position = Vector2i(_dock._functions_list.get_screen_position() + at_position)
	_dock._functions_menu.reset_size()
	_dock._functions_menu.popup()


func on_functions_menu_id_pressed(id: int) -> void:
	if id == 0:
		_dock._delete_selected_function()


## Removes the selected function from the sheet (undoable) and refreshes the list + preview.
func delete_selected_function() -> void:
	if _dock._current_sheet == null or _dock._functions_list == null:
		return
	var selected: PackedInt32Array = _dock._functions_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if index < 0 or index >= _dock._current_sheet.functions.size():
		return
	var removed_name: String = ""
	if _dock._current_sheet.functions[index] is EventFunction:
		removed_name = (_dock._current_sheet.functions[index] as EventFunction).function_name
	var changed: bool = _dock._perform_undoable_sheet_edit("Delete Function", func() -> bool:
		if index < _dock._current_sheet.functions.size():
			_dock._current_sheet.functions.remove_at(index)
			return true
		return false)
	if changed:
		_dock._mark_dirty("Deleted function %s()." % removed_name)
		_dock._refresh_functions_list()


## Highlights the generated lines for the currently selected sheet row and scrolls to them.
func update_code_panel_highlight() -> void:
	if _dock._code_edit == null or _dock._side_panel == null or not _dock._side_panel.visible:
		return
	if _dock._code_panel_highlight.x >= 0:
		for line in range(_dock._code_panel_highlight.x, _dock._code_panel_highlight.y + 1):
			if line < _dock._code_edit.get_line_count():
				_dock._code_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	_dock._code_panel_highlight = Vector2i(-1, -1)
	var selected: Resource = _dock._active_view().get_selected_context().get("source_resource", null) if _dock._viewport != null else null
	if selected == null:
		return
	var emitted: Vector2i = EventSheetLineRowMapper.range_for_resource(_dock._code_source_map, selected)
	var start_line: int = emitted.x - 1
	var end_line: int = mini(emitted.y - 1, _dock._code_edit.get_line_count() - 1)
	if start_line < 0 or end_line < start_line:
		return
	for line in range(start_line, end_line + 1):
		_dock._code_edit.set_line_background_color(line, _dock.CODE_PANEL_HIGHLIGHT_COLOR)
	_dock._code_edit.set_caret_line(start_line)
	_dock._code_panel_highlight = Vector2i(start_line, end_line)


## Reverse provenance: clicking a line of generated code selects the sheet row that
## produced it. Reacts only to mouse releases (never caret moves), so the forward
## direction - selection setting the caret in _dock._update_code_panel_highlight - cannot loop.
func on_code_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or mouse.pressed:
		return
	# The click already moved the caret; source maps are 1-based.
	_dock._select_sheet_row_for_code_line(_dock._code_edit.get_caret_line() + 1)


## The script editor's "Go to Sheet Row": shows the GDScript panel, refreshes the
## source map and selects the row that emitted the given 1-based generated line -
## errors and stack traces land on rows, not on generated code.
func goto_generated_line(line: int) -> void:
	_dock._ensure_code_panel()
	if not _dock._side_panel.visible:
		_dock._toggle_code_panel()
	else:
		_dock._refresh_code_panel()
	if _dock._code_edit != null and line > 0:
		_dock._code_edit.set_caret_line(maxi(line - 1, 0))
	_dock._select_sheet_row_for_code_line(line)


## Most-specific-first line→row lookup (the shared mapper), walking outward until something
## selects - inner entries may reference resources without rows of their own (e.g. an in-flow
## block inside an event's actions).
func select_sheet_row_for_code_line(line: int) -> void:
	if _dock._viewport == null:
		return
	for entry: Variant in EventSheetLineRowMapper.entries_for_line(_dock._code_source_map, line):
		var resource: Resource = instance_from_id(int(str((entry as Dictionary).get("uid", "0")))) as Resource
		if resource == null:
			continue
		# reveal_resource falls back where plain selection can't reach: a lifted function's Define
		# block lives inside the folded "Published verbs" section, and reveal unfolds ancestors.
		if _dock._viewport.select_resource(resource) or _dock._viewport.reveal_resource(resource):
			_dock._update_code_panel_highlight()
			return


## Double-clicking a GDScript block opens a CodeEdit dialog with compile-check linting and
## sheet-symbol completion. in_flow blocks live inside an event's actions (statements);
## class-level blocks are tree rows (helper functions, @onready vars, signals…).
func on_viewport_raw_code_edit_requested(raw_resource: Resource, in_flow: bool) -> void:
	var raw_row: RawCodeRow = raw_resource as RawCodeRow
	if raw_row == null:
		return
	_dock._ensure_raw_code_dialog()
	_dock._raw_code_target = raw_row
	_dock._raw_code_in_flow = in_flow
	_dock._raw_code_hint.text = (
		"Runs inside this event, right after its conditions pass - full GDScript, with the sheet's variables and host in scope. Written verbatim into the .gd."
		if in_flow
		else "Top-level GDScript - helper functions, @onready vars, signals… anything no built-in action covers. Written verbatim into the .gd and callable from your events."
	)
	_dock._raw_code_edit.text = raw_row.code
	_dock._validate_raw_code()
	_dock._raw_code_dialog.popup_centered(Vector2i(680, 460))
	_dock._raw_code_edit.grab_focus()


## Compile-checks the dialog's code against the sheet context (host class + sheet symbols).
func validate_raw_code() -> void:
	if _dock._raw_code_edit == null or _dock._raw_code_lint_label == null:
		return
	# Live hard-block: a STRUCTURAL error (unbalanced brackets / unterminated string) disables Save
	# immediately - always wrong, so it can never lock the user out on a lint false positive (a runtime-only
	# symbol). Semantic lint errors keep Save enabled but are caught on confirm (which re-opens the dialog).
	var structural: String = EventSheetGDScriptLint.structural_syntax_error(_dock._raw_code_edit.text)
	if _dock._raw_code_dialog != null:
		_dock._raw_code_dialog.get_ok_button().disabled = not structural.is_empty()
	if not structural.is_empty():
		_dock._raw_code_lint_label.text = "✗ %s" % structural
		_dock._raw_code_lint_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
		return
	var lint_result: Dictionary = EventSheetGDScriptLint.lint(_dock._raw_code_edit.text, _dock._raw_code_in_flow, _dock._current_sheet)
	if bool(lint_result.get("ok", true)):
		_dock._raw_code_lint_label.text = "✓ Compiles"
		_dock._raw_code_lint_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
	else:
		_dock._raw_code_lint_label.text = "✗ %s" % str(lint_result.get("error", "Does not compile."))
		_dock._raw_code_lint_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))


## Supplies sheet variables/functions and host-class members as completion candidates.
func populate_raw_code_completion() -> void:
	if _dock._raw_code_edit == null:
		return
	# Context-aware: `host.` / typed-variable. / $Behavior. offer that type's members.
	for candidate: Dictionary in EventSheetGDScriptLint.completion_for_context(_dock._text_before_caret(_dock._raw_code_edit), _dock._current_sheet):
		var label: String = str(candidate.get("label", ""))
		_dock._raw_code_edit.add_code_completion_option(int(candidate.get("kind", CodeEdit.KIND_PLAIN_TEXT)), label, label)
	_dock._raw_code_edit.update_code_completion_options(true)
	_dock._raw_code_edit.set_code_hint(EventSheetGDScriptLint.signature_hint(_dock._text_before_caret(_dock._raw_code_edit), _dock._current_sheet))


func on_raw_code_dialog_confirmed() -> void:
	if _dock._raw_code_target == null:
		return
	var target: RawCodeRow = _dock._raw_code_target
	# Guardrail: broken GDScript never commits - the dialog reopens with the text intact.
	var commit_lint: Dictionary = EventSheetGDScriptLint.lint(_dock._raw_code_edit.text, _dock._raw_code_in_flow, _dock._current_sheet)
	if not bool(commit_lint.get("ok", true)):
		_dock._set_status("GDScript block not saved: fix the error first (or Cancel to discard).", true)
		if _dock.is_inside_tree():
			_dock._raw_code_dialog.call_deferred("popup_centered", Vector2i(680, 420))
		return
	_dock._raw_code_target = null
	var new_code: String = _dock._raw_code_edit.text
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit GDScript Block", func() -> bool:
		if target.code == new_code:
			return false
		target.code = new_code
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Updated GDScript block.")
