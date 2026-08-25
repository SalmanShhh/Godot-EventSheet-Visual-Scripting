@tool
class_name EventSheetHierarchyEdits
extends RefCounted

# What the Hierarchy pane's gestures actually WRITE.
#
# Dropping an object into the pane, right-clicking ▸ flags…, and dragging a child out are three
# gestures for one thing: a row that changes the tree while the game runs. Each one lands here, opens
# the tick dialog where there is something to tick, and then writes plain GDScript through the dock's
# undo funnel - so Ctrl+Z takes the whole parenting back like any other row.
#
# The lines it writes are the hierarchy spellings themselves (`child.reparent(parent)` and friends),
# not a private encoding: a reader who opens the .gd sees exactly what the pane showed, and the
# canvas reads the row back without anything being converted between the two.
#
# The pane never touches a .tscn. A child the scene file owns greys its two writing commands out and
# offers "edit the scene" instead, which selects that node so Godot's own Scene dock has it.

var _dock: Control = null

var _flags_dialog: ConfirmationDialog = null
var _flag_boxes: Dictionary = {}
var _keep_place_box: CheckBox = null
var _flags_callback: Callable = Callable()
var _flags_subject: Label = null


func init(dock: Control) -> void:
	_dock = dock


## An object dropped into the pane: the flags dialog opens on the drop (that is where the four ticks
## live), and confirming writes the Add child lines under a start-of-layout event.
func add_child_requested(parent_label: String, child_label: String) -> void:
	if parent_label.strip_edges().is_empty() or child_label.strip_edges().is_empty():
		return
	if parent_label.strip_edges() == child_label.strip_edges():
		_dock._set_status("An object cannot be its own parent.", true)
		return
	prompt_flags(child_label, EventSheetObjectHierarchy.default_flags(),
		func(flags: Dictionary) -> void: _write_add_child(parent_label, child_label, flags))


## Right-click ▸ flags… on a child already in the list. Same dialog, same write: the previous lines
## are replaced rather than stacked, so ticking twice does not leave two RemoteTransforms behind.
func flags_requested(parent_label: String, child_label: String) -> void:
	var facts: Dictionary = _facts_for(parent_label)
	prompt_flags(child_label, _flags_of(facts, child_label),
		func(flags: Dictionary) -> void: _write_add_child(parent_label, child_label, flags))


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


## Right-click ▸ Remove from parent, and the same thing a child chip dragged out of the pane means.
func unparent_requested(child_label: String) -> void:
	var child_entry: Dictionary = EventSheetObjectProperties.find_entry(_dock._current_sheet, child_label)
	var line: String = EventSheetObjectHierarchy.remove_from_parent_line(
		EventSheetObjectHierarchy.reference_for(child_entry))
	if line.is_empty():
		_dock._set_status("There is no object named %s to unparent." % child_label, true)
		return
	if _dock._perform_undoable_sheet_edit("Remove From Parent",
			func() -> bool: return _append_setup_lines(PackedStringArray([line]))):
		_dock._set_status("%s leaves its parent and keeps its place in the layout." % child_label)


## The muted offer beside a child the .tscn owns: the scene is Godot's, so this only points Godot at
## the node - the Scene dock takes the selection and the reader edits it there.
func edit_scene_requested(child_label: String) -> void:
	_dock.select_object_in_scene(child_label)
	_dock._set_status("%s lives in the scene file - edit it in the Scene dock." % child_label)


## The four ticks, as the hierarchy's users know them, mapped onto what Godot really does. Only what
## differs from a plain child is ever written, so the ordinary drop stays one clean line.
func prompt_flags(child_label: String, flags: Dictionary, callback: Callable) -> void:
	if _flags_dialog == null:
		_flags_dialog = ConfirmationDialog.new()
		_flags_dialog.title = EventSheetL10n.translate("Add child")
		_flags_dialog.ok_button_text = EventSheetL10n.translate("Add child")
		_flags_dialog.min_size = Vector2i(420, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
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
		_flags_dialog.add_child(EventSheetPopupUI.margined(box))
		_flags_dialog.confirmed.connect(_apply_flags)
		_dock.add_child(_flags_dialog)
	_flags_subject.text = EventSheetL10n.translate("Add child %s") % child_label
	for key: String in _flag_boxes:
		(_flag_boxes[key] as CheckBox).button_pressed = bool(flags.get(key, true))
	_keep_place_box.button_pressed = bool(flags.get("keep_place", true))
	_flags_callback = callback
	_flags_dialog.popup_centered()


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


## The write itself. Both references are re-derived from the LIVE sheet: the undo funnel replaces
## every resource on commit, so an entry captured when the pane was drawn may describe a sheet that
## no longer exists.
func _write_add_child(parent_label: String, child_label: String, flags: Dictionary) -> bool:
	var sheet: EventSheetResource = _dock._current_sheet
	var parent_entry: Dictionary = EventSheetObjectProperties.find_entry(sheet, parent_label)
	var child_entry: Dictionary = EventSheetObjectProperties.find_entry(sheet, child_label)
	var lines: PackedStringArray = EventSheetObjectHierarchy.add_child_lines(
		EventSheetObjectHierarchy.reference_for(parent_entry) if not parent_entry.is_empty() else "$%s" % parent_label,
		EventSheetObjectHierarchy.reference_for(child_entry) if not child_entry.is_empty() else "$%s" % child_label,
		flags, EventSheetObjectHierarchy.dimension_for(sheet, parent_entry, child_entry))
	if lines.is_empty():
		_dock._set_status("Nothing to write - name both the parent and the child.", true)
		return false
	var applied: bool = _dock._perform_undoable_sheet_edit("Add Child",
		func() -> bool: return _append_setup_lines(lines))
	if applied:
		_dock._set_status("%s is now a child of %s." % [child_label, parent_label])
	return applied


## Where a hierarchy row lands: the sheet's start-of-layout event, joined if there already is one so
## a pane used four times writes four actions under one event instead of four bare events.
func _append_setup_lines(lines: PackedStringArray) -> bool:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null or lines.is_empty():
		return false
	var row: RawCodeRow = RawCodeRow.new()
	row.code = "\n".join(lines)
	for entry: Variant in sheet.events:
		var event_row: EventRow = entry as EventRow
		if event_row != null and event_row.trigger_id == "OnReady" and event_row.conditions.is_empty():
			event_row.actions.append(row)
			return true
	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"
	setup.trigger_id = "OnReady"
	setup.actions.append(row)
	sheet.events.append(setup)
	return true


func _facts_for(object_label: String) -> Dictionary:
	var sheet: EventSheetResource = _dock._current_sheet
	return EventSheetObjectHierarchy.facts_for(sheet,
		EventSheetObjectProperties.find_entry(sheet, object_label),
		str(sheet.get("external_source_path")) if sheet != null else "")


## The flags one child already carries, so re-opening the dialog starts from what is written rather
## than from the defaults.
static func _flags_of(facts: Dictionary, child_label: String) -> Dictionary:
	var flags: Dictionary = EventSheetObjectHierarchy.default_flags()
	for item: Variant in facts.get("children", []):
		var child: Dictionary = item
		if str(child.get("label", "")) != child_label:
			continue
		if bool(child.get("ignores_movement", false)):
			flags["position"] = false
			flags["angle"] = false
			flags["size"] = false
		for key: String in ["position", "angle", "size"]:
			var transforms: Dictionary = child.get("transforms", {})
			if transforms.has(key):
				flags[key] = bool(transforms[key])
		break
	return flags
