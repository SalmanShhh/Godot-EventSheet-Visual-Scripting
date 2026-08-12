# Godot EventSheets - the "types" vocabulary: questions a sheet asks ABOUT a value.
#
# Nine verbs in three families, all stateless, all authored in comparison_aces.gd:
#   - Text Is A Number / Text Is A Whole Number + Number From Text / Whole Number From Text.
#     The shipped Text To Int / Text To Float / To Integer / To Decimal all answer 0 for "abc",
#     for "" and for "0" alike, so a typo in an amount box arrives as a real-looking bet of
#     nothing. The checked pair asks first and lands on a fallback the author chose.
#   - Is Nothing / Has Something. One row for "is there anything there" whatever the value is,
#     where before it took four rows AND prior knowledge of the type.
#   - Contains Any Of / All Of / None Of. One row instead of an Or block of Text Contains.
#
# What is pinned, and why each pin exists:
#   - the EMITTED line for all nine, compiled through the real SheetCompiler, plus the proof that
#     the whole emitted script actually parses in its host;
#   - the RUNTIME behaviour of every shipped template, including the branches the descriptions
#     promise: the fallback on a typo, 0 surviving as a real value, an empty needle list, a
#     PackedStringArray from Split Text, and a non-text value that would crash an unwrapped read;
#   - that the frozen silent conversions were added BESIDE, not edited - their templates are
#     compatibility promises and this wave must not have touched them.
@tool
class_name TypesTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _test_registry_shape() and ok
	ok = _test_emitted_lines() and ok
	ok = _test_checked_conversion_runtime() and ok
	ok = _test_emptiness_runtime() and ok
	ok = _test_multi_needle_runtime() and ok
	return ok


## All nine are registered, in the kind and picker section the rows were designed around, and the
## silent conversions they sit beside are untouched.
static func _test_registry_shape() -> bool:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor

	var ok: bool = true
	var missing: Array[String] = []
	for ace_id: String in ["TextIsANumber", "TextIsAWholeNumber", "NumberFromText", "WholeNumberFromText",
			"IsNothing", "HasSomething", "ContainsAnyOf", "ContainsAllOf", "ContainsNoneOf"]:
		if not by_id.has(ace_id):
			missing.append(ace_id)
	ok = _check("all nine type verbs are registered", missing, [] as Array[String]) and ok
	if not missing.is_empty():
		return false

	# A condition branches, an expression fills a field. Getting this wrong makes the verb
	# unreachable from the row it was designed for, and nothing else would notice.
	var kinds: Array = []
	for ace_id: String in ["TextIsANumber", "TextIsAWholeNumber", "IsNothing", "HasSomething",
			"ContainsAnyOf", "ContainsAllOf", "ContainsNoneOf", "NumberFromText", "WholeNumberFromText"]:
		kinds.append(by_id[ace_id].ace_type)
	ok = _check("seven conditions, then the two conversions as expressions", kinds, [
		ACEDescriptor.ACEType.CONDITION, ACEDescriptor.ACEType.CONDITION,
		ACEDescriptor.ACEType.CONDITION, ACEDescriptor.ACEType.CONDITION,
		ACEDescriptor.ACEType.CONDITION, ACEDescriptor.ACEType.CONDITION,
		ACEDescriptor.ACEType.CONDITION,
		ACEDescriptor.ACEType.EXPRESSION, ACEDescriptor.ACEType.EXPRESSION]) and ok

	# The picker sections the mockup's click paths name. The conversions ship next to the silent
	# ones they replace, which is the whole point of where they landed.
	ok = _check("Text Is A Number sits with the text comparisons",
		str(by_id["TextIsANumber"].category), "Compare: Text") and ok
	ok = _check("the Contains family sits with the text comparisons too",
		[str(by_id["ContainsAnyOf"].category), str(by_id["ContainsAllOf"].category), str(by_id["ContainsNoneOf"].category)],
		["Compare: Text", "Compare: Text", "Compare: Text"]) and ok
	ok = _check("Is Nothing and Has Something sit with Value Is Of Type",
		[str(by_id["IsNothing"].category), str(by_id["HasSomething"].category)],
		["Compare: Types", "Compare: Types"]) and ok
	ok = _check("the checked conversions ship beside Text To Int / Text To Float",
		[str(by_id["NumberFromText"].category), str(by_id["WholeNumberFromText"].category)],
		["Variables: String", "Variables: String"]) and ok

	# Frozen API: the silent twins are a compatibility promise. This wave added beside them.
	ok = _check("Text To Int is untouched", str(by_id["StringToInt"].codegen_template), "{text}.to_int()") and ok
	ok = _check("Text To Float is untouched", str(by_id["StringToFloat"].codegen_template), "{text}.to_float()") and ok

	# Array(...) around the needle list is load-bearing, not decoration - see the runtime test.
	ok = _check("Contains Any Of wraps the needle list in Array()",
		str(by_id["ContainsAnyOf"].codegen_template).begins_with("Array({options}).any("), true) and ok
	ok = _check("Contains All Of asks all(), not any()",
		str(by_id["ContainsAllOf"].codegen_template).contains(".all("), true) and ok

	var undescribed: Array[String] = []
	for ace_id: String in ["TextIsANumber", "TextIsAWholeNumber", "NumberFromText", "WholeNumberFromText",
			"IsNothing", "HasSomething", "ContainsAnyOf", "ContainsAllOf", "ContainsNoneOf"]:
		if str(by_id[ace_id].description).strip_edges().is_empty():
			undescribed.append(ace_id)
	ok = _check("every new type verb explains itself", undescribed, [] as Array[String]) and ok
	return ok


