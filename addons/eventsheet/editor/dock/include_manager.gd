@tool
class_name EventSheetIncludeManager
extends RefCounted
# The "Manage Includes" window: browse / add / remove / reorder a sheet's included library sheets, with
# a live read-only preview of what each contributes (events / functions / variables). Every change is
# undoable. Extracted from event_sheet_dock.gd to keep that file maintainable; this owns all its own
# widgets and reaches dock state (current sheet + path, the ACE registry, undo / dirty / status / load)
# through the `_dock` back-reference, the same pattern as the other dock/ helpers.
#
# Each include shows what it brings beside its name ("3 functions", "not found"), and the help strip
# at the foot says what the selected one is and ADDS: every function and variable the sheet gains
# from it. Add… opens the include picker: the project's sheet files, where one already included or
# one that would include this sheet back is marked the moment it is chosen, before Include.

var _dock: Control = null
var _include_manager_window: Window = null
var _include_list: Tree = null
var _include_preview: RichTextLabel = null
var _include_preview_viewport: EventSheetViewport = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _adds_value: Label = null
var _picker: ConfirmationDialog = null
var _picker_list: Tree = null
## What the chosen file brings, or why it cannot be included - said before Include.
var _picker_note: EventSheetPopupUI.StateNote = null


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
	_include_manager_window.title = EventSheetL10n.translate("Manage what %s includes") % _sheet_name()
	_refresh_include_list()
	_include_manager_window.popup_centered(Vector2i(EventSheetPalette.scaled(760), EventSheetPalette.scaled(540)))


func _sheet_name() -> String:
	var path: String = str(_dock._current_sheet_path)
	return path.get_file() if not path.is_empty() else EventSheetL10n.translate("this sheet")


## What an include brings, in a few words for the list's second column.
static func brings(summary: Dictionary) -> String:
	if not bool(summary.get("valid", false)):
		return EventSheetL10n.translate(str(summary.get("error", "")))
	var functions: int = (summary.get("functions", []) as Array).size()
	if functions > 0:
		return EventSheetL10n.translate("%d function(s)") % functions
	return EventSheetL10n.translate("%d variable(s)") % (summary.get("variables", []) as Array).size()


## Everything an include adds to the sheet, as the strip's ADDS line: functions as calls, then
## variables, in the order the include declares them.
static func adds_line(summary: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for function_name: Variant in summary.get("functions", []):
		parts.append("%s()" % str(function_name))
	for variable_name: Variant in summary.get("variables", []):
		parts.append(str(variable_name))
	return " · ".join(parts)


func _build_include_manager() -> void:
	_include_manager_window = Window.new()
	_include_manager_window.close_requested.connect(_include_manager_window.hide)
	var outer: VBoxContainer = EventSheetPopupUI.form_box()
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = EventSheetPalette.scaled(300)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(300.0), 0.0)
	_include_list = _two_column_list()
	_include_list.item_selected.connect(_refresh_include_preview)
	var list_card: PanelContainer = EventSheetPopupUI.titled_card("Included sheets", _include_list)
	list_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(list_card)
	var buttons: HFlowContainer = HFlowContainer.new()
	for button_spec: Array in [["Add…", _include_add_requested], ["Remove", _include_remove_selected],
			["Move up", _include_move.bind(-1)], ["Move down", _include_move.bind(1)]]:
		var button: Button = Button.new()
		button.text = str(button_spec[0])
		button.pressed.connect(button_spec[1] as Callable)
		buttons.add_child(button)
	left.add_child(buttons)
	split.add_child(left)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_include_preview = RichTextLabel.new()
	_include_preview.bbcode_enabled = true
	_include_preview.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(76.0))
	right.add_child(EventSheetPopupUI.titled_card("Preview", _include_preview))
	# Provenance view - the included sheet's actual rows, read-only (a preview copy; edits here
	# never touch the source). "Open Source Sheet" is the jump-to-source.
	var preview_scroll: ScrollContainer = ScrollContainer.new()
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_include_preview_viewport = EventSheetViewport.new()
	_include_preview_viewport.set_ace_registry(_dock._ace_registry)
	# Read and navigate only, with no add row: it shows the included file, never edits it.
	_include_preview_viewport.companion_mode = true
	_include_preview_viewport.show_add_event_footers = false
	preview_scroll.add_child(_include_preview_viewport)
	var open_source: Button = Button.new()
	open_source.text = EventSheetL10n.translate("Open Source Sheet…")
	open_source.tooltip_text = EventSheetL10n.translate("Open the included sheet to edit it (changes flow to every sheet that includes it).")
	open_source.pressed.connect(_open_selected_include_source)
	var contents_box: VBoxContainer = EventSheetPopupUI.form_box()
	contents_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents_box.add_child(preview_scroll)
	contents_box.add_child(open_source)
	var contents_card: PanelContainer = EventSheetPopupUI.titled_card("Contents", contents_box)
	contents_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(contents_card)
	split.add_child(right)
	outer.add_child(split)
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(600.0))
	_adds_value = _strip.add_line(EventSheetL10n.translate("ADDS"))
	outer.add_child(_strip)
	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_include_manager_window.hide)
	outer.add_child(close_button)
	_include_manager_window.add_child(EventSheetPopupUI.window_body(outer))
	_dock.add_child(_include_manager_window)


