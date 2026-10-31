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

## The files this helper reaches BY PATH, at the moment something asks: naming one of these
## classes here would compile it, and everything it names, into the first open of a sheet.
const SHEET_COMPILER_PATH := "res://addons/eventforge/compiler/sheet_compiler.gd"
const COMPLETIONS_PATH := "res://addons/eventsheet/editor/autocomplete/completion_sources.gd"
const LINT_PATH := "res://addons/eventsheet/ace/gdscript_lint.gd"

var _dock: Control = null
## The Sheet | Code | Side by side switch, once a behaviour or a global has been shown.
var _view_switch: EventSheetPopupUI.ViewSwitch = null


func init(dock: Control) -> void:
	_dock = dock


## The side panel's tabs follow the open sheet: Anatomy, the Picker preview and Objects re-read it.
func refresh_anatomy_panel() -> void:
	if _dock._anatomy_panel != null:
		_dock._anatomy_panel.refresh(_dock._current_sheet)
	if _dock._picker_preview_panel != null:
		_dock._picker_preview_panel.refresh(_dock._current_sheet)
	# The Objects rail is a census of the OPEN sheet's own rows, so it refreshes with the rest
	# of the rail rather than keeping any state of its own between sheets.
	if _dock._objects_panel != null:
		_dock._objects_panel.set_sheet(_dock._current_sheet)
	refresh_rail_census()


## Which rail panels the open sheet has anything to put in: Anatomy is a behaviour pack's organs,
## and the Picker preview is how this sheet's verbs will read in the picker, so it is on offer only
## while the picker is on screen. Everything else is every sheet's.
func refresh_rail_census() -> void:
	if _dock._rail_panels == null:
		return
	_dock._rail_panels.set_census(
		_dock._current_sheet != null and _dock._current_sheet.behavior_mode,
		_dock._ace_picker_built and _dock._ace_picker.is_open())
	_dock._rail_panels.refresh_tab_tooltips()


func toggle_code_panel() -> void:
	_dock._ui_builder.ensure_code_panel()
	_dock._side_panel.visible = not _dock._side_panel.visible
	_dock._split.dragger_visibility = (
		SplitContainer.DRAGGER_VISIBLE if _dock._side_panel.visible else SplitContainer.DRAGGER_HIDDEN_COLLAPSED
	)
	if _dock._side_panel.visible:
		refresh_code_panel()


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
	refresh_functions_list()
	if _dock._current_sheet == null:
		_dock._code_edit.text = ""
		_dock._code_source_map = []
		_dock._code_panel_highlight = Vector2i(-1, -1)
		return
	# The output of a sheet that has not changed is the output it had: a compile is paid for by an
	# edit, never by looking at another tab and coming back. The cache is the tab's own and is held
	# against the same revision its rows are, so it can never show the previous sheet's code.
	var cached: Dictionary = _dock._tab_state.cached_code()
	if not cached.is_empty():
		_dock._code_edit.text = str(cached.get("text", ""))
		_dock._code_source_map = cached.get("map", [])
		_dock._code_panel_highlight = Vector2i(-1, -1)
		_dock._code_panel_glue.update_code_panel_highlight()
		return
	var compile_result: Dictionary = load(SHEET_COMPILER_PATH).compile(_dock._current_sheet, "user://eventforge_code_panel_preview.gd")
	_dock._code_edit.text = str(compile_result.get("output", ""))
	_dock._code_source_map = compile_result.get("source_map", [])
	_dock._tab_state.store_code(_dock._code_edit.text, _dock._code_source_map)
	_dock._code_panel_highlight = Vector2i(-1, -1)
	_dock._code_panel_glue.update_code_panel_highlight()


## Repopulates the Functions tab from the active sheet. Cheap; runs whenever the side panel
## refreshes (i.e. on any edit while it's open).
func refresh_functions_list() -> void:
	if _dock._functions_panel != null:
		_dock._functions_panel.set_sheet(_dock._current_sheet)


