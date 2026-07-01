@tool
extends RefCounted
class_name EventSheetFindBar
# The FIND & REPLACE bar cluster. This helper owns:
#   • the script-editor-style find bar behaviour — Ctrl+F opens it, Enter/F3 steps to the next match,
#     Shift+F3 the previous, Esc hides it (matches recompute on every step so results never go stale,
#     and find lands inside folded groups by unfolding the path to the match),
#   • Replace All across the whole sheet — comments, GDScript blocks, string params, pick-filter
#     expressions, group names/descriptions and match branches, as one undoable edit with a count,
#   • `_replace_in_rows`, the long/branchy recursion Replace All (and project-wide find) walk to
#     substitute text through the full row/ACE/group tree.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • the find-bar WIDGET members `_find_bar` / `_find_edit` / `_find_count_label` / `_replace_edit`
#     and the match-cursor state `_find_resource_matches` / `_find_cursor` — they stay declared on the
#     dock so the tests (godot_feel_test, ux_polish_test) and project_find.gd can read them by name.
#     `_ensure_find_bar()` (the builder) constructs them and assigns each back via `_dock._find_bar = …`
#     etc. (mirrors the menu_bar "widgets-stay, builder-assigns-back" pattern),
#   • the `_toolbar` the find bar is added into,
#   • the mutation funnel (`_perform_undoable_sheet_edit` / `_mark_dirty` / `_set_status` /
#     `_refresh_after_edit`), plus `_current_sheet` and `_viewport` / `_active_view`,
#   • `_open_match_in_split` — the find bar's "Open in Split" button keeps calling the dock delegate
#     (already a _multi_view delegate on the dock).
# Globals are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures + returns) for every method
# reached from outside this helper — the in-file `_viewport.find_requested.connect(_show_find_bar)`
# site, the tests, and the sibling dock/ helpers (multi_view_manager → `_dock._show_find_bar` /
# `_dock._find_step`; project_find → `_dock._ensure_find_bar` / `_dock._replace_in_rows` /
# `_dock._replace_all_in_sheet`) — so those callers resolve unchanged.
#
# CLOSURE NOTES:
#   • `_ensure_find_bar`'s `gui_input` lambda captures the WIDGET `_find_bar` and `_viewport`, which
#     live on the dock — so both reach through `_dock.`,
#   • the close-button lambda captures `_find_bar` → `_dock.`,
#   • `_replace_all_in_sheet`'s undoable lambda captures the LOCALS `counter` / `find_text` /
#     `replace_text` (not helper/dock members, so they survive verbatim) and calls `_replace_in_rows`
#     (a moved sibling, stays bare) plus `_current_sheet` → `_dock.`.

var _dock: Control = null

func init(dock: Control) -> void:
	_dock = dock

## Ctrl+F: a script-editor-style find bar (Enter/F3 next, Shift+F3 previous, Esc hides).
func _show_find_bar() -> void:
	_ensure_find_bar()
	_dock._find_bar.visible = true
	_dock._find_edit.grab_focus()
	_dock._find_edit.select_all()

func _ensure_find_bar() -> void:
	if _dock._find_bar != null:
		return
	_dock._find_bar = HBoxContainer.new()
	_dock._find_bar.name = "EventSheetFindBar"
	_dock._find_edit = LineEdit.new()
	_dock._find_edit.placeholder_text = "Find in sheet…  (Enter: next, Esc: close)"
	_dock._find_edit.custom_minimum_size = Vector2(220.0, 0.0)
	_dock._find_edit.text_changed.connect(_on_find_text_changed)
	_dock._find_edit.text_submitted.connect(func(_text: String) -> void: _find_step(1))
	_dock._find_edit.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventKey and (input_event as InputEventKey).pressed and (input_event as InputEventKey).keycode == KEY_ESCAPE:
			_dock._find_bar.visible = false
			if _dock._viewport != null:
				_dock._viewport.grab_focus()
	)
	_dock._find_bar.add_child(_dock._find_edit)
	_dock._find_count_label = Label.new()
	_dock._find_count_label.text = ""
	_dock._find_bar.add_child(_dock._find_count_label)
	_dock._replace_edit = LineEdit.new()
	_dock._replace_edit.placeholder_text = "Replace with…"
	_dock._replace_edit.custom_minimum_size = Vector2(160.0, 0.0)
	_dock._find_bar.add_child(_dock._replace_edit)
	var replace_button: Button = Button.new()
	replace_button.text = "Replace All"
	replace_button.pressed.connect(_replace_all_in_sheet)
	_dock._find_bar.add_child(replace_button)
	var split_match_button: Button = Button.new()
	split_match_button.text = "Open in Split"
	split_match_button.tooltip_text = "Open the current match in the split pane."
	split_match_button.pressed.connect(_dock._open_match_in_split)
	_dock._find_bar.add_child(split_match_button)
	var close_button: Button = Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.pressed.connect(func() -> void: _dock._find_bar.visible = false)
	_dock._find_bar.add_child(close_button)
	_dock._toolbar.add_child(_dock._find_bar)

func _on_find_text_changed(text: String) -> void:
	_dock._find_resource_matches = _dock._viewport.search_all(text) if _dock._viewport != null else []
	_dock._find_cursor = -1
	if _dock._find_resource_matches.is_empty():
		_dock._find_count_label.text = "no matches" if not text.strip_edges().is_empty() else ""
		return
	_find_step(1)

