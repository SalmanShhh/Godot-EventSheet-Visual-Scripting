# Godot EventSheets - project-wide Find / Replace / Usages (dock subsystem)
#
# Extracted from EventSheetDock (the decomposition arc): owns the Find-in-Project
# window, the res:// sheet scan, per-sheet matching (the SAME surfaces Replace All
# covers, so find and replace can never disagree) and Replace-in-Project. The dock
# keeps thin delegates; this class holds a back-reference for dock services
# (status line, current sheet, find bar, the undoable per-sheet replace).
@tool
class_name EventSheetProjectFind
extends RefCounted

## Where the behaviour packs live - read by Find, never rewritten by a project-wide replace or rename.
const PACK_ROOT: String = "res://eventsheet_addons/"

var _dock: Control = null


func _init(dock: Control) -> void:
	_dock = dock


func open(initial_query: String = "") -> void:
	_open_project_find(initial_query)

var _project_find_window: ConfirmationDialog = null
var _project_find_edit: LineEdit = null
var _project_replace_edit: LineEdit = null
var _project_find_results: Tree = null
var _project_find_count: Label = null
var _project_find_strip: EventSheetPopupUI.HelpStrip = null
var _project_find_this_row: Label = null


func _open_project_find(initial_query: String = "") -> void:
	if _project_find_window == null:
		_build_project_find()
	if not initial_query.is_empty():
		_project_find_edit.text = initial_query
	_project_find_window.popup_centered()
	_project_find_edit.grab_focus()
	if not initial_query.is_empty():
		_run_project_find()


## Builds the window without showing it, so a test can drive it headless.
func _build_project_find() -> void:
	var parts: Dictionary = EventSheetPopupUI.action_window(
		EventSheetL10n.translate("Find and replace in every sheet"), EventSheetL10n.translate("Replace in Project"),
		EventSheetL10n.translate("Close"), Vector2i(560, 480), _dock)
	_project_find_window = parts["window"]
	_project_find_window.confirmed.connect(_run_project_replace)
	# What the main button cannot take back, said beside it.
	(parts["note"] as EventSheetPopupUI.StateNote).say(EventSheetL10n.translate(
		"Closed sheets are saved at once; only the open sheet can be undone."), EventSheetPopupUI.TONE_WARNING)
	var box: VBoxContainer = parts["box"]
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	var query_row: HBoxContainer = HBoxContainer.new()
	_project_find_edit = LineEdit.new()
	_project_find_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_project_find_edit.text_submitted.connect(func(_t: String) -> void: _run_project_find())
	query_row.add_child(_project_find_edit)
	var find_button: Button = Button.new()
	find_button.text = EventSheetL10n.translate("Find")
	find_button.pressed.connect(_run_project_find)
	query_row.add_child(find_button)
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Find"), query_row))
	_project_replace_edit = LineEdit.new()
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Replace with"), _project_replace_edit))
	box.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Find and replace"), form))
	_project_find_results = Tree.new()
	_project_find_results.hide_root = true
	_project_find_results.columns = 3
	_project_find_results.set_column_title(0, EventSheetL10n.translate("Sheet"))
	_project_find_results.set_column_title(1, EventSheetL10n.translate("Event"))
	_project_find_results.set_column_title(2, EventSheetL10n.translate("Match"))
	_project_find_results.set_column_expand(1, false)
	_project_find_results.set_column_custom_minimum_width(1, roundi(EventSheetPalette.scaled_f(64.0)))
	_project_find_results.column_titles_visible = true
	_project_find_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_project_find_results.custom_minimum_size.y = EventSheetPalette.scaled_f(170.0)
	_project_find_results.item_selected.connect(_on_project_find_selected)
	_project_find_results.item_activated.connect(_on_project_find_activated)
	var results: VBoxContainer = EventSheetPopupUI.form_box()
	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.add_child(_project_find_results)
	_project_find_count = EventSheetPopupUI.hint_label("")
	results.add_child(_project_find_count)
	var results_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Results"), results)
	results_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(results_card)
	_project_find_strip = EventSheetPopupUI.help_strip()
	_project_find_this_row = _project_find_strip.add_line(EventSheetL10n.translate("THIS ROW"), true)
	_project_find_strip.visible = false
	box.add_child(_project_find_strip)


