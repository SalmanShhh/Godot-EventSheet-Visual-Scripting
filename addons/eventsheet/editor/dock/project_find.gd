# Godot EventSheets — project-wide Find / Replace / Usages (dock subsystem)
#
# Extracted from EventSheetDock (the decomposition arc): owns the Find-in-Project
# window, the res:// sheet scan, per-sheet matching (the SAME surfaces Replace All
# covers, so find and replace can never disagree) and Replace-in-Project. The dock
# keeps thin delegates; this class holds a back-reference for dock services
# (status line, current sheet, find bar, the undoable per-sheet replace).
@tool
class_name EventSheetProjectFind
extends RefCounted

var _dock: Control = null


func _init(dock: Control) -> void:
	_dock = dock


func open(initial_query: String = "") -> void:
	_open_project_find(initial_query)

var _project_find_window: Window = null
var _project_find_edit: LineEdit = null
var _project_replace_edit: LineEdit = null
var _project_find_results: Tree = null


func _open_project_find(initial_query: String = "") -> void:
	if _project_find_window == null:
		_project_find_window = Window.new()
		_project_find_window.title = "Find in Project"
		_project_find_window.size = Vector2i(560, 460)
		_project_find_window.close_requested.connect(func() -> void: _project_find_window.hide())
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
		var query_row: HBoxContainer = HBoxContainer.new()
		_project_find_edit = LineEdit.new()
		_project_find_edit.placeholder_text = "Find across every sheet in the project…"
		_project_find_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_project_find_edit.text_submitted.connect(func(_t: String) -> void: _run_project_find())
		query_row.add_child(_project_find_edit)
		var find_button: Button = Button.new()
		find_button.text = "Find"
		find_button.pressed.connect(_run_project_find)
		query_row.add_child(find_button)
		box.add_child(EventSheetPopupUI.titled_card("Find", query_row))
		var replace_row: HBoxContainer = HBoxContainer.new()
		_project_replace_edit = LineEdit.new()
		_project_replace_edit.placeholder_text = "Replace with… (applies to every match below)"
		_project_replace_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replace_row.add_child(_project_replace_edit)
		var replace_button: Button = Button.new()
		replace_button.text = "Replace in Project"
		replace_button.pressed.connect(_run_project_replace)
		replace_row.add_child(replace_button)
		box.add_child(EventSheetPopupUI.titled_card("Replace", replace_row))
		box.add_child(EventSheetPopupUI.hint_label("Replace in Project writes closed sheets to disk immediately — only the open sheet's change is undoable."))
		_project_find_results = Tree.new()
		_project_find_results.hide_root = true
		_project_find_results.columns = 2
		_project_find_results.set_column_title(0, "Sheet")
		_project_find_results.set_column_title(1, "Match")
		_project_find_results.column_titles_visible = true
		_project_find_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_project_find_results.item_activated.connect(_on_project_find_activated)
		var results_card: PanelContainer = EventSheetPopupUI.titled_card("Results", _project_find_results)
		results_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		results_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(results_card)
		_project_find_window.add_child(EventSheetPopupUI.margined(box))
		_dock.add_child(_project_find_window)
	if not initial_query.is_empty():
		_project_find_edit.text = initial_query
	_project_find_window.popup_centered()
	_project_find_edit.grab_focus()
	if not initial_query.is_empty():
		_run_project_find()


## Every .tres EventSheetResource under res:// (skips .godot and addons internals).
static func list_project_sheets() -> PackedStringArray:
	var sheet_paths: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray(["res://"])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry: String = directory.get_next()
		while not entry.is_empty():
			var full_path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				if not entry.begins_with(".") and entry != "addons":
					pending.append(full_path)
			elif entry.ends_with(".tres"):
				var resource: Resource = load(full_path)
				if resource is EventSheetResource:
					sheet_paths.append(full_path)
			entry = directory.get_next()
	return sheet_paths


## Text matches in one sheet's editable surfaces: [{preview}] (same surfaces Replace
## All covers, so find and replace can never disagree).
static func find_in_sheet(sheet: EventSheetResource, needle: String) -> Array:
	var matches: Array = []
	if sheet == null or needle.is_empty():
		return matches
	var haystacks: Array = []
	_collect_findable_text(sheet.events, haystacks)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_findable_text((function_entry as EventFunction).events if not (function_entry as EventFunction).events.is_empty() else (function_entry as EventFunction).rows, haystacks)
	var lowered: String = needle.to_lower()
	for haystack: String in haystacks:
		if haystack.to_lower().contains(lowered):
			var at: int = haystack.to_lower().find(lowered)
			matches.append({"preview": haystack.substr(maxi(at - 18, 0), needle.length() + 44).replace("\n", " ")})
	return matches


