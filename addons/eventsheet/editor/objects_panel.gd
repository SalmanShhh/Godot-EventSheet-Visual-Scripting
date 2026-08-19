@tool
class_name EventSheetObjectsPanel
extends VBoxContainer
# The OBJECT BAR (Q12) - a list you glance at, filter, and drag from.
#
# The first draft of this rail listed everything in one flat run, which turns a forty-node scene into
# thirty-seven grey lines burying the three objects the sheet actually uses. That is a scene tree, not
# an object bar. So the bar is three sections in the order a reader wants them:
#
#   USED IN THIS SHEET   open, with per-object counts, behaviors nested under the object they ride on
#   ALSO IN THE SCENE    collapsed, the rest of the scene, no counts because there are none
#   GLOBALS & FAMILIES   collapsed
#
# plus a filter box, and five gestures: HOVER previews an object's rows, CLICK pins that highlight,
# DOUBLE-CLICK opens Object properties, DRAG onto the sheet starts an event on the object, and
# RIGHT-CLICK offers Add condition / Add action / Select in scene / Open its script as a sheet.
#
# Every entry is DERIVED - the census for what the sheet uses, the .tscn for what else is in the
# scene - so there is no stored list to fall out of date. The panel is shell and gestures only: it
# emits what happened and the dock decides what that MEANS, which is what keeps one notion of "the
# sheet is filtered" in one place.

## An entry was clicked. The dock pins (or clears) that object's highlight.
signal object_activated(object_label: String)

## An entry was hovered. The dock previews that object's rows; "" means the pointer left the bar.
signal object_previewed(object_label: String)

## An entry was double-clicked: Object properties (what it is, what this sheet does with it).
signal object_properties_requested(object_label: String)

## Right-click > Add condition / Add action, already scoped to the object.
signal object_row_requested(object_label: String, as_action: bool)

## Right-click > Select in scene.
signal object_scene_selection_requested(object_label: String)

## Right-click > Open its script as a sheet.
signal object_script_requested(object_label: String)

const _META_KEY: String = "eventsheets_objects_panel"

## The drag payload a bar entry hands the canvas. Named so the viewport can recognise it without
## knowing anything about this panel.
const DRAG_TYPE: String = "eventsheet_object"

## The sort orders the header's ⇅ cycles through. Reading order (first appearance in the sheet) is
## the default because it is the order the reader just read.
const SORT_ORDERS: PackedStringArray = ["reading", "count", "name"]

var tree: Tree = null
var filter_edit: LineEdit = null

var _header_button: Button = null
var _sort_button: Button = null
var _entries: Array = []
var _scene_only: Array = []
var _expanded: bool = false
var _highlighted: String = ""
var _filter: String = ""
var _sort: String = "reading"
var _sheet: EventSheetResource = null
var _source_path: String = ""
var _scene_name: String = ""
var _section_folds: Dictionary = {"used": false, "scene": true, "globals": true}
var _menu: PopupMenu = null
var _menu_label: String = ""


func _init() -> void:
	name = "Objects"
	custom_minimum_size = Vector2(EventSheetPalette.scaled_f(180.0), 0.0)
	_header_button = Button.new()
	_header_button.flat = true
	_header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_button.tooltip_text = EventSheetL10n.translate(
		"Every object this file uses. Click one to highlight its rows, click it again to clear.")
	_header_button.pressed.connect(func() -> void: set_expanded(not _expanded))
	var header_row := HBoxContainer.new()
	header_row.add_child(_header_button)
	_sort_button = Button.new()
	_sort_button.flat = true
	_sort_button.text = "⇅"
	_sort_button.tooltip_text = EventSheetL10n.translate("Sort by reading order, by count or by name.")
	_sort_button.pressed.connect(_cycle_sort)
	header_row.add_child(_sort_button)
	add_child(header_row)
	filter_edit = LineEdit.new()
	filter_edit.name = "EventSheetObjectsFilter"
	filter_edit.placeholder_text = EventSheetL10n.translate("filter objects...")
	filter_edit.clear_button_enabled = true
	filter_edit.text_changed.connect(_on_filter_changed)
	filter_edit.text_submitted.connect(_on_filter_submitted)
	add_child(filter_edit)
	tree = Tree.new()
	tree.name = "EventSheetObjectsTree"
	tree.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(110.0))
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, int(EventSheetPalette.scaled_f(58.0)))
	tree.allow_reselect = true
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_activated)
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	tree.gui_input.connect(_on_tree_gui_input)
	tree.mouse_exited.connect(func() -> void: object_previewed.emit(""))
	# The bar hands the canvas a payload and forgets about it; the canvas decides what dropping an
	# object THERE means (a new event, or an action on the row it landed on).
	tree.set_drag_forwarding(_drag_payload_for, Callable(), Callable())
	add_child(tree)
	var prefs: Dictionary = _read_prefs()
	_sort = str(prefs.get("sort", "reading"))
	if not Array(SORT_ORDERS).has(_sort):
		_sort = "reading"
	set_expanded(bool(prefs.get("expanded", false)))