## Every .tres EventSheetResource under res:// (skips .godot and addons internals). `.tres` ONLY: a
## walk that means every sheet wants list_all_project_sheets() below.
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
	# Path order, always - the directory walk hands files back in filesystem order (near-alphabetical
	# on NTFS, hash order on ext4), and this list is the Find window's result order and the Doctor's
	# visiting order.
	sheet_paths.sort()
	return sheet_paths


## Every sheet in the project in BOTH formats, path-sorted: the `.tres` sheets above plus every
## project `.gd`. `.gd` is the default sheet format and any script opens as a sheet - the same rule
## Open as Event Sheet follows - so a walk that means "all sheets" and stops at `.tres` skips most of
## a real project. Listing a script costs a directory walk; nothing here loads or imports one.
static func list_all_project_sheets() -> PackedStringArray:
	var sheet_paths: PackedStringArray = list_project_sheets()
	for script_path: String in EventSheetFindReferences.project_scripts():
		if not sheet_paths.has(script_path):
			sheet_paths.append(script_path)
	sheet_paths.sort()
	return sheet_paths


## Text matches in a CLOSED `.gd` sheet, read as the file it is: [{preview, uid, line}]. A `.gd`
## sheet's text IS the sheet, so a line that says the needle is a row that says it, and `line` is
## what a result lands on - the editor selects the row a line belongs to. Nothing is imported: a
## closed script is never lifted just to be searched. `uid` is "" because a file has no event ids
## until it is opened. Case-insensitive, like find_in_sheet.
static func find_in_script_text(source: String, needle: String) -> Array:
	var matches: Array = []
	if source.is_empty() or needle.is_empty():
		return matches
	var lowered: String = needle.to_lower()
	var lines: PackedStringArray = source.split("\n")
	for index: int in range(lines.size()):
		var line_text: String = lines[index]
		var at: int = line_text.to_lower().find(lowered)
		if at == -1:
			continue
		matches.append({
			"preview": line_text.substr(maxi(at - 18, 0), needle.length() + 44).strip_edges(),
			"uid": "",
			"line": index + 1,
		})
	return matches


## Every match of `needle` across `sheet_paths`, in path order: [{path, preview, uid, line, event}].
## `open_sheets` ({path: EventSheetResource}) are the live versions of their files - a word typed a
## second ago exists only in memory - so they are searched as sheets, and searched even when the walk
## did not list them. A closed `.gd` is searched as its text; a closed `.tres` loads. `uid` is the
## event a match sits in ("" outside one) and `event` its number in the sheet's margin (0 outside
## one, and for a closed `.gd`, which is never imported to be searched); `line` is the file line of
## a closed `.gd` match (0 otherwise). Together they are where a result takes the reader.
static func find_in_project(needle: String, sheet_paths: PackedStringArray,
		open_sheets: Dictionary = {}) -> Array:
	var found: Array = []
	if needle.strip_edges().is_empty():
		return found
	var paths: PackedStringArray = sheet_paths.duplicate()
	for open_path: Variant in open_sheets.keys():
		if not paths.has(str(open_path)):
			paths.append(str(open_path))
	paths.sort()
	for sheet_path: String in paths:
		var matches: Array = []
		var sheet: EventSheetResource = null
		if open_sheets.has(sheet_path):
			sheet = open_sheets[sheet_path] as EventSheetResource
		elif sheet_path.get_extension().to_lower() == "gd":
			matches = find_in_script_text(FileAccess.get_file_as_string(sheet_path), needle)
		else:
			sheet = load(sheet_path) as EventSheetResource
		if sheet != null:
			matches = find_in_sheet(sheet, needle)
		var numbers: Dictionary = _event_numbers_by_uid(sheet) if not matches.is_empty() else {}
		for match_entry: Dictionary in matches:
			found.append({
				"path": sheet_path,
				"preview": str(match_entry.get("preview", "")),
				"uid": str(match_entry.get("uid", "")),
				"line": int(match_entry.get("line", 0)),
				"event": int(numbers.get(str(match_entry.get("uid", "")), 0)),
			})
	return found


