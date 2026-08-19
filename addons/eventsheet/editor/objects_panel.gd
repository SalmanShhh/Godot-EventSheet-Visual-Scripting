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

## R23 - the INPUT section's own payload. An Input Map action is not an object, and dropping one on
## the sheet means one specific thing (start an "On <action> pressed" event), so it travels under its
## own name rather than pretending to be an object drop.
const DRAG_TYPE_INPUT_ACTION: String = "eventsheet_input_action"

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
var _input_actions: Array = []
var _section_folds: Dictionary = {"used": false, "scene": true, "input": false, "globals": true}
var _menu: PopupMenu = null
var _menu_label: String = ""
var _class_map: Dictionary = {}


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
	# Without this a right-click selects nothing, and the context menu would open on whatever was
	# selected last rather than on the entry under the pointer.
	tree.allow_rmb_select = true
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_activated)
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	tree.gui_input.connect(_on_tree_gui_input)
	tree.item_collapsed.connect(_on_section_collapsed)
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
	_entries = _with_autoload_identity(EventSheetViewportReadingRows.object_census(sheet), sheet)
	var scene: Dictionary = ViewportRowBuilder.scene_using_script(_source_path) if not _source_path.is_empty() else {}
	_scene_name = str(scene.get("scene_path", "")).get_file()
	_scene_only = scene_only_entries(_entries, str(scene.get("scene_path", "")))
	EventSheetInputMapFacts.clear_cache()
	_input_actions = EventSheetInputMapFacts.actions_named_by(sheet)
	_rebuild_tree()
	_refresh_header()


## P10 - when the OPEN FILE is itself a project autoload, the rail says so about it: the file's own
## entry reads under the singleton's name, wears the globe, and says "autoload (global)" - the same
## words its Include bar uses, and the same words every other sheet's `Game (global) ▸ …` rows use
## for it, so a reader following one of those rows here recognises what they landed on.
##
## The census is left alone: it answers "what does this file USE", and what this file IS belongs to
## the head. So the identity is re-read here, on the derived list, and nothing downstream of the
## census changes.
func _with_autoload_identity(entries: Array, sheet: EventSheetResource) -> Array:
	if sheet == null or not sheet.autoload_mode or sheet.autoload_name.strip_edges().is_empty():
		return entries
	for entry: Variant in entries:
		if not (entry is Dictionary) or str((entry as Dictionary).get("kind", "")) != "script":
			continue
		(entry as Dictionary)["label"] = sheet.autoload_name.strip_edges()
		(entry as Dictionary)["kind"] = "autoload"
		(entry as Dictionary)["path"] = str(sheet.external_source_path)
		return entries
	# A global whose script declares no class of its own is named by nothing the census could see, so
	# its entry has to be added rather than amended - the rail must never be silent about the very
	# file it is describing.
	entries.insert(0, {
		"label": sheet.autoload_name.strip_edges(), "kind": "autoload", "class": "",
		"path": str(sheet.external_source_path), "match": sheet.autoload_name.strip_edges(),
		"rows": 0, "verbs": PackedStringArray(), "signals": PackedStringArray()
	})
	return entries


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
static func sections_for(census: Array, scene_only: Array, scene_name: String,
		input_actions: Array = []) -> Array:
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
		# R23 - the controls this file names, with what each one is bound to. The Input Map is the
		# object every input row is really about, and it was the one thing in the bar a reader had to
		# leave the sheet to look up.
		{
			"id": "input",
			"title": EventSheetL10n.translate("INPUT"),
			"note": EventSheetL10n.translate("drag one onto the sheet to start an event"),
			"entries": input_entries(input_actions)
		},
		{"id": "globals", "title": EventSheetL10n.translate("GLOBALS & FAMILIES"), "note": "", "entries": globals}
	]


## One Input Map action as a bar entry: its name, the object its rows read on, and its bindings as the
## muted note. An action the project does not have keeps its name and says so instead of a binding,
## which is the whole point of listing them here.
static func input_entries(input_actions: Array) -> Array:
	var entries: Array = []
	for entry: Variant in input_actions:
		var facts: Dictionary = entry
		var bindings: PackedStringArray = facts.get("bindings", PackedStringArray())
		var note: String = " · ".join(bindings)
		if not bool(facts.get("known", false)):
			note = EventSheetL10n.translate("not in the Input Map")
		elif bindings.is_empty():
			note = EventSheetL10n.translate("unbound")
		entries.append({
			"label": str(facts.get("name", "")),
			"kind": "input_action",
			"class": "",
			"path": "",
			"note": note,
			"known": bool(facts.get("known", false)),
			"object": str(facts.get("object", "")),
			"rows": 0,
			"verbs": PackedStringArray(),
			"signals": PackedStringArray()
		})
	return entries


