# Godot EventSheets - the History panel (dock subsystem)
#
# Every edit you have made to this sheet, in the sheet's own words, newest last. Godot's own History
# dock lists the same steps under their internal names; this one lists them the way the sheet named
# them when it made them ("Add Group", "Extract to Function", "Move Variable Up"), with the event
# they landed on beside them. Click one to undo or redo back to it (the first line, "Opened", is the
# sheet as it was before any of them) and the rows it touched light up on the canvas until the
# window closes; Go Back to This Step does the same for a line picked with the keys.
#
# The log is the dock's own: it is written by the one funnel every sheet edit goes through, and the
# cursor follows the snapshots that funnel restores - so Ctrl+Z from anywhere, the toolbar arrows
# and a click in this list all move the same marker. Session-only, never serialized.
@tool
class_name EventSheetHistoryPanel
extends RefCounted

## The mark in front of an entry: applied, or undone and waiting to be redone.
const MARK_APPLIED := "• "
const MARK_UNDONE := "◦ "

## The metadata of the list's first line, the sheet before any listed edit: travelling to it undoes
## every one of them.
const START_INDEX := -1

var _dock: Control = null

## [{label, event_number, touched: PackedStringArray, before: Resource, after: Resource}] in the
## order the edits were made. Everything from `cursor` on has been undone.
var entries: Array[Dictionary] = []
var cursor: int = 0

var window: Window = null
var tree: Tree = null
var _empty_hint: Label = null
## The strip under the list: the clicked step (THIS ROW) over the keys that move the same marker.
var strip: EventSheetPopupUI.HelpStrip = null
var _this_row: Label = null


func _init(dock: Control) -> void:
	_dock = dock


## Writes one edit into the log. A new edit made after an undo throws away the steps that were
## waiting to be redone, exactly as the undo stack itself does.
func record(label: String, before: Resource, after: Resource, event_number: int) -> void:
	if cursor < entries.size():
		entries.resize(cursor)
	entries.append({
		"label": label,
		"event_number": event_number,
		"touched": touched_uids(before, after),
		"before": before,
		"after": after
	})
	cursor = entries.size()
	refresh()


## Moves the marker to wherever an undo or a redo just put the sheet. The funnel restores the
## `before` of a step to undo it and the `after` to redo it, so the snapshot alone says where the
## marker belongs - no signal from the undo manager needed, and Godot's own Ctrl+Z lands here too.
## Returns true when the snapshot was one of ours.
func note_restored(snapshot: Resource) -> bool:
	for index: int in entries.size():
		if entries[index].get("after") == snapshot:
			cursor = index + 1
			refresh()
			return true
		if entries[index].get("before") == snapshot:
			cursor = index
			refresh()
			return true
	return false


func clear() -> void:
	entries.clear()
	cursor = 0
	refresh()


## The log as it stands, for a host that keeps one per open tab. The panel is the dock's, but the
## edits in it are one sheet's, so a tab that is switched away from takes its own list with it and
## the tab switched to shows the steps IT was edited by - never a merged list of both.
func capture_log() -> Dictionary:
	return {"entries": entries.duplicate(), "cursor": cursor}


## Seats a log capture_log() made back into the panel. An empty state is an empty log, which is
## what a tab that has never been edited has.
func adopt_log(state: Dictionary) -> void:
	var kept: Variant = state.get("entries", [])
	entries.assign(kept if kept is Array else [])
	cursor = clampi(int(state.get("cursor", 0)), 0, entries.size())
	refresh()


## The rows an edit changed: every row uid that one side of the edit has and the other does not.
## An edit that only rewrote a row's contents keeps its uid, so it answers nothing here - the panel
## falls back to the event the edit was made on. Pure and static, so tests pin it.
static func touched_uids(before: Resource, after: Resource) -> PackedStringArray:
	var before_uids: Dictionary = {}
	var after_uids: Dictionary = {}
	_collect_uids(before, before_uids)
	_collect_uids(after, after_uids)
	var touched: PackedStringArray = PackedStringArray()
	for uid: String in after_uids:
		if not before_uids.has(uid):
			touched.append(uid)
	for uid: String in before_uids:
		if not after_uids.has(uid):
			touched.append(uid)
	return touched


static func _collect_uids(sheet: Resource, into: Dictionary) -> void:
	if sheet == null or not (sheet is EventSheetResource):
		return
	_walk_uids((sheet as EventSheetResource).events, into)


## The uid a row carries is the one the canvas keys its own rows on: an event's `event_uid`, a
## group's `group_uid`. Anything else in the sheet is addressed by its position, so it is skipped -
## a step that only moved such a row falls back to the event it was made on.
static func _walk_uids(rows: Array, into: Dictionary) -> void:
	for entry: Variant in rows:
		if entry is EventRow:
			var event_row: EventRow = entry as EventRow
			if not event_row.event_uid.is_empty():
				into[event_row.event_uid] = true
			_walk_uids(event_row.sub_events, into)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			if not group.group_uid.is_empty():
				into[group.group_uid] = true
			_walk_uids(group.events if not group.events.is_empty() else group.rows, into)


## One entry's Step column: the sheet's own name for the edit, then "(undone)" when it is waiting to
## be redone. Pure, so the wording is pinned headless.
static func entry_label(label: String, undone: bool) -> String:
	return label + ("   " + EventSheetL10n.translate("(undone)") if undone else "")


## One entry's Event column: the event the edit landed on, blank for an edit made on no event.
static func event_label(event_number: int) -> String:
	return EventSheetL10n.translate("event %d") % event_number if event_number > 0 else ""


