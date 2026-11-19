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

## The least the window can be made, and the size it first opens at: wide enough for a real project line
## and the line column. The reader's own size, once changed, is kept and used from then on.
const MIN_WIDTH: int = 760
const MIN_HEIGHT: int = 520
const DEFAULT_WIDTH: int = 1120
const DEFAULT_HEIGHT: int = 720
const SIZE_SECTION: String = "eventsheets"
const SIZE_KEY: String = "replace_window_size"
## Headless twin of the editor's metadata store, so the remembered size is testable without an editor.
static var _size_memory: Array = []

var _dock: Control = null


func _init(dock: Control) -> void:
	_dock = dock


var _project_find_window: ConfirmationDialog = null
var _project_find_edit: LineEdit = null
var _project_replace_edit: LineEdit = null
var _project_find_results: Tree = null
var _project_find_count: Label = null
var _project_find_strip: EventSheetPopupUI.HelpStrip = null
var _project_find_this_row: Label = null
var _project_put_back: Button = null
var _project_put_back_row: HBoxContainer = null
var _project_put_back_line: Label = null
## What the last Find would replace: one entry per file (the plan in project_replace.gd), and the
## ticks the reader changed since. A file not in `_ticks` follows its kind's default.
var _plan: Array[Dictionary] = []
var _ticks: Dictionary = {}
var _needle: String = ""


func open(initial_query: String = "") -> void:
	if _project_find_window == null:
		_build_project_find()
	if not initial_query.is_empty():
		_project_find_edit.text = initial_query
	EventSheetPopupUI.popup_fitted(_project_find_window, _wanted_size())
	_refresh_put_back()
	_project_find_edit.grab_focus()
	if not initial_query.is_empty():
		_run_project_find()


## The size the window opens at: what the reader last left it at, else the default, never under the least.
func _wanted_size() -> Vector2i:
	var stored: Variant = _size_memory
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		stored = EditorInterface.get_editor_settings().get_project_metadata(SIZE_SECTION, SIZE_KEY, [])
	var wanted: Vector2i = Vector2i(EventSheetPalette.scaled(DEFAULT_WIDTH), EventSheetPalette.scaled(DEFAULT_HEIGHT))
	if stored is Array and (stored as Array).size() == 2:
		wanted = Vector2i(int((stored as Array)[0]), int((stored as Array)[1]))
	return wanted.max(Vector2i(EventSheetPalette.scaled(MIN_WIDTH), EventSheetPalette.scaled(MIN_HEIGHT)))


## Keeps the size the reader left the window at, for the next time it opens.
func _remember_size() -> void:
	if _project_find_window == null or _project_find_window.visible:
		return
	var kept: Array = [_project_find_window.size.x, _project_find_window.size.y]
	_size_memory = kept
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata(SIZE_SECTION, SIZE_KEY, kept)


## Builds the window without showing it, so a test can drive it headless.
func _build_project_find() -> void:
	var parts: Dictionary = EventSheetPopupUI.action_window(
		EventSheetL10n.translate("Find and replace in the project"), EventSheetL10n.translate("Replace in Project"),
		EventSheetL10n.translate("Close"), Vector2i(MIN_WIDTH, MIN_HEIGHT), _dock)
	_project_find_window = parts["window"]
	_project_find_window.confirmed.connect(_run_project_replace)
	# What the main button cannot take back, said beside it.
	_project_find_window.dialog_hide_on_ok = false
	(parts["note"] as EventSheetPopupUI.StateNote).say(EventSheetL10n.translate(
		"Closed files are saved at once, each with a backup in Sheet Backups. Ctrl+Z takes back an open tab, and Put them all back takes back the rest."),
		EventSheetPopupUI.TONE_WARNING)
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
	_project_find_results = EventSheetPopupUI.table(PackedStringArray([EventSheetL10n.translate("File"),
		EventSheetL10n.translate("Where"), EventSheetL10n.translate("Match")]), 300.0, {1: 96.0})
	# The file column and the match column share what the fixed one leaves, the match the larger part.
	_project_find_results.set_column_expand_ratio(0, 2)
	_project_find_results.set_column_expand_ratio(2, 5)
	# After a replace the way back sits right under the form: what it restores, and the button.
	_project_put_back_row = HBoxContainer.new()
	_project_put_back_row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(10.0)))
	_project_put_back_line = EventSheetPopupUI.hint_label("")
	_project_put_back_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_project_put_back_row.add_child(_project_put_back_line)
	_project_put_back = Button.new()
	_project_put_back.text = EventSheetL10n.translate("Put them all back")
	_project_put_back.tooltip_text = EventSheetL10n.translate("Puts every file the last Replace in Project wrote back as it was.")
	_project_put_back.pressed.connect(put_back_last)
	_project_put_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_project_put_back_row.add_child(_project_put_back)
	box.add_child(_project_put_back_row)
	_refresh_put_back()
	_project_find_window.visibility_changed.connect(_remember_size)
	_project_find_results.item_edited.connect(_on_tick_edited)
	_project_find_results.item_selected.connect(_on_project_find_selected)
	_project_find_results.item_activated.connect(_on_project_find_activated)
	var results: Dictionary = EventSheetPopupUI.add_results(box, EventSheetL10n.translate("Results"), _project_find_results, true)
	_project_find_count = results["count"]
	_project_find_strip = results["strip"]
	_project_find_this_row = results["this_row"]