## uid -> the event's number in the sheet's margin, through the one numbering walk the margin uses.
static func _event_numbers_by_uid(sheet: EventSheetResource) -> Dictionary:
	var by_uid: Dictionary = {}
	if sheet == null:
		return by_uid
	var numbers: Dictionary = EventSheetResource.event_numbers(sheet.events, sheet.functions)
	for id: int in numbers:
		var row: Object = instance_from_id(id)
		if row is EventRow and not (row as EventRow).event_uid.is_empty():
			by_uid[(row as EventRow).event_uid] = int(numbers[id])
	return by_uid


## Replace across the CLOSED sheets among `sheet_paths` - every path in `skip` is left alone, because
## those are open and change through their own undo step: {touched: ["file (n)"], failed: ["file"]}.
## `replace_rows` is the find bar's own row walk, so a closed `.tres` changes exactly what Replace All
## changes in an open sheet. A closed `.gd` is its text, so its text is what is replaced. Each file's
## pre-save bytes go to the backup ring first - a closed file has no undo - and a file is claimed as
## replaced only when the save landed. A behaviour pack's script is never rewritten (is_pack_script).
static func replace_in_closed_sheets(needle: String, replacement: String,
		sheet_paths: PackedStringArray, skip: Dictionary, replace_rows: Callable) -> Dictionary:
	var touched: PackedStringArray = PackedStringArray()
	var failed: PackedStringArray = PackedStringArray()
	if needle.is_empty():
		return {"touched": touched, "failed": failed}
	for sheet_path: String in sheet_paths:
		if skip.has(sheet_path):
			continue
		if sheet_path.get_extension().to_lower() == "gd":
			if is_pack_script(sheet_path):
				continue
			var source: String = FileAccess.get_file_as_string(sheet_path)
			var hits: int = source.count(needle)
			if hits <= 0:
				continue
			EventSheetBackups.backup_sheet(sheet_path)
			if write_script_text(sheet_path, source.replace(needle, replacement)):
				touched.append("%s (%d)" % [sheet_path.get_file(), hits])
			else:
				failed.append(sheet_path.get_file())
			continue
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		var counter: Dictionary = {"count": 0}
		replace_rows.call(sheet.events, needle, replacement, counter)
		for function_entry: Variant in sheet.functions:
			if function_entry is EventFunction:
				var event_function: EventFunction = function_entry as EventFunction
				replace_rows.call(event_function.events if not event_function.events.is_empty()
					else event_function.rows, needle, replacement, counter)
		if int(counter.get("count", 0)) > 0:
			# An unchecked save here reported the sheet as replaced while the file kept the
			# OLD text (locked file, read-only checkout) - claim success only when it saved.
			EventSheetBackups.backup_sheet(sheet_path)
			if ResourceSaver.save(sheet, sheet_path) == OK:
				touched.append("%s (%d)" % [sheet_path.get_file(), int(counter.get("count", 0))])
			else:
				failed.append(sheet_path.get_file())
	return {"touched": touched, "failed": failed}


## True for a script the project-wide REWRITES (Replace in Project, Rename class) leave alone: the
## behaviour packs under eventsheet_addons/. Their source is what the pack builders emit, so a text
## pass over one changes a file nobody opened - string literals and comments included - and the next
## rebuild silently takes it back. Find still reads them; only the writes stay out.
static func is_pack_script(path: String) -> bool:
	return path.begins_with(PACK_ROOT)


## Writes a closed `.gd` sheet's new text over it. True only when the write landed.
static func write_script_text(script_path: String, text: String) -> bool:
	var handle: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	if handle == null:
		return false
	handle.store_string(text)
	var landed: bool = handle.get_error() == OK
	handle.close()
	return landed


