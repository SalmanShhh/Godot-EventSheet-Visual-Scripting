# EventSheet - ACE Parameters dialog component
# Builds a dynamic form from ACEDefinition.parameters metadata and emits params_confirmed
# when the user confirms. Supports:
#  - left-label / right-control rows with the parameter description rendered below,
#  - variable-reference params (hint == "variable_reference"): a dropdown of the sheet's
#    variables; when none exist the dialog blocks apply and tells the user to add one,
#  - expression params (hint == "expression"): an inline "fx" button opening an Insert
#    Expression picker (EXPRESSION ACE definitions) whose code template is inserted,
#  - a "Back" button (when opened from the picker) that returns to the picker.
@tool
class_name ACEParamsDialog
extends RefCounted

## Emitted when the user confirms the parameter form.
## values is a Dictionary of { param_id -> typed_value }.
signal params_confirmed(definition: ACEDefinition, values: Dictionary, context: Dictionary)
## Emitted when the user presses Back to return to the picker.
signal back_requested(definition: ACEDefinition, context: Dictionary)

const VARIABLE_REFERENCE_HINT := "variable_reference"
const EXPRESSION_HINT := "expression"
const NO_VARIABLES_PLACEHOLDER := "No variables available"
const BACK_ACTION := "back"
const ADD_ANOTHER_ACTION := "add_another"

## Session memory of the last-applied values per ace id, so re-adding the same ACE
## prefills what you used last time instead of the bare descriptor default (Tier-1
## tedium cut: the values you type repeatedly stop being re-typed). Static = shared
## across dialog instances; cleared only on editor restart.
static var _remembered_values: Dictionary = {}

var _dialog: ConfirmationDialog = null
var _form: VBoxContainer = null
## P0 - the ONE help strip at the foot. It describes whatever parameter is focused, validates it as
## it is typed, and shows the line of code the row becomes. It replaced the per-field description
## labels and their tooltips: four parameters read as four rows now, not four paragraphs.
var _help_strip: EventSheetPopupUI.HelpStrip = null
## P0 - the title band: the row this dialog is writing, in the sheet's own colours, filled in live
## from the fields. The window title carries the same sentence as plain text.
var _title_label: RichTextLabel = null
var _title_ace_label: Label = null
## P3 - the reason OK is not the obvious next step, sitting beside it rather than replacing the
## button with a grey rectangle that explains nothing.
var _ok_reason: Label = null
var _fields: Dictionary = {}
## The shipped descriptor dictionary per parameter id - what the strip describes and validates
## against. Kept beside _fields because a built widget knows its value, never its parameter.
var _param_dicts: Dictionary = {}
## The muted lines beside the choice fields, as the callables that re-read them. A value written by
## a fix (or by anything that is not a click on the list) reaches them through here: OptionButton's
## select() deliberately does not emit item_selected, so a caption wired only to that signal goes
## stale the moment the dialog writes into its own field.
var _choice_captions: Array[Callable] = []
## Which parameter the strip is currently speaking about ("" before anything is focused).
var _focused_key: String = ""
## The variable catalog the row can see, read ONCE per open. own_entries is the cheap half of the
## catalog on purpose - the whole catalog walks every row and every autoload, which is not something
## to do per keystroke.
var _variable_entries: Array[Dictionary] = []
## Who owns the variables in scope - the object this row belongs to, as the title leads with.
var _row_owner: String = ""
var _definition: ACEDefinition = null
var _context: Dictionary = {}
var _registry: EventSheetACERegistry = null
var _variable_names_provider: Callable = Callable()
var _variable_names: PackedStringArray = PackedStringArray()
var _apply_blocked: bool = false
var _back_button: Button = null
var _add_another_button: Button = null

# Sheet-context source for live ƒx validation (set by the dock; returns the active sheet).
var _lint_context_provider: Callable = Callable()

# The 🔍 scene-node picker and the ƒx Insert-Expression picker are self-contained dialog
# subsystems extracted to their own files (each owns its widgets + state) to keep this file
# maintainable. They reach back here through a _host reference for the shared bits that stay on
# this dialog: _fields, _validate_expression_field, _first_metadata_row, _best_node_reference,
# the ACE registry and the host-class reflection. This dialog keeps a thin delegate for every
# entry point so callers/tests and the by-class-name static calls are unchanged.
# Instantiated at declaration (not in init_dialog) so the pure delegates (e.g. _expression_template)
# work for tests that exercise this dialog's logic without calling init_dialog / a display server.
# init_dialog wires each one's _host back-reference via init(self).
var _node_picker: ACEParamsNodePicker = ACEParamsNodePicker.new()
var _expression_picker: ACEParamsExpressionPicker = ACEParamsExpressionPicker.new()


## Initialise and attach the dialog to parent_node. Must be called before open().
## registry powers the Insert Expression picker; variable_names_provider returns the
## current sheet variable names (Callable -> PackedStringArray/Array).
func init_dialog(parent_node: Node, registry: EventSheetACERegistry = null, variable_names_provider: Callable = Callable()) -> void:
	_registry = registry
	_variable_names_provider = variable_names_provider
	if _dialog != null:
		return
	_node_picker.init(self)
	_expression_picker.init(self)
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Parameters"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.close_requested.connect(_close)
	_dialog.visibility_changed.connect(func() -> void:
		if not _dialog.visible:
			_stop_audio_preview()
	)
	_dialog.canceled.connect(_close)
	_back_button = _dialog.add_button("◀ Back", true, BACK_ACTION)
	# "Apply & Add Another" keeps the picker loop going for repeated authoring
	# (add three conditions without re-opening the picker each time). Only shown in
	# append modes, where the target event is stable.
	_add_another_button = _dialog.add_button("✚ Apply & Add Another", false, ADD_ANOTHER_ACTION)
	_dialog.custom_action.connect(_on_custom_action)
	# P3 - the "Add hpp…" fix opens the Add variable dialog over this one. Coming back, the variable
	# may exist, so the catalog is re-read and every field re-checked the moment focus returns.
	_dialog.focus_entered.connect(_refresh_variable_context)
	parent_node.add_child(_dialog)

	# One content child, laid out top to bottom: the row being written, the fields, the help strip.
	# The strip lives OUTSIDE the scroll on purpose - it is the foot of the dialog, not the foot of
	# the form, and scrolling to read why a field is red is exactly the friction it exists to remove.
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_dialog.add_child(EventSheetPopupUI.margined(content))
	content.add_child(_build_title_band())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520.0, 200.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Fields fit the dialog width instead of growing a horizontal scrollbar (long
	# enum defaults like DisplayServer.WINDOW_MODE_FULLSCREEN used to overflow).
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 4)
	# Sunken inset card so the parameter rows read as a themed panel (matches the picker + function dialog).
	var form_card: PanelContainer = EventSheetPopupUI.panel_section(_form)
	form_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(form_card)

	_help_strip = EventSheetPopupUI.help_strip()
	content.add_child(_help_strip)

	# The reason OK will not do what you expect, beside OK. AcceptDialog lays its buttons out in one
	# row, so the reason sits where the eye already is when the hand reaches for the button.
	_ok_reason = _muted_label()
	var button_row: Node = _dialog.get_ok_button().get_parent()
	if button_row != null:
		button_row.add_child(_ok_reason)
		button_row.move_child(_ok_reason, _dialog.get_ok_button().get_index())


## The band at the top: the object this row belongs to, then the sentence the row will read as, then
## the ACE's own name at the right. It IS the row - what the sheet will show once OK is pressed -
## which is the one thing the old "<name> Parameters" title could never say.
func _build_title_band() -> Control:
	var band: HBoxContainer = HBoxContainer.new()
	band.add_theme_constant_override("separation", 8)
	_title_label = RichTextLabel.new()
	_title_label.bbcode_enabled = true
	# One line, never wrapped, and NOT fit_content: a RichTextLabel asked to size itself to its
	# content reports one glyph per line during the initial zero-width layout pass, and a sentence
	# measured that way makes the whole dialog taller than the screen.
	_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_label.fit_content = false
	_title_label.scroll_active = false
	_title_label.clip_contents = true
	_title_label.custom_minimum_size = Vector2(EventSheetPopupUI.HINT_WRAP_WIDTH,
		EventSheetPalette.scaled_f(22.0))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(_title_label)
	_title_ace_label = _muted_label()
	band.add_child(_title_ace_label)
	return band


## A one-line muted caption - the ACE's own name beside the sentence, the reason beside OK. No
## autowrap: both sit in a row that measures them, and a wrapped caption there collapses to a column
## of single letters on the first zero-width layout pass.
func _muted_label() -> Label:
	var label: Label = Label.new()
	label.add_theme_color_override("font_color", EventSheetPalette.TEXT_MUTED)
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func set_registry(registry: EventSheetACERegistry) -> void:
	_registry = registry


## Open the parameter form for the given ACEDefinition.
func open(definition: ACEDefinition, context: Dictionary) -> void:
	open_with_values(definition, context, {})


func open_with_values(definition: ACEDefinition, context: Dictionary, initial_values: Dictionary) -> void:
	if _dialog == null:
		push_error("ACEParamsDialog.open() called before init_dialog().")
		return
	_definition = definition
	_context = context.duplicate(true)
	_variable_names = _resolve_variable_names()
	_read_variable_context()
	# Fresh add (no existing params, not a re-edit) prefills from session memory of
	# the last values used for this ACE.
	var form_values: Dictionary = initial_values
	if initial_values.is_empty() and not _is_reedit_flow() and _remembered_values.has(definition.id):
		form_values = (_remembered_values[definition.id] as Dictionary).duplicate(true)
	_build_form(definition, form_values)
	_attach_recent_value_combos()
	_refresh_live_reading()
	_dialog.get_ok_button().disabled = _apply_blocked
	# Back returns to the picker - from the add flow OR a row edit (which opens in a replace_* mode),
	# so editing any ACE (action/expression too, not just conditions) can go back and swap.
	_set_back_visible(_can_return_to_picker())
	if _add_another_button != null:
		_add_another_button.visible = str(_context.get("mode", "")) in ["append_condition", "append_action"]
	_dialog.popup_centered(Vector2i(560, 380))
	_dialog.call_deferred("grab_focus")
	call_deferred("_focus_first_field")

## Rebuilds the parameter rows. Separated from open() so it can be exercised without
## popping the window (which requires a display server).
var _single_param_form: bool = false


var _batch_apply_checks: Dictionary = {}


## Recent values, attached in ONE post-pass over the finished form rather than inside each of
## the per-hint builders (plain string, expression, audio_path, scene_path... a per-builder
## sprinkle misses whichever field type is added next). Any text-bearing field (LineEdit or
## CodeEdit) sitting in a row container gains a ▾ listing the last values COMMITTED to that
## exact parameter across the project; picking REPLACES the field (a recent value is a complete
## answer). The button only appears once history exists - a dead dropdown on every fresh field
## would be noise - and never doubles up on rows that already carry a suggestions combo (the
## popup rebuilds on open there, with recents already leading its pool).
func _attach_recent_value_combos() -> void:
	if _definition == null:
		return
	var provider_id: String = _definition.provider_id
	var ace_id: String = _definition.id
	for key: Variant in _fields.keys():
		var field: Variant = _fields[key]
		if not (field is LineEdit or field is TextEdit):
			continue
		var row: Node = (field as Control).get_parent()
		if not (row is HBoxContainer):
			continue
		var has_combo: bool = false
		for sibling in row.get_children():
			if sibling is MenuButton:
				has_combo = true
		if has_combo:
			continue
		var param_key: String = str(key)
		if EventSheetRecentParamValues.recent_for(provider_id, ace_id, param_key).is_empty():
			continue
		var recents_button: MenuButton = MenuButton.new()
		recents_button.text = "▾"
		recents_button.tooltip_text = "Recent values for this parameter (you can still type any value)"
		var recents_popup: PopupMenu = recents_button.get_popup()
		var shown: Dictionary = {"pool": PackedStringArray()}
		recents_popup.about_to_popup.connect(func() -> void:
			shown["pool"] = EventSheetRecentParamValues.recent_for(provider_id, ace_id, param_key)
			EventSheetPopupUI.fill_suggestion_popup(recents_popup, shown["pool"], ""))
		recents_popup.id_pressed.connect(func(picked_id: int) -> void:
			var pool: PackedStringArray = shown["pool"]
			if picked_id < 0 or picked_id >= pool.size():
				return
			if field is LineEdit:
				(field as LineEdit).text = pool[picked_id]
				(field as LineEdit).caret_column = pool[picked_id].length()
			else:
				(field as TextEdit).text = pool[picked_id]
			_validate_expression_field(field)
			(field as Control).grab_focus())
		row.add_child(recents_button)


func _build_form(definition: ACEDefinition, initial_values: Dictionary) -> void:
	_fields.clear()
	_param_dicts.clear()
	_field_notes.clear()
	_choice_captions.clear()
	_focused_key = ""
	_batch_apply_checks.clear()
	_apply_blocked = false
	_single_param_form = definition.parameters.size() == 1
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()
	# Native-node ACEs link to the engine's own class reference - the vocabulary IS
	# Godot, and the built-in docs are one click away.
	var docs_class: String = str(definition.metadata.get("node_type", "")).strip_edges()
	if not docs_class.is_empty() and ClassDB.class_exists(docs_class):
		var docs_button: Button = Button.new()
		docs_button.text = "View %s in Godot Docs" % docs_class
		docs_button.flat = true
		docs_button.tooltip_text = "Open the built-in class reference for %s." % docs_class
		docs_button.pressed.connect(func() -> void: open_class_docs(docs_class))
		_form.add_child(docs_button)

	for parameter: Variant in definition.parameters:
		if not (parameter is Dictionary):
			continue
		_add_param_row(parameter as Dictionary, initial_values)

	_describe_dialog_itself()


func _add_param_row(param_dict: Dictionary, initial_values: Dictionary) -> void:
	var key: String = str(param_dict.get("id", ""))
	var hint: String = str(param_dict.get("hint", ""))
	_param_dicts[key] = param_dict

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = str(param_dict.get("display_name", key))
	label.custom_minimum_size = Vector2(160.0, 0.0)
	row.add_child(label)
	# Extension seam (EventSheets.register_param_editor): a factory registered for this param's
	# hint (or type_name) supplies the field. Contract: it returns a LineEdit (subclass freely -
	# buttons, popups, validation) so the dialog's value read (.text) needs no special case.
	var field: Control = null
	var editor_factory: Callable = EventSheets.param_editor_for(hint if not hint.is_empty() else str(param_dict.get("type_name", "")))
	if editor_factory.is_valid():
		var custom_field: Variant = editor_factory.call(param_dict, str(initial_values.get(key, param_dict.get("default", ""))))
		if custom_field is LineEdit:
			field = custom_field
			_fields[key] = custom_field
		else:
			push_warning("[EventSheets] param editor for '%s' must return a LineEdit - falling back." % key)
	if field == null:
		field = _create_field(param_dict, initial_values, key, hint)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	# Batch edit: each param gets its own "apply to all" checkbox, so one field can retune
	# across the selection while the others keep each instance's own value.
	if str(_context.get("mode", "")) == "batch_edit_params":
		var apply_check: CheckBox = CheckBox.new()
		apply_check.text = "all"
		apply_check.button_pressed = true
		apply_check.tooltip_text = "Checked: this value overwrites every matching instance.\nUnchecked: each instance keeps its own value for this parameter."
		row.add_child(apply_check)
		_batch_apply_checks[key] = apply_check
	_form.add_child(row)
	# P0 - no description under the field and no tooltip on it. The strip at the foot says both, for
	# the focused parameter only, and it is the one place a reader has to look.
	# Drag the param's NAME to scrub its number (the Inspector gesture). Only arms while the field
	# holds a plain number, so an expression can never be flattened into a literal by a stray drag.
	EventSheetNumberScrub.attach(label, field)
	# Dropdowns clip long entries instead of forcing the dialog wider. The field may BE the dropdown
	# or be the dropdown wrapped with its muted code note (K1), so the value-bearing widget is asked
	# for rather than assumed - a wrapped dropdown must clip exactly like a bare one.
	var dropdown: OptionButton = _fields.get(key) as OptionButton
	if dropdown != null:
		dropdown.clip_text = true
		dropdown.custom_minimum_size = Vector2(220.0, 0.0)
	# P1 - the line under each choice, from whichever source the hint names.
	_attach_option_notes(key, param_dict, row, _option_notes_for(param_dict))
	if hint == "input_action" or (hint == "group_reference" and not EventSheetGroupFacts.reads_sheet_groups(_definition_template(), key)):
		_attach_typed_choice_note(key, row, hint)
	_watch_field(key, label)

## Build a typed input widget for one parameter entry. The value-extraction node is
## registered in _fields[key]; the returned Control is what gets added to the row.
var _hint_factories: Dictionary = {}


func _ensure_hint_factories() -> void:
	if _hint_factories.is_empty():
		_hint_factories = {
			"key_capture": _create_key_capture_field,
			"input_action": _create_input_action_field,
			"group_reference": _create_group_reference_field,
			"scene_node": _create_scene_node_field,
			"bbcode_text": _create_bbcode_field,
			"audio_path": _create_audio_path_field,
			"scene_path": _create_scene_path_field,
			"animation_reference": _create_animation_field,
			"method_reference": _create_method_reference_field,
			"property_reference": _create_property_reference_field,
			"physics_layer_2d": _create_physics_layer_2d_field,
			"physics_layer_3d": _create_physics_layer_3d_field,
			"feature_tag": _create_feature_tag_field,
			"editor_icon": _create_editor_icon_field,
			"editor_preference": _create_editor_preference_field,
			"project_setting": _create_project_setting_field,
			"minutes_seconds": _create_minutes_seconds_field,
			"palette": _create_palette_field,
			"input_prompt_show": _create_input_prompt_show_field,
			"input_prompt_clear": _create_input_prompt_clear_field,
		}


