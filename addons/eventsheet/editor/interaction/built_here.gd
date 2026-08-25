@tool
class_name EventSheetBuiltHere
extends RefCounted

# "SHOW THE EVENTS BEHIND THIS": Ctrl+Shift+Alt-click any control the plugin built and the
# sheet that built it opens, scrolled to the row that made it.
#
# "Where is this button made" is one of the two questions a contributor asks most, and today it is
# answered by grepping for the label. The sheet can answer it instead - the file that built the
# control IS a sheet, and the row that built it is a row in it.
#
# HOW IT IS FOUND, WITHOUT A REGISTRY. A control carries two facts in its own meta: which of the
# editor's files built it, and the words it was built with (its label, its menu text). The row is
# then found the way a reader would find it - the row whose code names those words. No table to keep
# in step, nothing to register, and a control whose words change simply stops matching rather than
# pointing at the wrong row.
#
# NOTHING IS WRITTEN OUTSIDE THIS REPO. `mark` is a no-op unless the open project IS the editor's own
# (the gate), so a shipped editor in a game project carries no meta, no strings and no extra
# bytes. The marking calls stay in the source either way, which is deliberate: a mark that had to be
# added and removed would be wrong within a week.

## The meta key one marked control carries: {"path": the file that built it, "marker": its words}.
const META_KEY: String = "eventsheets_built_here"


## Marks a control with the file that built it and the words it was built with. Does nothing at all
## outside the editor's own repo, and nothing when either fact is missing - a mark with no words to
## find is a mark that would open a file and then sit at the top of it.
static func mark(control: Control, source_path: String, marker: String) -> void:
	if control == null or source_path.is_empty() or marker.strip_edges().is_empty():
		return
	if not EventSheetThisEditor.folder_is_on():
		return
	control.set_meta(META_KEY, {"path": source_path, "marker": marker})


## What built this control, walking up until a marked ancestor is found - a button inside a marked
## row is made by whatever made the row. {} when nothing on the way up is marked.
static func source_for(control: Control) -> Dictionary:
	var node: Node = control
	while node != null:
		if node.has_meta(META_KEY):
			var recorded: Variant = node.get_meta(META_KEY)
			if recorded is Dictionary:
				return recorded as Dictionary
		node = node.get_parent()
	return {}


## The gesture: Ctrl+Shift+Alt and the left button, pressed. Three modifiers on purpose - this fires
## on any control in the editor, so it has to be a chord nothing else could mean.
static func is_show_source_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
		and mouse.ctrl_pressed and mouse.shift_pressed and mouse.alt_pressed


## The row of `sheet` that names `marker` - the row that built the control. Verbatim rows first,
## because a control is built by a line of code and that line carries its words as a literal; then
## the same walk through events and functions, so a marked control inside a lifted function is found
## too. Null when the words appear nowhere, which is an honest "this moved" rather than a wrong jump.
static func find_row(sheet: EventSheetResource, marker: String) -> Resource:
	if sheet == null or marker.strip_edges().is_empty():
		return null
	var found: Resource = _find_in(sheet.events, marker)
	if found != null:
		return found
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var in_function: Resource = _find_in((function_entry as EventFunction).events, marker)
			if in_function != null:
				return in_function
	return null


static func _find_in(items: Array, marker: String) -> Resource:
	for item: Variant in items:
		if item is RawCodeRow:
			if (item as RawCodeRow).code.contains("\"%s\"" % marker):
				return item as Resource
		elif item is EventRow:
			var event: EventRow = item as EventRow
			var in_actions: Resource = _find_in(event.actions, marker)
			if in_actions != null:
				return in_actions
			var in_subs: Resource = _find_in(event.sub_events, marker)
			if in_subs != null:
				return in_subs
		elif item is EventFunction:
			var in_function: Resource = _find_in((item as EventFunction).events, marker)
			if in_function != null:
				return in_function
		elif item is EventGroup:
			var in_group: Resource = _find_in((item as EventGroup).events, marker)
			if in_group != null:
				return in_group
	return null


## The status line the jump writes, so the reader is told which file they landed in and why.
static func landed_text(source_path: String, marker: String, found: bool) -> String:
	if found:
		return EventSheetL10n.translate("%s is built here - the row that makes \"%s\".") % [
			source_path.get_file(), marker]
	return EventSheetL10n.translate("%s builds it, but no row still names \"%s\" - it was renamed or moved.") % [
		source_path.get_file(), marker]
