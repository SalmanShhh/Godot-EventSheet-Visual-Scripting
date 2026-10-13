# EventForge - the focused "Edit Parameter" window.
#
# Clicking a parameter cell on a published verb used to open the WHOLE verb dialog with the cursor
# parked in one field. That is the right window for "redesign this verb" and the wrong one for "this
# input should be called speed, not s".
#
# So this window holds exactly what a parameter IS: its name, its type, an optional default, and the
# line describing it - the four fields the verb dialog's parameter row carries, written through the
# same undo funnel. On the window kit: a band showing the function's row with this input in it, the
# Parameter card, a state note that refuses a bad name or a misplaced default while Apply waits, the
# help strip with the `func` line it writes, and Delete as its own red button on the left. "Edit the
# whole function…" is one button away for anyone who wanted the big one.
@tool
class_name EventSheetParamDialog
extends RefCounted

## Emitted on Apply (or Delete) with {function: String, index: int, id, type_name, default,
## description, removed: bool}. index < 0 means "append a new parameter".
signal param_confirmed(data: Dictionary)
## Emitted when the user asks for the full verb dialog instead, carrying the verb's name.
signal full_editor_requested(function_name: String)

## The custom action the Delete button sends.
const DELETE_ACTION: StringName = &"param_delete"

var _dialog: ConfirmationDialog = null
var _band: EventSheetPopupUI.RowBand = null
var _name_edit: LineEdit = null
var _type_option: OptionButton = null
var _default_edit: LineEdit = null
var _description_edit: LineEdit = null
var _delete_button: Button = null
## Says why Apply waits, inside the window, so the typed fields survive the refusal.
var _problem_label: EventSheetPopupUI.StateNote = null
var _strip: EventSheetPopupUI.HelpStrip = null
## The names the verb's OTHER parameters already use - a second input of the same name would not parse.
var _taken_param_names: PackedStringArray = PackedStringArray()
## The verb's parameters as they stand, [{id, type_name, default}], for the band and the `func` line.
var _params: Array[Dictionary] = []
## The verb being edited and which of its parameters (-1 while adding a fresh one).
var _function_name: String = ""
var _param_index: int = -1


func init_dialog(parent_node: Node) -> void:
	_dialog = ConfirmationDialog.new()
	_dialog.title = EventSheetL10n.translate("Edit Parameter")
	_dialog.ok_button_text = EventSheetL10n.translate("Apply")
	# Apply closes the window itself, and only once the parameter is accepted.
	_dialog.dialog_hide_on_ok = false
	_dialog.confirmed.connect(_on_confirmed)
	parent_node.add_child(_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(420.0), 0.0)
	_dialog.add_child(EventSheetPopupUI.margined(form))
	_band = EventSheetPopupUI.RowBand.new()
	form.add_child(_band)
	var card: VBoxContainer = EventSheetPopupUI.form_box()
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "amount"
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_dialog.register_text_enter(_name_edit)
	card.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _name_edit))
	_type_option = EventSheetPopupUI.described_option()
	for type_name: String in EventSheetFunctionDialog.PARAM_TYPES:
		_type_option.add_item(type_name)
	_type_option.item_selected.connect(func(_index: int) -> void: _refresh())
	card.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Type"), _type_option))
	_default_edit = LineEdit.new()
	_default_edit.placeholder_text = EventSheetL10n.translate("leave empty to make it required")
	_default_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	card.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Default"), _default_edit))
	_description_edit = LineEdit.new()
	_description_edit.placeholder_text = EventSheetL10n.translate("what this input is for")
	card.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Description"), _description_edit))
	# The way back to the full verb dialog, for the person who clicked a parameter but meant to change
	# the verb itself.
	var full_editor_button: Button = Button.new()
	full_editor_button.text = EventSheetL10n.translate("Edit the whole function…")
	full_editor_button.flat = true
	full_editor_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	full_editor_button.pressed.connect(func() -> void:
		_dialog.hide()
		full_editor_requested.emit(_function_name))
	card.add_child(full_editor_button)
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Parameter"), card))
	_problem_label = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(400.0))
	form.add_child(_problem_label)
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(400.0))
	form.add_child(_strip)
	_strip.follow(_name_edit, EventSheetL10n.translate("Name"),
		EventSheetL10n.translate("The parameter's name in the GDScript, and the label on the function's row."))
	_strip.follow_option(_type_option, func(_index: int) -> Dictionary:
		return {"heading": EventSheetL10n.translate("Type"),
			"body": EventSheetL10n.translate("What kind of value this input accepts - a number (int / float), text (String), a true/false (bool), a position (Vector2 / Vector3), or Variant for anything at all.")})
	_strip.follow(_default_edit, EventSheetL10n.translate("Default"),
		EventSheetL10n.translate("An optional starting value, so whoever uses the function can skip this input. Written as GDScript (10, 1.5, \"idle\", true). Inputs with a default have to come after those without."))
	_strip.follow(_description_edit, EventSheetL10n.translate("Description"),
		EventSheetL10n.translate("One line explaining this input. It shows in the picker beside the field, which is where somebody decides what to type into it."))
	_strip.follow(full_editor_button, EventSheetL10n.translate("Edit the whole function…"),
		EventSheetL10n.translate("Opens the function's own window: its name, its doc comment, what kind it is and who can use it."))
	# Delete is its own red-outlined button on the left - never OK, never Cancel, so neither Enter
	# nor Esc can take it.
	_delete_button = _dialog.add_button(EventSheetL10n.translate("Delete"), false, DELETE_ACTION)
	_delete_button.add_theme_color_override("font_color", EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_ERROR))
	_delete_button.tooltip_text = EventSheetL10n.translate("Removes the input from the function entirely. Anything already calling the function loses the value it was passing here.")
	var buttons: Node = _delete_button.get_parent()
	buttons.move_child(_delete_button, 0)
	_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == DELETE_ACTION:
			delete_param())


