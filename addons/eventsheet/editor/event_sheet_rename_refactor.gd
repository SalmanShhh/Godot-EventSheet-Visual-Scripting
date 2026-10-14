@tool
class_name EventSheetRenameRefactor
extends RefCounted
# Rename refactoring across the whole sheet model. Two surfaces, bundled because both are "renaming":
#  - the regex whole-word VARIABLE rename (rename_variable_references + its row / param / template
#    walkers) which rewrites every embedded GDScript surface (ACE params, code blocks, pick-filter
#    expressions) so a variable rename never silently breaks compiled code; called by the variables tree.
#  - the "Rename Everywhere" writer (rename_everywhere) which renames a symbol via the EventSheetRefactor
#    core in the open sheet AND every project sheet that includes it (rename_in_includers). The window
#    in front of it is the rename receipt (dock/rename_receipt.gd), for a variable and a function alike;
#    the inline name fields call the writer directly.
# Extracted from event_sheet_dock.gd; the sheet + path state, the mutation funnel, status, and title-strip
# refresh it needs stay on the dock, reached through _dock.

var _dock: Control = null
## The last rename's places - {moved, touched, callers} - which the receipt after it lists.
var _last_done: Dictionary = {}


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


## The full rename: validate, undoably rewrite the open sheet, then rewrite + save every project sheet
## whose `includes` lists this one (Replace-in-Project contract: closed sheets save directly, the status
## names every touched file). Public because the receipt's button and the inline name fields are the
## same gesture, and two writers for one promise is how they come to disagree.
func rename_everywhere(old_name: String, new_name: String) -> bool:
	if _dock._current_sheet == null:
		return false
	var problem: String = EventSheetRefactor.validate_new_name(_dock._current_sheet, old_name, new_name)
	if not problem.is_empty():
		_dock._set_status(problem, true)
		return false
	var moved: Array[int] = [0]
	var renamed: bool = _dock._perform_undoable_sheet_edit(
		EventSheetL10n.translate("Rename %s") % old_name, func() -> bool:
			moved[0] = EventSheetRefactor.rename_symbol(_dock._current_sheet, old_name, new_name)
			return moved[0] > 0)
	if not renamed:
		_dock._set_status(EventSheetL10n.translate("\"%s\" appears nowhere in this sheet.") % old_name, true)
		return false
	var touched: PackedStringArray = PackedStringArray()
	if not _dock._current_sheet_path.is_empty():
		touched = rename_in_includers(old_name, new_name, EventSheetProjectFind.list_project_sheets())
	var callers: PackedStringArray = hand_written_callers(old_name,
		str(_dock._current_sheet.external_source_path))
	_last_done = {"moved": moved[0], "touched": touched, "callers": callers}
	_dock._refresh_title_strip()
	_dock._set_status(done_text(moved[0], touched) + ("" if callers.is_empty() else " " + EventSheetL10n.translate(
		"Hand-written code was not changed - check these, which call %s by that name: %s") % [
			old_name, ", ".join(callers)]))
	return true


## The status line after a rename. "One Ctrl+Z takes all of it back" is only true while nothing
## outside this sheet was written: an includer the rename saved to disk is outside this sheet's undo
## step, so the sentence then says what Ctrl+Z reaches and names what it does not.
static func done_text(moved: int, touched: PackedStringArray) -> String:
	if touched.is_empty():
		return EventSheetL10n.translate("%d row(s) renamed - one Ctrl+Z takes all of it back.") % moved
	return EventSheetL10n.translate("%d row(s) renamed - one Ctrl+Z takes back this sheet's rows. Also written and saved, which Ctrl+Z does not undo: %s.") % [
		moved, ", ".join(touched)]


## The receipt after the rename: what happened, and the places it happened in. The last rename's
## places are kept by rename_everywhere, so what is listed is what was written.
func show_done(old_name: String, new_name: String) -> ConfirmationDialog:
	var moved: int = int(_last_done.get("moved", 0))
	var touched: PackedStringArray = _last_done.get("touched", PackedStringArray())
	var places: Array = [[EventSheetL10n.translate("this sheet"),
		EventSheetL10n.translate("1 place") if moved == 1 else EventSheetL10n.translate("%d places") % moved]]
	for file: String in touched:
		places.append([file, EventSheetL10n.translate("saved")])
	for file: String in _last_done.get("callers", PackedStringArray()):
		places.append([EventSheetL10n.translate("%s - not changed") % file, EventSheetL10n.translate("check it")])
	return load(_dock.SMALL_PROMPT_PATH).open(_dock, {
		"title": EventSheetL10n.translate("Renamed %s to %s") % [old_name, new_name],
		"say": EventSheetL10n.translate("Changed %d place(s) in %d sheet(s).") % [moved, 1 + touched.size()],
		"list": places,
		"note": EventSheetL10n.translate("Ctrl+Z undoes all of it in this sheet.") if touched.is_empty()
			else EventSheetL10n.translate("Ctrl+Z undoes all of it in this sheet. Other files were saved; your version control can undo those."),
		"glyph": "✓",
		"main": EventSheetL10n.translate("OK"),
		"cancel": "",
	})


## The code a rename did NOT touch: the project's own scripts that call the old name, by file name,
## listed so the one decision the plugin must not make alone is made by somebody who can.
##
## It renames nothing outside a sheet, on purpose. Hand-written code is not the plugin's to rewrite,
## and the index answers BY NAME - the words say "check", because a file listed here may be calling a
## different function that happens to share the name. Empty when nothing calls it, and empty while
## the project index is still counting: a silent answer beats a wrong one.
static func hand_written_callers(old_name: String, own_script: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if not EventSheetProjectShareIndex.request():
		return names
	for path: String in EventSheetProjectShareIndex.callers_of(old_name, own_script):
		names.append(path.get_file())
	return names


## Every candidate sheet a rename WOULD rewrite and save: the ones whose `includes` lists the open
## sheet and that say the name. Sorted, and the answer is worked out BY DOING IT on a throwaway copy
## through the very function the button runs, so a receipt promising three files and a button writing
## four cannot happen.
##
## It is the third thing the receipt has to list. The two cards say what moves in this sheet and what
## is named and left alone; these are files that are neither - they are written, they are saved, and
## they are outside the one Ctrl+Z the status line promises.
func includers_of(old_name: String, new_name: String,
		candidate_paths: PackedStringArray) -> PackedStringArray:
	var listed: PackedStringArray = PackedStringArray()
	if old_name.strip_edges().is_empty() or new_name.strip_edges().is_empty():
		return listed
	for sheet_path: String in candidate_paths:
		if sheet_path == _dock._current_sheet_path or listed.has(sheet_path):
			continue
		var other: EventSheetResource = load(sheet_path) as EventSheetResource
		if other == null or not other.includes.has(_dock._current_sheet_path):
			continue
		var trial: EventSheetResource = other.duplicate(true)
		if trial != null and EventSheetRefactor.rename_symbol(trial, old_name, new_name) > 0:
			listed.append(sheet_path)
	listed.sort()
	return listed


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