## Every piece of text one sheet can be FOUND by, each with the event it lives in: [{text, uid}].
## `uid` is the enclosing event's own `event_uid`, and "" for text that is not inside an event at all
## (a loose comment, a group's own name and description, a script block between events) - which is
## what a reader can be taken to, and what they cannot.
##
## ONE collection, because two readers ask it: the Find window below, and the Quick Add field's
## answers. Two walks would be two opinions about what "this sheet says that" means, and the answer
## list would then offer rows the Find window swears are not there.
static func findable(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	_collect_findable_text(sheet.events, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			_collect_findable_text(event_function.events if not event_function.events.is_empty() else event_function.rows, found)
	return found


## Text matches in one sheet's editable surfaces: [{preview, uid}] (same surfaces Replace
## All covers, so find and replace can never disagree). `uid` names the event the match lives in,
## or "" when it lives outside one.
static func find_in_sheet(sheet: EventSheetResource, needle: String) -> Array:
	var matches: Array = []
	if sheet == null or needle.is_empty():
		return matches
	var lowered: String = needle.to_lower()
	for entry: Dictionary in findable(sheet):
		var haystack: String = str(entry.get("text", ""))
		if haystack.to_lower().contains(lowered):
			var at: int = haystack.to_lower().find(lowered)
			matches.append({
				"preview": haystack.substr(maxi(at - 18, 0), needle.length() + 44).replace("\n", " "),
				"uid": str(entry.get("uid", "")),
			})
	return matches


## One row list's findable text, appended as {text, uid}. `uid` is inherited by everything inside an
## event, so a match in a condition's parameter names the event a reader can be taken to rather than
## the parameter, which is not a place.
static func _collect_findable_text(rows: Array, into: Array, uid: String = "") -> void:
	for row: Variant in rows:
		if row is CommentRow:
			into.append({"text": (row as CommentRow).text, "uid": uid})
		elif row is RawCodeRow:
			into.append({"text": (row as RawCodeRow).code, "uid": uid})
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			into.append({"text": group.group_name + " " + group.description, "uid": uid})
			_collect_findable_text(group.events if not group.events.is_empty() else group.rows, into, uid)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			var own_uid: String = event_row.event_uid
			for ace: Variant in event_row.conditions + event_row.actions:
				if ace is RawCodeRow:
					into.append({"text": (ace as RawCodeRow).code, "uid": own_uid})
				elif ace is Resource and ace.get("params") is Dictionary:
					if ace.get("comment") is String and not str(ace.get("comment")).is_empty():
						into.append({"text": str(ace.get("comment")), "uid": own_uid})
					for value: Variant in (ace.get("params") as Dictionary).values():
						if value is String:
							into.append({"text": value, "uid": own_uid})
			for pick: Variant in event_row.pick_filters:
				if pick is PickFilter:
					into.append({"text": (pick as PickFilter).collection_value + " " \
						+ (pick as PickFilter).predicate_expression, "uid": own_uid})
			_collect_findable_text(event_row.sub_events, into, own_uid)


## Fills the results and the count under them. Returns the number of matches (testable headless).
func _run_project_find() -> int:
	var needle: String = _project_find_edit.text
	_project_find_results.clear()
	_project_find_strip.visible = false
	var root_item: TreeItem = _project_find_results.create_item()
	_project_find_count.text = ""
	if needle.strip_edges().is_empty():
		return 0
	var found: Array = find_in_project(needle, list_all_project_sheets(), EventSheetFindReferences.open_sheets_of(_dock))
	var sheets: Dictionary = {}
	for match_entry: Dictionary in found:
		var item: TreeItem = _project_find_results.create_item(root_item)
		item.set_text(0, str(match_entry["path"]).get_file())
		item.set_text(1, where_in_sheet(match_entry))
		item.set_text(2, "…%s…" % str(match_entry.get("preview", "")))
		# Where the match IS, not only which file: the event it sits in, or the line of a closed
		# script, so activating the result lands on the row rather than at the top of the sheet.
		item.set_metadata(0, match_entry)
		sheets[match_entry["path"]] = true
	_project_find_count.text = EventSheetL10n.translate("%d match(es) for \"%s\" in %d sheet(s). Searched every sheet, .tres and .gd.") % [
		found.size(), needle, sheets.size()]
	return found.size()


## The Event column of one result: the event's number, the line of a closed script, or "-" for
## text that sits outside any event (a loose comment, a group's name).
static func where_in_sheet(match_entry: Dictionary) -> String:
	if int(match_entry.get("event", 0)) > 0:
		return str(int(match_entry["event"]))
	if int(match_entry.get("line", 0)) > 0:
		return EventSheetL10n.translate("line %d") % int(match_entry["line"])
	return "-"


## The strip under the results names the selected one: which sheet, where in it, what a
## double-click does, and the matched text as it reads in the code.
func _on_project_find_selected() -> void:
	var selected: TreeItem = _project_find_results.get_selected()
	if selected == null or not (selected.get_metadata(0) is Dictionary):
		return
	var target: Dictionary = selected.get_metadata(0)
	var sheet_name: String = str(target.get("path", "")).get_file()
	var place: String = where_in_sheet(target)
	var told: String = EventSheetL10n.translate("%s, outside any event. Double-click opens the sheet and fills the Find bar.") % sheet_name
	if place != "-":
		told = EventSheetL10n.translate("%s, %s. Double-click opens the sheet, lands on the row and fills the Find bar.") % [
			sheet_name, (EventSheetL10n.translate("event %s") % place) if int(target.get("event", 0)) > 0 else place]
	_project_find_strip.set_line(_project_find_this_row, told)
	_project_find_strip.set_reading("", str(target.get("preview", "")))
	_project_find_strip.visible = true


func _on_project_find_activated() -> void:
	var selected: TreeItem = _project_find_results.get_selected()
	if selected == null or not (selected.get_metadata(0) is Dictionary):
		return
	var target: Dictionary = selected.get_metadata(0)
	var sheet_path: String = str(target.get("path", ""))
	var uid: String = str(target.get("uid", ""))
	var line: int = int(target.get("line", 0))
	if line > 0:
		# A closed script's match: the one cross-sheet landing, which waits for a `.gd` to finish
		# opening before it selects the row the line belongs to.
		_dock._find_results.jump_to_line(sheet_path, line)
	else:
		if sheet_path != _dock._current_sheet_path and (_dock._current_sheet == null
				or sheet_path != _dock._current_sheet.external_source_path):
			_dock._navigate.open_or_focus(sheet_path)
		if not uid.is_empty():
			_dock.reveal_event_row(uid)
	if _dock._find_edit != null:
		_dock._ensure_find_bar()
		_dock._find_edit.text = _project_find_edit.text
	_project_find_window.hide()


## Replace across every project sheet (undo covers only the OPEN sheet - closed sheets
## save directly; the status names every touched file so nothing changes silently).
func _run_project_replace() -> void:
	var needle: String = _project_find_edit.text
	var replacement: String = _project_replace_edit.text
	if needle.is_empty():
		_dock._set_status("Type something to find first.", true)
		return
	# The open sheet is left out of the file pass under either name it is known by - a `.gd` opened as
	# a sheet answers to the file it came from - and goes through the undoable path below.
	var skip: Dictionary = {}
	if not str(_dock._current_sheet_path).is_empty():
		skip[_dock._current_sheet_path] = true
	if _dock._current_sheet != null and not _dock._current_sheet.external_source_path.is_empty():
		skip[_dock._current_sheet.external_source_path] = true
	var outcome: Dictionary = replace_in_closed_sheets(needle, replacement,
		list_all_project_sheets(), skip, _dock._replace_in_rows)
	var touched: PackedStringArray = outcome["touched"]
	var failed: PackedStringArray = outcome["failed"]
	# The open sheet goes through the undoable path.
	if _dock._current_sheet != null:
		_dock._ensure_find_bar()
		_dock._find_edit.text = needle
		_dock._replace_edit.text = replacement
		_dock._replace_all_in_sheet()
	_run_project_find()
	if not failed.is_empty():
		_dock._set_status("Replace in Project: %s - COULD NOT SAVE: %s (files unchanged)." % [", ".join(touched) if not touched.is_empty() else "no sheets saved", ", ".join(failed)], true)
		return
	_dock._set_status("Replace in Project: %s" % (", ".join(touched) if not touched.is_empty() else "only the open sheet had matches."))

