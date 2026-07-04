@tool
class_name EventSheetLookGalleryDialog
extends AcceptDialog

## Choose an Inspector look BY PICTURE: one tile per preset, each showing a
## non-interactive miniature of the real Inspector widget plus a one-line
## explanation. A beginner recognizes a slider or a layer grid long before they
## know the phrase "export hint", so the gallery fronts the same presets the
## Variable dialog's dropdown offers (both read EventSheetInspectorLooks, and
## choosing a tile drives the SAME dropdown, so the apply path stays single).

signal look_chosen(look_id: String)

const _COLUMNS := 3

var _grid: GridContainer = null
var _current_look_id: String = ""


func _init() -> void:
	title = "Choose an Inspector look"
	ok_button_text = "Close"
	min_size = Vector2i(760, 520)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720.0, 460.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = _COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)


## Rebuilds the tile grid for a variable type (popup-free so tests can count tiles).
## The "Default field" tile leads, mirroring the dropdown's first entry.
func rebuild_for_type(type_name: String, current_look_id: String) -> void:
	_current_look_id = current_look_id
	# Freed immediately (not queue_free) so a same-frame reopen never shows both
	# generations of tiles; rebuild is never reached from inside a tile's own signal.
	while _grid.get_child_count() > 0:
		var stale_tile: Node = _grid.get_child(0)
		_grid.remove_child(stale_tile)
		stale_tile.free()
	_grid.add_child(_make_tile("", "Default field", "A plain field matching the type - no special look."))
	for preset: Dictionary in EventSheetInspectorLooks.for_type(type_name):
		_grid.add_child(_make_tile(
			str(preset.get("id")),
			str(preset.get("label")),
			str(preset.get("sentence", ""))
		))


func open_for_type(type_name: String, current_look_id: String) -> void:
	rebuild_for_type(type_name, current_look_id)
	popup_centered()


func tile_count() -> int:
	return _grid.get_child_count()


## The look ids currently on display, in tile order ("" = the Default tile).
func tile_look_ids() -> Array:
	var output: Array = []
	for tile in _grid.get_children():
		output.append(str((tile as Node).get_meta("look_id", "")))
	return output


func _make_tile(look_id: String, label_text: String, sentence: String) -> Button:
	var tile := Button.new()
	tile.set_meta("look_id", look_id)
	tile.custom_minimum_size = Vector2(228.0, 128.0)
	tile.toggle_mode = true
	tile.button_pressed = look_id == _current_look_id
	tile.pressed.connect(func() -> void:
		look_chosen.emit(look_id)
		hide())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var preview_holder := CenterContainer.new()
	preview_holder.custom_minimum_size = Vector2(0.0, 56.0)
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(EventSheetInspectorLooks.build_preview(look_id))
	column.add_child(preview_holder)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	var sentence_label := Label.new()
	sentence_label.text = sentence
	sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sentence_label.add_theme_font_size_override("font_size", 11)
	sentence_label.modulate = Color(1.0, 1.0, 1.0, 0.65)
	sentence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sentence_label)
	return tile
