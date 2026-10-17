@tool
extends RefCounted
# The selected function, edited in Godot's own Inspector. This object is what the Inspector shows:
#
#   Function take_damage
#   Name           take_damage
#   Description    Removes health, flashes the sprite, and dies at zero.
#   Returns        Nothing ▾
#   In Add Action  ☑
#   Category       Player
#   Waits          ☐
#   Shared         ☐
#   ▾ Parameters
#     ▾ 1   Name amount · Type int ▾ · Default 1
#     ▾ 2   Name critical · Type bool ▾ · Default false · [Move Up]
#     [Add Parameter]
#
# _get_property_list says the fields, _get reads them off the live function and _set writes each
# change as ONE undo step through the dock's edit funnel, applied by the function's NAME and
# re-fetched every time (the funnel replaces resources on commit). A field that ends up holding what
# it held writes nothing, so an opened .gd stays byte-exact until something really changes.
#
# Three habits of the Inspector are answered here rather than worked around elsewhere:
# - It records every change in the editor's own history. The funnel already makes the undo step,
#   so _dont_undo_redo hands the Inspector's step back - otherwise each change took two Ctrl+Z.
# - A text field hands over every keystroke. A rename renames every call (and saves the sheets that
#   include this one), so a typed value is held until its field is left - Enter, or the focus moving
#   on - and then written once.
# - Its own array list moves elements through the editor's history directly, outside the sheet's
#   undo, so the order is changed with a Move Up button on each parameter instead.
# The Inspector cannot describe the choices of a dropdown one by one, which the Properties bar
# panel this replaces did; the name's hover on the sheet still says what the function is for.
# A section is named by the parameter's place rather than its name because the Inspector
# capitalises section names, and a parameter is shown exactly as the code writes it.
#
# Loaded BY PATH on the first function selection, never on the boot path.

## The return and parameter types the dropdowns offer, as the code writes them. "Nothing" is the
## function that hands nothing back (`-> void`); a type outside the list is kept and offered as itself.
const TYPE_WORDS: PackedStringArray = ["Nothing", "bool", "int", "float", "String", "Vector2", "Vector3",
	"Color", "Array", "Dictionary", "Node", "Variant"]

## The one shape every quick question takes, loaded when the description window first opens.
const SMALL_PROMPT_PATH := "res://addons/eventsheet/editor/small_prompt.gd"

## How often a held text value checks whether its field has been left, in seconds.
const HOLD_CHECK_SECONDS := 0.25

var _dock: Control = null
var _function_name: String = ""
# Property name as the Inspector shows it -> the field it is ("name", "param:1:type", ...). Rebuilt
# with the property list, since the names are the translated words.
var _keys: Dictionary = {}
# Typed text not written yet: field -> value. Read back by _get, so the Inspector's own refresh never
# puts the old value back under the cursor.
var _pending: Dictionary = {}
var _watching: bool = false


func _init(dock: Control, event_function: EventFunction) -> void:
	_dock = dock
	_function_name = event_function.function_name


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


## The categories the Category field suggests: the ones this sheet's functions already file under,
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


## The words a type dropdown offers: TYPE_WORDS, plus the current type when it is not one of them.
## `with_nothing` keeps "Nothing", which only a return type can be.
static func type_words(current: String, with_nothing: bool) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for word: String in TYPE_WORDS:
		if word != "Nothing" or with_nothing:
			words.append(word)
	if not current.is_empty() and not words.has(current):
		words.append(current)
	return words


## The small window a double-click on a function's name opens beside the row: the description in a
## text box, Save and Cancel. Save writes it as one undo step, the same edit the Description field makes.
static func open_description_editor(dock: Control, event_function: EventFunction, at: Vector2) -> ConfirmationDialog:
	var inspector: RefCounted = new(dock, event_function)
	var text: TextEdit = TextEdit.new()
	text.name = "Description"
	text.text = event_function.description
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(300.0), EventSheetPalette.scaled_f(64.0))
	var dialog: ConfirmationDialog = load(SMALL_PROMPT_PATH).open(dock, {
		"title": EventSheetL10n.translate("Description of %s") % event_function.function_name,
		"say": EventSheetL10n.translate("Shown when hovering the name, in Add Action and as the ## comment above the function."),
		"body": text,
		"glyph": "i",
		"main": EventSheetL10n.translate("Save"),
		"on_main": func() -> void: inspector.apply_field("description", text.text.strip_edges()),
		"note": EventSheetL10n.translate("Ctrl+Z undoes it."),
	})
	if dialog.is_inside_tree():
		# Beside the row it describes, not in the middle of the screen: the name stays in view.
		dialog.position = Vector2i(at) + Vector2i(roundi(EventSheetPalette.scaled_f(12.0)), roundi(EventSheetPalette.scaled_f(12.0)))
		text.grab_focus()
	return dialog


