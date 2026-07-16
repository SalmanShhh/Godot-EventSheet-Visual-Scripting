# Godot EventSheets - sheet-function dialog / "ACE Studio" (event-sheet style)
#
# Authors an EventFunction from a popup, the way an "Add function" dialog does - reframed so a
# non-programmer designs a behaviour's PUBLIC VERB without meeting the words "func" or "return type":
#  • "What kind of verb is this?" is three plain-language CARDS - Does something (Action) / Is it
#    true? (Condition) / A value (Expression) - a friendly restyle of the old "Usable as" toggle. The
#    chosen card sets the return type (void / bool / the chosen value type) exactly as before.
#  • A LIVE PICKER PREVIEW ("this is what other people will see") renders the verb as it will appear
#    in other sheets' pickers - role badge, name, param chips, category chip - updating per keystroke.
#  • A quiet "Ships as:" line shows the exact generated `func` signature (built from the SAME compiler
#    formatters, so it can never disagree with the codegen) - the trust surface for a Godot dev.
#  • Parameters are event-sheet rows: name · type · default value · description.
#  • "Run only when" adds guard conditions (GDScript boolean expressions) that wrap the body in an `if`.
#  • Expose-as-ACE publishes it into other sheets' pickers.
#
# The
# `_usable_option` / `_value_type_option` OptionButtons remain the backing model (hidden) so
# build_function_data() and the unit tests that drive them by index are unchanged.
@tool
class_name EventSheetFunctionDialog
extends RefCounted

signal function_confirmed(data: Dictionary)

# "What kind of verb" → the EventFunction return type the three-way expose derives its directive from
# (void = action, bool = condition, any other value = expression). `card_*` drive the friendly cards.
const USABLE_AS: Array[Dictionary] = [
	{"label": "Action (does something - a setter)", "kind": "action", "card_title": "Does something", "card_examples": "Take Damage, Heal, Knock Back", "glyph": "▶"},
	{"label": "Condition (a yes/no test)", "kind": "condition", "card_title": "Is it true?", "card_examples": "Is Dead, Is Full Health", "glyph": "?"},
	{"label": "Expression (returns a value - a getter)", "kind": "expression", "card_title": "A value", "card_examples": "Health %, Remaining Shields", "glyph": "ƒx"},
]
# Value types offered when the verb is "A value" (Expression). `friendly` is the plain-English label
# shown; `label` is the GDScript type name kept for reference. Order is index-stable (build_function_data
# + the unit tests read VALUE_TYPES[selected]).
const VALUE_TYPES: Array[Dictionary] = [
	{"label": "float", "friendly": "a number (float)", "type": TYPE_FLOAT},
	{"label": "int", "friendly": "a whole number (int)", "type": TYPE_INT},
	{"label": "String", "friendly": "text (String)", "type": TYPE_STRING},
	{"label": "bool", "friendly": "yes / no (bool)", "type": TYPE_BOOL},
	{"label": "Vector2", "friendly": "a point (Vector2)", "type": TYPE_VECTOR2},
	{"label": "Vector3", "friendly": "a 3D point (Vector3)", "type": TYPE_VECTOR3},
	{"label": "Variant", "friendly": "anything (Variant)", "type": TYPE_MAX},
]
const PARAM_TYPES: PackedStringArray = ["float", "int", "bool", "String", "Vector2", "Vector3", "Variant"]

var _dialog: ConfirmationDialog = null
# Non-empty while editing an existing function (its CURRENT name): switches the dialog to edit mode -
# the taken-names check allows the function's own name, and the confirmed payload carries the original
# name so the apply updates that function instead of appending a new one.
var _original_name: String = ""
var _guards_card: Control = null
var _preview_card: Control = null
var _name_edit: LineEdit = null
var _doc_comment_edit: TextEdit = null
var _description_edit: LineEdit = null
var _usable_option: OptionButton = null           # hidden backing model for the three cards
var _usable_cards: Array = []                      # [{panel, title, examples, accent, kind}], index-aligned to USABLE_AS
var _value_type_row: Control = null
var _value_type_option: OptionButton = null
var _params_box: VBoxContainer = null
var _guards_box: VBoxContainer = null
var _expose_check: CheckBox = null
var _expose_section: VBoxContainer = null
var _expose_card: PanelContainer = null  # themed inset card wrapping _expose_section (shown when "Expose" is ticked)
var _expose_name_edit: LineEdit = null
var _expose_category_edit: LineEdit = null
var _problem_label: Label = null
var _taken_names_provider: Callable = Callable()
# Live picker-preview widgets (the "this is what other people will see" pane + the "Ships as:" line).
var _preview_badge: Label = null
var _preview_name: Label = null
var _preview_chips: HBoxContainer = null
var _preview_sub: Label = null
var _preview_signature: Label = null


