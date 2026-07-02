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
	var mode: String = "" if definition.ace_type == ACEDefinition.ACEType.ACTION else "new_condition_event"
	var context: Dictionary = {
		"mode": mode,
		"selected_resource": _dock._active_view().get_selected_context().get("source_resource", null)
	}
	if _popup != null:
		_popup.hide()
	_dock._apply_ace_definition(definition, candidate.get("params", {}), context)

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
