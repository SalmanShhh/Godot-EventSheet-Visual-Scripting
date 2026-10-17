# Godot EventSheets - the Outline panel (dock subsystem)
#
# The script editor's method-list, for sheets: a slim jump tree of the STRUCTURAL rows -
# groups (nested), region fences, and published functions - so a ballooning sheet
# navigates by the names you remember, not by scrolling. Clicking an entry reveals +
# selects the row, and the strip under the list says what the picked entry is and the line it is
# in code; Go to Row jumps there and closes the window. The entry walk is static and pure, so tests
# pin it headless.
@tool
class_name EventSheetOutlinePanel
extends RefCounted

## How each kind of entry reads: [the mark in front of its words, its colour, the editor icon it
## wears]. Groups and the "To do" folder wear the FileSystem dock's folder, a note the editor's info
## mark; a region and a function keep the "#" and "ƒ" their code is written with. The colour is
## darkened on a light panel (readable_on_panel). An icon is asked
## of the editor theme, so a run with no editor (the suite) shows the words alone.
const KINDS := {
	"group": ["", Color("#e0b070"), "Folder"],
	"region": ["# ", Color("#7fb3d5"), ""],
	"function": ["ƒ ", Color("#c79bf0"), ""],
	"todo_folder": ["", Color("#8b91a3"), "Folder"],
	"todo": ["", Color("#8b91a3"), "NodeInfo"],
}

var _dock: Control = null

var window: Window = null
var tree: Tree = null
## Narrows a long outline to the entries whose words hold what is typed, like the script editor's
## method filter; an entry that stays keeps the folders above it.
var filter_edit: LineEdit = null
var _empty_hint: Label = null
## The strip under the list: what the picked entry is (THIS ROW) and its line in code (IN CODE).
var strip: EventSheetPopupUI.HelpStrip = null
var _this_row: Label = null


func _init(dock: Control) -> void:
	_dock = dock


## The structural walk: groups (with nesting), region openers, then the sheet's published
## functions. Returns [{label, resource, depth, kind, parent}] in sheet order, where
## `parent` is the INDEX of the enclosing group's entry (-1 = top level) - explicit
## parentage, so the tree rebuild can never mis-nest an entry whose depth came from
## descending through an EventRow's sub_events rather than a group. Pure, so tests pin it.
static func outline_entries(sheet: EventSheetResource) -> Array:
	var entries: Array = []
	if sheet == null:
		return entries
	_collect_outline(sheet.events, 0, -1, entries)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			entries.append({
				"label": (function_entry as EventFunction).function_name,
				"resource": function_entry,
				"depth": 0,
				"kind": "function",
				"parent": -1
			})
	_append_task_notes(sheet, entries)
	return entries


## The sheet's own TODO / FIXME / HACK / NOTE comments, under one "To do" folder at the end.
##
## A note about work still to do is a place in the sheet somebody means to come back to, which is
## exactly what this panel is for. Last, so the structural walk above it never moves; the folder
## itself is only added when there is something in it.
static func _append_task_notes(sheet: EventSheetResource, entries: Array) -> void:
	var notes: Array = []
	_collect_task_notes(sheet.events, notes)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry
			_collect_task_notes(event_function.events if not event_function.events.is_empty() else event_function.rows, notes)
	if notes.is_empty():
		return
	entries.append({"label": "To do", "resource": null, "depth": 0, "kind": "todo_folder", "parent": -1})
	var folder_index: int = entries.size() - 1
	for note: Dictionary in notes:
		entries.append({
			"label": str(note.get("label", "")),
			"resource": note.get("resource", null),
			"depth": 1,
			"kind": "todo",
			"parent": folder_index
		})


## Every comment row in a walk whose text opens with a task marker, as {label, resource}. Comment
## rows are the only thing looked at: a note lives in a comment, in the sheet as in the file.
static func _collect_task_notes(rows: Array, notes: Array) -> void:
	for entry: Variant in rows:
		if entry is CommentRow:
			var comment: CommentRow = entry
			for line: String in comment.text.split("\n"):
				if not EventSheetSentence.task_note_marker(line).is_empty():
					notes.append({"label": line.strip_edges().trim_prefix("#").strip_edges(), "resource": comment})
		elif entry is EventGroup:
			var group: EventGroup = entry
			_collect_task_notes(group.events if not group.events.is_empty() else group.rows, notes)
		elif entry is EventRow:
			var event: EventRow = entry
			_collect_task_notes(event.actions, notes)
			_collect_task_notes(event.sub_events, notes)


