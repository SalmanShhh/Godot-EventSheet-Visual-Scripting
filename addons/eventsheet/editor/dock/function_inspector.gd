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
# A section is named by the parameter's place rather than its name because the Inspector
# capitalises section names, and a parameter is shown exactly as the code writes it.
#
# The fields are DRAWN by inspector/function_inspector_plugin.gd, which claims only this object:
# every dropdown describes each choice on hover and keeps the chosen one's sentence under the field,
# and each label's hover says what the field is for. This file answers what it shows - choices,
# purpose, note and warning - so the sentences stay beside the writes they describe. The line under a
# field steers a newcomer off an error BEFORE anything is written, in three strengths: REFUSED (a Name
# that is not a free identifier, a Default its Type cannot hold or that breaks the defaults-last
# order - they stay in their field as typed - and a Waits or Shared pick the body rules out), HINT
# (Returns with no Return in the body, Waits with nothing that waits, a parameter left required), and
# CONFIRMATION (the rename leaving the Name field will make).
#
# Loaded BY PATH on the first function selection, never on the boot path.

## The return and parameter types the dropdowns offer, as the code writes them. "Nothing" is the
## function that hands nothing back (`-> void`); a type outside the list is kept and offered as itself.
const TYPE_WORDS: PackedStringArray = ["Nothing", "bool", "int", "float", "String", "Vector2", "Vector3",
	"Color", "Array", "Dictionary", "Node", "Variant"]

## The one shape every quick question takes, loaded when the description window first opens.
const SMALL_PROMPT_PATH := "res://addons/eventsheet/editor/small_prompt.gd"

## The strength of a line under a field that is allowed but worth knowing; the editor's accent colours
## it. A refusal is EventSheetPopupUI.TONE_ERROR, and what leaving a field will do is TONE_OK.
const TONE_HINT := "hint"

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
# Typed text a guard refused: field -> value. Nothing was written, and the field keeps showing it
# with its warning until it is typed again.
var _refused: Dictionary = {}
# A pick a refusal turned back (Waits, Shared): field -> the sentence that says why, until the next pick.
var _said: Dictionary = {}
# How many places name the function besides its declaration, or -1 until asked (see call_count).
var _call_count: int = -1
var _watching: bool = false


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


## The described choices of the three yes/no settings, as [word, sentence] pairs: the first is
## "off", the second "on".
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


## What a category choice means: "Functions" (or none) is the default heading.
static func category_sentence(word: String) -> String:
	if word.strip_edges().is_empty() or word.strip_edges() == "Functions":
		return EventSheetL10n.translate("The default heading for your own functions.")
	return EventSheetL10n.translate("Listed under %s in Add Action.") % word.strip_edges()


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


## Hands this object to Godot's Inspector. Only in the editor: a headless run has no Inspector. The
## plugin that draws the fields is registered first, through the door the editor plugin gave the dock.
func inspect() -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		if _dock.function_fields_door.is_valid():
			_dock.function_fields_door.call()
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
	_call_count = -1
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


# ── What each field says: its purpose, its choices, the note and the warning under it ──────────


## The field a property the Inspector shows is ("name", "param:1:type", ...), or "".
func field_of(property: String) -> String:
	return str(_keys.get(property, ""))


## True for a field that shows a value without letting it be typed over.
func is_read_only(key: String) -> bool:
	return key.get_slice(":", 2) == "name"


## What a field is for, in one plain sentence: the hover on its label.
func purpose(key: String) -> String:
	match key:
		"name":
			return EventSheetL10n.translate("Exactly as written in code. Renaming it renames every call.")
		"description":
			return EventSheetL10n.translate("Shown when hovering the name, in Add Action and as the ## comment above the function.")
		"returns":
			return EventSheetL10n.translate("What the function hands back. Nothing makes it an action; any type makes it usable inside expressions, and its last action is Return.")
		"in_add_action":
			return EventSheetL10n.translate("Whether other events can pick it from Add Action like a built-in.")
		"category":
			return EventSheetL10n.translate("The heading it is listed under in Add Action.")
		"waits":
			return EventSheetL10n.translate("Whether the function can pause part way. Chosen for you when it contains a Wait.")
		"shared":
			return EventSheetL10n.translate("Whether it belongs to each object or to the script itself.")
	match key.get_slice(":", 2):
		"name":
			return EventSheetL10n.translate("The name the function's actions use for this input.")
		"type":
			return EventSheetL10n.translate("The kind of value a call passes in for this input.")
		"default":
			return EventSheetL10n.translate("The value it has when a call leaves it out. Empty makes it required.")
	return ""


