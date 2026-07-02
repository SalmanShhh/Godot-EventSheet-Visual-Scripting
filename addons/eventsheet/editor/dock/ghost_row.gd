@tool
extends RefCounted
class_name EventSheetGhostRow
# The zero-dialog add: pressing E / C / A materialises a small type-a-sentence popup at the selected
# row instead of the full picker window. Type "heal 5" or "every tick" — the quick-add brain scores it
# live and the list shows the top matches with their filled parameters; Enter applies the highlighted
# one straight onto the sheet, ↑/↓ choose, Esc cancels, and Ctrl+Enter opens the full picker for
# browsing (the picker stays one keystroke away — it doubles as the illustrated catalog a beginner
# learns the vocabulary from).
#
# ONE transient PopupPanel parented on the dock — never a per-row control, so the virtualized canvas
# stays widget-free — anchored just under the selected row (or at the mouse when nothing is selected).
# While its LineEdit has focus the dock's single-key reflexes suppress themselves exactly as they do
# for any focused text field, so typing "e" into the query never re-triggers Add Event.

var _dock: Control = null
var _popup: PopupPanel = null
var _edit: LineEdit = null
var _list: ItemList = null
var _candidates: Array = []      # the ranked {definition, params, score} entries backing the list
var _origin: String = "action"   # which add key opened it: "event" / "condition" / "action"

func init(dock: Control) -> void:
	_dock = dock

## Opens the ghost row for the add-kind that summoned it. In a headless run the popup can't show, so
## this only resets the query state — the match/apply flow stays fully drivable by tests.
func open(origin: String) -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_origin = origin
	_ensure_popup()
	_edit.text = ""
	_refresh("")
	if not Engine.is_editor_hint() and DisplayServer.get_name() == "headless":
		return
	_popup.popup(Rect2i(_anchor_position(), Vector2i(0, 0)))
	_edit.grab_focus()

func _ensure_popup() -> void:
	if _popup != null:
		return
	_popup = PopupPanel.new()
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_edit = LineEdit.new()
	_edit.placeholder_text = "Type what to add…  e.g. heal 5  ·  play sound \"jump\""
	_edit.custom_minimum_size = Vector2(420.0, 0.0)
	_edit.text_changed.connect(_refresh)
	_edit.text_submitted.connect(func(_text: String) -> void: _apply_selected())
	_edit.gui_input.connect(_on_edit_input)
	box.add_child(_edit)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(420.0, 118.0)
	_list.item_activated.connect(func(index: int) -> void:
		_list.select(index)
		_apply_selected())
	box.add_child(_list)
	var hint: Label = Label.new()
	hint.text = "⏎ add  ·  ↑/↓ choose  ·  Ctrl+⏎ browse the full picker  ·  Esc cancel"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1.0, 1.0, 1.0, 0.65)
	box.add_child(hint)
	_popup.add_child(box)
	_dock.add_child(_popup)

## Keyboard on the query field: ↑/↓ steer the suggestion list without leaving the text, Ctrl+Enter
## opens the full picker (Esc already closes any PopupPanel).
func _on_edit_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key: InputEventKey = event as InputEventKey
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER] and (key.ctrl_pressed or key.meta_pressed):
		_open_full_picker()
		_edit.accept_event()
	elif key.keycode == KEY_DOWN:
		_move_selection(1)
		_edit.accept_event()
	elif key.keycode == KEY_UP:
		_move_selection(-1)
		_edit.accept_event()

func _move_selection(delta: int) -> void:
	if _list == null or _list.item_count == 0:
		return
	var selected: PackedInt32Array = _list.get_selected_items()
	var current: int = selected[0] if selected.size() > 0 else 0
	_list.select(clampi(current + delta, 0, _list.item_count - 1))

## Rebuilds the suggestion list from the ranked quick-add candidates for the current query text.
func _refresh(query: String) -> void:
	_candidates = _dock._quick_match_ranked(query, 5) if not query.strip_edges().is_empty() else []
	if _list == null:
		return
	_list.clear()
	for candidate: Dictionary in _candidates:
		var definition: ACEDefinition = candidate.get("definition")
		var glyph: String = "⚡"
		if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
			glyph = "➜"
		elif definition.ace_type == ACEDefinition.ACEType.CONDITION:
			glyph = "?"
		var summary: String = ""
		var params: Dictionary = candidate.get("params", {})
		for key: Variant in params:
			summary += "  %s" % str(params[key])
		_list.add_item("%s  %s%s" % [glyph, definition.display_name, summary])
	if _list.item_count > 0:
		_list.select(0)