## The glyph expression an input prompt is written with - the readable name of whatever the control
## is bound to right now, or nothing when it is bound to nothing. The same spelling the Show Prompt
## row writes, so a prompt an input window puts up and a prompt put up by hand are one line, not two
## dialects. Takes the control expression TWICE (it is asked about, then asked for).
const INPUT_PROMPT_GLYPH := "InputMap.action_get_events(%s)[0].as_text() if not InputMap.action_get_events(%s).is_empty() else \"\""


## The extra line an Open Input Window row writes when a prompt was chosen: the control's key goes on
## the label as the window opens. Leading newline, because the value is a TAIL appended to a template
## - an empty answer therefore leaves the row writing exactly the lines it wrote before prompts
## existed. "" whenever either half is missing, which is the no-prompt answer.
static func input_prompt_show_tail(label: String, action: String) -> String:
	var target: String = str(label).strip_edges()
	var control: String = str(action).strip_edges()
	if target.is_empty() or control.is_empty():
		return ""
	return "\n%s.text = %s" % [target, INPUT_PROMPT_GLYPH % [control, control]]


## The extra line a Close Input Window row writes: the prompt comes off the label as the window
## shuts, so it can never outlive the moment it was asking about. "" when no label was chosen.
static func input_prompt_clear_tail(label: String) -> String:
	var target: String = str(label).strip_edges()
	return "" if target.is_empty() else "\n%s.text = \"\"" % target


## Reads a show-tail back as {label, action}, or {} when the text is not one. The answer is proved by
## RECOMPOSING it - if the two halves do not rebuild the very bytes handed in, this was somebody
## else's line and the fields stay empty rather than being filled with a guess.
static func input_prompt_show_facts(tail: String) -> Dictionary:
	var marker: String = ".text = InputMap.action_get_events("
	var at: int = tail.find(marker)
	if at <= 0:
		return {}
	var label: String = tail.substr(0, at).strip_edges().trim_prefix("\n").strip_edges()
	var rest: String = tail.substr(at + marker.length())
	var close: int = rest.find(")[0].as_text()")
	if close <= 0:
		return {}
	var action: String = rest.substr(0, close)
	if input_prompt_show_tail(label, action) != tail:
		return {}
	return {"label": label, "action": action}


## Reads a clear-tail back as its label, or "" when the text is not one. Proved by recomposition, the
## same way the show-tail is.
static func input_prompt_clear_label(tail: String) -> String:
	var label: String = tail.strip_edges().trim_suffix("\n").strip_edges()
	var at: int = label.find(".text = \"\"")
	if at <= 0:
		return ""
	label = label.substr(0, at).strip_edges()
	return label if input_prompt_clear_tail(label) == tail else ""


## The Prompt field on Open Input Window (hint "input_prompt_show"): a tick, a label and a control -
## never a line of code. The value it carries IS the emitted line, composed here, so the row shows
## the player which key to press for exactly as long as the window is open.
func _create_input_prompt_show_field(key: String, default_value: Variant) -> Control:
	var facts: Dictionary = input_prompt_show_facts(str(default_value))
	var choices: Array = input_action_choices()
	var first_choice: String = str(choices[0]) if not choices.is_empty() else "\"ui_accept\""
	var action_row: Control = _create_autocomplete_field("%s__action" % key,
		choices, str(facts.get("action", first_choice)))
	var action_edit: LineEdit = _fields.get("%s__action" % key) as LineEdit
	_fields.erase("%s__action" % key)
	var container: VBoxContainer = _new_input_prompt_container(key,
		EventSheetL10n.translate("Show the control's key on a label while the window is open"),
		str(facts.get("label", "$PromptLabel")), not facts.is_empty())
	container.set_meta("input_prompt_kind", "show")
	container.set_meta("input_prompt_action", action_edit)
	container.add_child(action_row)
	_refresh_input_prompt_enabled(container)
	return container


## The Prompt field on Close Input Window (hint "input_prompt_clear"): the same tick and the same
## label, with no control to name - shutting a window takes the prompt off whatever it was showing.
func _create_input_prompt_clear_field(key: String, default_value: Variant) -> Control:
	var label: String = input_prompt_clear_label(str(default_value))
	var container: VBoxContainer = _new_input_prompt_container(key,
		EventSheetL10n.translate("Clear the prompt off its label as the window shuts"),
		label if not label.is_empty() else "$PromptLabel", not label.is_empty())
	container.set_meta("input_prompt_kind", "clear")
	_refresh_input_prompt_enabled(container)
	return container


## The half both prompt fields share: the tick that turns the prompt on and the label it goes on.
## Registered into _fields[key] as the value-bearing control, which is what makes the composed line
## the parameter's value.
func _new_input_prompt_container(key: String, tick_text: String, label_text: String, on: bool) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	var toggle: CheckBox = CheckBox.new()
	toggle.text = tick_text
	toggle.button_pressed = on
	container.add_child(toggle)
	var label_edit: LineEdit = LineEdit.new()
	label_edit.text = label_text
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_edit.tooltip_text = EventSheetL10n.translate(
		"The label that shows the prompt, as a node path - $PromptLabel.")
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(label_edit)
	container.add_child(label_edit)
	container.set_meta("input_prompt_toggle", toggle)
	container.set_meta("input_prompt_label", label_edit)
	toggle.toggled.connect(func(_pressed: bool) -> void: _refresh_input_prompt_enabled(container))
	_fields[key] = container
	return container


## The label and control fields only take answers while the tick is on - an untouched prompt field
## reads as no prompt at all, however much text was left sitting in it.
func _refresh_input_prompt_enabled(container: Control) -> void:
	var on: bool = (container.get_meta("input_prompt_toggle") as CheckBox).button_pressed
	(container.get_meta("input_prompt_label") as LineEdit).editable = on
	if container.has_meta("input_prompt_action"):
		(container.get_meta("input_prompt_action") as LineEdit).editable = on


## The line a prompt field stands for, or "" when its tick is off.
func _read_input_prompt_tail(container: Control) -> String:
	if not (container.get_meta("input_prompt_toggle") as CheckBox).button_pressed:
		return ""
	var label: String = (container.get_meta("input_prompt_label") as LineEdit).text
	if str(container.get_meta("input_prompt_kind", "")) != "show":
		return input_prompt_clear_tail(label)
	# No control field to read means no control was named, and a prompt with no control to ask for
	# is nothing at all - better an untouched row than a half-written line.
	if not container.has_meta("input_prompt_action"):
		return ""
	return input_prompt_show_tail(label,
		(container.get_meta("input_prompt_action") as LineEdit).text)


## X27. A length of time typed the way a player READS it - 3:00 - and stored as the seconds the
## emitted line needs. The visible field takes m:ss (or plain seconds, or any expression); a hidden
## mirror holds what actually ships, so the commit path reads seconds without knowing this field
## exists. A value that is not a time at all passes straight through, because the seconds slot is
## still an ordinary expression and a variable belongs in it as much as a number does.
func _create_minutes_seconds_field(key: String, default_value: Variant) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var seconds: LineEdit = LineEdit.new()
	seconds.text = str(default_value)
	seconds.visible = false
	var typed: LineEdit = LineEdit.new()
	typed.text = seconds_as_minutes_seconds(str(default_value))
	typed.tooltip_text = "Type it as minutes:seconds - 3:00 - or as plain seconds."
	typed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown: Label = Label.new()
	shown.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86, 0.95))
	shown.text = "= %s s" % seconds.text
	var sync: Callable = func(_ignored: Variant = null) -> void:
		seconds.text = minutes_seconds_as_seconds(typed.text)
		shown.text = "= %s s" % seconds.text
	typed.text_changed.connect(sync)
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(typed)
	row.add_child(typed)
	row.add_child(shown)
	row.add_child(seconds)
	_fields[key] = seconds
	return row


## X27. "180.0" -> "3:00", so a stored length opens in the field a reader can check at a glance. A
## value that is not a plain number comes back as itself: an expression is not a time to reformat.
static func seconds_as_minutes_seconds(value: String) -> String:
	var text: String = value.strip_edges()
	if not text.is_valid_float():
		return text
	var total: int = int(text.to_float())
	if total < 0:
		return text
	return "%d:%02d" % [total / 60, total % 60]


## X27. "3:00" -> "180.0", the seconds the emitted line carries. Anything that is not m:ss comes
## back untouched, so a plain number and a variable name both ship exactly as typed.
static func minutes_seconds_as_seconds(value: String) -> String:
	var text: String = value.strip_edges()
	var colon_at: int = text.find(":")
	if colon_at <= 0:
		return text
	var minutes: String = text.substr(0, colon_at).strip_edges()
	var seconds: String = text.substr(colon_at + 1).strip_edges()
	if not minutes.is_valid_int() or not seconds.is_valid_float():
		return text
	return String.num(minutes.to_int() * 60.0 + seconds.to_float(), 1)


## Feature-tag combo, LIVE (the input_action lesson: never bake project state into the
## descriptor): suggestions are read at dialog-open from the engine set + every export
## preset's custom_features, so a tag added in Project > Export appears immediately.
func _create_feature_tag_field(key: String, default_value: Variant) -> Control:
	return _create_autocomplete_field(key, EventSheetFeatureTags.suggestions(), default_value)


func _create_field(param_dict: Dictionary, initial_values: Dictionary, key: String, hint: String) -> Control:
	var field_type: int = int(param_dict.get("type", TYPE_NIL))
	var default_value: Variant = initial_values.get(key, param_dict.get("default_value", ""))
	var options: Array = param_dict.get("options", [])
	var autocomplete: Array = param_dict.get("autocomplete", [])

	# A lone Vector2/Vector3 param (positions, sizes…) splits into per-axis fields -
	# each axis is still a full GDScript expression (user call: "when setting
	# positions, split it into 2-3 params").
	if _single_param_form and hint in ["", EXPRESSION_HINT]:
		var vector_parts: PackedStringArray = vector_literal_parts(str(default_value))
		if not vector_parts.is_empty():
			return _create_vector_field(key, vector_parts)
	if hint == VARIABLE_REFERENCE_HINT or hint.begins_with(VARIABLE_REFERENCE_HINT + ":"):
		return _create_variable_reference_field(key, default_value, hint)
	if hint == "signal_reference" or hint.begins_with("signal_reference:"):
		return _create_signal_reference_field(key, default_value, hint.ends_with(":quoted"))
	if hint.begins_with("enum:"):
		return _create_enum_reference_field(key, default_value, hint.get_slice(":", 1))
	# Exact-match field hints dispatch through the registry - adding the next hint is
	# one registration line, not another branch (prefix hints stay above: they carry
	# arguments after ':').
	_ensure_hint_factories()
	if _hint_factories.has(hint):
		return (_hint_factories[hint] as Callable).call(key, default_value)
	if hint == "color" or field_type == TYPE_COLOR:
		return _create_color_field(key, default_value)
	if hint == EXPRESSION_HINT:
		return _create_expression_field(key, default_value)
	# Editable autocomplete combo (event-sheet-style): type any value, or filter/pick from
	# the behavior-declared suggestions. Takes priority over a fixed dropdown.
	if autocomplete is Array and not autocomplete.is_empty():
		return _create_autocomplete_field(key, autocomplete, default_value)
	if options is Array and not options.is_empty():
		# K1 - a dropdown whose words differ from the token it inserts shows that token muted beside
		# it: "≤  at most" reads as the row will read, `<=` says what the line will say. A list whose
		# labels ARE its values is returned untouched.
		return EventSheetPopupUI.code_noted_option(_create_options_field(key, options, default_value))
	if field_type == TYPE_BOOL:
		var check: CheckBox = CheckBox.new()
		check.button_pressed = _parse_bool(default_value)
		_fields[key] = check
		return check
	if field_type in [TYPE_INT, TYPE_FLOAT]:
		var spin: SpinBox = SpinBox.new()
		spin.step = 1.0 if field_type == TYPE_INT else 0.1
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.value = float(default_value)
		_fields[key] = spin
		return spin
	# Plain string params get the globe: toggled on, the value ships wrapped in
	# tr("...") so Godot's own POT extraction and TranslationServer pick it up at
	# runtime - localisation the Godot way, with zero plugin runtime. An incoming
	# value already wrapped in tr(...) unwraps into the field with the globe lit.
	var edit: LineEdit = LineEdit.new()
	var unwrapped: Dictionary = translatable_parts(str(default_value))
	edit.text = str(unwrapped.get("text", str(default_value)))
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Keyboard flow: Enter in any plain field presses OK (type, Enter, done).
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(edit)
	_fields[key] = edit
	if field_type != TYPE_STRING and not (default_value is String):
		return edit
	var globe: Button = Button.new()
	globe.toggle_mode = true
	globe.flat = true
	globe.text = "🌐"
	globe.tooltip_text = "Translatable: ships as tr(\"…\") so Godot's localisation\n(POT generation + TranslationServer) translates it at runtime."
	globe.button_pressed = bool(unwrapped.get("translatable", false))
	# Quiet until lit: most params are not player-facing text, so the affordance
	# whispers (dim, flat) and only reads solid once the value is translatable.
	globe.modulate = Color(1.0, 1.0, 1.0, 1.0 if globe.button_pressed else 0.4)
	globe.toggled.connect(func(on: bool) -> void:
		globe.modulate = Color(1.0, 1.0, 1.0, 1.0 if on else 0.4))
	edit.set_meta("translatable_toggle", globe)
	var string_row: HBoxContainer = HBoxContainer.new()
	string_row.add_child(edit)
	string_row.add_child(globe)
	return string_row


## Splits a stored param value into {text, translatable}: `tr("Hi")` -> {"Hi", true};
## anything else passes through untouched. Static and exact (only the canonical
## one-argument literal form unwraps; expressions with context stay verbatim).
static func translatable_parts(value: String) -> Dictionary:
	var trimmed: String = value.strip_edges()
	if trimmed.begins_with("tr(\"") and trimmed.ends_with("\")"):
		var inner: String = trimmed.substr(4, trimmed.length() - 6)
		# Reject values whose inner quotes would make this a multi-arg call
		# (e.g. tr("a", "ctx")) - only the plain literal form round-trips here.
		var unescaped: String = inner.replace("\\\"", "")
		if not unescaped.contains("\""):
			return {"text": inner.replace("\\\"", "\"").replace("\\\\", "\\"), "translatable": true}
	return {"text": value, "translatable": false}


func _create_options_field(key: String, options: Array, default_value: Variant) -> OptionButton:
	var dropdown: OptionButton = OptionButton.new()
	for option_entry in options:
		var option_key: String = ""
		var option_label: String = ""
		if option_entry is Dictionary:
			option_key = str((option_entry as Dictionary).get("key", ""))
			option_label = str((option_entry as Dictionary).get("label", option_key))
		else:
			option_key = str(option_entry)
			option_label = option_key
		if option_key.is_empty():
			continue
		dropdown.add_item(option_label)
		var index: int = dropdown.item_count - 1
		dropdown.set_item_metadata(index, option_key)
		if option_key == str(default_value):
			dropdown.select(index)
	_fields[key] = dropdown
	return dropdown


## Editable autocomplete combo (event-sheet-style "Combo" with free text): a LineEdit the
## user types into, plus a ▾ button whose popup lists the behavior-declared suggestions
## filtered by what's already typed. Picking inserts a suggestion verbatim; typing any
## other value is still allowed. The LineEdit IS the value-bearing field (read like text).
func _create_autocomplete_field(key: String, suggestions: Array, default_value: Variant,
		note_provider: Callable = Callable()) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var edit: LineEdit = LineEdit.new()
	edit.text = str(default_value)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = "type or pick…"
	# Enter still presses OK (keyboard flow stays identical to a plain field).
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(edit)
	row.add_child(edit)

	var suggestion_texts: PackedStringArray = PackedStringArray()
	for suggestion: Variant in suggestions:
		var suggestion_text: String = str(suggestion).strip_edges()
		if not suggestion_text.is_empty() and not suggestion_texts.has(suggestion_text):
			suggestion_texts.append(suggestion_text)

	# One shared combo implementation for the whole plugin (popup_ui.gd): rebuild-on-open,
	# pick-inserts, focus-return, Down-arrow opener with the dead-popup guard. Recent values
	# for THIS parameter lead the declared suggestions (most recent first, no duplicates) -
	# the combo rebuilds per open, so history committed this session shows immediately.
	var recents_provider_id: String = _definition.provider_id if _definition != null else ""
	var recents_ace_id: String = _definition.id if _definition != null else ""
	row.add_child(EventSheetPopupUI.autocomplete_combo(edit, func() -> PackedStringArray:
		var pool: PackedStringArray = EventSheetRecentParamValues.recent_for(recents_provider_id, recents_ace_id, key)
		for suggestion_text: String in suggestion_texts:
			if not pool.has(suggestion_text):
				pool.append(suggestion_text)
		return pool, note_provider))
	_fields[key] = edit
	return row


## Thin delegate kept for external callers (tests pin the filter through this name); the
## shared implementation lives on EventSheetPopupUI beside the combo builder it feeds.
static func _rebuild_autocomplete_popup(popup: PopupMenu, suggestions: PackedStringArray, filter_text: String) -> void:
	EventSheetPopupUI.fill_suggestion_popup(popup, suggestions, filter_text)


