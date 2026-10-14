# Godot EventSheets - the New / Edit Function window.
#
# Built on the window kit, top to bottom:
#  • a band holding the function's row as the sheet will show it ("ƒ  On take_damage → nothing"),
#  • the Function card: Name (with the snake_case name the code will use beside it), the doc comment
#    with its drafted line, and the Inspector button,
#  • the "What kind is it?" card: ONE described dropdown - Action / Condition / Expression - whose
#    choice sets the return type, the value type when it is an Expression, and Publish,
#  • "This is what other people will see": the picker entry, shown once Publish is ticked,
#  • the help strip: what the focused field means, and IN CODE the exact `func` line it will write
#    (built from the compiler's own formatters, so it can never disagree with the code that ships),
#  • the amber reason a name cannot be used, said while it is typed.
#
# NOT here, on purpose: the parameter list, a "run only when" card, and the picker metadata
# (description / display name / category). A parameter is a line under the function on the sheet and
# a field in the Properties bar; a guard is a condition on an event inside it. The window CARRIES the
# function's existing parameters and metadata (_carried_*) so saving an edit cannot write empty values
# over them - an untouched open-and-save stays byte-identical.
@tool
class_name EventSheetFunctionDialog
extends RefCounted

signal function_confirmed(data: Dictionary)

# "What kind is it?" -> the EventFunction return type the three-way expose derives its directive from
# (void = action, bool = condition, any other value = expression). Index-stable: build_function_data()
# and the tests read the dropdown by index.
const USABLE_AS: Array[Dictionary] = [
	{"kind": "action", "kind_label": "Action", "glyph": "▶"},
	{"kind": "condition", "kind_label": "Condition", "glyph": "?"},
	{"kind": "expression", "kind_label": "Expression", "glyph": "ƒx"},
]
# Value types offered when the function is an Expression, as the code writes them. Order is
# index-stable (build_function_data + the unit tests read VALUE_TYPES[selected]).
const VALUE_TYPES: Array[Dictionary] = [
	{"label": "float", "type": TYPE_FLOAT},
	{"label": "int", "type": TYPE_INT},
	{"label": "String", "type": TYPE_STRING},
	{"label": "bool", "type": TYPE_BOOL},
	{"label": "Vector2", "type": TYPE_VECTOR2},
	{"label": "Vector3", "type": TYPE_VECTOR3},
	{"label": "Variant", "type": TYPE_MAX},
]
const PARAM_TYPES: PackedStringArray = ["float", "int", "bool", "String", "Vector2", "Vector3", "Variant"]

var _dialog: ConfirmationDialog = null
# Non-empty while editing an existing function (its CURRENT name): switches the window to edit mode -
# the taken-names check allows the function's own name, and the confirmed payload carries the original
# name so the apply updates that function instead of appending a new one.
var _original_name: String = ""
var _preview_card: Control = null
var _name_edit: LineEdit = null
## The name the code will use, shown beside the Name field as it is typed.
var _code_name_label: Label = null
## The function's row as the sheet will show it, in the band at the top.
var _band_label: Label = null
var _doc_comment_edit: TextEdit = null
## The description this function's own rows compose, and the strip that offers it. Held only while
## the window is open: a draft is never stored anywhere, so there is nowhere for a stale one to hide.
var _drafted_description: String = ""
var _draft_hint: Label = null
var _draft_row: HBoxContainer = null
var _tool_button_edit: LineEdit = null
# Shown when the OWNING sheet is an editor tool (tool_mode): this function runs INSIDE the editor.
var _tool_mode_hint: Label = null
var _usable_option: OptionButton = null
var _value_type_row: Control = null
var _value_type_option: OptionButton = null
## Values carried through an edit untouched (see the header).
var _carried_params: Array[Dictionary] = []
var _carried_description: String = ""
var _carried_display_name: String = ""
var _carried_category: String = ""
var _expose_check: CheckBox = null
var _problem_label: Label = null
var _taken_names_provider: Callable = Callable()
## The open sheet's class-level picker category ("" = none), the preview's fallback shelf.
var _sheet_category: String = ""
var _help: EventSheetPopupUI.HelpStrip = null
# Live picker preview.
var _preview_badge: Label = null
var _preview_name: Label = null
var _preview_chips: HBoxContainer = null
var _preview_sub: Label = null
## The exact `func` line - the help strip's IN CODE value.
var _preview_signature: Label = null