## Opens on one existing parameter of `event_function` (index into its params).
func open_for_param(event_function: EventFunction, param_index: int) -> void:
	if event_function == null or param_index < 0 or param_index >= event_function.params.size():
		return
	var param: ACEParam = event_function.params[param_index]
	_read_function(event_function, param_index)
	_dialog.title = EventSheetL10n.translate("Edit parameter {name}").replace("{name}", param.id)
	_name_edit.text = param.id
	EventSheetPopupUI.select_option(_type_option, param.type_name)
	_default_edit.text = param.gdscript_default
	_description_edit.text = param.description
	_delete_button.visible = true
	_popup()


## Opens blank, to append a fresh parameter to `event_function`.
func open_for_new_param(event_function: EventFunction) -> void:
	if event_function == null:
		return
	_read_function(event_function, -1)
	_dialog.title = EventSheetL10n.translate("Add Parameter")
	_name_edit.text = ""
	# Variant is the honest default for a parameter nobody has typed yet - it accepts anything, so the
	# verb compiles and runs while the author is still deciding.
	EventSheetPopupUI.select_option(_type_option, "Variant")
	_default_edit.text = ""
	_description_edit.text = ""
	# Nothing to delete yet.
	_delete_button.visible = false
	_popup()


func _read_function(event_function: EventFunction, param_index: int) -> void:
	_function_name = event_function.function_name
	_param_index = param_index
	_taken_param_names = other_param_names(event_function, param_index)
	_params.clear()
	for param: ACEParam in event_function.params:
		_params.append({"id": param.id, "type_name": param.type_name, "default": param.gdscript_default})


func _popup() -> void:
	_strip.describe(EventSheetL10n.translate("Name"),
		EventSheetL10n.translate("The parameter's name in the GDScript, and the label on the function's row."))
	_refresh()
	if _dialog.is_inside_tree():
		_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(460.0)), 0))
		_name_edit.call_deferred("grab_focus")
		_name_edit.call_deferred("select_all")


## The verb's parameters with THIS one as the fields describe it - appended when it is new.
func _params_now() -> Array[Dictionary]:
	var now: Array[Dictionary] = []
	for param: Dictionary in _params:
		now.append(param.duplicate())
	var edited: Dictionary = {"id": _name_edit.text.strip_edges(), "type_name": _type_text(),
		"default": _default_edit.text.strip_edges()}
	if _param_index >= 0 and _param_index < now.size():
		now[_param_index] = edited
	else:
		now.append(edited)
	return now


