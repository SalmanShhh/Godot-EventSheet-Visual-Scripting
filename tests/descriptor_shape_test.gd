# Godot EventSheets - every published row, held to the shape a row has to have.
#
# A descriptor is a promise made in five places at once: the template says what GDScript the row
# writes, the sentence says what the row reads as, the parameters say what the dialog asks for, and
# the host class says what the row can be dropped on. Nothing had been checking that those five
# agree. The compile gate beside this one proves the TEMPLATE parses; it cannot notice a sentence
# that mentions a parameter nobody has, a `{slot}` no parameter fills, a dropdown with one item
# repeated, or a host class the engine has never heard of.
#
# So this walks every registered descriptor once and asks the questions a reader would:
#
#   1. Every `{slot}` in the template and in the sentence is a parameter of that row.
#   2. Every parameter is used - by the template, or by the sentence, or by both.
#   3. A dropdown has items, and no item twice.
#   4. A parameter has a default, so a row dropped from the picker is a working row.
#   5. A host class is a class the engine knows.
#
# WHAT IS ALLOWED THROUGH, and why each shape is legitimate rather than an exception somebody wanted:
# four short lists below, each with its reason - EXEMPT_SLOTS (slots the emitter fills),
# PARAMS_THE_ROW_CARRIES (what a row acts on), EMPTY_IS_AN_ANSWER (a blank that means something) and
# PICKED_FROM_THE_PROJECT / PICKED_BY_NAME (a name only this project can supply). They are meant to
# stay short: an entry is a claim that a shape is correct, not a way of quietening a finding.
@tool
class_name DescriptorShapeTest
extends RefCounted

## The shared pin helper: one failure line, whatever failed.
const Pins := preload("res://tests/pin_table.gd")

## Slots that are filled by the EMITTER rather than by a parameter, so a template carrying one is
## complete without a parameter of that name:
##   {uid}      a stable per-row id the dock bakes in at apply time;
##   {target.}  the optional receiver prefix a node-scoped row wears (the dot lives inside the
##              braces so clearing the field emits the bare member operation);
##   {host.}    the same idea for a behaviour's host object;
##   {n}        the loop iterator a looping condition binds.
const EXEMPT_SLOTS: Array[String] = ["uid", "target.", "host.", "n", "0", "1", "2", "3"]

## Parameters a row CARRIES rather than writes: they steer the editor rather than the emitted line,
## so neither the template nor the sentence names them.
##   target / host    which object the row acts on - the object column shows it, not the sentence;
##   comparison       the operator a comparison row keeps beside its two values in some templates;
##   is_deprecated    routing only.
const PARAMS_THE_ROW_CARRIES: Array[String] = ["target", "host", "on_node"]

## A slot is `{name}`; a receiver slot is `{name.}` (the dot inside the braces, so clearing the field
## emits the bare member operation); and an optional trailing argument is `{, name}` (the comma
## inside the braces, so an empty value emits nothing rather than a dangling comma). One pattern
## reads all three, which is the point - a rule that knew only the first reported the third as a
## parameter nothing uses.
const SLOT_PATTERN: String = "\\{,?[ \\t]*([A-Za-z_][A-Za-z0-9_]*\\.?)\\}"

## Parameters whose EMPTY value is a real answer rather than a missing one:
##   args     no arguments at all - `f()` is as valid a call as `f(1)`;
##   prompt   the optional label a timed input window shows, off when it is blank.
const EMPTY_IS_AN_ANSWER: Array[String] = ["args", "prompt"]

## Hints that mean "name something in the author's own project". No default can be right for one of
## these - a group, a variable, a node or an input action that this project happens to have is a
## guess, and the picker is what fills them in.
const PICKED_FROM_THE_PROJECT: Array[String] = ["group_reference", "variable_reference",
	"scene_node", "input_action", "function_reference", "signal_reference", "sheet_function"]

## The same idea, for the one parameter that carries no hint saying so: the function a Call row
## calls is a function of THIS sheet, and the picker is what lists them. A default would name a
## function the sheet does not have, which is worse than an empty field the dialog fills in.
const PICKED_BY_NAME: Array[String] = ["function_name"]


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_reader_can_fail() and ok
	ok = _test_every_published_row_holds_its_shape() and ok
	return ok


## The detector, before the sweep: each rule is shown a descriptor that breaks it, so a rule that
## has stopped working cannot report a clean vocabulary.
static func _test_the_reader_can_fail() -> bool:
	var ok: bool = true
	ok = Pins.check("descriptor_shape_test", {
		"a slot no parameter fills": _problems_of(_probe("{missing} = 1", "set it", [])).size() > 0,
		"a sentence naming a parameter nobody has": _problems_of(
			_probe("x = 1", "set x to {nope}", [])).size() > 0,
		"a parameter nothing uses": _problems_of(
			_probe("x = 1", "set x", [_param("stray", "1", [])])).size() > 0,
		"a dropdown with one item twice": _problems_of(
			_probe("x = {v}", "set x to {v}", [_param("v", "a", ["a", "a"])])).size() > 0,
		"a parameter with no default": _problems_of(
			_probe("x = {v}", "set x to {v}", [_param("v", "", [])])).size() > 0,
		"a sound row is left alone": _problems_of(
			_probe("x = {v}", "set x to {v}", [_param("v", "1", [])])).size() > 0,
	}, func(key: String) -> Variant:
		return key != "a sound row is left alone") and ok
	return ok