func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Define a Verb"
	_dialog.ok_button_text = "Create Function"
	_dialog.confirmed.connect(_on_confirmed)
	parent_node.add_child(_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.custom_minimum_size = Vector2(540.0, 0.0)
	_dialog.add_child(EventSheetPopupUI.margined(form))

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Take Damage"
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_studio())
	_dialog.register_text_enter(_name_edit)
	form.add_child(EventSheetPopupUI.form_row("Name", _name_edit))

	# Godot documentation comment (the `##` block above the function). BBCode is allowed - it renders in
	# the generated docs and in-editor tooltips - so the same selection toolbar the comment dialog uses is
	# attached here. Applies to ANY function, not just published verbs, so it lives in the always-visible form.
	_doc_comment_edit = TextEdit.new()
	_doc_comment_edit.placeholder_text = "Documentation shown above the function (## …). BBCode like [b]bold[/b] is allowed."
	_doc_comment_edit.custom_minimum_size = Vector2(0.0, 60.0)
	_doc_comment_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	form.add_child(EventSheetPopupUI.form_row("Doc comment", _doc_comment_edit))
	# Highlight-to-format bar (same one the comment dialog uses) - BBCode renders in Godot's generated docs.
	EventSheetBBCodeSelectionBar.attach(_doc_comment_edit)

	# Description is a picker/publish concern (grouped under Publish below), not a first thing a beginner
	# naming a local helper needs - so it lives in the expose section, not the always-visible form.
	_description_edit = LineEdit.new()
	_description_edit.placeholder_text = "What this verb does (shown in the picker)."
	_description_edit.text_changed.connect(func(_t: String) -> void: _refresh_studio())

	# What kind of verb - three plain-language cards. The hidden _usable_option stays the backing model
	# (build_function_data + the tests read it by index); the cards drive and mirror it.
	_usable_option = OptionButton.new()
	for entry: Dictionary in USABLE_AS:
		_usable_option.add_item(str(entry.get("label")))
	_usable_option.visible = false
	form.add_child(_usable_option)
	form.add_child(_build_verb_kind_section())

	# Value type - only shown for "A value" (Expression). Friendly labels; index-stable mapping.
	_value_type_option = OptionButton.new()
	for entry: Dictionary in VALUE_TYPES:
		_value_type_option.add_item(str(entry.get("friendly")))
	_value_type_option.item_selected.connect(func(_index: int) -> void: _refresh_studio())
	_value_type_row = EventSheetPopupUI.form_row("What kind of value?", _value_type_option)
	form.add_child(_value_type_row)

	# The live picker preview + "Ships as:" - only relevant when publishing ("what OTHER people see"),
	# so it stays hidden until Publish is ticked to keep the default create/edit view focused.
	_preview_card = _build_preview_card()
	_preview_card.visible = false
	form.add_child(_preview_card)

	# Parameters - a titled card holding the event-sheet-style rows (name · type · default · description).
	var params_content: VBoxContainer = VBoxContainer.new()
	params_content.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	_params_box = VBoxContainer.new()
	params_content.add_child(_params_box)
	var add_param_button: Button = Button.new()
	add_param_button.text = "+ Add parameter"
	add_param_button.tooltip_text = "Each parameter has a name, type, optional default value, and description."
	add_param_button.pressed.connect(func() -> void: add_param_row())
	params_content.add_child(add_param_button)
	form.add_child(EventSheetPopupUI.titled_card("Parameters", params_content))

	# Run only when - a titled card of guard conditions that wrap the function body in an `if`.
	var guards_content: VBoxContainer = VBoxContainer.new()
	guards_content.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	_guards_box = VBoxContainer.new()
	guards_content.add_child(_guards_box)
	var add_guard_button: Button = Button.new()
	add_guard_button.text = "+ Add condition"
	add_guard_button.tooltip_text = "A GDScript boolean expression - the body runs only when all hold (e.g. host.enabled)."
	add_guard_button.pressed.connect(func() -> void: add_guard_row())
	guards_content.add_child(add_guard_button)
	_guards_card = EventSheetPopupUI.titled_card("Run only when", guards_content)
	form.add_child(_guards_card)

	# Expose as an ACE other sheets can pick.
	_expose_check = CheckBox.new()
	_expose_check.text = "Publish to the picker (other sheets can use it)"
	_expose_check.tooltip_text = "Publishes the verb into pickers as the chosen kind."
	_expose_check.toggled.connect(func(on: bool) -> void:
		_expose_card.visible = on
		_preview_card.visible = on
		_refresh_studio())
	form.add_child(_expose_check)
	_expose_section = EventSheetPopupUI.form_box()
	# Description sits with the other picker/publish fields (it is "shown in the picker").
	_expose_section.add_child(EventSheetPopupUI.form_row("Description", _description_edit))
	_expose_name_edit = LineEdit.new()
	_expose_name_edit.placeholder_text = "defaults from the verb name"
	_expose_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_studio())
	_expose_section.add_child(EventSheetPopupUI.form_row("Display name", _expose_name_edit))
	_expose_category_edit = LineEdit.new()
	_expose_category_edit.placeholder_text = "e.g. Combat"
	_expose_category_edit.text_changed.connect(func(_t: String) -> void: _refresh_studio())
	_expose_section.add_child(EventSheetPopupUI.form_row("Picker category", _expose_category_edit))
	# Themed inset card, shown only when "Expose" is ticked.
	_expose_card = EventSheetPopupUI.panel_section(_expose_section)
	_expose_card.visible = false
	form.add_child(_expose_card)

	_problem_label = Label.new()
	_problem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Width-bound so the autowrap label can't report a runaway min height and balloon the dialog
	# when it becomes visible on a validation error (the form is 540 wide).
	_problem_label.custom_minimum_size = Vector2(520.0, 0.0)
	_problem_label.visible = false
	_problem_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
	form.add_child(_problem_label)
	_select_usable(0)