## Rich-text param editor (hint "bbcode_text"): Discord-style formatting for BBCode-taking
## params - select part of the text and hit B / I / U / S (buttons or Ctrl+B/I/U,
## Ctrl+Shift+S) and the selection wraps in the matching tag, toggling back off when it is
## already wrapped. A live preview underneath renders the current BBCode. The wrap logic
## never touches the quotes of a string literal - a selection containing one is refused.
func _create_bbcode_field(key: String, default_value: Variant) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 2)
	var edit: LineEdit = LineEdit.new()
	edit.text = str(default_value)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(edit)
	var preview: RichTextLabel = RichTextLabel.new()
	preview.bbcode_enabled = true
	preview.fit_content = true
	preview.scroll_active = false
	preview.custom_minimum_size = Vector2(0.0, 24.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var refresh_preview: Callable = func() -> void:
		var inner: String = edit.text.strip_edges()
		if inner.length() >= 2 and inner.begins_with("\"") and inner.ends_with("\""):
			inner = inner.substr(1, inner.length() - 2)
		preview.text = inner
	var wrap_with: Callable = func(tag: String) -> void:
		var wrapped: Dictionary = bbcode_wrap_selection(edit.text,
			edit.get_selection_from_column() if edit.has_selection() else edit.caret_column,
			edit.get_selection_to_column() if edit.has_selection() else edit.caret_column, tag)
		edit.text = str(wrapped.get("text", edit.text))
		edit.grab_focus()
		edit.select(int(wrapped.get("from", 0)), int(wrapped.get("to", 0)))
		edit.caret_column = int(wrapped.get("to", 0))
		refresh_preview.call()
	for entry: Array in [["B", "b", "Bold (Ctrl+B)"], ["I", "i", "Italic (Ctrl+I)"], ["U", "u", "Underline (Ctrl+U)"], ["S", "s", "Strikethrough (Ctrl+Shift+S)"]]:
		var button: Button = Button.new()
		button.text = str(entry[0])
		button.tooltip_text = str(entry[2])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(wrap_with.bind(str(entry[1])))
		toolbar.add_child(button)
	var color_button: Button = Button.new()
	color_button.text = "Color"
	color_button.tooltip_text = "Wrap the selection in [color=...] (edit the hex after)"
	color_button.focus_mode = Control.FOCUS_NONE
	color_button.pressed.connect(wrap_with.bind("color=yellow"))
	toolbar.add_child(color_button)
	edit.gui_input.connect(func(input_event: InputEvent) -> void:
		if not (input_event is InputEventKey) or not (input_event as InputEventKey).pressed:
			return
		var key_event: InputEventKey = input_event as InputEventKey
		if not key_event.is_command_or_control_pressed():
			return
		var handled: bool = true
		match key_event.keycode:
			KEY_B: wrap_with.call("b")
			KEY_I: wrap_with.call("i")
			KEY_U: wrap_with.call("u")
			KEY_S:
				if key_event.shift_pressed:
					wrap_with.call("s")
				else:
					handled = false
			_: handled = false
		if handled:
			edit.accept_event())
	edit.text_changed.connect(func(_new_text: String) -> void: refresh_preview.call())
	refresh_preview.call()
	column.add_child(toolbar)
	column.add_child(edit)
	column.add_child(preview)
	_fields[key] = edit
	return column


## The selection-wrap kernel, pure so tests pin it: wraps [from, to) of `text` in
## [tag]...[/tag] (the tag may carry an arg, "color=yellow"; the closer uses the bare
## name). Toggles OFF when the selection is already exactly wrapped or exactly surrounded.
## No selection inserts an empty pair with the caret inside. A selection containing a
## double quote is refused unchanged - wrapping across a string-literal boundary would
## break the GDScript the param compiles into.
static func bbcode_wrap_selection(text: String, from: int, to: int, tag: String) -> Dictionary:
	var bare_tag: String = tag.split("=")[0]
	var open_tag: String = "[%s]" % tag
	var close_tag: String = "[/%s]" % bare_tag
	var low: int = clampi(mini(from, to), 0, text.length())
	var high: int = clampi(maxi(from, to), 0, text.length())
	var selected: String = text.substr(low, high - low)
	if selected.contains("\""):
		return {"text": text, "from": low, "to": high}
	# Toggle off - the selection IS the wrapped run.
	if selected.begins_with(open_tag) and selected.ends_with(close_tag) and selected.length() >= open_tag.length() + close_tag.length():
		var inner: String = selected.substr(open_tag.length(), selected.length() - open_tag.length() - close_tag.length())
		return {"text": text.substr(0, low) + inner + text.substr(high), "from": low, "to": low + inner.length()}
	# Toggle off - the tags sit just outside the selection.
	if low >= open_tag.length() and text.substr(low - open_tag.length(), open_tag.length()) == open_tag and text.substr(high, close_tag.length()) == close_tag:
		return {"text": text.substr(0, low - open_tag.length()) + selected + text.substr(high + close_tag.length()), "from": low - open_tag.length(), "to": low - open_tag.length() + selected.length()}
	var wrapped_text: String = text.substr(0, low) + open_tag + selected + close_tag + text.substr(high)
	return {"text": wrapped_text, "from": low + open_tag.length(), "to": low + open_tag.length() + selected.length()}


## Live node-group picker (hint "group_reference"): an editable suggest-combo listing the
## groups that actually exist - the project's global groups (Project Settings > Groups) plus
## every group used in the edited scene - as the quoted literals templates expect. Enumerated
## when the dialog builds, so a group added a minute ago appears without a restart; free text
## stays allowed (expressions, variables, brand-new names).
func _create_group_reference_field(key: String, default_value: Variant) -> Control:
	# G2 - the same hint answers two questions. Set/Is Group Active name one of the SHEET's own
	# groups (its template builds the very `"__group_<name>_active"` member the compiler emits for a
	# runtime-toggleable group), so it gets the sheet's group list and the offer to make a group
	# switchable; every other group param means a NODE group and keeps the scene's list.
	if EventSheetGroupFacts.reads_sheet_groups(_definition_template(), key):
		return _create_sheet_group_field(key, default_value)
	var scene_root: Node = animation_scene_root_override
	if scene_root == null and Engine.is_editor_hint():
		scene_root = EditorInterface.get_edited_scene_root()
	return _create_autocomplete_field(key, group_choices(scene_root), default_value,
		func(group_value: String) -> String:
			return EventSheetParamFieldFactory.node_group_note(group_value, scene_root))


## The codegen template of the ACE being edited, or "" when the dialog has no definition.
func _definition_template() -> String:
	return str(_definition.metadata.get("codegen_template", "")) if _definition != null else ""


## The sheet-group picker: this sheet's own groups, switchable ones first, written as the quoted
## snake_case the template concatenates. A group that is NOT switchable yet is still offered - with
## the one-click offer to make it one, because "it is not in the list" teaches nobody why.
func _create_sheet_group_field(key: String, default_value: Variant) -> Control:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	var offered: Array[Dictionary] = EventSheetGroupFacts.choices(sheet)
	var suggestions: Array = []
	for entry: Dictionary in offered:
		suggestions.append(str(entry.get("value", "")))
	var row: Control = _create_autocomplete_field(key, suggestions, default_value)
	var edit: LineEdit = _fields.get(key) as LineEdit
	if edit == null:
		return row
	var offer: Button = Button.new()
	offer.text = EventSheetL10n.translate("Make switchable")
	offer.tooltip_text = EventSheetL10n.translate("Turns on \"Can be switched at runtime\" for this group, so this row can reach it.")
	offer.visible = false
	offer.pressed.connect(func() -> void:
		if _group_toggle_requester.is_valid() and bool(_group_toggle_requester.call(edit.text)):
			offer.visible = false
	)
	row.add_child(offer)
	var refresh_offer: Callable = func(_text: String = "") -> void:
		offer.visible = _group_toggle_requester.is_valid() \
			and EventSheetGroupFacts.needs_switch(offered, edit.text)
	edit.text_changed.connect(refresh_offer)
	refresh_offer.call()
	return row


## Every known node group, quoted: project-wide global groups first (they are the deliberate
## vocabulary), then groups found on nodes in the given scene, sorted and deduped. Pure and
## static (scene passed in), so tests pin it headless.
static func group_choices(scene_root: Node) -> Array:
	var names: Dictionary = {}
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if property_name.begins_with("global_group/"):
			names[property_name.trim_prefix("global_group/")] = true
	if scene_root != null:
		var pending: Array = [scene_root]
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			for group_name: StringName in node.get_groups():
				# Skip engine-internal groups (leading underscore, e.g. _vp_canvas_items).
				if not str(group_name).begins_with("_"):
					names[str(group_name)] = true
			for child: Node in node.get_children():
				pending.append(child)
	var sorted_names: Array = names.keys()
	sorted_names.sort()
	var choices: Array = []
	for group_name: Variant in sorted_names:
		choices.append("\"%s\"" % group_name)
	return choices


## Live Input Map picker (hint "input_action"): an editable suggest-combo whose choices are
## enumerated from the PROJECT'S Input Map when the dialog builds - NOT the snapshot baked into
## the definition at registry-refresh time, so actions added in Project Settings a minute ago
## appear without an editor restart. Free text stays allowed (expressions, variables).
## R23 - and a "New action…" button beside it, because the moment a control is missing is the moment
## you are typing its name into this very field. It writes the action into project.godot through the
## Input Map's own facts (deadzone + an empty binding list - binding it is the Input Map's job) and
## refreshes the picker, so the name the row is about exists before the row does.
func _create_input_action_field(key: String, default_value: Variant) -> Control:
	var row: Control = _create_autocomplete_field(key, input_action_choices(), default_value,
		EventSheetParamFieldFactory.input_action_note)
	var edit: LineEdit = _fields.get(key) as LineEdit
	if edit == null:
		return row
	var new_action: Button = Button.new()
	new_action.text = EventSheetL10n.translate("New action…")
	new_action.tooltip_text = EventSheetL10n.translate(
		"Add this name to the project's Input Map, then bind it in Project ▸ Input Map.")
	new_action.pressed.connect(func() -> void: _add_input_action(edit))
	row.add_child(new_action)
	return row


## W18. The editor-icon field: type or pick a name out of the editor's own icon set, and see the
## icon itself beside the field while you choose. Drawing it is the point - a tool author is picking
## a PICTURE, and "Node2D" versus "Sprite2D" is a name only until you look at them.
func _create_editor_icon_field(key: String, default_value: Variant) -> Control:
	var row: Control = _create_autocomplete_field(key, editor_icon_choices(), default_value)
	var edit: LineEdit = _fields.get(key) as LineEdit
	if edit == null:
		return row
	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(EventSheetPalette.scaled(20), EventSheetPalette.scaled(20))
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.tooltip_text = EventSheetL10n.translate("The editor icon this name draws.")
	row.add_child(preview)
	var refresh: Callable = func() -> void:
		preview.texture = editor_icon_named(edit.text)
	edit.text_changed.connect(func(_new_text: String) -> void: refresh.call())
	refresh.call()
	return row


## Every icon name the editor's own theme carries, as the quoted literals the templates expect.
## Empty whenever there is no editor around (a headless run, an embedder), so the field simply
## degrades to a plain text box instead of erroring.
static func editor_icon_choices() -> Array:
	var theme: Theme = _editor_theme()
	if theme == null:
		return []
	var choices: Array = []
	for icon_name: StringName in theme.get_icon_list("EditorIcons"):
		choices.append("\"%s\"" % String(icon_name))
	choices.sort()
	return choices


## The texture one quoted (or bare) icon name stands for, or null when there is no editor theme or
## no icon by that name - the preview simply stays blank rather than drawing a fallback that lies.
static func editor_icon_named(raw_name: String) -> Texture2D:
	var theme: Theme = _editor_theme()
	if theme == null:
		return null
	var wanted: String = raw_name.strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
	if wanted.is_empty() or not theme.has_icon(wanted, "EditorIcons"):
		return null
	return theme.get_icon(wanted, "EditorIcons")


## The editor's theme, or null outside the editor. Reached through Engine rather than by naming
## EditorInterface directly so this file still loads in a headless run and in an exported game.
static func _editor_theme() -> Theme:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var interface: Object = Engine.get_singleton("EditorInterface")
	if interface == null or not interface.has_method("get_editor_theme"):
		return null
	return interface.call("get_editor_theme") as Theme


## W18. The Editor Settings path field: every path the user's own preferences actually carry, so a
## tool author picks a real one instead of guessing at Godot's docs.
func _create_editor_preference_field(key: String, default_value: Variant) -> Control:
	return _create_autocomplete_field(key, editor_preference_choices(), default_value)


static func editor_preference_choices() -> Array:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return []
	var interface: Object = Engine.get_singleton("EditorInterface")
	if interface == null or not interface.has_method("get_editor_settings"):
		return []
	var settings: Object = interface.call("get_editor_settings")
	if settings == null:
		return []
	var choices: Array = []
	for property_info: Dictionary in settings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if property_name.contains("/") and not property_name.begins_with("_"):
			choices.append("\"%s\"" % property_name)
	choices.sort()
	return choices


## W18. The Project Settings path field. The input/* rows are left out: an action belongs in an
## input_action field, which already offers them with the quotes and the New action… door.
func _create_project_setting_field(key: String, default_value: Variant) -> Control:
	return _create_autocomplete_field(key, project_setting_choices(), default_value)


static func project_setting_choices() -> Array:
	var choices: Array = []
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if not property_name.contains("/") or property_name.begins_with("input/"):
			continue
		choices.append("\"%s\"" % property_name)
	choices.sort()
	return choices


## Says something back through the help strip - the one place this form reports what it thinks, so a
## New action… result does not need a surface of its own.
func _say(message: String) -> void:
	if _help_strip != null:
		_help_strip.show_note(EventSheetL10n.translate("Input Map"), message)


## Creates the action the field currently names. Refuses an empty or already-registered name rather
## than reporting a success that changed nothing; on success the field is normalised to the quoted
## literal the codegen templates expect, so the row is correct the instant it is added.
func _add_input_action(edit: LineEdit) -> void:
	var wanted: String = edit.text.strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
	if wanted.is_empty():
		_say(EventSheetL10n.translate("Type the name of the control first, then New action…"))
		return
	if EventSheetInputMapFacts.has_action(wanted):
		_say(EventSheetL10n.translate("\"%s\" is already in the Input Map.") % wanted)
		return
	if not EventSheetInputMapFacts.add_action(wanted):
		_say(EventSheetL10n.translate("\"%s\" could not be added to the Input Map.") % wanted)
		return
	EventSheetInputMapFacts.clear_cache()
	edit.text = "\"%s\"" % wanted
	_say(EventSheetL10n.translate("Added \"%s\" - bind it in Project ▸ Input Map.") % wanted)


## The project's input actions as the quoted string literals codegen templates expect
## ("\"jump\""): the project's OWN actions first (they are what the user cares about), then the
## handful of everyday ui_* built-ins. The other ~40 editor-facing ui_* actions ProjectSettings
## also carries (ui_cut, ui_focus_mode…) are deliberately left out - they would drown the
## project's actions; type one if you genuinely need it. Pure and static, so tests pin it.
static func input_action_choices() -> Array:
	var choices: Array = []
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if property_name.begins_with("input/") and not property_name.contains(".") and not property_name.trim_prefix("input/").begins_with("ui_"):
			choices.append("\"%s\"" % property_name.trim_prefix("input/"))
	for builtin: String in ["ui_accept", "ui_cancel", "ui_select", "ui_left", "ui_right", "ui_up", "ui_down", "ui_focus_next", "ui_focus_prev"]:
		var quoted: String = "\"%s\"" % builtin
		if not choices.has(quoted):
			choices.append(quoted)
	return choices


func _create_physics_layer_2d_field(key: String, default_value: Variant) -> Control:
	return _create_physics_layer_field(key, default_value, "2d_physics")


func _create_physics_layer_3d_field(key: String, default_value: Variant) -> Control:
	return _create_physics_layer_field(key, default_value, "3d_physics")


## The collision-mask picker: a checkable list of the project's physics layers - NAMED layers
## show their Project Settings names, so a beginner ticks "Walls" instead of computing the
## bitmask integer. The button label reads the selection back ("Walls, Enemies"); the value
## submitted is the plain mask int the ACE expects. Layers past 8 only list once the project
## names them - 32 anonymous checkboxes would bury the ones that matter.
func _create_physics_layer_field(key: String, default_value: Variant, dimension: String) -> Control:
	var button: MenuButton = MenuButton.new()
	button.flat = false
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var default_text: String = str(default_value).strip_edges()
	var mask: int = default_text.to_int() if default_text.is_valid_int() else 1
	button.set_meta("physics_mask", mask)
	var popup: PopupMenu = button.get_popup()
	popup.hide_on_checkable_item_selection = false
	for layer_index: int in 32:
		var layer_name: String = str(ProjectSettings.get_setting("layer_names/%s/layer_%d" % [dimension, layer_index + 1], "")).strip_edges()
		if layer_index >= 8 and layer_name.is_empty() and not ((mask >> layer_index) & 1):
			continue
		var label: String = ("Layer %d" % (layer_index + 1)) if layer_name.is_empty() else ("%d  %s" % [layer_index + 1, layer_name])
		popup.add_check_item(label, layer_index)
		popup.set_item_checked(popup.item_count - 1, bool((mask >> layer_index) & 1))
	popup.index_pressed.connect(func(index: int) -> void:
		popup.set_item_checked(index, not popup.is_item_checked(index))
		var value: int = 0
		for item_index: int in popup.item_count:
			if popup.is_item_checked(item_index):
				value |= 1 << popup.get_item_id(item_index)
		button.set_meta("physics_mask", value)
		button.text = _physics_mask_summary(value, dimension))
	button.text = _physics_mask_summary(mask, dimension)
	_fields[key] = button
	return button


## Human-readable readback of a mask: named layers by name, anonymous ones by number.
func _physics_mask_summary(mask: int, dimension: String) -> String:
	if mask == 0:
		return "No layers"
	var parts: PackedStringArray = PackedStringArray()
	for layer_index: int in 32:
		if (mask >> layer_index) & 1:
			var layer_name: String = str(ProjectSettings.get_setting("layer_names/%s/layer_%d" % [dimension, layer_index + 1], "")).strip_edges()
			parts.append(layer_name if not layer_name.is_empty() else str(layer_index + 1))
	var summary: String = ", ".join(parts)
	return summary if summary.length() <= 42 else summary.left(39) + "..."


## hint may carry a required base type ("variable_reference:Array") - the dropdown then
## offers only variables of that container type (Variant/untyped always qualify).
## Reflection pickers for the Helper ACEs' method/property params: an editable suggest-combo
## of the sheet host class's members (reflected from ClassDB), so Call Method / Set Property
## become pick-don't-type. Editable, so an expert can still type a member reflection misses.
func _create_method_reference_field(key: String, default_value: Variant) -> Control:
	return _create_autocomplete_field(key, reflected_members(_host_class_for_context(), "method"), default_value)


func _create_property_reference_field(key: String, default_value: Variant) -> Control:
	return _create_autocomplete_field(key, reflected_members(_host_class_for_context(), "property"), default_value)


## The sheet's host class (or Node) - the default Call Method / Set Property target (`self`).
func _host_class_for_context() -> String:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	return sheet.host_class if sheet != null and not sheet.host_class.strip_edges().is_empty() else "Node"


## Public method / property names declared on a class (reflected from ClassDB, sorted, no
## private `_`-prefixed members). Static + pure, so it is unit-testable without a dialog.
static func reflected_members(host_class: String, kind: String) -> Array:
	var names: Array = []
	if host_class.is_empty() or not ClassDB.class_exists(host_class):
		return names
	if kind == "property":
		for info: Dictionary in ClassDB.class_get_property_list(host_class):
			var member: String = str(info.get("name", ""))
			if not member.is_empty() and not member.begins_with("_") and not member.contains("/") and not names.has(member):
				names.append(member)
	else:
		for info: Dictionary in ClassDB.class_get_method_list(host_class):
			var member: String = str(info.get("name", ""))
			if not member.is_empty() and not member.begins_with("_") and not names.has(member):
				names.append(member)
	names.sort()
	return names


func _create_variable_reference_field(key: String, default_value: Variant, hint: String = VARIABLE_REFERENCE_HINT) -> Control:
	var required_type: String = hint.get_slice(":", 1) if hint.contains(":") else ""
	var offered_names: Array = []
	for candidate_name in _variable_names:
		if required_type.is_empty() or _variable_matches_type(str(candidate_name), required_type):
			offered_names.append(candidate_name)
	if offered_names.is_empty():
		# No (matching) variables exist: surface a disabled placeholder and block apply.
		_apply_blocked = true
		var placeholder: LineEdit = LineEdit.new()
		placeholder.text = NO_VARIABLES_PLACEHOLDER if required_type.is_empty() else "No %s variables - add one first" % required_type
		placeholder.editable = false
		_fields[key] = placeholder
		return placeholder
	var dropdown: OptionButton = OptionButton.new()
	for variable_name in offered_names:
		dropdown.add_item(variable_name)
		var index: int = dropdown.item_count - 1
		dropdown.set_item_metadata(index, variable_name)
		if variable_name == str(default_value):
			dropdown.select(index)
	if dropdown.selected < 0 and dropdown.item_count > 0:
		dropdown.select(0)
	_fields[key] = dropdown
	return dropdown


## True when the sheet variable's declared type starts with `required` (so "Array" also
## matches "Array[int]"); untyped/Variant variables always qualify.
func _variable_matches_type(variable_name: String, required: String) -> bool:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	if sheet == null:
		return true
	var type_name: String = ""
	if sheet.variables.has(variable_name):
		type_name = str((sheet.variables[variable_name] as Dictionary).get("type", ""))
	for entry in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == variable_name:
			type_name = (entry as LocalVariable).type_name
	if type_name.is_empty() or type_name == "Variant":
		return true
	return type_name.begins_with(required)


## Event-sheet-style object-signal picker: a dropdown of the host class's signals plus signals
## declared in the sheet's GDScript blocks (raw names - OnSignal connects them directly).
## The current value is always offered (custom names persist).
## quoted=true stores values as "name" string literals (Emit Signal's template wraps
## them in &{...}); false stores raw names (On Signal connects them directly).
func _create_signal_reference_field(key: String, default_value: Variant, quoted: bool = false) -> Control:
	var options: Array[String] = _signal_options()
	var current: String = str(default_value).strip_edges()
	if quoted:
		current = current.trim_prefix("\"").trim_suffix("\"")
	if not current.is_empty() and not options.has(current):
		options.insert(0, current)
	if options.is_empty():
		var fallback: LineEdit = LineEdit.new()
		fallback.text = current
		fallback.placeholder_text = "signal name"
		_fields[key] = fallback
		return fallback
	var dropdown: OptionButton = OptionButton.new()
	for signal_name in options:
		dropdown.add_item(signal_name)
		var index: int = dropdown.item_count - 1
		dropdown.set_item_metadata(index, format_quoted_literal(signal_name) if quoted else signal_name)
		if signal_name == current:
			dropdown.select(index)
	if dropdown.selected < 0 and dropdown.item_count > 0:
		dropdown.select(0)
	_fields[key] = dropdown
	return dropdown


## Host-class signals (ClassDB) + `signal x` declarations in the sheet's class-level
## GDScript blocks, sorted and deduplicated.
func _signal_options() -> Array[String]:
	var names: Array[String] = []
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	if sheet == null:
		return names
	for entry in sheet.events:
		if entry is SignalRow and (entry as SignalRow).enabled:
			var row_signal: String = (entry as SignalRow).signal_name
			if not row_signal.is_empty() and not names.has(row_signal):
				names.append(row_signal)
		if entry is RawCodeRow:
			for line in (entry as RawCodeRow).code.split("\n"):
				if line.begins_with("signal "):
					var declared: String = line.trim_prefix("signal ").strip_edges()
					declared = declared.get_slice("(", 0).strip_edges()
					if not declared.is_empty() and not names.has(declared):
						names.append(declared)
	if ClassDB.class_exists(sheet.host_class):
		for signal_info in ClassDB.class_get_signal_list(sheet.host_class):
			var signal_name: String = str(signal_info.get("name", ""))
			if not signal_name.is_empty() and not names.has(signal_name):
				names.append(signal_name)
	names.sort()
	return names


## Sheet-enum-driven dropdown (hint "enum:State"): options are the enum's members as
## State.MEMBER values - the Combo backed by a real enum.
func _create_enum_reference_field(key: String, default_value: Variant, enum_name: String) -> Control:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	var member_options: Array = []
	if sheet != null:
		for entry in sheet.events:
			if entry is EnumRow and (entry as EnumRow).enum_name == enum_name and (entry as EnumRow).enabled:
				for member: String in (entry as EnumRow).members:
					var member_name: String = member.get_slice("=", 0).strip_edges()
					member_options.append({"key": "%s.%s" % [enum_name, member_name], "label": member_name})
	if member_options.is_empty():
		var fallback: LineEdit = LineEdit.new()
		fallback.text = str(default_value)
		fallback.placeholder_text = "%s.MEMBER (enum not found in this sheet)" % enum_name
		_fields[key] = fallback
		return fallback
	return EventSheetPopupUI.code_noted_option(_create_options_field(key, member_options, default_value))


## Color picker param (hint "color" or a Color-typed param). The value round-trips as a
## canonical Color(r, g, b, a) literal so the sheet can show a swatch next to the text.
func _create_color_field(key: String, default_value: Variant) -> Control:
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(72.0, 0.0)
	var parsed: Variant = str_to_var(str(default_value))
	picker.color = parsed if parsed is Color else Color.WHITE
	_fields[key] = picker
	return picker


func _can_drop_on_expression(_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var kind: String = str((data as Dictionary).get("type", ""))
	return kind == "files" or kind == "nodes"


func _drop_on_expression(_position: Vector2, data: Variant, edit: CodeEdit) -> void:
	var snippet: String = drop_data_to_expression(data)
	if not snippet.is_empty():
		edit.insert_text_at_caret(snippet)


## Converts an editor drag payload to GDScript: FileSystem files become quoted res://
## paths; Scene-dock nodes become $Path references (relative to the edited scene root).
static func drop_data_to_expression(data: Variant) -> String:
	if not (data is Dictionary):
		return ""
	var payload: Dictionary = data as Dictionary
	match str(payload.get("type", "")):
		"files":
			var files: Array = payload.get("files", [])
			return format_quoted_literal(str(files[0])) if not files.is_empty() else ""
		"nodes":
			var nodes: Array = payload.get("nodes", [])
			if nodes.is_empty():
				return ""
			var node_path: String = str(nodes[0])
			var relative: String = node_path.get_file()
			var scene_root: Node = null
			if Engine.is_editor_hint():
				scene_root = EditorInterface.get_edited_scene_root()
				if scene_root != null:
					var root_prefix: String = str(scene_root.get_path())
					if node_path.begins_with(root_prefix + "/"):
						relative = node_path.trim_prefix(root_prefix + "/")
			# Prefer a scene-unique %Name (collapses a deep $A/B/C/D path to %D, reparent-proof) when the
			# dragged node carries one - the same flat handle the node picker hands back; else the $path.
			return _best_node_reference(scene_root, relative)
	return ""


## $Name for identifier-safe paths, $"Path/To Node" otherwise.
static func _node_reference(relative_path: String) -> String:
	var identifier_regex: RegEx = RegEx.new()
	if identifier_regex.compile("^[A-Za-z_][A-Za-z0-9_]*$") == OK and identifier_regex.search(relative_path) != null:
		return "$%s" % relative_path
	return "$\"%s\"" % relative_path


## The shortest robust reference for a picked node - Godot's answer to deep, node-heavy objects. When the
## node carries a scene-unique name (owner-scoped to this scene), returns "%Name": a flat handle that
## collapses a deep $A/B/C/D path to %D AND survives the node being moved in the tree. Otherwise falls back
## to the relative $path. Experienced Godot users mark key deep nodes unique for exactly this - so picking
## one should hand back the % shortcut, not the brittle path.
static func _best_node_reference(scene_root: Node, relative_path: String) -> String:
	if scene_root != null and not relative_path.is_empty() and relative_path != ".":
		var node: Node = scene_root.get_node_or_null(NodePath(relative_path))
		if node != null and node.unique_name_in_owner and (node.owner == scene_root or node == scene_root):
			return "%" + str(node.name)
	return _node_reference(relative_path)


## Audio params: a path field plus a ▶ button that previews the sound in the editor
## (loads the stream into a throwaway player under the dialog; ■ stops it).
## Shared scaffold for path-style fields (audio/scene/…): container + expanding
## LineEdit with FileSystem drag-drop, Enter-applies, and _fields registration.
## Returns {"container": HBoxContainer, "edit": LineEdit}; callers add their button.
func _build_path_field_base(key: String, default_value: Variant) -> Dictionary:
	var container: HBoxContainer = HBoxContainer.new()
	var path_edit: LineEdit = LineEdit.new()
	path_edit.text = str(default_value)
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(path_edit)
	path_edit.set_drag_forwarding(Callable(), _can_drop_on_expression, _drop_on_line_edit.bind(path_edit))
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(path_edit)
	_fields[key] = path_edit
	return {"container": container, "edit": path_edit}


func _create_audio_path_field(key: String, default_value: Variant) -> Control:
	var base: Dictionary = _build_path_field_base(key, default_value)
	var container: HBoxContainer = base["container"]
	var path_edit: LineEdit = base["edit"]
	var preview: Button = Button.new()
	preview.text = "▶"
	preview.tooltip_text = "Preview this sound"
	preview.pressed.connect(func() -> void:
		if _preview_player != null and is_instance_valid(_preview_player):
			_preview_player.queue_free()
			_preview_player = null
			preview.text = "▶"
			return
		var resource_path: String = path_edit.text.strip_edges().trim_prefix("\"").trim_suffix("\"")
		var stream: Resource = load(resource_path) if ResourceLoader.exists(resource_path) else null
		if not (stream is AudioStream):
			preview.tooltip_text = "Not an audio file: %s" % resource_path
			return
		_preview_player = AudioStreamPlayer.new()
		_preview_player.stream = stream
		container.add_child(_preview_player)
		_preview_player.finished.connect(func() -> void:
			if _preview_player != null and is_instance_valid(_preview_player):
				_preview_player.queue_free()
				_preview_player = null
			preview.text = "▶"
		)
		_preview_player.play()
		preview.text = "■"
	)
	container.add_child(preview)
	return container

var _preview_player: AudioStreamPlayer = null


## Scene params: a path field plus a Browse… button (editor file dialog filtered to
## scenes); the chosen path inserts quoted, ready for load()/Spawn Scene At.
func _create_scene_path_field(key: String, default_value: Variant) -> Control:
	var base: Dictionary = _build_path_field_base(key, default_value)
	var container: HBoxContainer = base["container"]
	var path_edit: LineEdit = base["edit"]
	var browse: Button = Button.new()
	browse.text = "Browse…"
	browse.pressed.connect(func() -> void: _browse_for_scene(path_edit))
	container.add_child(browse)
	return container

# One cached scene browser, parented to the PERSISTENT params dialog: no per-press
# accumulation, and a form rebuild can't kill it mid-interaction. The target retargets
# per open via a single stored reference (old lambda connections would pile up).
var _scene_file_dialog: EditorFileDialog = null
var _scene_browse_target: LineEdit = null


func _browse_for_scene(path_edit: LineEdit) -> void:
	if not Engine.is_editor_hint():
		return
	if _scene_file_dialog == null:
		_scene_file_dialog = EditorFileDialog.new()
		_scene_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_scene_file_dialog.add_filter("*.tscn", "Scenes")
		_scene_file_dialog.add_filter("*.scn", "Scenes (binary)")
		_scene_file_dialog.file_selected.connect(func(selected_path: String) -> void:
			if _scene_browse_target != null and is_instance_valid(_scene_browse_target):
				_scene_browse_target.text = format_quoted_literal(selected_path)
		)
		_dialog.add_child(_scene_file_dialog)
	_scene_browse_target = path_edit
	_scene_file_dialog.popup_file_dialog()


## X29. The palette parameter: a path to a colour-palette data asset, with every colour SET that
## asset carries drawn SIDE BY SIDE underneath the field. Choosing a palette is a looking task -
## "Deuteranopia" is a word until the three colours it swaps in are on the screen next to the three
## it replaces - so the field shows the sets instead of describing them. Typing stays free (an
## expression or a variable belongs in this slot as much as a path does), and a value that names
## nothing readable on disk simply leaves the strip out, so the field degrades to a plain path box.
func _create_palette_field(key: String, default_value: Variant) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var row: Control = _create_autocomplete_field(key, palette_asset_choices(), default_value)
	column.add_child(row)
	var edit: LineEdit = _fields.get(key) as LineEdit
	if edit == null:
		return column
	var browse: Button = Button.new()
	browse.text = EventSheetL10n.translate("Browse…")
	browse.pressed.connect(func() -> void: _browse_for_palette(edit))
	row.add_child(browse)
	var swatches: HBoxContainer = HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 12)
	swatches.tooltip_text = EventSheetL10n.translate(
		"Every colour set this palette asset carries, side by side.")
	column.add_child(swatches)
	edit.text_changed.connect(func(_new_text: String) -> void:
		fill_palette_swatches(swatches, edit.text))
	fill_palette_swatches(swatches, edit.text)
	return column


## Rebuilds the swatch strip for one typed value: one column per colour set, the set's name over it,
## and the role names down the left when the asset names them. Clears first, so retyping redraws
## rather than stacking. Static and container-in, so a headless test can hand it a plain HBox.
static func fill_palette_swatches(into: HBoxContainer, raw_value: String) -> void:
	for child: Node in into.get_children():
		into.remove_child(child)
		child.queue_free()
	var path: String = palette_path_of(raw_value)
	var sets: Array = palette_sets_at(path)
	into.visible = not sets.is_empty()
	if sets.is_empty():
		return
	var swatch_side: float = float(EventSheetPalette.scaled(18))
	var roles: PackedStringArray = palette_role_names_at(path)
	if not roles.is_empty():
		var role_column: VBoxContainer = VBoxContainer.new()
		role_column.add_theme_constant_override("separation", 2)
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0.0, swatch_side)
		role_column.add_child(spacer)
		for role_name: String in roles:
			var role_label: Label = Label.new()
			role_label.text = role_name
			role_label.custom_minimum_size = Vector2(0.0, swatch_side)
			role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			role_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
			role_label.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86, 0.95))
			role_column.add_child(role_label)
		into.add_child(role_column)
	for entry: Variant in sets:
		var colour_set: Dictionary = entry
		var set_column: VBoxContainer = VBoxContainer.new()
		set_column.add_theme_constant_override("separation", 2)
		var set_label: Label = Label.new()
		set_label.text = str(colour_set.get("name", ""))
		set_label.custom_minimum_size = Vector2(0.0, swatch_side)
		set_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
		set_column.add_child(set_label)
		var swatch_index: int = 0
		for colour: Color in (colour_set.get("colors", PackedColorArray()) as PackedColorArray):
			var swatch: ColorRect = ColorRect.new()
			swatch.color = colour
			swatch.custom_minimum_size = Vector2(swatch_side * 2.0, swatch_side)
			swatch.tooltip_text = ("#%s" % colour.to_html(false)) if swatch_index >= roles.size() \
				else "%s - #%s" % [roles[swatch_index], colour.to_html(false)]
			set_column.add_child(swatch)
			swatch_index += 1
		into.add_child(set_column)