## The sentence a kind choice shows as the pointer rests on it, with its examples.
static func kind_description(kind: String) -> String:
	match kind:
		"condition":
			return EventSheetL10n.translate("A condition asks a yes or no question: the event only runs when it answers yes. It sits in the left-hand lane. For example: Is Dead, Is Full Health.")
		"expression":
			return EventSheetL10n.translate("An expression answers with a value you can use inside any parameter box, like a number or some text. For example: Health %, Remaining Shields.")
	return EventSheetL10n.translate("An action does something when the event runs: change a value, move, play a sound. It sits in the right-hand lane. For example: Take Damage, Heal, Knock Back.")


## The words a kind choice shows in the dropdown.
static func kind_choice_text(entry: Dictionary) -> String:
	var words: String = EventSheetL10n.translate("Does something")
	match str(entry.get("kind")):
		"condition":
			words = EventSheetL10n.translate("Is it true?")
		"expression":
			words = EventSheetL10n.translate("A value")
	return "%s  %s - %s" % [str(entry.get("glyph")), EventSheetL10n.translate(str(entry.get("kind_label"))), words]


func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	# OK closes the window itself, and only when the function is accepted - a refused name keeps the
	# form open with the reason under it rather than closing and popping back up.
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("New Function"), Vector2i.ZERO,
		parent_node, EventSheetL10n.translate("Create Function"), _on_confirmed)
	_dialog = parts["window"]
	_dialog.cancel_button_text = EventSheetL10n.translate("Cancel")
	var form: VBoxContainer = parts["box"]
	form.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(540.0), 0.0)
	_help = EventSheetPopupUI.help_strip()

	_band_label = Label.new()
	_band_label.tooltip_text = EventSheetL10n.translate("The function's row, as the sheet will show it.")
	_band_label.mouse_filter = Control.MOUSE_FILTER_STOP
	form.add_child(EventSheetPopupUI.panel_section(_band_label))

	var function_box: VBoxContainer = EventSheetPopupUI.form_box()
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = EventSheetL10n.translate("Take Damage")
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_studio())
	_dialog.register_text_enter(_name_edit)
	var name_box: HBoxContainer = HBoxContainer.new()
	name_box.add_child(_name_edit)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_name_label = Label.new()
	_code_name_label.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	name_box.add_child(_code_name_label)
	function_box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), name_box))
	_help.follow(_name_edit, EventSheetL10n.translate("Name"),
		EventSheetL10n.translate("Write it in plain words - \"Take Damage\" becomes take_damage in the generated GDScript. Other rows call it by this name."))

	# Godot documentation comment (the `##` block above the function). BBCode is allowed - it renders
	# in the generated docs and in-editor tooltips - so the comment window's selection bar is attached.
	_doc_comment_edit = TextEdit.new()
	_doc_comment_edit.placeholder_text = EventSheetL10n.translate("Documentation shown above the function (## …). BBCode like [b]bold[/b] is allowed.")
	_doc_comment_edit.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(60.0))
	_doc_comment_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	function_box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Doc comment"), _doc_comment_edit))
	_help.follow(_doc_comment_edit, EventSheetL10n.translate("Doc comment"),
		EventSheetL10n.translate("Godot's own documentation for this function. It is written above the function as ## lines and shows up in the editor's built-in help and when hovering it elsewhere. Optional."))
	EventSheetBBCodeSelectionBar.attach(_doc_comment_edit)
	# The offer beside the field: what this function's OWN rows would say about it. Nothing is written
	# until the button is pressed - a draft never overwrites words a person typed.
	_draft_row = HBoxContainer.new()
	_draft_row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	_draft_hint = EventSheetPopupUI.hint_label("")
	_draft_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draft_row.add_child(_draft_hint)
	var draft_button: Button = Button.new()
	draft_button.text = EventSheetL10n.translate("Use this draft")
	draft_button.pressed.connect(func() -> void: _doc_comment_edit.text = _drafted_description)
	_draft_row.add_child(draft_button)
	_help.follow(draft_button, EventSheetL10n.translate("Use this draft"),
		EventSheetL10n.translate("Puts the drafted line in the field above, where you can edit it before saving. Nothing is written until you save."))
	_draft_row.visible = false
	function_box.add_child(_draft_row)

	# Inspector button: name a label and this function gets a one-click button in the Inspector
	# (@export_tool_button). Empty = no button (the default; most functions).
	_tool_button_edit = LineEdit.new()
	_tool_button_edit.placeholder_text = EventSheetL10n.translate("e.g. Re-bake  (empty = no button)")
	function_box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Inspector button"), _tool_button_edit))
	_help.follow(_tool_button_edit, EventSheetL10n.translate("Inspector button"),
		EventSheetL10n.translate("Puts a clickable button on this node's Inspector panel, labelled with whatever you type here. Pressing it runs this function right there in the editor. Leave it empty (the usual case) and no button appears."))
	_tool_mode_hint = EventSheetPopupUI.hint_label(EventSheetL10n.translate("This sheet is an editor tool: this function runs INSIDE the editor (File > Run or an Inspector button), never in the game."))
	_tool_mode_hint.visible = false
	function_box.add_child(_tool_mode_hint)
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Function"), function_box))

	var kind_box: VBoxContainer = EventSheetPopupUI.form_box()
	_usable_option = EventSheetPopupUI.described_option()
	for entry: Dictionary in USABLE_AS:
		EventSheetPopupUI.add_described_item(_usable_option, kind_choice_text(entry), kind_description(str(entry.get("kind"))))
	_usable_option.item_selected.connect(func(index: int) -> void: _select_usable(index))
	kind_box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Kind"), _usable_option))
	_help.follow_option(_usable_option, func(index: int) -> Dictionary:
		return {"heading": EventSheetL10n.translate(str(USABLE_AS[index].get("kind_label"))),
			"body": kind_description(str(USABLE_AS[index].get("kind")))})
	_help.follow(_usable_option, EventSheetL10n.translate("Kind"), "", func() -> String:
		return kind_description(_usable_kind()))

	_value_type_option = EventSheetPopupUI.described_option()
	for entry: Dictionary in VALUE_TYPES:
		EventSheetPopupUI.add_described_item(_value_type_option, str(entry.get("label")),
			value_type_description(int(entry.get("type"))))
	_value_type_option.item_selected.connect(func(_index: int) -> void: _refresh_studio())
	_value_type_row = EventSheetPopupUI.form_row(EventSheetL10n.translate("Value"), _value_type_option)
	kind_box.add_child(_value_type_row)
	_help.follow_option(_value_type_option, func(index: int) -> Dictionary:
		return {"heading": _value_type_option.get_item_text(index), "body": _value_type_option.get_item_tooltip(index)})

	_expose_check = CheckBox.new()
	_expose_check.text = EventSheetL10n.translate("Publish to the picker (other sheets can use it)")
	_expose_check.toggled.connect(func(on: bool) -> void:
		_preview_card.visible = on
		_refresh_studio())
	kind_box.add_child(_expose_check)
	_help.follow(_expose_check, EventSheetL10n.translate("Publish"),
		EventSheetL10n.translate("Ticked: this function shows up in the Add Action / Condition picker for every sheet in the project. Unticked: only events in this sheet can call it."))
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("What kind is it?"), kind_box))

	# The live picker preview - only relevant when publishing ("what OTHER people see").
	_preview_card = _build_preview_card()
	_preview_card.visible = false
	form.add_child(_preview_card)

	_help.describe(EventSheetL10n.translate("Name"),
		EventSheetL10n.translate("Write it in plain words - \"Take Damage\" becomes take_damage in the generated GDScript. Other rows call it by this name."))
	_preview_signature = _help.in_code_value
	form.add_child(_help)

	_problem_label = Label.new()
	_problem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Width-bound so the autowrap label can't report a runaway min height and balloon the window.
	_problem_label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(520.0), 0.0)
	_problem_label.visible = false
	_problem_label.add_theme_color_override("font_color", EventSheetPopupUI.readable_on_panel(
		EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING)))
	form.add_child(_problem_label)
	_select_usable(0)