## Expanding gives the list rail space (it competes with Open Sheets / Functions / Anatomy);
## collapsing shrinks the panel back to its one-line header.
func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	tree.visible = expanded
	filter_edit.visible = expanded
	_sort_button.visible = expanded
	size_flags_vertical = Control.SIZE_EXPAND_FILL if expanded else Control.SIZE_SHRINK_BEGIN
	_refresh_header()
	_save_prefs()


func is_expanded() -> bool:
	return _expanded


## Which object's rows are currently highlighted, or "" when none are.
func highlighted_object() -> String:
	return _highlighted


## Rebuilds the bar from a sheet. Safe to call on every sheet change - both halves are reads (the
## census of the sheet's own rows, and the .tscn as text), and nothing here is cached across sheets.
func set_sheet(sheet: EventSheetResource) -> void:
	_sheet = sheet
	_source_path = str(sheet.get("external_source_path")).strip_edges() if sheet != null else ""
	_entries = EventSheetViewportReadingRows.object_census(sheet)
	var scene: Dictionary = ViewportRowBuilder.scene_using_script(_source_path) if not _source_path.is_empty() else {}
	_scene_name = str(scene.get("scene_path", "")).get_file()
	_scene_only = scene_only_entries(_entries, str(scene.get("scene_path", "")))
	_rebuild_tree()
	_refresh_header()


## The census this bar is showing, so the dock (and a test) can read exactly what it lists without
## walking a Tree.
func entries() -> Array:
	return _entries.duplicate(true)


## The "also in the scene" half, same reason.
func scene_entries() -> Array:
	return _scene_only.duplicate(true)


# ── What goes in which section (pure, so tests pin it) ─────────────────────────────────────────


## The bar's three sections for one census + scene, as
##   [{"id", "title", "note", "entries": Array}]
## in the order they are drawn. Sections with nothing in them are still returned (the header says so);
## the tree simply does not build an empty one.
static func sections_for(census: Array, scene_only: Array, scene_name: String) -> Array:
	var used: Array = []
	var globals: Array = []
	for entry: Variant in census:
		var record: Dictionary = entry
		if str(record.get("kind", "")) in ["autoload", "group"]:
			globals.append(record)
		else:
			used.append(record)
	return [
		{"id": "used", "title": EventSheetL10n.translate("USED IN THIS SHEET"), "note": "", "entries": used},
		{
			"id": "scene",
			"title": EventSheetL10n.translate("ALSO IN THE SCENE"),
			"note": EventSheetL10n.translate("drag one onto the sheet to use it") if not scene_name.is_empty() else "",
			"entries": scene_only
		},
		{"id": "globals", "title": EventSheetL10n.translate("GLOBALS & FAMILIES"), "note": "", "entries": globals}
	]


## What the SCENE has that the sheet does not use yet: at most the direct children of the root plus
## anything carrying a script, so the section stays a bar and never becomes a second Scene dock.
static func scene_only_entries(census: Array, scene_path: String) -> Array:
	if scene_path.strip_edges().is_empty():
		return []
	var known: Dictionary = {}
	for entry: Variant in census:
		known[str((entry as Dictionary).get("label", ""))] = true
	var found: Array = []
	var facts: Dictionary = EventSheetObjectFacts.scene_facts(scene_path)
	for child_entry: Variant in facts.get("children", []):
		var child: Dictionary = child_entry
		var child_name: String = str(child.get("name", ""))
		var parent: String = str(child.get("parent", ""))
		var direct: bool = parent == "." or parent.is_empty()
		if known.has(child_name) or child_name.is_empty():
			continue
		if not direct and str(child.get("script", "")).is_empty():
			continue
		known[child_name] = true
		found.append({
			"label": child_name, "kind": "node", "class": str(child.get("type", "")),
			"path": "", "rows": 0, "verbs": PackedStringArray(), "signals": PackedStringArray()
		})
	return found


