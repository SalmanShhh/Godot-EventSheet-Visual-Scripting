@tool
class_name EventSheetProjectBar
extends VBoxContainer

# T13 - THE PROJECT BAR: a read-only outline of the project by KIND, as a TAB of the Object bar.
#
# It is not a second FileSystem dock and it is not a new dock at all. It shares the Object bar's
# strip, it is collapsed to a thin header by default, and it is OFF unless the reader asked for it
# (Simple mode, a project started from a template, or View ▸ Project bar). ✕ hides it again.
#
# It owns NO action. Every right-click entry opens Godot's own dialog or one the plugin already has,
# every double-click routes somewhere that already exists, and nothing here creates, renames, moves
# or deletes a file. What it adds over FileSystem is the four things a folder tree cannot say: which
# scripts open as sheets and how much of them reads as events, which classes the project declares and
# who extends whom, which behavior packs are installed, and the last Doctor run's findings per item.
#
# It is built LAZILY - nothing is scanned until the tab is first shown - and refreshed on the same
# `filesystem_changed` ping the rest of the plugin listens to, so a hidden Project bar costs nothing.

## An entry was double-clicked. `route` is one of the routes EventSheetProjectOutline names, and the
## dock decides what each one MEANS - the bar never opens anything itself.
signal entry_activated(route: String, entry: Dictionary)

## Right-click ▸ New scene / New script / New class / Extract base class / Import sound. Every one of
## these opens something that already exists; the bar only says which.
signal create_requested(what: String)

## The ✕ - hide the Project bar for this project.
signal close_requested()

## The drag payload a Project bar entry hands the canvas, kept apart from the Object bar's own so the
## viewport can tell "a class from the project" from "an object this sheet already uses".
const DRAG_TYPE: String = "eventsheet_project_entry"

const _META_KEY: String = "eventsheets_project_bar"

## Right-click, in the order it reads. Each id is the thing that opens, never a thing this bar does.
const CREATE_ITEMS: Array = [
	["new_scene", "New scene…"],
	["new_script", "New script…"],
	["new_class", "New class…"],
	["extract_base_class", "Extract base class…"],
	["import_sound", "Import sound…"],
]

var tree: Tree = null
var filter_edit: LineEdit = null

var _header_button: Button = null
var _close_button: Button = null
var _outline: Dictionary = {}
var _built: bool = false
var _expanded: bool = false
var _filter: String = ""
var _familiar_words: bool = false
var _script_opens_as_sheet: bool = true
var _coverage_by_path: Dictionary = {}
var _menu: PopupMenu = null
var _section_folds: Dictionary = {}


func _init() -> void:
	name = "Project"
	var header_row := HBoxContainer.new()
	_header_button = Button.new()
	_header_button.flat = true
	_header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_button.tooltip_text = EventSheetL10n.translate(
		"Everything in this project, by what it is. Nothing here changes a file - every entry opens something you already have.")
	_header_button.pressed.connect(func() -> void: set_expanded(not _expanded))
	header_row.add_child(_header_button)
	_close_button = Button.new()
	_close_button.flat = true
	_close_button.text = "✕"
	_close_button.tooltip_text = EventSheetL10n.translate("Hide the Project bar for this project (View ▸ Project bar brings it back).")
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	header_row.add_child(_close_button)
	add_child(header_row)
	filter_edit = LineEdit.new()
	filter_edit.name = "EventSheetProjectFilter"
	filter_edit.placeholder_text = EventSheetL10n.translate("filter the project...")
	filter_edit.clear_button_enabled = true
	filter_edit.text_changed.connect(_on_filter_changed)
	filter_edit.text_submitted.connect(_on_filter_submitted)
	filter_edit.gui_input.connect(_on_filter_gui_input)
	add_child(filter_edit)
	tree = Tree.new()
	tree.name = "EventSheetProjectTree"
	tree.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(110.0))
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = true
	tree.allow_reselect = true
	tree.allow_rmb_select = true
	tree.item_activated.connect(_on_item_activated)
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	tree.item_collapsed.connect(_on_section_collapsed)
	tree.gui_input.connect(_on_tree_gui_input)
	tree.set_drag_forwarding(_drag_payload_for, Callable(), Callable())
	add_child(tree)
	set_expanded(bool(_read_prefs().get("expanded", false)))


