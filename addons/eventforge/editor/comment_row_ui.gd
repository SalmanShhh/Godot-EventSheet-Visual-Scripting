# EventForge — Comment row UI
# C3-style full-width section annotation / banner row.
# Renders as a warm amber banner aligned with the sheet grid.
@tool
extends PanelContainer
class_name CommentRowUI

signal comment_selected(row: CommentRowUI)
signal comment_delete_requested(row: CommentRowUI)
signal insert_comment_above_requested(row: CommentRowUI)
signal insert_comment_below_requested(row: CommentRowUI)
signal comment_text_changed(row: CommentRowUI, text: String)
signal comment_text_submitted(row: CommentRowUI, text: String)
signal comment_drop_requested(target_row: CommentRowUI, source_comment: CommentRow, insert_after: bool)

const INSERT_CONTROL_DIM_ALPHA: float = 0.46
## Drop / drag-preview colours
const DROP_HIGHLIGHT_COLOR: Color = Color(1.0, 0.86, 0.40, 0.18)
const COMMENT_PREVIEW_BG_COLOR: Color = Color(0.17, 0.13, 0.06, 0.96)
const COMMENT_PREVIEW_BORDER_COLOR: Color = Color(0.90, 0.68, 0.18, 0.82)

## Banner accent colours — warm amber matching C3's yellow comment banner.
const COMMENT_ACCENT: Color = Color(0.90, 0.68, 0.18, 0.90)
const COMMENT_BG: Color = Color(0.156, 0.128, 0.064, 1.0)
const COMMENT_BG_HOVER: Color = Color(0.192, 0.158, 0.080, 1.0)
const COMMENT_BG_SELECTED: Color = Color(0.228, 0.188, 0.096, 1.0)
const COMMENT_BORDER: Color = Color(0.408, 0.324, 0.172, 1.0)
const COMMENT_BORDER_HOVER: Color = Color(0.596, 0.476, 0.246, 1.0)
const COMMENT_BORDER_SELECTED: Color = Color(0.840, 0.680, 0.312, 1.0)

var comment_row: CommentRow = null

var _left_accent: ColorRect = null
var _comment_text_edit: LineEdit = null
var _depth: int = 0
var _selected: bool = false
var _hovered: bool = false
var _insert_above_btn: Button = null
var _insert_below_btn: Button = null
var _edit_btn: Button = null
var _delete_btn: Button = null
## Drop position indicator.  -1.0 = hidden; 0..1 = fraction of row height (< 0.5 → top, ≥ 0.5 → bottom).
var _drop_indicator_frac: float = -1.0
## Semi-transparent tint overlay drawn on top of row contents during drag-hover.
var _drop_highlight_rect: ColorRect = null

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	_apply_row_style()

	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 4)
	add_child(line)

	# Left accent strip — 4px amber bar that makes comment rows read as section
	# annotations (C3 "yellow banner" visual language).
	# Also satisfies lane-divider presence test (ColorRect min_width >= 2).
	_left_accent = ColorRect.new()
	_left_accent.custom_minimum_size = Vector2(4, 0)
	_left_accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_accent.color = COMMENT_ACCENT
	_left_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_left_accent)

	# "# " section-marker prefix — cleaner C3 banner feel than "//"
	var prefix: Label = Label.new()
	prefix.text = "#"
	prefix.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40))
	prefix.add_theme_font_size_override("font_size", 12)
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(prefix)

	_comment_text_edit = LineEdit.new()
	_comment_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comment_text_edit.placeholder_text = "Section comment…"
	_comment_text_edit.tooltip_text = "Edit inline comment text"
	_comment_text_edit.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	_comment_text_edit.add_theme_color_override("font_placeholder_color", Color(0.66, 0.56, 0.36))
	_comment_text_edit.add_theme_font_size_override("font_size", 11)
	# Transparent background so comment row colour shows through.
	var le_style: StyleBoxFlat = StyleBoxFlat.new()
	le_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	le_style.set_border_width_all(0)
	le_style.set_content_margin_all(2)
	_comment_text_edit.add_theme_stylebox_override("normal", le_style)
	_comment_text_edit.add_theme_stylebox_override("read_only", le_style)
	_comment_text_edit.add_theme_stylebox_override("focus", le_style)
	_comment_text_edit.connect("text_changed", _on_comment_text_changed)
	_comment_text_edit.connect("text_submitted", _on_comment_text_submitted)
	_comment_text_edit.connect("focus_entered", _on_comment_text_focus_entered)
	line.add_child(_comment_text_edit)

	_insert_above_btn = Button.new()
	_insert_above_btn.text = "+↑"
	_insert_above_btn.flat = true
	_insert_above_btn.tooltip_text = "Insert comment above this row"
	_insert_above_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insert_above_btn.add_theme_color_override("font_color", Color(0.84, 0.72, 0.42))
	_insert_above_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.58))
	_insert_above_btn.connect("pressed", _on_insert_above_pressed)
	line.add_child(_insert_above_btn)

	_insert_below_btn = Button.new()
	_insert_below_btn.text = "+↓"
	_insert_below_btn.flat = true
	_insert_below_btn.tooltip_text = "Insert comment below this row"
	_insert_below_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insert_below_btn.add_theme_color_override("font_color", Color(0.84, 0.72, 0.42))
	_insert_below_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.58))
	_insert_below_btn.connect("pressed", _on_insert_below_pressed)
	line.add_child(_insert_below_btn)

	_edit_btn = Button.new()
	_edit_btn.text = "✎"
	_edit_btn.flat = true
	_edit_btn.tooltip_text = "Focus comment text"
	_edit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_edit_btn.add_theme_color_override("font_color", Color(0.82, 0.70, 0.44))
	_edit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.58))
	_edit_btn.connect("pressed", _on_pressed)
	line.add_child(_edit_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "×"
	_delete_btn.flat = true
	_delete_btn.tooltip_text = "Delete comment"
	_delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_delete_btn.add_theme_color_override("font_color", Color(0.80, 0.42, 0.42))
	_delete_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))
	_delete_btn.add_theme_font_size_override("font_size", 12)
	_delete_btn.connect("pressed", _on_delete_pressed)
	line.add_child(_delete_btn)

	mouse_filter = Control.MOUSE_FILTER_STOP
	connect("gui_input", _on_gui_input)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	_apply_affordance_state()

	# Drop-position highlight overlay — amber tint composited above row contents.
	# Mouse-ignored so pointer events still reach interactive children.
	_drop_highlight_rect = ColorRect.new()
	_drop_highlight_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_drop_highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_highlight_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drop_highlight_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_drop_highlight_rect)