## The census entries this sheet uses that the scene does NOT have - a `$Enemies/Boss` that is not
## there. Flagged at the top of USED, because a name that resolves to nothing at runtime is the one
## thing in the bar a reader must not scroll past.
static func missing_labels(census: Array, scene_path: String) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	if scene_path.strip_edges().is_empty():
		return missing
	var facts: Dictionary = EventSheetObjectFacts.scene_facts(scene_path)
	if facts.is_empty():
		return missing
	var present: Dictionary = {str(facts.get("root", "")): true}
	for child_entry: Variant in facts.get("children", []):
		present[str((child_entry as Dictionary).get("name", ""))] = true
	for behavior_entry: Variant in facts.get("behaviors", []):
		present[str((behavior_entry as Dictionary).get("node", ""))] = true
	for entry: Variant in census:
		var record: Dictionary = entry
		if str(record.get("kind", "")) != "node":
			continue
		var label: String = str(record.get("label", ""))
		if not present.has(label):
			missing.append(label)
	return missing


## One entry's line: the object's name, then its muted note - what kind of thing it is, the class or
## path it resolves to, and how many rows use it.
static func entry_text(entry: Dictionary) -> String:
	var note: String = EventSheetViewportReadingRows.object_note(entry)
	var label: String = str(entry.get("label", ""))
	return label if note.is_empty() else "%s  %s" % [label, note]


## The hover: the verbs this file uses the object with, so the bar answers "and what does it DO with
## it" without a click. Falls back to the entry's own line when the file only names it.
static func entry_tooltip(entry: Dictionary) -> String:
	var verbs: PackedStringArray = entry.get("verbs", PackedStringArray())
	if verbs.is_empty():
		return entry_text(entry)
	return " · ".join(verbs)


## The count cell's hover: what those rows ARE. `2 conditions · 3 actions · 1 trigger`.
static func count_tooltip(split: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var counted: Array = [
		["conditions", "1 condition", "%d conditions"],
		["actions", "1 action", "%d actions"],
		["triggers", "1 trigger", "%d triggers"]
	]
	for item: Variant in counted:
		var row: Array = item
		var value: int = int(split.get(str(row[0]), 0))
		if value <= 0:
			continue
		parts.append(EventSheetL10n.translate(str(row[1])) if value == 1
			else EventSheetL10n.translate(str(row[2])) % value)
	return " · ".join(parts)


## The words the empty bar says. A script with no scene cannot have objects yet, and saying WHY plus
## what to do about it is worth more than an empty list.
static func empty_state_text(has_scene: bool) -> String:
	if has_scene:
		return EventSheetL10n.translate("Nothing in this sheet names an object yet.")
	return EventSheetL10n.translate(
		"This script is not on a scene yet - drop it on a node in the Scene dock and its objects appear here.")


## The sorted order one section's entries are drawn in.
static func sorted_entries(section_entries: Array, order: String) -> Array:
	var sorted: Array = section_entries.duplicate()
	if order == "count":
		sorted.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			if int(left.get("rows", 0)) != int(right.get("rows", 0)):
				return int(left.get("rows", 0)) > int(right.get("rows", 0))
			return str(left.get("label", "")) < str(right.get("label", "")))
	elif order == "name":
		sorted.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("label", "")) < str(right.get("label", "")))
	return sorted


## True when an entry survives the filter box. Matched on the name AND on the note, so typing a class
## finds every object of it.
static func matches_filter(entry: Dictionary, filter_text: String) -> bool:
	var needle: String = filter_text.strip_edges().to_lower()
	if needle.is_empty():
		return true
	return entry_text(entry).to_lower().contains(needle)


# ── The tree ──────────────────────────────────────────────────────────────────────────────────