## Names already taken on the sheet (functions + variables) - duplicates are refused.
func set_taken_names_provider(provider: Callable) -> void:
	_taken_names_provider = provider


func open() -> void:
	_original_name = ""
	_dialog.title = "Define a Verb"
	_dialog.ok_button_text = "Create Function"
	_guards_card.visible = true
	_clear_rows(_params_box)
	_clear_rows(_guards_box)
	_name_edit.text = ""
	_doc_comment_edit.text = ""
	_description_edit.text = ""
	_expose_check.button_pressed = false
	_expose_card.visible = false
	_expose_name_edit.text = ""
	_expose_category_edit.text = ""
	_problem_label.visible = false
	_reset_value_type_items()
	_value_type_option.select(0)
	_select_usable(0)
	if _dialog.is_inside_tree():
		_dialog.popup_centered()
		_name_edit.grab_focus()


## Opens the dialog pre-filled from an existing function (edit mode) - the sheet's Define blocks
## double-click into here. The verb-kind card is derived from the return type exactly the way the
## canvas classifies it (void = Action, bool = Condition, typed = Expression), so the pre-selected
## card always matches the badge the user clicked. The "Run only when" card is hidden: guards live
## as condition rows inside the function's body, and re-emitting them from here would stack a second
## wrapper row onto the body instead of editing the first.
func open_for_edit(event_function: EventFunction) -> void:
	open()
	_original_name = event_function.function_name
	_dialog.title = "Edit Verb - %s" % event_function.function_name
	_dialog.ok_button_text = "Save Changes"
	_guards_card.visible = false
	_name_edit.text = event_function.function_name
	_doc_comment_edit.text = event_function.doc_comment
	_description_edit.text = event_function.description
	# Represent whatever type this verb returns, using the compiler's own emitted type name as the truth.
	# A custom / engine class (return_type_name set), OR a builtin Variant type with no card (Color, Array,
	# Dictionary, ...), rides in a dynamic Expression dropdown entry that shows that exact `-> Type`; only the
	# carded builtins (float/int/String/bool/Vector2/Vector3/Variant) and void/bool select a fixed card. This
	# keeps opening + saving with no change a byte-safe no-op instead of flattening the type to void / float.
	if not event_function.return_type_name.strip_edges().is_empty():
		_add_custom_value_type(event_function.return_type_name.strip_edges())
		_select_usable(2)
	elif event_function.return_type == TYPE_NIL:
		_select_usable(0)
	elif event_function.return_type == TYPE_BOOL:
		_select_usable(1)
	else:
		var builtin_index: int = _builtin_value_type_index(event_function.return_type)
		if builtin_index >= 0:
			_value_type_option.select(builtin_index)
		else:
			# A builtin Variant type with no card (Color, Array, Dictionary, ...): show its emitted name so
			# opening and saving re-emits `-> Type` exactly, rather than mislabelling it the first card (float).
			_add_custom_value_type(SheetCompiler._function_return_type_name(event_function))
		_select_usable(2)
	for param: ACEParam in event_function.params:
		add_param_row(param.id, param.type_name, param.gdscript_default, param.description)
	_expose_check.button_pressed = event_function.expose_as_ace
	_expose_card.visible = event_function.expose_as_ace
	_expose_name_edit.text = event_function.ace_display_name
	_expose_category_edit.text = event_function.ace_category
	_refresh_studio()