## The function this object edits, re-fetched from the live sheet (never held across an edit).
func live_function() -> EventFunction:
	if _dock == null or _dock._current_sheet == null:
		return null
	for entry: Variant in _dock._current_sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == _function_name:
			return entry as EventFunction
	return null


## True when this object is the one editing `event_function`.
func edits(event_function: EventFunction) -> bool:
	return event_function != null and event_function.function_name == _function_name


## Hands this object to Godot's Inspector. Only in the editor: a headless run has no Inspector.
func inspect() -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.inspect_object(self, "", true)


## The function is no longer selected (or its sheet closed): the Inspector stops showing this object,
## so it never stays on a function nothing points at. Text still held is written first: its field is
## being left, which is all the hold waits for.
func release() -> void:
	if not _pending.is_empty():
		commit_pending()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface") \
			and EditorInterface.get_inspector().get_edited_object() == self:
		EditorInterface.inspect_object(null)


## The sheet changed under the Inspector (an edit, an undo): it reads the fields again.
func refresh() -> void:
	notify_property_list_changed()


# ── What the Inspector shows ─────────────────────────────────────────────────────────────────────


func _dont_undo_redo() -> bool:
	return true


func _get_property_list() -> Array[Dictionary]:
	_keys.clear()
	var properties: Array[Dictionary] = []
	var event_function: EventFunction = live_function()
	if event_function == null:
		return properties
	properties.append({"name": EventSheetL10n.translate("Function %s") % event_function.function_name,
		"type": TYPE_NIL, "usage": PROPERTY_USAGE_CATEGORY})
	_add(properties, "name", EventSheetL10n.translate("Name"), TYPE_STRING)
	_add(properties, "description", EventSheetL10n.translate("Description"), TYPE_STRING, PROPERTY_HINT_MULTILINE_TEXT)
	_add(properties, "returns", EventSheetL10n.translate("Returns"), TYPE_INT, PROPERTY_HINT_ENUM,
		",".join(_return_choices(event_function)))
	_add(properties, "in_add_action", EventSheetL10n.translate("In Add Action"), TYPE_BOOL)
	_add(properties, "category", EventSheetL10n.translate("Category"), TYPE_STRING, PROPERTY_HINT_ENUM_SUGGESTION,
		",".join(category_choices(_dock._current_sheet, event_function.ace_category)))
	_add(properties, "waits", EventSheetL10n.translate("Waits"), TYPE_BOOL)
	_add(properties, "shared", EventSheetL10n.translate("Shared"), TYPE_BOOL)
	var section: String = EventSheetL10n.translate("Parameters")
	for index: int in range(event_function.params.size()):
		var param: ACEParam = event_function.params[index]
		var place: String = "%s/%d/" % [section, index + 1]
		_add(properties, "param:%d:name" % index, place + EventSheetL10n.translate("Name"), TYPE_STRING,
			PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
		_add(properties, "param:%d:type" % index, place + EventSheetL10n.translate("Type"), TYPE_INT, PROPERTY_HINT_ENUM,
			",".join(type_words(param.type_name.strip_edges(), false)))
		_add(properties, "param:%d:default" % index, place + EventSheetL10n.translate("Default"), TYPE_STRING,
			PROPERTY_HINT_PLACEHOLDER_TEXT, EventSheetL10n.translate("required"))
		if index > 0:
			_add(properties, "param:%d:up" % index, place + EventSheetL10n.translate("Move Up"), TYPE_CALLABLE,
				PROPERTY_HINT_TOOL_BUTTON, EventSheetL10n.translate("Move Up") + ",MoveUp")
	_add(properties, "add_param", "%s/%s" % [section, EventSheetL10n.translate("Add Parameter")], TYPE_CALLABLE,
		PROPERTY_HINT_TOOL_BUTTON, EventSheetL10n.translate("Add Parameter") + ",Add")
	return properties


func _add(properties: Array[Dictionary], key: String, shown: String, type: int,
		hint: int = PROPERTY_HINT_NONE, hint_string: String = "", usage: int = PROPERTY_USAGE_EDITOR) -> void:
	_keys[shown] = key
	properties.append({"name": shown, "type": type, "hint": hint, "hint_string": hint_string, "usage": usage})


## The Returns choices as the dropdown shows them: "Nothing" in the editor's language, every type as
## the code writes it.
func _return_choices(event_function: EventFunction) -> PackedStringArray:
	var shown: PackedStringArray = type_words(return_word(event_function), true)
	shown[0] = EventSheetL10n.translate("Nothing")
	return shown


func _get(property: StringName) -> Variant:
	var key: String = str(_keys.get(str(property), ""))
	var event_function: EventFunction = live_function()
	if key.is_empty() or event_function == null:
		return null
	if _pending.has(key):
		return _pending[key]
	match key:
		"name":
			return event_function.function_name
		"description":
			return event_function.description
		"returns":
			return Array(type_words(return_word(event_function), true)).find(return_word(event_function))
		"in_add_action":
			return event_function.expose_as_ace
		"category":
			return event_function.ace_category
		"waits":
			return event_function.is_async
		"shared":
			return event_function.is_static
		"add_param":
			return add_param
	var index: int = int(key.get_slice(":", 1))
	if index < 0 or index >= event_function.params.size():
		return null
	var param: ACEParam = event_function.params[index]
	match key.get_slice(":", 2):
		"name":
			return param.id
		"type":
			return Array(type_words(param.type_name.strip_edges(), false)).find(param.type_name.strip_edges())
		"default":
			return param.gdscript_default
		"up":
			return move_param.bind(index, index - 1)
	return null


func _set(property: StringName, value: Variant) -> bool:
	var key: String = str(_keys.get(str(property), ""))
	var event_function: EventFunction = live_function()
	if key.is_empty() or event_function == null:
		return false
	match key:
		"name", "description", "category":
			_hold_until_left(key, str(value))
		"returns":
			var words: PackedStringArray = type_words(return_word(event_function), true)
			if int(value) >= 0 and int(value) < words.size():
				apply_returns(words[int(value)])
		"in_add_action", "waits", "shared":
			apply_flag(key, bool(value))
		_:
			var index: int = int(key.get_slice(":", 1))
			if index < 0 or index >= event_function.params.size():
				return false
			match key.get_slice(":", 2):
				"type":
					var param_words: PackedStringArray = type_words(event_function.params[index].type_name.strip_edges(), false)
					if int(value) >= 0 and int(value) < param_words.size():
						apply_param_type(index, param_words[int(value)])
				"default":
					_hold_until_left(key, str(value))
				_:
					return false
	return true


# ── Typed text waits until its field is left ───────────────────────────────────────────────────


## Keeps a typed value without writing it. It is written by commit_pending, once its field is left.
func hold(key: String, value: String) -> void:
	_pending[key] = value


func _hold_until_left(key: String, value: String) -> void:
	hold(key, value)
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface") or _dock == null \
			or not _dock.is_inside_tree():
		# No Inspector field to leave: the value is written as it comes.
		commit_pending()
		return
	if not _watching:
		_watching = true
		_dock.get_tree().create_timer(HOLD_CHECK_SECONDS).timeout.connect(_check_held)


func _check_held() -> void:
	_watching = false
	if _pending.is_empty():
		return
	if _pending.has(_typing_in()):
		_watching = true
		_dock.get_tree().create_timer(HOLD_CHECK_SECONDS).timeout.connect(_check_held)
		return
	commit_pending()


## The field the Inspector's focused text box belongs to, or "" when the focus is anywhere else.
func _typing_in() -> String:
	var inspector: Control = EditorInterface.get_inspector()
	var focused: Control = inspector.get_viewport().gui_get_focus_owner() if inspector != null else null
	while focused != null and not focused.is_class("EditorProperty"):
		focused = focused.get_parent() as Control
	if focused == null or focused.call("get_edited_object") != self:
		return ""
	return str(_keys.get(str(focused.call("get_edited_property")), ""))


## Writes every held value, each as its own undo step, then lets the Inspector read what was really
## written - a name the sheet refused goes back to the one it has.
func commit_pending() -> void:
	var held: Dictionary = _pending.duplicate()
	_pending.clear()
	for key: String in held:
		var text: String = str(held[key]).strip_edges()
		match key:
			"name":
				apply_name(text)
			"description":
				apply_field("description", text)
			"category":
				var current: String = live_function().ace_category.strip_edges() if live_function() != null else ""
				# "Functions" is the heading an uncategorised function is already listed under, so
				# choosing it for one with none is no change at all.
				if text != current and not (text == "Functions" and current.is_empty()):
					apply_field("ace_category", text)
			_:
				apply_param_default(int(key.get_slice(":", 1)), text)
	refresh()


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


## Add Parameter: the parameter window, the same one a function row's "+ Add parameter" opens.
func add_param() -> void:
	var target: EventFunction = live_function()
	if target != null:
		_dock._function_dialog_glue._open_function_dialog_add_param(target)


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
	var moved_one: bool = _dock._perform_undoable_sheet_edit("Move Parameter", func() -> bool:
		for entry: Variant in _dock._current_sheet.functions:
			if entry is EventFunction and (entry as EventFunction).function_name == function_name:
				var params: Array[ACEParam] = (entry as EventFunction).params
				var param: ACEParam = params.pop_at(from_index)
				params.insert(to_index, param)
				return true
		return false)
	refresh()
	return moved_one