## One sheet carrying all nine verbs, compiled by the real SheetCompiler. Pins the exact emitted
## line for each, then instantiates the result - so a template that produced plausible-looking but
## unparseable GDScript cannot pass on the substrings alone.
static func _test_emitted_lines() -> bool:
	var output: String = str(SheetCompiler.compile(_build_sheet(), "user://types_vocabulary_emit.gd").get("output", ""))
	var ok: bool = _check("the checked float condition emits is_valid_float on a str()-wrapped read",
		output.contains("if str(amount_text).strip_edges().is_valid_float():"), true)
	ok = _check("the checked int condition emits is_valid_int",
		output.contains("if str(amount_text).strip_edges().is_valid_int():"), true) and ok
	ok = _check("Number From Text emits the guarded read with the author's fallback",
		output.contains("bet = (str(amount_text).strip_edges().to_float() if str(amount_text).strip_edges().is_valid_float() else -1.0)"), true) and ok
	ok = _check("Whole Number From Text emits the int twin",
		output.contains("slot = (str(amount_text).strip_edges().to_int() if str(amount_text).strip_edges().is_valid_int() else -1)"), true) and ok
	ok = _check("Is Nothing emits the four-empties membership test plus the packed-list clause",
		output.contains("if (player_name in [null, \"\", [], {}] or (typeof(player_name) >= TYPE_PACKED_BYTE_ARRAY and not player_name)):"), true) and ok
	ok = _check("Has Something emits its exact negation",
		output.contains("if (not (player_name in [null, \"\", [], {}] or (typeof(player_name) >= TYPE_PACKED_BYTE_ARRAY and not player_name))):"), true) and ok
	ok = _check("Contains Any Of emits the Array-wrapped any() over the needles",
		output.contains("if Array(banned_words).any(func(__needle): return chat_line.contains(__needle)):"), true) and ok
	ok = _check("Contains All Of emits all() over a list written on the row",
		output.contains("if Array([\"Burn\", \"Chain\"]).all(func(__needle): return chat_line.contains(__needle)):"), true) and ok
	ok = _check("Contains None Of emits the negated any()",
		output.contains("if (not Array(banned_words).any(func(__needle): return chat_line.contains(__needle))):"), true) and ok

	# Parity: the emitted file is plain GDScript with no plugin runtime behind it.
	ok = _check("the emitted sheet names no plugin runtime", output.contains("eventforge"), false) and ok
	var node: Node = _instantiate(output)
	ok = _check("the whole emitted sheet parses and instantiates", node != null, true) and ok
	if node != null:
		node.free()
	return ok


