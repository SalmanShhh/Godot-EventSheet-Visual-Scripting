# EventSheet - "this raw call looks like one of your verbs". The lifter is
# deliberately NOT involved: attribution is a user act, offered here and applied through the
# ordinary path. So the bar for the matcher is the same as every advisory in this plugin -
# exactly one candidate or silence - and the must-NOT-suggest cases are pinned as hard as the
# matches.
@tool
class_name VerbSuggestionTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The target expression -> class name ──
	ok = _check("a behaviour node names its class",
		EventSheetVerbSuggestion.class_from_target("$Inventory"), "Inventory") and ok
	ok = _check("a nested path names its LAST segment",
		EventSheetVerbSuggestion.class_from_target("$Player/Inventory"), "Inventory") and ok
	ok = _check("a unique-name node resolves",
		EventSheetVerbSuggestion.class_from_target("%Inventory"), "Inventory") and ok
	ok = _check("a bare autoload name resolves",
		EventSheetVerbSuggestion.class_from_target("Inventory"), "Inventory") and ok
	# Must NOT guess through anything computed - a wrong class means a wrong verb.
	ok = _check("a call expression names nothing",
		EventSheetVerbSuggestion.class_from_target("get_node(\"Inventory\")"), "") and ok
	ok = _check("an indexed expression names nothing",
		EventSheetVerbSuggestion.class_from_target("bags[0]"), "") and ok
	ok = _check("a lowercase variable is not a class",
		EventSheetVerbSuggestion.class_from_target("inventory"), "") and ok
	ok = _check("empty names nothing", EventSheetVerbSuggestion.class_from_target("  "), "") and ok

	# ── Argument splitting: top level only ──
	ok = _check("plain arguments split",
		EventSheetVerbSuggestion.split_arguments("\"potion\", 3"),
		PackedStringArray(["\"potion\"", "3"])) and ok
	ok = _check("a comma INSIDE a string is not a separator",
		EventSheetVerbSuggestion.split_arguments("\"a, b\", 3"),
		PackedStringArray(["\"a, b\"", "3"])) and ok
	ok = _check("a comma inside a call is not a separator",
		EventSheetVerbSuggestion.split_arguments("Vector2(1, 2), true"),
		PackedStringArray(["Vector2(1, 2)", "true"])) and ok
	ok = _check("a comma inside an array is not a separator",
		EventSheetVerbSuggestion.split_arguments("[3, 4], \"x\""),
		PackedStringArray(["[3, 4]", "\"x\""])) and ok
	ok = _check("no arguments yields none",
		EventSheetVerbSuggestion.split_arguments("   ").size(), 0) and ok

	# ── The suggestion itself ──
	var add_item: ACEDefinition = _definition("Inventory", "method:add_item", "Add Item", ["item_id", "count"])
	var heal: ACEDefinition = _definition("Inventory", "method:heal", "Heal", ["amount"])
	var vocabulary: Array = [add_item, heal]

	var hit: Dictionary = EventSheetVerbSuggestion.suggest("$Inventory", "add_item", "\"potion\", 3", vocabulary)
	ok = _check("a matching call is named", str(hit.get("display_name", "")), "Add Item") and ok
	ok = _check("and carries its verb id", str(hit.get("ace_id", "")), "method:add_item") and ok
	ok = _check("and the split arguments ride along",
		hit.get("arguments"), PackedStringArray(["\"potion\"", "3"])) and ok

	# Must NOT suggest.
	ok = _check("a method the class does not have suggests nothing",
		EventSheetVerbSuggestion.suggest("$Inventory", "explode", "", vocabulary), {}) and ok
	ok = _check("a different class suggests nothing",
		EventSheetVerbSuggestion.suggest("$Wallet", "add_item", "\"potion\", 3", vocabulary), {}) and ok
	# Arity disagreement is the dangerous case: converting would drop or invent an argument.
	ok = _check("too few arguments suggests nothing",
		EventSheetVerbSuggestion.suggest("$Inventory", "add_item", "\"potion\"", vocabulary), {}) and ok
	ok = _check("too many arguments suggests nothing",
		EventSheetVerbSuggestion.suggest("$Inventory", "add_item", "\"potion\", 3, 4", vocabulary), {}) and ok
	# Two verbs with the same id and arity: the tool does not know which, so it says nothing.
	var twin: ACEDefinition = _definition("Inventory", "method:add_item", "Stash Item", ["item_id", "count"])
	ok = _check("an ambiguous match suggests nothing",
		EventSheetVerbSuggestion.suggest("$Inventory", "add_item", "\"potion\", 3", [add_item, twin]), {}) and ok

	# ── Parameter mapping for the conversion ──
	var mapped: Dictionary = EventSheetVerbSuggestion.mapped_params(add_item, PackedStringArray(["\"potion\"", "3"]))
	ok = _check("arguments map onto the verb's own parameter ids",
		mapped, {"item_id": "\"potion\"", "count": "3"}) and ok
	ok = _check("a count mismatch maps nothing",
		EventSheetVerbSuggestion.mapped_params(add_item, PackedStringArray(["\"potion\""])), {}) and ok
	ok = _check("a no-parameter verb maps empty",
		EventSheetVerbSuggestion.mapped_params(_definition("Inventory", "method:clear", "Clear", []),
			PackedStringArray()), {}) and ok

	# ── The dock path: only a raw Call Method is ever a candidate ──
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	var not_a_call: ACEAction = ACEAction.new()
	not_a_call.provider_id = "Core"
	not_a_call.ace_id = "PlaySound"
	not_a_call.params = {"path": "\"res://x.ogg\""}
	ok = _check("a normal verb is never offered a conversion",
		editor.suggested_verb_for_action(not_a_call), {}) and ok
	ok = _check("a null action is handled", editor.suggested_verb_for_action(null), {}) and ok
	var unknown_class: ACEAction = ACEAction.new()
	unknown_class.provider_id = "Core"
	unknown_class.ace_id = "CallMethod"
	unknown_class.params = {"target": "$NotAProjectClass", "method": "whatever", "args": ""}
	ok = _check("a call on a class this project does not have suggests nothing",
		editor.suggested_verb_for_action(unknown_class), {}) and ok
	editor.free()
	return ok


static func _definition(provider: String, ace_id: String, display: String, param_ids: Array) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = provider
	definition.id = ace_id
	definition.display_name = display
	definition.ace_type = ACEDefinition.ACEType.ACTION
	var parameters: Array = []
	for id: Variant in param_ids:
		parameters.append({"id": str(id), "display_name": str(id).capitalize(), "type": TYPE_STRING,
			"default_value": "", "hint": "expression", "options": [], "autocomplete": []})
	definition.parameters = parameters
	definition.metadata = {"codegen_template": "{target.}%s()" % ace_id.trim_prefix("method:"), "reflected": true}
	return definition


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] verb_suggestion_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