## Right-click a sheet function to delete it (the list is otherwise read-only - editing is via the
## rows). A function still written as code has no menu: it is edited where it is written.
func on_functions_list_item_clicked(at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT or _dock._functions_menu == null or _dock._functions_panel == null:
		return
	if _dock._functions_panel.selected_function_index() < 0:
		return
	_dock._functions_menu.position = Vector2i(_dock._functions_list.get_screen_position() + at_position)
	_dock._functions_menu.reset_size()
	_dock._functions_menu.popup()


func on_functions_menu_id_pressed(id: int) -> void:
	if id == 0:
		delete_selected_function()


## Removes the selected function from the sheet (undoable) and refreshes the list + preview.
func delete_selected_function() -> void:
	if _dock._current_sheet == null or _dock._functions_panel == null:
		return
	var index: int = _dock._functions_panel.selected_function_index()
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
		refresh_functions_list()


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
## direction - selection setting the caret in _dock._code_panel_glue.update_code_panel_highlight - cannot loop.
func on_code_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or mouse.pressed:
		return
	# The click already moved the caret; source maps are 1-based.
	_dock._code_panel_glue.select_sheet_row_for_code_line(_dock._code_edit.get_caret_line() + 1)


## The code echo beside a variable row, activated: show the GDScript panel and put the caret on
## the very line that row writes. The reverse direction already works (clicking a line of generated
## code selects the row that produced it), so this closes the loop from the canvas side.
func open_at_row(row_data: EventRowData) -> void:
	if row_data == null or row_data.source_resource == null:
		return
	_dock._ui_builder.ensure_code_panel()
	if not _dock._side_panel.visible:
		_dock._code_panel_glue.toggle_code_panel()
	else:
		refresh_code_panel()
	var emitted: Vector2i = EventSheetLineRowMapper.range_for_resource(_dock._code_source_map, row_data.source_resource)
	if _dock._code_edit != null and emitted.x > 0:
		_dock._code_edit.set_caret_line(maxi(emitted.x - 1, 0))
	_dock._code_panel_glue.update_code_panel_highlight()


## The script editor's "Go to Sheet Row": shows the GDScript panel, refreshes the
## source map and selects the row that emitted the given 1-based generated line -
## errors and stack traces land on rows, not on generated code.
func goto_generated_line(line: int) -> void:
	_dock._ui_builder.ensure_code_panel()
	if not _dock._side_panel.visible:
		_dock._code_panel_glue.toggle_code_panel()
	else:
		refresh_code_panel()
	if _dock._code_edit != null and line > 0:
		_dock._code_edit.set_caret_line(maxi(line - 1, 0))
	_dock._code_panel_glue.select_sheet_row_for_code_line(line)


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
		# reveal_resource falls back where plain selection can't reach (e.g. a resource nested inside a
		# folded section like the Class-setup strip); it unfolds ancestors before selecting.
		if _dock._viewport.select_resource(resource) or _dock._viewport.reveal_resource(resource):
			_dock._code_panel_glue.update_code_panel_highlight()
			return


## Double-clicking a GDScript block opens a CodeEdit dialog with compile-check linting and
## sheet-symbol completion. in_flow blocks live inside an event's actions (statements);
## class-level blocks are tree rows (helper functions, @onready vars, signals…).
func on_viewport_raw_code_edit_requested(raw_resource: Resource, in_flow: bool) -> void:
	if raw_resource is InnerClassRow:
		raw_resource = _class_as_code(raw_resource as InnerClassRow)
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
	_dock._code_panel_glue.validate_raw_code()
	_dock._raw_code_dialog.popup_centered(Vector2i(680, 460))
	_dock._raw_code_edit.grab_focus()


## A class read as rows, turned back into the code block it is written as, so it can be edited as
## code: the same lines, through the undo funnel. Returns the live code row, or null when the class is
## not in the sheet. The class reads as rows again the next time the file is opened.
func _class_as_code(inner: InnerClassRow) -> RawCodeRow:
	var sheet: EventSheetResource = _dock._current_sheet
	var index: int = sheet.events.find(inner) if sheet != null else -1
	if index < 0:
		return null
	var code: String = "\n".join(load(SHEET_COMPILER_PATH).inner_class_lines(inner))
	_dock._perform_undoable_sheet_edit("Edit Class as Code", func() -> bool:
		var as_code: RawCodeRow = RawCodeRow.new()
		as_code.code = code
		_dock._current_sheet.events[index] = as_code
		return true
	)
	# The commit replaces every resource with its snapshot copy, so the row is fetched again.
	return _dock._current_sheet.events[index] as RawCodeRow


## Compile-checks the dialog's code against the sheet context (host class + sheet symbols).
func validate_raw_code() -> void:
	if _dock._raw_code_edit == null or _dock._raw_code_lint_label == null:
		return
	# Live hard-block: a STRUCTURAL error (unbalanced brackets / unterminated string) disables Save
	# immediately - always wrong, so it can never lock the user out on a lint false positive (a runtime-only
	# symbol). Semantic lint errors keep Save enabled but are caught on confirm (which re-opens the dialog).
	var structural: String = load(LINT_PATH).structural_syntax_error(_dock._raw_code_edit.text)
	if _dock._raw_code_dialog != null:
		_dock._raw_code_dialog.get_ok_button().disabled = not structural.is_empty()
	if not structural.is_empty():
		_dock._raw_code_lint_label.text = "✗ %s" % structural
		_dock._raw_code_lint_label.add_theme_color_override("font_color", EventSheetPopupUI.readable_on_panel(Color(0.95, 0.5, 0.5)))
		return
	var lint_result: Dictionary = load(LINT_PATH).lint(_dock._raw_code_edit.text, _dock._raw_code_in_flow, _dock._current_sheet)
	if bool(lint_result.get("ok", true)):
		_dock._raw_code_lint_label.text = "✓ Compiles"
		_dock._raw_code_lint_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
	else:
		_dock._raw_code_lint_label.text = "✗ %s" % str(lint_result.get("error", "Does not compile."))
		_dock._raw_code_lint_label.add_theme_color_override("font_color", EventSheetPopupUI.readable_on_panel(Color(0.95, 0.5, 0.5)))


## Contributes the SHEET's own names to Godot's completion in a Script block. The block keeps the
## engine's popup and the engine's keys - it is a GDScript editor, and a reader typing in one
## already knows how it behaves - so what the plugin adds is the vocabulary, through the same
## completion seam every other field asks.
func populate_raw_code_completion() -> void:
	if _dock._raw_code_edit == null:
		return
	var before_caret: String = _dock._text_before_caret(_dock._raw_code_edit)
	for entry: Dictionary in load(COMPLETIONS_PATH).for_field(_dock._current_sheet,
			load(COMPLETIONS_PATH).FIELD_EXPRESSION, before_caret):
		var label: String = str(entry.get("text", ""))
		_dock._raw_code_edit.add_code_completion_option(
			load(COMPLETIONS_PATH).code_edit_kind(str(entry.get("kind", ""))), label, label)
	_dock._raw_code_edit.update_code_completion_options(true)
	_dock._raw_code_edit.set_code_hint(load(LINT_PATH).signature_hint(_dock._text_before_caret(_dock._raw_code_edit), _dock._current_sheet))


func on_raw_code_dialog_confirmed() -> void:
	if _dock._raw_code_target == null:
		return
	var target: RawCodeRow = _dock._raw_code_target
	# Guardrail: broken GDScript never commits - the dialog reopens with the text intact.
	var commit_lint: Dictionary = load(LINT_PATH).lint(_dock._raw_code_edit.text, _dock._raw_code_in_flow, _dock._current_sheet)
	if not bool(commit_lint.get("ok", true)):
		_dock._set_status("Script block not saved: fix the error first (or Cancel to discard).", true)
		if _dock.is_inside_tree():
			_dock._raw_code_dialog.call_deferred("popup_centered", Vector2i(680, 420))
		return
	_dock._raw_code_target = null
	var new_code: String = _dock._raw_code_edit.text
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Script Block", func() -> bool:
		if target.code == new_code:
			return false
		target.code = new_code
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Updated script block.")


# ── The Events | Code | Both switch above the sheet ───────────────────────────────────────────────
# Every open sheet is a file somebody may want to read either way, so the strip above the sheet
# carries the switch whenever a sheet is open: the rows, the GDScript the file is, or both at once.
# The selection is kept in step both ways (a row highlights its lines, a clicked line selects its
# row), and the docked Manual follows either, since both end in the same selection.


## The switch's three words: Events, Code and Both, with what each shows.
static func view_switch_words() -> Dictionary:
	return {
		EventSheetPopupUI.ViewSwitch.SHEET: [EventSheetL10n.translate("Events"),
			EventSheetL10n.translate("The file read as events.")],
		EventSheetPopupUI.ViewSwitch.CODE: [EventSheetL10n.translate("Code"),
			EventSheetL10n.translate("The file as the GDScript it is, byte for byte. Click a line to select the row that writes it.")],
		EventSheetPopupUI.ViewSwitch.BOTH: [EventSheetL10n.translate("Both"),
			EventSheetL10n.translate("The events and the lines they write, side by side. Selecting either highlights the other.")],
	}


## Whether the switch is offered for `sheet`: for any sheet that is open.
static func offers_view_switch(sheet: EventSheetResource) -> bool:
	return sheet != null


func refresh_view_switch() -> void:
	var offered: bool = offers_view_switch(_dock._current_sheet)
	if _view_switch == null:
		# On the toolbar, at its end: the strip that held it under the tabs is no longer shown.
		var holder: Control = _dock._toolbar if _dock._toolbar != null else _dock._title_strip
		if not offered or holder == null:
			return
		_view_switch = EventSheetPopupUI.ViewSwitch.new(EventSheetPopupUI.ViewSwitch.SHEET, view_switch_words())
		_view_switch.name = "EventSheetViewSwitch"
		_view_switch.view_chosen.connect(set_sheet_view)
		holder.add_child(_view_switch)
		# One of the controls the strip rests with, in either layout: the switch is the reading door.
		if _dock._menu_bar != null and not _dock._menu_bar._resting_controls.has(_view_switch):
			_dock._menu_bar._resting_controls.append(_view_switch)
	_view_switch.visible = offered
	if not offered and _dock._scroll != null and not _dock._scroll.visible:
		# A sheet with no switch always shows its rows.
		set_sheet_view(EventSheetPopupUI.ViewSwitch.SHEET)
		return
	_view_switch.choose(current_sheet_view(), false)


## Which of the three the dock shows now.
func current_sheet_view() -> String:
	if not _dock.is_code_panel_visible():
		return EventSheetPopupUI.ViewSwitch.SHEET
	return EventSheetPopupUI.ViewSwitch.CODE if not _dock._scroll.visible else EventSheetPopupUI.ViewSwitch.BOTH


## Shows the rows, the code, or both side by side. The code is the panel the View menu opens.
func set_sheet_view(view: String) -> void:
	# Code while a .gd is still being read as events is the other door to "show as code".
	if view == EventSheetPopupUI.ViewSwitch.CODE and _dock._open_progress != null:
		_dock._open_progress.request_code()
	var wants_code: bool = view != EventSheetPopupUI.ViewSwitch.SHEET
	if wants_code != _dock.is_code_panel_visible():
		toggle_code_panel()
	if _dock._scroll != null:
		_dock._scroll.visible = view != EventSheetPopupUI.ViewSwitch.CODE
	if _view_switch != null:
		_view_switch.choose(view, false)