## The asset path a typed palette value points at, or "" when the value is not a plain path at all
## (an expression, a variable, an empty field). Quotes come off, because the slot ships quoted; the
## test is the extension rather than a res:// prefix, so a palette kept beside a save file reads too.
static func palette_path_of(raw_value: String) -> String:
	var text: String = raw_value.strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
	return text if EventSheetDataTable.ASSET_EXTENSIONS.has(text.get_extension().to_lower()) else ""


## The colour SETS in one palette data asset, as [{name, colors}] in the asset's own order.
##
## The canonical shape is a ColorPaletteResource: `set_names` names the sets and `set_colors` holds
## one colour array per set. Any other asset whose exported fields are plainly colour arrays reads
## as a palette too, one set per field named after the field - a hand-rolled palette class from
## before this one existed still draws rather than showing nothing.
static func palette_sets_at(path: String) -> Array:
	var sets: Array = []
	if path.is_empty() or not ResourceLoader.exists(path):
		return sets
	var asset: Dictionary = EventSheetDataTable.asset_row(path)
	var values: Dictionary = asset.get("values", {}) if asset.get("values") is Dictionary else {}
	if values.is_empty():
		return sets
	var names: PackedStringArray = _palette_names_of(values.get("set_names"))
	var grouped: Variant = values.get("set_colors")
	if grouped is Array:
		var set_index: int = 0
		for entry: Variant in (grouped as Array):
			var colours: PackedColorArray = _palette_colors_of(entry)
			if not colours.is_empty():
				var set_name: String = names[set_index] if set_index < names.size() else str(set_index + 1)
				sets.append({"name": set_name, "colors": colours})
			set_index += 1
	if not sets.is_empty():
		return sets
	for column_entry: Variant in EventSheetDataTable.columns_at(path):
		var column: Dictionary = column_entry
		var field: String = str(column.get("name", ""))
		var field_colours: PackedColorArray = _palette_colors_of(values.get(field))
		if not field_colours.is_empty():
			sets.append({"name": str(column.get("words", field)), "colors": field_colours})
	return sets


