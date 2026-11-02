@tool
class_name TypeCheckTest
extends RefCounted

# The kind-of-value check: a typed field is compiled inside a stand-in script that carries the sheet's
# declared types, and Godot's own analyzer judges it. Pinned here: the analyzer's wording on this engine
# (every plain sentence is keyed on a message produced by a real reload), what is refused and what is
# said, that every ordinary valid shape stays accepted, the underline spans, the one-click rewrites,
# the dialog's commit gate and the stand-in's fall-back when a type cannot be written.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "type_check_test"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _wording_is_what_this_engine_says() and all_passed
	all_passed = _wrong_kinds_are_refused_in_plain_words() and all_passed
	all_passed = _valid_shapes_stay_accepted() and all_passed
	all_passed = _cannot_tell_is_a_note_not_an_error() and all_passed
	all_passed = _spans_and_rewrites() and all_passed
	all_passed = _unknown_types_fall_back_to_untyped() and all_passed
	all_passed = _scene_nodes_are_typed_and_checked() and all_passed
	all_passed = _the_dialog_gate_refuses_and_says_why() and all_passed
	all_passed = _a_message_without_a_plain_form_is_left_to_the_compile_check() and all_passed
	all_passed = _no_false_refusals_around_scene_nodes() and all_passed
	all_passed = _self_is_said_by_its_class_and_a_foreign_host_says_nothing() and all_passed
	all_passed = _the_scene_that_judges_is_the_one_that_runs_the_sheet() and all_passed
	return all_passed


## A sheet that declares what the board's examples use, with a mix of tidy and awkward types.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {
		"score": {"type": "int", "default": 0},
		"player_name": {"type": "String", "default": "Ada"},
		"speed": {"type": "float", "default": 220.0},
		"tint": {"type": "Color", "default": Color.WHITE},
		"spawn": {"type": "Vector2", "default": Vector2.ZERO},
		"target_node": {"type": "Node2D", "default": null},
		"label_id": {"type": "StringName", "default": "x"},
		"ids": {"type": "Array[int]", "default": []},
		"mystery": {"type": "NotAType", "default": null},
	}
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	heal.params.append(_param("amount", "int"))
	heal.return_type = TYPE_NIL
	sheet.functions.append(heal)
	var describe: EventFunction = EventFunction.new()
	describe.function_name = "describe"
	describe.params.append(_param("label", "String"))
	var count: ACEParam = _param("count", "int")
	count.gdscript_default = "2"
	describe.params.append(count)
	describe.return_type_name = "String"
	sheet.functions.append(describe)
	var ratio: EventFunction = EventFunction.new()
	ratio.function_name = "ratio"
	ratio.return_type_name = "float"
	sheet.functions.append(ratio)
	var table: EventFunction = EventFunction.new()
	table.function_name = "table"
	table.return_type_name = "Dictionary"
	sheet.functions.append(table)
	return sheet


static func _param(id: String, type_name: String) -> ACEParam:
	var param: ACEParam = ACEParam.new()
	param.id = id
	param.type_name = type_name
	return param


const SET_VAR := "{var_name} = {value}"
const COMPARE_VAR := "{var_name} {op} {value}"
const CALL_FUNCTION := "{function_name}({args})"


## What the check says for one field: [level, head] (["", ""] when it says nothing).
static func _says(template: String, param_id: String, value: String, others: Dictionary,
		scene_root: Node = null) -> Array:
	var values: Dictionary = others.duplicate()
	values[param_id] = value
	var finding: Dictionary = EventSheetTypeCheck.check_field(template, param_id, value, values, _sheet(),
		PackedStringArray(["delta", "other"]), scene_root)
	return [str(finding.get("level", "")), str(finding.get("head", ""))]