## Right-click ▸ "Add Parameter" entry point: opens the verb for editing, then appends a fresh
## parameter row and focuses its name field - so the whole "add an argument" gesture is a single
## right-click, and the user lands typing the new param's name (Name/Type/Default/Description follow).
func open_for_edit_focus_new_param(event_function: EventFunction) -> void:
	open_for_edit(event_function)
	add_param_row()
	var row_count: int = _params_box.get_child_count()
	if row_count == 0:
		return
	var last_row: Node = _params_box.get_child(row_count - 1)
	if last_row.get_child_count() > 0 and last_row.get_child(0) is LineEdit:
		var name_field: LineEdit = last_row.get_child(0) as LineEdit
		# The dialog is still popping up this frame; defer so focus lands after layout settles.
		name_field.call_deferred("grab_focus")
		name_field.call_deferred("select_all")


## queue_free alone leaves children in the tree until end of frame, so a prefill added right after
## would coexist with the stale rows and collect_params() would read both - detach immediately.
func _clear_rows(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()

# ── The "what kind of verb" cards ────────────────────────────────────────────────────────────────


## The three plain-language verb-kind cards, index-aligned to USABLE_AS. Each is a focusable, clickable
## card that drives the hidden _usable_option; _refresh_usable_cards() paints the selected one.
func _build_verb_kind_section() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.add_child(EventSheetPopupUI.section_header("What kind of verb is this?"))
	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	_usable_cards.clear()
	for index: int in range(USABLE_AS.size()):
		var entry: Dictionary = USABLE_AS[index]
		var accent: Color = _role_accent(str(entry.get("kind")))
		var card: PanelContainer = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_ALL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var inner: VBoxContainer = VBoxContainer.new()
		inner.add_theme_constant_override("separation", 3)
		var title_row: HBoxContainer = HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 6)
		var glyph: Label = Label.new()
		glyph.text = str(entry.get("glyph"))
		glyph.add_theme_color_override("font_color", accent)
		title_row.add_child(glyph)
		var title: Label = Label.new()
		title.text = str(entry.get("card_title"))
		title.add_theme_font_size_override("font_size", 14)
		title_row.add_child(title)
		inner.add_child(title_row)
		var examples: Label = Label.new()
		examples.text = str(entry.get("card_examples"))
		examples.add_theme_font_size_override("font_size", 11)
		examples.add_theme_color_override("font_color", EventSheetPalette.TEXT_MUTED)
		examples.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(examples)
		var content_margin: MarginContainer = EventSheetPopupUI.margined(inner, 9)
		# The card panel handles the click/keypress; its contents must be transparent to the mouse or
		# a Label under the cursor would swallow the event before the panel's gui_input sees it.
		for passthrough: Control in [content_margin, inner, title_row, glyph, title, examples]:
			passthrough.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(content_margin)
		var card_index: int = index
		card.gui_input.connect(func(event: InputEvent) -> void:
			var clicked: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			var keyed: bool = event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			if clicked or keyed:
				_select_usable(card_index)
				card.accept_event())
		cards_row.add_child(card)
		_usable_cards.append({"panel": card, "title": title, "accent": accent, "kind": str(entry.get("kind"))})
	box.add_child(cards_row)
	return box