func set_depth(depth: int) -> void:
	_depth = max(0, depth)
	_apply_row_style()

func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_row_style()
	_apply_affordance_state()

func _apply_row_style() -> void:
	var palette: Dictionary = _get_comment_palette()
	var base_bg: Color = palette.get("bg", COMMENT_BG)
	var hover_bg: Color = palette.get("hover_bg", COMMENT_BG_HOVER)
	var selected_bg: Color = palette.get("selected_bg", COMMENT_BG_SELECTED)
	var border: Color = palette.get("border", COMMENT_BORDER)
	var hover_border: Color = palette.get("hover_border", COMMENT_BORDER_HOVER)
	var selected_border: Color = palette.get("selected_border", COMMENT_BORDER_SELECTED)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if _selected:
		style.bg_color = _apply_depth_tint(selected_bg)
		style.border_color = selected_border
	elif _hovered:
		style.bg_color = _apply_depth_tint(hover_bg)
		style.border_color = hover_border
	else:
		style.bg_color = _apply_depth_tint(base_bg)
		style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 0  # accent handled by left_accent ColorRect
	style.set_corner_radius_all(0)
	style.set_content_margin_all(0)
	style.set_content_margin(SIDE_TOP, 3)
	style.set_content_margin(SIDE_BOTTOM, 3)
	style.set_content_margin(SIDE_RIGHT, 4)
	add_theme_stylebox_override("panel", style)
	if _left_accent != null:
		_left_accent.color = palette.get("accent", COMMENT_ACCENT)

func _apply_depth_tint(base: Color) -> Color:
	var depth_factor: float = float(min(_depth, 4))
	if depth_factor <= 0.0:
		return base
	var lighten_amount: float = depth_factor * 0.010
	return Color(
		min(base.r + lighten_amount, 1.0),
		min(base.g + lighten_amount, 1.0),
		min(base.b + lighten_amount, 1.0),
		base.a
	)