## Every sentence in the plain-words table is keyed on a message this engine really prints: each source
## below is reloaded and the message it makes must be read by the table as the kind it is meant to be.
static func _wording_is_what_this_engine_says() -> bool:
	var probes: Array = [
		["assign", "extends Node\nvar score: int\nfunc f() -> void:\n\tscore = \"ten\"\n\tpass"],
		["operands", "extends Node\nvar s: String\nfunc f() -> void:\n\tvar x = (s == 3)\n\tpass"],
		["many", "extends Node\nfunc heal(amount: int) -> void: pass\nfunc f() -> void:\n\theal(10, 2)\n\tpass"],
		["few", "extends Node\nfunc heal(amount: int) -> void: pass\nfunc f() -> void:\n\theal()\n\tpass"],
		["argument", "extends Node\nfunc heal(amount: int) -> void: pass\nfunc f() -> void:\n\theal(\"lots\")\n\tpass"],
		["member", "extends Node\nfunc f() -> void:\n\tvar v: Vector2\n\tvar x = v.zz\n\tpass"],
	]
	var rows: Array = []
	for entry: Array in probes:
		var run: Dictionary = EventSheetTypeCheck.run_probe(str(entry[1]))
		var texts: Array = []
		for message: Dictionary in run["messages"]:
			texts.append(str(message["text"]))
		var lead: String = EventSheetTypeWords.lead_message(texts)
		rows.append(["%s fails to load" % entry[0], bool(run["ok"]), false])
		rows.append(["%s is read by the table as %s" % [entry[0], entry[0]], str(EventSheetTypeWords.recognise(lead).get("id", "")), str(entry[0])])
	return SUPPORT.pins(NAME + ": wording", rows)


static func _wrong_kinds_are_refused_in_plain_words() -> bool:
	var rows: Array = [
		["text in a number slot", _says(SET_VAR, "value", "\"ten\"", {"var_name": "score"}), ["error", "score holds a whole number."]],
		["a text variable in a number slot", _says(SET_VAR, "value", "player_name", {"var_name": "score"}), ["error", "score holds a whole number."]],
		["a number into a text variable", _says(SET_VAR, "value", "score", {"var_name": "player_name"}), ["error", "player_name holds text."]],
		["a number compared with a text variable", _says(COMPARE_VAR, "value", "3", {"var_name": "player_name", "op": "=="}), ["error", "player_name is text."]],
		["too many values to a sheet function", _says(CALL_FUNCTION, "args", "10, 2", {"function_name": "heal"}), ["error", "heal takes 1 value(s) (amount: int)."]],
		["too few values to a sheet function", _says(CALL_FUNCTION, "args", "", {"function_name": "describe"}), ["", ""]],
		["text for a whole number argument", _says(CALL_FUNCTION, "args", "\"lots\"", {"function_name": "heal"}), ["error", "heal's amount is a whole number."]],
		["the second argument is the wrong kind", _says(CALL_FUNCTION, "args", "\"a\", \"b\"", {"function_name": "describe"}), ["error", "describe's count is a whole number."]],
		["a number for a Vector2 slot", _says("position = {position}", "position", "5", {}), ["error", "position holds two numbers (Vector2)."]],
		["two numbers for a Color variable", _says(SET_VAR, "value", "Vector2(1, 2)", {"var_name": "tint"}), ["error", "tint holds a colour."]],
		["text for a Node2D variable", _says(SET_VAR, "value", "\"Player\"", {"var_name": "target_node"}), ["error", "target_node holds a node (Node2D)."]],
		["a Vector2 for a whole number", _says(SET_VAR, "value", "Vector2(1, 2)", {"var_name": "score"}), ["error", "score holds a whole number."]],
		["a function that returns text into a number", _says(SET_VAR, "value", "describe(\"a\")", {"var_name": "score"}), ["error", "score holds a whole number."]],
		["a float function into a text variable", _says(SET_VAR, "value", "ratio()", {"var_name": "player_name"}), ["error", "player_name holds text."]],
		["a dictionary function into a number", _says(SET_VAR, "value", "table()", {"var_name": "score"}), ["error", "score holds a whole number."]],
		["a list of whole numbers given text", _says(SET_VAR, "value", "\"x\"", {"var_name": "ids"}), ["error", "ids holds a list."]],
	]
	return SUPPORT.pins(NAME + ": refusals", rows)


