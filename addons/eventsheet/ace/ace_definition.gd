@tool
class_name ACEDefinition
extends Resource

enum ACEType {
	CONDITION,
	ACTION,
	EXPRESSION,
	TRIGGER
}

var provider_id: String = ""
var id: String = ""
var display_name: String = ""
var category: String = ""
var ace_type: int = ACEType.ACTION
var description: String = ""
var parameters: Array = []
var return_type: Variant.Type = TYPE_NIL
var icon: String = ""
var metadata: Dictionary = {}

# ── Editor parameter exposure ────────────────────────────────────────────────

## When true, this ACE's parameters can be surfaced in the Godot inspector.
## Inferred automatically by the generator for exported properties and
## primitive-typed methods.  Signals are not editor-exposed by default.
var editor_exposed: bool = false

## Optional PropertyHint constant (e.g. PROPERTY_HINT_RANGE) applied when the
## parameter is rendered in a custom inspector widget.
var property_hint: int = PROPERTY_HINT_NONE

## Companion string for property_hint (e.g. "0,100,1" for a range hint).
var hint_string: String = ""

## Optional widget hint tag for richer inspector rendering
## (e.g. "color", "file", "node_path").
var widget_hint: String = ""

## Override the category shown in the inspector panel for this ACE.
## When empty the regular category field is used.
var category_override: String = ""


## A full copy of this definition.
##
## Use this, NEVER `Resource.duplicate()`: every field above is a plain `var` rather than an
## `@export`, and duplicate() only copies exported properties - so it returns a BLANK
## definition (empty id, no template) that looks valid and silently publishes nothing. The
## fields are deliberately unexported (definitions are built in code, never edited as .tres),
## so this method is the supported way to derive one definition from another, e.g. when a
## refinement must not mutate the shared cached instance.
func copy() -> ACEDefinition:
	var clone: ACEDefinition = ACEDefinition.new()
	clone.provider_id = provider_id
	clone.id = id
	clone.display_name = display_name
	clone.category = category
	clone.ace_type = ace_type
	clone.description = description
	clone.parameters = parameters.duplicate(true)
	clone.return_type = return_type
	clone.icon = icon
	clone.metadata = metadata.duplicate(true)
	clone.editor_exposed = editor_exposed
	clone.property_hint = property_hint
	clone.hint_string = hint_string
	clone.widget_hint = widget_hint
	clone.category_override = category_override
	return clone


func get_identifier() -> String:
	return "%s::%s" % [provider_id, id]


func get_search_text() -> String:
	var tag_text: String = ""
	var tags: Variant = metadata.get("tags", [])
	if tags is Array and not (tags as Array).is_empty():
		var tag_parts: PackedStringArray = PackedStringArray()
		for tag in tags:
			tag_parts.append(str(tag))
		tag_text = " ".join(tag_parts)
	return "%s %s %s %s %s" % [display_name, category, description, str(metadata.get("source_name", "")), tag_text]


## Returns the category to display in the inspector (respects category_override).
func get_inspector_category() -> String:
	return category_override if not category_override.is_empty() else category


## The owned-instance call an instance-backed reflected METHOD compiles to
## (`__eventsheet_provider_<Class>.method({args})` - the compiler declares the member
## when it sees the reference). Empty for everything else: explicit templates win at
## bake, and non-method reflections carry synthesized templates from generation.
## THE single source for this form - the apply-time bake and the picker/expression
## previews all call it, so what the UI shows is exactly what gets baked.
func instance_backed_template() -> String:
	if not str(metadata.get("codegen_template", "")).strip_edges().is_empty():
		return ""
	if str(metadata.get("semantic_source", "")) != "reflection":
		return ""
	if str(metadata.get("source_kind", "")) != "method":
		return ""
	var method_name: String = str(metadata.get("source_name", ""))
	if method_name.is_empty() or provider_id.is_empty():
		return ""
	var argument_tokens: PackedStringArray = PackedStringArray()
	for parameter: Variant in parameters:
		if parameter is Dictionary and not str((parameter as Dictionary).get("id", "")).is_empty():
			argument_tokens.append("{%s}" % str((parameter as Dictionary).get("id", "")))
	return "__eventsheet_provider_%s.%s(%s)" % [provider_id, method_name, ", ".join(argument_tokens)]


func format_display(params_dict: Dictionary = {}) -> String:
	var template: String = str(metadata.get("display_template", display_name))
	if template.is_empty():
		return display_name
	var output: String = template
	for index: int in range(parameters.size()):
		var parameter: Variant = parameters[index]
		if not (parameter is Dictionary):
			continue
		var parameter_dict: Dictionary = parameter
		var key: String = str(parameter_dict.get("id", ""))
		if key.is_empty():
			continue
		var fallback: Variant = parameter_dict.get("default_value", parameter_dict.get("default", ""))
		var value: Variant = params_dict.get(key, fallback)
		var shown: String = display_value_for(parameter_dict, value)
		output = output.replace("{%d}" % index, shown)
		output = output.replace("{%s}" % key, shown)
	return output


## What a param's value should READ as in a row sentence. The identity for every ordinary param; a
## dropdown that declared display_option_labels shows the matching option's LABEL instead of the raw
## key it emits, so "the up/down part of velocity" never renders as `the "y" part of velocity`. A
## value matching no option falls through unchanged (an option removed after the row was authored).
## A param that declares a READING LENS is a different question and is answered on the canvas
## (see EventForgeValueLens): a lens is a derived reading rather than a second spelling of the value,
## so it is applied where the SENTENCE is drawn and never where a value is handed back.
## Static + pure so the viewport row builder, the picker preview and this method share ONE rule.
static func display_value_for(parameter_dict: Dictionary, value: Variant) -> String:
	var text: String = str(value)
	if not bool(parameter_dict.get("display_option_labels", false)):
		return text
	for option: Variant in parameter_dict.get("options", []):
		if option is Dictionary and str((option as Dictionary).get("key", "")) == text:
			return str((option as Dictionary).get("label", text))
	return text