## The failure branch is the point. Every claim in the two conversion descriptions is run for real:
## a typo lands on the author's fallback, a genuine "0" does NOT, and a value that came back out of
## a save as a number instead of text is read rather than crashing.
static func _test_checked_conversion_runtime() -> bool:
	var instance: RefCounted = _harness()
	if instance == null:
		return _check("the type-verb harness compiles", false, true)

	var ok: bool = _check("\"12\" is a number", instance.f_is_number("12"), true)
	ok = _check("\"12.5\" is a number", instance.f_is_number("12.5"), true) and ok
	ok = _check("\"-3.5\" is a number", instance.f_is_number("-3.5"), true) and ok
	ok = _check("spaces around it are ignored", instance.f_is_number("  7  "), true) and ok
	ok = _check("empty text is not a number", instance.f_is_number(""), false) and ok
	ok = _check("a typo is not a number", instance.f_is_number("abc"), false) and ok
	ok = _check("a half-typed amount is not a number", instance.f_is_number("12abc"), false) and ok
	# The str() wrapper earning its place: a save slot hands values back as whatever was written.
	ok = _check("a value that came back as a real number still answers yes", instance.f_is_number(12), true) and ok
	ok = _check("a missing value answers no instead of crashing", instance.f_is_number(null), false) and ok

	ok = _check("\"12\" is a whole number", instance.f_is_whole("12"), true) and ok
	ok = _check("\"12.5\" is NOT a whole number", instance.f_is_whole("12.5"), false) and ok
	ok = _check("\"-3\" is a whole number", instance.f_is_whole("-3"), true) and ok
	ok = _check("empty text is not a whole number", instance.f_is_whole(""), false) and ok
	ok = _check("spaces are ignored for whole numbers too", instance.f_is_whole(" 7 "), true) and ok

	ok = _check("a good amount reads as itself", instance.f_number_from("12", -1.0), 12.0) and ok
	ok = _check("a decimal amount keeps its decimals", instance.f_number_from("12.5", -1.0), 12.5) and ok
	ok = _check("a typo hands back the author's fallback, not 0", instance.f_number_from("abc", -1.0), -1.0) and ok
	ok = _check("an empty box hands back the fallback", instance.f_number_from("", -1.0), -1.0) and ok
	ok = _check("a padded amount still reads", instance.f_number_from("  8 ", -1.0), 8.0) and ok
	# THE distinction the silent conversions cannot make: a real zero is not a failure.
	ok = _check("a genuine \"0\" reads as 0, not as the fallback", instance.f_number_from("0", -1.0), 0.0) and ok
	ok = _check("the silent twin cannot tell those apart - it answers 0 for a typo too",
		"abc".to_float(), 0.0) and ok
	ok = _check("a missing value hands back the fallback", instance.f_number_from(null, -1.0), -1.0) and ok

	ok = _check("a good count reads as itself", instance.f_whole_from("12", -1), 12) and ok
	# Documented edge: it does not quietly truncate. The condition twin says "12.5" is not a whole
	# number, so the conversion must agree or the pair would contradict each other on the same row.
	ok = _check("\"12.5\" lands on the fallback rather than quietly becoming 12",
		instance.f_whole_from("12.5", -1), -1) and ok
	ok = _check("a typed count typo hands back the fallback", instance.f_whole_from("abc", -1), -1) and ok
	ok = _check("a genuine \"0\" count reads as 0", instance.f_whole_from("0", -1), 0) and ok
	return ok