func _get_comment_palette() -> Dictionary:
	var palette_key: String = _resolve_comment_palette_key()
	match palette_key:
		"yellow":
			return {
				"accent": COMMENT_ACCENT,
				"bg": COMMENT_BG,
				"hover_bg": COMMENT_BG_HOVER,
				"selected_bg": COMMENT_BG_SELECTED,
				"border": COMMENT_BORDER,
				"hover_border": COMMENT_BORDER_HOVER,
				"selected_border": COMMENT_BORDER_SELECTED
			}
		"blue":
			return {
				"accent": Color(0.38, 0.66, 0.96, 0.92),
				"bg": Color(0.078, 0.120, 0.168, 1.0),
				"hover_bg": Color(0.098, 0.148, 0.202, 1.0),
				"selected_bg": Color(0.120, 0.176, 0.240, 1.0),
				"border": Color(0.210, 0.350, 0.520, 1.0),
				"hover_border": Color(0.300, 0.480, 0.670, 1.0),
				"selected_border": Color(0.420, 0.620, 0.840, 1.0)
			}
		"green":
			return {
				"accent": Color(0.44, 0.84, 0.54, 0.92),
				"bg": Color(0.082, 0.154, 0.102, 1.0),
				"hover_bg": Color(0.106, 0.190, 0.126, 1.0),
				"selected_bg": Color(0.130, 0.224, 0.148, 1.0),
				"border": Color(0.206, 0.430, 0.258, 1.0),
				"hover_border": Color(0.286, 0.560, 0.346, 1.0),
				"selected_border": Color(0.390, 0.700, 0.430, 1.0)
			}
		"red":
			return {
				"accent": Color(0.94, 0.48, 0.44, 0.92),
				"bg": Color(0.186, 0.088, 0.082, 1.0),
				"hover_bg": Color(0.226, 0.106, 0.098, 1.0),
				"selected_bg": Color(0.264, 0.124, 0.114, 1.0),
				"border": Color(0.520, 0.206, 0.192, 1.0),
				"hover_border": Color(0.690, 0.278, 0.258, 1.0),
				"selected_border": Color(0.850, 0.372, 0.336, 1.0)
			}
		"orange":
			return {
				"accent": Color(0.96, 0.66, 0.32, 0.92),
				"bg": Color(0.198, 0.120, 0.070, 1.0),
				"hover_bg": Color(0.232, 0.146, 0.086, 1.0),
				"selected_bg": Color(0.268, 0.168, 0.100, 1.0),
				"border": Color(0.570, 0.336, 0.170, 1.0),
				"hover_border": Color(0.730, 0.442, 0.214, 1.0),
				"selected_border": Color(0.870, 0.536, 0.268, 1.0)
			}
		"grey":
			return {
				"accent": Color(0.70, 0.76, 0.82, 0.92),
				"bg": Color(0.126, 0.136, 0.150, 1.0),
				"hover_bg": Color(0.148, 0.160, 0.176, 1.0),
				"selected_bg": Color(0.168, 0.184, 0.202, 1.0),
				"border": Color(0.320, 0.344, 0.376, 1.0),
				"hover_border": Color(0.430, 0.464, 0.502, 1.0),
				"selected_border": Color(0.560, 0.604, 0.654, 1.0)
			}
		_:
			return {
				"accent": COMMENT_ACCENT,
				"bg": COMMENT_BG,
				"hover_bg": COMMENT_BG_HOVER,
				"selected_bg": COMMENT_BG_SELECTED,
				"border": COMMENT_BORDER,
				"hover_border": COMMENT_BORDER_HOVER,
				"selected_border": COMMENT_BORDER_SELECTED
			}

func _resolve_comment_palette_key() -> String:
	if comment_row == null:
		return "yellow"
	var from_tag: String = str(comment_row.color_tag).strip_edges().to_lower()
	if not from_tag.is_empty():
		return from_tag
	match comment_row.style:
		CommentRow.CommentStyle.NOTE:
			return "blue"
		CommentRow.CommentStyle.TODO:
			return "orange"
		CommentRow.CommentStyle.WARNING:
			return "red"
		CommentRow.CommentStyle.SECTION:
			return "grey"
		_:
			return "yellow"

func _apply_affordance_state() -> void:
	var controls_alpha: float = 1.0 if (_hovered or _selected) else INSERT_CONTROL_DIM_ALPHA
	if _insert_above_btn != null:
		_insert_above_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
	if _insert_below_btn != null:
		_insert_below_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
	if _edit_btn != null:
		_edit_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
	if _delete_btn != null:
		_delete_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)

