@tool
class_name EventSheetRenameRefactor
extends RefCounted
# Rename refactoring across the whole sheet model. Two surfaces, bundled because both are "renaming":
#  - the regex whole-word VARIABLE rename (rename_variable_references + its row / param / template
#    walkers) which rewrites every embedded GDScript surface (ACE params, code blocks, pick-filter
#    expressions) so a variable rename never silently breaks compiled code; called by the variables tree.
#  - the "Rename Everywhere" DIALOG (open / _perform_symbol_rename) which renames a symbol via the
#    EventSheetRefactor core in the open sheet AND every project sheet that includes it (rename_in_includers).
# Extracted from event_sheet_dock.gd; the sheet + path state, the mutation funnel, status, and title-strip
# refresh it needs stay on the dock, reached through _dock. The dock keeps thin _rename_variable_references /
# _open_rename_dialog / _rename_in_includers delegates for the variables-tree callers and tedium_test.

var _dock: Control = null
var _rename_window: Window = null
var _rename_edit: LineEdit = null
var _rename_old_name: String = ""


func init(dock: Control) -> void:
	_dock = dock


## Whole-word renames a variable across everything that embeds GDScript text - ACE params, GDScript
## blocks (class-level, in-flow, function bodies), and pick-filter expressions - so a rename never
## silently breaks compiled code (event-sheet-style refactor safety). Returns the number of replacements.
## Call inside the same undoable edit as the rename.
func rename_variable_references(old_name: String, new_name: String) -> int:
	if old_name.is_empty() or old_name == new_name or _dock._current_sheet == null:
		return 0
	var regex: RegEx = RegEx.new()
	if regex.compile("\\b%s\\b" % old_name) != OK:  # names are sanitized identifiers - regex-safe
		return 0
	var counter: Dictionary = {"count": 0}
	_rename_in_rows(_dock._current_sheet.events, regex, new_name, counter)
	for function_resource: Variant in _dock._current_sheet.functions:
		if function_resource is EventFunction:
			var function_rows: Array = (function_resource as EventFunction).events if not (function_resource as EventFunction).events.is_empty() else (function_resource as EventFunction).rows
			_rename_in_rows(function_rows, regex, new_name, counter)
	return int(counter.get("count", 0))


func _rename_in_rows(rows: Array, regex: RegEx, new_name: String, counter: Dictionary) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			(row as RawCodeRow).code = _regex_rename(regex, (row as RawCodeRow).code, new_name, counter)
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			_rename_in_rows(group.events if not group.events.is_empty() else group.rows, regex, new_name, counter)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			if event_row.trigger != null:
				_rename_in_params(event_row.trigger, regex, new_name, counter)
			for condition: Variant in event_row.conditions:
				if condition is ACECondition:
					_rename_in_params(condition, regex, new_name, counter)
			for action: Variant in event_row.actions:
				if action is ACEAction:
					_rename_in_params(action, regex, new_name, counter)
				elif action is RawCodeRow:
					(action as RawCodeRow).code = _regex_rename(regex, (action as RawCodeRow).code, new_name, counter)
			for pick: Variant in event_row.pick_filters:
				if pick is PickFilter:
					(pick as PickFilter).collection_value = _regex_rename(regex, (pick as PickFilter).collection_value, new_name, counter)
					(pick as PickFilter).predicate_expression = _regex_rename(regex, (pick as PickFilter).predicate_expression, new_name, counter)
			if not event_row.with_node_target.is_empty():
				event_row.with_node_target = _regex_rename(regex, event_row.with_node_target, new_name, counter)
			_rename_in_rows(event_row.sub_events, regex, new_name, counter)


## String params hold GDScript expressions / variable references - rename inside them. Baked codegen
## templates can embed the variable too, but their {placeholder} tokens must never be touched (they're
## param names, not variables).
func _rename_in_params(ace: Resource, regex: RegEx, new_name: String, counter: Dictionary) -> void:
	var params: Dictionary = ace.get("params")
	for key: Variant in params.keys():
		if params[key] is String:
			params[key] = _regex_rename(regex, params[key], new_name, counter)
	var template: String = str(ace.get("codegen_template"))
	if not template.is_empty():
		ace.set("codegen_template", _rename_in_template(template, regex, new_name, counter))