## Applies the highlighted candidate straight onto the sheet: a trigger/condition becomes a new
## conditioned event, an action appends to the selected event — the same apply flow the quick-add bar
## and the picker use, so undo/refresh/params-dialog behavior is identical.
func _apply_selected() -> void:
	if _candidates.is_empty():
		if not _edit.text.strip_edges().is_empty():
			_dock._set_status("Nothing matches \"%s\" — Ctrl+Enter browses the full picker." % _edit.text.strip_edges(), true)
		return
	var selected: PackedInt32Array = _list.get_selected_items() if _list != null else PackedInt32Array()
	var index: int = selected[0] if selected.size() > 0 else 0
	if index < 0 or index >= _candidates.size():
		index = 0
	var candidate: Dictionary = _candidates[index]
	var definition: ACEDefinition = candidate.get("definition")
	var selected_resource: Resource = _dock._active_view().get_selected_context().get("source_resource", null)
	# Mode mirrors the classic picker flows: an action APPENDS to the selected event (mode "" would
	# fall into the apply's default branch and wrap it in a NEW event — only right with no selection);
	# a condition summoned by the C key also appends; triggers and the E key start a new event.
	var mode: String = "new_condition_event"
	if definition.ace_type == ACEDefinition.ACEType.ACTION:
		mode = "append_action" if selected_resource is EventRow else ""
	elif definition.ace_type == ACEDefinition.ACEType.CONDITION and _origin == "condition" and selected_resource is EventRow:
		mode = "append_condition"
	var context: Dictionary = {
		"mode": mode,
		"selected_resource": selected_resource
	}
	if _popup != null:
		_popup.hide()
	_dock._apply_ace_definition(definition, candidate.get("params", {}), context)
	_continue_into_params(definition, candidate.get("params", {}))

# The just-applied ACE's first param the sentence did NOT fill, staged for the follow-up editor.
# Kept as a member so tests can assert the continuation target without a window.
var _last_follow_up: Dictionary = {}

## Post-insert continuation: when the sentence left parameters unfilled ("heal" with no amount), the
## one-field param editor opens straight onto the first of them — pre-filled with the resolved default
## and select-all'd — so `A → heal ⏎ → 5 ⏎` completes with zero dialogs. A fully-specified sentence
## ("heal 5") applies silently. Either way the affected row is revealed, so pressing an add key again
## continues the stream right below it.
func _continue_into_params(definition: ACEDefinition, filled: Dictionary) -> void:
	_last_follow_up = {}
	var found: Dictionary = _find_applied_ace(definition)
	if found.is_empty():
		return
	var view: EventSheetViewport = _dock._active_view()
	if view != null:
		view.reveal_resource(found.get("row"))
	var ace: Resource = found.get("ace")
	for parameter: Variant in definition.parameters:
		if not (parameter is Dictionary):
			continue
		var param_id: String = str((parameter as Dictionary).get("id", ""))
		if param_id.is_empty() or filled.has(param_id):
			continue
		_last_follow_up = {"ace": ace, "param_id": param_id}
		if not Engine.is_editor_hint() and DisplayServer.get_name() == "headless":
			return
		_dock._inline_params.on_param_value_edit_requested(ace, param_id, str((ace.get("params") as Dictionary).get(param_id, "")))
		return

## Locates the LIVE just-applied ACE. The apply runs through the undo funnel, whose commit restores a
## duplicated snapshot — the resources it created are replaced — so the only reliable handle is a
## reverse walk of the live sheet for the newest ACE with this definition's id. {row, ace} or {}.
func _find_applied_ace(definition: ACEDefinition) -> Dictionary:
	var sheet: EventSheetResource = _dock.get_current_sheet()
	if sheet == null:
		return {}
	for index: int in range(sheet.events.size() - 1, -1, -1):
		var found: Dictionary = _find_in_row(sheet.events[index], definition.id)
		if not found.is_empty():
			return found
	return {}

func _find_in_row(row: Variant, ace_id: String) -> Dictionary:
	if row is EventGroup:
		var group_rows: Array = (row as EventGroup).events if not (row as EventGroup).events.is_empty() else (row as EventGroup).rows
		for index: int in range(group_rows.size() - 1, -1, -1):
			var found: Dictionary = _find_in_row(group_rows[index], ace_id)
			if not found.is_empty():
				return found
		return {}
	if not (row is EventRow):
		return {}
	var event_row: EventRow = row as EventRow
	for index: int in range(event_row.sub_events.size() - 1, -1, -1):
		var found: Dictionary = _find_in_row(event_row.sub_events[index], ace_id)
		if not found.is_empty():
			return found
	for index: int in range(event_row.actions.size() - 1, -1, -1):
		if event_row.actions[index] is ACEAction and (event_row.actions[index] as ACEAction).ace_id == ace_id:
			return {"row": event_row, "ace": event_row.actions[index]}
	for index: int in range(event_row.conditions.size() - 1, -1, -1):
		if event_row.conditions[index].ace_id == ace_id:
			return {"row": event_row, "ace": event_row.conditions[index]}
	if event_row.trigger != null and event_row.trigger.ace_id == ace_id:
		return {"row": event_row, "ace": event_row.trigger}
	return {}

## Ctrl+Enter — the browsable catalog is one keystroke away; which picker opens follows the add-kind
## that summoned the ghost row.
func _open_full_picker() -> void:
	if _popup != null:
		_popup.hide()
	match _origin:
		"event":
			_dock._on_add_event_requested()
		"condition":
			_dock._on_add_condition_requested()
		_:
			_dock._on_add_action_requested()

## Just under the selected row (zoom-aware), so the suggestions appear where the new row will land;
## falls back to the mouse when nothing is selected.
func _anchor_position() -> Vector2i:
	var view: EventSheetViewport = _dock._active_view()
	if view != null and view.get_selected_row_index() >= 0:
		var row_index: int = view.get_selected_row_index()
		var zoom: float = view.get_zoom_factor()
		var local_y: float = (view._row_metrics_helper.row_top(row_index) + view._row_metrics_helper.row_height(row_index)) * zoom
		return Vector2i(view.get_screen_position() + Vector2(60.0, local_y))
	return DisplayServer.mouse_get_position()