## Whether the reader has this bar OPEN. A thin strip is the default: the bar's promise is that it
## takes no room until it is asked for.
func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	tree.visible = expanded
	filter_edit.visible = expanded
	size_flags_vertical = Control.SIZE_EXPAND_FILL if expanded else Control.SIZE_SHRINK_BEGIN
	# LAZY: the scan happens the first time the bar is actually opened, never at boot.
	if expanded and not _built:
		refresh()
	_refresh_header()
	_save_prefs()


func is_expanded() -> bool:
	return _expanded


## Which word the headings lead with, and where a double-clicked script goes - both are reader
## settings the dock owns, handed down rather than read here.
func set_reading_prefs(familiar_words: bool, script_opens_as_sheet: bool) -> void:
	_familiar_words = familiar_words
	_script_opens_as_sheet = script_opens_as_sheet
	if _built:
		_rebuild_tree()
	_refresh_header()


## The coverage line on the scripts the reader has open ("82% reads as events, 3 script blocks").
## Only the open ones: measuring the rest means opening every file in the project.
func set_coverage(coverage_by_path: Dictionary) -> void:
	_coverage_by_path = coverage_by_path.duplicate()


## Re-reads the project. Called on first open and on the editor's filesystem_changed - the same ping
## the Object bar's caches drop on, so the bar can never be describing yesterday's project.
func refresh() -> void:
	_built = true
	_outline = EventSheetProjectOutline.outline("res://", EventSheetProjectOutline.PACKS_DIR, _coverage_by_path)
	_rebuild_tree()
	_refresh_header()


## What the bar is currently listing, so the dock (and a test) can read it without walking a Tree.
func outline() -> Dictionary:
	return _outline.duplicate(true)


func _rebuild_tree() -> void:
	tree.clear()
	var root: TreeItem = tree.create_item()
	var shown: int = 0
	for kind: String in EventSheetProjectOutline.KIND_ORDER:
		var entries: Array = _outline.get(kind, [])
		var visible_entries: Array = []
		for entry: Variant in entries:
			if EventSheetProjectOutline.matches_filter(entry as Dictionary, _filter):
				visible_entries.append(entry)
		if visible_entries.is_empty():
			continue
		var section: TreeItem = tree.create_item(root)
		section.set_text(0, "%s  (%d)" % [
			EventSheetProjectOutline.heading_for(kind, _familiar_words), visible_entries.size()])
		section.set_selectable(0, false)
		section.set_custom_color(0, EventSheetActiveTheme.chrome().project_bar_heading_color)
		section.set_metadata(0, {"section": kind})
		# A filter that is typing must not fight the folds: a section with a match opens while the
		# box has text and goes back to its remembered state when it is cleared.
		section.collapsed = bool(_section_folds.get(kind, kind != "scenes")) and _filter.strip_edges().is_empty()
		for entry: Variant in visible_entries:
			_add_entry_item(section, entry as Dictionary)
			shown += 1
	if shown == 0:
		var empty_item: TreeItem = tree.create_item(root)
		empty_item.set_text(0, EventSheetL10n.translate("Nothing here matches that.") if not _filter.strip_edges().is_empty()
			else EventSheetL10n.translate("This project has no scenes or scripts yet."))
		empty_item.set_selectable(0, false)
		empty_item.set_custom_color(0, EventSheetActiveTheme.chrome().project_bar_heading_color)
		empty_item.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)


func _add_entry_item(parent_item: TreeItem, entry: Dictionary) -> TreeItem:
	var item: TreeItem = tree.create_item(parent_item)
	var badge: String = EventSheetProjectOutline.badge_for(entry)
	item.set_text(0, entry_text(entry, badge))
	if not badge.is_empty():
		item.set_custom_color(0, EventSheetActiveTheme.chrome().object_bar_warning_color)
		item.set_tooltip_text(0, EventSheetL10n.translate(
			"The last Project Doctor run had something to say about this one."))
	else:
		# V20 - the health card's short form on hover, where a sheet is picked. Text reads only:
		# a bar listing a whole project must never load a sheet to hover one.
		item.set_tooltip_text(0, EventSheetHealthCard.brief_for_path(
			str(entry.get("path", "")), str(entry.get("note", ""))))
	item.set_metadata(0, entry)
	return item