static func _collect_outline(rows: Array, depth: int, parent_index: int, entries: Array) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			entries.append({"label": group.group_name, "resource": group, "depth": depth, "kind": "group", "parent": parent_index})
			_collect_outline(group.events if not group.events.is_empty() else group.rows, depth + 1, entries.size() - 1, entries)
		elif entry is CustomBlockRow:
			var block: CustomBlockRow = entry as CustomBlockRow
			if block.kind_id == "region" and not bool(block.fields.get("is_end", false)):
				var label: String = str(block.fields.get("label", "")).strip_edges()
				entries.append({"label": label if not label.is_empty() else "(region)", "resource": block, "depth": depth, "kind": "region", "parent": parent_index})
		elif entry is EventRow:
			# Sub-events may hold nested regions/groups: they nest under the SAME outline
			# parent (an event is not an outline node), whatever the visual depth.
			_collect_outline((entry as EventRow).sub_events, depth + 1, parent_index, entries)


## Builds the window + tree without popping it (testable headless); open() pops it up.
func build() -> void:
	if window != null:
		return
	var parts: Dictionary = EventSheetPopupUI.action_window(EventSheetL10n.translate("Outline"),
		EventSheetL10n.translate("Go to Row"), EventSheetL10n.translate("Close"), Vector2i(380, 460), _dock)
	window = parts["window"]
	window.confirmed.connect(go_to_row)
	var body_box: VBoxContainer = parts["box"]
	filter_edit = LineEdit.new()
	filter_edit.placeholder_text = EventSheetL10n.translate("Filter")
	filter_edit.clear_button_enabled = true
	filter_edit.right_icon = EventSheetEditorIcons.icon("Search")
	filter_edit.text_changed.connect(func(_text: String) -> void: refresh())
	body_box.add_child(filter_edit)
	tree = EventSheetPopupUI.table(PackedStringArray(), 240.0)
	tree.select_mode = Tree.SELECT_ROW
	tree.item_selected.connect(_on_entry_selected)
	tree.item_activated.connect(go_to_row)
	var results: Dictionary = EventSheetPopupUI.add_results(body_box, EventSheetL10n.translate("Outline"), tree)
	strip = results["strip"]
	_this_row = results["this_row"]
	_empty_hint = EventSheetPopupUI.hint_label(EventSheetL10n.translate("Nothing structural yet - groups, #region fences, and published functions appear here as you add them."), 320.0)
	body_box.add_child(_empty_hint)


func open() -> void:
	build()
	refresh()
	window.popup_centered()


## Rebuilds the jump tree from the current sheet (popup-free; testable headless).
func refresh() -> void:
	if tree == null:
		return
	tree.clear()
	var root: TreeItem = tree.create_item()
	# The Outline follows the arrangement - when the sheet is read by object / trigger / group,
	# so is its jump tree.
	window.title = EventSheetL10n.translate("Outline of %s") % _sheet_file()
	if strip != null:
		strip.visible = false
	var view: EventSheetViewport = _dock._active_view()
	var entries: Array = outline_entries(_dock._current_sheet)
	if view != null and view.arrangement_mode != EventSheetArrangement.MODE_FILE_ORDER:
		entries = arranged_entries(_dock._current_sheet, view.get_row_tree(), view.arrangement_mode)
	# Explicit parentage: each entry names its enclosing group's entry INDEX, so the tree
	# mirrors the walk exactly (a depth-keyed map mis-nested entries reached through an
	# EventRow's sub_events under whatever group happened to set that depth earlier).
	var items: Array = []
	var shown: Array[bool] = filter_matches(entries, filter_edit.text if filter_edit != null else "")
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var parent_index: int = int(entry.get("parent", -1))
		var parent: TreeItem = items[parent_index] if parent_index >= 0 and parent_index < items.size() else root
		var item: TreeItem = tree.create_item(parent)
		var look: Array = KINDS.get(str(entry.get("kind", "")), ["", Color.WHITE, ""])
		item.set_text(0, str(look[0]) + str(entry.get("label", "")))
		item.set_custom_color(0, EventSheetPopupUI.readable_on_panel(look[1]))
		var icon: Texture2D = EventSheetEditorIcons.icon(str(look[2])) if not str(look[2]).is_empty() else null
		if icon != null:
			item.set_icon(0, icon)
		item.set_metadata(0, entry.get("resource", null))
		item.set_meta("entry", entry)
		item.visible = shown[index]
		items.append(item)
	if _empty_hint != null:
		_empty_hint.visible = entries.is_empty()