## What each position in a set means, when the asset says so ("Danger", "Safe"). Empty is fine: the
## strip then draws the colours with no labels beside them rather than inventing names for them.
static func palette_role_names_at(path: String) -> PackedStringArray:
	if path.is_empty() or not ResourceLoader.exists(path):
		return PackedStringArray()
	var asset: Dictionary = EventSheetDataTable.asset_row(path)
	var values: Dictionary = asset.get("values", {}) if asset.get("values") is Dictionary else {}
	return _palette_names_of(values.get("role_names"))


static func _palette_names_of(value: Variant) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		return value as PackedStringArray
	if value is Array:
		for entry: Variant in (value as Array):
			names.append(str(entry))
	return names


static func _palette_colors_of(value: Variant) -> PackedColorArray:
	if value is PackedColorArray:
		return value as PackedColorArray
	var colours: PackedColorArray = PackedColorArray()
	if value is Array:
		for entry: Variant in (value as Array):
			if entry is Color:
				colours.append(entry as Color)
	return colours


## Every palette asset in the project, quoted the way the slot ships it. Read at dialog-open rather
## than baked into the descriptor, so an asset saved a minute ago is in the list. The plugin's own
## folders are skipped: a palette is the user's content, and walking addons/ would only cost time.
static func palette_asset_choices() -> Array:
	var choices: Array = []
	var pending: PackedStringArray = PackedStringArray(["res://"])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		for sub_directory: String in directory.get_directories():
			if not sub_directory.begins_with(".") and sub_directory != "addons":
				pending.append(directory_path.path_join(sub_directory))
		for file_name: String in directory.get_files():
			var bare: String = file_name.trim_suffix(".remap")
			if bare.get_extension().to_lower() != "tres":
				continue
			var full_path: String = directory_path.path_join(bare)
			if not palette_sets_at(full_path).is_empty():
				choices.append(format_quoted_literal(full_path))
	choices.sort()
	return choices

# One cached palette browser, parented to the persistent dialog for the same reason the scene
# browser is: no per-press accumulation, and a form rebuild cannot kill it mid-interaction.
var _palette_file_dialog: EditorFileDialog = null
var _palette_browse_target: LineEdit = null


func _browse_for_palette(path_edit: LineEdit) -> void:
	if not Engine.is_editor_hint():
		return
	if _palette_file_dialog == null:
		_palette_file_dialog = EditorFileDialog.new()
		_palette_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_palette_file_dialog.add_filter("*.tres", EventSheetL10n.translate("Palette assets"))
		_palette_file_dialog.file_selected.connect(func(selected_path: String) -> void:
			if _palette_browse_target != null and is_instance_valid(_palette_browse_target):
				_palette_browse_target.text = format_quoted_literal(selected_path)
				# Setting `text` in code raises no signal, so the strip is told by hand -
				# otherwise a browsed palette lands in the field with the old swatches under it.
				_palette_browse_target.text_changed.emit(_palette_browse_target.text)
		)
		_dialog.add_child(_palette_file_dialog)
	_palette_browse_target = path_edit
	_palette_file_dialog.popup_file_dialog()


## Drops onto plain LineEdit fields: files become quoted paths, nodes $Refs (reuses
## the expression-field converter so the two can never disagree).
func _drop_on_line_edit(_position: Vector2, data: Variant, edit: LineEdit) -> void:
	var snippet: String = drop_data_to_expression(data)
	if not snippet.is_empty() and is_instance_valid(edit):
		edit.text = snippet


## The single source of truth for "value as a GDScript string literal".
static func format_quoted_literal(value: String) -> String:
	return "\"%s\"" % value

## Animation params (the animation picker): a dropdown of every animation on every
## AnimationPlayer in the edited scene, plus a free-text fallback for names that only
## exist at runtime. Selections insert quoted.
var animation_scene_root_override: Node = null  # tests inject a tree here


func _create_animation_field(key: String, default_value: Variant) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = str(default_value)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(name_edit)
	var scene_root: Node = animation_scene_root_override
	if scene_root == null and Engine.is_editor_hint():
		scene_root = EditorInterface.get_edited_scene_root()
	var known: PackedStringArray = animation_options_from(scene_root)
	if not known.is_empty():
		var picker: OptionButton = OptionButton.new()
		picker.add_item("(animations)")
		for animation_name: String in known:
			picker.add_item(animation_name)
			# Real entries are tagged - position-proof against future separators.
			picker.set_item_metadata(picker.item_count - 1, animation_name)
		picker.item_selected.connect(func(index: int) -> void:
			var tagged: Variant = picker.get_item_metadata(index)
			if tagged is String:
				name_edit.text = format_quoted_literal(tagged)
		)
		container.add_child(picker)
	if _dialog is AcceptDialog:
		(_dialog as AcceptDialog).register_text_enter(name_edit)
	_fields[key] = name_edit
	return container


## Every animation name on every AnimationPlayer under root (sorted, deduped) -
## static + UI-free so the headless suite can pin it.
static func animation_options_from(root: Node) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if root == null:
		return names
	var seen: Dictionary = {}
	var pending: Array = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is AnimationPlayer:
			for animation_name: StringName in (node as AnimationPlayer).get_animation_list():
				seen[str(animation_name)] = true
		for child: Node in node.get_children():
			pending.append(child)
	for unique_name: Variant in seen.keys():
		names.append(str(unique_name))
	names.sort()
	return names


## The press-a-key workflow: a button that captures the next key press (storing the
## KEY_* constant), plus a fallback dropdown for keys that can't be detected.
func _create_key_capture_field(key: String, default_value: Variant) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	var capture: Button = Button.new()
	capture.text = str(default_value) if not str(default_value).is_empty() else "<click, then press a key>"
	capture.set_meta("key_constant", str(default_value))
	capture.toggle_mode = true
	capture.tooltip_text = "Click, then press the key you want."
	capture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capture.gui_input.connect(func(input_event: InputEvent) -> void:
		if capture.button_pressed and input_event is InputEventKey and (input_event as InputEventKey).pressed:
			var constant: String = key_constant_for((input_event as InputEventKey).physical_keycode)
			capture.set_meta("key_constant", constant)
			capture.text = constant
			capture.button_pressed = false
			capture.accept_event()
	)
	container.add_child(capture)
	var fallback: OptionButton = OptionButton.new()
	fallback.add_item("(or choose)")
	for key_name in ["KEY_SPACE", "KEY_ENTER", "KEY_ESCAPE", "KEY_SHIFT", "KEY_CTRL", "KEY_ALT", "KEY_TAB", "KEY_UP", "KEY_DOWN", "KEY_LEFT", "KEY_RIGHT"]:
		fallback.add_item(key_name)
	fallback.item_selected.connect(func(index: int) -> void:
		if index > 0:
			capture.set_meta("key_constant", fallback.get_item_text(index))
			capture.text = fallback.get_item_text(index)
	)
	container.add_child(fallback)
	_fields[key] = capture
	return container


## Physical keycode -> KEY_* constant name (KEY_F8, KEY_PAGEUP, KEY_SPACE…).
static func key_constant_for(keycode: int) -> String:
	var key_name: String = OS.get_keycode_string(keycode)
	# Keypad constants keep their underscore (KEY_KP_ADD); everything else drops spaces
	# (KEY_PAGEUP, KEY_BRACKETLEFT…).
	if key_name.begins_with("Kp "):
		return "KEY_KP_%s" % key_name.substr(3).to_upper().replace(" ", "")
	return "KEY_%s" % key_name.to_upper().replace(" ", "")