## One entry's line: its name, then its muted note - the file it came from, the classes that extend
## it, how much of it reads as events. Static so a test pins the words without a Tree.
static func entry_text(entry: Dictionary, badge: String = "") -> String:
	var label: String = str(entry.get("label", ""))
	if not badge.is_empty():
		label = "%s %s" % [badge, label]
	var note: String = str(entry.get("note", ""))
	return label if note.is_empty() else "%s  %s" % [label, note]


func _on_item_activated() -> void:
	var entry: Dictionary = _selected_entry()
	if entry.is_empty():
		return
	entry_activated.emit(EventSheetProjectOutline.route_for(entry, _script_opens_as_sheet), entry)


func _on_item_mouse_selected(_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	_ensure_menu()
	_menu.reset_size()
	_menu.popup(Rect2i(Vector2i(get_screen_transform() * get_local_mouse_position()), Vector2i.ZERO))


func _on_section_collapsed(item: TreeItem) -> void:
	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary and (metadata as Dictionary).has("section"):
		_section_folds[str((metadata as Dictionary)["section"])] = item.collapsed


func _on_tree_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key_event: InputEventKey = event as InputEventKey
	# Enter opens what the arrows landed on; Esc hands focus back to the sheet. The bar never
	# DELETES anything, so Delete is deliberately nothing at all here.
	if key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_on_item_activated()
		accept_event()
	elif key_event.keycode == KEY_ESCAPE:
		tree.release_focus()
		accept_event()


func _selected_entry() -> Dictionary:
	var selected: TreeItem = tree.get_selected()
	if selected == null or not (selected.get_metadata(0) is Dictionary):
		return {}
	var metadata: Dictionary = selected.get_metadata(0)
	return {} if metadata.has("section") else metadata


## The payload a dragged entry hands the canvas: what it is and what dragging it MEANS, so the canvas
## decides where. An entry the sheet has no gesture for refuses the drag rather than inventing one.
func _drag_payload_for(_at_position: Vector2) -> Variant:
	var entry: Dictionary = _selected_entry()
	if entry.is_empty():
		return null
	var intent: String = EventSheetProjectOutline.drag_intent_for(entry)
	if intent.is_empty():
		return null
	var preview := Label.new()
	preview.text = str(entry.get("label", ""))
	tree.set_drag_preview(preview)
	return {"type": DRAG_TYPE, "intent": intent, "label": str(entry.get("label", "")),
		"path": str(entry.get("path", "")), "kind": str(entry.get("kind", ""))}


func _ensure_menu() -> void:
	if _menu != null:
		return
	_menu = PopupMenu.new()
	for index: int in CREATE_ITEMS.size():
		_menu.add_item(EventSheetL10n.translate(str((CREATE_ITEMS[index] as Array)[1])), index)
	_menu.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < CREATE_ITEMS.size():
			create_requested.emit(str((CREATE_ITEMS[id] as Array)[0])))
	add_child(_menu)


func _on_filter_changed(text: String) -> void:
	_filter = text
	_rebuild_tree()


## Enter on a SINGLE match opens it - the type-and-go path, which is what a filter box in a bar is for.
func _on_filter_submitted(_text: String) -> void:
	var matched: Array = []
	for kind: String in EventSheetProjectOutline.KIND_ORDER:
		for entry: Variant in _outline.get(kind, []):
			if EventSheetProjectOutline.matches_filter(entry as Dictionary, _filter):
				matched.append(entry)
	if matched.size() != 1:
		return
	var entry: Dictionary = matched[0]
	entry_activated.emit(EventSheetProjectOutline.route_for(entry, _script_opens_as_sheet), entry)


## Down out of the filter box walks into the list, Esc clears it - the two keys that make a filter
## box plus a tree feel like one control.
func _on_filter_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode == KEY_DOWN:
		tree.grab_focus()
		accept_event()
	elif key_event.keycode == KEY_ESCAPE:
		filter_edit.clear()
		_filter = ""
		_rebuild_tree()
		accept_event()


func _refresh_header() -> void:
	var counted: int = 0
	for kind: String in EventSheetProjectOutline.KIND_ORDER:
		counted += (_outline.get(kind, []) as Array).size()
	_header_button.text = "%s %s%s" % [
		"▾" if _expanded else "▸",
		EventSheetL10n.translate("Project"),
		"" if not _built else " · %s" % (EventSheetL10n.translate("%d things") % counted)
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
			"eventsheets", _META_KEY, {"expanded": _expanded})