## Paints the selected card (accent border + tint + bright title) and dims the rest; called on every
## selection change. Selecting also updates the hidden model, the value-type visibility, and the preview.
func _select_usable(index: int) -> void:
	_usable_option.select(index)
	_refresh_usable_cards()
	_sync_value_type_visibility()
	_refresh_studio()


func _refresh_usable_cards() -> void:
	var selected: int = maxi(_usable_option.selected, 0)
	for index: int in range(_usable_cards.size()):
		var card: Dictionary = _usable_cards[index]
		var panel: PanelContainer = card.get("panel")
		var title: Label = card.get("title")
		var accent: Color = card.get("accent")
		var is_selected: bool = index == selected
		panel.add_theme_stylebox_override("panel", _card_stylebox(accent, is_selected))
		title.add_theme_color_override("font_color", accent if is_selected else EventSheetPalette.TEXT_SECONDARY)


## Selected = a 2px accent border over an accent-tinted fill; unselected = the neutral inset panel.
func _card_stylebox(accent: Color, selected: bool) -> StyleBoxFlat:
	if not selected:
		return EventSheetPopupUI.inset_panel_stylebox()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	box.border_color = accent
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	return box

# ── The live picker preview + "Ships as:" ────────────────────────────────────────────────────────


func _build_preview_card() -> Control:
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	# The picker-entry mock - rendered in a sunken panel so it reads like a real row in someone's picker.
	var entry: HBoxContainer = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 6)
	_preview_badge = _pill("Action", EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG)
	entry.add_child(_preview_badge)
	_preview_name = Label.new()
	_preview_name.add_theme_color_override("font_color", EventSheetPalette.COLOR_OBJECT)
	entry.add_child(_preview_name)
	_preview_chips = HBoxContainer.new()
	_preview_chips.add_theme_constant_override("separation", 5)
	entry.add_child(_preview_chips)
	content.add_child(EventSheetPopupUI.panel_section(entry))
	_preview_sub = Label.new()
	_preview_sub.add_theme_font_size_override("font_size", 11)
	_preview_sub.add_theme_color_override("font_color", EventSheetPalette.TEXT_MUTED)
	content.add_child(_preview_sub)
	# "Ships as:" - the exact generated signature (built from the compiler's own formatters).
	var ships_box: VBoxContainer = VBoxContainer.new()
	ships_box.add_theme_constant_override("separation", 1)
	var ships_cap: Label = Label.new()
	ships_cap.text = "SHIPS AS"
	ships_cap.add_theme_font_size_override("font_size", 10)
	ships_cap.add_theme_color_override("font_color", EventSheetPalette.TEXT_MUTED)
	ships_box.add_child(ships_cap)
	_preview_signature = Label.new()
	_preview_signature.add_theme_color_override("font_color", EventSheetPalette.TEXT_SECONDARY)
	ships_box.add_child(_preview_signature)
	content.add_child(EventSheetPopupUI.panel_section(ships_box))
	return EventSheetPopupUI.titled_card("This is what other people will see", content)