## Which entries a filter keeps, one bool per entry: those whose words hold `filter` (any case),
## plus every folder above one of them, so a kept entry still reads where it lives. An empty filter
## keeps everything. Parents always come before their children, so one pass backwards lifts them.
static func filter_matches(entries: Array, filter: String) -> Array[bool]:
	var wanted: String = filter.strip_edges()
	var shown: Array[bool] = []
	for entry: Variant in entries:
		shown.append(wanted.is_empty() or str((entry as Dictionary).get("label", "")).containsn(wanted))
	for index: int in range(entries.size() - 1, -1, -1):
		var parent_index: int = int((entries[index] as Dictionary).get("parent", -1))
		if shown[index] and parent_index >= 0:
			shown[parent_index] = true
	return shown


## The sheet's file as its tab names it, or "this sheet" before it has one.
func _sheet_file() -> String:
	var path: String = str(_dock.get("_current_sheet_path")) if "_current_sheet_path" in _dock else ""
	return path.get_file() if not path.is_empty() else EventSheetL10n.translate("this sheet")


## A click reveals and selects the entry's row (the window stays open, so the next click can go on
## looking) and the strip says what the entry is and its line in code.
func _on_entry_selected() -> void:
	var selected: TreeItem = tree.get_selected()
	if selected == null:
		return
	var entry: Dictionary = selected.get_meta("entry", {})
	if strip != null:
		strip.set_line(_this_row, entry_sentence(entry))
		strip.set_reading("", entry_code(entry))
		strip.visible = true
	_reveal(selected.get_metadata(0))


## Go to Row (or a double-click): the picked entry's row, revealed and selected, and the window out
## of the way so the row can be read.
func go_to_row() -> void:
	var selected: TreeItem = tree.get_selected() if tree != null else null
	if selected == null or selected.get_metadata(0) == null:
		return
	_reveal(selected.get_metadata(0))
	window.hide()


## The pane the outline was built from (refresh reads the active view's arrangement), so in split
## view the jump lands where the reader is looking, not always in the left pane.
func _reveal(target: Variant) -> void:
	var view: EventSheetViewport = _dock._active_view()
	if target is Resource and view != null:
		view.reveal_resource(target as Resource)
		view.select_resource(target as Resource)


## What a picked entry is, in one sentence for the strip's THIS ROW line. Pure, so tests pin it.
static func entry_sentence(entry: Dictionary) -> String:
	var label: String = str(entry.get("label", ""))
	match str(entry.get("kind", "")):
		"group":
			return EventSheetL10n.translate("%s: a group. Click reveals and selects it.") % label
		"region":
			return EventSheetL10n.translate("%s: a #region fence. Click reveals and selects it.") % label
		"function":
			return EventSheetL10n.translate("%s: a function of this sheet. Click reveals and selects it.") % label
		"todo_folder":
			return EventSheetL10n.translate("Every TODO, FIXME, HACK and NOTE comment in this sheet.")
		"todo":
			return EventSheetL10n.translate("%s: a note left in a comment. Click reveals and selects it.") % label
		"event":
			return EventSheetL10n.translate("%s: an event. Click reveals and selects it.") % label
	return ""


## The line a picked entry is in code, where the entry carries it whole: a region's fence and a
## note's comment. A group or a function is a block of lines, so it has no one line to show.
static func entry_code(entry: Dictionary) -> String:
	match str(entry.get("kind", "")):
		"region":
			return "#region %s" % str(entry.get("label", ""))
		"todo":
			return "# %s" % str(entry.get("label", ""))
	return ""


## The Outline under an arrangement. When the sheet is being read Arranged By something, the
## jump tree IS that arrangement: one entry per header, its events beneath it, each still jumping to
## the event it stands for. `rows` are the view's built root rows and `mode` an EventSheetArrangement
## mode; file order (or nothing to arrange) falls back to the structural walk. Pure, so tests pin it.
static func arranged_entries(sheet: EventSheetResource, rows: Array, mode: int) -> Array:
	if sheet == null or mode == EventSheetArrangement.MODE_FILE_ORDER:
		return outline_entries(sheet)
	var self_object: String = EventSheetArrangement.self_object_of(sheet)
	var planned: Array = EventSheetArrangement.plan(rows, mode, self_object)
	if planned.is_empty():
		return outline_entries(sheet)
	var entries: Array = []
	for bucket: Variant in planned:
		var header: Dictionary = bucket
		var header_index: int = entries.size()
		entries.append({
			"label": str(header.get("header", "")),
			"resource": null,
			"depth": 0,
			"kind": "group",
			"parent": -1,
		})
		for member: Variant in (header.get("rows", []) as Array):
			var row_data: EventRowData = member as EventRowData
			if row_data == null or not (row_data.source_resource is EventRow):
				continue
			entries.append({
				"label": EventSheetArrangement.event_label(
					{"event": row_data.source_resource as EventRow}, mode, self_object),
				"resource": row_data.source_resource,
				"depth": 1,
				"kind": "event",
				"parent": header_index,
			})
	return entries