## The false-positive table: every shape here is a legitimate value for the slot it is in and must say
## nothing. An int in a float slot, a float in an int slot (Godot only warns), text where a StringName
## goes, a Variant call, an enum, a local, a lambda, a loop counter.
static func _valid_shapes_stay_accepted() -> bool:
	var rows: Array = []
	var valid: Array = [
		["a whole number", SET_VAR, "value", "10", {"var_name": "score"}],
		["an int in a float slot", SET_VAR, "value", "3", {"var_name": "speed"}],
		["a float in an int slot", SET_VAR, "value", "speed * 1.5", {"var_name": "score"}],
		["a float literal in an int slot", SET_VAR, "value", "2.5", {"var_name": "score"}],
		["a number made whole", SET_VAR, "value", "int(speed)", {"var_name": "score"}],
		["text for text", SET_VAR, "value", "\"Ada\"", {"var_name": "player_name"}],
		["a StringName literal in a text slot", SET_VAR, "value", "&\"jump\"", {"var_name": "player_name"}],
		["text in a StringName slot", SET_VAR, "value", "\"jump\"", {"var_name": "label_id"}],
		["a StringName in a text slot", SET_VAR, "value", "label_id", {"var_name": "player_name"}],
		["str() of a number", SET_VAR, "value", "str(score)", {"var_name": "player_name"}],
		["joined text", SET_VAR, "value", "player_name + \" \" + str(score)", {"var_name": "player_name"}],
		["a Vector2 for a Vector2", SET_VAR, "value", "Vector2(5, 0)", {"var_name": "spawn"}],
		["a Vector2 from a call", SET_VAR, "value", "get_global_mouse_position()", {"var_name": "spawn"}],
		["a host Vector2 member", SET_VAR, "value", "position", {"var_name": "spawn"}],
		["a Color", SET_VAR, "value", "Color(1, 0.5, 0)", {"var_name": "tint"}],
		["a Color constant", SET_VAR, "value", "Color.RED", {"var_name": "tint"}],
		["a Color from a name", SET_VAR, "value", "Color(\"orange\")", {"var_name": "tint"}],
		["a node for a node", SET_VAR, "value", "get_parent()", {"var_name": "target_node"}],
		["null for a node", SET_VAR, "value", "null", {"var_name": "target_node"}],
		["a Variant call", SET_VAR, "value", "abs(speed)", {"var_name": "score"}],
		["max of numbers", SET_VAR, "value", "max(1, score)", {"var_name": "score"}],
		["clamp", SET_VAR, "value", "clamp(score, 0, 10)", {"var_name": "score"}],
		["lerp", SET_VAR, "value", "lerp(0.0, 1.0, 0.5)", {"var_name": "speed"}],
		["a random whole number", SET_VAR, "value", "randi() % 10", {"var_name": "score"}],
		["an engine enum constant", "process_mode = {m}", "m", "Node.PROCESS_MODE_ALWAYS", {}],
		["a ternary", SET_VAR, "value", "1 if speed > 0 else 2", {"var_name": "score"}],
		["delta", SET_VAR, "value", "delta * 2", {"var_name": "speed"}],
		["a local (untyped)", SET_VAR, "value", "other", {"var_name": "score"}],
		["a lambda call", SET_VAR, "value", "(func(a: int) -> int: return a + 1).call(score)", {"var_name": "score"}],
		["a typed array literal", SET_VAR, "value", "[1, 2, 3]", {"var_name": "ids"}],
		["len of a list", SET_VAR, "value", "ids.size()", {"var_name": "score"}],
		["a variable of an unknown type", SET_VAR, "value", "mystery", {"var_name": "score"}],
		["a number compared with a number variable", COMPARE_VAR, "value", "3", {"var_name": "score", "op": "=="}],
		["text compared with text", COMPARE_VAR, "value", "\"Ada\"", {"var_name": "player_name", "op": "=="}],
		["a float compared with an int", COMPARE_VAR, "value", "3", {"var_name": "speed", "op": ">"}],
		["one value to heal", CALL_FUNCTION, "args", "10", {"function_name": "heal"}],
		["a float to an int parameter", CALL_FUNCTION, "args", "speed", {"function_name": "heal"}],
		["the default is left out", CALL_FUNCTION, "args", "\"a\"", {"function_name": "describe"}],
		["both values given", CALL_FUNCTION, "args", "\"a\", 3", {"function_name": "describe"}],
		["a call inside a call", CALL_FUNCTION, "args", "int(speed * 2)", {"function_name": "heal"}],
		["a position from two numbers", "position = {position}", "position", "Vector2(score, speed)", {}],
		["another Vector2 member", "position = {position}", "position", "get_global_mouse_position()", {}],
	]
	for entry: Array in valid:
		var said: Array = _says(str(entry[1]), str(entry[2]), str(entry[3]), entry[4] as Dictionary)
		rows.append([str(entry[0]), said[0] if said[0] == "error" else "", ""])
	return SUPPORT.pins(NAME + ": valid shapes", rows)