func _rebuild_tree() -> void:
	tree.clear()
	var root: TreeItem = tree.create_item()
	var scene_path: String = ViewportRowBuilder.scene_using_script(_source_path).get("scene_path", "") \
		if not _source_path.is_empty() else ""
	var missing: PackedStringArray = missing_labels(_entries, str(scene_path))
	var shown: int = 0
	for section_entry: Variant in sections_for(_entries, _scene_only, _scene_name):
		var section: Dictionary = section_entry
		var visible_entries: Array = []
		for entry: Variant in sorted_entries(section.get("entries", []), _sort):
			if matches_filter(entry as Dictionary, _filter):
				visible_entries.append(entry)
		if visible_entries.is_empty():
			continue
		var section_item: TreeItem = tree.create_item(root)
		section_item.set_text(0, "%s%s" % [
			str(section.get("title", "")),
			"  (%d)" % visible_entries.size() if str(section.get("id", "")) != "used" else ""
		])
		var note: String = str(section.get("note", ""))
		if not note.is_empty():
			section_item.set_text(1, "")
			section_item.set_tooltip_text(0, note)
		section_item.set_selectable(0, false)
		section_item.set_selectable(1, false)
		section_item.set_custom_color(0, EventSheetPalette.TEXT_MUTED)
		section_item.set_metadata(0, {"section": str(section.get("id", ""))})
		# A filter that is typing must not fight the folds: any section with a match opens while the
		# box has text, and goes back to its remembered state when it is cleared.
		section_item.collapsed = bool(_section_folds.get(str(section.get("id", "")), false)) \
			and _filter.strip_edges().is_empty()
		var by_label: Dictionary = {}
		for entry: Variant in visible_entries:
			var record: Dictionary = entry
			var label: String = str(record.get("label", ""))
			var parent_item: TreeItem = section_item
			var owner_label: String = _owner_label_of(record)
			if by_label.has(owner_label):
				parent_item = by_label[owner_label]
			by_label[label] = _add_entry_item(parent_item, record, Array(missing).has(label))
			shown += 1
	if shown == 0:
		var empty_item: TreeItem = tree.create_item(root)
		empty_item.set_text(0, empty_state_text(not _scene_name.is_empty()))
		empty_item.set_selectable(0, false)
		empty_item.set_custom_color(0, EventSheetPalette.TEXT_MUTED)
		empty_item.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)


## Which object an entry sits UNDER, so the bar reads like the object dialog: a behavior belongs to
## the object it is mounted on, everything else stands on its own.
func _owner_label_of(entry: Dictionary) -> String:
	if str(entry.get("kind", "")) != "behaviour":
		return ""
	return EventSheetViewportReadingRows.script_object_name(_sheet)


func _add_entry_item(parent_item: TreeItem, entry: Dictionary, is_missing: bool) -> TreeItem:
	var item: TreeItem = tree.create_item(parent_item)
	var label: String = str(entry.get("label", ""))
	item.set_text(0, ("⚠ %s" % entry_text(entry)) if is_missing else entry_text(entry))
	item.set_tooltip_text(0, (EventSheetL10n.translate("not in %s") % _scene_name) if is_missing
		else entry_tooltip(entry))
	var icon: Texture2D = EventSheetViewportReadingRows.object_icon(
		entry, EventSheetViewportReadingRows.object_class_map(_sheet), _source_path)
	if icon != null:
		item.set_icon(0, icon)
	var rows: int = int(entry.get("rows", 0))
	if rows > 0:
		item.set_text(1, str(rows))
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_custom_color(1, EventSheetPalette.TEXT_MUTED)
		item.set_tooltip_text(1, count_tooltip(
			EventSheetViewportReadingRows.object_usage_split(_sheet, label)))
	item.set_metadata(0, {"label": label})
	return item


## Clicking an entry pins that object's rows; clicking the SAME one again clears, which is why the
## selection is dropped on the second click - a bar row that stays lit while nothing is filtered
## would be a lie about the state of the sheet.
func _on_item_selected() -> void:
	var label: String = _selected_label()
	if label.is_empty():
		return
	_highlighted = "" if _highlighted == label else label
	if _highlighted.is_empty():
		tree.deselect_all()
	object_activated.emit(label)


