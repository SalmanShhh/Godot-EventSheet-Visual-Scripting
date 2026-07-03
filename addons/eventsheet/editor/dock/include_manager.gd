@tool
class_name EventSheetIncludeManager
extends RefCounted
# The "Manage Includes" window: browse / add / remove / reorder a sheet's included library sheets, with
# a live read-only preview of what each contributes (events / functions / variables). Every change is
# undoable. Extracted from event_sheet_dock.gd to keep that file maintainable; this owns all its own
# widgets and reaches dock state (current sheet + path, the ACE registry, undo / dirty / status / load)
# through the `_dock` back-reference, the same pattern as the other dock/ helpers.

var _dock: Control = null
var _include_manager_window: Window = null
var _include_list: ItemList = null
var _include_preview: RichTextLabel = null
var _include_preview_viewport: EventSheetViewport = null


func init(dock: Control) -> void:
	_dock = dock


## Manage Includes: browse/add/remove/reorder the sheet's included library sheets, with a live
## preview of what each contributes (events/functions/variables). Every change is undoable.
func open() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Open or create a sheet first.", true)
		return
	if _include_manager_window == null:
		_build_include_manager()
	_refresh_include_list()
	_include_manager_window.popup_centered(Vector2i(720, 480))


func _build_include_manager() -> void:
	_include_manager_window = Window.new()
	_include_manager_window.title = "Manage Includes"
	_include_manager_window.close_requested.connect(func() -> void: _include_manager_window.hide())
	var split: HSplitContainer = HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.split_offset = 300
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(300.0, 0.0)
	_include_list = ItemList.new()
	_include_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_include_list.item_selected.connect(func(_index: int) -> void: _refresh_include_preview())
	var list_card: PanelContainer = EventSheetPopupUI.titled_card("Included sheets", _include_list)
	list_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(list_card)
	var buttons: HBoxContainer = HBoxContainer.new()
	var add_button: Button = Button.new(); add_button.text = "Add…"; add_button.pressed.connect(_include_add_requested); buttons.add_child(add_button)
	var remove_button: Button = Button.new(); remove_button.text = "Remove"; remove_button.pressed.connect(_include_remove_selected); buttons.add_child(remove_button)
	var up_button: Button = Button.new(); up_button.text = "↑"; up_button.pressed.connect(func() -> void: _include_move(-1)); buttons.add_child(up_button)
	var down_button: Button = Button.new(); down_button.text = "↓"; down_button.pressed.connect(func() -> void: _include_move(1)); buttons.add_child(down_button)
	left.add_child(buttons)
	split.add_child(left)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_include_preview = RichTextLabel.new()
	_include_preview.bbcode_enabled = true
	_include_preview.custom_minimum_size = Vector2(0.0, 76.0)
	right.add_child(EventSheetPopupUI.titled_card("Preview", _include_preview))
	# Provenance view — the included sheet's actual rows, read-only (a preview copy; edits here
	# never touch the source). "Open Source Sheet" is the jump-to-source.
	var preview_scroll: ScrollContainer = ScrollContainer.new()
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_include_preview_viewport = EventSheetViewport.new()
	_include_preview_viewport.set_ace_registry(_dock._ace_registry)
	preview_scroll.add_child(_include_preview_viewport)
	var open_source: Button = Button.new()
	open_source.text = "Open Source Sheet…"
	open_source.tooltip_text = "Open the included sheet to edit it (changes flow to every sheet that includes it)."
	open_source.pressed.connect(_open_selected_include_source)
	var contents_box: VBoxContainer = EventSheetPopupUI.form_box()
	contents_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents_box.add_child(preview_scroll)
	contents_box.add_child(open_source)
	var contents_card: PanelContainer = EventSheetPopupUI.titled_card("Contents", contents_box)
	contents_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(contents_card)
	split.add_child(right)
	_include_manager_window.add_child(split)
	_dock.add_child(_include_manager_window)


func _open_selected_include_source() -> void:
	var selected: PackedInt32Array = _include_list.get_selected_items()
	if selected.is_empty():
		return
	var path: String = str(_include_list.get_item_metadata(selected[0]))
	if ResourceLoader.exists(path):
		_include_manager_window.hide()
		_dock._load_sheet_from_path(path)


