# EventForge - Shared descriptor factory for builtin/module ACE vocabularies.
#
# THE MODULE CONTRACT (see modules/): each vocabulary lives in its own file exposing
# `static func get_descriptors() -> Array[ACEDescriptor]`, built through this factory.
# EventForgeBuiltinACEs concatenates the modules. Why this shape:
#   - each "addon" (Audio, Keyboard, …) is one readable, documented file;
#   - a module can ship standalone (copy the file + factory into another project) or be
#     curated into packs without dragging the whole builtin list along;
#   - the compatibility covenant stays easy to audit: ace_ids and templates are grep-able
#     per module, and moving a descriptor between files never changes its identity.
@tool
class_name EventForgeACEFactory
extends RefCounted


## Builds a descriptor. Mirrors EventForgeBuiltinACEs._make_descriptor exactly (incl. the
## legacy alias fields) - ace_ids, templates and display text are API (compatibility
## covenant); the factory only changes where descriptors are AUTHORED, never what they bake.
static func make_descriptor(provider_id: String, ace_id: String, display_name: String, ace_type: int, codegen_template: String, signal_name: String = "", params: Array[ACEParam] = [], category: String = "", display_text: String = "", node_type: String = "") -> ACEDescriptor:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.provider_id = provider_id
	descriptor.ace_id = ace_id
	descriptor.display_name = display_name
	descriptor.list_name = display_name
	descriptor.display_text = display_text if not display_text.is_empty() else display_name
	descriptor.category = category
	descriptor.ace_type = ace_type
	descriptor.codegen_template = codegen_template
	descriptor.signal_name = signal_name
	descriptor.params = params
	descriptor.node_type = node_type
	descriptor.nodeType = node_type
	return descriptor


## Builds a parameter. `hint` selects the dialog field ("expression" = ƒx button,
## "key_capture" = press-a-key, "audio_path" = path + preview ▶, "color", …);
## `options` makes it a fixed dropdown; `autocomplete` makes it an editable suggest combo
## (type freely + filter/pick). Mirrors EventForgeBuiltinACEs._make_param exactly.
## `options` entries are either a plain value string (label == value) or a {"key": <inserted value>,
## "label": <shown text>} dict, so a dropdown can read "Warning" while inserting `push_warning`.
static func make_param(param_id: String, type_name: String, default_value: Variant = "", display_name: String = "", description: String = "", hint: String = "", options: Array = [], autocomplete: Array[String] = []) -> ACEParam:
	return ACEParam.of(param_id, type_name, default_value, display_name, description, hint, options, autocomplete)


## The name the whole builtin vocabulary publishes under. One constant, because it IS one provider:
## the makers below default to it, so no module types it again, and a module publishing under
## another name passes its own as the last argument.
const BUILTIN_PROVIDER: String = "Core"


## THE FOUR MAKERS - one call per KIND of row, so the kind is the method rather than a constant
## spelled out in the middle of an argument list, and what is left to write is what actually differs
## between two verbs. Each returns the descriptor, so the chained calls finish the row:
## `.param(...)` for a field, then `.featured()`, `.stateful(...)`, `.looping(...)`,
## `.succeeded_by(...)` exactly as before.
##
##   ace_id       the frozen key this verb is known by forever
##   label        the name the picker lists
##   template     the GDScript this row emits, with {param} slots
##   group        the shelf the picker files it under (make_descriptor's `category`)
##   reads_as     the sentence the row shows (make_descriptor's `display_text`); blank reads as label
##   description  the plain-language help, the same text `.described(...)` sets
##   host         the Godot class this row belongs to, when it belongs to one (`node_type`)
##   provider     who publishes it
##
## They COMPILE TO make_descriptor - same fields, same legacy aliases, descriptors indistinguishable
## from the ones the long form builds. make_descriptor stays forever, and is still the call for a
## descriptor whose kind is a variable rather than a word.
## An ACTION: a row that DOES something.
static func act(ace_id: String, label: String, template: String, group: String = "", reads_as: String = "", description: String = "", host: String = "", provider: String = BUILTIN_PROVIDER) -> ACEDescriptor:
	return _verb(provider, ace_id, label, ACEDescriptor.ACEType.ACTION, template, "", group, reads_as, description, host)


