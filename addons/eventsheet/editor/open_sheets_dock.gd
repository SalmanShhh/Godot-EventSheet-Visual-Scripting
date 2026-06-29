@tool
class_name EventSheetOpenSheetsDock
extends VBoxContainer
# A left editor DOCK that lists the open (and recently-closed) event sheets, so switching
# between many sheets is a single click + filter instead of hunting the tab strip — the
# event-sheet answer to the script editor's "Filter Scripts" list.
#
# It is a PURE VIEW over EventSheetDock's tab model: it holds no sheet state, never touches
# resources, and only emits "the user clicked row N / reopen this path". The plugin wires it
# to the workspace (see plugin.gd): EventSheetDock.open_tabs_changed -> set_state(...), and
# these signals -> EventSheetDock.activate_open_tab / reopen_sheet_path.

## The user clicked an OPEN sheet — switch to that tab (index into the open list).
signal activate_requested(index: int)
## The user clicked a recently-CLOSED sheet — reopen it from its path.
signal reopen_requested(path: String)

const _MUTED: Color = Color(0.62, 0.62, 0.66)  # recently-closed rows read as secondary

var _filter: LineEdit = null
var _list: ItemList = null

# Last state pushed by the plugin, kept so re-filtering doesn't need a fresh snapshot.
var _open: Array = []
var _recent: Array = []
var _active: int = -1

func _init() -> void:
	name = "Open Sheets"
	custom_minimum_size = Vector2(180.0, 140.0)
	add_theme_constant_override("separation", 2)

	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter sheets…"
	_filter.clear_button_enabled = true
	_filter.tooltip_text = "Filter the open sheets by name or path."
	_filter.text_changed.connect(func(_t: String) -> void: _render())
	add_child(_filter)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.allow_reselect = true  # re-clicking the active sheet still re-focuses it
	_list.auto_height = false
	_list.item_selected.connect(_on_item_chosen)  # one click switches — that's the whole point
	add_child(_list)

## Replace the view with a fresh snapshot from EventSheetDock.get_open_sheets_state().
## `open` is [{title, path, dirty}], `active` the active index, `recent` a list of paths.
func set_state(open: Array, active: int, recent: Array) -> void:
	_open = open
	_active = active
	_recent = recent
	_render()

## Rebuild the ItemList from the cached state, honouring the filter. Each actionable row
## carries metadata so a selection maps back to a tab index (open) or a path (recent) even
## when filtering hides rows. Programmatic select() does NOT re-emit item_selected, so this
## can't loop with the plugin's refresh.
func _render() -> void:
	if _list == null:
		return
	var needle: String = _filter.text.strip_edges().to_lower()
	_list.clear()

	if _open.is_empty():
		var empty: int = _list.add_item("No sheets open")
		_list.set_item_selectable(empty, false)
		_list.set_item_disabled(empty, true)
		_list.set_item_custom_fg_color(empty, _MUTED)
		return

	for i: int in range(_open.size()):
		var entry: Dictionary = _open[i]
		var title: String = str(entry.get("title", ""))
		var path: String = str(entry.get("path", ""))
		if not _matches(needle, title, path):
			continue
		var idx: int = _list.add_item(title)
		_list.set_item_tooltip(idx, path if not path.is_empty() else "(unsaved sheet)")
		_list.set_item_metadata(idx, {"kind": "open", "index": i})
		if i == _active:
			_list.select(idx)  # highlight the current sheet (no signal)

	# Recently-closed sheets the plugin filtered down to those NOT currently open.
	var recents: Array = []
	for p: Variant in _recent:
		var path2: String = str(p)
		if _matches(needle, path2.get_file(), path2):
			recents.append(path2)
	if not recents.is_empty():
		var header: int = _list.add_item("Recently closed")
		_list.set_item_selectable(header, false)
		_list.set_item_disabled(header, true)
		_list.set_item_custom_fg_color(header, _MUTED)
		for path3: String in recents:
			var ridx: int = _list.add_item(path3.get_file())
			_list.set_item_tooltip(ridx, "Reopen  " + path3)
			_list.set_item_metadata(ridx, {"kind": "recent", "path": path3})
			_list.set_item_custom_fg_color(ridx, _MUTED)

## A row matches when the filter is blank or is a case-insensitive substring of its title or path.
static func _matches(needle: String, title: String, path: String) -> bool:
	if needle.is_empty():
		return true
	return title.to_lower().contains(needle) or path.to_lower().contains(needle)

func _on_item_chosen(idx: int) -> void:
	if _list == null or idx < 0 or idx >= _list.item_count:
		return
	var meta: Variant = _list.get_item_metadata(idx)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	match str(meta.get("kind", "")):
		"open":
			activate_requested.emit(int(meta.get("index", -1)))
		"recent":
			reopen_requested.emit(str(meta.get("path", "")))