## Rebuilds the preview + signature from the current dialog state - called on every keystroke / choice.
## Uses raw (unvalidated) fields so it shows a live "if published" identity while the name is still
## incomplete; the signature falls back to a `new_verb` placeholder so it never renders broken GDScript.
func _refresh_studio() -> void:
	if _preview_badge == null:
		return
	var kind: String = _usable_kind()
	var style: Dictionary = _role_pill_style(kind)
	_preview_badge.text = str(style.get("label"))
	_style_pill(_preview_badge, style.get("bg"), style.get("fg"))
	var raw_name: String = _name_edit.text.strip_edges()
	var display_name: String = _expose_name_edit.text.strip_edges()
	if display_name.is_empty():
		display_name = raw_name.capitalize() if not raw_name.is_empty() else "New verb"
	_preview_name.text = display_name
	var params: Array[Dictionary] = collect_params()
	var category: String = _expose_category_edit.text.strip_edges()
	# Param chips + the category chip.
	for child: Node in _preview_chips.get_children():
		child.queue_free()
	for param: Dictionary in params:
		_preview_chips.add_child(_pill(str(param.get("id")), EventSheetPalette.COLOR_CHIP_BG, EventSheetPalette.COLOR_CHIP_FG))
	if not category.is_empty():
		_preview_chips.add_child(_pill(category, EventSheetPalette.COLOR_CAT_CHIP_BG, EventSheetPalette.COLOR_CAT_CHIP_FG))
	var arg_hint: String = ""
	for param: Dictionary in params:
		arg_hint += "  %s" % str(param.get("id"))
	_preview_sub.text = "%s › %s%s" % [category if not category.is_empty() else "(this behaviour)", display_name, arg_hint]
	# Signature - from the compiler's own formatters, so it can't disagree with what actually ships.
	var signature_name: String = raw_name.to_snake_case()
	if signature_name.is_empty() or not signature_name.is_valid_identifier():
		signature_name = "new_verb"
	_preview_signature.text = format_signature(signature_name, _return_type_for_kind(kind), params, _selected_return_type_name())


## A pill Label with a rounded coloured background - the shared badge/chip look.
func _pill(text: String, bg: Color, fg: Color, font_size: int = 11) -> Label:
	var label: Label = Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	_style_pill(label, bg, fg)
	label.text = text
	return label


func _style_pill(label: Label, bg: Color, fg: Color) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(4)
	box.set_content_margin(SIDE_LEFT, 6.0)
	box.set_content_margin(SIDE_RIGHT, 6.0)
	box.set_content_margin(SIDE_TOP, 1.0)
	box.set_content_margin(SIDE_BOTTOM, 2.0)
	label.add_theme_stylebox_override("normal", box)
	label.add_theme_color_override("font_color", fg)


func _role_accent(kind: String) -> Color:
	match kind:
		"condition":
			return EventSheetPalette.COLOR_CONDITION
		"expression":
			return EventSheetPalette.COLOR_EXPRESSION
		_:
			return EventSheetPalette.COLOR_ACTION


## The role badge {label, bg, fg} for the preview pill.
func _role_pill_style(kind: String) -> Dictionary:
	match kind:
		"condition":
			return {"label": "Condition", "bg": EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, "fg": EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG}
		"expression":
			return {"label": "Expression", "bg": EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, "fg": EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG}
		_:
			return {"label": "Action", "bg": EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, "fg": EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG}


func _return_type_for_kind(kind: String) -> int:
	match kind:
		"condition":
			return TYPE_BOOL
		"expression":
			if _value_type_option.selected >= VALUE_TYPES.size():
				# A custom / not-carded return carried by return_type_name: store TYPE_MAX (Variant), matching
				# how the importer lifts one, so return_type never disagrees and the fingerprint stays stable.
				return TYPE_MAX
			return int(VALUE_TYPES[maxi(_value_type_option.selected, 0)].get("type"))
		_:
			return TYPE_NIL


## The exact `-> Type` name currently chosen when it can't be a builtin card, or "" otherwise. Non-empty
## only when the Expression value-type dropdown points at a dynamic entry (a custom / engine class, or a
## builtin Variant type with no card like Color) - the compiler then emits it verbatim (return_type_name
## wins). Switching to the Action / Condition card, or to a carded builtin value type, yields "" so the
## dynamic type is intentionally dropped and the new one takes effect.
func _selected_return_type_name() -> String:
	if _usable_kind() != "expression":
		return ""
	if _value_type_option.selected >= VALUE_TYPES.size():
		return _value_type_option.get_item_text(_value_type_option.selected).strip_edges()
	return ""


## Index of the VALUE_TYPES card for a Variant.Type, or -1 when that type has no card (Color, Array, ...).
func _builtin_value_type_index(return_type: int) -> int:
	for index: int in range(VALUE_TYPES.size()):
		if int(VALUE_TYPES[index].get("type")) == return_type:
			return index
	return -1


