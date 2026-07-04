# Godot EventSheets - UX polish slice: C/A/E reflexes, picker recents, onboarding
# watermark, inline live-value chips, bookmarks panel, find→split.
@tool
class_name UxPolishTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true

	# Picker recents: newest first, deduped, capped.
	ACEPickerDialog._recent_ace_ids = PackedStringArray()
	ACEPickerDialog.note_recent("Core", "Wait")
	ACEPickerDialog.note_recent("Core", "PlaySound")
	ACEPickerDialog.note_recent("Core", "Wait")
	all_passed = _check("recents dedupe to newest-first",
		ACEPickerDialog._recent_ace_ids[0] == "Core/Wait" and ACEPickerDialog._recent_ace_ids.size() == 2, true) and all_passed
	for index in range(12):
		ACEPickerDialog.note_recent("Core", "Filler%d" % index)
	all_passed = _check("recents cap at %d" % ACEPickerDialog.RECENT_ACES_CAP,
		ACEPickerDialog._recent_ace_ids.size(), ACEPickerDialog.RECENT_ACES_CAP) and all_passed
	ACEPickerDialog._recent_ace_ids = PackedStringArray()

	# Inline live-value chips resolve variable rows by name.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "hp"
	tree_var.type_name = "int"
	tree_var.default_value = 100
	sheet.events.append(tree_var)
	var marked: CommentRow = CommentRow.new()
	marked.text = "remember this"
	sheet.events.append(marked)
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	viewport.set_live_values({"hp": 42})
	var variable_row: EventRowData = null
	for flat_entry: Dictionary in viewport.get_flat_rows():
		if (flat_entry.get("row") as EventRowData).source_resource == tree_var:
			variable_row = flat_entry.get("row")
	all_passed = _check("live chips resolve variable rows", viewport.live_value_chip_for(variable_row), "= 42") and all_passed
	editor.update_live_values({"hp": 7})
	all_passed = _check("frames forward to panes via the dock sink",
		viewport.live_value_chip_for(variable_row), "= 7") and all_passed

	# Bookmarks panel lists marked rows (popup-free refresh).
	viewport._select_row(1, -1)
	viewport.toggle_bookmark_selected()
	editor._ensure_live_values_window()  # unrelated windows coexist
	if editor._bookmarks_window == null:
		editor._bookmarks_window = Window.new()
		editor._bookmarks_list = ItemList.new()
		editor._bookmarks_window.add_child(editor._bookmarks_list)
		editor.add_child(editor._bookmarks_window)
	editor._refresh_bookmarks_list()
	var listed: bool = false
	for index in range(editor._bookmarks_list.item_count):
		if editor._bookmarks_list.get_item_text(index).contains("remember this"):
			listed = true
	all_passed = _check("bookmarks panel lists marked rows", listed, true) and all_passed

	# Find -> split: the current match opens in the split pane.
	editor._ensure_find_bar()
	editor._find_edit.text = "remember"
	editor._find_resource_matches = editor.get_viewport_control().search_all("remember")
	editor._find_cursor = 0
	editor._open_match_in_split()
	all_passed = _check("find match opens in the split pane",
		editor._multi_view._split_viewport != null and editor._multi_view._split_viewport.get_flat_rows().size() > 0, true) and all_passed
	editor.free()

	# Single-param inline editing: value -> param resolution (incl. equal-value
	# disambiguation by occurrence) and the undoable dock apply.
	var ace: ACEAction = ACEAction.new()
	ace.provider_id = "Core"
	ace.ace_id = "X"
	ace.codegen_template = "move({x}, {y})"
	ace.params = {"x": "10", "y": "10"}
	all_passed = _check("first occurrence resolves the first equal param",
		EventSheetViewport.param_id_for_value(ace, "10", 0), "x") and all_passed
	all_passed = _check("second occurrence resolves the second equal param",
		EventSheetViewport.param_id_for_value(ace, "10", 1), "y") and all_passed
	all_passed = _check("unknown values resolve to nothing",
		EventSheetViewport.param_id_for_value(ace, "99", 0), "") and all_passed
	var param_editor: EventSheetEditor = EventSheetEditor.new()
	var param_sheet: EventSheetResource = EventSheetResource.new()
	var param_event: EventRow = EventRow.new()
	param_event.trigger_provider_id = "Core"
	param_event.trigger_id = "OnReady"
	param_event.actions.append(ace)
	param_sheet.events.append(param_event)
	param_editor.setup(param_sheet)
	param_editor.set_undo_redo_manager(NoopUndoManager.new())
	param_editor._on_param_value_edit_requested(ace, "y", "10")
	param_editor._inline_params._param_edit_field.text = "42"
	param_editor._inline_params._commit_inline_param_edit()
	all_passed = _check("inline edits land on just that param",
		str(ace.params.get("y")) == "42" and str(ace.params.get("x")) == "10", true) and all_passed
	param_editor.free()

	# Favorites: toggle pins/unpins and persists via ProjectSettings.
	if ProjectSettings.has_setting(ACEPickerDialog.FAVORITES_SETTING):
		ProjectSettings.set_setting(ACEPickerDialog.FAVORITES_SETTING, null)
	all_passed = _check("pinning a favorite reports pinned",
		ACEPickerDialog.toggle_favorite("Core", "Wait"), true) and all_passed
	all_passed = _check("favorites persist in project settings",
		ACEPickerDialog.favorite_ids().has("Core/Wait"), true) and all_passed
	all_passed = _check("toggling again unpins",
		ACEPickerDialog.toggle_favorite("Core", "Wait"), false) and all_passed
	all_passed = _check("unpinned favorites clear", ACEPickerDialog.favorite_ids().is_empty(), true) and all_passed

	# Group color tags: undoable apply + clear-to-theme.
	var color_editor: EventSheetEditor = EventSheetEditor.new()
	var color_sheet: EventSheetResource = EventSheetResource.new()
	var colored_group: EventGroup = EventGroup.new()
	colored_group.group_name = "Combat"
	color_sheet.events.append(colored_group)
	color_editor.setup(color_sheet)
	color_editor.set_undo_redo_manager(NoopUndoManager.new())
	color_editor._group_color_target = colored_group
	color_editor._apply_group_color(Color(0.9, 0.3, 0.3, 1.0))
	all_passed = _check("group color applies", colored_group.custom_color, Color(0.9, 0.3, 0.3, 1.0)) and all_passed
	color_editor._apply_group_color(Color(0.0, 0.0, 0.0, 0.0))
	all_passed = _check("clearing returns the group to theme colors",
		colored_group.custom_color.a == 0.0, true) and all_passed
	color_editor.free()

	# Project-wide find: sheet discovery + per-sheet matching share Replace All's
	# surfaces (so find and replace can never disagree).
	var project_sheets: PackedStringArray = EventSheetEditor.list_project_sheets()
	all_passed = _check("project scan finds the demo sheet",
		project_sheets.has("res://demo/sheets/player.tres"), true) and all_passed
	var probe_sheet: EventSheetResource = EventSheetResource.new()
	var probe_comment: CommentRow = CommentRow.new()
	probe_comment.text = "the hidden treasure"
	probe_sheet.events.append(probe_comment)
	var found: Array = EventSheetEditor.find_in_sheet(probe_sheet, "treasure")
	all_passed = _check("find_in_sheet matches with preview",
		found.size() == 1 and str(found[0].get("preview", "")).contains("treasure"), true) and all_passed
	all_passed = _check("find_in_sheet is case-insensitive",
		EventSheetEditor.find_in_sheet(probe_sheet, "TREASURE").size(), 1) and all_passed

	# Fuzzy picker matching: subsequence, case/space-insensitive, never empty-query.
	all_passed = _check("fuzzy matches subsequences", ACEPickerDialog.fuzzy_match("stt", "Set Time Scale"), true) and all_passed
	all_passed = _check("fuzzy respects order", ACEPickerDialog.fuzzy_match("tts", "Set Time Scale"), true) and all_passed
	all_passed = _check("fuzzy rejects missing letters", ACEPickerDialog.fuzzy_match("xyz", "Set Time Scale"), false) and all_passed
	all_passed = _check("empty queries never fuzzy-match", ACEPickerDialog.fuzzy_match("", "anything"), false) and all_passed

	# Sheet text dump (the git-textconv backbone): readable, deterministic rows.
	var dump_sheet: EventSheetResource = EventSheetResource.new()
	dump_sheet.variables = {"hp": {"type": "int", "default": 3, "exported": true}}
	var dump_group: EventGroup = EventGroup.new()
	dump_group.group_name = "Combat"
	dump_group.runtime_toggleable = true
	var dump_event: EventRow = EventRow.new()
	dump_event.trigger_provider_id = "Core"
	dump_event.trigger_id = "OnProcess"
	var dump_condition: ACECondition = ACECondition.new()
	dump_condition.ace_id = "IsOnFloor"
	dump_condition.negated = true
	dump_event.conditions.append(dump_condition)
	var dump_action: ACEAction = ACEAction.new()
	dump_action.ace_id = "SetVar"
	dump_action.params = {"var_name": "hp", "value": "3"}
	dump_event.actions.append(dump_action)
	dump_group.events.append(dump_event)
	dump_sheet.events.append(dump_group)
	var dumped: String = EventSheetTextDump.dump(dump_sheet)
	all_passed = _check("dump renders rows readably",
		dumped.contains("VAR hp: int = 3")
		and dumped.contains("GROUP Combat (runtime-toggleable)")
		and dumped.contains("EVENT Core/OnProcess")
		and dumped.contains("IF NOT IsOnFloor")
		and dumped.contains("DO SetVar {value=3, var_name=hp}"), true) and all_passed
	all_passed = _check("dump is deterministic", EventSheetTextDump.dump(dump_sheet), dumped) and all_passed

	# Compile-on-save: saving a .tres also writes the conventional generated script.
	var cos_editor: EventSheetEditor = EventSheetEditor.new()
	cos_editor.setup(dump_sheet)
	cos_editor.set_undo_redo_manager(NoopUndoManager.new())
	cos_editor._current_sheet_path = "user://eventsheets_cos.tres"
	if FileAccess.file_exists("user://eventsheets_cos_generated.gd"):
		DirAccess.remove_absolute("user://eventsheets_cos_generated.gd")
	cos_editor._on_save_requested()
	all_passed = _check("save also compiles the generated script",
		FileAccess.file_exists("user://eventsheets_cos_generated.gd"), true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/compile_on_save", false)
	DirAccess.remove_absolute("user://eventsheets_cos_generated.gd")
	cos_editor._on_save_requested()
	all_passed = _check("the setting disables compile-on-save",
		FileAccess.file_exists("user://eventsheets_cos_generated.gd"), false) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/compile_on_save", null)
	cos_editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ux_polish_test: %s" % label)
		return true
	print("[FAIL] ux_polish_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