## A CONDITION: a row that asks a question the actions run behind.
static func cond(ace_id: String, label: String, template: String, group: String = "", reads_as: String = "", description: String = "", host: String = "", provider: String = BUILTIN_PROVIDER) -> ACEDescriptor:
	return _verb(provider, ace_id, label, ACEDescriptor.ACEType.CONDITION, template, "", group, reads_as, description, host)


## An EXPRESSION: a row that reads as a VALUE, dropped into any other row's field.
static func expr(ace_id: String, label: String, template: String, group: String = "", reads_as: String = "", description: String = "", host: String = "", provider: String = BUILTIN_PROVIDER) -> ACEDescriptor:
	return _verb(provider, ace_id, label, ACEDescriptor.ACEType.EXPRESSION, template, "", group, reads_as, description, host)


## A TRIGGER: a row the engine runs, rather than one the sheet asks. `signal_name` is the Godot
## signal it hangs off; a trigger that is a MOMENT OF THE PHYSICS STEP rather than a signal (landing,
## leaving the ground) leaves it blank. A trigger emits no expression of its own, which is why there
## is no template here.
static func trig(ace_id: String, label: String, signal_name: String, group: String = "", reads_as: String = "", description: String = "", host: String = "", provider: String = BUILTIN_PROVIDER) -> ACEDescriptor:
	return _verb(provider, ace_id, label, ACEDescriptor.ACEType.TRIGGER, "", signal_name, group, reads_as, description, host)


## The one body behind the four makers, so they differ in exactly the word that names them.
static func _verb(provider: String, ace_id: String, label: String, kind: ACEDescriptor.ACEType, template: String, signal_name: String, group: String, reads_as: String, description: String, host: String) -> ACEDescriptor:
	var descriptor: ACEDescriptor = make_descriptor(provider, ace_id, label, kind, template, signal_name, [] as Array[ACEParam], group, reads_as, host)
	descriptor.description = description
	return descriptor


## One class property's ENGINE default, as the literal a row starts on - asked of ClassDB rather than
## guessed, so a dropped row opens where Godot opens it and a reader never meets a number nobody
## chose. The one place any module asks the question, because the answer needs the care below.
##
## FLOATS ARE ROUNDED ON THE WAY OUT. Godot stores most of these properties as float32 and ClassDB
## hands the value back widened to a double, so printing it in full writes the widening into the
## user's script: `Environment.fog_density` is a hundredth and prints as `0.00999999977648`, and
## `glow_intensity` is three tenths and prints as `0.30000001192093`. A millionth is finer than any
## of these dials and coarse enough to land back on the literal the engine's own docs name.
static func default_literal(class_text: String, property: String) -> String:
	var value: Variant = ClassDB.class_get_property_default_value(class_text, property)
	# A property whose type is a Resource answers with a NULL OBJECT, and the text of a null object
	# is `<Object#null>` - which is not GDScript, so a row opening on it does not compile and an
	# expression falling back to it does not parse. The engine's own answer for such a property is
	# "nothing is set", and `null` is how that is written.
	if value == null:
		return "null"
	if value is Color:
		var colour: Color = value
		return "Color.WHITE" if colour == Color.WHITE else "Color(%s, %s, %s)" % [
			float_literal(colour.r), float_literal(colour.g), float_literal(colour.b)]
	if value is float:
		return float_literal(float(value))
	return str(value)


## One float as a row writes it: rounded to a millionth, which is what turns a float32 widened to a
## double back into the number a person would type.
static func float_literal(number: float) -> String:
	return str(snappedf(number, 0.000001))


## THE canonical comparison dropdown, labeled - every operator picker in the plugin resolves here:
## the builtin Compare Variable / Compare Values conditions, the `hint: comparison` provider
## shorthand, and any pack builder that calls comparison_options(). One list, so a wording change
## lands everywhere at once instead of drifting between copies.
##
## The label leads with the SYMBOL a reader sees on the row (≤ ≥ ≠, and `=` for equality, matching
## the sheet's own spelling), then says it in words. The GDScript form is the `key` and stays exactly
## as it was - it is what the template inserts and what the compiler emits - so a dialog showing this
## list shows that key muted beside the choice rather than baking it into the words.
const COMPARISON_OPTIONS: Array = [
	{"key": "==", "label": "=  equal to"},
	{"key": "!=", "label": "≠  not equal to"},
	{"key": "<", "label": "<  less than"},
	{"key": "<=", "label": "≤  at most"},
	{"key": ">", "label": ">  greater than"},
	{"key": ">=", "label": "≥  at least"}
]