## A dropdown's choices as [word, sentence] pairs, in the order of the indices the field stores.
func choices(key: String) -> Array:
	var event_function: EventFunction = live_function()
	if event_function == null:
		return []
	var pairs: Array = []
	match key:
		"returns":
			for word: String in type_words(return_word(event_function), true):
				pairs.append([EventSheetL10n.translate("Nothing") if word == "Nothing" else word, type_description(word)])
		"in_add_action", "waits", "shared":
			pairs = flag_choices(key)
		"category":
			for word: String in category_choices(_dock._current_sheet, event_function.ace_category):
				pairs.append([word, category_sentence(word)])
		_:
			var index: int = int(key.get_slice(":", 1))
			if key.get_slice(":", 2) == "type" and index >= 0 and index < event_function.params.size():
				for word: String in type_words(event_function.params[index].type_name.strip_edges(), false):
					pairs.append([word, type_description(word)])
	return pairs


## The sentence kept under a field: a Category's meaning, or a parameter Type read as "int: A whole
## number...". "" leaves the drawer to show the chosen choice's own sentence. `text` is what the field
## shows: the typed text, or the chosen choice's word.
func note(key: String, text: String) -> String:
	if key == "category":
		return category_sentence(text)
	if key.get_slice(":", 2) == "type" and not text.is_empty():
		return "%s: %s" % [text, type_description(text)]
	return ""


## The line under a field as [tone, sentence], or ["", ""] when there is nothing to say. The tone is
## its strength: TONE_ERROR is refused (nothing is written), TONE_HINT is allowed but worth knowing,
## TONE_OK says what leaving the field will do. `text` is what the field shows now.
func warning(key: String, text: String) -> Array:
	var event_function: EventFunction = live_function()
	if event_function == null:
		return ["", ""]
	if _said.has(key):
		return [EventSheetPopupUI.TONE_ERROR, str(_said[key])]
	match key:
		"name":
			return name_problem(text)
		"returns":
			var word: String = return_word(event_function)
			if word != "Nothing" and not body_has(event_function, _returns_value):
				return [TONE_HINT, EventSheetL10n.translate("%s hands back %s, but no event in it says Return yet. Add a Return action as its last step, or callers get %s.") % [
					_function_name, word, zero_of(word)]]
		"waits":
			if event_function.is_async and not body_has(event_function, _waits):
				return [TONE_HINT, EventSheetL10n.translate("Nothing in %s waits yet, so Can wait only makes callers write await. Add a Wait, or pick Finishes at once.") % _function_name]
		_:
			if key.get_slice(":", 2) == "default":
				return default_problem(int(key.get_slice(":", 1)), text)
	return ["", ""]


## True when typed text must not be written: its line is a refusal.
func refuses(key: String, text: String) -> bool:
	return (key == "name" or key.get_slice(":", 2) == "default") \
		and str(warning(key, text)[0]) == EventSheetPopupUI.TONE_ERROR


## Why a pick of Waits or Shared is refused, or "": a function with a Wait inside always pauses, and
## a shared one cannot reach a variable each object has its own copy of.
func pick_refusal(flag: String, on: bool) -> String:
	var event_function: EventFunction = live_function()
	if event_function == null:
		return ""
	if flag == "waits" and not on and body_has(event_function, _waits):
		return EventSheetL10n.translate("%s has a Wait inside, so it always pauses part way. It stays Can wait; remove the Wait first to change this.") % _function_name
	if flag == "shared" and on:
		var used: String = object_variable_used(event_function)
		if not used.is_empty():
			return EventSheetL10n.translate("%s uses %s, which each object has its own copy of. A shared function cannot reach it, so this stays One per object.") % [
				_function_name, used]
	return ""


