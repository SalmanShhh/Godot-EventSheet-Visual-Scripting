# Godot EventSheets - the History panel (dock subsystem)
#
# Every edit you have made to this sheet, in the sheet's own words, newest last. Godot's own History
# dock lists the same steps under their internal names; this one lists them the way the sheet named
# them when it made them ("Add Group", "Extract to Function", "Move Variable Up"), with the event
# they landed on beside them. Click one to undo or redo back to it; hover one to see the rows it
# touched lit up on the canvas.
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

const COLOR_APPLIED := Color("#dfe4ec")
const COLOR_UNDONE := Color("#8a90a0")

var _dock: Control = null

## [{label, event_number, touched: PackedStringArray, before: Resource, after: Resource}] in the
## order the edits were made. Everything from `cursor` on has been undone.
var entries: Array[Dictionary] = []
var cursor: int = 0

var window: Window = null
var tree: Tree = null
var _empty_hint: Label = null


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


## One entry as the list writes it: the sheet's own name for the edit, then the event it landed on,
## then "(undone)" when it is waiting to be redone. Pure, so the wording is pinned headless.
static func entry_label(label: String, event_number: int, undone: bool) -> String:
	var text: String = label
	if event_number > 0:
		text += "   event %d" % event_number
	if undone:
		text += "   (undone)"
	return text


func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "History"
	window.size = Vector2i(420, 420)
	window.close_requested.connect(func() -> void: window.hide())
	var body_box: VBoxContainer = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 6)
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree = Tree.new()
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0.0, 260.0)
	tree.item_selected.connect(_on_entry_selected)
	tree.item_mouse_selected.connect(_on_entry_hovered)
	body_box.add_child(tree)
	_empty_hint = EventSheetPopupUI.hint_label("No edits yet. Every change you make to this sheet is listed here, in the sheet's own words.", 360.0)
	body_box.add_child(_empty_hint)
	var card: Control = EventSheetPopupUI.titled_card("History", body_box)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: Control = EventSheetPopupUI.margined(card)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(body)
	_dock.add_child(window)


func open() -> void:
	build()
	refresh()
	window.popup_centered()


## Rebuilds the list from the log (popup-free, so tests pin it headless).
func refresh() -> void:
	if tree == null:
		return
	tree.clear()
	var root: TreeItem = tree.create_item()
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var undone: bool = index >= cursor
		var item: TreeItem = tree.create_item(root)
		item.set_text(0, (MARK_UNDONE if undone else MARK_APPLIED) + entry_label(
			str(entry.get("label", "")), int(entry.get("event_number", 0)), undone))
		item.set_custom_color(0, COLOR_UNDONE if undone else COLOR_APPLIED)
		item.set_metadata(0, index)
	if _empty_hint != null:
		_empty_hint.visible = entries.is_empty()


## Click = travel: undo back to the step before this one, or redo forward to it. The steps in
## between are replayed by the undo stack itself, so nothing here reimplements an edit.
func _on_entry_selected() -> void:
	var selected: TreeItem = tree.get_selected()
	if selected == null:
		return
	travel_to(int(selected.get_metadata(0)) + 1)


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


## Hover = the rows that edit touched, lit on the canvas. Selecting an entry with the mouse is the
## hover the Tree gives us; leaving the panel clears the light.
func _on_entry_hovered(_position: Vector2, _button: int) -> void:
	var selected: TreeItem = tree.get_selected()
	if selected == null or _dock._viewport == null:
		return
	var index: int = int(selected.get_metadata(0))
	if index < 0 or index >= entries.size():
		return
	_dock._viewport.set_row_highlight(entries[index].get("touched", PackedStringArray()))