## Appends a dynamic value-type entry naming a type no builtin card offers (a custom / engine class, or a
## not-carded Variant type) and selects it, so the Expression dropdown shows the verb's exact `-> Type`.
## The selected entry's text is the single source of truth for the type name (read by _selected_return_type_name).
func _add_custom_value_type(type_name: String) -> void:
	_value_type_option.add_item(type_name)
	_value_type_option.select(_value_type_option.item_count - 1)


## Drops any dynamic entry a prior edit appended, leaving only the builtin VALUE_TYPES rows so the
## value-type dropdown starts each open in a known state (item_count back to VALUE_TYPES.size()).
func _reset_value_type_items() -> void:
	while _value_type_option.item_count > VALUE_TYPES.size():
		_value_type_option.remove_item(_value_type_option.item_count - 1)


## The exact generated `func` signature for a verb - built from a transient EventFunction run through
## the COMPILER's own static formatters (_emit_function_params / _function_return_type_name), so the
## "Ships as:" line can never disagree with the code that actually ships. Static + pure (unit-testable).
static func format_signature(function_name: String, return_type: int, params: Array, return_type_name: String = "") -> String:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = function_name
	event_function.return_type = return_type
	event_function.return_type_name = return_type_name
	for param_entry: Variant in params:
		var param: ACEParam = ACEParam.new()
		param.id = str((param_entry as Dictionary).get("id"))
		param.type_name = str((param_entry as Dictionary).get("type_name", "Variant"))
		param.gdscript_default = str((param_entry as Dictionary).get("default", ""))
		event_function.params.append(param)
	return "func %s(%s) -> %s" % [
		function_name,
		SheetCompiler._emit_function_params(event_function),
		SheetCompiler._function_return_type_name(event_function),
	]


## The value-type sub-row only matters for "A value" (Action = void, Condition = bool).
func _sync_value_type_visibility() -> void:
	if _value_type_row != null:
		_value_type_row.visible = _usable_kind() == "expression"


func _usable_kind() -> String:
	return str(USABLE_AS[maxi(_usable_option.selected, 0)].get("kind"))