static func _cannot_tell_is_a_note_not_an_error() -> bool:
	var rows: Array = [
		["an untyped local's member is a note", _says(SET_VAR, "value", "other.points + 1", {"var_name": "score"}), ["note", "Worked out while the game runs."]],
		["a typed value's member is not", _says(SET_VAR, "value", "spawn.x", {"var_name": "speed"}), ["", ""]],
		["an engine class's constant is not", _says(SET_VAR, "value", "Vector2.ZERO.x", {"var_name": "speed"}), ["", ""]],
	]
	return SUPPORT.pins(NAME + ": cannot tell", rows)


static func _spans_and_rewrites() -> bool:
	var assign: String = "Cannot assign a value of type \"String\" as \"int\"."
	var rows: Array = [
		["the whole wrong value is marked", EventSheetTypeCheck.span_of(assign, "\"ten\""), Vector2i(0, 5)],
		["the extra arguments are marked", EventSheetTypeCheck.span_of("Too many arguments for \"heal()\" call. Expected at most 1 but received 2.", "10, 2"), Vector2i(4, 5)],
		["only the argument that is the wrong kind", EventSheetTypeCheck.span_of(
			"Invalid argument for \"describe()\" function: argument 2 should be \"int\" but is \"String\".", "\"a\", \"b\""), Vector2i(5, 8)],
		["a missing member is marked by name", EventSheetTypeCheck.span_of("Cannot find member \"zz\" in base \"Vector2\".", "v.zz * 2"), Vector2i(2, 4)],
		["quotes come off a number written as text", EventSheetTypeCheck.rewrites_for(assign, "\"10\"", Vector2i(0, 4)), [{"kind": "use", "name": "10"}]],
		["a number becomes a Vector2", EventSheetTypeCheck.rewrites_for("Cannot assign a value of type \"int\" as \"Vector2\".", "5", Vector2i(0, 1)), [{"kind": "use", "name": "Vector2(5, 0)"}]],
		["a number becomes text", EventSheetTypeCheck.rewrites_for("Value of type \"int\" cannot be assigned to a variable of type \"String\".", "score", Vector2i(0, 5)), [{"kind": "use", "name": "str(score)"}]],
		["a quoted name becomes a node", EventSheetTypeCheck.rewrites_for("Value of type \"String\" cannot be assigned to a variable of type \"Node2D\".", "\"Player\"", Vector2i(0, 8)), [{"kind": "use", "name": "$Player"}]],
		["only the piece is rewritten", EventSheetTypeCheck.rewrites_for(assign, "x, \"7\"", Vector2i(3, 6)), [{"kind": "use", "name": "x, 7"}]],
		["text that is not a number has no rewrite", EventSheetTypeCheck.rewrites_for(assign, "\"ten\"", Vector2i(0, 5)), []],
	]
	var finding: Dictionary = EventSheetTypeCheck.check_field(SET_VAR, "value", "  \"ten\"",
		{"var_name": "score", "value": "  \"ten\""}, _sheet())
	rows.append(["the underline starts past leading spaces", finding.get("offset", -1), 2])
	rows.append(["Godot's own words ride along", str(finding.get("original", "")), "Cannot assign a value of type \"String\" as \"int\"."])
	rows.append(["the reason beside OK names the mistake", str(finding.get("reason", "")), "score holds a whole number; \"ten\" is text"])
	return SUPPORT.pins(NAME + ": spans", rows)