func _on_item_activated() -> void:
	var label: String = _selected_label()
	if not label.is_empty():
		object_properties_requested.emit(label)


func _on_item_mouse_selected(_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	var label: String = _selected_label()
	if label.is_empty():
		return
	_menu_label = label
	_ensure_menu()
	_menu.reset_size()
	_menu.popup(Rect2i(Vector2i(get_screen_transform() * get_local_mouse_position()), Vector2i.ZERO))


func _on_tree_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var hovered: TreeItem = tree.get_item_at_position((event as InputEventMouseMotion).position)
	var metadata: Variant = hovered.get_metadata(0) if hovered != null else null
	# Hover PREVIEWS, click pins: the sheet glows while the pointer rests and forgets the moment it
	# leaves, so a reader can sweep the bar without committing to anything.
	object_previewed.emit(str((metadata as Dictionary).get("label", "")) if metadata is Dictionary else "")


func _selected_label() -> String:
	var selected: TreeItem = tree.get_selected()
	if selected == null or not (selected.get_metadata(0) is Dictionary):
		return ""
	return str((selected.get_metadata(0) as Dictionary).get("label", ""))


## The payload a dragged entry hands the canvas: the object's name and nothing else, because the
## canvas decides what dropping it THERE means.
func _drag_payload_for(_at_position: Vector2) -> Variant:
	var label: String = _selected_label()
	if label.is_empty():
		return null
	var preview := Label.new()
	preview.text = label
	tree.set_drag_preview(preview)
	return {"type": DRAG_TYPE, "label": label}


func _ensure_menu() -> void:
	if _menu != null:
		return
	_menu = PopupMenu.new()
	_menu.add_item(EventSheetL10n.translate("Add condition"), 0)
	_menu.add_item(EventSheetL10n.translate("Add action"), 1)
	_menu.add_separator()
	_menu.add_item(EventSheetL10n.translate("Select in scene"), 2)
	_menu.add_item(EventSheetL10n.translate("Open its script as a sheet"), 3)
	_menu.id_pressed.connect(_on_menu_id)
	add_child(_menu)


func _on_menu_id(id: int) -> void:
	match id:
		0:
			object_row_requested.emit(_menu_label, false)
		1:
			object_row_requested.emit(_menu_label, true)
		2:
			object_scene_selection_requested.emit(_menu_label)
		3:
			object_script_requested.emit(_menu_label)


func _on_filter_changed(text: String) -> void:
	_filter = text
	_rebuild_tree()


## Enter on a SINGLE match pins it - the type-and-go path, which is what a filter box in a bar is for.
func _on_filter_submitted(_text: String) -> void:
	var matched: PackedStringArray = PackedStringArray()
	for entry: Variant in _entries:
		if matches_filter(entry as Dictionary, _filter):
			matched.append(str((entry as Dictionary).get("label", "")))
	if matched.size() != 1:
		return
	_highlighted = matched[0]
	object_activated.emit(matched[0])


func _cycle_sort() -> void:
	var index: int = Array(SORT_ORDERS).find(_sort)
	_sort = SORT_ORDERS[(index + 1) % SORT_ORDERS.size()]
	_save_prefs()
	_rebuild_tree()
	_refresh_header()


func _refresh_header() -> void:
	var used: int = 0
	for entry: Variant in _entries:
		if str((entry as Dictionary).get("kind", "")) not in ["autoload", "group"]:
			used += 1
	var counts: String = "%s · %s" % [
		EventSheetL10n.translate("%d used") % used,
		EventSheetL10n.translate("%d more") % _scene_only.size()
	]
	var scene_note: String = "  %s" % _scene_name if not _scene_name.is_empty() else ""
	_header_button.text = "%s %s%s · %s" % [
		"▾" if _expanded else "▸", EventSheetL10n.translate("Objects"), scene_note, counts
	]


func _read_prefs() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var meta: Variant = EditorInterface.get_editor_settings().get_project_metadata("eventsheets", _META_KEY, {})
		if meta is Dictionary:
			return meta
	return {}


func _save_prefs() -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata(
			"eventsheets", _META_KEY, {"expanded": _expanded, "sort": _sort})