## Shows the way back with what it restores (how many files, and when), or hides it when there is none.
func _refresh_put_back() -> void:
	if _project_put_back_row == null:
		return
	var line: String = _replace_module().newest_set_line()
	_project_put_back_row.visible = not line.is_empty()
	_project_put_back_line.text = line


## The `.tres` sheets a Project Doctor audit already found for itself, on a worker, for the length of that
## audit - see `hold_sheets`. Empty and unused otherwise, so every other asker sees the folder as it is.
static var _held_sheets: PackedStringArray = PackedStringArray()
static var _holds_sheets: bool = false


## Hands `list_project_sheets` its answer for one audit, so the audit does not load every `.tres` of the
## project on the main thread to ask each what it is.
static func hold_sheets(sheet_paths: PackedStringArray) -> void:
	_held_sheets = sheet_paths
	_holds_sheets = true


static func release_held_sheets() -> void:
	_held_sheets = PackedStringArray()
	_holds_sheets = false


## Every .tres EventSheetResource under res:// (skips .godot and addons internals). `.tres` ONLY: a
## walk that means every sheet wants list_all_project_sheets() below.
static func list_project_sheets() -> PackedStringArray:
	if _holds_sheets:
		return _held_sheets.duplicate()
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
	# A set, not a search of the list for each script: ten thousand scripts against a thousand sheets was thirteen
	# million comparisons, a stretch of the main thread of its own.
	var seen: Dictionary = {}
	for sheet_path: String in sheet_paths:
		seen[sheet_path] = true
	for script_path: String in EventSheetFindReferences.project_scripts():
		if not seen.has(script_path):
			seen[script_path] = true
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
		open_sheets: Dictionary = {}, markers: Dictionary = {}) -> Array:
	var found: Array = []
	if needle.strip_edges().is_empty():
		return found
	var paths: PackedStringArray = sheet_paths.duplicate()
	for open_path: Variant in open_sheets.keys():
		if not paths.has(str(open_path)):
			paths.append(str(open_path))
	paths.sort()
	# The game's own sheets first, then the behaviour packs: a pack is searched (its words are worth
	# finding) but it is the plugin's code, and in a project that installed the packs their hundreds of
	# matches came before the first line of the reader's own player.gd.
	var own: PackedStringArray = PackedStringArray()
	var packs: PackedStringArray = PackedStringArray()
	for sheet_path: String in paths:
		if is_pack_script(sheet_path):
			packs.append(sheet_path)
		else:
			own.append(sheet_path)
	own.append_array(packs)
	paths = own
	for sheet_path: String in paths:
		var matches: Array = []
		var sheet: EventSheetResource = null
		if open_sheets.has(sheet_path):
			sheet = open_sheets[sheet_path] as EventSheetResource
		elif sheet_path.get_extension().to_lower() == "gd":
			var script_text: String = FileAccess.get_file_as_string(sheet_path)
			matches = find_in_script_text(script_text, needle)
			if not matches.is_empty():
				# What the replace plan needs to tell a sheet from a script, so it never reads the file again.
				markers[sheet_path] = load("res://addons/eventsheet/editor/dock/project_replace.gd").has_sheet_marker(script_text)
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
	var numbers: Dictionary = EventSheetResource.margin_numbers(sheet)
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
				elif ace is CollectionDeclRow:
					into.append({"text": "
".join((ace as CollectionDeclRow).emit_lines()), "uid": own_uid})
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
	_needle = _project_find_edit.text
	_project_find_results.clear()
	_project_find_strip.visible = false
	_project_find_results.create_item()
	_project_find_count.text = ""
	_plan = []
	if _needle.strip_edges().is_empty():
		return 0
	var open_sheets: Dictionary = EventSheetFindReferences.open_sheets_of(_dock)
	var markers: Dictionary = {}
	var found: Array = find_in_project(_needle, list_all_project_sheets(), open_sheets, markers)
	var open_paths: Dictionary = {}
	for open_path: Variant in open_sheets.keys():
		open_paths[str(open_path)] = true
	_plan = _replace_module().plan(found, _needle, _project_replace_edit.text, open_paths, markers)
	for entry: Dictionary in _plan:
		for line: Dictionary in entry["lines"]:
			line["match"] = _match_of(found, str(entry["path"]), line)
	_fill_results()
	return found.size()


## The Find match a shown line was made from, so a double-click can land on it.
func _match_of(found: Array, path: String, line: Dictionary) -> Dictionary:
	for match_entry: Dictionary in found:
		if str(match_entry["path"]) == path and where_in_sheet(match_entry) == str(line["where"]) \
				and str(match_entry.get("preview", "")) == str(line["before"]):
			return match_entry
	return {}


## Draws the plan as three groups - sheets, scripts you wrote, behaviour packs - each showing at most
## MAX_FILES_SHOWN files and MAX_LINES_SHOWN lines a file, so a project of thousands of scripts is a
## list a window can hold. A group's tick covers every file in it, shown or not.
func _fill_results() -> void:
	_project_find_results.clear()
	var root_item: TreeItem = _project_find_results.create_item()
	var module: GDScript = _replace_module()
	var titles: Dictionary = {
		module.KIND_SHEET: EventSheetL10n.translate("Event sheets - %d file(s)"),
		module.KIND_SCRIPT: EventSheetL10n.translate("Scripts you wrote - %d file(s), not ticked until you tick them"),
		module.KIND_PACK: EventSheetL10n.translate("Behaviour packs - %d file(s), never changed"),
	}
	var sheets: int = 0
	var scripts: int = 0
	for kind: String in [module.KIND_SHEET, module.KIND_SCRIPT, module.KIND_PACK]:
		var files: Array[Dictionary] = []
		for entry: Dictionary in _plan:
			if str(entry["kind"]) == kind:
				files.append(entry)
		if files.is_empty():
			continue
		if kind == module.KIND_SHEET:
			sheets = files.size()
		elif kind == module.KIND_SCRIPT:
			scripts = files.size()
		var group_item: TreeItem = _project_find_results.create_item(root_item)
		if kind != module.KIND_PACK:
			# The mode first: changing a cell's mode clears its text.
			group_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			group_item.set_editable(0, true)
			group_item.set_checked(0, _group_ticked(kind))
		group_item.set_text(0, str(titles[kind]) % files.size())
		group_item.set_metadata(0, {"group": kind})
		# The group names its own count in full: the rest of the row is empty, so the words run on into it.
		group_item.set_expand_right(0, true)
		group_item.set_tooltip_text(0, group_item.get_text(0))
		if kind == module.KIND_SCRIPT:
			var hint_item: TreeItem = _project_find_results.create_item(group_item)
			hint_item.set_text(0, EventSheetL10n.translate("A .gd file with none of the plugin's markers is listed here even if it is a sheet. Tick a file to change it."))
			hint_item.set_expand_right(0, true)
			hint_item.set_selectable(0, false)
			hint_item.set_custom_color(0, EventSheetPopupUI.text_color() * Color(1.0, 1.0, 1.0, 0.74))
			hint_item.set_metadata(0, {})
		for index: int in range(mini(files.size(), module.MAX_FILES_SHOWN)):
			_add_file_item(group_item, files[index])
		if files.size() > module.MAX_FILES_SHOWN:
			var more_item: TreeItem = _project_find_results.create_item(group_item)
			more_item.set_text(0, EventSheetL10n.translate("...and %d more file(s)") % (files.size() - module.MAX_FILES_SHOWN))
			more_item.set_metadata(0, {})
	_project_find_count.text = EventSheetL10n.translate("%d file(s) have \"%s\": %d sheet(s) and %d script(s). Searched every sheet, .tres and .gd.") % [
		_plan.size(), _needle, sheets, scripts] + "\n" + module.summary(_plan, _ticks)


func _add_file_item(group_item: TreeItem, entry: Dictionary) -> void:
	var module: GDScript = _replace_module()
	var kind: String = str(entry["kind"])
	var item: TreeItem = _project_find_results.create_item(group_item)
	if kind != module.KIND_PACK:
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, int(entry["hits"]) > 0)
		item.set_checked(0, int(entry["hits"]) > 0 and bool(_ticks.get(str(entry["path"]), module.default_ticked(kind))))
	item.set_text(0, str(entry["path"]).get_file())
	item.set_tooltip_text(0, str(entry["path"]))
	var places: String = EventSheetL10n.translate("%d place(s)") % int(entry["hits"])
	if bool(entry["open"]):
		places += " - " + EventSheetL10n.translate("open in a tab")
	item.set_text(2, places)
	item.set_tooltip_text(2, places)
	item.set_metadata(0, {"file": str(entry["path"]), "kind": kind})
	var replaced: bool = not _project_replace_edit.text.is_empty()
	for line: Dictionary in entry["lines"]:
		var line_item: TreeItem = _project_find_results.create_item(item)
		line_item.set_text(1, str(line["where"]))
		var shown: String = ("%s => %s" % [line["before"], line["after"]]) if replaced else str(line["before"])
		line_item.set_text(2, shown)
		line_item.set_tooltip_text(2, shown)
		line_item.set_tooltip_text(1, str(line["where"]))
		line_item.set_metadata(0, line["match"])
	if int(entry["more"]) > 0:
		var more_item: TreeItem = _project_find_results.create_item(item)
		more_item.set_text(2, EventSheetL10n.translate("...and %d more place(s) in this file") % int(entry["more"]))
		more_item.set_metadata(0, {})


func _group_ticked(kind: String) -> bool:
	var any: bool = false
	for entry: Dictionary in _plan:
		if str(entry["kind"]) == kind and int(entry["hits"]) > 0:
			any = true
			if not bool(_ticks.get(str(entry["path"]), _replace_module().default_ticked(kind))):
				return false
	return any


## A tick changed: a file's own, or a group's, which sets every file of its kind - the ones the list
## does not show as well. The count line follows.
func _on_tick_edited() -> void:
	var item: TreeItem = _project_find_results.get_edited()
	if item == null or not (item.get_metadata(0) is Dictionary):
		return
	var meta: Dictionary = item.get_metadata(0)
	if meta.has("file"):
		_ticks[str(meta["file"])] = item.is_checked(0)
	elif meta.has("group"):
		for entry: Dictionary in _plan:
			if str(entry["kind"]) == str(meta["group"]) and int(entry["hits"]) > 0:
				_ticks[str(entry["path"])] = item.is_checked(0)
		_fill_results.call_deferred()
		return
	_project_find_count.text = _project_find_count.text.get_slice("\n", 0) + "\n" + _replace_module().summary(_plan, _ticks)


func _replace_module() -> GDScript:
	return load("res://addons/eventsheet/editor/dock/project_replace.gd")


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
	var target: Dictionary = _selected_target()
	if target.is_empty():
		return
	var sheet_name: String =str(target.get("path", "")).get_file()
	var place: String = where_in_sheet(target)
	var told: String = EventSheetL10n.translate("%s, outside any event. Double-click opens the sheet and fills the Find bar.") % sheet_name
	if place != "-":
		told = EventSheetL10n.translate("%s, %s. Double-click opens the sheet, lands on the row and fills the Find bar.") % [
			sheet_name, (EventSheetL10n.translate("event %s") % place) if int(target.get("event", 0)) > 0 else place]
	_project_find_strip.set_line(_project_find_this_row, told)
	_project_find_strip.set_reading("", str(target.get("preview", "")))
	_project_find_strip.visible = true


## Where the selected row takes the reader: a match is itself, a file is its path, a group or a
## "more" line is nowhere.
func _selected_target() -> Dictionary:
	var selected: TreeItem = _project_find_results.get_selected()
	if selected == null or not (selected.get_metadata(0) is Dictionary):
		return {}
	var meta: Dictionary = selected.get_metadata(0)
	if meta.has("file"):
		return {"path": str(meta["file"])}
	return meta if meta.has("path") else {}


func _on_project_find_activated() -> void:
	var target: Dictionary = _selected_target()
	if target.is_empty():
		return
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


## Replace what is ticked. An open tab changes through its own undo step (one in each tab); a closed
## file is written only if the result is known to be good, and each one written is kept in a set that
## Put them all back takes back whole.
func _run_project_replace() -> void:
	var needle: String = _project_find_edit.text
	var replacement: String = _project_replace_edit.text
	if needle.is_empty():
		_dock._set_status("Type something to find first.", true)
		return
	if _plan.is_empty() or _needle != needle:
		_run_project_find()
	var module: GDScript = _replace_module()
	var chosen: Array[Dictionary] = module.selected(_plan, _ticks)
	var outcome: Dictionary = module.apply_closed(chosen, needle, replacement, _dock._replace_in_rows)
	var tabs: int = 0
	for entry: Dictionary in chosen:
		if bool(entry["open"]) and _replace_in_open_tab(str(entry["path"]), needle, replacement):
			tabs += 1
	_ticks = {}
	_run_project_find()
	_refresh_put_back()
	var failed: PackedStringArray = outcome["failed"]
	var skipped: PackedStringArray = outcome["skipped"]
	var written: Array = outcome["written"]
	var told: String = EventSheetL10n.translate("Replace in Project: %d file(s) written, %d open tab(s) changed (Ctrl+Z in each takes it back).") % [written.size(), tabs]
	if not skipped.is_empty():
		told += " " + EventSheetL10n.translate("%d file(s) were left as they were because the result would not have opened or parsed.") % skipped.size()
	if not written.is_empty():
		told += " " + EventSheetL10n.translate("Put them all back is in Find in Project and in Sheet Backups.")
	if not failed.is_empty():
		told += " " + EventSheetL10n.translate("COULD NOT SAVE: %s (files unchanged).") % ", ".join(failed)
	_dock._set_status(told, not failed.is_empty())


## Puts the file's tab through Replace All, and the reader's own tab back in front. True when the tab
## existed. The step lands on that tab's own undo, not on the one in front.
func _replace_in_open_tab(path: String, needle: String, replacement: String) -> bool:
	var original: int = _dock._active_tab_index
	for index: int in range(_dock._open_tabs.size()):
		var tab: Dictionary = _dock._open_tabs[index]
		var sheet: EventSheetResource = tab.get("sheet") as EventSheetResource
		if sheet == null:
			continue
		var tab_path: String = str(tab.get("path", ""))
		if tab_path.is_empty():
			tab_path = sheet.external_source_path
		if tab_path != path:
			continue
		if index != original:
			_dock._activate_tab(index)
		_dock._ensure_find_bar()
		_dock._find_edit.text = needle
		_dock._replace_edit.text = replacement
		_dock._replace_all_in_sheet()
		if index != original:
			_dock._activate_tab(original)
		return true
	return false


## Puts back every file the newest replace wrote, each only if it is still as that replace left it.
func put_back_last() -> void:
	var module: GDScript = _replace_module()
	_dock._set_status(module.put_back_newest())
	_refresh_put_back()
	if _project_find_edit != null and not _project_find_edit.text.is_empty():
		_run_project_find()