## One section's header line: its title, then its count and what it is FOR. USED carries no count -
## the header above the bar already says how many are used, and the entries are right there.
static func section_line(section: Dictionary, shown: int) -> String:
	if str(section.get("id", "")) == "used":
		return str(section.get("title", ""))
	var note: String = str(section.get("note", ""))
	var counted: String = "%s  (%d)" % [str(section.get("title", "")), shown]
	return counted if note.is_empty() else "%s - %s" % [counted, note]


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
	# An Input Map action carries its own note (its bindings), because "what is this bound to" is what
	# a reader came to the INPUT section for, and no census count answers it.
	var note: String = str(entry.get("note", "")) if str(entry.get("kind", "")) == "input_action" \
		else EventSheetViewportReadingRows.object_note(entry)
	var label: String = str(entry.get("label", ""))
	return label if note.is_empty() else "%s  %s" % [label, note]


## The hover: the verbs this file uses the object with, so the bar answers "and what does it DO with
## it" without a click. Falls back to the entry's own line when the file only names it.
static func entry_tooltip(entry: Dictionary) -> String:
	var verbs: PackedStringArray = entry.get("verbs", PackedStringArray())
	if verbs.is_empty():
		return entry_text(entry)
	return " · ".join(verbs)


## R40 - an autoload's hover under GLOBALS says what it HOLDS, with the values: `Score = 0 ·
## Lives = 3 · PlayerName = ""`. The verbs an autoload is used with are the least interesting thing
## about it; the numbers the whole project shares are the answer a reader came for. Read straight off
## the autoload's file, so it works for one nobody has opened. Falls back to the ordinary hover when
## the file declares nothing readable.
static func globals_tooltip(entry: Dictionary) -> String:
	var singleton: String = str(entry.get("label", "")).strip_edges()
	var path: String = ""
	for autoload: Dictionary in EventSheetGlobalVariables.autoload_sheets():
		if str(autoload.get("name", "")) == singleton:
			path = str(autoload.get("path", ""))
	if path.is_empty():
		return entry_tooltip(entry)
	var parts: PackedStringArray = PackedStringArray()
	for declared: Dictionary in EventSheetGlobalVariables.declared_globals(path):
		parts.append("%s = %s" % [str(declared.get("name", "")), str(declared.get("value", ""))])
	return " · ".join(parts) if not parts.is_empty() else entry_tooltip(entry)


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
	# Hoisted: the class map is a read of the whole sheet, and it is the same answer for every entry.
	_class_map = EventSheetViewportReadingRows.object_class_map(_sheet)
	var shown: int = 0
	for section_entry: Variant in sections_for(_entries, _scene_only, _scene_name, _input_actions):
		var section: Dictionary = section_entry
		var visible_entries: Array = []
		for entry: Variant in sorted_entries(section.get("entries", []), _sort):
			if matches_filter(entry as Dictionary, _filter):
				visible_entries.append(entry)
		if visible_entries.is_empty():
			continue
		var section_item: TreeItem = tree.create_item(root)
		section_item.set_text(0, section_line(section, visible_entries.size()))
		section_item.set_selectable(0, false)
		section_item.set_selectable(1, false)
		section_item.set_custom_color(0, EventSheetActiveTheme.chrome().object_bar_section_color)
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
			var entry_item: TreeItem = _add_entry_item(parent_item, record, Array(missing).has(label))
			by_label[label] = entry_item
			_add_could_adopt_line(entry_item, str(section.get("id", "")), label)
			shown += 1
	if shown == 0:
		var empty_item: TreeItem = tree.create_item(root)
		empty_item.set_text(0, empty_state_text(not _scene_name.is_empty()))
		empty_item.set_selectable(0, false)
		empty_item.set_custom_color(0, EventSheetActiveTheme.chrome().object_bar_section_color)
		empty_item.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)


