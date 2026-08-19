@tool
class_name EventSheetLooseEndsPanel
extends RefCounted
# Tools ▸ Loose Ends - "what did I leave unfinished?", indexed.
#
# Every state this panel lists is ALREADY modelled and already drawn: a TODO comment looks like a
# TODO comment, a disabled row looks disabled, a breakpointed row carries its dot. Nothing indexes
# them, so an unfinished thing is invisible until you happen to scroll past it.
#
# A PANEL, DELIBERATELY NOT ROW BADGES. Marking every TODO, disabled row and forgotten breakpoint
# in the margin would put a permanent warning layer over a sheet whose author already knows what is
# in it, and would ask a beginner to ignore something. With this panel closed the sheet renders
# exactly as it does today - byte for byte, pixel for pixel. The index is somewhere you GO when the
# question comes up, which is a few times a project, not continuously.
#
# The walk (loose_ends) is static and pure over the sheet, so the same list is available headless,
# in a test, and to anything else that wants to ask the question.

## The kinds, in the order the panel groups them. Each is {id, title}.
const KIND_ORDER: Array = [
	{"id": "todo", "title": "TODO / FIXME"},
	{"id": "unfinished", "title": "Unfinished events"},
	{"id": "disabled", "title": "Disabled rows"},
	{"id": "breakpoint", "title": "Breakpoints left on"},
	{"id": "orphan_verb", "title": "Functions nothing calls"},
	{"id": "flagged", "title": "Rows the checker flags"},
]

## The markers a comment or a code line carries when it is a note to self.
const MARKERS := ["TODO", "FIXME", "HACK", "XXX"]

var _dock: Control = null

var window: Window = null
var tree: Tree = null
var summary_label: Label = null

var _entries: Array = []


func init(dock: Control) -> void:
	_dock = dock


## Every loose end in `sheet`, in sheet order, as [{kind, label, detail, resource}].
## `flagged` is the row-diagnostics list ([{uid, message, ...}], as EventSheetDiagnostics.analyze
## returns it) - passed in rather than computed here so the walk stays pure and the panel can pass
## the registry-aware version while a test passes none. Static, so the same answer is available
## headless and to anything else that wants to ask.
static func loose_ends(sheet: EventSheetResource, flagged: Array = []) -> Array:
	var entries: Array = []
	if sheet == null:
		return entries
	var counter: Dictionary = {"event": 0}
	_walk(sheet.events, counter, entries)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_walk((function_entry as EventFunction).events, counter, entries)
	for orphan: Dictionary in _orphan_verbs(sheet):
		entries.append(orphan)
	for finding: Variant in flagged:
		if not (finding is Dictionary):
			continue
		var flagged_resource: Resource = instance_from_id(int(str((finding as Dictionary).get("uid", "0")))) as Resource
		entries.append({
			"kind": "flagged",
			"label": str((finding as Dictionary).get("message", "")),
			"detail": str((finding as Dictionary).get("suggestion", "")),
			"resource": flagged_resource,
		})
	return entries