## Names already taken on the sheet (functions + variables) - duplicates are refused.
func set_taken_names_provider(provider: Callable) -> void:
	_taken_names_provider = provider


## The dock flips this per open: true when the current sheet is tool_mode, so the window says
## where the function will run.
func set_tool_mode_context(enabled: bool) -> void:
	if _tool_mode_hint != null:
		_tool_mode_hint.visible = enabled


## The dock passes the open sheet's class-level picker category per open ("" when it has none), so
## the preview files an uncategorised function on the same shelf the picker will.
func set_sheet_category_context(category: String) -> void:
	_sheet_category = category.strip_edges()


## Opens the window for a NEW function. `kind` pre-selects a kind ("action" / "condition" /
## "expression", empty = Action); `publish` pre-ticks the publish checkbox.
func open(kind: String = "", publish: bool = false) -> void:
	_original_name = ""
	_dialog.ok_button_text = EventSheetL10n.translate("Create Function")
	_carried_params = []
	_carried_description = ""
	_carried_display_name = ""
	_carried_category = ""
	_name_edit.text = ""
	_doc_comment_edit.text = ""
	_tool_button_edit.text = ""
	_draft_row.visible = false
	_expose_check.button_pressed = publish
	_preview_card.visible = publish
	_problem_label.visible = false
	_reset_value_type_items()
	_value_type_option.select(0)
	_select_usable(_usable_index_for_kind(kind))
	if _dialog.is_inside_tree():
		_dialog.popup_centered()
		_name_edit.grab_focus()


