@tool
extends RefCounted
# The selected function, edited in the Properties bar beside the canvas.
#
#   Name           take_damage
#   Description    Removes health, flashes the sprite, and dies at zero.
#   Returns        Nothing ▾
#   In Add Action  Listed ▾
#   Category       Player ▾
#   Waits          Finishes at once ▾
#   Shared         One per object ▾
#   Parameters                       + Add
#   ⋮⋮ amount      int ▾      1
#
# Every dropdown carries the sentence that says what each choice means (the window kit's described
# dropdown), which is why this is built from the kit rather than handed to Godot's EditorInspector:
# the stock Inspector has no way to describe a single choice, cannot reorder a list a script declares,
# and does not exist in a headless run, so none of this could be pinned by the suite.
#
# Every change is ONE undo step through the dock's edit funnel, applied by the function's NAME and
# re-fetched each time (the funnel replaces resources on commit). A field that ends up holding what it
# held writes nothing, so an opened .gd stays byte-exact until something really changes.
#
# Loaded BY PATH from the Properties bar on the first function selection, never on the boot path.

## The return and parameter types the dropdowns offer, as the code writes them. "Nothing" is the
## function that hands nothing back (`-> void`); a type outside the list is kept and offered as itself.
const TYPE_WORDS: PackedStringArray = ["Nothing", "bool", "int", "float", "String", "Vector2", "Vector3",
	"Color", "Array", "Dictionary", "Node", "Variant"]

var _dock: Control = null
var _function_name: String = ""


func _init(dock: Control, event_function: EventFunction) -> void:
	_dock = dock
	_function_name = event_function.function_name


## The sentence a type choice shows as the pointer rests on it. Each is spelled out inside its own
## translate() call so the translation harvest finds it.
static func type_description(type_word: String) -> String:
	match type_word:
		"Nothing":
			return EventSheetL10n.translate("Hands nothing back. Use it as an action.")
		"bool":
			return EventSheetL10n.translate("True or false: answers a yes/no question.")
		"int":
			return EventSheetL10n.translate("A whole number: counts, health, coins.")
		"float":
			return EventSheetL10n.translate("A number with a fraction: speeds, distances, seconds.")
		"String":
			return EventSheetL10n.translate("Text, like a name or a line of dialogue.")
		"Vector2":
			return EventSheetL10n.translate("A 2D point or direction (x, y).")
		"Vector3":
			return EventSheetL10n.translate("A 3D point or direction (x, y, z).")
		"Color":
			return EventSheetL10n.translate("A color, with transparency.")
		"Array":
			return EventSheetL10n.translate("A list of values, in order.")
		"Dictionary":
			return EventSheetL10n.translate("Values stored under names, looked up by name.")
		"Node":
			return EventSheetL10n.translate("Any node in the scene, like the nearest enemy.")
		"Variant":
			return EventSheetL10n.translate("Any type at all. The editor cannot check it for you.")
	return EventSheetL10n.translate("A type of your own project, kept as it is written.")


## The return word a function shows in the Returns dropdown: "Nothing" for `-> void`, otherwise the
## type exactly as the file writes it.
static func return_word(event_function: EventFunction) -> String:
	var spelled: String = SheetCompiler._function_return_type_name(event_function)
	return "Nothing" if spelled == "void" else spelled


## The (return_type, return_type_name) pair a Returns word stores. A builtin type is stored as its
## Variant.Type; any other word (Node, a class of the project) rides in return_type_name, which the
## compiler writes verbatim - the same split the importer makes when it lifts `-> Node`.
static func return_fields(type_word: String) -> Array:
	match type_word:
		"Nothing":
			return [TYPE_NIL, ""]
		"Variant":
			return [TYPE_MAX, ""]
	for type_id: int in range(TYPE_MAX):
		if type_id != TYPE_NIL and type_id != TYPE_OBJECT and type_string(type_id) == type_word:
			return [type_id, ""]
	return [TYPE_MAX, type_word]


