# EventSheet — shared popup UI helpers.
#
# A single, consistent look for the plugin's dialogs (aligned "Label  [field]" rows, standard
# content margins, a standard form box) so every popup matches the Godot 4.7 editor styling
# instead of each one inventing its own margins + label placement. Pure factory helpers — they
# return controls the caller parents; they apply no logic of their own, so they are unit-testable.
@tool
class_name EventSheetPopupUI
extends RefCounted

const CONTENT_MARGIN := 12
const ROW_SEPARATION := 8
const LABEL_MIN_WIDTH := 120.0
## Default wrap width (px) for hint/wrapping labels. A ConfirmationDialog/AcceptDialog sizes to its
## content's MINIMUM, and an UNBOUNDED autowrap label reports a runaway one-glyph-per-line min height
## during the initial zero-width pass — which balloons the whole dialog. Giving the label a minimum
## width makes that pass wrap at a sane width while the label still wraps wider at runtime.
const HINT_WRAP_WIDTH := 360.0

## An aligned "Label   [field]" row — the consistent form layout for the plugin's dialogs. The
## label takes a fixed leading width so stacked rows align; the field expands to fill the rest.
static func form_row(label_text: String, field: Control, label_min_width: float = LABEL_MIN_WIDTH) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(label_min_width, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row

## A standard form VBox (consistent row separation) to hold form_row()s + helper labels.
static func form_box() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	return box

## Wraps content in a standard-margin container for a dialog/window body, so every popup has the
## same breathing room as the editor's own dialogs.
static func margined(content: Control, margin: int = CONTENT_MARGIN) -> MarginContainer:
	var box: MarginContainer = MarginContainer.new()
	box.add_theme_constant_override("margin_left", margin)
	box.add_theme_constant_override("margin_right", margin)
	box.add_theme_constant_override("margin_top", margin)
	box.add_theme_constant_override("margin_bottom", margin)
	box.add_child(content)
	return box

## A muted helper/hint label (the small explanatory text under a field). The autowrap is WIDTH-BOUNDED
## (wrap_width) so it never balloons a content-sized dialog — see HINT_WRAP_WIDTH. Pass a smaller
## wrap_width in a narrower dialog if the default would widen it.
static func hint_label(text: String, wrap_width: float = HINT_WRAP_WIDTH) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(wrap_width, 0.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.66)
	return label
