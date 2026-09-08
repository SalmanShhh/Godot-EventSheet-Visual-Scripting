@tool
class_name EventSheetOpenSheetsDock
extends VBoxContainer
# A left-hand in-workspace PANEL that lists the open (and recently-closed) event sheets, so
# switching between many sheets is a single click + filter instead of hunting the tab strip -
# the event-sheet answer to the script editor's "Filter Scripts" list. It can be collapsed to a
# thin strip (the ◀ header button) or removed entirely (the View ▸ Open Sheets Panel toggle).
#
# It is a PURE VIEW over EventSheetDock's tab model: it holds no sheet state and never touches
# resources. The workspace (event_sheet_dock.gd) feeds it the open-tab snapshot via set_state()
# whenever the tabs change, and acts on its two signals - activate_requested switches to that
# tab, reopen_requested reopens a closed sheet by path.

## The user clicked an OPEN sheet - switch to that tab (index into the open list).
signal activate_requested(index: int)
## The user clicked a recently-CLOSED sheet - reopen it from its path.
signal reopen_requested(path: String)
## The panel was collapsed to a strip / restored - the workspace resizes the split pane to match.
signal collapse_toggled(collapsed: bool)

const _MUTED: Color = Color(0.62, 0.62, 0.66)  # recently-closed rows read as secondary
const _EXPANDED_WIDTH: float = 180.0
const _COLLAPSED_WIDTH: float = 26.0

var _header: HBoxContainer = null
var _title: Label = null
var _collapse_button: Button = null
var _body: VBoxContainer = null
var _filter: LineEdit = null
var _list: ItemList = null
var _collapsed: bool = false

# Last state pushed by the workspace, kept so re-filtering doesn't need a fresh snapshot.
var _open: Array = []
var _recent: Array = []
var _active: int = -1


func _init() -> void:
	name = "Open Sheets"
	custom_minimum_size = Vector2(_EXPANDED_WIDTH, 140.0)
	add_theme_constant_override("separation", 2)

	# Header: a title + a ◀ button that collapses the panel to a thin strip (minimise) without
	# removing it - the View menu does full removal.
	_header = HBoxContainer.new()
	_title = Label.new()
	_title.text = "Open Sheets"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title)
	_collapse_button = Button.new()
	_collapse_button.flat = true
	_collapse_button.text = "◀"
	_collapse_button.tooltip_text = "Collapse the panel to a strip"
	_collapse_button.pressed.connect(func() -> void: set_collapsed(not _collapsed))
	_header.add_child(_collapse_button)
	add_child(_header)

	# Body (filter + list) - hidden when the panel is collapsed.
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 2)
	add_child(_body)

	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter sheets…"
	_filter.clear_button_enabled = true
	_filter.tooltip_text = "Filter the open sheets by name or path."
	_filter.text_changed.connect(func(_t: String) -> void: _render())
	_body.add_child(_filter)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.allow_reselect = true  # re-clicking the active sheet still re-focuses it
	_list.auto_height = false
	_list.item_selected.connect(_on_item_chosen)  # one click switches - that's the whole point
	_body.add_child(_list)


## Collapse the panel to a thin strip (just the ▸ button) or restore it. Keeps the panel in
## place but reclaims its width; the View-menu toggle removes it entirely.
func set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_body.visible = not collapsed
	_title.visible = not collapsed
	custom_minimum_size = Vector2(_COLLAPSED_WIDTH if collapsed else _EXPANDED_WIDTH, custom_minimum_size.y)
	_collapse_button.text = "▸" if collapsed else "◀"
	_collapse_button.tooltip_text = "Expand the Open Sheets panel" if collapsed else "Collapse the panel to a strip"
	collapse_toggled.emit(collapsed)


func is_collapsed() -> bool:
	return _collapsed


## The header line the rail hangs its minimise button on, at the right edge.
func rail_header_row() -> HBoxContainer:
	return _header


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

	for entry: Dictionary in group_entries(_open):
		var title: String = str(entry.get("title", ""))
		var path: String = str(entry.get("path", ""))
		if not _matches(needle, title, path):
			continue
		var indices: Array = entry.get("indices", [])
		var idx: int = _list.add_item(list_label(entry))
		_list.set_item_tooltip(idx, hover_text(entry))
		_list.set_item_metadata(idx, {
			"kind": "open",
			"index": next_index(indices, _active),
			"indices": indices,
		})
		if indices.has(_active):
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


## One line per FILE, not per tab: the same sheet opened eight times (a pack whose verbs each
## opened it, a split view, a jump back and forth) used to be eight identical lines with nothing
## to tell them apart. Entries are grouped by path, in first-appearance order, and the group
## carries every tab index that shares it so a click can walk them. An UNSAVED sheet has no path
## to be the same as, so it never groups. Static + pure, so the grouping is pinnable.
static func group_entries(open: Array) -> Array:
	var grouped: Array = []
	var by_path: Dictionary = {}
	for i: int in range(open.size()):
		if not (open[i] is Dictionary):
			continue
		var entry: Dictionary = open[i]
		var path: String = str(entry.get("path", "")).strip_edges()
		if not path.is_empty() and by_path.has(path):
			var seen: Dictionary = grouped[int(by_path[path])]
			(seen["indices"] as Array).append(i)
			seen["count"] = (seen["indices"] as Array).size()
			seen["dirty"] = bool(seen.get("dirty", false)) or bool(entry.get("dirty", false))
			continue
		var row: Dictionary = entry.duplicate()
		row["indices"] = [i]
		row["count"] = 1
		if not path.is_empty():
			by_path[path] = grouped.size()
		grouped.append(row)
	return grouped


## What a grouped row reads as: the sheet's title, and how many tabs are on that one file when
## more than one is. Static so the wording is pinnable.
static func list_label(entry: Dictionary) -> String:
	var title: String = str(entry.get("title", ""))
	var count: int = int(entry.get("count", 1))
	return title if count <= 1 else "%s ×%d" % [title, count]


## Which tab a click on a grouped row goes to: the NEXT tab of that file after the active one, so
## clicking a group of eight walks them one at a time; the first, when the active tab is elsewhere.
static func next_index(indices: Array, active: int) -> int:
	if indices.is_empty():
		return -1
	var at: int = indices.find(active)
	if at < 0:
		return int(indices[0])
	return int(indices[(at + 1) % indices.size()])


## What an open sheet says on hover, where a sheet is picked: where it is stored, how much of
## it reads as events, and the workspace it was opened as part of. Pure, so tests pin it.
static func hover_text(entry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var path: String = str(entry.get("path", "")).strip_edges()
	parts.append(path if not path.is_empty() else "(unsaved sheet)")
	var health: String = str(entry.get("health", "")).strip_edges()
	if not health.is_empty():
		parts.append(health)
	var group: String = str(entry.get("group", "")).strip_edges()
	if not group.is_empty():
		parts.append(group)
	var count: int = int(entry.get("count", 1))
	if count > 1:
		parts.append("%d tabs are open on this file - clicking walks them." % count)
	return "\n".join(parts)


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