## The line a new name for this function gets: refused with a free name to use instead, or the rename
## that leaving the field will make. The function's own name says nothing.
func name_problem(text: String) -> Array:
	var wanted: String = text.strip_edges()
	if wanted == _function_name:
		return ["", ""]
	var refused: String = EventSheetPopupUI.TONE_ERROR
	if wanted.is_empty():
		return [refused, EventSheetL10n.translate("A function needs a name. Nothing was changed.")]
	var suggestion: String = free_name(wanted)
	if EventSheetIdentifierRules.RESERVED.has(wanted):
		return [refused, EventSheetL10n.translate("\"%s\" is a word GDScript keeps for itself. Try %s. Nothing was changed.") % [wanted, suggestion]]
	if not EventSheetIdentifierRules.is_valid(wanted):
		return [refused, EventSheetL10n.translate("\"%s\" cannot be a name: use letters, numbers and _, and do not start with a number. Try %s. Nothing was changed.") % [
			wanted, suggestion]]
	match _taken_names().get(wanted, ""):
		"function":
			return [refused, EventSheetL10n.translate("There is already a function %s on this sheet, so calls could not tell them apart. Try %s. Nothing was changed.") % [
				wanted, suggestion]]
		"variable":
			return [refused, EventSheetL10n.translate("\"%s\" is already the variable %s on this sheet, and two things with one name break the script. Try %s. Nothing was changed.") % [
				wanted, wanted, suggestion]]
		"signal":
			return [refused, EventSheetL10n.translate("\"%s\" is already the signal %s on this sheet, and two things with one name break the script. Try %s. Nothing was changed.") % [
				wanted, wanted, suggestion]]
	return [EventSheetPopupUI.TONE_OK, EventSheetL10n.translate("When you leave the field: renames %s to %s, and its %d calls with it. Ctrl+Z undoes it.") % [
		_function_name, wanted, call_count()]]


## How many places in this sheet name the function, besides its own declaration. Counted once per
## refresh, on a copy, by the same rename the field will make.
func call_count() -> int:
	if _call_count < 0:
		var copy: EventSheetResource = _dock._current_sheet.duplicate(true) if _dock != null and _dock._current_sheet != null else null
		_call_count = maxi(EventSheetRefactor.rename_symbol(copy, _function_name, "__name_probe__") - 1, 0) if copy != null else 0
	return _call_count


