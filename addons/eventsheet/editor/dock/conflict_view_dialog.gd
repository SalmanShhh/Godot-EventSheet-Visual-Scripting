@tool
class_name EventSheetConflictViewDialog
extends RefCounted
# The conflict view - a merge conflict shown as events, picked one event at a time.
#
# Opening a script a merge left unresolved used to mean reading marker lines. This window shows the
# conflicted region as two columns of events, OURS beside THEIRS: the events both sides agree on are
# greyed (there is nothing to decide about them) and only the differing ones are a question, each
# with its own Keep ours / Keep theirs / Keep both. Everything outside the region is not shown here
# at all, because it is not in question and it is not touched.
#
# All the reading and all the resolution live in EventSheetConflictRegions (static, pure, pinned
# headless); this file is the shell: two columns, a choice per pair, and the Save that writes the
# resolved file back with no markers in it and every byte outside the region exactly as it was.
#
# Built lazily and by path from the menu, so nothing here sits in the editor's boot path.

var _dock: Control = null

var window: Window = null
var heading_label: Label = null
var rows_box: VBoxContainer = null
var save_button: Button = null

## The file being resolved and what it said when it was opened.
var _path: String = ""
var _source: String = ""
var _regions: Array[Dictionary] = []
## One Array of per-pair choices per region, in region order.
var _choices: Array = []


func init(dock: Control) -> void:
	_dock = dock


## Points the window at a file. Returns false when there is nothing to resolve, so a caller can ask
## on every open without deciding for itself what a conflict looks like.
func open_path(path: String) -> bool:
	_path = path
	_source = FileAccess.get_file_as_string(path)
	_regions = EventSheetConflictRegions.find(_source)
	if _regions.is_empty():
		return false
	_choices.clear()
	for region: Dictionary in _regions:
		_choices.append(EventSheetConflictRegions.whole_side_choices(region, EventSheetConflictRegions.KEEP_OURS))
	build()
	_refresh()
	window.popup_centered(Vector2i(920, 620))
	return true


## Builds the window without popping it, so a test drives the real widgets headlessly.
func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = EventSheetL10n.translate("Resolve Conflict")
	window.size = Vector2i(920, 620)
	window.min_size = Vector2i(620, 380)
	window.close_requested.connect(func() -> void: window.hide())
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	heading_label = Label.new()
	body.add_child(heading_label)
	body.add_child(EventSheetPopupUI.hint_label(translate_hint()))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A ScrollContainer reports its CONTENT's size as nothing, so without a floor of its own the card
	# above it collapses to a hairline and the two columns are invisible.
	scroll.custom_minimum_size = Vector2(0.0, 300.0)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)
	body.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Ours and theirs"), scroll))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	save_button = Button.new()
	save_button.text = EventSheetL10n.translate("Save resolved file")
	save_button.tooltip_text = EventSheetL10n.translate("Write the file back with the markers gone. Every byte outside the conflicted region is left exactly as it is.")
	save_button.pressed.connect(_save_resolved)
	buttons.add_child(save_button)
	body.add_child(buttons)
	var margined: MarginContainer = EventSheetPopupUI.margined(body)
	margined.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(margined)
	_dock.add_child(window)


static func translate_hint() -> String:
	return EventSheetL10n.translate("Events both sides agree on are greyed - there is nothing to decide about them. Pick one of the rest per event.")


func _refresh() -> void:
	heading_label.text = EventSheetL10n.translate("%s - %d to resolve") % [_path.get_file(), _regions.size()]
	for child: Node in rows_box.get_children():
		child.queue_free()
	for region: Dictionary in _regions:
		var region_index: int = int(region["index"])
		rows_box.add_child(EventSheetPopupUI.section_header(EventSheetConflictRegions.region_heading(region)))
		var pairs: Array[Dictionary] = EventSheetConflictRegions.side_by_side(region)
		for pair_index: int in pairs.size():
			rows_box.add_child(_pair_row(region_index, pair_index, pairs[pair_index]))


## One line of the two columns: what ours calls the event, what theirs calls it, and the choice.
func _pair_row(region_index: int, pair_index: int, pair: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var ours: Label = Label.new()
	ours.text = _side_label(pair["ours"])
	ours.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ours.clip_text = true
	var theirs: Label = Label.new()
	theirs.text = _side_label(pair["theirs"])
	theirs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theirs.clip_text = true
	row.add_child(ours)
	row.add_child(theirs)
	if bool(pair["same"]):
		ours.modulate = Color(1.0, 1.0, 1.0, 0.45)
		theirs.modulate = Color(1.0, 1.0, 1.0, 0.45)
		row.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("both the same"), 160.0))
		return row
	var picker: OptionButton = OptionButton.new()
	picker.add_item(EventSheetL10n.translate("Keep ours"), 0)
	picker.add_item(EventSheetL10n.translate("Keep theirs"), 1)
	picker.add_item(EventSheetL10n.translate("Keep both"), 2)
	picker.select(_choice_index(region_index, pair_index))
	picker.item_selected.connect(func(selected: int) -> void:
		set_choice(region_index, pair_index, [EventSheetConflictRegions.KEEP_OURS,
			EventSheetConflictRegions.KEEP_THEIRS, EventSheetConflictRegions.KEEP_BOTH][selected]))
	row.add_child(picker)
	return row


func _choice_index(region_index: int, pair_index: int) -> int:
	var choices: Array = _choices[region_index] as Array
	var choice: String = str(choices[pair_index]) if pair_index < choices.size() else EventSheetConflictRegions.KEEP_OURS
	match choice:
		EventSheetConflictRegions.KEEP_THEIRS:
			return 1
		EventSheetConflictRegions.KEEP_BOTH:
			return 2
	return 0


## Records one pick. Public so a test can drive the window without touching a widget.
func set_choice(region_index: int, pair_index: int, choice: String) -> void:
	if region_index < 0 or region_index >= _choices.size():
		return
	var choices: Array = _choices[region_index] as Array
	while choices.size() <= pair_index:
		choices.append(EventSheetConflictRegions.KEEP_OURS)
	choices[pair_index] = choice
	_choices[region_index] = choices


static func _side_label(block: Variant) -> String:
	if block == null:
		return "-"
	return str((block as Dictionary).get("label", ""))


## The resolved text for whatever is picked right now. Public so the Save and the test agree.
func resolved_text() -> String:
	return str(EventSheetConflictRegions.resolve(_source, _choices)["text"])


func _save_resolved() -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		_dock._set_status(EventSheetL10n.translate("Could not write %s.") % _path.get_file(), true)
		return
	file.store_string(resolved_text())
	file.close()
	window.hide()
	_dock._set_status(EventSheetL10n.translate("Resolved %s - the markers are gone and the rest of the file is untouched.") % _path.get_file())
	_dock._load_sheet_from_path(_path)