func _find_step(direction: int) -> void:
	# Matches recompute on every step (results go stale after any edit) and search the
	# FULL tree — find lands inside folded groups by unfolding the path to the match.
	if _dock._find_edit == null or _dock._viewport == null or _dock._find_edit.text.strip_edges().is_empty():
		return
	_dock._find_resource_matches = _dock._viewport.search_all(_dock._find_edit.text)
	if _dock._find_resource_matches.is_empty():
		if _dock._find_count_label != null:
			_dock._find_count_label.text = "no matches"
		return
	_dock._find_cursor = wrapi(_dock._find_cursor + direction, 0, _dock._find_resource_matches.size())
	_dock._find_count_label.text = "%d of %d" % [_dock._find_cursor + 1, _dock._find_resource_matches.size()]
	_dock._viewport.reveal_resource(_dock._find_resource_matches[_dock._find_cursor])

## Replace All: substitutes the find text across comments, GDScript blocks, string
## params, pick-filter expressions, group names/descriptions and match branches —
## one undoable edit, count reported.
func _replace_all_in_sheet() -> void:
	if _dock._viewport == null or _dock._current_sheet == null or _dock._find_edit == null or _dock._replace_edit == null:
		return
	var find_text: String = _dock._find_edit.text
	if find_text.is_empty():
		_dock._set_status("Type something in Find first.", true)
		return
	var replace_text: String = _dock._replace_edit.text
	var counter: Dictionary = {"count": 0}
	var changed: bool = _dock._perform_undoable_sheet_edit("Replace All", func() -> bool:
		_replace_in_rows(_dock._current_sheet.events, find_text, replace_text, counter)
		for function_resource: Variant in _dock._current_sheet.functions:
			if function_resource is EventFunction:
				_replace_in_rows((function_resource as EventFunction).events if not (function_resource as EventFunction).events.is_empty() else (function_resource as EventFunction).rows, find_text, replace_text, counter)
		return int(counter.get("count", 0)) > 0
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Replaced %d occurrence(s)." % int(counter.get("count", 0)))
	else:
		_dock._set_status("No matches for \"%s\"." % find_text)

func _replace_in_rows(rows: Array, find_text: String, replace_text: String, counter: Dictionary) -> void:
	for row: Variant in rows:
		if row is CommentRow:
			counter["count"] = int(counter.get("count", 0)) + (row as CommentRow).text.count(find_text)
			(row as CommentRow).text = (row as CommentRow).text.replace(find_text, replace_text)
		elif row is RawCodeRow:
			counter["count"] = int(counter.get("count", 0)) + (row as RawCodeRow).code.count(find_text)
			(row as RawCodeRow).code = (row as RawCodeRow).code.replace(find_text, replace_text)
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			counter["count"] = int(counter.get("count", 0)) + group.group_name.count(find_text) + group.description.count(find_text)
			group.group_name = group.group_name.replace(find_text, replace_text)
			group.name = group.group_name
			group.description = group.description.replace(find_text, replace_text)
			_replace_in_rows(group.events if not group.events.is_empty() else group.rows, find_text, replace_text, counter)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			for ace: Variant in event_row.conditions + event_row.actions:
				if ace is RawCodeRow:
					counter["count"] = int(counter.get("count", 0)) + (ace as RawCodeRow).code.count(find_text)
					(ace as RawCodeRow).code = (ace as RawCodeRow).code.replace(find_text, replace_text)
				elif ace is MatchRow:
					counter["count"] = int(counter.get("count", 0)) + (ace as MatchRow).branches_text.count(find_text)
					(ace as MatchRow).branches_text = (ace as MatchRow).branches_text.replace(find_text, replace_text)
				elif ace is Resource and ace.get("params") is Dictionary:
					if ace.get("comment") is String and not str(ace.get("comment")).is_empty():
						counter["count"] = int(counter.get("count", 0)) + str(ace.get("comment")).count(find_text)
						ace.set("comment", str(ace.get("comment")).replace(find_text, replace_text))
					var params: Dictionary = ace.get("params")
					for key: Variant in params.keys():
						if params[key] is String:
							counter["count"] = int(counter.get("count", 0)) + (params[key] as String).count(find_text)
							params[key] = (params[key] as String).replace(find_text, replace_text)
			for pick: Variant in event_row.pick_filters:
				if pick is PickFilter:
					counter["count"] = int(counter.get("count", 0)) + (pick as PickFilter).collection_value.count(find_text) + (pick as PickFilter).predicate_expression.count(find_text) + (pick as PickFilter).order_by_expression.count(find_text)
					(pick as PickFilter).collection_value = (pick as PickFilter).collection_value.replace(find_text, replace_text)
					(pick as PickFilter).predicate_expression = (pick as PickFilter).predicate_expression.replace(find_text, replace_text)
					(pick as PickFilter).order_by_expression = (pick as PickFilter).order_by_expression.replace(find_text, replace_text)
			if not event_row.with_node_target.is_empty():
				counter["count"] = int(counter.get("count", 0)) + event_row.with_node_target.count(find_text)
				event_row.with_node_target = event_row.with_node_target.replace(find_text, replace_text)
			_replace_in_rows(event_row.sub_events, find_text, replace_text, counter)
