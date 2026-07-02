@tool
extends RefCounted
class_name EventSheetSheetDiff
# "What changed since the last save?" — in EVENT language, not text lines.
#
# Compiles the CURRENT sheet to a scratch path (never the real file — compile writes its output, and
# a diff must not save behind the user's back), diffs that against the SAVED .gd on disk, and maps
# the changed lines back to sheet rows through the line↔row mapper — so the answer is "these events
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
## {old_start, old_end, new_start, new_end} — 1-based inclusive; {} when identical.
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

## The saved file this sheet's compile targets — the diff's "old" side. "" when never saved.
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
		_dock._set_status("What Changed: this sheet has no saved file yet — everything is new.")
		return
	var result: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_diff_preview.gd")
	var summary: Dictionary = summarize(
		str(result.get("output", "")),
		result.get("source_map", []),
		FileAccess.get_file_as_string(saved_path))
	if bool(summary.get("identical", false)):
		_dock._set_status("What Changed: nothing — saving would be byte-identical to %s." % saved_path.get_file())
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
	_summary_label.text = "%d row%s change%s on save%s — double-click to jump." % [
		row_count, "" if row_count == 1 else "s", "s" if row_count == 1 else "",
		"" if removed.is_empty() else " · %d line%s removed" % [removed.size(), "" if removed.size() == 1 else "s"]]
	if _dialog.is_inside_tree():
		_dialog.popup_centered(Vector2i(560, 380))

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
