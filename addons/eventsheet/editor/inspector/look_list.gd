# Godot EventSheets - the list the Variable window picks an Inspector look from.
#
# Each look is a row with a small picture of what it draws, its name in bold and one grey sentence,
# under a heading that says whose it is: Godot's own, EventSheets', or the project's. The list shows
# the choices the window's option button holds and writes the pick back to it, so everything that
# reads the option keeps working; the option itself stays out of sight.
@tool
class_name EventSheetLookList
extends ScrollContainer

## How many rows are showing before the list scrolls.
const VISIBLE_ROWS: int = 5
## The least a row's height is, in lines of text; a row whose sentence wraps further grows past it.
const ROW_LINES: float = 3.0
## How strongly the accent shows under the pointer, as an opacity.
const HOVER_ALPHA: float = 0.25

var _option: OptionButton = null
var _column: VBoxContainer = null
var _group: ButtonGroup = ButtonGroup.new()
var _rows: Array[Button] = []
var _syncing: bool = false


func _init(option: OptionButton = null) -> void:
	_option = option
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = row_height() * VISIBLE_ROWS
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_column)


func row_height() -> float:
	return EventSheetLookStyle.font().get_height(EventSheetLookStyle.font_size()) * ROW_LINES + EventSheetLookStyle.px(8.0)


## How tall a row is whose content (the picture, the title and the wrapped sentence) needs `content`
## pixels: the content and a little air, and never less than the row's least height.
func fitted_height(content: float) -> float:
	return maxf(row_height(), content + EventSheetLookStyle.px(8.0))


## The heading a look sits under: "own" (Godot's), "ours" (shipped with the plugin) or "project".
static func group_of(look_id: String) -> String:
	if look_id.is_empty() or look_id == "written":
		return "own"
	var look: Dictionary = EventSheetInspectorLooks.by_id(look_id)
	match str(look.get("source", "")):
		"shipped":
			return "ours"
		"project":
			return "project"
	return "own"


## What the list shows, one entry per option item in the order the rows appear: the item's index,
## the look id, the heading it sits under, its name, its one sentence and whether it is the pick.
## The rows are built from this and a test reads it without building a row.
static func model(option: OptionButton) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for group: String in ["own", "ours", "project"]:
		for index: int in range(option.item_count):
			var look_id: String = str(option.get_item_metadata(index))
			if group_of(look_id) != group:
				continue
			entries.append({"index": index, "id": look_id, "group": group, "title": option.get_item_text(index),
				"sentence": option.get_item_tooltip(index).get_slice("
", 0), "selected": index == option.selected})
	return entries


## Rebuilds the rows from the option's items.
func rebuild() -> void:
	for old: Node in _column.get_children():
		_column.remove_child(old)
		old.queue_free()
	_rows.clear()
	var words: Dictionary = {"own": EventSheetL10n.translate("Godot's own"), "ours": EventSheetL10n.translate("EventSheets looks"),
		"project": EventSheetL10n.translate("In your project")}
	var heading_group: String = ""
	for entry: Dictionary in model(_option):
		if str(entry["group"]) != heading_group:
			heading_group = str(entry["group"])
			var heading: Label = Label.new()
			heading.text = words[heading_group]
			heading.add_theme_font_override("font", EventSheetLookStyle.bold_font())
			heading.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
			_column.add_child(heading)
		var row: Button = _make_row(int(entry["index"]))
		_column.add_child(row)
		_rows.append(row)
	sync_selection()


## A fill with no outline: the editor's own box for the state with its border removed and its
## colour taken from `fill`.
static func fill_box(fill: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	var theme_box: StyleBoxFlat = EventSheetLookStyle.typed_box(&"normal", &"Button") as StyleBoxFlat
	if theme_box != null:
		box = theme_box.duplicate() as StyleBoxFlat
	box.set_border_width_all(0)
	box.bg_color = fill
	box.set_content_margin_all(0.0)
	return box


func _make_row(index: int) -> Button:
	var look_id: String = str(_option.get_item_metadata(index))
	var row: Button = Button.new()
	row.toggle_mode = true
	row.button_group = _group
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = row_height()
	row.set_meta("option_index", index)
	row.tooltip_text = _option.get_item_tooltip(index)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var picked: StyleBoxFlat = fill_box(EventSheetLookStyle.accent())
	for state: String in ["pressed", "hover_pressed"]:
		row.add_theme_stylebox_override(state, picked)
	var hovered: Color = EventSheetLookStyle.accent()
	hovered.a = HOVER_ALPHA
	row.add_theme_stylebox_override("hover", fill_box(hovered))
	row.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var inside: HBoxContainer = HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.offset_left = EventSheetLookStyle.px(8.0)
	inside.offset_right = -EventSheetLookStyle.px(8.0)
	inside.add_theme_constant_override("separation", int(EventSheetLookStyle.px(10.0)))
	var mini: Control = _MiniPicture.new(look_id)
	mini.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inside.add_child(mini)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	var title: Label = Label.new()
	title.text = _option.get_item_text(index)
	title.add_theme_font_override("font", EventSheetLookStyle.bold_font())
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(title)
	var sentence: Label = Label.new()
	sentence.text = _option.get_item_tooltip(index).get_slice("
", 0)
	sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sentence.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
	sentence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(sentence)
	inside.add_child(words)
	row.add_child(inside)
	# The row is as tall as what it holds: its sentence wraps to the width the window gives it, so a
	# longer sentence or a narrower window grows the row instead of running under the next one.
	var fit_height: Callable = func() -> void:
		if is_instance_valid(row) and is_instance_valid(inside):
			row.custom_minimum_size.y = fitted_height(inside.get_combined_minimum_size().y)
	inside.minimum_size_changed.connect(fit_height)
	fit_height.call_deferred()
	row.toggled.connect(func(on: bool) -> void:
		var on_accent: Color = EventSheetLookStyle.ink_on_accent()
		title.add_theme_color_override("font_color", on_accent if on else EventSheetLookStyle.ink())
		sentence.add_theme_color_override("font_color", on_accent if on else EventSheetLookStyle.quiet())
		if on and not _syncing:
			_pick(index))
	return row


func _pick(index: int) -> void:
	_option.select(index)
	_option.item_selected.emit(index)


## Makes the row of the option's current choice the pressed one.
func sync_selection() -> void:
	if _option == null or _option.selected < 0:
		return
	_syncing = true
	for row: Button in _rows:
		row.set_pressed(int(row.get_meta("option_index")) == _option.selected)
	_syncing = false
	_show_selected.call_deferred()


## Scrolls the list so the chosen look is in view, once the rows have their places.
func _show_selected() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	for row: Button in _rows:
		if is_instance_valid(row) and row.button_pressed:
			ensure_control_visible(row)
			return


## The look ids in the order the rows show them, for a test to read.
func look_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for row: Button in _rows:
		ids.append(str(_option.get_item_metadata(int(row.get_meta("option_index")))))
	return ids


## The small picture at the left of a row.
class _MiniPicture:
	extends Control
	var _look_id: String = ""

	func _init(look_id: String) -> void:
		_look_id = look_id
		custom_minimum_size = Vector2(EventSheetLookStyle.px(EventSheetLookMinis.WIDTH), EventSheetLookStyle.px(EventSheetLookMinis.HEIGHT))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		EventSheetLookMinis.draw_mini(self, Rect2(Vector2.ZERO, size), _look_id, EventSheetLookMinis.theme_colours())