## A list of files with a quieter second column, the shape both this window and its picker use.
static func _two_column_list() -> Tree:
	var list: Tree = Tree.new()
	list.columns = 2
	list.hide_root = true
	list.select_mode = Tree.SELECT_ROW
	list.set_column_expand_ratio(0, 3)
	list.set_column_expand_ratio(1, 2)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.create_item()
	return list


static func _add_row(list: Tree, path: String, label: String, note: String) -> TreeItem:
	var item: TreeItem = list.create_item(list.get_root())
	item.set_text(0, label)
	item.set_text(1, note)
	item.set_tooltip_text(0, path)
	item.set_custom_color(1, EventSheetPopupUI.muted_text_color())
	item.set_metadata(0, path)
	return item


func _selected_path() -> String:
	var item: TreeItem = _include_list.get_selected() if _include_list != null else null
	return str(item.get_metadata(0)) if item != null else ""


func _open_selected_include_source() -> void:
	var path: String = _selected_path()
	if ResourceLoader.exists(path):
		_include_manager_window.hide()
		_dock._load_sheet_from_path(path)


func _refresh_include_list(select_index: int = -1) -> void:
	if _include_list == null:
		return
	_include_list.clear()
	_include_list.create_item()
	for index: int in _dock._current_sheet.includes.size():
		var path: String = _dock._current_sheet.includes[index]
		var item: TreeItem = _add_row(_include_list, path, path.get_file(), brings(EventSheetIncludes.summarize(path)))
		if index == select_index:
			item.select(0)
	_refresh_include_preview()


func _refresh_include_preview() -> void:
	if _include_preview == null:
		return
	if _include_preview_viewport != null:
		_include_preview_viewport.set_sheet(EventSheetResource.new())
		# Hidden until an include with rows is picked: an empty canvas offered "Add your first event"
		# and "New from template" here, and neither had a sheet to act on.
		_include_preview_viewport.get_parent().visible = false
	var path: String = _selected_path()
	if path.is_empty():
		_include_preview.text = EventSheetL10n.translate("Select an include to preview what it contributes.")
		_strip.describe(EventSheetL10n.translate("This sheet"),
			EventSheetL10n.translate("Pick an include to see what it brings; Add… includes another sheet."))
		_strip.set_line(_adds_value, "")
		return
	var summary: Dictionary = EventSheetIncludes.summarize(path)
	_strip.set_line(_adds_value, adds_line(summary))
	if not bool(summary.get("valid", false)):
		var error_colour: String = EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_ERROR).to_html(false)
		_include_preview.text = "[color=#%s]%s[/color]\n%s" % [error_colour, path, str(summary.get("error", ""))]
		_strip.show_note(path.get_file(), EventSheetL10n.translate("This include is missing or is not a sheet - Remove takes it off the list."),
			EventSheetPopupUI.TONE_ERROR)
		return
	_strip.show_note(EventSheetL10n.translate("This sheet"),
		EventSheetL10n.translate("%s - read-only here. Open Source Sheet… edits it, and every sheet that includes it follows.") % path.get_file())
	var functions: Array = summary.get("functions", [])
	var variables: Array = summary.get("variables", [])
	var class_line: String = ("class %s\n" % str(summary.get("class"))) if str(summary.get("class", "")) != "" else ""
	_include_preview.text = EventSheetL10n.translate("[b]%s[/b]\n%s\nEvents: %d\nFunctions: %s\nVariables: %s") % [
		path, class_line, int(summary.get("events", 0)),
		", ".join(PackedStringArray(functions)) if not functions.is_empty() else EventSheetL10n.translate("(none)"),
		", ".join(PackedStringArray(variables)) if not variables.is_empty() else EventSheetL10n.translate("(none)")]
	var included: EventSheetResource = load(path) as EventSheetResource
	if _include_preview_viewport != null and included != null:
		_include_preview_viewport.set_sheet(included)  # read-only provenance view
		_include_preview_viewport.get_parent().visible = not included.events.is_empty()