static func _unknown_types_fall_back_to_untyped() -> bool:
	var sheet: EventSheetResource = _sheet()
	var function_with_unknown: EventFunction = EventFunction.new()
	function_with_unknown.function_name = "wander"
	function_with_unknown.params.append(_param("who", "NotAType"))
	sheet.functions.append(function_with_unknown)
	var lines: PackedStringArray = EventSheetGDScriptLint.typed_variable_lines(sheet)
	var functions: PackedStringArray = EventSheetGDScriptLint.typed_function_lines(sheet)
	var classes: Dictionary = {"Player": true}
	var rows: Array = [
		["an unknown type is declared bare", "var mystery" in lines, true],
		["a known type keeps its type", "var score: int" in lines, true],
		["a typed array keeps its type", "var ids: Array[int]" in lines, true],
		["a function with an unknown type keeps the loose stand-in", functions.has("func wander(_a = null, _b = null, _c = null, _d = null, _e = null, _f = null, _g = null, _h = null) -> Variant: return null"), true],
		["a function with known types is spelled as the compiler spells it", functions.has("func heal(amount: int) -> void:"), true],
		["a Dictionary return gets a body that loads", functions.has("\treturn Dictionary()"), true],
		["a Variant is not a type", EventSheetGDScriptLint.is_known_type("Variant", PackedStringArray(), classes), false],
		["a project class is", EventSheetGDScriptLint.is_known_type("Player", PackedStringArray(), classes), true],
		["a sheet enum is", EventSheetGDScriptLint.is_known_type("State", PackedStringArray(["State"]), classes), true],
		["an engine enum is", EventSheetGDScriptLint.is_known_type("Node.ProcessMode", PackedStringArray(), classes), true],
		["an array of a Variant is not", EventSheetGDScriptLint.is_known_type("Array[Variant]", PackedStringArray(), classes), false],
		["an inner class the stand-in cannot see is not", EventSheetGDScriptLint.is_known_type("Inner", PackedStringArray(), classes), false],
	]
	# A bad function in the middle of the sheet does not stop the typed check of a value elsewhere.
	rows.append(["the check still works with that function present",
		_says_with(sheet, SET_VAR, "value", "\"ten\"", {"var_name": "score"}), ["error", "score holds a whole number."]])
	return SUPPORT.pins(NAME + ": fall-back", rows)


static func _says_with(sheet: EventSheetResource, template: String, param_id: String, value: String, others: Dictionary) -> Array:
	var values: Dictionary = others.duplicate()
	values[param_id] = value
	var finding: Dictionary = EventSheetTypeCheck.check_field(template, param_id, value, values, sheet)
	return [str(finding.get("level", "")), str(finding.get("head", ""))]


static func _scene_nodes_are_typed_and_checked() -> bool:
	var root: Node2D = Node2D.new()
	var player: Node2D = Node2D.new()
	player.name = "Player"
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node2D\nvar jump_height: int = 3\nsignal landed\nfunc hop() -> void:\n\tpass\n"
	script.reload()
	player.set_script(script)
	root.add_child(player)
	player.owner = root
	var rows: Array = [
		["a member the node lacks", _says(SET_VAR, "value", "$Player.jump_hieght * 2", {"var_name": "speed"}, root), ["error", "Player has no jump_hieght."]],
		["a member its script has", _says(SET_VAR, "value", "$Player.jump_height * 2", {"var_name": "speed"}, root), ["", ""]],
		["a method its script has", _says(SET_VAR, "value", "$Player.hop()", {"var_name": "speed"}, root)[0] == "error", false],
		["a signal its script has", _says(SET_VAR, "value", "$Player.landed", {"var_name": "speed"}, root)[0] == "error", false],
		["an engine property", _says(SET_VAR, "value", "$Player.position.x", {"var_name": "speed"}, root), ["", ""]],
		["an engine method", _says(SET_VAR, "value", "$Player.get_parent()", {"var_name": "target_node"}, root), ["", ""]],
		["a node the scene does not hold", _says(SET_VAR, "value", "$Ghost.anything", {"var_name": "speed"}, root), ["", ""]],
		["no scene at all", _says(SET_VAR, "value", "$Player.jump_hieght", {"var_name": "speed"}), ["", ""]],
		["a node reference is typed from the scene", _says("{target.}position = {v}", "v", "5", {"target": "$Player"}, root), ["error", "This takes two numbers (Vector2)."]],
	]
	var finding: Dictionary = EventSheetTypeCheck.check_field(SET_VAR, "value", "$Player.jump_hieght * 2",
		{"var_name": "speed"}, _sheet(), PackedStringArray(), root)
	rows.append(["the closest member is offered as a rewrite", finding.get("fixes", []), [{"kind": "use", "name": "$Player.jump_height * 2"}]])
	rows.append(["a member finding quotes nothing from Godot", str(finding.get("original", "x")), ""])
	rows.append(["the member is the span", finding.get("span", Vector2i()), Vector2i(8, 19)])
	root.free()
	return SUPPORT.pins(NAME + ": scene nodes", rows)