## The kind index for a kind string; defaults to Action (0) for an empty/unknown kind.
func _usable_index_for_kind(kind: String) -> int:
	for index: int in range(USABLE_AS.size()):
		if str(USABLE_AS[index].get("kind")) == kind:
			return index
	return 0


## Opens the window pre-filled from an existing function (edit mode). The kind is derived from the
## return type exactly the way the canvas classifies it (void = Action, bool = Condition, typed =
## Expression). The picker metadata is carried through untouched rather than shown as fields.
func open_for_edit(event_function: EventFunction) -> void:
	open()
	_original_name = event_function.function_name
	_dialog.ok_button_text = EventSheetL10n.translate("Save Changes")
	_name_edit.text = event_function.function_name
	_doc_comment_edit.text = event_function.doc_comment
	_tool_button_edit.text = event_function.tool_button_label
	_carried_description = event_function.description
	_carried_display_name = event_function.ace_display_name
	_carried_category = event_function.ace_category
	# Represent whatever type this function returns, using the compiler's own emitted type name as the
	# truth: a type with no fixed entry (a class, Color, Array ...) rides in an extra Value entry that
	# shows that exact `-> Type`, so opening + saving with no change is a byte-safe no-op.
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
			_add_custom_value_type(SheetCompiler._function_return_type_name(event_function))
		_select_usable(2)
	for param: ACEParam in event_function.params:
		_carried_params.append({
			"id": param.id,
			"type_name": param.type_name,
			"default": param.gdscript_default,
			"description": param.description,
		})
	_expose_check.button_pressed = event_function.expose_as_ace
	_preview_card.visible = event_function.expose_as_ace
	_show_draft_offer(event_function)
	_refresh_studio()