static func color_to_literal(value: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [String.num(value.r, 3), String.num(value.g, 3), String.num(value.b, 3), String.num(value.a, 3)]


func _create_expression_field(key: String, default_value: Variant) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	# A single-line CodeEdit instead of a LineEdit: same look, but with completion popups
	# for sheet variables/functions and host members (Ctrl+Space or just typing).
	var edit: CodeEdit = CodeEdit.new()
	edit.text = str(default_value)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0.0, 31.0)
	edit.scroll_fit_content_height = true
	# Wrap a long expression across the box width (with scroll_fit_content_height the box grows taller to
	# fit) so the whole thing is readable without a horizontal scroll - event-sheet style. Still one
	# LOGICAL line (wrap is visual only; the newline-strip below keeps Enter confirming the dialog).
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.gutters_draw_line_numbers = false
	edit.code_completion_enabled = true
	EventSheetPopupUI.configure_code_editor(edit)  # auto-close brackets/quotes - prevent syntax errors at the source
	# Expressions are plain GDScript - say so explicitly so event-sheet users learn there is no
	# separate expression language to memorize.
	edit.placeholder_text = "GDScript expression (e.g. health + 10)"
	edit.tooltip_text = "Plain GDScript - anything valid in an expression works here. Ctrl+Space completes sheet variables/functions and host members. Alt+Enter grows the box for a long expression (and shrinks it back)."
	# Alt+Enter toggles a TALL editing box (an event-sheet reflex): the same one logical expression, just
	# room to read it - wrap already fills the height. Plain Enter keeps confirming the dialog.
	edit.gui_input.connect(func(event: InputEvent) -> void:
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null or not key_event.pressed or not key_event.alt_pressed:
			return
		if key_event.keycode != KEY_ENTER and key_event.keycode != KEY_KP_ENTER:
			return
		var expanded: bool = edit.custom_minimum_size.y > 31.0
		edit.custom_minimum_size = Vector2(0.0, 31.0 if expanded else 128.0)
		edit.accept_event())
	# Godot-native drag & drop: dropping a FileSystem file inserts its quoted res:// path,
	# dropping a Scene-dock node inserts a $Path reference.
	edit.set_drag_forwarding(Callable(), _can_drop_on_expression, _drop_on_expression.bind(edit))
	edit.text_changed.connect(func() -> void:
		# Keep it single-line (Enter confirms the dialog instead of inserting a newline).
		if edit.text.contains("
"):
			var caret: int = edit.get_caret_column()
			edit.text = edit.text.replace("
", " ")
			edit.set_caret_column(mini(caret, edit.text.length()))
		_validate_expression_field(edit)
		edit.request_code_completion()
	)
	edit.code_completion_requested.connect(func() -> void: _populate_expression_completion(edit))
	_validate_expression_field(edit)
	container.add_child(edit)
	var fx_button: Button = Button.new()
	fx_button.text = "ƒx"
	fx_button.tooltip_text = "Find Expressions - open the expressions dictionary (floating: double-click inserts, stays open until you close it)"
	fx_button.pressed.connect(_open_expression_picker.bind(key))
	container.add_child(fx_button)
	var node_button: Button = Button.new()
	node_button.text = "🔍"
	node_button.tooltip_text = "Pick a scene node (search by name, class or path)"
	node_button.pressed.connect(_open_node_picker.bind(key))
	container.add_child(node_button)
	_fields[key] = edit
	return container

# ── Scene node picker (large-project search) ──────────────────────────────────────────
# The 🔍 picker dialog (search modes, filter chips, recents, used-in-sheet audit) lives in its own
# file - see ACEParamsNodePicker (ace_params_node_picker.gd). The methods/state below are thin
# delegates so callers, the 🔍 button's .bind, and the by-class-name static calls
# (ACEParamsDialog.node_matches_query, .extract_sheet_node_references, .scan_scene_files,
# ._node_is_uniqueable) keep working unchanged.


func _open_node_picker(key: String) -> void:
	_node_picker._open_node_picker(key)


## Builds the picker UI lazily - delegate kept for tests that drive it headlessly.
func _ensure_node_picker_ui() -> void:
	_node_picker._ensure_node_picker_ui()


## Population delegate kept for tests that drive an explicit tree.
func _populate_node_picker_from_root(scene_root: Node) -> void:
	_node_picker._populate_node_picker_from_root(scene_root)


## Selection-changed delegate kept for tests.
func _on_node_picker_selection_changed() -> void:
	_node_picker._on_node_picker_selection_changed()


## Query matching with the group:/script: prefixes (plain = name/class/path).
## Static delegate - reached as ACEParamsDialog.node_matches_query by tests/tools.
static func node_matches_query(node: Node, relative_path: String, query: String) -> bool:
	return ACEParamsNodePicker.node_matches_query(node, relative_path, query)


## Every $Name / $"Path" reference the sheet makes (params, blocks, pick filters).
## Static delegate - reached as ACEParamsDialog.extract_sheet_node_references by tests/tools.
static func extract_sheet_node_references(sheet: EventSheetResource) -> PackedStringArray:
	return ACEParamsNodePicker.extract_sheet_node_references(sheet)


## Cross-scene search: regex-scans .tscn node headers under res://.
## Static delegate - reached as ACEParamsDialog.scan_scene_files by tests/tools.
static func scan_scene_files(query: String, base_dir: String = "res://") -> Array:
	return ACEParamsNodePicker.scan_scene_files(query, base_dir)


## True when the node at relative_path can be made scene-unique. Pure → unit-testable.
## Static delegate - reached as ACEParamsDialog._node_is_uniqueable by tests.
static func _node_is_uniqueable(scene_root: Node, relative_path: String) -> bool:
	return ACEParamsNodePicker._node_is_uniqueable(scene_root, relative_path)


## Stops any in-flight audio preview (called when the dialog hides - a preview must
## never outlive the dialog that started it).
func _stop_audio_preview() -> void:
	if _preview_player != null and is_instance_valid(_preview_player):
		_preview_player.queue_free()
	_preview_player = null


## Depth-first: the first tree item carrying metadata - a real result row, skipping non-selectable
## group folders and empty-state placeholders. Lets Enter in the sub-picker search boxes commit the
## top match the way the main ACE picker's type-and-Enter does.
func _first_metadata_row(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var child: TreeItem = item.get_first_child()
	while child != null:
		if child.get_metadata(0) != null:
			return child
		var nested: TreeItem = _first_metadata_row(child)
		if nested != null:
			return nested
		child = child.get_next()
	return null


## Literal node-path references in an expression that can be checked against a scene: bare `$Name`,
## `$"Quoted/Path"`, and `get_node("Path")`. Unique-name (`%Name`) refs are handled separately by
## unique_names_in_expression(); dynamic get_node(expr) is not statically resolvable and is skipped.
static func node_references_in_expression(expression: String) -> PackedStringArray:
	var references: PackedStringArray = PackedStringArray()
	var dollar_re: RegEx = RegEx.new()
	dollar_re.compile("\\$(?:\"([^\"]+)\"|([A-Za-z_][A-Za-z0-9_/]*))")
	for hit: RegExMatch in dollar_re.search_all(expression):
		var quoted: String = hit.get_string(1)
		references.append(quoted if not quoted.is_empty() else hit.get_string(2))
	var get_node_re: RegEx = RegEx.new()
	get_node_re.compile("get_node\\(\"([^\"]+)\"\\)")
	for hit: RegExMatch in get_node_re.search_all(expression):
		references.append(hit.get_string(1))
	return references


## Unique-name references (Godot 4's `%Name` - the stable, refactor-proof way to reach a node, like an
## event-sheet object name): bare `%Name` and `%"Quoted Name"`. A `%` that sits INSIDE a string literal is
## a printf-style format specifier (`"%d"`, `"%.2f"`) and is NOT a node reference, so it is skipped.
static func unique_names_in_expression(expression: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var quoted_re: RegEx = RegEx.new()
	quoted_re.compile("%\"([^\"]+)\"")
	for hit: RegExMatch in quoted_re.search_all(expression):
		names.append(hit.get_string(1))
	var bare_re: RegEx = RegEx.new()
	bare_re.compile("%([A-Za-z_][A-Za-z0-9_]*)")
	for hit: RegExMatch in bare_re.search_all(expression):
		if _is_inside_string_literal(expression, hit.get_start()):
			continue  # "%d" / "%s" format specifier, not a node ref
		names.append(hit.get_string(1))
	return names


## Whether `index` falls inside a "…" string literal (odd number of double-quotes before it). Cheap
## heuristic - enough to tell a `%d` format specifier from a real `%Name` node reference.
static func _is_inside_string_literal(text: String, index: int) -> bool:
	var quotes: int = 0
	for i: int in range(mini(index, text.length())):
		if text[i] == "\"":
			quotes += 1
	return quotes % 2 == 1


## True when a trailing `%` is the modulo / string-format operator (preceded by a value: an
## identifier, number, `)`, `]`, or a closing quote) rather than the start of a `%Name` reference.
static func _looks_like_modulo(before_caret: String) -> bool:
	var stem: String = before_caret.substr(0, before_caret.length() - 1).rstrip(" 	")
	if stem.is_empty():
		return false
	var last: String = stem.substr(stem.length() - 1)
	return "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_)]\"'".contains(last)


## The first node reference in `expression` that does NOT resolve in `scene_root`, or "" when every
## reference resolves (or there are none / no scene to check). Checks both `$path`/get_node refs (via
## has_node) and `%Name` unique refs (via the scene's unique-name set); a `%`-ref is returned with its
## `%` so the warning reads back as `%Foo`. Absolute paths are skipped - they address the running tree,
## not the edited scene. Used to surface a typo'd reference as an author-time warning.
static func unresolved_node_reference(expression: String, scene_root: Node) -> String:
	if scene_root == null:
		return ""
	for reference: String in node_references_in_expression(expression):
		if reference.is_empty() or reference.begins_with("/"):
			continue
		if not scene_root.has_node(NodePath(reference)):
			return reference
	var unique_refs: PackedStringArray = unique_names_in_expression(expression)
	if not unique_refs.is_empty():
		var known: PackedStringArray = scene_unique_names(scene_root)
		for name: String in unique_refs:
			if not name.is_empty() and not known.has(name):
				return "%" + name
	return ""


## Every node under `scene_root` as a relative path (Player, UI, UI/Score, …), capped, for `$` node
## autocomplete. Depth-first so siblings stay grouped under their parent.
static func scene_node_paths(scene_root: Node, limit: int = 200) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	if scene_root != null:
		_collect_node_paths(scene_root, scene_root, paths, limit)
	return paths


static func _collect_node_paths(node: Node, scene_root: Node, paths: PackedStringArray, limit: int) -> void:
	for child: Node in node.get_children():
		if paths.size() >= limit:
			return
		paths.append(str(scene_root.get_path_to(child)))
		_collect_node_paths(child, scene_root, paths, limit)


## The unique names (`%Name`) reachable from anywhere in `scene_root`: nodes flagged
## unique_name_in_owner whose owner is the scene root (owner-scoped - an instanced sub-scene's own
## uniques are encapsulated and not reachable via `%` here). Drives `%` validation + autocomplete.
static func scene_unique_names(scene_root: Node, limit: int = 200) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if scene_root != null:
		_collect_unique_names(scene_root, scene_root, names, limit)
	return names


static func _collect_unique_names(node: Node, scene_root: Node, names: PackedStringArray, limit: int) -> void:
	for child: Node in node.get_children():
		if names.size() >= limit:
			return
		if child.unique_name_in_owner and child.owner == scene_root:
			names.append(child.name)
		_collect_unique_names(child, scene_root, names, limit)

## The scene to validate node paths against: a test-injected tree, else the edited scene (editor only).
var node_validation_scene_override: Node = null  # tests inject a tree here


func _validation_scene_root() -> Node:
	if node_validation_scene_override != null:
		return node_validation_scene_override
	return EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null


## X16. The node parameter, picked out of the layout that is open RIGHT NOW (hint "scene_node"): an
## editable suggest-combo whose choices are the tree the editor is showing, in the spellings a row
## writes. Enumerated when the dialog builds - never baked into the descriptor - so a node added a
## minute ago is in the list without an editor restart. Free text stays allowed (expressions,
## variables, nodes that only exist at runtime), and with no scene open (or headless) there are no
## choices at all, which leaves the ordinary text field the param had before.
func _create_scene_node_field(key: String, default_value: Variant) -> Control:
	return _create_autocomplete_field(key, scene_node_choices(_validation_scene_root()), default_value)


## Every node reference the open layout offers: `self` first (the sheet's own node is the commonest
## answer of all), then `%Name` for the scene-unique nodes - the refactor-proof reference, so it
## leads the paths - then `$Path` for the rest. A name a bare `$` cannot spell (a space in it) is
## quoted, because `$My Node` is not GDScript and `$"My Node"` is. Empty for a null scene: a picker
## with nothing in it IS a plain field, which is the no-scene-open fallback. Pure and static (the
## scene is passed in), so tests pin it headless.
static func scene_node_choices(scene_root: Node) -> Array:
	if scene_root == null:
		return []
	var choices: Array = ["self"]
	for unique_name: String in scene_unique_names(scene_root):
		choices.append("%" + unique_name)
	for node_path: String in scene_node_paths(scene_root):
		choices.append("$" + node_path if is_bare_node_path(node_path) else "$\"%s\"" % node_path)
	return choices


## The characters a node path may hold and still follow a bare `$`.
const BARE_NODE_PATH_CHARACTERS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_/"


## True when a node path can follow a bare `$` (letters, digits, underscores and the `/` between
## names). Anything else has to be written as `$"…"`.
static func is_bare_node_path(node_path: String) -> bool:
	if node_path.is_empty():
		return false
	for character: String in node_path:
		if not BARE_NODE_PATH_CHARACTERS.contains(character):
			return false
	return true


## Live expression validation: compile-checks the field against the sheet context
## (variables, host members) and tints the text red when it would not compile. The lint
## context provider is optional - without it the field stays unvalidated.
func _validate_expression_field(edit: Control) -> void:
	if not _lint_context_provider.is_valid():
		return
	var sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	var lint_result: Dictionary = EventSheetGDScriptLint.lint_expression(str(edit.get("text")), sheet)
	var key: String = _key_of_field(edit)
	var param: Dictionary = _param_dicts.get(key, {})
	if bool(lint_result.get("ok", true)):
		# Valid GDScript - but a literal $node / get_node("…") path that does NOT exist in the edited
		# scene is almost always a typo. Flag it amber (a warning, not a red error: the node may be
		# spawned at runtime) so "$Enmy" is caught at author time instead of failing silently in game.
		var unresolved: String = unresolved_node_reference(str(edit.get("text")), _validation_scene_root())
		if unresolved.is_empty():
			edit.remove_theme_color_override("font_color")
			_record_expression_note(edit, "", "", "", "", "")
		else:
			edit.add_theme_color_override("font_color", Color(0.92, 0.72, 0.35))
			# Teach the unique-name idiom: % resolves only once a node is marked unique in the scene.
			var missing_node: String = EventSheetL10n.translate(
				"There is no node named %s in this scene - right-click it in the scene tree and choose Access as Unique Name, or it may be spawned at runtime.") % unresolved \
				if unresolved.begins_with("%") else EventSheetL10n.translate(
				"There is no node %s in this scene yet - fine if it is spawned at runtime, otherwise check the path.") % unresolved
			_record_expression_note(edit, EventSheetParamFieldFactory.LEVEL_WARNING,
				EventSheetParamFieldFactory.strip_heading(param, EventSheetL10n.translate("no such node")),
				missing_node, "", "")
	else:
		edit.add_theme_color_override("font_color", Color(0.96, 0.45, 0.45))
		var undeclared: String = undeclared_identifier_in_expression(str(edit.get("text")), sheet)
		# Typo path first: if the unknown identifier is one edit away from something the sheet
		# DOES know, offer a one-click "Use it" before the create-new-variable fallback - far
		# friendlier than a red squiggle for a non-coder who fat-fingered a name.
		var suggestion: String = closest_known_identifier(undeclared, sheet)
		var body: String = EventSheetL10n.translate("This is not an expression this sheet can compile.")
		if not undeclared.is_empty():
			body = EventSheetL10n.translate("%s is not a variable of %s.") % [undeclared,
				_row_owner if not _row_owner.strip_edges().is_empty() else EventSheetL10n.translate("this object")]
			if not suggestion.is_empty():
				body += " " + EventSheetL10n.translate("Did you mean %s?") % suggestion
		_record_expression_note(edit, EventSheetParamFieldFactory.LEVEL_ERROR,
			EventSheetParamFieldFactory.strip_heading(param, EventSheetL10n.translate("not found")
				if not undeclared.is_empty() else EventSheetL10n.translate("will not compile")),
			body, undeclared, suggestion)
	if _dialog != null:
		_refresh_live_reading()


## Wires the sheet-context source for expression validation (returns EventSheetResource).
func set_lint_context_provider(provider: Callable) -> void:
	_lint_context_provider = provider


## Opens the editor's built-in class reference for a native class. Returns the help
## topic (testable headless, where there's no editor to open it in).
static func open_class_docs(docs_class: String) -> String:
	var topic: String = "class_name:%s" % docs_class
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var script_editor: Variant = (Engine.get_singleton("EditorInterface") as Object).call("get_script_editor")
		if script_editor is Object:
			(script_editor as Object).call("goto_help", topic)
	return topic

# ── Create-variable quick-fix: an undeclared identifier in an expression field grows
# a one-click "+ var" button (cancel → Add Variable → retype, collapsed to one click).
# The dialog stays dock-agnostic: the dock injects a creator Callable(name) -> bool.
var _variable_creator: Callable = Callable()
## P3 - what the "Add hpp…" fix calls: the dock opens the Add variable dialog with the name already
## filled in. Left invalid outside the dock, where the fix declares the variable outright instead.
var _variable_adder: Callable = Callable()
## G2 - what the "Make switchable" offer calls: the dock flips the named group's runtime toggle in
## one undo step and answers whether it did. Left invalid (no offer shown) outside the dock.
var _group_toggle_requester: Callable = Callable()
## P3 - what the last check said about each field, as {param id -> note}. An expression field fills
## its entry as it is typed (the lint runs there anyway); everything else is checked on demand. The
## strip and the reason beside OK both read from here, so one keystroke costs one check.
var _field_notes: Dictionary = {}


## The closest name the sheet already knows (variable / tree var / sheet function / host
## member) to an unknown identifier, within a small edit distance - powers the "Did you
## mean …?" typo quick-fix. "" when nothing is close enough (avoid nonsense suggestions).
static func closest_known_identifier(identifier: String, sheet: EventSheetResource) -> String:
	if identifier.length() < 2:
		return ""
	var candidates: Array[String] = []
	if sheet != null:
		for var_name: Variant in sheet.variables.keys():
			candidates.append(str(var_name))
		for row: Variant in sheet.events:
			if row is LocalVariable:
				candidates.append((row as LocalVariable).name)
		for function_entry: Variant in sheet.functions:
			if function_entry is EventFunction:
				candidates.append((function_entry as EventFunction).function_name)
	var host_class: String = sheet.host_class if sheet != null and ClassDB.class_exists(sheet.host_class) else "Node"
	for property: Dictionary in ClassDB.class_get_property_list(host_class):
		candidates.append(str(property.get("name")))
	var best: String = ""
	var best_distance: int = 3  # only suggest within 2 edits (strictly < 3)
	for candidate: String in candidates:
		if candidate.is_empty() or candidate == identifier:
			continue
		var distance: int = _edit_distance(identifier.to_lower(), candidate.to_lower())
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


## Levenshtein distance (small strings - identifiers), used only by closest_known_identifier.
static func _edit_distance(a: String, b: String) -> int:
	var n: int = a.length()
	var m: int = b.length()
	if n == 0:
		return m
	if m == 0:
		return n
	var previous: Array[int] = []
	for j: int in range(m + 1):
		previous.append(j)
	for i: int in range(1, n + 1):
		var current: Array[int] = [i]
		current.resize(m + 1)
		for j: int in range(1, m + 1):
			var cost: int = 0 if a[i - 1] == b[j - 1] else 1
			current[j] = min(min(previous[j] + 1, current[j - 1] + 1), previous[j - 1] + cost)
		previous = current
	return previous[m]


func set_variable_creator(creator: Callable) -> void:
	_variable_creator = creator


## Injects the "Add hpp…" opener (see _variable_adder). With one, the fix opens the Add variable
## dialog on the name that was typed; without one it declares the variable directly.
func set_variable_adder(adder: Callable) -> void:
	_variable_adder = adder


## Injects the "Make switchable" writer (see _group_toggle_requester).
func set_group_toggle_requester(requester: Callable) -> void:
	_group_toggle_requester = requester


## The probable culprit when an expression fails lint: the first plain identifier the
## sheet context can't account for. The engine never exposes its parse-error text to
## scripts (the lint result is generic), so this derives the answer from the
## expression itself - skipping string literals, member accesses (`x.y`), node refs
## (`$`/`%`/`&`), calls, keywords, sheet variables/functions/tree vars, host members,
## global classes and singletons. "" when the failure isn't identifier-shaped.
static func undeclared_identifier_in_expression(expression: String, sheet: EventSheetResource) -> String:
	var stripped: String = RegEx.create_from_string("\"[^\"]*\"|'[^']*'").sub(expression, " ", true)
	var skip_words: PackedStringArray = PackedStringArray([
		"true", "false", "null", "and", "or", "not", "in", "is", "as", "if", "else",
		"self", "host", "delta", "PI", "TAU", "INF", "NAN",
	])
	var host_class: String = sheet.host_class if sheet != null and ClassDB.class_exists(sheet.host_class) else "Node"
	var host_members: Dictionary = {}
	for property: Dictionary in ClassDB.class_get_property_list(host_class):
		host_members[str(property.get("name"))] = true
	var tree_variables: Dictionary = {}
	if sheet != null:
		for row: Variant in sheet.events:
			if row is LocalVariable:
				tree_variables[(row as LocalVariable).name] = true
	for ident_match: RegExMatch in RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*").search_all(stripped):
		var ident: String = ident_match.get_string()
		var before: String = stripped.substr(0, ident_match.get_start()).strip_edges(false, true)
		if before.ends_with(".") or before.ends_with("$") or before.ends_with("&") or before.ends_with("%"):
			continue
		if stripped.substr(ident_match.get_end()).strip_edges(true, false).begins_with("("):
			continue
		if skip_words.has(ident) or ClassDB.class_exists(ident) or Engine.has_singleton(ident):
			continue
		if sheet != null and (sheet.variables.has(ident) or tree_variables.has(ident)):
			continue
		var is_sheet_function: bool = false
		if sheet != null:
			for function_entry: Variant in sheet.functions:
				if function_entry is EventFunction and (function_entry as EventFunction).function_name == ident:
					is_sheet_function = true
					break
		if is_sheet_function or ClassDB.class_has_method(host_class, ident) or host_members.has(ident):
			continue
		return ident
	return ""


## P3 - what a failing expression field is complaining about, as the strip's note. The two buttons
## that used to grow beside the field ("+ var hp", "Use hp") are the note's FIXES now: one place a
## reader looks for a problem, one wording for it, and the same shape the parameter checks answer in.
func _record_expression_note(edit: Control, level: String, heading: String, body: String,
		unknown: String, suggestion: String) -> void:
	var key: String = _key_of_field(edit)
	if key.is_empty():
		return
	if level.is_empty():
		_field_notes.erase(key)
		return
	var fixes: Array = []
	if not suggestion.is_empty():
		fixes.append({"kind": "use", "name": suggestion})
	if not unknown.is_empty() and (_variable_creator.is_valid() or _variable_adder.is_valid()):
		fixes.append({"kind": "add", "name": unknown})
	_field_notes[key] = {
		"level": level,
		"heading": heading,
		"body": body,
		"reason": EventSheetL10n.translate("fix %s first") % _param_label(key) if level == EventSheetParamFieldFactory.LEVEL_ERROR
			else EventSheetL10n.translate("check %s") % _param_label(key),
		"fixes": fixes,
	}


## The parameter id a built widget answers for, or "" for a widget this dialog did not build (the
## Properties bar borrows the builders through the factory, with no form behind them).
func _key_of_field(field: Control) -> String:
	for key: Variant in _fields.keys():
		if _fields[key] == field:
			return str(key)
	return ""


## The hint one parameter carries, read off the shipped descriptor this dialog built it from.
func _hint_of(key: String) -> String:
	return str((_param_dicts.get(key, {}) as Dictionary).get("hint", ""))


## A parameter as a sentence names it - its display name, or its id when it has none.
func _param_label(key: String) -> String:
	var param: Dictionary = _param_dicts.get(key, {})
	return str(param.get("display_name", key)) if not param.is_empty() else key


## Fills the completion popup with sheet variables/functions + host members (same source
## as the GDScript-block editor, so the vocabulary matches everywhere).
func _populate_expression_completion(edit: CodeEdit) -> void:
	if not _lint_context_provider.is_valid():
		return
	var sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	var before_caret: String = edit.get_line(edit.get_caret_line()).substr(0, edit.get_caret_column())
	# Context-aware: `host.` / typed-variable. / $Behavior. offer that type's members.
	for candidate: Dictionary in EventSheetGDScriptLint.completion_for_context(before_caret, sheet):
		edit.add_code_completion_option(
			int(candidate.get("kind", CodeEdit.KIND_PLAIN_TEXT)),
			str(candidate.get("label", "")),
			str(candidate.get("label", ""))
		)
	# The expressions dictionary, while typing (event-sheet style): every EXPRESSION verb the
	# picker window lists also autocompletes right in the field - display name shown, the code
	# fragment inserted. Skipped in member (`x.`) position, where only that type's members apply.
	if _registry != null and not text_before_dot(before_caret):
		for expression_definition: ACEDefinition in _registry.get_all_definitions():
			if expression_definition.ace_type == ACEDefinition.ACEType.EXPRESSION:
				edit.add_code_completion_option(
					CodeEdit.KIND_FUNCTION,
					expression_definition.display_name,
					_expression_picker._expression_template(expression_definition)
				)
	# Right after a `$`, offer the edited scene's node paths so a path can be typed-and-picked, not only
	# selected through the 🔍 picker. The `$` is already typed, so the inserted text is the bare path.
	if before_caret.ends_with("$") and Engine.is_editor_hint():
		for node_path: String in scene_node_paths(EditorInterface.get_edited_scene_root()):
			edit.add_code_completion_option(CodeEdit.KIND_NODE_PATH, "$" + node_path, node_path)
	# Right after a `%`, offer the scene's unique names (the stable, refactor-proof references) - unless
	# the `%` is the modulo / string-format operator (a % b, "%d" % x).
	if before_caret.ends_with("%") and Engine.is_editor_hint() and not _looks_like_modulo(before_caret):
		for unique_name: String in scene_unique_names(EditorInterface.get_edited_scene_root()):
			edit.add_code_completion_option(CodeEdit.KIND_NODE_PATH, "%" + unique_name, unique_name)
	edit.update_code_completion_options(true)
	edit.set_code_hint(EventSheetGDScriptLint.signature_hint(before_caret, sheet))


## True when the caret sits in member position (`token.`), where only that type's members
## should complete - the dictionary's global verbs would be noise there.
static func text_before_dot(before_caret: String) -> bool:
	return before_caret.ends_with(".")


## Extract the typed value from a registered field node.
## "Vector2(0, 0)" → ["0", "0"]; "Vector3(1, 2, 3)" → ["1", "2", "3"]; [] otherwise.
## Splits on TOP-LEVEL commas only, so nested calls inside an axis survive.
static func vector_literal_parts(value: String) -> PackedStringArray:
	var trimmed: String = value.strip_edges()
	var dims: int = 0
	if trimmed.begins_with("Vector2(") and trimmed.ends_with(")"):
		dims = 2
	elif trimmed.begins_with("Vector3(") and trimmed.ends_with(")"):
		dims = 3
	if dims == 0:
		return PackedStringArray()
	var inner: String = trimmed.substr(8, trimmed.length() - 9)
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for character in inner:
		if character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
		if character == "," and depth == 0:
			parts.append(current.strip_edges())
			current = ""
		else:
			current += character
	parts.append(current.strip_edges())
	return parts if parts.size() == dims else PackedStringArray()


## Per-axis fields composing back to "VectorN(x, y[, z])" on extract.
func _create_vector_field(key: String, parts: PackedStringArray) -> Control:
	var container: HBoxContainer = HBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	var axis_edits: Array = []
	var axis_names: PackedStringArray = PackedStringArray(["x", "y", "z"])
	for axis in parts.size():
		var axis_label: Label = Label.new()
		axis_label.text = axis_names[axis]
		container.add_child(axis_label)
		var axis_edit: LineEdit = LineEdit.new()
		axis_edit.text = parts[axis]
		axis_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		axis_edit.tooltip_text = "Any GDScript expression works per axis."
		_dialog.register_text_enter(axis_edit)
		container.add_child(axis_edit)
		axis_edits.append(axis_edit)
	container.set_meta("vector_axis_edits", axis_edits)
	_fields[key] = container
	return container


func _extract_value(field: Control) -> Variant:
	if field is CheckBox:
		return (field as CheckBox).button_pressed
	if field is MenuButton and field.has_meta("physics_mask"):
		return int(field.get_meta("physics_mask"))
	# An input-window prompt field: a tick, a label and (on the open row) a control, read back as the
	# one line they stand for - so nothing above this has to know the prompt is code at all.
	if field.has_meta("input_prompt_kind"):
		return _read_input_prompt_tail(field)
	if field.has_meta("vector_axis_edits"):
		var axis_values: PackedStringArray = PackedStringArray()
		for axis_edit: Variant in (field.get_meta("vector_axis_edits") as Array):
			axis_values.append((axis_edit as LineEdit).text.strip_edges())
		return "Vector%d(%s)" % [axis_values.size(), ", ".join(axis_values)]
	if field is OptionButton:
		var option_button: OptionButton = field as OptionButton
		var selected_index: int = option_button.selected
		if selected_index < 0:
			return ""
		var metadata: Variant = option_button.get_item_metadata(selected_index)
		if metadata != null:
			return metadata
		return option_button.get_item_text(selected_index)
	if field is SpinBox:
		var spin: SpinBox = field as SpinBox
		if is_equal_approx(spin.step, 1.0):
			return int(spin.value)
		return spin.value
	if field is ColorPickerButton:
		return color_to_literal((field as ColorPickerButton).color)
	if field is Button and field.has_meta("key_constant"):
		return str(field.get_meta("key_constant"))
	if field is LineEdit:
		# A pressed globe wraps the literal in tr(...) INSIDE THE VALUE - the whole
		# translatable feature is this convention: emission substitutes it verbatim
		# (so Godot's POT scan finds it), the lifter captures it back untouched, and
		# the toggle merely reads/writes the wrapper. No schema, no compiler change.
		if field.has_meta("translatable_toggle"):
			var globe: Button = field.get_meta("translatable_toggle")
			if globe != null and globe.button_pressed:
				return "tr(\"%s\")" % (field as LineEdit).text.replace("\\", "\\\\").replace("\"", "\\\"")
		return (field as LineEdit).text
	if field is CodeEdit:
		# Expression fields are single-line CodeEdits (for completion); strip any newline
		# completion may sneak in.
		return (field as CodeEdit).text.replace("
", " ").strip_edges()
	return ""


## First expression field whose text fails the compile-check (null = all valid). The
## commit guardrail: invalid GDScript never reaches the sheet.
func _first_invalid_expression() -> Control:
	if not _lint_context_provider.is_valid():
		return null
	var sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	for key: Variant in _fields.keys():
		var field: Control = _fields[key]
		if field is CodeEdit and not bool(EventSheetGDScriptLint.lint_expression(str(field.get("text")), sheet).get("ok", true)):
			return field
	return null


## The first expression field with a STRUCTURAL syntax error (unbalanced brackets / unterminated string),
## or null. Context-free, so it catches malformed code even when the symbol-aware lint can't run (an
## unhealthy lint context) - the always-on backstop that closes _first_invalid_expression's skip path.
func _first_structural_error_field() -> Control:
	for key: Variant in _fields.keys():
		var field: Control = _fields[key]
		if field is CodeEdit and not EventSheetGDScriptLint.structural_syntax_error(str(field.get("text"))).is_empty():
			return field
	return null


## The expression field that should block Apply, with its message, or {} when clear. Structural errors
## (always wrong, no context needed) take priority over the symbol-aware lint and run unconditionally.
func _blocking_expression_field() -> Dictionary:
	var structural_field: Control = _first_structural_error_field()
	if structural_field != null:
		return {"field": structural_field, "message": "✗ %s" % EventSheetGDScriptLint.structural_syntax_error(str(structural_field.get("text")))}
	var invalid_field: Control = _first_invalid_expression() if _lint_context_healthy() else null
	if invalid_field != null:
		return {"field": invalid_field, "message": "✗ An expression doesn't compile - fix it before applying."}
	return {}


## True unless the lint scratch ITSELF is broken (a sheet variable shadowing a host
## member makes the scratch unparseable, so every expression "fails" and the OK
## guardrail would lock the user out - verified by linting a bare literal).
func _lint_context_healthy() -> bool:
	if not _lint_context_provider.is_valid():
		return true
	var baseline_sheet: EventSheetResource = _lint_context_provider.call() as EventSheetResource
	return bool(EventSheetGDScriptLint.lint_expression("0", baseline_sheet).get("ok", true))


func _on_confirmed() -> void:
	if _definition == null or _apply_blocked:
		return
	# Guardrail (event-sheet-style): block the commit while any expression is malformed. A structural
	# syntax error (unbalanced brackets / unterminated string) blocks ALWAYS; a symbol-aware lint error
	# blocks when the lint context is healthy.
	var blocker: Dictionary = _blocking_expression_field()
	if not blocker.is_empty():
		if _help_strip != null:
			_help_strip.show_note(EventSheetL10n.translate("Cannot be written"),
				str(blocker.get("message", "")), EventSheetParamFieldFactory.LEVEL_ERROR)
		if _ok_reason != null:
			_ok_reason.text = EventSheetL10n.translate("this will not compile")
		(blocker.get("field") as Control).grab_focus()
		if _dialog != null and is_instance_valid(_dialog) and _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered", Vector2i(520, 380))
		return
	_commit(false)


## Shared apply path for OK and "Apply & Add Another". When chaining, the context
## carries chain_add so the dock reopens the picker in the same append mode; the
## values are remembered either way.
func _commit(chain: bool) -> void:
	var values: Dictionary = {}
	for key: Variant in _fields.keys():
		values[str(key)] = _extract_value(_fields[key])
	_remembered_values[_definition.id] = values.duplicate(true)
	# Recent values: every committed STRING value joins its parameter's project-wide ring, so the
	# suggestion combo can offer it next time (bools/checkboxes have nothing worth ringing).
	for key: Variant in values.keys():
		if values[key] is String:
			EventSheetRecentParamValues.record(_definition.provider_id, _definition.id, str(key), str(values[key]))
	var context: Dictionary = _context.duplicate(true)
	if chain:
		context["chain_add"] = true
	# Batch edit: only the checked params overwrite the other instances - the apply step
	# leaves every unchecked key at each instance's own value.
	if not _batch_apply_checks.is_empty():
		var apply_keys: Array = []
		for check_key: Variant in _batch_apply_checks.keys():
			var check: CheckBox = _batch_apply_checks[check_key]
			if is_instance_valid(check) and check.button_pressed:
				apply_keys.append(str(check_key))
		context["batch_apply_params"] = apply_keys
	var emit_definition: ACEDefinition = _definition
	_definition = null
	_context.clear()
	# Commit-time validators (the generic per-hint seam - EventSheets.register_param_commit_
	# validator): the first field whose validator asks for confirmation defers the emit
	# into ONE shared prompt machinery. The feature-tag nudge registers through this seam.
	var prompt: Dictionary = _first_commit_validation_prompt(values)
	if not prompt.is_empty() and _dialog != null and _dialog.is_inside_tree():
		_prompt_commit_validation(prompt, emit_definition, values, context)
		return
	params_confirmed.emit(emit_definition, values, context)


var _commit_validation_prompt: ConfirmationDialog = null


## The first committed field whose hint-registered validator returns a prompt spec
## ({} when every field passes). Validators see the raw committed String value.
func _first_commit_validation_prompt(values: Dictionary) -> Dictionary:
	for key: Variant in values.keys():
		var validator: Callable = EventSheets.param_commit_validator_for(_hint_of(str(key)))
		if not validator.is_valid():
			continue
		var prompt: Variant = validator.call(str(values[key]))
		if prompt is Dictionary and not (prompt as Dictionary).is_empty():
			return prompt
	return {}


## The ONE deferred-commit prompt: whichever way it closes - confirm, cancel, Esc
## (canceled), or the titlebar X (close_requested, which does NOT emit canceled) - the
## deferred params_confirmed lands exactly once; on_confirm runs only on confirm.
## Dropping any exit path would silently lose the user's already-committed edit.
func _prompt_commit_validation(prompt: Dictionary, definition: ACEDefinition, values: Dictionary, context: Dictionary) -> void:
	if _commit_validation_prompt != null and is_instance_valid(_commit_validation_prompt):
		_commit_validation_prompt.queue_free()
	_commit_validation_prompt = ConfirmationDialog.new()
	_commit_validation_prompt.title = str(prompt.get("title", "Check this value"))
	_commit_validation_prompt.dialog_text = str(prompt.get("message", ""))
	_commit_validation_prompt.ok_button_text = str(prompt.get("confirm_text", "OK"))
	_commit_validation_prompt.cancel_button_text = str(prompt.get("cancel_text", "Keep As Is"))
	var dialog_node: ConfirmationDialog = _commit_validation_prompt
	var on_confirm: Callable = prompt.get("on_confirm", Callable())
	var finished: Dictionary = {"done": false}
	var finish_commit: Callable = func(confirmed_choice: bool) -> void:
		if finished["done"]:
			return
		finished["done"] = true
		if confirmed_choice and on_confirm.is_valid():
			on_confirm.call()
		params_confirmed.emit(definition, values, context)
		dialog_node.queue_free()
	_commit_validation_prompt.confirmed.connect(func() -> void: finish_commit.call(true))
	_commit_validation_prompt.canceled.connect(func() -> void: finish_commit.call(false))
	_commit_validation_prompt.close_requested.connect(func() -> void: finish_commit.call(false))
	_dialog.get_parent().add_child(_commit_validation_prompt)
	EventSheetL10n.apply_to(_commit_validation_prompt)
	_commit_validation_prompt.popup_centered(Vector2i(460, 200))


func _on_custom_action(action: StringName) -> void:
	if str(action) == BACK_ACTION:
		var definition: ACEDefinition = _definition
		var context: Dictionary = _context.duplicate(true)
		_close()
		back_requested.emit(definition, context)
		return
	if str(action) == ADD_ANOTHER_ACTION:
		# Same validation gate as OK; only chain when it passed (definition cleared).
		if _definition == null or _apply_blocked:
			return
		var blocker: Dictionary = _blocking_expression_field()
		if not blocker.is_empty():
			if _help_strip != null:
				_help_strip.show_note(EventSheetL10n.translate("Cannot be written"),
					str(blocker.get("message", "")), EventSheetParamFieldFactory.LEVEL_ERROR)
			(blocker.get("field") as Control).grab_focus()
			return
		_commit(true)
		_close()


func _set_back_visible(visible: bool) -> void:
	if _back_button != null:
		_back_button.visible = visible

# ── Insert Expression picker ────────────────────────────────────────────────
# The ƒx visual expression builder lives in its own file - see ACEParamsExpressionPicker
# (ace_params_expression_picker.gd). The methods/state below are thin delegates so callers, the ƒx
# button's .bind, and the by-class-name static calls (ACEParamsDialog.member_expression_fragment,
# .variable_member_fragment) keep working unchanged.


func _open_expression_picker(target_key: String) -> void:
	_expression_picker._open_expression_picker(target_key)


## Builds the Insert-Expression window lazily - delegate kept for tests that drive it headlessly.
func _ensure_expression_window() -> void:
	_expression_picker._ensure_expression_window()


## Rebuilds the expression tree - delegate kept for tests.
func _refresh_expression_tree() -> void:
	_expression_picker._refresh_expression_tree()


## Inserts a snippet at the caret of the expression field - delegate kept for tests.
func _insert_into_expression_target(snippet: String) -> void:
	_expression_picker._insert_into_expression_target(snippet)


## The code template inserted for an expression definition - delegate kept for tests.
func _expression_template(definition: ACEDefinition) -> String:
	return _expression_picker._expression_template(definition)


## The insert fragment for a reflected member (`name()` / `name`). Static + pure.
## Static delegate - reached as ACEParamsDialog.member_expression_fragment by tests.
static func member_expression_fragment(member: String, is_method: bool) -> String:
	return ACEParamsExpressionPicker.member_expression_fragment(member, is_method)


## The insert fragment for a member reached THROUGH a variable (`enemy.health`). Static + pure.
## Static delegate - reached as ACEParamsDialog.variable_member_fragment by tests.
static func variable_member_fragment(var_name: String, member: String, is_method: bool) -> String:
	return ACEParamsExpressionPicker.variable_member_fragment(var_name, member, is_method)

# ── Helpers ─────────────────────────────────────────────────────────────────


func _resolve_variable_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if not _variable_names_provider.is_valid():
		return names
	var result: Variant = _variable_names_provider.call()
	if result is PackedStringArray:
		return result
	if result is Array:
		for entry in result:
			names.append(str(entry))
	return names


func _came_from_picker() -> bool:
	# The dock sets from_picker when this dialog is opened from a picker selection.
	return bool(_context.get("from_picker", false))


## Whether Back can return to a picker: the add flow (from_picker) OR a row edit, which opens in a
## replace_* mode the picker understands - so editing an action/expression can also go back to swap
## the ACE, exactly like editing a condition already does (it routes through the replace-picker).
func _can_return_to_picker() -> bool:
	if _came_from_picker():
		return true
	return str(_context.get("mode", "")) in ["replace_condition", "replace_action", "replace_trigger"]


func _close() -> void:
	if _dialog != null:
		_dialog.hide()


func _is_reedit_flow() -> bool:
	var mode: String = str(_context.get("mode", ""))
	return mode.begins_with("replace")


# ── The row this dialog writes, and the strip that explains it ───────────────────────────────
#
# P0. The dialog used to be titled "<ACE name> Parameters" and to print each parameter's
# description under its field. It never said the one thing the author is actually deciding: what
# the ROW will read as once OK is pressed. The title band says it, filled in from the fields as
# they are typed, in the sheet's own colours - and the strip at the foot says what the FOCUSED
# parameter takes, what is wrong with it, and the line of code the row becomes.


## The sentence the row will read as: the object it belongs to, then the ACE's own display
## template with the values filled in. Static and pure, so a test pins it without a window.
static func title_sentence(definition: ACEDefinition, values: Dictionary, owner: String = "") -> String:
	if definition == null:
		return ""
	var text: String = definition.format_display(values).strip_edges()
	if text.is_empty():
		text = definition.display_name
	var named: String = owner.strip_edges()
	return text if named.is_empty() else "%s   %s" % [named, text]


## The same sentence in the sheet's colours: the owner in the object blue, every filled value in
## the value green, the template's own words plain. Square brackets in a value are escaped, because
## a value like `[1, 2]` is a list and not markup.
static func title_bbcode(definition: ACEDefinition, values: Dictionary, owner: String = "") -> String:
	if definition == null:
		return ""
	var template: String = str(definition.metadata.get("display_template", definition.display_name))
	if template.strip_edges().is_empty():
		template = definition.display_name
	var text: String = _bbcode_escaped(template)
	for index: int in range(definition.parameters.size()):
		var parameter: Variant = definition.parameters[index]
		if not (parameter is Dictionary):
			continue
		var parameter_dict: Dictionary = parameter
		var key: String = str(parameter_dict.get("id", ""))
		if key.is_empty():
			continue
		var fallback: Variant = parameter_dict.get("default_value", parameter_dict.get("default", ""))
		var shown: String = ACEDefinition.display_value_for(parameter_dict, values.get(key, fallback))
		var tinted: String = "[color=#%s]%s[/color]" % [
			EventSheetPalette.COLOR_VALUE.to_html(false), _bbcode_escaped(shown)]
		text = text.replace("{%d}" % index, tinted)
		text = text.replace("{%s}" % key, tinted)
	var named: String = owner.strip_edges()
	if named.is_empty():
		return text
	return "[color=#%s]%s[/color]  %s" % [EventSheetPalette.COLOR_OBJECT.to_html(false),
		_bbcode_escaped(named), text]


## The line the compiler will write for this row, with the values as typed - produced BY the
## emitter, from a throwaway row, so the dialog cannot promise a spelling the compiler would not
## use. "" for a definition whose kind has no line of its own.
static func row_code_line(definition: ACEDefinition, values: Dictionary) -> String:
	if definition == null:
		return ""
	match definition.ace_type:
		ACEDefinition.ACEType.CONDITION:
			var condition: ACECondition = ACECondition.new()
			condition.provider_id = definition.provider_id
			condition.ace_id = definition.id
			condition.params = values.duplicate()
			var expression: String = ConditionCodegen.generate_condition(condition)
			return "" if expression.strip_edges().is_empty() else "if %s:" % expression
		ACEDefinition.ACEType.ACTION:
			var action: ACEAction = ACEAction.new()
			action.provider_id = definition.provider_id
			action.ace_id = definition.id
			action.params = values.duplicate()
			return ActionCodegen.generate_action(action).strip_edges()
	# An expression (and a trigger's parameters) has no statement of its own - the template with
	# the values in it IS what the row contributes to whatever line encloses it.
	var template: String = str(definition.metadata.get("codegen_template", ""))
	if template.strip_edges().is_empty():
		return ""
	for key: Variant in values.keys():
		template = template.replace("{%s}" % str(key), str(values[key]))
	return template


## Square brackets in a value are a list, a node path or an array index - never markup. Escaped
## before anything is tinted, so the tint's own tags are the only markup in the string.
static func _bbcode_escaped(text: String) -> String:
	return text.replace("[", "[lb]")


## Every field's value as the row would carry it - the same read the commit path does, so what the
## title shows and what OK writes are one answer.
func _current_values() -> Dictionary:
	var values: Dictionary = {}
	for key: Variant in _fields.keys():
		if is_instance_valid(_fields[key]):
			values[str(key)] = str(_extract_value(_fields[key]))
	return values


## The catalog of variables this row can see, read once per open. own_entries is the cheap half of
## EventSheetVariableOwners on purpose: the whole catalog walks every row and reads every autoload's
## script, which is not something to do while somebody is typing.
func _read_variable_context() -> void:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	_variable_entries = EventSheetVariableOwners.own_entries(sheet) if sheet != null else ([] as Array[Dictionary])
	_row_owner = EventSheetVariableOwners.owner_of_sheet(sheet) if sheet != null else ""


## Re-reads the catalog and re-checks every field. Runs when focus returns to this dialog, because
## the variable a fix went off to add exists by then.
func _refresh_variable_context() -> void:
	if _definition == null:
		return
	_read_variable_context()
	_refresh_live_reading()


## The title band, the window title, the IN CODE line and the reason beside OK - everything that
## reads the values rather than describing a field. Called on every change of every field.
func _refresh_live_reading() -> void:
	if _definition == null or _dialog == null:
		return
	var values: Dictionary = _current_values()
	var sentence: String = title_sentence(_definition, values, _row_owner)
	_dialog.title = sentence if not sentence.is_empty() else _definition.display_name
	if _title_label != null:
		_title_label.text = title_bbcode(_definition, values, _row_owner)
	if _title_ace_label != null:
		_title_ace_label.text = "%s (%s)" % [_definition.display_name,
			EventSheetL10n.translate("editing")] if _is_reedit_flow() else _definition.display_name
	if _help_strip != null:
		_help_strip.set_reading("", row_code_line(_definition, values))
	for caption: Callable in _choice_captions:
		caption.call()
	_refresh_notes()


## The strip for whichever parameter is focused, and the reason beside OK: the strongest problem any
## field has, so a red field is never hidden behind an amber one.
func _refresh_notes() -> void:
	if _help_strip != null and not _focused_key.is_empty():
		_describe_field(_focused_key)
	if _ok_reason == null:
		return
	var strongest: Dictionary = {}
	for key: Variant in _fields.keys():
		var note: Dictionary = _note_for(str(key))
		_tint_field(_fields[key] as Control, str(note.get("level", "")))
		if note.is_empty():
			continue
		if strongest.is_empty() or str(note.get("level", "")) == EventSheetParamFieldFactory.LEVEL_ERROR:
			strongest = note
	_ok_reason.text = str(strongest.get("reason", ""))
	_ok_reason.add_theme_color_override("font_color",
		EventSheetPalette.COLOR_ERROR_TEXT if str(strongest.get("level", "")) == EventSheetParamFieldFactory.LEVEL_ERROR
		else EventSheetPalette.COLOR_HEALTH_WARN)


## The field itself wears its note's colour, so the trouble is visible from the field the eye is
## already on rather than only at the foot. A field with nothing wrong keeps the theme's own ink -
## removed rather than set back to a guess at what the theme uses.
func _tint_field(field: Control, level: String) -> void:
	if field == null or not is_instance_valid(field):
		return
	match level:
		EventSheetParamFieldFactory.LEVEL_ERROR:
			field.add_theme_color_override("font_color", EventSheetPalette.COLOR_ERROR_TEXT)
		EventSheetParamFieldFactory.LEVEL_WARNING:
			field.add_theme_color_override("font_color", EventSheetPalette.COLOR_HEALTH_WARN)
		_:
			field.remove_theme_color_override("font_color")


## What is wrong with one parameter's value, or {}. An expression field's own lint answer comes
## first (it was computed as the field was typed and knows things a table cannot), then the shared
## per-parameter checks.
func _note_for(key: String) -> Dictionary:
	var lint_note: Dictionary = _field_notes.get(key, {})
	if not lint_note.is_empty():
		return lint_note
	var param: Dictionary = _param_dicts.get(key, {})
	if param.is_empty() or not is_instance_valid(_fields.get(key, null)):
		return {}
	var takes: String = str(EventSheetVariableOwners.VARIABLE_VERB_TAKES.get(_definition.id, "")) if _definition != null else ""
	return EventSheetParamFieldFactory.validate(param, str(_extract_value(_fields[key])),
		_variable_entries, _row_owner, takes)


## Points the strip at one parameter: its description and what its kind of field takes, or - when
## something is wrong with the value - the complaint, in the tone it deserves, with the fixes.
func _describe_field(key: String) -> void:
	if _help_strip == null:
		return
	_focused_key = key
	var param: Dictionary = _param_dicts.get(key, {})
	var note: Dictionary = _note_for(key)
	if note.is_empty():
		# V6 - nothing is wrong, but there may still be a plainer way to read what was typed.
		_help_strip.show_note(EventSheetParamFieldFactory.strip_heading(param),
			EventSheetParamFieldFactory.strip_body(param, _row_owner),
			EventSheetPopupUI.HelpStrip.TONE_NORMAL, reading_offers())
		return
	_help_strip.show_note(str(note.get("heading", "")), str(note.get("body", "")),
		str(note.get("level", "")), _fix_offers(key, note))


## The strip's own description before any field is focused: what the ACE is, and what this opening
## of the dialog is doing (adding a condition, editing a cell, batch-editing a selection).
func _describe_dialog_itself() -> void:
	if _help_strip == null or _definition == null:
		return
	var about: String = _definition.description.strip_edges()
	var doing: String = _build_hint_text().strip_edges()
	_help_strip.show_note(_definition.display_name,
		doing if about.is_empty() else "%s  %s" % [about, doing])


## V6. The plainer reading of what is already typed, as a button on the strip: a Set value whose
## expression only adds to (or subtracts from) the variable it sets IS an Add to / Subtract from, and
## the row says so in fewer words for the same emitted line. [] whenever the expression is anything
## else, and [] when this editor's registry cannot name the verb it would write.
##
## Public so the reading can be pinned without a display server - the button is one press of it.
func reading_offers() -> Array:
	if _definition == null or _registry == null:
		return []
	var reading: Dictionary = EventSheetVariableOwners.compound_reading(str(_definition.id), _current_values())
	if reading.is_empty():
		return []
	var target: ACEDefinition = _registry.find_definition(_definition.provider_id, str(reading["ace_id"]))
	if target == null:
		return []
	var values: Dictionary = reading["params"]
	return [{
		"text": EventSheetL10n.translate("read as %s") % EventSheetL10n.translate(target.display_name),
		"pressed": func() -> void: _confirm_as(target, values)
	}]


## Applies `definition` with `values` as if OK had been pressed on it, and closes. The row is
## replaced through the very path this dialog's own OK takes (the context still names the slot being
## edited), so re-reading a row is one undo step and one writer.
func _confirm_as(definition: ACEDefinition, values: Dictionary) -> void:
	var context: Dictionary = _context.duplicate(true)
	_definition = null
	_context.clear()
	_close()
	params_confirmed.emit(definition, values, context)


## The one-click answers a note offers, wired to this dialog's own fields.
func _fix_offers(key: String, note: Dictionary) -> Array:
	var offers: Array = []
	for fix: Variant in note.get("fixes", []):
		if not (fix is Dictionary):
			continue
		var entry: Dictionary = fix
		var name_text: String = str(entry.get("name", ""))
		if name_text.is_empty():
			continue
		match str(entry.get("kind", "")):
			"use":
				offers.append({
					"text": EventSheetL10n.translate("Use %s") % name_text,
					"pressed": func() -> void: _write_field(key, name_text),
				})
			"add":
				offers.append({
					"text": EventSheetL10n.translate("Add %s…") % name_text,
					"pressed": func() -> void: _add_variable_named(key, name_text),
				})
	return offers


## Writes a value into a built field the way the user would have typed it, then re-reads the row.
## Every widget kind the fixes can land on is named here; anything else is left alone rather than
## being written to through a guess.
func _write_field(key: String, value: String) -> void:
	var field: Variant = _fields.get(key, null)
	if not is_instance_valid(field):
		return
	if field is OptionButton:
		var dropdown: OptionButton = field
		for index: int in range(dropdown.item_count):
			if str(dropdown.get_item_metadata(index)) == value:
				dropdown.select(index)
				break
	elif field is LineEdit:
		(field as LineEdit).text = value
		(field as LineEdit).caret_column = value.length()
	elif field is TextEdit:
		(field as TextEdit).text = value
		_validate_expression_field(field as Control)
	_refresh_live_reading()
	(field as Control).grab_focus()


## The "Add hpp…" fix: the dock opens the Add variable dialog with the name already in it when it
## has offered one, and declares it outright when it has not. Either way the catalog is re-read and
## the field re-checked, so the red note answers itself.
func _add_variable_named(key: String, variable_name: String) -> void:
	if _variable_adder.is_valid():
		_variable_adder.call(variable_name)
		return
	if _variable_creator.is_valid() and bool(_variable_creator.call(variable_name)):
		_variable_names = _resolve_variable_names()
		_read_variable_context()
		_rebuild_variable_options(key, variable_name)
		_refresh_live_reading()


## Puts a newly declared variable into the dropdown that asked for it and selects it, so the fix
## finishes the job instead of leaving the reader to reopen the list. A typed field is left exactly
## as it is - the name the fix declared is the one already in the box.
func _rebuild_variable_options(key: String, variable_name: String) -> void:
	var dropdown: OptionButton = _fields.get(key) as OptionButton
	if dropdown == null:
		return
	var found: int = -1
	for index: int in range(dropdown.item_count):
		if str(dropdown.get_item_metadata(index)) == variable_name:
			found = index
	if found < 0:
		dropdown.add_item(variable_name)
		found = dropdown.item_count - 1
		dropdown.set_item_metadata(found, variable_name)
	dropdown.select(found)


## Wires one built field to the strip and the title: focusing or hovering it describes it, and every
## change re-reads the row. The change SIGNAL is per widget kind on purpose - the factory's
## `change_signal_of` names the signal that means "committed", and this wants "being typed".
func _watch_field(key: String, label: Control) -> void:
	var field: Control = _fields.get(key) as Control
	if field == null:
		return
	var describe: Callable = func() -> void: _describe_field(key)
	field.focus_entered.connect(describe)
	field.mouse_entered.connect(describe)
	if label != null:
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.mouse_entered.connect(describe)
	var changed: Callable = func(_ignored: Variant = null) -> void: _refresh_live_reading()
	# An expression field re-lints on its own text_changed and finishes by re-reading the row, so it
	# is deliberately absent here - a second connection would run the whole pass twice per keystroke.
	if field is LineEdit:
		(field as LineEdit).text_changed.connect(changed)
	elif field is OptionButton:
		(field as OptionButton).item_selected.connect(changed)
	elif field is CheckBox:
		(field as CheckBox).toggled.connect(changed)
	elif field is SpinBox:
		(field as SpinBox).value_changed.connect(changed)
	elif field is ColorPickerButton:
		(field as ColorPickerButton).color_changed.connect(changed)


## P1 - the line under each choice of a dropdown, from wherever the choices came from. The muted
## caption beside the list shows the chosen one's line; arrowing the open list describes each choice
## in the strip BEFORE it is picked. A list with no lines is left exactly as it was.
func _attach_option_notes(key: String, param_dict: Dictionary, row: HBoxContainer, notes: Dictionary) -> void:
	var dropdown: OptionButton = _fields.get(key) as OptionButton
	if dropdown == null or notes.is_empty():
		return
	var caption: Label = _muted_label()
	row.add_child(caption)
	var refresh: Callable = func(_index: int = -1) -> void:
		caption.text = str(notes.get(str(_extract_value(dropdown)), ""))
	dropdown.item_selected.connect(refresh)
	_choice_captions.append(refresh)
	refresh.call(dropdown.selected)
	if _help_strip == null:
		return
	_help_strip.follow_option(dropdown, func(index: int) -> Dictionary:
		if index < 0 or index >= dropdown.item_count:
			return {}
		var note: String = str(notes.get(str(dropdown.get_item_metadata(index)), ""))
		if note.is_empty():
			return {}
		return {
			"heading": EventSheetParamFieldFactory.strip_heading(param_dict),
			"body": "%s - %s" % [dropdown.get_item_text(index), note],
		})


## P1 - the line beside a field whose choices are typed rather than picked: an Input Map action's
## keys, how many nodes of the open scene are in a node group. Live, because both answers change
## with what is in the box.
func _attach_typed_choice_note(key: String, row: HBoxContainer, hint: String) -> void:
	var field: LineEdit = _fields.get(key) as LineEdit
	if field == null:
		return
	var caption: Label = _muted_label()
	row.add_child(caption)
	var scene_root: Node = _validation_scene_root()
	var refresh: Callable = func(_text: String = "") -> void:
		caption.text = EventSheetParamFieldFactory.input_action_note(field.text) if hint == "input_action" \
			else EventSheetParamFieldFactory.node_group_note(field.text, scene_root)
	field.text_changed.connect(refresh)
	_choice_captions.append(refresh)
	refresh.call()


## The second lines a parameter's choices carry, from whichever source the hint names. A
## variable_reference reads them off the catalog (each variable's type and value); every other
## options list reads them off the descriptor.
func _option_notes_for(param_dict: Dictionary) -> Dictionary:
	if str(param_dict.get("hint", "")).begins_with(VARIABLE_REFERENCE_HINT):
		var notes: Dictionary = {}
		for entry: Dictionary in _variable_entries:
			var line: String = EventSheetParamFieldFactory.variable_option_note(entry)
			if not line.is_empty():
				notes[str(entry.get("name", ""))] = line
		return notes
	return EventSheetParamFieldFactory.option_notes(param_dict)


func _build_hint_text() -> String:
	if _apply_blocked:
		return "This needs a sheet variable, but none exist yet. Add a variable to the sheet first (Add > Global Variable), then come back."
	var mode: String = str(_context.get("mode", ""))
	var base: String = "Fill in parameters, then press OK to apply."
	match mode:
		"append_condition":
			base = "Adding a condition to the selected event."
		"append_action":
			base = "Adding an action to the selected event."
		"new_sub_condition_event":
			base = "Creating a nested sub-condition event."
		"replace_condition", "replace_trigger", "replace_action":
			base = "Editing this existing cell."
		"batch_edit_params":
			# The whole point of the batch flow, stated up front: one OK, many cells.
			base = "Batch edit: OK applies these values to all %d matching %s across the selection." % [
				int(_context.get("batch_count", 0)),
				"conditions" if str(_context.get("batch_kind", "")) == "condition" else "actions"
			]
		"new_event", "new_condition_event":
			base = "Creating a new event from this pick."
	return "%s %s" % [
		base,
		"Existing values were loaded for quick re-editing." if _is_reedit_flow() else ""
	]


func _focus_first_field() -> void:
	for key in _fields.keys():
		# Skip entries whose widget was already freed (the dialog can close before this
		# deferred focus runs) - casting a freed object would error instead of returning null.
		if not is_instance_valid(_fields[key]):
			continue
		var field: Control = _fields[key] as Control
		if field != null and field.visible and not (field is LineEdit and not (field as LineEdit).editable):
			field.grab_focus()
			return


static func _parse_bool(value: Variant) -> bool:
	return str(value).to_lower() in ["true", "1", "yes"]