## The dialog's commit gate: a wrong kind blocks with the sentence and the reason beside OK, a right one
## does not, and a field the check cannot judge never blocks.
static func _the_dialog_gate_refuses_and_says_why() -> bool:
	var sheet: EventSheetResource = _sheet()
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "test"
	definition.id = "SetVar"
	definition.display_name = "Set value"
	definition.metadata = {"codegen_template": SET_VAR}
	definition.parameters = [
		{"id": "var_name", "display_name": "Variable", "type_name": "String", "hint": "variable_reference"},
		{"id": "value", "display_name": "Value", "type_name": "String", "hint": "expression"},
	]
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	dialog._definition = definition
	for parameter: Variant in definition.parameters:
		dialog._param_dicts[str((parameter as Dictionary)["id"])] = parameter
	var variable_field: LineEdit = LineEdit.new()
	variable_field.text = "score"
	var value_field: CodeEdit = CodeEdit.new()
	value_field.text = "\"ten\""
	dialog._fields = {"var_name": variable_field, "value": value_field}
	dialog._read_variable_context()
	dialog._validate_expression_field(value_field)
	var refused: Dictionary = dialog._blocking_expression_field()
	var note: Dictionary = dialog._note_for("value")
	var rows: Array = [
		["a wrong kind blocks OK", str(refused.get("message", "")), "✗ score holds a whole number. \"ten\" is text. Write a number, or an expression that gives a number."],
		["the reason names the mistake", str(refused.get("reason", "")), "not written: score holds a whole number; \"ten\" is text"],
		["the field's note is an error with Godot's words", [str(note.get("level", "")), str(note.get("original", ""))],
			["error", "Cannot assign a value of type \"String\" as \"int\"."]],
		["the field is marked, not tinted", bool(note.get("underline", false)), true],
	]
	value_field.text = "10"
	dialog._validate_expression_field(value_field)
	rows.append(["a right kind does not block", dialog._blocking_expression_field(), {}])
	value_field.text = "speed * 1.5"
	dialog._validate_expression_field(value_field)
	rows.append(["a narrowing conversion does not block", dialog._blocking_expression_field(), {}])
	variable_field.text = "player_name"
	value_field.text = "3"
	dialog._validate_expression_field(value_field)
	rows.append(["changing the variable re-judges the value", str(dialog._blocking_expression_field().get("message", "")),
		"✗ player_name holds text. 3 is a whole number. Write text in quotes, or put the value in str(...) to turn it into text."])
	# The same gate answers for the inline editor and the Properties bar.
	var inline: Dictionary = dialog.blocking_problem_for(definition.parameters[1] as Dictionary, "\"ten\"", true,
		"", SET_VAR, {"var_name": "score"})
	rows.append(["the inline gate says the same", str(inline.get("message", "")),
		"score holds a whole number. \"ten\" is text. Write a number, or an expression that gives a number."])
	rows.append(["the inline gate lets a right value through", dialog.blocking_problem_for(
		definition.parameters[1] as Dictionary, "7", true, "", SET_VAR, {"var_name": "score"}), {}])
	# A sheet whose typed stand-in cannot be written says nothing rather than something false.
	var odd: EventSheetResource = _sheet()
	var broken: EventFunction = EventFunction.new()
	broken.function_name = "broken"
	broken.return_type_name = "Dictionary"
	broken.params.append(_param("a", "int"))
	odd.functions.append(broken)
	rows.append(["a sheet with an odd function still checks",
		_says_with(odd, SET_VAR, "value", "\"ten\"", {"var_name": "score"}), ["error", "score holds a whole number."]])
	# The arguments of a call are a plain text field, and are checked all the same.
	var call_definition: ACEDefinition = ACEDefinition.new()
	call_definition.provider_id = "test"
	call_definition.id = "CallFunction"
	call_definition.metadata = {"codegen_template": CALL_FUNCTION}
	call_definition.parameters = [
		{"id": "function_name", "display_name": "Function", "type_name": "String", "hint": ""},
		{"id": "args", "display_name": "Arguments", "type_name": "String", "hint": ""},
	]
	var call_dialog: ACEParamsDialog = ACEParamsDialog.new()
	call_dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	call_dialog._definition = call_definition
	for parameter: Variant in call_definition.parameters:
		call_dialog._param_dicts[str((parameter as Dictionary)["id"])] = parameter
	var function_field: LineEdit = LineEdit.new()
	function_field.text = "heal"
	var args_field: LineEdit = LineEdit.new()
	args_field.text = "10, 2"
	call_dialog._fields = {"function_name": function_field, "args": args_field}
	call_dialog._read_variable_context()
	rows.append(["too many values in the arguments field block OK", str(call_dialog._blocking_expression_field().get("reason", "")),
		"not written: heal takes 1 value(s) (amount: int); this gives 2"])
	args_field.text = "10"
	rows.append(["the right count does not", call_dialog._blocking_expression_field(), {}])
	rows.append(["the function name field is not a value to check", call_dialog._is_type_checked("function_name", function_field), false])
	function_field.free()
	args_field.free()
	value_field.free()
	variable_field.free()
	return SUPPORT.pins(NAME + ": gate", rows)