func _refresh_include_list() -> void:
	if _include_list == null:
		return
	_include_list.clear()
	for path: String in _dock._current_sheet.includes:
		var summary: Dictionary = EventSheetIncludes.summarize(path)
		var label: String = path.get_file()
		if not bool(summary.get("valid", false)):
			label += "  (⚠ %s)" % str(summary.get("error", ""))
		_include_list.add_item(label)
		_include_list.set_item_metadata(_include_list.item_count - 1, path)
	_refresh_include_preview()


func _refresh_include_preview() -> void:
	if _include_preview == null:
		return
	if _include_preview_viewport != null:
		_include_preview_viewport.set_sheet(EventSheetResource.new())
	var selected: PackedInt32Array = _include_list.get_selected_items()
	if selected.is_empty():
		_include_preview.text = "Select an include to preview what it contributes."
		return
	var path: String = str(_include_list.get_item_metadata(selected[0]))
	var summary: Dictionary = EventSheetIncludes.summarize(path)
	if not bool(summary.get("valid", false)):
		_include_preview.text = "[color=#e88]%s[/color]\n%s" % [path, str(summary.get("error", ""))]
		return
	var functions: Array = summary.get("functions", [])
	var variables: Array = summary.get("variables", [])
	var class_line: String = ("class %s\n" % str(summary.get("class"))) if str(summary.get("class", "")) != "" else ""
	_include_preview.text = "[b]%s[/b]\n%s\nEvents: %d\nFunctions: %s\nVariables: %s" % [
		path, class_line, int(summary.get("events", 0)),
		", ".join(_string_list(functions)) if not functions.is_empty() else "(none)",
		", ".join(_string_list(variables)) if not variables.is_empty() else "(none)"]
	var included: EventSheetResource = load(path) as EventSheetResource
	if _include_preview_viewport != null and included != null:
		_include_preview_viewport.set_sheet(included)  # read-only provenance view


func _include_add_requested() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.title = "Add Include Sheet"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.tres ; EventSheet"])
	dialog.file_selected.connect(func(path: String) -> void:
		_add_include(path)
		dialog.call_deferred("queue_free"))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	_dock.add_child(dialog)
	dialog.popup_centered(Vector2i(820, 560))


func _add_include(path: String) -> void:
	if _dock._current_sheet.includes.has(path):
		_dock._set_status("%s is already included." % path.get_file(), true)
		return
	if EventSheetIncludes.would_create_cycle(_dock._current_sheet_path, path):
		_dock._set_status("Can't add %s — it would create an include cycle." % path.get_file(), true)
		return
	if _dock._perform_undoable_sheet_edit("Add Include", func() -> bool:
		_dock._current_sheet.includes.append(path)
		return true):
		_dock._mark_dirty("Added include %s." % path.get_file())
	_refresh_include_list()


func _include_remove_selected() -> void:
	var selected: PackedInt32Array = _include_list.get_selected_items()
	if selected.is_empty():
		return
	var path: String = str(_include_list.get_item_metadata(selected[0]))
	if _dock._perform_undoable_sheet_edit("Remove Include", func() -> bool:
		_dock._current_sheet.includes.erase(path)
		return true):
		_dock._mark_dirty("Removed include %s." % path.get_file())
	_refresh_include_list()


func _include_move(delta: int) -> void:
	var selected: PackedInt32Array = _include_list.get_selected_items()
	if selected.is_empty():
		return
	var from_index: int = selected[0]
	var to_index: int = from_index + delta
	if to_index < 0 or to_index >= _dock._current_sheet.includes.size():
		return
	if _dock._perform_undoable_sheet_edit("Reorder Includes", func() -> bool:
		var moved: String = _dock._current_sheet.includes[from_index]
		_dock._current_sheet.includes[from_index] = _dock._current_sheet.includes[to_index]
		_dock._current_sheet.includes[to_index] = moved
		return true):
		_dock._mark_dirty("Reordered includes.")
	_refresh_include_list()
	_include_list.select(to_index)
	_refresh_include_preview()


func _string_list(values: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		out.append(str(value))
	return out