## One expanding row per parameter: name · type · default · description · remove. Field edits refresh
## the live preview so the picker entry + signature track what's being typed. The optional trailing
## args prefill the row (edit mode re-opens an existing verb's parameters).
func add_param_row(suggested_name: String = "", type_name_value: String = "", default_value: String = "", description_value: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var param_name: LineEdit = LineEdit.new()
	param_name.text = suggested_name if not suggested_name.is_empty() else _next_param_name()
	param_name.custom_minimum_size = Vector2(110.0, 0.0)
	param_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_name.text_changed.connect(func(_t: String) -> void: _refresh_studio())
	row.add_child(param_name)
	var param_type: OptionButton = OptionButton.new()
	for type_name: String in PARAM_TYPES:
		param_type.add_item(type_name)
	var preset_type: int = PARAM_TYPES.find(type_name_value)
	if preset_type >= 0:
		param_type.select(preset_type)
	param_type.item_selected.connect(func(_index: int) -> void: _refresh_studio())
	row.add_child(param_type)
	var param_default: LineEdit = LineEdit.new()
	param_default.text = default_value
	param_default.placeholder_text = "default"
	param_default.tooltip_text = "Optional default value (a GDScript expression). Defaulted params must come last."
	param_default.custom_minimum_size = Vector2(80.0, 0.0)
	param_default.text_changed.connect(func(_t: String) -> void: _refresh_studio())
	row.add_child(param_default)
	var param_desc: LineEdit = LineEdit.new()
	param_desc.text = description_value
	param_desc.placeholder_text = "description"
	param_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(param_desc)
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = "Remove this parameter."
	remove_button.pressed.connect(func() -> void:
		_params_box.remove_child(row)
		row.queue_free()
		_refresh_studio())
	row.add_child(remove_button)
	_params_box.add_child(row)
	_refresh_studio()


## One row per guard condition: a boolean expression + remove.
func add_guard_row(expression: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var guard_edit: LineEdit = LineEdit.new()
	guard_edit.text = expression
	guard_edit.placeholder_text = "e.g. host.enabled  or  is_active"
	guard_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(guard_edit)
	var remove_button: Button = Button.new()
	remove_button.text = "✕"
	remove_button.tooltip_text = "Remove this condition."
	remove_button.pressed.connect(func() -> void:
		_guards_box.remove_child(row)
		row.queue_free())
	row.add_child(remove_button)
	_guards_box.add_child(row)


func _next_param_name() -> String:
	var taken: Dictionary = {}
	for entry: Dictionary in collect_params():
		taken[str(entry.get("id"))] = true
	var index: int = 1
	while taken.has("param_%d" % index):
		index += 1
	return "param_%d" % index


## The current param rows as [{id, type_name, default, description}] (names snake_cased + de-duplicated).
func collect_params() -> Array[Dictionary]:
	var params: Array[Dictionary] = []
	var seen: Dictionary = {}
	for row: Node in _params_box.get_children():
		if row.get_child_count() < 4 or not (row.get_child(0) is LineEdit):
			continue
		var raw_name: String = (row.get_child(0) as LineEdit).text.strip_edges().to_snake_case()
		if raw_name.is_empty() or not raw_name.is_valid_identifier() or seen.has(raw_name):
			continue
		seen[raw_name] = true
		var type_option: OptionButton = row.get_child(1) as OptionButton
		params.append({
			"id": raw_name,
			"type_name": type_option.get_item_text(type_option.selected),
			"default": (row.get_child(2) as LineEdit).text.strip_edges(),
			"description": (row.get_child(3) as LineEdit).text.strip_edges(),
		})
	return params


## The current guard expressions (non-empty, in order).
func collect_guards() -> PackedStringArray:
	var guards: PackedStringArray = PackedStringArray()
	for row: Node in _guards_box.get_children():
		if row.get_child_count() < 1 or not (row.get_child(0) is LineEdit):
			continue
		var expression: String = (row.get_child(0) as LineEdit).text.strip_edges()
		if not expression.is_empty():
			guards.append(expression)
	return guards


func _on_confirmed() -> void:
	var data: Dictionary = build_function_data()
	if not str(data.get("problem", "")).is_empty():
		_problem_label.text = "✗ %s" % str(data.get("problem"))
		_problem_label.visible = true
		if _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered")
		return
	function_confirmed.emit(data)


## Validated dialog state → {name, return_type, params, guards, description, expose,
## ace_display_name, ace_category} or {problem}. Auto-corrections: names snake_case, display
## name defaults from the function name, return type derived from the chosen verb kind.
func build_function_data() -> Dictionary:
	var function_name: String = _name_edit.text.strip_edges().to_snake_case()
	if function_name.is_empty() or not function_name.is_valid_identifier():
		return {"problem": "Verb names must be valid identifiers (e.g. take_damage)."}
	# In edit mode the function's own current name is not a collision - only OTHER taken names are.
	if function_name != _original_name and _taken_names_provider.is_valid() \
			and (_taken_names_provider.call() as PackedStringArray).has(function_name):
		return {"problem": "\"%s\" already exists on this sheet (function or variable)." % function_name}
	var params: Array[Dictionary] = collect_params()
	# GDScript requires defaulted parameters to be trailing - refuse a gap so the generated
	# function never fails to parse.
	var seen_default: bool = false
	for param: Dictionary in params:
		if not str(param.get("default", "")).is_empty():
			seen_default = true
		elif seen_default:
			return {"problem": "Parameters with a default value must come after those without (\"%s\" has no default)." % str(param.get("id"))}
	return {
		"problem": "",
		"editing": _original_name,  # "" = create a new function; non-empty = update the one so named
		"name": function_name,
		"return_type": _return_type_for_kind(_usable_kind()),
		"return_type_name": _selected_return_type_name(),
		"params": params,
		"guards": collect_guards(),
		"doc_comment": _doc_comment_edit.text.strip_edges(),
		"description": _description_edit.text.strip_edges(),
		"expose": _expose_check.button_pressed,
		"ace_display_name": _expose_name_edit.text.strip_edges() if not _expose_name_edit.text.strip_edges().is_empty() else function_name.capitalize(),
		"ace_category": _expose_category_edit.text.strip_edges(),
	}