## The nearest free name to `wanted`: lowercase, every other character an _, an _ before a leading
## number, then _2, _3... until it is no keyword and nothing of this sheet is called it.
func free_name(wanted: String) -> String:
	var base: String = ""
	for character: String in wanted.strip_edges().to_lower():
		base += character if (character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "_" else "_"
	if base.is_empty():
		base = "my_function"
	if base[0] >= "0" and base[0] <= "9":
		base = "_" + base
	var taken: Dictionary = _taken_names()
	var candidate: String = base
	var number: int = 2
	while EventSheetIdentifierRules.RESERVED.has(candidate) or (taken.has(candidate) and candidate != _function_name):
		candidate = "%s_%d" % [base, number]
		number += 1
	return candidate


## Every name this sheet already gives a function, a variable or a signal: name -> which of the three.
func _taken_names() -> Dictionary:
	var taken: Dictionary = {}
	for variable: LocalVariable in _sheet_variables():
		taken[variable.name] = "variable"
	var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
	if sheet == null:
		return taken
	for key: Variant in sheet.variables:
		taken[str(key)] = "variable"
	for row: Variant in _sheet_rows():
		if row is SignalRow:
			taken[(row as SignalRow).signal_name] = "signal"
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name != _function_name:
			taken[(entry as EventFunction).function_name] = "function"
	return taken


## The sheet's rows, groups opened, in no particular order.
func _sheet_rows() -> Array:
	var found: Array = []
	var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
	var rows: Array = sheet.events.duplicate() if sheet != null else []
	while not rows.is_empty():
		var row: Variant = rows.pop_back()
		found.append(row)
		if row is EventGroup:
			rows.append_array((row as EventGroup).events if not (row as EventGroup).events.is_empty() else (row as EventGroup).rows)
	return found


func _sheet_variables() -> Array[LocalVariable]:
	var found: Array[LocalVariable] = []
	for row: Variant in _sheet_rows():
		if row is LocalVariable and not (row as LocalVariable).name.is_empty():
			found.append(row as LocalVariable)
	return found


## The first variable each object has its own copy of that the function's body names, or "".
func object_variable_used(event_function: EventFunction) -> String:
	var names: PackedStringArray = PackedStringArray()
	for variable: LocalVariable in _sheet_variables():
		if not variable.is_static and not variable.is_constant:
			names.append(variable.name)
	var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
	for key: Variant in sheet.variables if sheet != null else {}:
		names.append(str(key))
	names.sort()
	var text: String = body_text(event_function)
	for name: String in names:
		if RegEx.create_from_string("\\b%s\\b" % name).search(text) != null:
			return name
	return ""


## The line a parameter's default gets: refused when its Type cannot hold it or GDScript's order of
## defaults would break, a hint when it leaves the parameter required.
func default_problem(index: int, text: String) -> Array:
	var event_function: EventFunction = live_function()
	if event_function == null or index < 0 or index >= event_function.params.size():
		return ["", ""]
	var value: String = text.strip_edges()
	var params: Array[ACEParam] = event_function.params
	var this_id: String = params[index].id
	for other: int in range(params.size()):
		var other_has: bool = not params[other].gdscript_default.strip_edges().is_empty()
		if value.is_empty() and other < index and other_has:
			return [EventSheetPopupUI.TONE_ERROR, EventSheetL10n.translate("GDScript needs parameters without a default first, and %s before it has one. Give %s a default, or move it up. Nothing was changed.") % [
				params[other].id, this_id]]
		if not value.is_empty() and other > index and not other_has:
			return [EventSheetPopupUI.TONE_ERROR, EventSheetL10n.translate("GDScript needs parameters without a default first, and %s after it has none. Give %s a default too, or move %s down. Nothing was changed.") % [
				params[other].id, params[other].id, this_id]]
	if value.is_empty():
		return [TONE_HINT, EventSheetL10n.translate("Required: every call to %s must give %s.") % [_function_name, this_id]]
	var type_word: String = params[index].type_name.strip_edges()
	if value_fits(type_word, value, _known_word):
		return ["", ""]
	return [EventSheetPopupUI.TONE_ERROR, EventSheetL10n.translate("\"%s\" is not %s, so %s (%s) cannot start as it. Nothing was changed.") % [
		value, value_phrase(type_word), this_id, type_word]]


## True unless `text` plainly is not a value of `type_word`. Only what can be read for certain is
## judged: a literal is checked against the type, and a bare word must name something `known` accepts
## (a constant, a class, an engine singleton, this sheet's own names). Anything else - `Vector2.ZERO`,
## a call, a sum - is left to GDScript, so a valid default is never refused.
static func value_fits(type_word: String, text: String, known: Callable) -> bool:
	var expression: Expression = Expression.new()
	if expression.parse(text) != OK:
		return true
	var value: Variant = expression.execute([], null, false, true)
	if expression.has_execute_failed():
		var bare: RegEx = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
		return bare.search(text) == null or known.call(text)
	var expected: int = return_fields(type_word)[0]
	if type_word.begins_with("Array"):
		return typeof(value) == TYPE_ARRAY
	if type_word.begins_with("Dictionary"):
		return typeof(value) == TYPE_DICTIONARY
	if expected == TYPE_MAX:
		# A node or a class of the project takes only `null` as a written default; anything else that
		# is not a builtin type (Variant, an enum) is GDScript's to judge.
		return value == null or not (ClassDB.class_exists(type_word) or _is_project_class(type_word))
	return typeof(value) == expected or (expected == TYPE_FLOAT and typeof(value) == TYPE_INT) \
		or (expected == TYPE_STRING_NAME and typeof(value) == TYPE_STRING)


## What a value of a type looks like, said for a refused default.
static func value_phrase(type_word: String) -> String:
	match type_word:
		"bool":
			return EventSheetL10n.translate("true or false")
		"int":
			return EventSheetL10n.translate("a whole number (like 1)")
		"float":
			return EventSheetL10n.translate("a number (like 0.5)")
		"String":
			return EventSheetL10n.translate("text in quotes (like \"Ready\")")
		"Vector2":
			return EventSheetL10n.translate("Vector2(0, 0) or Vector2.ZERO")
		"Vector3":
			return EventSheetL10n.translate("Vector3(0, 0, 0) or Vector3.ZERO")
		"Color":
			return EventSheetL10n.translate("a color (like Color.WHITE)")
	if type_word.begins_with("Array"):
		return EventSheetL10n.translate("a list (like [])")
	if type_word.begins_with("Dictionary"):
		return EventSheetL10n.translate("a dictionary (like {})")
	return EventSheetL10n.translate("null (no object yet)")


## What a caller gets back from a function of this type that never says Return, as GDScript writes it.
static func zero_of(type_word: String) -> String:
	var zeros: Dictionary = {"bool": "false", "int": "0", "float": "0.0", "String": "\"\"",
		"Vector2": "Vector2(0, 0)", "Vector3": "Vector3(0, 0, 0)", "Color": "Color(0, 0, 0, 1)", "Array": "[]",
		"Dictionary": "{}"}
	return str(zeros.get(type_word, "null"))


## True for a bare word a default may name: a constant-style word, a class, an engine singleton, or a
## variable, signal, function or enum this sheet declares.
func _known_word(word: String) -> bool:
	if word == word.to_upper() or ClassDB.class_exists(word) or Engine.has_singleton(word) or _is_project_class(word):
		return true
	if _taken_names().has(word) or word == _function_name:
		return true
	for row: Variant in _sheet_rows():
		if row is EnumRow and ((row as EnumRow).enum_name == word or (row as EnumRow).members.has(word)):
			return true
	return false


static func _is_project_class(word: String) -> bool:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == word:
			return true
	return false


## True when any row of the function's body, at any depth, passes `test`.
static func body_has(event_function: EventFunction, test: Callable) -> bool:
	for row: Resource in _body_rows(event_function):
		if test.call(row):
			return true
	return false


## Every row of the function's body at any depth: each stored array of a row is opened in turn.
static func _body_rows(event_function: EventFunction) -> Array[Resource]:
	var found: Array[Resource] = []
	var rows: Array = (event_function.events if not event_function.events.is_empty() else event_function.rows).duplicate()
	while not rows.is_empty():
		var row: Variant = rows.pop_back()
		if not (row is Resource):
			continue
		found.append(row as Resource)
		for property: Dictionary in (row as Resource).get_property_list():
			if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE and int(property.get("type", 0)) == TYPE_ARRAY:
				rows.append_array((row as Resource).get(str(property["name"])))
	return found


## Every word the function's body holds - code, templates, parameter values - as one text to search.
static func body_text(event_function: EventFunction) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row: Resource in _body_rows(event_function):
		for property: Dictionary in row.get_property_list():
			if not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
				continue
			var value: Variant = row.get(str(property["name"]))
			if value is String or value is StringName:
				parts.append(str(value))
			elif value is Dictionary:
				for item: Variant in (value as Dictionary).values():
					parts.append(str(item))
	return "\n".join(parts)


## A Return Value action, or a line of code that returns something.
static func _returns_value(row: Resource) -> bool:
	var returns: RegEx = RegEx.create_from_string("(?m)^\\s*return\\s+[^\\s#]")
	if row is ACEAction:
		return (row as ACEAction).ace_id == "ReturnValue" or returns.search((row as ACEAction).codegen_template) != null
	return row is RawCodeRow and returns.search((row as RawCodeRow).code) != null


## An action that pauses (a Wait, an await of a signal), or a line of code that awaits.
static func _waits(row: Resource) -> bool:
	if row is ACEAction:
		var action: ACEAction = row as ACEAction
		return action.is_awaited or action.await_call or action.codegen_template.contains("await ") \
			or SheetCompiler._COROUTINE_ACE_IDS.has(action.ace_id)
	return row is RawCodeRow and (row as RawCodeRow).code.contains("await ")


func _get(property: StringName) -> Variant:
	var key: String = str(_keys.get(str(property), ""))
	var event_function: EventFunction = live_function()
	if key.is_empty() or event_function == null:
		return null
	if _pending.has(key):
		return _pending[key]
	if _refused.has(key):
		return _refused[key]
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
			var refusal: String = pick_refusal(key, bool(value))
			_said.erase(key)
			if refusal.is_empty():
				apply_flag(key, bool(value))
			else:
				# Nothing is written; the field reads the setting it has, with the reason under it.
				_said[key] = refusal
				refresh()
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
	_refused.erase(key)


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
## written. A Name or Default its warning refuses writes nothing and stays in its field as typed.
func commit_pending() -> void:
	var held: Dictionary = _pending.duplicate()
	_pending.clear()
	for key: String in held:
		var text: String = str(held[key]).strip_edges()
		if refuses(key, text):
			_refused[key] = str(held[key])
			continue
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
