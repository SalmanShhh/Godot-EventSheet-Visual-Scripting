@tool
class_name EventSheetCompareDialog
extends RefCounted
# Tools ▸ Compare With… - the shipped row-language diff, pointed at any other side.
#
# "What Changed Since Save" answers one question (this sheet against its own last save) and keeps
# answering it unchanged. This is the same machinery with the target unfrozen: the last save, a
# backup from the shipped ring, another project sheet, or any .gd you browse to. Both sides compile
# to SCRATCH paths and the comparison runs summarize() in both directions, so the report has two
# columns - what differs HERE, and what exists THERE and is missing or different here.
#
# The compared sheet is held alive for as long as its result is on screen: every "there" entry
# references one of its resources by instance id, and a freed sheet would turn Bring This Row Over
# into a dead link. Bringing a row over writes ORDINARY rows into the sheet through the undo funnel,
# one undo step, with fresh row uids - exactly what a paste writes.
#
# All the diff logic lives in sheet_diff.gd (static + pure, pinned headless); this file is the shell:
# a target picker, two lists, and the copy-over button.

var _dock: Control = null

var window: Window = null
var target_picker: OptionButton = null
var here_list: ItemList = null
var there_list: ItemList = null
var summary_label: Label = null
var bring_button: Button = null

var _targets: Array = []
var _here_entries: Array = []
var _there_entries: Array = []
## The compared sheet, kept alive while its entries are shown (see the header note).
var _other_sheet: EventSheetResource = null
var _browse_dialog: FileDialog = null
var _browsed_path: String = ""


func init(dock: Control) -> void:
	_dock = dock


## Builds the window without popping it (so tests drive the real widgets headlessly).
func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Compare With"
	window.size = Vector2i(760, 520)
	window.min_size = Vector2i(520, 360)
	window.close_requested.connect(func() -> void: window.hide())
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var picker_row: HBoxContainer = HBoxContainer.new()
	picker_row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	target_picker = OptionButton.new()
	target_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_picker.tooltip_text = "The other side of the comparison: this sheet's last save, a backup from the ring, or another sheet in the project."
	picker_row.add_child(target_picker)
	var browse_button: Button = Button.new()
	browse_button.text = "Browse…"
	browse_button.tooltip_text = "Compare against any .gd or .tres sheet on disk - a teammate's file, a downloaded pack, an older copy."
	browse_button.pressed.connect(_open_browse_dialog)
	picker_row.add_child(browse_button)
	var compare_button: Button = Button.new()
	compare_button.text = "Compare"
	compare_button.pressed.connect(func() -> void: compare_with(selected_target_path()))
	picker_row.add_child(compare_button)
	body.add_child(EventSheetPopupUI.labelled_card("Compare against", picker_row))

	summary_label = EventSheetPopupUI.hint_label(
		"Pick a side and press Compare. Double-click a row to jump to it; a row that only exists on the other side can be brought over.", 520.0)
	body.add_child(summary_label)

	here_list = _build_list("Nothing on this side yet.")
	here_list.item_activated.connect(func(index: int) -> void: _jump_to_entry(_here_entries, index))
	there_list = _build_list("Nothing on the compared side yet.")
	there_list.item_activated.connect(func(index: int) -> void: bring_row_over(index))
	var here_card: PanelContainer = EventSheetPopupUI.labelled_card("Only here / different here", here_list)
	here_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var there_card: PanelContainer = EventSheetPopupUI.labelled_card("Only there / different there", there_list)
	there_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var band: BoxContainer = EventSheetPopupUI.responsive_band(here_card, there_card)
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(band)

	bring_button = Button.new()
	bring_button.text = "Bring This Row Over"
	bring_button.tooltip_text = "Copy the selected row from the compared sheet into this one as ordinary rows - one undo step."
	bring_button.disabled = true
	bring_button.pressed.connect(func() -> void:
		var selected: PackedInt32Array = there_list.get_selected_items()
		if not selected.is_empty():
			bring_row_over(selected[0]))
	there_list.item_selected.connect(func(_index: int) -> void: bring_button.disabled = false)
	body.add_child(bring_button)

	var margined: MarginContainer = EventSheetPopupUI.margined(body)
	margined.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(margined)
	_dock.add_child(window)


func _build_list(placeholder: String) -> ItemList:
	var list: ItemList = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(0.0, 180.0)
	list.tooltip_text = placeholder
	return list


## Tools ▸ Compare With…: refresh the target list and show the window.
func open() -> void:
	build()
	refresh_targets()
	if window.is_inside_tree():
		window.popup_centered()


## Rebuilds the target dropdown from the shipped backup ring + the project's sheets. A browsed
## path stays at the top of the list for as long as the window lives, so re-comparing against a
## teammate's file is one press rather than another trip through the file dialog.
func refresh_targets() -> void:
	if target_picker == null:
		return
	_targets = EventSheetSheetDiff.compare_targets(_dock._current_sheet, _dock._current_sheet_path)
	if not _browsed_path.is_empty():
		_targets.push_front({"label": "Browsed - %s" % _browsed_path.get_file(), "path": _browsed_path, "kind": "browse"})
	target_picker.clear()
	for index: int in range(_targets.size()):
		target_picker.add_item(str((_targets[index] as Dictionary).get("label", "")), index)
	if _targets.is_empty():
		target_picker.add_item("(nothing to compare against yet - save this sheet first)", 0)
		target_picker.disabled = true
	else:
		target_picker.disabled = false


## The path the picker currently points at, or "" when there is nothing to compare against.
func selected_target_path() -> String:
	if _targets.is_empty() or target_picker == null:
		return ""
	var index: int = clampi(target_picker.selected, 0, _targets.size() - 1)
	return str((_targets[index] as Dictionary).get("path", ""))