## A message the table has no sentence for is not turned into a claim: when the plain compile check
## would refuse the same text, the type check keeps quiet and leaves it to that check.
static func _a_message_without_a_plain_form_is_left_to_the_compile_check() -> bool:
	var rows: Array = [
		["a bare pair is the compile check's", _says("position = {position}", "position", "(5, 0)", {}), ["", ""]],
		["an undeclared name is the compile check's", _says(SET_VAR, "value", "nothing_here + 1", {"var_name": "score"}), ["", ""]],
		["a constructor that matches nothing is the compile check's", _says(SET_VAR, "value", "Color(\"a\", 3, 4, 5, 6, 7)", {"var_name": "tint"}), ["", ""]],
		["an empty field says nothing", _says(SET_VAR, "value", "", {"var_name": "score"}), ["", ""]],
		["a field without a template is judged as an expression", _says("", "value", "heal(1, 2)", {}), ["error", "heal takes 1 value(s) (amount: int)."]],
	]
	return SUPPORT.pins(NAME + ": left to the compile check", rows)


## Valid values that the node stand-ins and the member check must leave alone.
static func _no_false_refusals_around_scene_nodes() -> bool:
	var root: Node2D = Node2D.new()
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite"
	root.add_child(sprite)
	sprite.owner = root
	var dynamic: Node = Node.new()
	dynamic.name = "Dynamic"
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\nfunc _get(property: StringName) -> Variant:\n\treturn 1\n"
	script.reload()
	dynamic.set_script(script)
	root.add_child(dynamic)
	dynamic.owner = root
	var broken_path: String = "user://type_check_broken_script.gd"
	var broken_file: FileAccess = FileAccess.open(broken_path, FileAccess.WRITE)
	broken_file.store_string("extends Node\nvar x: int = \"a\"\n")
	broken_file.close()
	var fine_path: String = "res://tests/fixtures/type_check_host.gd"
	var rows: Array = [
		["a node path inside text is text", _says(SET_VAR, "value", "\"$Sprite.nothing costs 5\"", {"var_name": "player_name"}, root), ["", ""]],
		["a unique name inside text is text", _says(SET_VAR, "value", "\"%Sprite.nothing\"", {"var_name": "player_name"}, root), ["", ""]],
		["a longer name beginning with a node's name", _says(SET_VAR, "value", "$Sprite.position.x + $Sprite2.y", {"var_name": "speed"}, root), ["", ""]],
		["a script that answers names of its own making", _says(SET_VAR, "value", "$Dynamic.anything", {"var_name": "speed"}, root), ["", ""]],
		["a script that does not compile is not a whole list", EventSheetTypeCheck.run_probe("extends \"%s\"\n" % broken_path).get("ok"), false],
		["a script that compiles is", EventSheetTypeCheck.script_compiles(load(fine_path)), true],
	]
	for member: String in ["free", "queue_free", "call_deferred", "call", "callv", "get", "set", "connect", "emit_signal", "get_class", "is_class", "has_method", "get_meta", "add_child", "tree_exited", "script", "name", "texture"]:
		rows.append(["%s is a member of a node" % member, _says(SET_VAR, "value", "$Sprite.%s" % member, {"var_name": "mystery"}, root)[1].contains("has no"), false])
	var result: bool = SUPPORT.pins(NAME + ": around scene nodes", rows)
	root.free()
	DirAccess.remove_absolute(broken_path)
	return result