## Shows what this function's rows would say about it, and offers to put those words in the field.
## Only when the function has no description yet.
func _show_draft_offer(event_function: EventFunction) -> void:
	_drafted_description = EventSheetDescriptionDrafts.for_function(event_function)
	var already_described: bool = not EventSheetDescriptions.for_function(event_function).is_empty()
	# The shared offer budget decides, so a person who ignored this suggestion is not shown it again
	# on every open of the same function.
	_draft_row.visible = EventSheetDescriptionDrafts.may_offer("function",
		event_function.function_name, already_described, _drafted_description)
	if _draft_row.visible:
		_draft_hint.text = EventSheetL10n.translate("No description yet. Its own rows say: \"%s\"") % _drafted_description


func _select_usable(index: int) -> void:
	_usable_option.select(index)
	EventSheetPopupUI.follow_description(_usable_option)
	_sync_value_type_visibility()
	_refresh_studio()

# ── The live picker preview ──────────────────────────────────────────────────────────────────────


func _build_preview_card() -> Control:
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	# The picker-entry mock - in a sunken panel so it reads like a real row in someone's picker.
	var entry: HBoxContainer = HBoxContainer.new()
	entry.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	_preview_badge = _pill("", EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG)
	entry.add_child(_preview_badge)
	_preview_name = Label.new()
	_preview_name.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
	entry.add_child(_preview_name)
	_preview_chips = HBoxContainer.new()
	_preview_chips.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(5.0)))
	entry.add_child(_preview_chips)
	content.add_child(EventSheetPopupUI.panel_section(entry))
	_preview_sub = Label.new()
	_preview_sub.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	_preview_sub.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	content.add_child(_preview_sub)
	return EventSheetPopupUI.titled_card(EventSheetL10n.translate("This is what other people will see"), content)


## Rebuilds the band, the title, the preview and the IN CODE line from the current state - called on
## every keystroke / choice. Uses raw (unvalidated) fields so it shows a live identity while the name
## is still incomplete; the signature falls back to a `new_function` placeholder so it never renders
## broken GDScript.
func _refresh_studio() -> void:
	if _preview_badge == null:
		return
	var kind: String = _usable_kind()
	var style: Dictionary = _role_pill_style(kind)
	_preview_badge.text = str(style.get("label"))
	_style_pill(_preview_badge, style.get("bg"), style.get("fg"))
	var raw_name: String = _name_edit.text.strip_edges()
	# The preview shows the carried display name (from an edited function), falling back to the typed
	# name - the same fallback the row and compiler use when no @ace_name is set.
	var display_name: String = _carried_display_name.strip_edges()
	if display_name.is_empty():
		display_name = raw_name.capitalize() if not raw_name.is_empty() else EventSheetL10n.translate("New function")
	_preview_name.text = display_name
	var params: Array[Dictionary] = collect_params()
	var category: String = _carried_category.strip_edges()
	for child: Node in _preview_chips.get_children():
		child.queue_free()
	for param: Dictionary in params:
		_preview_chips.add_child(_pill(str(param.get("id")), EventSheetPalette.COLOR_CHIP_BG, EventSheetPalette.COLOR_CHIP_FG))
	if not category.is_empty():
		_preview_chips.add_child(_pill(category, EventSheetPalette.COLOR_CAT_CHIP_BG, EventSheetPalette.COLOR_CAT_CHIP_FG))
	var arg_hint: String = ""
	for param: Dictionary in params:
		arg_hint += "  %s" % str(param.get("id"))
	_preview_sub.text = "%s › %s%s" % [_preview_category(category, raw_name, kind), display_name, arg_hint]
	var signature_name: String = raw_name.to_snake_case()
	var named: bool = not signature_name.is_empty() and signature_name.is_valid_identifier()
	_code_name_label.text = "→ %s" % signature_name if named else ""
	if not named:
		signature_name = "new_function"
	var signature: String = format_signature(signature_name, _return_type_for_kind(kind), params, _selected_return_type_name())
	_help.set_reading("", signature)
	var returns_word: String = signature.get_slice("-> ", 1)
	_band_label.text = "ƒ  %s  %s → %s" % [EventSheetL10n.translate("Function"),
		EventSheetL10n.translate("On %s") % signature_name,
		EventSheetL10n.translate("nothing") if returns_word == "void" else returns_word]
	_dialog.title = (EventSheetL10n.translate("Edit function %s") if not _original_name.is_empty()
		else EventSheetL10n.translate("Create function %s")) % (signature_name if named else "")
	# The problem is said as it is typed, not only after OK. An empty name is not one yet - the
	# window has just opened - so it stays quiet until there is something to judge.
	if _problem_label != null:
		_show_problem("" if raw_name.is_empty() else str(build_function_data().get("problem", "")))