## The include picker: the project's sheet files, by path. Choosing one says what it brings, or
## why it cannot be included (already included, or it would include this sheet back), before
## Include is pressed. Only .tres sheets are offered - the compiler merges sheet resources, so a
## .gd script cannot be an include.
func _include_add_requested() -> void:
	if _picker == null:
		var parts: Dictionary = EventSheetPopupUI.panel_window("", Vector2i.ZERO, _include_manager_window,
			EventSheetL10n.translate("Include"), func() -> void:
				var picked: TreeItem = _picker_list.get_selected()
				if picked != null:
					_add_include(str(picked.get_metadata(0))), true)
		_picker = parts["window"]
		var box: VBoxContainer = parts["box"]
		box.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(480.0), EventSheetPalette.scaled_f(360.0))
		_picker_list = _two_column_list()
		_picker_list.item_selected.connect(_on_picker_selected)
		_picker_list.item_activated.connect(func() -> void:
			if not _picker.get_ok_button().disabled:
				_picker.get_ok_button().pressed.emit())
		box.add_child(_picker_list)
		_picker_note = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(440.0))
		box.add_child(_picker_note)
	_picker.title = EventSheetL10n.translate("Add an include to %s") % _sheet_name()
	_picker_list.clear()
	_picker_list.create_item()
	for path: String in sheet_files("res://"):
		var note: String = EventSheetL10n.translate("included") if _dock._current_sheet.includes.has(path) else ""
		_add_row(_picker_list, path, path.trim_prefix("res://"), note)
	_picker_note.say("")
	_picker.get_ok_button().disabled = true
	_picker.popup_centered()


## The .tres files under `folder`, sorted, skipping hidden folders and addons/ - the files a sheet
## could include. Read by name only: nothing is loaded until one is chosen.
static func sheet_files(folder: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension() == "tres":
			found.append(folder.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(folder):
		if not sub.begins_with(".") and not (folder == "res://" and sub == "addons"):
			found.append_array(sheet_files(folder.path_join(sub)))
	found.sort()
	return found


## Why `path` cannot be included in the open sheet, or "" when it can.
func include_refusal(path: String) -> String:
	if _dock._current_sheet.includes.has(path):
		return EventSheetL10n.translate("already included")
	if EventSheetIncludes.would_create_cycle(_dock._current_sheet_path, path):
		return EventSheetL10n.translate("would loop")
	if not bool(EventSheetIncludes.summarize(path).get("valid", false)):
		return EventSheetL10n.translate("not an event sheet")
	return ""


func _on_picker_selected() -> void:
	var item: TreeItem = _picker_list.get_selected()
	var path: String = str(item.get_metadata(0))
	var refusal: String = include_refusal(path)
	item.set_text(1, refusal)
	_picker.get_ok_button().disabled = not refusal.is_empty()
	var said: String = refusal if not refusal.is_empty() else brings(EventSheetIncludes.summarize(path))
	_picker_note.say("%s · %s" % [path.get_file(), said],
		EventSheetPopupUI.TONE_OK if refusal.is_empty() else EventSheetPopupUI.TONE_WARNING)


func _add_include(path: String) -> void:
	var refusal: String = include_refusal(path)
	if not refusal.is_empty():
		_dock._set_status("Can't add %s - %s." % [path.get_file(), refusal], true)
		return
	if _dock._perform_undoable_sheet_edit("Add Include", func() -> bool:
		_dock._current_sheet.includes.append(path)
		return true):
		_dock._mark_dirty("Added include %s." % path.get_file())
	_refresh_include_list(_dock._current_sheet.includes.size() - 1)


func _include_remove_selected() -> void:
	var path: String = _selected_path()
	if path.is_empty():
		return
	if _dock._perform_undoable_sheet_edit("Remove Include", func() -> bool:
		_dock._current_sheet.includes.erase(path)
		return true):
		_dock._mark_dirty("Removed include %s." % path.get_file())
	_refresh_include_list()


func _include_move(delta: int) -> void:
	var from_index: int = _dock._current_sheet.includes.find(_selected_path())
	var to_index: int = from_index + delta
	if from_index < 0 or to_index < 0 or to_index >= _dock._current_sheet.includes.size():
		return
	if _dock._perform_undoable_sheet_edit("Reorder Includes", func() -> bool:
		var moved: String = _dock._current_sheet.includes[from_index]
		_dock._current_sheet.includes[from_index] = _dock._current_sheet.includes[to_index]
		_dock._current_sheet.includes[to_index] = moved
		return true):
		_dock._mark_dirty("Reordered includes.")
	_refresh_include_list(to_index)