static func _walk(rows: Array, counter: Dictionary, entries: Array) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			if not group.enabled:
				entries.append(_entry("disabled", "Group \"%s\" is turned off" % _group_label(group), "nothing inside it runs", group))
			_walk(group.events if not group.events.is_empty() else group.rows, counter, entries)
		elif row is CommentRow:
			var comment: CommentRow = row as CommentRow
			var marker: String = _marker_in(comment.text)
			# A WARNING-styled comment is deliberately NOT listed: the style is a presentation
			# device for a standing note ("this runs every frame"), permanent documentation rather
			# than unfinished work, and it could never be cleared off this index.
			if comment.style == CommentRow.CommentStyle.TODO or not marker.is_empty():
				entries.append(_entry("todo", _first_line(comment.text), _after_event(counter), comment))
			if not comment.enabled:
				entries.append(_entry("disabled", "Comment \"%s\" is turned off" % _first_line(comment.text), _after_event(counter), comment))
		elif row is RawCodeRow:
			var raw: RawCodeRow = row as RawCodeRow
			for line: String in raw.code.split("\n"):
				if not _marker_in(_comment_part(line)).is_empty():
					entries.append(_entry("todo", line.strip_edges(), "in a script block %s" % _after_event(counter), raw))
			if not raw.enabled:
				entries.append(_entry("disabled", "A script block is turned off", _after_event(counter), raw))
		elif row is EventRow:
			var event: EventRow = row as EventRow
			counter["event"] = int(counter["event"]) + 1
			var here: String = "event %d" % int(counter["event"])
			if not _marker_in(event.comment).is_empty():
				entries.append(_entry("todo", event.comment.strip_edges(), here, event))
			if not event.enabled:
				entries.append(_entry("disabled", "%s is turned off" % here.capitalize(), _event_label(event), event))
			if event.debug_break:
				entries.append(_entry("breakpoint", "%s breaks into the debugger" % here.capitalize(), _event_label(event), event))
			if event.actions.is_empty() and event.sub_events.is_empty() \
					and (not event.trigger_id.is_empty() or not event.conditions.is_empty()):
				entries.append(_entry("unfinished", "%s has conditions and no actions" % here.capitalize(), _event_label(event), event))
			for action: Variant in event.actions:
				if action is ACEAction and not (action as ACEAction).enabled:
					entries.append(_entry("disabled", "An action of %s is turned off" % here, (action as ACEAction).ace_id, action as Resource))
			for condition: Variant in event.conditions:
				if condition is ACECondition and not (condition as ACECondition).enabled:
					entries.append(_entry("disabled", "A condition of %s is turned off" % here, (condition as ACECondition).ace_id, condition as Resource))
			_walk(event.sub_events, counter, entries)


## Published verbs nothing calls: a function exposed as an ACE whose name appears in no Call
## action anywhere in the sheet. The honest reading is "you extracted it and never wired it up",
## which is a loose end - not an error, which is why it is an index entry and not a diagnostic.
static func _orphan_verbs(sheet: EventSheetResource) -> Array:
	var orphans: Array = []
	var found: Dictionary = {"called": {}, "code": ""}
	_collect_calls(sheet.events, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_calls((function_entry as EventFunction).events, found)
	var called: Dictionary = found["called"]
	var code_text: String = str(found["code"])
	for function_entry: Variant in sheet.functions:
		if not (function_entry is EventFunction):
			continue
		var function: EventFunction = function_entry as EventFunction
		var name: String = function.function_name.strip_edges()
		# Hand-written code can call a verb too, so a name that appears anywhere in a code block
		# counts as called. Reporting a verb a GDScript row calls would be a lie the reader would
		# have to check by hand every time.
		if name.is_empty() or called.has(name) or code_text.contains(name):
			continue
		orphans.append(_entry("orphan_verb", "\"%s\" is never called" % name,
			"published function" if function.expose_as_ace else "function", function))
	return orphans


## Fills `found` with {called: {name: true}} from every Call action and {code: String} from every
## GDScript block, so orphan detection sees both the structured calls and the hand-written ones.
static func _collect_calls(rows: Array, found: Dictionary) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			_collect_calls(group.events if not group.events.is_empty() else group.rows, found)
		elif row is EventRow:
			var event: EventRow = row as EventRow
			for action: Variant in event.actions:
				if action is ACEAction:
					var call_name: String = str((action as ACEAction).params.get("function_name", "")).strip_edges()
					if not call_name.is_empty():
						(found["called"] as Dictionary)[call_name] = true
				elif action is RawCodeRow:
					found["code"] = str(found["code"]) + "\n" + (action as RawCodeRow).code
			_collect_calls(event.sub_events, found)
		elif row is RawCodeRow:
			found["code"] = str(found["code"]) + "\n" + (row as RawCodeRow).code


## The first note-to-self marker in `text`, or "". Matched as a WHOLE WORD: a bare substring scan
## indexes "no TODOs left here" as an unfinished thing, and an index that lists things which are not
## loose is one the reader learns to ignore.
static func _marker_in(text: String) -> String:
	for marker: String in MARKERS:
		if RegEx.create_from_string("\\b%s\\b" % marker).search(text) != null:
			return marker
	return ""


## The comment part of a line of GDScript ("" when it has none). Only comments are scanned for
## markers: a literal "XXX" inside a string is data the sheet prints, not a note to self.
static func _comment_part(line: String) -> String:
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if quote.is_empty():
			if character == "#":
				return line.substr(index)
			if character == "\"" or character == "'":
				quote = character
		elif character == "\\":
			index += 1
		elif character == quote:
			quote = ""
		index += 1
	return ""


static func _first_line(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	return lines[0].strip_edges() if lines.size() > 0 else ""


static func _after_event(counter: Dictionary) -> String:
	var seen: int = int(counter.get("event", 0))
	return "before the first event" if seen == 0 else "after event %d" % seen


static func _event_label(event: EventRow) -> String:
	if not event.trigger_id.is_empty():
		return event.trigger_id
	if not event.conditions.is_empty() and event.conditions[0] != null:
		return event.conditions[0].ace_id
	return "no trigger"


static func _group_label(group: EventGroup) -> String:
	var name: String = group.group_name.strip_edges()
	return name if not name.is_empty() else group.name.strip_edges()


static func _entry(kind: String, label: String, detail: String, resource: Resource) -> Dictionary:
	return {"kind": kind, "label": label, "detail": detail, "resource": resource}


## Builds the window + tree without popping it (testable headless); open() pops it up.
func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Loose Ends"
	window.size = Vector2i(520, 480)
	window.min_size = Vector2i(400, 300)
	window.close_requested.connect(func() -> void: window.hide())
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_label = EventSheetPopupUI.hint_label(
		"Everything you left half-done, in one list. Nothing here is drawn on the sheet - click an entry to jump to the row.", 420.0)
	body.add_child(summary_label)
	tree = Tree.new()
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_title(0, "What")
	tree.set_column_title(1, "Where")
	tree.column_titles_visible = true
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 190)
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_on_entry_selected)
	var card: PanelContainer = EventSheetPopupUI.labelled_card("Loose ends", tree)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(card)
	var margined: MarginContainer = EventSheetPopupUI.margined(body)
	margined.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(margined)
	_dock.add_child(window)