## The shelf the picker will file this function under, worked out the way the picker itself does:
## the function's own category, else the sheet's class-level one, else the inferred one.
func _preview_category(own_category: String, raw_name: String, kind: String) -> String:
	if not own_category.is_empty():
		return own_category
	if not _sheet_category.is_empty():
		return _sheet_category
	var ace_type: int = ACEDefinition.ACEType.ACTION
	if kind == "condition":
		ace_type = ACEDefinition.ACEType.CONDITION
	elif kind == "expression":
		ace_type = ACEDefinition.ACEType.EXPRESSION
	return EventSheetCategoryInference.infer_category(raw_name.to_snake_case(), ace_type, _return_type_for_kind(kind))


## A pill Label with a rounded coloured background - the shared badge/chip look.
func _pill(text: String, bg: Color, fg: Color, font_size: int = 11) -> Label:
	var label: Label = Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(font_size))
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


## The role badge {label, bg, fg} for the preview pill.
func _role_pill_style(kind: String) -> Dictionary:
	match kind:
		"condition":
			return {"label": EventSheetL10n.translate("Condition"), "bg": EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, "fg": EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG}
		"expression":
			return {"label": EventSheetL10n.translate("Expression"), "bg": EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, "fg": EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG}
		_:
			return {"label": EventSheetL10n.translate("Action"), "bg": EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, "fg": EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG}


func _return_type_for_kind(kind: String) -> int:
	match kind:
		"condition":
			return TYPE_BOOL
		"expression":
			if _value_type_option.selected >= VALUE_TYPES.size():
				# A custom / not-listed return carried by return_type_name: store TYPE_MAX (Variant),
				# matching how the importer lifts one, so return_type never disagrees.
				return TYPE_MAX
			return int(VALUE_TYPES[maxi(_value_type_option.selected, 0)].get("type"))
		_:
			return TYPE_NIL


## The exact `-> Type` name currently chosen when it can't be a builtin entry, or "" otherwise.
func _selected_return_type_name() -> String:
	if _usable_kind() != "expression":
		return ""
	if _value_type_option.selected >= VALUE_TYPES.size():
		return _value_type_option.get_item_text(_value_type_option.selected).strip_edges()
	return ""


## Index of the VALUE_TYPES entry for a Variant.Type, or -1 when that type has none (Color, Array, ...).
func _builtin_value_type_index(return_type: int) -> int:
	for index: int in range(VALUE_TYPES.size()):
		if int(VALUE_TYPES[index].get("type")) == return_type:
			return index
	return -1


## The sentence the open value-type list shows for a VALUE_TYPES entry.
static func value_type_description(value_type: int) -> String:
	match value_type:
		TYPE_FLOAT:
			return EventSheetL10n.translate("A number with a fraction: speeds, distances, seconds.")
		TYPE_INT:
			return EventSheetL10n.translate("A whole number: counts, health, coins.")
		TYPE_STRING:
			return EventSheetL10n.translate("Text, like a name or a line of dialogue.")
		TYPE_BOOL:
			return EventSheetL10n.translate("True or false: answers a yes/no question.")
		TYPE_VECTOR2:
			return EventSheetL10n.translate("A 2D point or direction (x, y).")
		TYPE_VECTOR3:
			return EventSheetL10n.translate("A 3D point or direction (x, y, z).")
		TYPE_MAX:
			return EventSheetL10n.translate("Any type at all. The editor cannot check it for you.")
	return ""