## The described choices of the three yes/no settings, as [word, sentence] pairs: the first is
## "off", the second "on". Kept as data so a test can read what each one says.
static func flag_choices(flag: String) -> Array:
	match flag:
		"in_add_action":
			return [
				[EventSheetL10n.translate("Not listed"), EventSheetL10n.translate("Only callable by name from this sheet, or from code.")],
				[EventSheetL10n.translate("Listed"), EventSheetL10n.translate("Shown in Add Action under its Category, with its description as help.")],
			]
		"waits":
			return [
				[EventSheetL10n.translate("Finishes at once"), EventSheetL10n.translate("Runs start to end in one frame. Callers carry on straight after.")],
				[EventSheetL10n.translate("Can wait"), EventSheetL10n.translate("May pause on a Wait (timer, signal, tween). Callers can wait for it to finish before carrying on.")],
			]
		"shared":
			return [
				[EventSheetL10n.translate("One per object"), EventSheetL10n.translate("Each object runs its own copy and can use its own variables, like health.")],
				[EventSheetL10n.translate("One for the script"), EventSheetL10n.translate("Called without picking an object. It cannot read one object's variables, so it suits helpers like maths.")],
			]
	return []


## The categories the Category dropdown offers: the ones this sheet's functions already file under,
## then "Functions" (the heading a function with none is listed under), then the function's own.
static func category_choices(sheet: EventSheetResource, current: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if sheet != null:
		for entry: Variant in sheet.functions:
			var category: String = (entry as EventFunction).ace_category.strip_edges() if entry is EventFunction else ""
			if not category.is_empty() and not found.has(category):
				found.append(category)
	found.sort()
	if not found.has("Functions"):
		found.append("Functions")
	if not current.strip_edges().is_empty() and not found.has(current.strip_edges()):
		found.append(current.strip_edges())
	return found


## The function this panel edits, re-fetched from the live sheet (never held across an edit).
func live_function() -> EventFunction:
	if _dock == null or _dock._current_sheet == null:
		return null
	for entry: Variant in _dock._current_sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == _function_name:
			return entry as EventFunction
	return null


## Builds the fields into the bar's two-column grid. A read-only sheet shows them disabled.
func build_into(form: GridContainer) -> void:
	var event_function: EventFunction = live_function()
	if event_function == null:
		return
	var editable: bool = not _dock._current_sheet.read_only
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = event_function.function_name
	_commit_on_submit(name_edit, func(text: String) -> void: apply_name(text))
	_row(form, EventSheetL10n.translate("Name"), name_edit,
		EventSheetL10n.translate("Exactly as written in code. Renaming it renames every call."), editable)
	var description_edit: LineEdit = LineEdit.new()
	description_edit.text = event_function.description
	_commit_on_submit(description_edit, func(text: String) -> void: apply_field("description", text.strip_edges()))
	_row(form, EventSheetL10n.translate("Description"), description_edit,
		EventSheetL10n.translate("Shown in italics under the name, and as the help text in Add Action."), editable)
	var returns: OptionButton = type_dropdown(return_word(event_function), true)
	returns.item_selected.connect(func(index: int) -> void: apply_returns(returns.get_item_text(index)))
	_row(form, EventSheetL10n.translate("Returns"), returns,
		EventSheetL10n.translate("What the function hands back. Nothing makes it an action; any type makes it usable inside expressions, and its last action is Return."), editable)
	_flag_row(form, "in_add_action", EventSheetL10n.translate("In Add Action"), event_function.expose_as_ace,
		EventSheetL10n.translate("Whether other events can pick it from Add Action like a built-in."), editable)
	var category: OptionButton = EventSheetPopupUI.described_option()
	for word: String in category_choices(_dock._current_sheet, event_function.ace_category):
		EventSheetPopupUI.add_described_item(category, word,
			EventSheetL10n.translate("The default heading for your own functions.") if word == "Functions"
				else EventSheetL10n.translate("Listed under %s in Add Action.") % word)
	EventSheetPopupUI.select_option(category, event_function.ace_category.strip_edges() if not event_function.ace_category.strip_edges().is_empty() else "Functions")
	EventSheetPopupUI.follow_description(category)
	category.item_selected.connect(func(index: int) -> void:
		var word: String = category.get_item_text(index)
		var current: String = live_function().ace_category.strip_edges() if live_function() != null else ""
		# "Functions" is the heading an uncategorised function is already listed under, so picking it
		# for one with none is no change at all.
		if not (word == "Functions" and current.is_empty()):
			apply_field("ace_category", word))
	_row(form, EventSheetL10n.translate("Category"), category,
		EventSheetL10n.translate("The heading it is listed under in Add Action."), editable)
	_flag_row(form, "waits", EventSheetL10n.translate("Waits"), event_function.is_async,
		EventSheetL10n.translate("Whether the function can pause part way. Chosen for you when it contains a Wait."), editable)
	_flag_row(form, "shared", EventSheetL10n.translate("Shared"), event_function.is_static,
		EventSheetL10n.translate("Whether it belongs to each object or to the script itself."), editable)
	_build_parameters(form, event_function, editable)


## A type dropdown: every word of TYPE_WORDS described, plus the current type when it is not one of
## them. `with_nothing` keeps "Nothing", which only a return type can be.
static func type_dropdown(current: String, with_nothing: bool) -> OptionButton:
	var dropdown: OptionButton = EventSheetPopupUI.described_option()
	for word: String in TYPE_WORDS:
		if word == "Nothing" and not with_nothing:
			continue
		EventSheetPopupUI.add_described_item(dropdown, word, type_description(word))
	if not current.is_empty() and not Array(TYPE_WORDS).has(current):
		EventSheetPopupUI.add_described_item(dropdown, current, type_description(current))
	EventSheetPopupUI.select_option(dropdown, current if not current.is_empty() else "Variant")
	EventSheetPopupUI.follow_description(dropdown)
	return dropdown


func _row(form: GridContainer, label_text: String, field: Control, tooltip: String, editable: bool) -> void:
	var label: Label = Label.new()
	label.text = label_text
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	form.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if field.tooltip_text.is_empty():
		field.tooltip_text = tooltip
	_set_editable(field, editable)
	form.add_child(field)


static func _set_editable(field: Control, editable: bool) -> void:
	if field is LineEdit:
		(field as LineEdit).editable = editable
	elif field is BaseButton:
		(field as BaseButton).disabled = not editable


func _flag_row(form: GridContainer, flag: String, label_text: String, on: bool, tooltip: String, editable: bool) -> void:
	var dropdown: OptionButton = EventSheetPopupUI.described_option()
	for choice: Array in flag_choices(flag):
		EventSheetPopupUI.add_described_item(dropdown, str(choice[0]), str(choice[1]))
	dropdown.select(1 if on else 0)
	EventSheetPopupUI.follow_description(dropdown)
	dropdown.item_selected.connect(func(index: int) -> void: apply_flag(flag, index == 1))
	_row(form, label_text, dropdown, tooltip, editable)


## A text field commits when Enter is pressed and when focus leaves it - the Inspector's own habit.
static func _commit_on_submit(edit: LineEdit, commit: Callable) -> void:
	edit.text_submitted.connect(func(text: String) -> void: commit.call(text))
	edit.focus_exited.connect(func() -> void: commit.call(edit.text))


# ── Parameters: one line each, dragged by the handle to reorder ─────────────────────────────────


func _build_parameters(form: GridContainer, event_function: EventFunction, editable: bool) -> void:
	var heading: Label = EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Parameters"))
	form.add_child(heading)
	var add_button: Button = Button.new()
	add_button.text = EventSheetL10n.translate("+ Add")
	add_button.tooltip_text = EventSheetL10n.translate("Adds an input this function is called with.")
	add_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_button.disabled = not editable
	add_button.pressed.connect(func() -> void:
		var target: EventFunction = live_function()
		if target != null:
			_dock._function_dialog_glue._open_function_dialog_add_param(target))
	form.add_child(add_button)
	for index: int in range(event_function.params.size()):
		var param: ACEParam = event_function.params[index]
		var handle: Label = Label.new()
		handle.text = "⋮⋮  %s" % param.id
		handle.tooltip_text = EventSheetL10n.translate("Drag to move this parameter. Callers pass inputs in this order.")
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
		var fields: HBoxContainer = HBoxContainer.new()
		var type_option: OptionButton = type_dropdown(param.type_name.strip_edges(), false)
		type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var param_index: int = index
		type_option.item_selected.connect(func(choice: int) -> void:
			apply_param_type(param_index, type_option.get_item_text(choice)))
		var default_edit: LineEdit = LineEdit.new()
		default_edit.text = param.gdscript_default
		default_edit.placeholder_text = EventSheetL10n.translate("required")
		default_edit.tooltip_text = EventSheetL10n.translate("The value it has when a call leaves it out. Empty makes it required.")
		default_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_commit_on_submit(default_edit, func(text: String) -> void: apply_param_default(param_index, text.strip_edges()))
		_set_editable(type_option, editable)
		_set_editable(default_edit, editable)
		fields.add_child(type_option)
		fields.add_child(default_edit)
		if editable:
			# Godot's own drag-and-drop, forwarded: the handle hands over its index, and the line it is
			# dropped on takes that index's place.
			var can_drop: Callable = func(_at: Vector2, data: Variant) -> bool:
				return data is Dictionary and (data as Dictionary).has("function_parameter")
			var drop: Callable = func(_at: Vector2, data: Variant) -> void:
				move_param(int((data as Dictionary).get("function_parameter", -1)), param_index)
			var param_name: String = param.id
			handle.set_drag_forwarding(func(_at: Vector2) -> Variant:
				var preview: Label = Label.new()
				preview.text = param_name
				handle.set_drag_preview(preview)
				return {"function_parameter": param_index}, can_drop, drop)
			fields.set_drag_forwarding(Callable(), can_drop, drop)
		form.add_child(handle)
		form.add_child(fields)


# ── The writes: one undo step each, nothing written when nothing changed ────────────────────────


## Renames the function and every call to it in this sheet (and the sheets that include it).
func apply_name(new_name: String) -> bool:
	var cleaned: String = new_name.strip_edges()
	if cleaned.is_empty() or cleaned == _function_name:
		return false
	if not _dock._rename.rename_everywhere(_function_name, cleaned):
		return false
	_function_name = cleaned
	return true


## Writes one whole-function field through the function dialog's own edit path, so the Inspector and
## the dialog are the same edit. `field` is a key of that path's payload.
func apply_field(field: String, value: Variant) -> bool:
	var target: EventFunction = live_function()
	if target == null:
		return false
	var data: Dictionary = EventSheetFunctionDialogGlue.edit_payload(target)
	data[field] = value
	return _dock._function_dialog_glue._apply_function_edit(data)


func apply_returns(type_word: String) -> bool:
	var target: EventFunction = live_function()
	if target == null or return_word(target) == type_word:
		return false
	var fields: Array = return_fields(type_word)
	var data: Dictionary = EventSheetFunctionDialogGlue.edit_payload(target)
	data["return_type"] = fields[0]
	data["return_type_name"] = fields[1]
	return _dock._function_dialog_glue._apply_function_edit(data)


func apply_flag(flag: String, on: bool) -> bool:
	match flag:
		"in_add_action":
			return apply_field("expose", on)
		"waits":
			return apply_field("is_async", on)
		"shared":
			return apply_field("is_static", on)
	return false


func apply_param_type(index: int, type_word: String) -> void:
	_apply_param(index, "type_name", type_word)


func apply_param_default(index: int, default_text: String) -> void:
	_apply_param(index, "default", default_text)


func _apply_param(index: int, key: String, value: String) -> void:
	var target: EventFunction = live_function()
	if target == null or index < 0 or index >= target.params.size():
		return
	var param: ACEParam = target.params[index]
	var data: Dictionary = {
		"function": _function_name, "index": index, "id": param.id, "type_name": param.type_name,
		"default": param.gdscript_default, "description": param.description,
	}
	if str(data.get(key, "")) == value:
		return
	data[key] = value
	_dock._function_dialog_glue._apply_param_edit(data)


## Moves one parameter to another place in the list. Refused when the new order would put a
## parameter with a default before one without, which GDScript does not parse.
func move_param(from_index: int, to_index: int) -> bool:
	var target: EventFunction = live_function()
	if target == null or from_index == to_index or from_index < 0 or to_index < 0 \
			or from_index >= target.params.size() or to_index >= target.params.size():
		return false
	var order: Array = target.params.duplicate()
	var moved: Variant = order.pop_at(from_index)
	order.insert(to_index, moved)
	var seen_default: bool = false
	for param: Variant in order:
		var has_default: bool = not (param as ACEParam).gdscript_default.strip_edges().is_empty()
		if seen_default and not has_default:
			_dock._set_status(EventSheetL10n.translate(
				"Parameters with a default value must come after those without."), true)
			return false
		seen_default = seen_default or has_default
	var function_name: String = _function_name
	return _dock._perform_undoable_sheet_edit("Move Parameter", func() -> bool:
		for entry: Variant in _dock._current_sheet.functions:
			if entry is EventFunction and (entry as EventFunction).function_name == function_name:
				var params: Array[ACEParam] = (entry as EventFunction).params
				var param: ACEParam = params.pop_at(from_index)
				params.insert(to_index, param)
				return true
		return false)
