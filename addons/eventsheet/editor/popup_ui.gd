# EventSheet - shared popup UI helpers.
#
# A single, consistent look for the plugin's dialogs (aligned "Label  [field]" rows, standard
# content margins, a standard form box) so every popup matches the Godot 4.7 editor styling
# instead of each one inventing its own margins + label placement. Pure factory helpers - they
# return controls the caller parents; they apply no logic of their own, so they are unit-testable.
@tool
class_name EventSheetPopupUI
extends RefCounted

const CONTENT_MARGIN := 12
const ROW_SEPARATION := 8
const LABEL_MIN_WIDTH := 120.0
## Default wrap width (px) for hint/wrapping labels. A ConfirmationDialog/AcceptDialog sizes to its
## content's MINIMUM, and an UNBOUNDED autowrap label reports a runaway one-glyph-per-line min height
## during the initial zero-width pass - which balloons the whole dialog. Giving the label a minimum
## width makes that pass wrap at a sane width while the label still wraps wider at runtime.
const HINT_WRAP_WIDTH := 360.0


## Hardens a CodeEdit against the most common user syntax errors: auto-CLOSES brackets and quotes (typing
## "(" inserts "()" with the caret inside, '"' inserts ""), so an unbalanced pair is hard to leave behind,
## and matching brackets highlight. Applied to every EDITABLE code field - the ƒx expression boxes and the
## GDScript-block dialog - so users (especially non-coders) rarely produce a bracket/quote syntax error in
## the first place. Pure setter on the passed control → unit-testable, safe headless.
static func configure_code_editor(edit: CodeEdit) -> void:
	if edit == null:
		return
	edit.auto_brace_completion_enabled = true
	edit.auto_brace_completion_highlight_matching = true
	edit.auto_brace_completion_pairs = {"(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"}