## A stand-in script has no name, so Godot says `gdscript://-123.gd` for `self`. The reader never sees it; and
## a host the stand-in does not stand for (no class it can extend) is not judged by what `self` is.
static func _self_is_said_by_its_class_and_a_foreign_host_says_nothing() -> bool:
	var behaviour: EventSheetResource = _sheet()
	behaviour.behavior_mode = true
	var finding: Dictionary = EventSheetTypeCheck.check_field(SET_VAR, "value", "self", {"var_name": "target_node"}, behaviour)
	var foreign: EventSheetResource = _sheet()
	foreign.host_class = "NoSuchProjectClass"
	var project_class: EventSheetResource = _sheet()
	project_class.host_class = "EventSheetFixtureHost"
	return SUPPORT.pins(NAME + ": self", [
		["a behaviour's self is a Node, which a Node2D variable refuses", str(finding.get("level", "")), "error"],
		["Godot's words name the class", str(finding.get("original", "")), "Value of type \"Node\" cannot be assigned to a variable of type \"Node2D\"."],
		["no address reaches the sentence", str(finding.get("body", "")).contains("gdscript://"), false],
		["no address reaches the reason", str(finding.get("reason", "")).contains("gdscript://"), false],
		["a host the stand-in cannot extend: self is not judged", EventSheetTypeCheck.check_field(SET_VAR, "value", "self", {"var_name": "target_node"}, foreign), {}],
		["a project class as the host: its self is a node", EventSheetTypeCheck.check_field(SET_VAR, "value", "self", {"var_name": "target_node"}, project_class), {}],
		["a project class as the host: inherited members compile", EventSheetGDScriptLint.lint_expression("position", project_class).get("ok"), true],
	])


## A `$Path` is read from the node that runs the sheet; a scene that does not run it says nothing.
static func _the_scene_that_judges_is_the_one_that_runs_the_sheet() -> bool:
	var sheet: EventSheetResource = _sheet()
	sheet.external_source_path = "res://tests/fixtures/type_check_host.gd"
	var root: Node2D = Node2D.new()
	var carrier: Node2D = Node2D.new()
	carrier.name = "Carrier"
	root.add_child(carrier)
	var other_scene: Node2D = Node2D.new()
	var pins: Array = [["a scene that does not run the sheet has no host", EventSheetTypeCheck.host_in_scene(other_scene, sheet), null]]
	carrier.set_script(load(sheet.external_source_path))
	pins.append(["the node that runs the script is the host", EventSheetTypeCheck.host_in_scene(root, sheet), carrier])
	pins.append(["a sheet with no file has no host", EventSheetTypeCheck.host_in_scene(root, EventSheetResource.new()), null])
	var result: bool = SUPPORT.pins(NAME + ": host", pins)
	root.free()
	other_scene.free()
	return result