## S25 - the muted "could adopt: X, Y" line under an object whose script the readings recognised a
## replaceable pattern in. One line, under the object it is about, so a reader meets the offer where
## they are already looking instead of only inside a right-click menu.
##
## Only under the sheet's OWN object, because a claim is a fact about THIS file - and only for
## behaviors this build can actually swap in, since an offer that cannot be taken up is worse than
## no offer at all.
func _add_could_adopt_line(parent_item: TreeItem, section_id: String, label: String) -> void:
	if parent_item == null or section_id != "used" or _sheet == null:
		return
	if label != EventSheetViewportReadingRows.script_object_name(_sheet):
		return
	EventSheetViewportReadingRows.ensure_claims(_sheet)
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(_sheet):
		if not EventSheetPatternAdopt.is_adoptable(claim as Dictionary):
			continue
		var pack: String = EventSheetPatternVocabulary.pack_label(
			EventSheetPatternAdopt.adoptable_of(claim as Dictionary))
		if pack.is_empty() or seen.has(pack):
			continue
		seen[pack] = true
		names.append(pack)
	if names.is_empty():
		return
	var line: TreeItem = tree.create_item(parent_item)
	line.set_text(0, EventSheetL10n.translate("could adopt: %s") % ", ".join(names))
	line.set_selectable(0, false)
	line.set_selectable(1, false)
	line.set_custom_color(0, EventSheetActiveTheme.chrome().object_bar_section_color)
	line.set_tooltip_text(0, EventSheetL10n.translate(
		"This script hand-writes something a shipped behavior already does. Right-click the marked event to see what would change."))
	line.set_metadata(0, {"could_adopt": true})


## Which object an entry sits UNDER, so the bar reads like the object dialog: a behavior belongs to
## the object it is mounted on, everything else stands on its own.
func _owner_label_of(entry: Dictionary) -> String:
	if str(entry.get("kind", "")) != "behaviour":
		return ""
	return EventSheetViewportReadingRows.script_object_name(_sheet)


func _add_entry_item(parent_item: TreeItem, entry: Dictionary, is_missing: bool) -> TreeItem:
	var item: TreeItem = tree.create_item(parent_item)
	var label: String = str(entry.get("label", ""))
	# R23 - an action this script names that the project's Input Map does not have is the same kind of
	# broken as a node that is not in the scene, and wears the same mark.
	var unknown_action: bool = str(entry.get("kind", "")) == "input_action" \
		and not bool(entry.get("known", false))
	var flagged: bool = is_missing or unknown_action
	item.set_text(0, ("⚠ %s" % entry_text(entry)) if flagged else entry_text(entry))
	if flagged:
		# The ⚠ used to be a bare glyph in the row's own colour, which made a flagged entry read
		# exactly like a fine one until you looked twice. It wears the theme's warning tone now.
		item.set_custom_color(0, EventSheetActiveTheme.chrome().object_bar_warning_color)
	if unknown_action:
		item.set_tooltip_text(0, EventSheetL10n.translate("\"%s\" is not in the Input Map") % label)
	elif str(entry.get("kind", "")) == "autoload" and not is_missing:
		item.set_tooltip_text(0, globals_tooltip(entry))
	else:
		item.set_tooltip_text(0, (EventSheetL10n.translate("not in %s") % _scene_name) if is_missing
			else entry_tooltip(entry))
	var icon: Texture2D = EventSheetViewportReadingRows.object_icon(entry, _class_map, _source_path)
	if icon != null:
		item.set_icon(0, icon)
	var rows: int = int(entry.get("rows", 0))
	if rows > 0:
		item.set_text(1, str(rows))
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_custom_color(1, EventSheetActiveTheme.chrome().object_bar_section_color)
		item.set_tooltip_text(1, count_tooltip(
			EventSheetViewportReadingRows.object_usage_split(_sheet, label)))
	item.set_metadata(0, {"label": label, "kind": str(entry.get("kind", ""))})
	return item


## Clicking an entry pins that object's rows; clicking the SAME one again clears, which is why the
## selection is dropped on the second click - a bar row that stays lit while nothing is filtered
## would be a lie about the state of the sheet.
func _on_item_selected() -> void:
	# A right-click selects the entry under the pointer before the menu opens, and that selection is
	# not the reader asking to pin anything - it is them asking what they can do with it.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
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


## Folding a section is remembered for the session, so a reader who opens ALSO IN THE SCENE and works
## through it does not have to open it again on every sheet change.
func _on_section_collapsed(item: TreeItem) -> void:
	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary and (metadata as Dictionary).has("section"):
		_section_folds[str((metadata as Dictionary)["section"])] = item.collapsed


func _on_tree_gui_input(event: InputEvent) -> void:
	# Esc clears the pin. The bar never EDITS the scene, so Delete and the rest are deliberately
	# nothing at all here.
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE and not _highlighted.is_empty():
		var pinned: String = _highlighted
		_highlighted = ""
		tree.deselect_all()
		object_activated.emit(pinned)
		accept_event()
		return
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
	return {"type": DRAG_TYPE_INPUT_ACTION if _selected_kind() == "input_action" else DRAG_TYPE,
		"label": label}


## What kind of thing the selected entry is - an object, or one of the Input Map's actions.
func _selected_kind() -> String:
	var selected: TreeItem = tree.get_selected()
	if selected == null or not (selected.get_metadata(0) is Dictionary):
		return ""
	return str((selected.get_metadata(0) as Dictionary).get("kind", ""))


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