## An aligned "Label   [field]" row - the consistent form layout for the plugin's dialogs. The
## label takes a fixed leading width so stacked rows align; the field expands to fill the rest.
##
## Pass `tooltip` and the row explains itself on hover. It lands on the LABEL as well as the field,
## because the label is the part a puzzled user actually points at - a field name like "Inspector
## button" is exactly the kind of term that means nothing until someone says what it does. Note the
## mouse_filter: Godot Labels ignore the mouse by default, so a tooltip set on one never fires. Any
## caller passing a tooltip would silently get nothing without this line.
static func form_row(label_text: String, field: Control, label_min_width: float = LABEL_MIN_WIDTH,
		tooltip: String = "") -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(label_min_width, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if not tooltip.strip_edges().is_empty():
		label.tooltip_text = tooltip
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		# The field carries the same words, so hovering anywhere on the row answers the question - and
		# a field that already explains itself in its own terms keeps that more specific text.
		if field.tooltip_text.strip_edges().is_empty():
			field.tooltip_text = tooltip
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
## (wrap_width) so it never balloons a content-sized dialog - see HINT_WRAP_WIDTH. Pass a smaller
## wrap_width in a narrower dialog if the default would widen it.
static func hint_label(text: String, wrap_width: float = HINT_WRAP_WIDTH) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(wrap_width, 0.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.74)
	return label

## Inner padding (px) baked into a panel_section()'s background, so its contents don't touch the edges.
const PANEL_SECTION_PAD := 6.0


## Wraps `content` in a filled "inset card" - a PanelContainer whose background sits a touch darker than
## the dialog, with a hairline border + rounded corners (Godot's Create-New-Node side-pane look), so a
## section reads as a distinct sunken panel instead of floating on the dialog background. Use it to give
## the picker's Favorites/Recent/description areas real visual separation. The caller still sets the
## panel's size flags if it should expand.
static func panel_section(content: Control, pad: float = PANEL_SECTION_PAD) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = inset_panel_stylebox()
	style.set_content_margin_all(pad)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	return panel


## A section-title label for grouping a dialog into legible blocks - full opacity, a touch larger,
## tinted with the editor's accent so a section reads as a heading rather than just another form row.
## Falls back to a neutral blue outside the editor (headless tests / non-editor runtime).
static func section_header(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	var accent: Color = Color(0.58, 0.74, 1.0)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface != null and editor_interface.has_method("get_editor_theme"):
			var theme: Theme = editor_interface.get_editor_theme()
			if theme != null and theme.has_color("accent_color", "Editor"):
				accent = theme.get_color("accent_color", "Editor")
	label.add_theme_color_override("font_color", accent)
	return label


## A titled inset card - a section_header above panel_section(content). The standard "labelled section"
## block, so every dialog groups its content into the same legible, themed panels instead of a flat
## wall of rows. The caller still sets the returned panel's size flags if it should expand.
static func titled_card(title: String, content: Control, pad: float = PANEL_SECTION_PAD) -> PanelContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	box.add_child(section_header(title))
	box.add_child(content)
	return panel_section(box, pad)


## The StyleBoxFlat behind panel_section() (and any card that wants the matching look): a filled inset
## with a subtle border + 4px corners. Editor-theme-aware - the fill comes from the editor's `dark_color_2`
## (the same tone Godot's own inset panels use) and the border from `contrast_color_1`; both fall back to
## neutral dark values outside the editor (headless tests / non-editor runtime) so it never errors.
static func inset_panel_stylebox() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	var fill: Color = Color(0.12, 0.13, 0.16, 1.0)
	var border: Color = Color(1.0, 1.0, 1.0, 0.07)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface != null and editor_interface.has_method("get_editor_theme"):
			var theme: Theme = editor_interface.get_editor_theme()
			if theme != null:
				if theme.has_color("dark_color_2", "Editor"):
					fill = theme.get_color("dark_color_2", "Editor")
				if theme.has_color("contrast_color_1", "Editor"):
					var contrast: Color = theme.get_color("contrast_color_1", "Editor")
					border = Color(contrast.r, contrast.g, contrast.b, 0.22)
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	return box


## Fills `popup` with the suggestions whose text contains `filter_text` (case-insensitive;
## empty filter shows all). Each item's id is its index into the FULL list, so a pick maps
## back correctly even when filtered. The one shared filler behind every autocomplete
## combo (ACE params, Replace Object References, the match/switch case patterns).
static func fill_suggestion_popup(popup: PopupMenu, suggestions: PackedStringArray, filter_text: String) -> void:
	popup.clear()
	var needle: String = filter_text.strip_edges().to_lower()
	var any_added: bool = false
	for index: int in range(suggestions.size()):
		var suggestion: String = suggestions[index]
		if needle.is_empty() or suggestion.to_lower().contains(needle):
			popup.add_item(suggestion, index)
			any_added = true
	if not any_added:
		popup.add_item("(no match - keep typing)", -1)
		popup.set_item_disabled(popup.item_count - 1, true)


## The editable autocomplete combo's ▾ picker, fully wired to `edit` (event-sheet-style
## "Combo" with free text): opening rebuilds the (filtered) list from suggestions_provider
## - a Callable returning the CURRENT suggestions, so live lists (project feature tags,
## enum members) are never stale - picking inserts the suggestion and returns the caret,
## and Down-arrow in the field opens the popup (skipping a dead "(no match)"-only menu).
## The caller parents the returned MenuButton beside its LineEdit. One implementation for
## every combo in the plugin - the ACE params dialog, the Replace Object References To
## field, and the match/switch case patterns all attach through here.
static func autocomplete_combo(edit: LineEdit, suggestions_provider: Callable) -> MenuButton:
	var picker: MenuButton = MenuButton.new()
	picker.text = "▾"
	picker.tooltip_text = "Suggestions (you can still type any value)"
	var popup: PopupMenu = picker.get_popup()
	# The pool shown last: item ids index into THIS array, so a pick resolves against
	# exactly the list the user saw even if the live provider changes between calls.
	var shown: Dictionary = {"pool": PackedStringArray()}
	popup.about_to_popup.connect(func() -> void:
		shown["pool"] = PackedStringArray(suggestions_provider.call())
		fill_suggestion_popup(popup, shown["pool"], edit.text))
	# Whenever the popup closes (pick, Escape, click-away), return the caret to the field
	# so Enter still confirms the dialog and typing continues seamlessly.
	popup.popup_hide.connect(func() -> void: edit.grab_focus())
	popup.id_pressed.connect(func(picked_id: int) -> void:
		var pool: PackedStringArray = shown["pool"]
		if picked_id >= 0 and picked_id < pool.size():
			edit.text = pool[picked_id]
			edit.caret_column = edit.text.length()
			edit.grab_focus())
	# Down-arrow from the field opens the suggestions (keyboard-first authoring).
	edit.gui_input.connect(func(event: InputEvent) -> void:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.pressed and key_event.keycode == KEY_DOWN:
			shown["pool"] = PackedStringArray(suggestions_provider.call())
			fill_suggestion_popup(popup, shown["pool"], edit.text)
			# Don't pop a dead, disabled-only "(no match)" menu - keep the caret in the field.
			if popup.item_count == 1 and popup.is_item_disabled(0):
				edit.accept_event()
				return
			popup.position = Vector2i(edit.get_screen_position() + Vector2(0.0, edit.size.y))
			popup.reset_size()
			popup.popup()
			edit.accept_event())
	return picker