## What a clicked step did, for the strip's THIS ROW line. Pure, so tests pin it.
static func entry_sentence(label: String, event_number: int) -> String:
	if event_number > 0:
		return EventSheetL10n.translate("%s, event %d. Click undoes back to just after it; the rows it touched light up.") % [label, event_number]
	return EventSheetL10n.translate("%s. Click undoes back to just after it; the rows it touched light up.") % label


func build() -> void:
	if window != null:
		return
	var parts: Dictionary = EventSheetPopupUI.action_window(EventSheetL10n.translate("History"),
		EventSheetL10n.translate("Go Back to This Step"), EventSheetL10n.translate("Close"), Vector2i(440, 460), _dock)
	window = parts["window"]
	window.confirmed.connect(_on_entry_selected)
	# The light is the clicked step's; it goes dark when the window does.
	window.visibility_changed.connect(func() -> void:
		if not window.visible:
			highlight_entry(-1))
	var body_box: VBoxContainer = parts["box"]
	tree = EventSheetPopupUI.table(PackedStringArray([EventSheetL10n.translate("Step"),
		EventSheetL10n.translate("Event")]), 260.0, {1: 90})
	tree.select_mode = Tree.SELECT_ROW
	tree.item_selected.connect(_on_entry_selected)
	var results: Dictionary = EventSheetPopupUI.add_results(body_box, EventSheetL10n.translate("History"), tree)
	strip = results["strip"]
	_this_row = results["this_row"]
	strip.set_line(strip.add_line(EventSheetL10n.translate("KEYS")),
		EventSheetL10n.translate("Ctrl+Z and the toolbar arrows move the same marker"))
	strip.visible = true
	_empty_hint = EventSheetPopupUI.hint_label(EventSheetL10n.translate("No edits yet. Every change you make to this sheet is listed here, in the sheet's own words."), 360.0)
	body_box.add_child(_empty_hint)


func open() -> void:
	build()
	refresh()
	window.popup_centered()


## Fills the list from the log (popup-free, so tests pin it headless). The lines are rewritten IN
## PLACE when there are as many as before: a click travels through undo and redo, which lands back
## here while the Tree is still selecting the clicked line, and freeing that line mid-selection takes
## the editor down.
func refresh() -> void:
	if tree == null:
		return
	window.title = EventSheetL10n.translate("History of %s") % _sheet_file()
	# The sheet before the first listed edit: without a line of its own the list could undo back to
	# just after the first edit and no further.
	var wanted: int = entries.size() + (0 if entries.is_empty() else 1)
	var root: TreeItem = tree.get_root()
	if root == null or root.get_child_count() != wanted:
		tree.clear()
		root = tree.create_item()
		for _line: int in wanted:
			tree.create_item(root)
	var lines: Array[TreeItem] = root.get_children()
	for line_index: int in lines.size():
		var item: TreeItem = lines[line_index]
		var index: int = line_index - 1
		var undone: bool = index >= cursor
		if index < 0:
			item.set_text(0, MARK_APPLIED + EventSheetL10n.translate("Opened %s") % _sheet_file())
		else:
			var entry: Dictionary = entries[index]
			item.set_text(0, (MARK_UNDONE if undone else MARK_APPLIED) + entry_label(str(entry.get("label", "")), undone))
			item.set_text(1, event_label(int(entry.get("event_number", 0))))
		# The theme's own text and muted text, so an undone step reads quieter on a light panel too.
		for column: int in 2:
			item.set_custom_color(column, EventSheetPopupUI.muted_text_color() if undone else EventSheetPopupUI.text_color())
		item.set_metadata(0, START_INDEX if index < 0 else index)
	if _empty_hint != null:
		_empty_hint.visible = entries.is_empty()


## The sheet's file as the tab names it, or "this sheet" before it has one.
func _sheet_file() -> String:
	var path: String = str(_dock.get("_current_sheet_path")) if _dock != null and "_current_sheet_path" in _dock else ""
	return path.get_file() if not path.is_empty() else EventSheetL10n.translate("this sheet")


## Click = travel: undo back to the step before this one, or redo forward to it, and light the rows
## that step touched. The steps in between are replayed by the undo stack itself, so nothing here
## reimplements an edit.
func _on_entry_selected() -> void:
	var selected: TreeItem = tree.get_selected()
	if selected == null:
		return
	var index: int = int(selected.get_metadata(0))
	if strip != null:
		strip.set_line(_this_row, EventSheetL10n.translate("The sheet as it was opened. Click undoes every step below it.")
			if index < 0 else entry_sentence(str(entries[index].get("label", "")), int(entries[index].get("event_number", 0))))
	travel_to(index + 1)
	highlight_entry(index)


func travel_to(target_cursor: int) -> void:
	var target: int = clampi(target_cursor, 0, entries.size())
	var guard: int = entries.size() + 1
	while cursor > target and guard > 0:
		guard -= 1
		var was: int = cursor
		_dock._on_undo_requested()
		if cursor == was:
			break
	while cursor < target and guard > 0:
		guard -= 1
		var was_redo: int = cursor
		_dock._on_redo_requested()
		if cursor == was_redo:
			break
	refresh()


## Lights the rows entry `index` touched; anything that is not an edit (the start line, empty space,
## -1) clears the light. The rows light in the ACTIVE pane - the one the reader is working in, as
## the Outline and Bookmarks jump there - not always in the left one.
func highlight_entry(index: int) -> void:
	if _dock == null:
		return
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return
	if index < 0 or index >= entries.size():
		view.clear_row_highlight()
		return
	view.set_row_highlight(entries[index].get("touched", PackedStringArray()))