func _open_browse_dialog() -> void:
	if _browse_dialog == null:
		_browse_dialog = FileDialog.new()
		_browse_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_browse_dialog.access = FileDialog.ACCESS_RESOURCES
		_browse_dialog.filters = PackedStringArray(["*.gd ; GDScript sheet", "*.tres ; Event sheet resource"])
		_browse_dialog.title = "Compare against…"
		_browse_dialog.file_selected.connect(func(path: String) -> void:
			_browsed_path = path
			refresh_targets()
			target_picker.selected = 0
			compare_with(path))
		window.add_child(_browse_dialog)
	_browse_dialog.popup_centered(Vector2i(640, 460))


## Runs the comparison against `other_path` and fills both lists. Returns the raw two-sided
## result ({identical, here_rows, there_rows} or {error}), so a test can assert the comparison
## itself without reading widgets.
func compare_with(other_path: String) -> Dictionary:
	build()
	_here_entries = []
	_there_entries = []
	here_list.clear()
	there_list.clear()
	bring_button.disabled = true
	if _dock._current_sheet == null:
		return _report_error("Open a sheet first.")
	if other_path.strip_edges().is_empty():
		return _report_error("Pick something to compare against first.")
	var other_side: Dictionary = EventSheetSheetDiff.load_side(other_path)
	if other_side.has("error"):
		return _report_error(str(other_side.get("error")))
	_other_sheet = other_side.get("sheet") as EventSheetResource
	var here_compiled: Dictionary = SheetCompiler.compile(_dock._current_sheet, EventSheetSheetDiff.COMPARE_HERE_PATH)
	var result: Dictionary = EventSheetSheetDiff.compare_sides(
		str(here_compiled.get("output", "")), here_compiled.get("source_map", []),
		str(other_side.get("output", "")), other_side.get("source_map", []))
	_here_entries = result.get("here_rows", [])
	_there_entries = result.get("there_rows", [])
	for entry: Dictionary in _here_entries:
		here_list.add_item("± %s" % str(entry.get("label", "")))
	for entry: Dictionary in _there_entries:
		there_list.add_item("← %s" % str(entry.get("label", "")))
	if bool(result.get("identical", false)):
		summary_label.text = "Identical - this sheet and %s compile to the same script." % other_path.get_file()
	else:
		summary_label.text = "%d row(s) differ here, %d row(s) differ in %s. Double-click a row on the left to jump to it, or one on the right to bring it over." % [
			_here_entries.size(), _there_entries.size(), other_path.get_file()]
	return result


func _report_error(message: String) -> Dictionary:
	if summary_label != null:
		summary_label.text = message
	_dock._set_status("Compare With: %s" % message, true)
	return {"error": message}


func _jump_to_entry(entries: Array, index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	var resource: Variant = (entries[index] as Dictionary).get("resource")
	if not (resource is Resource):
		return
	var view: EventSheetViewport = _dock._active_view()
	if view != null:
		view.reveal_resource(resource as Resource)
		view.select_resource(resource as Resource)


## Copies the compared side's row at `index` into this sheet as ordinary rows, in ONE undo step -
## the whole top-level row that owns the changed emission, duplicated deeply with fresh row uids
## (the same shape a paste writes). Returns true when the sheet changed.
func bring_row_over(index: int) -> bool:
	if index < 0 or index >= _there_entries.size():
		return false
	var resource: Variant = (_there_entries[index] as Dictionary).get("resource")
	if not (resource is Resource):
		_dock._set_status("That entry's row is no longer available - run Compare again.", true)
		return false
	var owner: Resource = EventSheetSheetDiff.top_level_owner(_other_sheet, resource as Resource)
	if owner == null:
		_dock._set_status("That change isn't a row that can be copied over (it comes from the compared sheet's setup, not from an event).", true)
		return false
	var copy: Resource = owner.duplicate(true)
	# Every event inside the copy - a group's children included - gets a fresh uid. Two rows sharing
	# one event_uid would make the Event Trace highlight and the hit-count tally answer for both.
	_refresh_event_uids(copy)
	# A row is not portable on its own: it may read sheet variables the compared sheet declares and
	# this one does not, and a row referencing an undeclared member compiles to broken GDScript. The
	# missing ones are CREATED, never overwritten - the same rule the paste path follows.
	var required: Dictionary = EventSheetSnippet._collect_required_variables([copy], _other_sheet)
	var created: Dictionary = {"count": 0}
	var changed: bool = _dock._perform_undoable_sheet_edit("Bring Row Over", func() -> bool:
		for variable_name: Variant in required.keys():
			if not _dock._current_sheet.variables.has(variable_name):
				_dock._current_sheet.variables[variable_name] = required[variable_name]
				created["count"] = int(created["count"]) + 1
		_dock._current_sheet.events.append(copy)
		return true)
	if changed:
		var note: String = "" if int(created["count"]) == 0 \
			else " %d sheet variable(s) it needed came with it." % int(created["count"])
		_dock._mark_dirty("Brought one row over from the compared sheet - it is an ordinary row now, undo takes it back.%s" % note)
	return changed


## Fresh event uids across a copied top-level row, whether it is one event or a whole group.
func _refresh_event_uids(copy: Resource) -> void:
	if copy is EventRow:
		_dock._assign_fresh_event_uids(copy as EventRow)
		return
	if copy is EventGroup:
		var group: EventGroup = copy as EventGroup
		for child: Variant in (group.events if not group.events.is_empty() else group.rows):
			if child is Resource:
				_refresh_event_uids(child as Resource)