func open() -> void:
	build()
	refresh()
	if window.is_inside_tree():
		window.popup_centered()


## Rebuilds the index from the current sheet (popup-free, so tests drive it headlessly).
## Returns the entry count.
func refresh() -> int:
	build()
	var sheet: EventSheetResource = _dock._current_sheet
	var flagged: Array = EventSheetDiagnostics.analyze(sheet, _dock._ace_registry)
	_entries = loose_ends(sheet, flagged)
	tree.clear()
	var root: TreeItem = tree.create_item()
	var heading_font: FontVariation = EventSheetPopupUI.small_caps_font(tree.get_theme_font("font"))
	for kind_entry: Dictionary in KIND_ORDER:
		var kind_id: String = str(kind_entry.get("id"))
		var of_kind: Array = _entries.filter(func(entry: Variant) -> bool:
			return str((entry as Dictionary).get("kind", "")) == kind_id)
		if of_kind.is_empty():
			continue
		var heading: TreeItem = tree.create_item(root)
		heading.set_text(0, "%s (%d)" % [str(kind_entry.get("title")).to_upper(), of_kind.size()])
		heading.set_custom_color(0, EventSheetPopupUI.accent_color())
		heading.set_selectable(0, false)
		heading.set_selectable(1, false)
		if heading_font != null:
			heading.set_custom_font(0, heading_font)
		for entry: Variant in of_kind:
			var item: TreeItem = tree.create_item(heading)
			item.set_text(0, str((entry as Dictionary).get("label", "")))
			item.set_text(1, str((entry as Dictionary).get("detail", "")))
			item.set_metadata(0, (entry as Dictionary).get("resource"))
	summary_label.text = "Nothing left hanging - no TODOs, no disabled rows, no half-written events." if _entries.is_empty() \
		else "%d loose end(s). Nothing here is drawn on the sheet - click an entry to jump to the row." % _entries.size()
	return _entries.size()


func _on_entry_selected() -> void:
	var selected: TreeItem = tree.get_selected()
	if selected == null:
		return
	var target: Resource = selected.get_metadata(0)
	if target == null:
		return
	var view: EventSheetViewport = _dock._active_view()
	if view != null:
		view.reveal_resource(target)
		view.select_resource(target)
