@tool
class_name EventSheetSheetDiff
extends RefCounted
# "What changed since the last save?" - in EVENT language, not text lines.
#
# Compiles the CURRENT sheet to a scratch path (never the real file - compile writes its output, and
# a diff must not save behind the user's back), diffs that against the SAVED .gd on disk, and maps
# the changed lines back to sheet rows through the line↔row mapper - so the answer is "these events
# change when you save", each clickable to jump to its row, with any disk-only lines listed as what
# a save would remove. The diff core is static + pure (testable headless); the dialog is the shell.
#
# The line diff itself is deliberately simple: trim the common prefix and suffix, and everything
# between is THE changed region. Sheets are edited a few rows at a time, so one honest region that
# names every touched row beats a clever hunk algorithm that costs O(n·m) on every open.

var _dock: Control = null
var _dialog: Window = null
var _list: ItemList = null
var _summary_label: Label = null
var _entries: Array = []


func init(dock: Control) -> void:
	_dock = dock


## The changed region between two line arrays after common prefix/suffix trimming:
## {old_start, old_end, new_start, new_end} - 1-based inclusive; {} when identical.
## A pure insertion/removal yields an empty side (end < start).
static func changed_region(old_lines: PackedStringArray, new_lines: PackedStringArray) -> Dictionary:
	var prefix: int = 0
	var max_prefix: int = mini(old_lines.size(), new_lines.size())
	while prefix < max_prefix and old_lines[prefix] == new_lines[prefix]:
		prefix += 1
	if prefix == old_lines.size() and prefix == new_lines.size():
		return {}
	var suffix: int = 0
	while suffix < mini(old_lines.size(), new_lines.size()) - prefix \
			and old_lines[old_lines.size() - 1 - suffix] == new_lines[new_lines.size() - 1 - suffix]:
		suffix += 1
	return {
		"old_start": prefix + 1,
		"old_end": old_lines.size() - suffix,
		"new_start": prefix + 1,
		"new_end": new_lines.size() - suffix,
	}


## The event-language summary: which rows the changed region touches (deduped, in order, each with a
## label from its first emitted line) plus the disk-only lines a save would remove. Static + pure over
## the compile artifacts. {identical: true} when a save would be byte-identical.
static func summarize(output: String, source_map: Array, disk_text: String) -> Dictionary:
	var new_lines: PackedStringArray = output.split("\n")
	var old_lines: PackedStringArray = disk_text.split("\n")
	var region: Dictionary = changed_region(old_lines, new_lines)
	if region.is_empty():
		return {"identical": true, "rows": [], "removed_lines": PackedStringArray()}
	var rows: Array = []
	var seen_uids: Dictionary = {}
	for line: int in range(int(region.get("new_start")), int(region.get("new_end")) + 1):
		var entries: Array = EventSheetLineRowMapper.entries_for_line(source_map, line)
		if entries.is_empty():
			continue
		var entry: Dictionary = entries[0]
		var uid: String = str(entry.get("uid", ""))
		if seen_uids.has(uid):
			continue
		seen_uids[uid] = true
		var start_line: int = int(entry.get("start", line))
		var label: String = new_lines[start_line - 1].strip_edges() if start_line - 1 < new_lines.size() else ""
		rows.append({
			"uid": uid,
			"kind": str(entry.get("kind", "")),
			"label": label,
			"resource": instance_from_id(int(uid)) as Resource,
		})
	var removed: PackedStringArray = PackedStringArray()
	for line: int in range(int(region.get("old_start")), int(region.get("old_end")) + 1):
		var text: String = old_lines[line - 1].strip_edges()
		if not text.is_empty() and not output.contains(old_lines[line - 1]):
			removed.append(text)
	return {"identical": false, "rows": rows, "removed_lines": removed}