func refresh() -> void:
	if comment_row == null or _comment_text_edit == null:
		return
	_apply_row_style()
	var text: String = comment_row.text
	if _comment_text_edit.text != text and not _comment_text_edit.has_focus():
		_comment_text_edit.text = text

func _on_pressed() -> void:
	comment_selected.emit(self)
	if _comment_text_edit != null:
		_comment_text_edit.grab_focus()
		_comment_text_edit.caret_column = _comment_text_edit.text.length()

func _on_delete_pressed() -> void:
	comment_delete_requested.emit(self)

func _on_insert_above_pressed() -> void:
	insert_comment_above_requested.emit(self)

func _on_insert_below_pressed() -> void:
	insert_comment_below_requested.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			comment_selected.emit(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if comment_row == null:
		return null
	var payload: Dictionary = {
		"type": "event_comment_row",
		"source_comment": comment_row
	}
	# Styled drag preview — amber banner colours matching comment row identity.
	var preview: PanelContainer = PanelContainer.new()
	var preview_style: StyleBoxFlat = StyleBoxFlat.new()
	preview_style.bg_color = COMMENT_PREVIEW_BG_COLOR
	preview_style.set_border_width_all(1)
	preview_style.border_color = COMMENT_PREVIEW_BORDER_COLOR
	preview_style.set_corner_radius_all(3)
	preview_style.set_content_margin_all(5)
	preview.add_theme_stylebox_override("panel", preview_style)
	var preview_label: Label = Label.new()
	preview_label.text = "# %s" % comment_row.text
	preview_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	preview_label.add_theme_font_size_override("font_size", 11)
	preview.add_child(preview_label)
	set_drag_preview(preview)
	return payload

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if comment_row == null or not (data is Dictionary):
		_clear_drop_indicator()
		return false
	var payload: Dictionary = data as Dictionary
	if str(payload.get("type", "")) != "event_comment_row":
		_clear_drop_indicator()
		return false
	var source_comment: Variant = payload.get("source_comment", null)
	if not (source_comment is CommentRow) or source_comment == comment_row:
		_clear_drop_indicator()
		return false
	var frac: float = at_position.y / max(size.y, 1.0)
	_set_drop_indicator(frac)
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	_clear_drop_indicator()
	if not (data is Dictionary):
		return
	var payload: Dictionary = data as Dictionary
	if str(payload.get("type", "")) != "event_comment_row":
		return
	var source_comment: Variant = payload.get("source_comment", null)
	if not (source_comment is CommentRow) or source_comment == comment_row:
		return
	var insert_after: bool = at_position.y >= (size.y * 0.5)
	comment_drop_requested.emit(self, source_comment as CommentRow, insert_after)

## Sets the drop-position indicator fractional position and shows the tint overlay.
func _set_drop_indicator(frac: float) -> void:
	_drop_indicator_frac = frac
	_update_drop_highlight()
	set_process(true)

## Clears the drop-position indicator and hides the tint overlay.
func _clear_drop_indicator() -> void:
	if _drop_indicator_frac < 0.0:
		return
	_drop_indicator_frac = -1.0
	_update_drop_highlight()
	set_process(false)

## Syncs the highlight overlay colour to the current drop-indicator state.
func _update_drop_highlight() -> void:
	if _drop_highlight_rect == null:
		return
	_drop_highlight_rect.color = DROP_HIGHLIGHT_COLOR if _drop_indicator_frac >= 0.0 else Color(0.0, 0.0, 0.0, 0.0)

func _process(_delta: float) -> void:
	if _drop_indicator_frac >= 0.0 and not get_viewport().gui_is_dragging():
		_clear_drop_indicator()

## Moves keyboard focus directly to the inline text edit for fast authoring.
## Useful for programmatic focus after inserting a new comment row.
func grab_text_focus() -> void:
	if _comment_text_edit != null:
		_comment_text_edit.grab_focus()
		_comment_text_edit.caret_column = _comment_text_edit.text.length()

func _on_comment_text_focus_entered() -> void:
	comment_selected.emit(self)

func _on_comment_text_changed(text: String) -> void:
	comment_text_changed.emit(self, text)

func _on_comment_text_submitted(text: String) -> void:
	comment_text_submitted.emit(self, text)

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_row_style()
	_apply_affordance_state()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_row_style()
	_apply_affordance_state()
