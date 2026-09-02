# EventForge - ACEParam resource
# Describes a typed parameter accepted by an ACE descriptor.
#
# Supported type_name values (GDScript-aligned):
#   "bool" / "boolean"        → checkbox / bool dropdown
#   "int" / "integer"         → integer SpinBox
#   "float" / "double"        → float SpinBox
#   "String" / "string"       → text field (default)
#   Any type with options[]   → enum dropdown (combo). Entries are either a plain "value" string
#                               (label == value) or a {"key": <inserted value>, "label": <shown text>}
#                               dict, so a dropdown can show "Warning" while inserting `push_warning`.
#   Any type with hint = "variable_reference"
#                             → variable dropdown populated from sheet variables
#   String params with hint = "expression"
#                             → text field with expression picker button
@tool
class_name ACEParam
extends Resource

@export var id: String = ""
@export var name: String = "" # Backwards-compatible alias for early Phase 1 code.
@export var display_name: String = ""
@export var description: String = ""
@export var desc: String = "" # event-sheet-style alias.
@export var type: int = TYPE_STRING
## Human-readable GDScript type name. Drives the UI control choice.
@export var type_name: String = "String"
@export var default_value: Variant = ""
## For SHEET-FUNCTION parameters only: an optional GDScript default argument, emitted into the
## function signature as `name: type = <this>` (so the parameter is optional). Distinct from
## default_value (a picker pre-fill); empty = a required parameter. GDScript requires defaulted
## parameters to be trailing - the function dialog enforces that.
@export var gdscript_default: String = ""
@export var initial_value: Variant = null
@export var initialValue: Variant = null # event-sheet-style alias.
# Untyped so entries may be plain value strings OR {"key","label"} dicts (friendly label ↔ inserted value).
@export var options: Array = []
## Suggestions for an EDITABLE autocomplete combo (event-sheet-style): unlike `options`
## (a fixed dropdown), the user may type any value AND pick/filter from these. A behavior
## opts in per-param via `## @ace_param_autocomplete(param "a", "b", …)`; empty = plain field.
@export var autocomplete: Array[String] = []
@export var required: bool = false
## UI hint for richer control selection.
## Use "variable_reference" to show a dropdown of available sheet variables.
## Use "expression" to show an expression picker button beside text input.
@export var hint: String = ""
## Display-only: substitute this param's OPTION LABEL into the row sentence instead of its raw value.
## Only ever set it on a param whose emitted value is always exactly one of `options` - the label is
## then a faithful reading of the value, not a guess. It exists because an option key is GDScript
## (`"y"`, quotes and all) while the row is a sentence: without this, "set the up/down part of
## velocity" renders as `set the "y" part of velocity`. Left false everywhere the key IS the natural
## reading (a comparison operator shows as `>`, never as "> (greater than)").
@export var display_option_labels: bool = false
## Display-only: the name of a READING LENS the canvas puts this param's value through before it
## lands in the row sentence (see EventForgeValueLens - "darkness" reads a CanvasModulate colour as
## "81%, tinted #26304d"). The stored value never changes, the dialog and the code echo go on
## showing the author's own GDScript, and a name no lens answers to reads exactly as it always did.
## Set it only where the reading is DERIVED from the value rather than a second way of writing it.
@export var display_lens: String = ""


## ONE PARAMETER, BUILT. The single place an ACEParam's fields are filled in, so a parameter means
## the same thing wherever it was authored from: the factory's `make_param`, a descriptor's chained
## `.param(...)`, and any pack builder reaching for a parameter directly all land here.
##
## `hint` selects the dialog field ("expression" = the fx button, "key_capture" = press-a-key,
## "audio_path" = path + preview, "color", ...); `options` makes it a fixed dropdown; `autocomplete`
## makes it an editable suggest combo (type freely + filter/pick). `options` entries are either a
## plain value string (label == value) or a {"key": <inserted value>, "label": <shown text>} dict, so
## a dropdown can read "Warning" while inserting `push_warning`.
static func of(param_id: String, type_name: String, default_value: Variant = "", display_name: String = "", description: String = "", hint: String = "", options: Array = [], autocomplete: Array[String] = []) -> ACEParam:
	var parameter: ACEParam = ACEParam.new()
	parameter.id = param_id
	parameter.name = param_id
	parameter.display_name = display_name if not display_name.is_empty() else param_id
	parameter.description = description
	parameter.desc = description
	parameter.type_name = type_name
	parameter.default_value = default_value
	parameter.initial_value = default_value
	parameter.initialValue = default_value
	parameter.hint = hint
	parameter.options = options.duplicate()
	parameter.autocomplete = autocomplete.duplicate()
	return parameter


## THE TYPE A DEFAULT SAYS IT IS - the answer behind a descriptor's `.param(...)`, which names no
## type at all because the value a row starts on already names one: `true` is a checkbox, `3` an
## integer spinner, `1.5` a float spinner, and text is a String field (the ordinary case, and the
## one every GDScript-expression parameter is in - its default is the expression's own text).
##
## A default whose TEXT stands for a value of another type - `Vector2.ZERO`, `self`, a Color
## constructor - is text as far as this question goes, which is exactly why a descriptor spells
## those out with `.param_typed(...)` instead.
static func type_name_for(default_value: Variant) -> String:
	match typeof(default_value):
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR2I:
			return "Vector2i"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_COLOR:
			return "Color"
	return "String"


## The same field, set inline and handed back - so a parameter that wants a lens can be written in
## the descriptor's own argument list rather than pulled out into a variable first, exactly as
## `described()` and `featured()` are written on a descriptor.
func with_lens(lens: String) -> ACEParam:
	display_lens = lens
	return self


## The label a value should be SHOWN as in a row sentence: the matching option's label when this
## param opted into label display, and the value itself otherwise (including a value that matches no
## option, which can only mean the row was authored before an option was removed).
func display_value(value: Variant) -> String:
	var text: String = str(value)
	if not display_option_labels:
		return text
	for option: Variant in options:
		if option is Dictionary and str((option as Dictionary).get("key", "")) == text:
			return str((option as Dictionary).get("label", text))
	return text


## Returns the best available display name for picker/inspector UI.
func get_param_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not name.is_empty():
		return name
	return id


## Returns the best available parameter description.
func get_param_description() -> String:
	if not description.is_empty():
		return description
	return desc


## Returns the best available default/initial value.
func get_initial_value() -> Variant:
	if initial_value != null:
		return initial_value
	if initialValue != null:
		return initialValue
	return default_value
