@tool
class_name EventSheetObjectsPanel
extends VBoxContainer
# The OBJECTS rail panel - "what is in this file", the way a scene tree answers "what is in this
# scene". An event sheet's reader needs the same question answered about a script: which nodes does
# it reach for, which behaviours ride on it, which globals does it touch, which groups does it
# address, which scenes does it spawn.
#
# Every entry is DERIVED from the open sheet (EventSheetViewportReadingRows.object_census), so there
# is no stored list to fall out of date and no census to maintain by hand. The panel is shell + fold
# state only: clicking an entry emits, and the dock decides what that means (it highlights the
# object's rows through the viewport's filter lens). Expanded/collapsed persists per project.

## An entry was clicked. The dock highlights that object's rows; clicking the same one again clears,
## which is why the label is all this carries - the panel does not know what highlighting is.
signal object_activated(object_label: String)

const _META_KEY: String = "eventsheets_objects_panel"

var list: ItemList = null

var _header_button: Button = null
var _entries: Array = []
var _expanded: bool = false
var _highlighted: String = ""


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
	add_child(_header_button)
	list = ItemList.new()
	list.name = "EventSheetObjectsList"
	list.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(110.0))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.allow_reselect = true
	list.item_selected.connect(_on_item_selected)
	add_child(list)
	set_expanded(bool(_read_prefs().get("expanded", false)))


## Expanding gives the list rail space (it competes with Open Sheets / Functions / Anatomy);
## collapsing shrinks the panel back to its one-line header.
func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	list.visible = expanded
	size_flags_vertical = Control.SIZE_EXPAND_FILL if expanded else Control.SIZE_SHRINK_BEGIN
	_refresh_header()
	_save_prefs()


func is_expanded() -> bool:
	return _expanded


## Which object's rows are currently highlighted, or "" when none are.
func highlighted_object() -> String:
	return _highlighted


## Rebuilds the list from a sheet. Safe to call on every sheet change - the census is a read of the
## sheet's own rows, and nothing here is cached across sheets.
func set_sheet(sheet: EventSheetResource) -> void:
	_entries = EventSheetViewportReadingRows.object_census(sheet)
	var class_map: Dictionary = EventSheetViewportReadingRows.object_class_map(sheet)
	list.clear()
	for entry: Dictionary in _entries:
		var index: int = list.add_item(entry_text(entry))
		var icon: Texture2D = EventSheetViewportReadingRows.object_icon(entry, class_map)
		if icon != null:
			list.set_item_icon(index, icon)
		list.set_item_tooltip(index, entry_tooltip(entry))
	if not _entries.is_empty() and _highlighted.is_empty():
		list.deselect_all()
	_refresh_header()


## One entry's line: the object's name, then its muted note - what kind of thing it is, the class or
## path it resolves to, and how many rows use it.
static func entry_text(entry: Dictionary) -> String:
	var note: String = EventSheetViewportReadingRows.object_note(entry)
	var label: String = str(entry.get("label", ""))
	return label if note.is_empty() else "%s  %s" % [label, note]


## The hover: the verbs this file uses the object with, so the rail answers "and what does it DO
## with it" without a click. Falls back to the entry's own line when the file only names it.
static func entry_tooltip(entry: Dictionary) -> String:
	var verbs: PackedStringArray = entry.get("verbs", PackedStringArray())
	if verbs.is_empty():
		return entry_text(entry)
	return " · ".join(verbs)


## The census this panel is showing, so the dock (and a test) can read exactly what the rail lists
## without reaching into an ItemList.
func entries() -> Array:
	return _entries.duplicate(true)


## Clicking an entry highlights that object's rows; clicking the SAME one again clears, which is why
## the selection is dropped on the second click - a rail row that stays lit while nothing is
## filtered would be a lie about the state of the sheet.
func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var label: String = str((_entries[index] as Dictionary).get("label", ""))
	_highlighted = "" if _highlighted == label else label
	if _highlighted.is_empty():
		list.deselect_all()
	object_activated.emit(label)


func _refresh_header() -> void:
	_header_button.text = "%s %s · %d" % [
		"▾" if _expanded else "▸", EventSheetL10n.translate("Objects"), _entries.size()
	]


func _read_prefs() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var meta: Variant = EditorInterface.get_editor_settings().get_project_metadata("eventsheets", _META_KEY, {})
		if meta is Dictionary:
			return meta
	return {}


func _save_prefs() -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", _META_KEY, {"expanded": _expanded})