## Appends an extra Value entry naming a type no fixed entry offers and selects it, so the dropdown
## shows the function's exact `-> Type`.
func _add_custom_value_type(type_name: String) -> void:
	EventSheetPopupUI.add_described_item(_value_type_option, type_name,
		EventSheetL10n.translate("A type of your own project, kept as it is written."))
	_value_type_option.select(_value_type_option.item_count - 1)


## Drops any extra entry a prior edit appended, so each open starts with only VALUE_TYPES.
func _reset_value_type_items() -> void:
	while _value_type_option.item_count > VALUE_TYPES.size():
		_value_type_option.remove_item(_value_type_option.item_count - 1)


## The exact generated `func` signature - built from a transient EventFunction run through the
## COMPILER's own static formatters, so the IN CODE line can never disagree with the code that ships.
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


## The Value row only matters for an Expression (Action = void, Condition = bool).
func _sync_value_type_visibility() -> void:
	if _value_type_row != null:
		_value_type_row.visible = _usable_kind() == "expression"


func _usable_kind() -> String:
	return str(USABLE_AS[maxi(_usable_option.selected, 0)].get("kind"))


## The carried parameters as [{id, type_name, default, description}].
func collect_params() -> Array[Dictionary]:
	return _carried_params.duplicate(true)


func _on_confirmed() -> void:
	var data: Dictionary = build_function_data()
	if not str(data.get("problem", "")).is_empty():
		_show_problem(str(data.get("problem")))
		return
	_dialog.hide()
	function_confirmed.emit(data)


## The amber reason under the form: shown while there is one, hidden when there is none.
func _show_problem(problem: String) -> void:
	_problem_label.text = "✗ %s" % problem if not problem.is_empty() else ""
	_problem_label.visible = not problem.is_empty()


## Validated window state -> {name, return_type, params, guards, description, expose,
## ace_display_name, ace_category} or {problem}. Names are snake_cased; the return type is derived
## from the chosen kind.
func build_function_data() -> Dictionary:
	var function_name: String = _name_edit.text.strip_edges().to_snake_case()
	if function_name.is_empty() or not function_name.is_valid_identifier():
		return {"problem": EventSheetL10n.translate("Function names must be valid identifiers (e.g. take_damage).")}
	# In edit mode the function's own current name is not a collision - only OTHER taken names are.
	if function_name != _original_name and _taken_names_provider.is_valid() \
			and (_taken_names_provider.call() as PackedStringArray).has(function_name):
		return {"problem": EventSheetL10n.translate("\"%s\" already exists on this sheet (function or variable).") % function_name}
	var params: Array[Dictionary] = collect_params()
	# GDScript requires defaulted parameters to be trailing - refuse a gap so the generated
	# function never fails to parse.
	var seen_default: bool = false
	for param: Dictionary in params:
		if not str(param.get("default", "")).is_empty():
			seen_default = true
		elif seen_default:
			return {"problem": EventSheetL10n.translate("Parameters with a default value must come after those without (\"%s\" has no default).") % str(param.get("id"))}
	return {
		"problem": "",
		"editing": _original_name,  # "" = create a new function; non-empty = update the one so named
		"name": function_name,
		"return_type": _return_type_for_kind(_usable_kind()),
		"return_type_name": _selected_return_type_name(),
		"params": params,
		"doc_comment": _doc_comment_edit.text.strip_edges(),
		"tool_button_label": _tool_button_edit.text.strip_edges(),
		# The picker metadata is CARRIED, not authored here (see the header).
		"description": _carried_description,
		"expose": _expose_check.button_pressed,
		"ace_display_name": _carried_display_name,
		"ace_category": _carried_category,
	}