## "A zero is NOT nothing" is the sentence on the row, so it is the assertion here.
static func _test_emptiness_runtime() -> bool:
	var instance: RefCounted = _harness()
	if instance == null:
		return _check("the type-verb harness compiles", false, true)

	var ok: bool = _check("no value at all is nothing", instance.f_is_nothing(null), true)
	ok = _check("empty text is nothing", instance.f_is_nothing(""), true) and ok
	ok = _check("an empty list is nothing", instance.f_is_nothing([]), true) and ok
	ok = _check("an empty record is nothing", instance.f_is_nothing({}), true) and ok
	# The promise the whole verb is shaped around.
	ok = _check("a score of 0 is a real value, not nothing", instance.f_is_nothing(0), false) and ok
	ok = _check("0.0 is a real value too", instance.f_is_nothing(0.0), false) and ok
	ok = _check("a switch that is off is a real value", instance.f_is_nothing(false), false) and ok
	ok = _check("text is not nothing", instance.f_is_nothing("hi"), false) and ok
	ok = _check("a list with an item is not nothing", instance.f_is_nothing([1]), false) and ok
	ok = _check("a record with a key is not nothing", instance.f_is_nothing({"a": 1}), false) and ok
	# Spaces are a separate question, and Text Is Blank is the row that asks it.
	ok = _check("text made only of spaces is not nothing (that is Text Is Blank)",
		instance.f_is_nothing("   "), false) and ok

	ok = _check("nothing there means Has Something is false", instance.f_has_something(null), false) and ok
	ok = _check("an empty name box means Has Something is false", instance.f_has_something(""), false) and ok
	ok = _check("an empty inventory means Has Something is false", instance.f_has_something([]), false) and ok
	ok = _check("a filled name box means Has Something is true", instance.f_has_something("Ada"), true) and ok
	ok = _check("an inventory with an item means Has Something is true", instance.f_has_something([1]), true) and ok
	ok = _check("a score of 0 still counts as something", instance.f_has_something(0), true) and ok

	# Split Text hands back a PackedStringArray, and an empty one does NOT equal an empty Array - so
	# without the packed clause the single most natural way a sheet makes a list read as "there is
	# something" when it was empty, and the guard took the wrong branch. Asserted for BOTH verbs.
	ok = _check("an empty Split Text result is nothing", instance.f_is_nothing("".split(",", false)), true) and ok
	ok = _check("a filled Split Text result is not nothing", instance.f_is_nothing("a,b".split(",")), false) and ok
	ok = _check("an empty Split Text result means Has Something is false",
		instance.f_has_something("".split(",", false)), false) and ok
	ok = _check("a filled Split Text result means Has Something is true",
		instance.f_has_something("a,b".split(",")), true) and ok
	ok = _check("an empty list of bytes is nothing too", instance.f_is_nothing(PackedByteArray()), true) and ok
	ok = _check("a filled list of bytes is not", instance.f_is_nothing(PackedByteArray([7])), false) and ok
	# And the packed clause must not swallow the values Is Nothing exists to PROTECT.
	ok = _check("the packed clause still keeps a 0 a real value", instance.f_is_nothing(0), false) and ok
	ok = _check("and still keeps a false a real value", instance.f_is_nothing(false), false) and ok
	return ok


## The three-needle family, including both empty-list edges and the PackedStringArray the Array()
## wrapper exists for.
static func _test_multi_needle_runtime() -> bool:
	var instance: RefCounted = _harness()
	if instance == null:
		return _check("the type-verb harness compiles", false, true)

	var ok: bool = _check("any of: one needle hits", instance.f_any("fire sword", ["fire", "ice"]), true)
	ok = _check("any of: no needle hits", instance.f_any("wood sword", ["fire", "ice"]), false) and ok
	ok = _check("any of: an empty list is never a match", instance.f_any("fire sword", []), false) and ok
	ok = _check("any of: matching is case-sensitive", instance.f_any("Fire sword", ["fire"]), false) and ok

	ok = _check("all of: every needle hits", instance.f_all("Burn and Chain", ["Burn", "Chain"]), true) and ok
	ok = _check("all of: one needle missing fails the row", instance.f_all("Burn only", ["Burn", "Chain"]), false) and ok
	ok = _check("all of: an empty list passes, because nothing is missing",
		instance.f_all("anything at all", []), true) and ok

	ok = _check("none of: a clean name passes", instance.f_none("Ada", ["damn", "heck"]), true) and ok
	ok = _check("none of: a dirty name fails", instance.f_none("hecklerAda", ["damn", "heck"]), false) and ok
	ok = _check("none of: an empty list always passes", instance.f_none("anything", []), true) and ok

	# Array(...) is load-bearing: Split Text hands back a PackedStringArray, which has no any()/all()
	# at all, so the unwrapped template would fail on the single most natural way to build the list.
	# The two "Cannot find member any in base PackedStringArray" lines this prints are the PROOF,
	# deliberately provoked - they are not a failure of this suite.
	var unwrapped: GDScript = GDScript.new()
	unwrapped.source_code = "@tool\nextends RefCounted\nfunc f(options: PackedStringArray) -> bool:\n\treturn options.any(func(n): return n == \"a\")\n"
	ok = _check("an unwrapped {options}.any(...) does not even compile on a Split Text result",
		unwrapped.reload() != OK, true) and ok
	ok = _check("a Split Text result still works, because the template wraps it in Array()",
		instance.f_any("fire sword", "fire,ice".split(",")), true) and ok
	ok = _check("all of works on a Split Text result too",
		instance.f_all("fire and ice", "fire,ice".split(",")), true) and ok
	return ok