## The saved file this sheet's compile targets - the diff's "old" side. "" when never saved.
static func saved_path_for(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	if not sheet.external_source_path.is_empty():
		return sheet.external_source_path
	if sheet.resource_path.is_empty():
		return ""
	return SheetCompiler._resolve_output_path(sheet, "")


## Sheet ▸ What Changed…: compute + show. The current sheet compiles to a SCRATCH path (a diff must
## never write the real file); the real file is only read.
func open() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	var saved_path: String = saved_path_for(sheet)
	if saved_path.is_empty() or not FileAccess.file_exists(saved_path):
		_dock._set_status("What Changed: this sheet has no saved file yet - everything is new.")
		return
	var result: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_diff_preview.gd")
	var summary: Dictionary = summarize(
		str(result.get("output", "")),
		result.get("source_map", []),
		FileAccess.get_file_as_string(saved_path))
	if bool(summary.get("identical", false)):
		_dock._set_status("What Changed: nothing - saving would be byte-identical to %s." % saved_path.get_file())
		return
	_entries = summary.get("rows", [])
	_ensure_dialog()
	_list.clear()
	for entry: Dictionary in _entries:
		_list.add_item("± %s" % str(entry.get("label", "")))
	var removed: PackedStringArray = summary.get("removed_lines", PackedStringArray())
	for removed_line: String in removed:
		_list.add_item("− %s" % removed_line)
	var row_count: int = _entries.size()
	_summary_label.text = "%d row%s change%s on save%s - double-click to jump." % [
		row_count, "" if row_count == 1 else "s", "s" if row_count == 1 else "",
		"" if removed.is_empty() else " · %d line%s removed" % [removed.size(), "" if removed.size() == 1 else "s"]]
	if _dialog.is_inside_tree():
		_dialog.popup_centered(Vector2i(560, 380))


# ── Compare With… - the same row-language diff against ANY other side ─────────────────────────
#
# open() answers exactly one question: this sheet against its own last save. The core underneath it
# was never that narrow - summarize() takes the compared side as a plain string - so the target is
# the only thing that has to move. compare_sides() runs summarize BOTH ways over two compiled sides,
# which is what turns a one-way report into a two-column comparison: rows that differ HERE, and rows
# that exist THERE and are missing or different here (each carrying its live resource, so a row can
# be brought over as ordinary rows). Everything below is static + pure over its arguments except
# load_side(), which reads one file and compiles to a SCRATCH path - a comparison never writes
# either real file.

## Where a compared side compiles to. Never a real path: comparing must not save behind anyone's back.
const COMPARE_SCRATCH_PATH := "user://eventforge_compare_side.gd"
## Where the CURRENT sheet compiles to while comparing. Same rule, separate file so one side's
## output can never overwrite the other's mid-compare.
const COMPARE_HERE_PATH := "user://eventforge_compare_here.gd"


## Loads one comparison side from disk and compiles it, so both sides of a comparison are
## {output, source_map} in the same shape open() already uses. A `.gd` opens through the lossless
## lifter (the same path Open… uses), anything else loads as an EventSheetResource. The loaded
## sheet is returned as well and MUST be kept alive by the caller: the row entries reference its
## resources by instance id, and a freed sheet turns every entry into a dead link.
## Returns {sheet, output, source_map} or {error: String}.
static func load_side(path: String) -> Dictionary:
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		return {"error": "There is no file at %s." % path}
	var sheet: EventSheetResource = null
	if path.get_extension() == "gd":
		sheet = GDScriptImporter.new().import_external_source(FileAccess.get_file_as_string(path))
		if sheet != null:
			# The lifted sheet must know it CAME FROM that file, or it recompiles down the authored
			# path and grows a second generated banner - which would then read as a difference the
			# user never made. With the source path set, an untouched file recompiles to its own
			# bytes, which is the whole basis of comparing compiled sides.
			sheet.external_source_path = path
	else:
		sheet = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	if sheet == null:
		return {"error": "%s could not be read as an event sheet." % path.get_file()}
	var compiled: Dictionary = SheetCompiler.compile(sheet, COMPARE_SCRATCH_PATH)
	return {
		"sheet": sheet,
		"output": str(compiled.get("output", "")),
		"source_map": compiled.get("source_map", []),
	}


## The two-sided comparison: summarize() run in both directions over two compiled sides.
## `here_*` is the open sheet, `there_*` the compared one. Returns
## {identical, here_rows, there_rows} where each row list is summarize()'s own
## [{uid, kind, label, resource}] - here_rows are rows of the OPEN sheet that differ, there_rows
## are rows of the COMPARED sheet that are missing or different here (the "Bring This Row Over"
## candidates). Pure: the caller owns both sides.
static func compare_sides(here_output: String, here_map: Array, there_output: String, there_map: Array) -> Dictionary:
	var here_side: Dictionary = strip_generated_banner(here_output, here_map)
	var there_side: Dictionary = strip_generated_banner(there_output, there_map)
	here_output = str(here_side.get("output"))
	here_map = here_side.get("source_map", [])
	there_output = str(there_side.get("output"))
	there_map = there_side.get("source_map", [])
	var here: Dictionary = summarize(here_output, here_map, there_output)
	var there: Dictionary = summarize(there_output, there_map, here_output)
	return {
		"identical": bool(here.get("identical", false)) and bool(there.get("identical", false)),
		"here_rows": here.get("rows", []),
		"there_rows": there.get("rows", []),
	}


## The comparison targets offered for `sheet`: its own last save, every backup in the shipped ring
## for `sheet_path`, then every other project sheet. [{label, path, kind}] in that order, so the
## most-asked question ("what did I change since I saved?") is the first entry. Browse… is added by
## the dialog, since it is a file picker rather than a known path.
static func compare_targets(sheet: EventSheetResource, sheet_path: String) -> Array:
	var targets: Array = []
	var saved: String = saved_path_for(sheet)
	if not saved.is_empty() and FileAccess.file_exists(saved):
		targets.append({"label": "Last save - %s" % saved.get_file(), "path": saved, "kind": "save"})
	if not sheet_path.strip_edges().is_empty():
		for backup_path: String in EventSheetBackups.list_backups(sheet_path):
			var stamp: String = Time.get_datetime_string_from_unix_time(
				int(FileAccess.get_modified_time(backup_path))).replace("T", " ")
			targets.append({"label": "Backup - %s" % stamp, "path": backup_path, "kind": "backup"})
	for other_path: String in EventSheetProjectFind.list_project_sheets():
		if other_path == sheet_path or other_path == saved:
			continue
		targets.append({"label": "Sheet - %s" % other_path.get_file(), "path": other_path, "kind": "sheet"})
	return targets


## The first line of the header every authored compile writes. A sheet opened FROM a .gd carries
## that header as ordinary comment ROWS instead, so two sides of the same file can disagree about
## whether the banner is content - and the banner names a version and a source path, which differ
## between any two files anyway. Neither is a difference the author made, so a comparison drops it.
const GENERATED_BANNER_PREFIX := "# AUTO-GENERATED by EventForge"


## `output` with a leading generated banner removed and `source_map` shifted to match, as
## {output, source_map}. Entries that emitted only banner lines drop out; one that straddles the
## cut keeps its remaining lines. A file that does not start with the banner is returned untouched.
## Pure, so the normalisation is pinned by a test rather than inferred from a screenshot.
static func strip_generated_banner(output: String, source_map: Array) -> Dictionary:
	var lines: PackedStringArray = output.split("\n")
	if lines.is_empty() or not lines[0].begins_with(GENERATED_BANNER_PREFIX):
		return {"output": output, "source_map": source_map}
	var cut: int = 0
	while cut < lines.size() and (lines[cut].begins_with("#") or lines[cut].strip_edges().is_empty()):
		cut += 1
	var shifted: Array = []
	for entry: Variant in source_map:
		if not (entry is Dictionary):
			continue
		var moved: Dictionary = (entry as Dictionary).duplicate()
		moved["start"] = maxi(int(moved.get("start", 0)) - cut, 1)
		moved["end"] = int(moved.get("end", 0)) - cut
		if int(moved["end"]) >= 1:
			shifted.append(moved)
	return {"output": "\n".join(lines.slice(cut)), "source_map": shifted}


## The row a "Bring This Row Over" writes: the TOP-LEVEL row of `sheet` that owns `resource`
## (an event that emitted the changed lines is normally itself top-level, but one nested in a
## group must arrive as its own row rather than as a fragment). Returns `resource` itself when it
## is already top level, or null when it belongs to no row of this sheet. Pure.
static func top_level_owner(sheet: EventSheetResource, resource: Resource) -> Resource:
	if sheet == null or resource == null:
		return null
	for row: Variant in sheet.events:
		if row is Resource and _row_contains(row as Resource, resource):
			return row as Resource
	return null


static func _row_contains(row: Resource, candidate: Resource) -> bool:
	if row == candidate:
		return true
	if row is EventRow:
		var event: EventRow = row as EventRow
		for child: Variant in event.sub_events:
			if child is Resource and _row_contains(child as Resource, candidate):
				return true
		for action: Variant in event.actions:
			if action is Resource and (action as Resource) == candidate:
				return true
		# Conditions and the trigger belong to the row every bit as much as its actions do. Leaving
		# them out made a difference that lives in a condition report as "not a row that can be
		# copied over", which is a false statement about an ordinary event.
		for condition: Variant in event.conditions:
			if condition is Resource and (condition as Resource) == candidate:
				return true
		for filter: Variant in event.pick_filters:
			if filter is Resource and (filter as Resource) == candidate:
				return true
		if event.trigger != null and event.trigger == candidate:
			return true
	elif row is EventGroup:
		var group: EventGroup = row as EventGroup
		for child: Variant in (group.events if not group.events.is_empty() else group.rows):
			if child is Resource and _row_contains(child as Resource, candidate):
				return true
	return false


func _ensure_dialog() -> void:
	if _dialog != null:
		return
	_dialog = Window.new()
	_dialog.title = "What Changed Since Save"
	_dialog.visible = false
	_dialog.min_size = Vector2i(480, 300)
	_dialog.close_requested.connect(func() -> void: _dialog.hide())
	_dock.add_child(_dialog)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_summary_label = EventSheetPopupUI.hint_label("")
	content.add_child(_summary_label)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(func(index: int) -> void:
		if index < _entries.size() and (_entries[index] as Dictionary).get("resource") is Resource:
			var view: EventSheetViewport = _dock._active_view()
			if view != null:
				view.reveal_resource((_entries[index] as Dictionary).get("resource"))
			_dialog.hide())
	content.add_child(_list)
	var full_content: MarginContainer = EventSheetPopupUI.margined(content)
	full_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(full_content)