## Renames only OUTSIDE {placeholder} segments of a codegen template.
func _rename_in_template(template: String, regex: RegEx, new_name: String, counter: Dictionary) -> String:
	var output: String = ""
	var cursor: int = 0
	while cursor < template.length():
		var open_brace: int = template.find("{", cursor)
		if open_brace == -1:
			output += _regex_rename(regex, template.substr(cursor), new_name, counter)
			break
		var close: int = template.find("}", open_brace)
		if close == -1:
			output += _regex_rename(regex, template.substr(cursor), new_name, counter)
			break
		output += _regex_rename(regex, template.substr(cursor, open_brace - cursor), new_name, counter)
		output += template.substr(open_brace, close - open_brace + 1)
		cursor = close + 1
	return output


func _regex_rename(regex: RegEx, text: String, new_name: String, counter: Dictionary) -> String:
	if text.is_empty():
		return text
	var hits: int = regex.search_all(text).size()
	if hits == 0:
		return text
	counter["count"] = int(counter.get("count", 0)) + hits
	return regex.sub(text, new_name, true)


## Opens the "Rename Everywhere" dialog seeded with old_name (the variable context menu's Rename).
func open(old_name: String) -> void:
	if old_name.is_empty():
		return
	_rename_old_name = old_name
	if _rename_window == null:
		_rename_window = Window.new()
		_rename_window.title = "Rename Everywhere"
		_rename_window.size = Vector2i(380, 110)
		_rename_window.close_requested.connect(func() -> void: _rename_window.hide())
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rename_edit = LineEdit.new()
		_rename_edit.text_submitted.connect(func(_t: String) -> void: _confirm_rename())
		box.add_child(_rename_edit)
		var apply_button: Button = Button.new()
		apply_button.text = "Rename in this sheet + every sheet that includes it"
		apply_button.pressed.connect(_confirm_rename)
		box.add_child(apply_button)
		_rename_window.add_child(box)
		_dock.add_child(_rename_window)
	_rename_edit.text = old_name
	_rename_window.popup_centered()
	_rename_edit.grab_focus()
	_rename_edit.select_all()


func _confirm_rename() -> void:
	var renamed: bool = _perform_symbol_rename(_rename_old_name, _rename_edit.text.strip_edges())
	if renamed:
		_rename_window.hide()


## The full rename: validate, undoably rewrite the open sheet, then rewrite + save every project sheet
## whose `includes` lists this one (Replace-in-Project contract: closed sheets save directly, the status
## names every touched file).
func _perform_symbol_rename(old_name: String, new_name: String) -> bool:
	if _dock._current_sheet == null:
		return false
	var problem: String = EventSheetRefactor.validate_new_name(_dock._current_sheet, old_name, new_name)
	if not problem.is_empty():
		_dock._set_status(problem, true)
		return false
	var renamed: bool = _dock._perform_undoable_sheet_edit("Rename %s" % old_name, func() -> bool:
		return EventSheetRefactor.rename_symbol(_dock._current_sheet, old_name, new_name) > 0)
	if not renamed:
		_dock._set_status("\"%s\" appears nowhere in this sheet." % old_name, true)
		return false
	var touched: PackedStringArray = PackedStringArray()
	if not _dock._current_sheet_path.is_empty():
		touched = rename_in_includers(old_name, new_name, EventSheetProjectFind.list_project_sheets())
	_dock._refresh_title_strip()
	_dock._set_status("Renamed %s → %s%s." % [old_name, new_name,
		" (also in: %s)" % ", ".join(touched) if not touched.is_empty() else ""])
	return true


## Rewrites + saves every candidate sheet whose `includes` lists the open sheet (closed sheets save
## directly - the Replace-in-Project contract).
func rename_in_includers(old_name: String, new_name: String, candidate_paths: PackedStringArray) -> PackedStringArray:
	var touched: PackedStringArray = PackedStringArray()
	for sheet_path: String in candidate_paths:
		if sheet_path == _dock._current_sheet_path:
			continue
		var other: EventSheetResource = load(sheet_path) as EventSheetResource
		if other == null or not other.includes.has(_dock._current_sheet_path):
			continue
		if EventSheetRefactor.rename_symbol(other, old_name, new_name) > 0:
			# Claim the rename only when the save landed - an unchecked save reported the
			# includer as renamed while the file still used the old symbol (silent breakage
			# at the NEXT compile of that sheet). Closed sheets have no undo: ring first.
			EventSheetBackups.backup_sheet(sheet_path)
			if ResourceSaver.save(other, sheet_path) == OK:
				touched.append(sheet_path.get_file())
			else:
				push_warning("EventSheets: rename could not save %s - it still uses '%s'." % [sheet_path, old_name])
	return touched