## The sweep. Every registered descriptor, every rule, and the problems named one per line so a
## failure says which row and which promise rather than "some descriptor is wrong".
static func _test_every_published_row_holds_its_shape() -> bool:
	var descriptors: Array[ACEDescriptor] = ACERegistry.get_all_descriptors()
	var problems: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in descriptors:
		for problem: String in _problems_of(descriptor):
			problems.append("%s/%s: %s" % [descriptor.provider_id, descriptor.ace_id, problem])
	for problem: String in problems:
		print("  descriptor: %s" % problem)
	var ok: bool = Pins.check_value("descriptor_shape_test",
		"the sweep reads the whole vocabulary", descriptors.size() > 500, true)
	return Pins.check_value("descriptor_shape_test",
		"every published row's template, sentence, parameters and host agree (%d rows)"
		% descriptors.size(), problems.size(), 0) and ok


## Everything wrong with one descriptor, as sentences. Empty when it is sound - and pure, so the
## rules above are provable without a registry.
static func _problems_of(descriptor: ACEDescriptor) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var names: Dictionary = {}
	for param: ACEParam in descriptor.params:
		var id: String = param.id if not param.id.is_empty() else param.name
		if id.is_empty():
			problems.append("a parameter has no id")
			continue
		if names.has(id):
			problems.append("two parameters are called %s" % id)
		names[id] = param
		# A TRIGGER's parameters are what the signal HANDS the sheet - the body that entered, the
		# peer that joined - so they are named rather than filled in, and have no default to have.
		problems.append_array(_problems_of_param(id, param,
			descriptor.ace_type != ACEDescriptor.ACEType.TRIGGER))
	var template_slots: PackedStringArray = _slots_in(descriptor.codegen_template
		+ "\n" + descriptor.member_template + "\n" + descriptor.codegen_prelude
		+ "\n" + descriptor.codegen_on_true + "\n" + descriptor.codegen_on_exit)
	var sentence_slots: PackedStringArray = _slots_in(descriptor.display_text)
	for slot: String in template_slots:
		if not names.has(slot) and not EXEMPT_SLOTS.has(slot):
			problems.append("the code says {%s}, and no parameter fills it" % slot)
	for slot: String in sentence_slots:
		if not names.has(slot) and not EXEMPT_SLOTS.has(slot):
			problems.append("the sentence says {%s}, and no parameter fills it" % slot)
	# A trigger writes no template of its own - the emitter builds its handler from the descriptor
	# directly - so a parameter of one is read rather than substituted, and "nothing uses it" is a
	# question only a row with a template can be asked.
	var writes_a_line: bool = not descriptor.codegen_template.strip_edges().is_empty()
	for id: String in names.keys():
		if template_slots.has(id) or sentence_slots.has(id) or PARAMS_THE_ROW_CARRIES.has(id):
			continue
		if template_slots.has(id + ".") or sentence_slots.has(id + ".") or not writes_a_line:
			continue
		problems.append("the dialog asks for %s, and neither the code nor the sentence uses it" % id)
	if not descriptor.node_type.is_empty() and not ClassDB.class_exists(descriptor.node_type) \
			and not ResourceLoader.exists(descriptor.node_type):
		problems.append("it is hosted on %s, which is not a class the engine knows"
			% descriptor.node_type)
	return problems


## Everything wrong with one parameter of a descriptor.
static func _problems_of_param(id: String, param: ACEParam, wants_default: bool) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for option: Variant in param.options:
		var key: String = str((option as Dictionary).get("key", "")) if option is Dictionary else str(option)
		if seen.has(key):
			problems.append("%s offers %s twice" % [id, key])
		seen[key] = true
	if not param.options.is_empty() and seen.is_empty():
		problems.append("%s has a dropdown with nothing in it" % id)
	if wants_default and str(param.default_value).strip_edges().is_empty() \
			and param.type_name != "bool" and param.type_name != "boolean" \
			and param.options.is_empty() and not PARAMS_THE_ROW_CARRIES.has(id) \
			and not EMPTY_IS_AN_ANSWER.has(id) and not PICKED_BY_NAME.has(id) \
			and not PICKED_FROM_THE_PROJECT.has(param.hint):
		problems.append("%s has no default, so the row it drops in is incomplete" % id)
	return problems


## The `{slot}` names in a text, without repeats.
static func _slots_in(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pattern: RegEx = RegEx.create_from_string(SLOT_PATTERN)
	if pattern == null:
		return found
	for hit: RegExMatch in pattern.search_all(text):
		var name: String = hit.get_string(1)
		if not found.has(name):
			found.append(name)
	return found


# ── stand-ins, for proving the rules ──────────────────────────────────────────


static func _probe(template: String, sentence: String, params: Array[ACEParam]) -> ACEDescriptor:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.provider_id = "Probe"
	descriptor.ace_id = "Probe"
	descriptor.codegen_template = template
	descriptor.display_text = sentence
	descriptor.params = params
	return descriptor


static func _param(id: String, default_value: String, options: Array) -> ACEParam:
	var param: ACEParam = ACEParam.new()
	param.id = id
	param.default_value = default_value
	param.options = options
	return param