static func _collect_findable_text(rows: Array, into: Array) -> void:
	for row: Variant in rows:
		if row is CommentRow:
			into.append((row as CommentRow).text)
		elif row is RawCodeRow:
			into.append((row as RawCodeRow).code)
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			into.append(group.group_name + " " + group.description)
			_collect_findable_text(group.events if not group.events.is_empty() else group.rows, into)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			for ace: Variant in event_row.conditions + event_row.actions:
				if ace is RawCodeRow:
					into.append((ace as RawCodeRow).code)
				elif ace is Resource and ace.get("params") is Dictionary:
					if ace.get("comment") is String and not str(ace.get("comment")).is_empty():
						into.append(str(ace.get("comment")))
					for value: Variant in (ace.get("params") as Dictionary).values():
						if value is String:
							into.append(value)
			for pick: Variant in event_row.pick_filters:
				if pick is PickFilter:
					into.append((pick as PickFilter).collection_value + " " + (pick as PickFilter).predicate_expression)
			_collect_findable_text(event_row.sub_events, into)


func _run_project_find() -> void:
	var needle: String = _project_find_edit.text
	_project_find_results.clear()
	var root_item: TreeItem = _project_find_results.create_item()
	if needle.strip_edges().is_empty():
		return
	var total: int = 0
	var sheet_paths: PackedStringArray = list_project_sheets()
	if _dock._current_sheet != null and not _dock._current_sheet_path.is_empty() and not sheet_paths.has(_dock._current_sheet_path):
		sheet_paths.append(_dock._current_sheet_path)
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = _dock._current_sheet if sheet_path == _dock._current_sheet_path else load(sheet_path) as EventSheetResource
		for match_entry: Dictionary in find_in_sheet(sheet, needle):
			var item: TreeItem = _project_find_results.create_item(root_item)
			item.set_text(0, sheet_path.get_file())
			item.set_text(1, "…%s…" % str(match_entry.get("preview", "")))
			item.set_metadata(0, sheet_path)
			total += 1
	_dock._set_status("Find in Project: %d match(es) for \"%s\"." % [total, needle])


func _on_project_find_activated() -> void:
	var selected: TreeItem = _project_find_results.get_selected()
	if selected == null:
		return
	var sheet_path: String = str(selected.get_metadata(0))
	if sheet_path != _dock._current_sheet_path:
		_dock._load_sheet_from_path(sheet_path)
	if _dock._find_edit != null:
		_dock._ensure_find_bar()
		_dock._find_edit.text = _project_find_edit.text
	_project_find_window.hide()


## Replace across every project sheet (undo covers only the OPEN sheet — closed sheets
## save directly; the status names every touched file so nothing changes silently).
func _run_project_replace() -> void:
	var needle: String = _project_find_edit.text
	var replacement: String = _project_replace_edit.text
	if needle.is_empty():
		_dock._set_status("Type something to find first.", true)
		return
	var touched: PackedStringArray = PackedStringArray()
	for sheet_path: String in list_project_sheets():
		if sheet_path == _dock._current_sheet_path:
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		var counter: Dictionary = {"count": 0}
		_dock._replace_in_rows(sheet.events, needle, replacement, counter)
		for function_entry: Variant in sheet.functions:
			if function_entry is EventFunction:
				_dock._replace_in_rows((function_entry as EventFunction).events if not (function_entry as EventFunction).events.is_empty() else (function_entry as EventFunction).rows, needle, replacement, counter)
		if int(counter.get("count", 0)) > 0:
			ResourceSaver.save(sheet, sheet_path)
			touched.append("%s (%d)" % [sheet_path.get_file(), int(counter.get("count", 0))])
	# The open sheet goes through the undoable path.
	if _dock._current_sheet != null:
		_dock._ensure_find_bar()
		_dock._find_edit.text = needle
		_dock._replace_edit.text = replacement
		_dock._replace_all_in_sheet()
	_run_project_find()
	_dock._set_status("Replace in Project: %s" % (", ".join(touched) if not touched.is_empty() else "only the open sheet had matches."))