func _type_text() -> String:
	return EventSheetFunctionDialog.PARAM_TYPES[maxi(_type_option.selected, 0)]


## The `func` line the verb compiles to with these parameters.
static func func_line(function_name: String, params: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for param: Dictionary in params:
		var part: String = "%s: %s" % [str(param.get("id", "")), str(param.get("type_name", "Variant"))]
		if not str(param.get("default", "")).is_empty():
			part += " = " + str(param.get("default", ""))
		parts.append(part)
	return "func %s(%s)" % [function_name, ", ".join(parts)]


## Why Apply waits, or "": the name (as written - it becomes the parameter in the generated `func`
## line) and the rule that inputs with a default come after those without.
func problem() -> String:
	var name_problem: String = param_name_problem(_name_edit.text.strip_edges(), _taken_param_names)
	if not name_problem.is_empty():
		return name_problem
	var seen_default: bool = false
	for param: Dictionary in _params_now():
		if not str(param.get("default", "")).is_empty():
			seen_default = true
		elif seen_default:
			return EventSheetL10n.translate("Parameters with a default value must come after those without - move this one down, or give the ones after it defaults too.")
	return ""


func _refresh() -> void:
	var params: Array[Dictionary] = _params_now()
	var names: PackedStringArray = PackedStringArray()
	for index: int in range(params.size()):
		var shown: String = str(params[index].get("id", ""))
		var edited: bool = index == _param_index or (_param_index < 0 and index == params.size() - 1)
		names.append("[%s]" % shown if edited else shown)
	_band.show_row("ƒ " + _function_name, "  ".join(names))
	_strip.set_reading("", func_line(_function_name, params))
	var said: String = problem()
	_problem_label.say(said)
	EventSheetPopupUI.mark_field(_name_edit, not said.is_empty() and not param_name_problem(_name_edit.text.strip_edges(), _taken_param_names).is_empty())
	EventSheetPopupUI.mark_field(_default_edit, not said.is_empty() and param_name_problem(_name_edit.text.strip_edges(), _taken_param_names).is_empty())
	_dialog.get_ok_button().disabled = not said.is_empty()


## Every parameter name of `event_function` except the one at `skip_index` (-1 skips none).
static func other_param_names(event_function: EventFunction, skip_index: int) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for position: int in range(event_function.params.size()):
		if position != skip_index:
			names.append((event_function.params[position] as ACEParam).id)
	return names


## Why `param_name` cannot name a parameter beside `taken`, or "" when it can. The name is taken as
## written - it becomes the parameter in the generated `func` line - so a space or a keyword is
## refused rather than silently rewritten into something the reader did not type.
static func param_name_problem(param_name: String, taken: PackedStringArray) -> String:
	if param_name.is_empty():
		return EventSheetL10n.translate("A parameter needs a name.")
	if not EventSheetIdentifierRules.is_valid(param_name):
		return EventSheetL10n.translate("\"{name}\" can't be a parameter name - use letters, digits and underscores (move_speed, not move speed), and not a GDScript keyword.").replace("{name}", param_name)
	if taken.has(param_name):
		return EventSheetL10n.translate("This function already has a parameter called \"{name}\".").replace("{name}", param_name)
	return ""


## The Delete button: removes this input from the function, one undo step.
func delete_param() -> void:
	if _param_index < 0:
		return
	_dialog.hide()
	param_confirmed.emit({"function": _function_name, "index": _param_index, "id": "", "type_name": "",
		"default": "", "description": "", "removed": true})


func _on_confirmed() -> void:
	if not problem().is_empty():
		_refresh()
		return
	_dialog.hide()
	param_confirmed.emit({
		"function": _function_name,
		"index": _param_index,
		"id": _name_edit.text.strip_edges(),
		"type_name": _type_text(),
		"default": _default_edit.text.strip_edges(),
		"description": _description_edit.text.strip_edges(),
		"removed": false,
	})
