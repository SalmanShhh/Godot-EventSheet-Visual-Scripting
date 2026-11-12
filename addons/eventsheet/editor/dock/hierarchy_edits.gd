@tool
class_name EventSheetHierarchyEdits
extends RefCounted

# What the flags chip on an Add child row WRITES.
#
# Clicking the chip opens the tick dialog, and confirming rewrites the row's own lines as plain
# GDScript through the dock's undo funnel, so Ctrl+Z takes the change back like any other edit. The
# lines are the hierarchy spellings themselves (`child.reparent(parent)` and friends), not a private
# encoding: a reader who opens the .gd sees what the row says.

var _dock: Control = null

var _flags_dialog: ConfirmationDialog = null
var _flag_boxes: Dictionary = {}
var _keep_place_box: CheckBox = null
var _flags_callback: Callable = Callable()
var _flags_subject: Label = null


func init(dock: Control) -> void:
	_dock = dock


## The flags chip on an Add child ROW: the same four ticks, seeded from what the run already
## says, and written back over the very lines the row stands for rather than appended beside them.
func row_flags_requested(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	prompt_flags(str(payload.get("child", "")), payload.get("flags", {}),
		func(flags: Dictionary) -> void: _write_row_flags(payload, flags))


## The rewrite. The run's own actions are replaced by the lines the new ticks mean, so ticking twice
## leaves ONE set of plumbing rather than two - and the row reads back as the flagged row it was,
## which is the two-way promise this chip makes.
func _write_row_flags(payload: Dictionary, flags: Dictionary) -> bool:
	var lines: PackedStringArray = EventSheetObjectHierarchy.add_child_lines(
		str(payload.get("parent_value", "")), str(payload.get("child_value", "")), flags,
		_row_dimension(payload))
	if lines.is_empty():
		_dock._set_status("Nothing to write - the row no longer names both objects.", true)
		return false
	var applied: bool = _dock._perform_undoable_sheet_edit("Add Child Flags",
		func() -> bool: return _replace_run_lines(payload, lines))
	if applied:
		_dock._set_status("%s follows %s by the flags you ticked." % [str(payload.get("child", "")),
			EventSheetSentence.object_of_reference(str(payload.get("parent_value", "")))])
	return applied


## Which dimension the follower is written in: the one the run already used, or - for a run that had
## no follower to say it - what the two objects themselves are.
func _row_dimension(payload: Dictionary) -> String:
	var stated: String = str(payload.get("dimension", "")).strip_edges()
	if not stated.is_empty():
		return stated
	var sheet: EventSheetResource = _dock._current_sheet
	return EventSheetObjectHierarchy.dimension_for(sheet, {}, {})


## The actions the row stands for, swapped for the ones the ticks mean. The event is found by UID in
## the LIVE sheet: the undo funnel replaces every resource on commit, so the row the chip was drawn
## from describes a sheet that no longer exists by the time this runs.
func _replace_run_lines(payload: Dictionary, lines: PackedStringArray) -> bool:
	return replace_run_lines(_dock._current_sheet, payload, lines)


## The same rewrite, over any sheet - which is how a test asks what the chip writes without a dock,
## a viewport or a dialog anywhere in the picture.
static func replace_run_lines(sheet: EventSheetResource, payload: Dictionary,
		lines: PackedStringArray) -> bool:
	var event_row: EventRow = _find_event(sheet, str(payload.get("event_uid", "")))
	if event_row == null:
		return false
	var first: int = int(payload.get("first_index", -1))
	var last: int = int(payload.get("last_index", -1))
	if first < 0 or last < first or last >= event_row.actions.size():
		return false
	var written: RawCodeRow = RawCodeRow.new()
	written.code = "\n".join(lines)
	for _removed: int in range(first, last + 1):
		event_row.actions.remove_at(first)
	event_row.actions.insert(first, written)
	return true


## One event by uid, anywhere in the sheet - inside a group or a function as readily as at the top.
static func _find_event(sheet: EventSheetResource, event_uid: String) -> EventRow:
	if sheet == null or event_uid.strip_edges().is_empty():
		return null
	var pending: Array = []
	pending.append_array(sheet.events)
	for function_entry: Variant in sheet.functions:
		var event_function: EventFunction = function_entry as EventFunction
		if event_function != null:
			pending.append_array(event_function.events)
	while not pending.is_empty():
		var entry: Variant = pending.pop_front()
		var event_row: EventRow = entry as EventRow
		if event_row != null:
			if event_row.event_uid == event_uid:
				return event_row
			pending.append_array(event_row.sub_events)
			continue
		var group: EventGroup = entry as EventGroup
		if group != null:
			pending.append_array(group.events)
	return null


## The four ticks, as the hierarchy's users know them, mapped onto what Godot really does. Only what
## differs from a plain child is ever written, so the ordinary drop stays one clean line.
func prompt_flags(child_label: String, flags: Dictionary, callback: Callable) -> void:
	if _flags_dialog == null:
		var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("Add child"), Vector2i(420, 0),
			_dock, EventSheetL10n.translate("Add child"), _apply_flags, true)
		_flags_dialog = parts["window"]
		var box: VBoxContainer = parts["box"]
		_flags_subject = Label.new()
		box.add_child(_flags_subject)
		var ticks: VBoxContainer = EventSheetPopupUI.form_box()
		for tick: Array in [["position", "transform position"], ["angle", "transform angle"],
				["size", "transform size"], ["destroy", "destroy with parent"]]:
			var check: CheckBox = CheckBox.new()
			check.text = EventSheetL10n.translate(str(tick[1]))
			_flag_boxes[str(tick[0])] = check
			ticks.add_child(check)
		_keep_place_box = CheckBox.new()
		_keep_place_box.text = EventSheetL10n.translate("keeping its place")
		ticks.add_child(_keep_place_box)
		box.add_child(EventSheetPopupUI.panel_section(ticks))
		box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
			"All four on is a plain Godot child, and writes one line. Switching a transform off adds the node that drives the child instead; switching all three off is Ignore parent's movement. Unticking keeping its place snaps the child to its new parent.")))
	_flags_subject.text = EventSheetL10n.translate("Add child %s") % child_label
	for key: String in _flag_boxes:
		(_flag_boxes[key] as CheckBox).button_pressed = bool(flags.get(key, true))
	_keep_place_box.button_pressed = bool(flags.get("keep_place", true))
	_flags_callback = callback
	EventSheetPopupUI.popup_fitted(_flags_dialog)


## The ticks as a flags dictionary, public so a headless test reads what the dialog would apply.
func flags_from_dialog() -> Dictionary:
	var flags: Dictionary = EventSheetObjectHierarchy.default_flags()
	for key: String in _flag_boxes:
		flags[key] = (_flag_boxes[key] as CheckBox).button_pressed
	flags["keep_place"] = _keep_place_box.button_pressed
	return flags


func _apply_flags() -> void:
	if not _flags_callback.is_valid():
		return
	var callback: Callable = _flags_callback
	_flags_callback = Callable()
	callback.call(flags_from_dialog())