## `<Node> / vars / _process:` one event row per verb, each carrying the REAL registered template
## with the row's values substituted through the real codegen - exactly what the dock bakes on apply.
static func _build_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("amount_text", "String", "12"))
	sheet.events.append(_variable("player_name", "String", ""))
	sheet.events.append(_variable("chat_line", "String", ""))
	sheet.events.append(_variable("banned_words", "Array", []))
	sheet.events.append(_variable("bet", "float", 0.0))
	sheet.events.append(_variable("slot", "int", 0))
	sheet.events.append(_variable("blocked", "bool", false))

	sheet.events.append(_event(_condition("TextIsANumber", {"text": "amount_text"}),
		_action("SetVar", {"var_name": "bet", "value": _expression("NumberFromText", {"text": "amount_text", "fallback": "-1.0"})})))
	sheet.events.append(_event(_condition("TextIsAWholeNumber", {"text": "amount_text"}),
		_action("SetVar", {"var_name": "slot", "value": _expression("WholeNumberFromText", {"text": "amount_text", "fallback": "-1"})})))
	sheet.events.append(_event(_condition("IsNothing", {"value": "player_name"}), _raw_action("blocked = true")))
	sheet.events.append(_event(_condition("HasSomething", {"value": "player_name"}), _raw_action("blocked = false")))
	sheet.events.append(_event(_condition("ContainsAnyOf", {"text": "chat_line", "options": "banned_words"}), _raw_action("blocked = true")))
	sheet.events.append(_event(_condition("ContainsAllOf", {"text": "chat_line", "options": "[\"Burn\", \"Chain\"]"}), _raw_action("blocked = true")))
	sheet.events.append(_event(_condition("ContainsNoneOf", {"text": "chat_line", "options": "banned_words"}), _raw_action("blocked = false")))
	return sheet


static func _event(condition: ACECondition, action: ACEAction) -> EventRow:
	# A bare EventRow without a trigger_id emits nothing at all, so every row names one.
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(condition)
	row.actions.append(action)
	return row


static func _variable(variable_name: String, type_name: String, default_value: Variant) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = default_value
	return variable


static func _condition(ace_id: String, values: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.codegen_template = _expression(ace_id, values)
	return condition


static func _action(ace_id: String, values: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = _expression(ace_id, values)
	return action


static func _raw_action(statement: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawCode"
	action.codegen_template = statement
	return action


## The SHIPPED template for an ace, substituted through the real single-pass codegen.
static func _expression(ace_id: String, values: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return ""
	return ActionCodegen._apply_template(str(descriptor.codegen_template), values)


## A script whose bodies ARE the shipped templates, so the runtime checks below exercise the real
## vocabulary rather than a restatement of it. Params stay untyped on purpose: these verbs are
## pointed at values whose type nobody knows yet, which is the whole reason they exist.
static func _harness() -> RefCounted:
	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func f_is_number(text) -> bool:",
		"\treturn %s" % _expression("TextIsANumber", {"text": "text"}),
		"func f_is_whole(text) -> bool:",
		"\treturn %s" % _expression("TextIsAWholeNumber", {"text": "text"}),
		"func f_number_from(text, fallback: float) -> float:",
		"\treturn %s" % _expression("NumberFromText", {"text": "text", "fallback": "fallback"}),
		"func f_whole_from(text, fallback: int) -> int:",
		"\treturn %s" % _expression("WholeNumberFromText", {"text": "text", "fallback": "fallback"}),
		"func f_is_nothing(value) -> bool:",
		"\treturn %s" % _expression("IsNothing", {"value": "value"}),
		"func f_has_something(value) -> bool:",
		"\treturn %s" % _expression("HasSomething", {"value": "value"}),
		"func f_any(text, options) -> bool:",
		"\treturn %s" % _expression("ContainsAnyOf", {"text": "text", "options": "options"}),
		"func f_all(text, options) -> bool:",
		"\treturn %s" % _expression("ContainsAllOf", {"text": "text", "options": "options"}),
		"func f_none(text, options) -> bool:",
		"\treturn %s" % _expression("ContainsNoneOf", {"text": "text", "options": "options"}),
		"",
	])  # NOTE the trailing "": a single-line lambda needs a terminating newline, so a script whose
		# LAST line is one fails to parse. Real compiler output always has that newline.
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  the template harness failed to reload:\n%s" % source)
		return null
	return script.new()


static func _instantiate(source: String) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  the compiled sheet failed to reload:\n%s" % source)
		return null
	var node: Node = Node.new()
	node.set_script(script)
	return node


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] types_test: %s" % label)
		return true
	print("[FAIL] types_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