## The same six as bare inserted tokens, for callers that only need the values.
const COMPARISON_OPERATORS: Array[String] = ["==", "!=", "<", "<=", ">", ">="]

## The glyph a ROW shows for each operator. `==` reads `=` because a sheet row is a question, not an
## assignment, so there is nothing for the doubled character to disambiguate. The two-character forms
## stay the truth everywhere else: templates insert the key, the compiler emits the key.
const COMPARISON_GLYPHS: Dictionary = {
	"==": "=", "!=": "≠", "<": "<", "<=": "≤", ">": ">", ">=": "≥"
}

## Each operator's clean opposite - the question that is true exactly when this one is false. A pair
## per line so the table reads as the six answers it is. Every one of the six HAS an opposite, which
## is what lets an inverted comparison say itself the short way (`hp > 0`) instead of wearing a
## `not (...)` a reader has to unwrap.
const COMPARISON_OPPOSITES: Dictionary = {
	"==": "!=", "!=": "==", "<": ">=", ">=": "<", "<=": ">", ">": "<="
}


## The row glyph for an operator token, or the text unchanged when it is not one of the six. Safe to
## call on any param value: only a value that IS an operator changes.
static func comparison_glyph(operator: String) -> String:
	return str(COMPARISON_GLYPHS.get(operator.strip_edges(), operator))


## The opposite of an operator token, or "" when the text is not one of the six.
static func opposite_operator(operator: String) -> String:
	return str(COMPARISON_OPPOSITES.get(operator.strip_edges(), ""))


## The param id holding the operator of a template that is EXACTLY one binary comparison - three
## slots, `{a} {op} {b}`, and nothing around them. "" for every other template, deliberately: a
## comparison buried in a larger expression (`absf({a} - {b}) <= {t}`, `Input.get_joy_axis(...) * 100
## {op} {v}`) is still cleanly invertible on paper, but claiming it here would flip operators inside
## expressions this table has never seen. The narrow shape is the one the sheet's own Compare rows
## use, and it is the one an inverted row can be rewritten as without changing anything else.
static func comparison_operator_param(template: String, params: Dictionary) -> String:
	var parts: PackedStringArray = template.strip_edges().split(" ")
	if parts.size() != 3:
		return ""
	for part: String in parts:
		if not (part.begins_with("{") and part.ends_with("}") and part.length() > 2):
			return ""
	var key: String = parts[1].substr(1, parts[1].length() - 2)
	return key if COMPARISON_OPERATORS.has(str(params.get(key, ""))) else ""


## This condition's params with the operator flipped to its opposite, or {} when the template is not
## the plain binary comparison above. ONE answer for the compiler (what to emit for an inverted row),
## the importer (what `not (...)` around a comparison lifts to) and the editor (what the row shows) -
## three readers that must never disagree about which rows flip.
static func flipped_comparison_params(template: String, params: Dictionary) -> Dictionary:
	var key: String = comparison_operator_param(template, params)
	if key.is_empty():
		return {}
	var flipped: Dictionary = params.duplicate(true)
	flipped[key] = opposite_operator(str(params[key]))
	return flipped


## The labeled comparison dropdown, with the equality token swapped for callers whose runtime
## matches on something other than `==`. A data-driven pack that stores the operator and compares
## it later (Storylet Weaver's requirement rows) uses a single `=`, and re-typing the whole list to
## change one character is how the copies drifted apart in the first place.
static func comparison_options(equal_token: String = "==") -> Array:
	var output: Array = []
	for option: Dictionary in COMPARISON_OPTIONS:
		var key: String = str(option["key"])
		output.append({"key": equal_token if key == "==" else key, "label": str(option["label"])})
	return output


## InputMap action names (project actions + the ui_* defaults), quoted for templates.
static func input_action_options() -> Array[String]:
	var options: Array[String] = []
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if property_name.begins_with("input/") and not property_name.contains("."):
			options.append("\"%s\"" % property_name.trim_prefix("input/"))
	for builtin: String in ["ui_accept", "ui_cancel", "ui_select", "ui_left", "ui_right", "ui_up", "ui_down"]:
		var quoted: String = "\"%s\"" % builtin
		if not options.has(quoted):
			options.append(quoted)
	return options


## First custom project action when one exists, else "ui_accept".
static func default_input_action() -> String:
	var options: Array[String] = input_action_options()
	return options[0] if not options.is_empty() else "\"ui_accept\""
