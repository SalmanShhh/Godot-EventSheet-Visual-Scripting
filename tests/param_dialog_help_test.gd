# Godot EventSheets - the Parameters dialog says what the row will be.
#
# The dialog every action and condition with a blank opens used to be titled "<name> Parameters" and
# to print each parameter's description under its field in small text. It never said what the ROW
# would read as, never said what the focused BOX wanted, and found a wrong value on OK or later.
#
# This pins the four halves of the answer: the title sentence filled from the fields (P0), the line
# under each choice of an option list (P1), the paragraph each hint contributes to the one help
# strip (P2), and the red / amber notes with their fixes (P3). Everything here is static or built
# without a tree, because the dialog's own window needs a display server and its logic does not.
@tool
class_name ParamDialogHelpTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_title_sentence() and all_passed
	all_passed = _test_strip_text_per_hint() and all_passed
	all_passed = _test_option_second_lines() and all_passed
	all_passed = _test_validation_states() and all_passed
	all_passed = _test_strip_component() and all_passed
	return all_passed


## P0. The title IS the row: the object it belongs to, then the ACE's sentence with the values as
## typed. The code line beside it comes from the emitter, so the dialog cannot promise a spelling
## the compiler would not use.
static func _test_title_sentence() -> bool:
	var passed: bool = true
	var subtract: ACEDefinition = _definition("SubtractVar", "Subtract from",
		"Subtract {amount} from {var_name}", "{var_name} -= {amount}", ACEDefinition.ACEType.ACTION)
	passed = _check("the title reads as the row will",
		ACEParamsDialog.title_sentence(subtract, {"var_name": "hp", "amount": "damage * 2"}, "Player"),
		"Player   Subtract damage * 2 from hp") and passed
	passed = _check("without an owner it is the sentence alone",
		ACEParamsDialog.title_sentence(subtract, {"var_name": "hp", "amount": "1"}),
		"Subtract 1 from hp") and passed
	# The values fill from the descriptor's own defaults, so a dialog that has just opened already
	# reads as the row it would write if OK were pressed straight away.
	passed = _check("an untouched dialog still reads as a row",
		ACEParamsDialog.title_sentence(subtract, {}, "Player"),
		"Player   Subtract 1 from score") and passed
	passed = _check("the owner is tinted with the object colour",
		ACEParamsDialog.title_bbcode(subtract, {"var_name": "hp", "amount": "1"}, "Player").begins_with(
			"[color=#%s]Player[/color]" % EventSheetPalette.COLOR_OBJECT.to_html(false)), true) and passed
	passed = _check("and every filled value with the value colour",
		ACEParamsDialog.title_bbcode(subtract, {"var_name": "hp", "amount": "1"}).contains(
			"[color=#%s]hp[/color]" % EventSheetPalette.COLOR_VALUE.to_html(false)), true) and passed
	# A value carrying square brackets is a list, not markup - it must survive into the band as text.
	passed = _check("a bracketed value is escaped, not parsed",
		ACEParamsDialog.title_bbcode(subtract, {"var_name": "hp", "amount": "[1, 2]"}).contains("[lb]1, 2]"),
		true) and passed
	passed = _check("IN CODE is the line the emitter writes",
		ACEParamsDialog.row_code_line(subtract, {"var_name": "hp", "amount": "damage * 2"}),
		"hp -= damage * 2") and passed
	var compare: ACEDefinition = _definition("CompareVar", "Compare variable",
		"{var_name} {op} {value}", "{var_name} {op} {value}", ACEDefinition.ACEType.CONDITION)
	passed = _check("a condition's line is the if it becomes",
		ACEParamsDialog.row_code_line(compare, {"var_name": "hp", "op": "<=", "value": "0"}),
		"if hp <= 0:") and passed
	passed = _check("no definition, nothing promised",
		ACEParamsDialog.title_sentence(null, {}, "Player"), "") and passed
	return passed


## P2. One paragraph per hint, next to the control that hint already builds - so the strip is never
## generic, and the parameter's own description still leads.
static func _test_strip_text_per_hint() -> bool:
	var passed: bool = true
	var amount: Dictionary = {"id": "amount", "display_name": "Amount", "type_name": "String",
		"hint": "expression", "description": "How much to take off."}
	passed = _check("the heading names the parameter and what it takes",
		EventSheetParamFieldFactory.strip_heading(amount), "Amount - a value") and passed
	passed = _check("the description leads and the hint follows",
		EventSheetParamFieldFactory.strip_body(amount, "Player").begins_with("How much to take off."),
		true) and passed
	passed = _check("and the hint paragraph names the owner",
		EventSheetParamFieldFactory.strip_body(amount, "Player").contains("Player's variables"),
		true) and passed
	passed = _check("a colour parameter says what a colour may be",
		EventSheetParamFieldFactory.hint_paragraph("color").contains("#ff4d4d"), true) and passed
	passed = _check("a key capture says how to answer it",
		EventSheetParamFieldFactory.hint_paragraph("key_capture").begins_with("Press the key"),
		true) and passed
	passed = _check("a scene node says where to drag one from",
		EventSheetParamFieldFactory.hint_paragraph("scene_node").contains("Scene dock"), true) and passed
	passed = _check("an angle says which way zero points",
		EventSheetParamFieldFactory.hint_paragraph("angle").contains("Degrees"), true) and passed
	passed = _check("a variable reference promises the live value",
		EventSheetParamFieldFactory.hint_paragraph("variable_reference", "Player"),
		"One of Player's variables. The list shows each one's type and, while the game runs, its value.") and passed
	passed = _check("a hint nobody wrote a paragraph for contributes nothing",
		EventSheetParamFieldFactory.hint_paragraph("not_a_real_hint"), "") and passed
	# The type phrase falls back to the declared type when the hint has nothing to say about kind.
	passed = _check("a whole-number parameter says so",
		EventSheetParamFieldFactory.strip_heading({"id": "count", "display_name": "Count",
			"type_name": "int", "hint": ""}), "Count - a whole number") and passed
	passed = _check("a heading takes a problem word in place of the kind",
		EventSheetParamFieldFactory.strip_heading({"id": "var_name", "display_name": "Variable"},
			"not found"), "Variable - not found") and passed
	# Every hint the dialog builds a widget for should have something to say about it - a strip that
	# goes blank on the very fields that needed explaining is the state this replaced.
	var described: int = 0
	for hint: String in ["expression", "variable_reference", "color", "key_capture", "scene_node",
			"scene_path", "audio_path", "angle", "bbcode_text", "property_reference",
			"method_reference", "animation_reference", "input_action", "group_reference"]:
		if not EventSheetParamFieldFactory.hint_paragraph(hint).is_empty():
			described += 1
	passed = _check("every hint the mockup named is described", described, 14) and passed
	return passed


## P1. A choice explains itself from wherever the choice came from: the Input Map for an action, the
## open scene for a node group, the descriptor for a shipped list, the catalog for a variable.
static func _test_option_second_lines() -> bool:
	var passed: bool = true
	# An Input Map action reads with the keys bound to it. Registered here rather than assumed,
	# because the project's own map is what the picker reads and a test must not depend on it.
	var probe_action: StringName = &"__ef_param_help_probe"
	if InputMap.has_action(probe_action):
		InputMap.erase_action(probe_action)
	InputMap.add_action(probe_action)
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	InputMap.action_add_event(probe_action, space)
	passed = _check("an action reads with the key bound to it",
		EventSheetParamFieldFactory.input_action_note("\"%s\"" % probe_action), "Space") and passed
	InputMap.action_erase_events(probe_action)
	passed = _check("an action nothing is bound to says so",
		EventSheetParamFieldFactory.input_action_note(str(probe_action)),
		"not bound to anything yet") and passed
	InputMap.erase_action(probe_action)
	passed = _check("an action the map never had reads as nothing",
		EventSheetParamFieldFactory.input_action_note("\"never_registered\""), "") and passed

	# A node group counts what the open scene holds. Counted from a built tree, so the answer is a
	# fact about nodes and not about whichever scene happened to be open.
	var root: Node = Node.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	first.add_to_group(&"enemies", true)
	second.add_to_group(&"enemies", true)
	root.add_child(first)
	root.add_child(second)
	passed = _check("a group counts the nodes in it",
		EventSheetParamFieldFactory.node_group_note("\"enemies\"", root), "2 nodes in this scene") and passed
	passed = _check("one node is not two",
		EventSheetParamFieldFactory.node_group_note("\"pickups\"", root), "none yet - added at runtime?") and passed
	root.free()

	# A shipped list explains its choices from the note each option declares.
	var mode_param: Dictionary = {"id": "mode", "display_option_labels": true, "options": [
		{"key": "run", "label": "Run", "note": "double speed, keeps momentum"},
		{"key": "walk", "label": "Walk", "note": ""},
	]}
	var notes: Dictionary = EventSheetParamFieldFactory.option_notes(mode_param)
	passed = _check("an option carrying a note reads with it",
		str(notes.get("run", "")), "double speed, keeps momentum") and passed
	passed = _check("an option with no note renders as it always did",
		notes.has("walk"), false) and passed
	# A true/false pair says what each value does here rather than repeating the token it emits.
	var switch_param: Dictionary = {"id": "state", "display_option_labels": true, "options": [
		{"key": "true", "label": "active", "note": ""},
		{"key": "false", "label": "inactive", "note": ""},
	]}
	passed = _check("a boolean choice says the token it stands for",
		str(EventSheetParamFieldFactory.option_notes(switch_param).get("true", "")), "true") and passed
	passed = _check("a list that did not opt in stays bare",
		EventSheetParamFieldFactory.option_notes({"id": "op", "options": [
			{"key": "true", "label": "true", "note": ""}]}).is_empty(), true) and passed

	# A variable reads with its type and what it starts at - the same chip the sheet's rows lead with.
	passed = _check("a variable reads with its type and value",
		EventSheetParamFieldFactory.variable_option_note({"name": "hp", "type_word": "whole number",
			"value": "100"}), "whole number - 100") and passed
	passed = _check("and with what it holds while the game runs",
		EventSheetParamFieldFactory.variable_option_note({"name": "hp", "type_word": "whole number",
			"value": "100"}, "73"), "whole number - 100 - 73 now") and passed

	# The list a pick comes out of is the POOL, however much the item shows - which is what lets a
	# second line ride in the item text without changing what a pick inserts.
	passed = _check("a suggestion carries its line in the list",
		EventSheetPopupUI.suggestion_item_text("jump", func(_name: String) -> String: return "Space"),
		"jump    Space") and passed
	passed = _check("a suggestion with no line is itself",
		EventSheetPopupUI.suggestion_item_text("jump"), "jump") and passed
	return passed


## P3. The checks run at keystroke time, in the words the sheet's own row notes use, with the fix
## beside them - red for what cannot be meant, amber for what will surprise.
static func _test_validation_states() -> bool:
	var passed: bool = true
	var entries: Array[Dictionary] = [
		{"name": "hp", "type_word": "whole number", "type_name": "int", "value": "100", "scope": "instance"},
		{"name": "speed", "type_word": "number", "type_name": "float", "value": "200.0", "scope": "instance"},
	]
	var variable_param: Dictionary = {"id": "var_name", "display_name": "Variable",
		"hint": "variable_reference", "type_name": "String"}
	var unknown: Dictionary = EventSheetParamFieldFactory.validate(variable_param, "hpp", entries, "Player")
	passed = _check("an unknown variable is red", str(unknown.get("level", "")), "error") and passed
	passed = _check("and says whose it is not",
		str(unknown.get("body", "")), "hpp is not a variable of Player. Did you mean hp?") and passed
	passed = _check("the heading names the trouble",
		str(unknown.get("heading", "")), "Variable - not found") and passed
	var fixes: Array = unknown.get("fixes", [])
	passed = _check("the nearest name is offered first",
		str((fixes[0] as Dictionary).get("name", "")), "hp") and passed
	passed = _check("and declaring the one that was typed second",
		str((fixes[1] as Dictionary).get("kind", "")), "add") and passed
	passed = _check("the reason beside OK names the field",
		str(unknown.get("reason", "")), "fix Variable first") and passed
	passed = _check("a known variable is fine",
		EventSheetParamFieldFactory.validate(variable_param, "hp", entries, "Player").is_empty(), true) and passed
	passed = _check("a blank where a variable goes is red",
		str(EventSheetParamFieldFactory.validate(variable_param, "", entries, "Player").get("level", "")),
		"error") and passed

	# Amber: a literal of the wrong kind for what the VERB takes. Only a literal is judged - an
	# expression or a name is not something the dialog can be sure about.
	var amount_param: Dictionary = {"id": "amount", "display_name": "Amount",
		"hint": "expression", "type_name": "String"}
	var mismatch: Dictionary = EventSheetParamFieldFactory.validate(amount_param, "\"ten\"",
		entries, "Player", "number")
	passed = _check("text where a number goes is amber",
		str(mismatch.get("level", "")), "warning") and passed
	passed = _check("the heading says what it wants",
		str(mismatch.get("heading", "")), "Amount - wants a number") and passed
	passed = _check("and the fitting verb is named",
		str(mismatch.get("body", "")).contains("Set value can"), true) and passed
	passed = _check("a number is what it wanted",
		EventSheetParamFieldFactory.validate(amount_param, "10", entries, "Player", "number").is_empty(),
		true) and passed
	passed = _check("an expression is never second-guessed",
		EventSheetParamFieldFactory.validate(amount_param, "damage * 2", entries, "Player", "number").is_empty(),
		true) and passed
	passed = _check("a verb that takes anything warns about nothing",
		EventSheetParamFieldFactory.validate(amount_param, "\"ten\"", entries, "Player").is_empty(),
		true) and passed
	# The literal test itself: what a value IS, told apart from what it might evaluate to.
	passed = _check("a quoted value is text", EventSheetParamFieldFactory.literal_kind("\"ten\""), "text") and passed
	passed = _check("a number is a number", EventSheetParamFieldFactory.literal_kind("10.5"), "number") and passed
	passed = _check("true is a boolean", EventSheetParamFieldFactory.literal_kind("true"), "boolean") and passed
	passed = _check("a name is not a literal", EventSheetParamFieldFactory.literal_kind("hp"), "") and passed
	# A declared type still speaks for a field the verb says nothing about.
	passed = _check("a bool-typed parameter given a number is amber",
		str(EventSheetParamFieldFactory.validate({"id": "loop", "display_name": "Loop",
			"type_name": "bool", "hint": ""}, "3", entries, "Player").get("level", "")), "warning") and passed
	return passed


## P0/P4. The one strip: it speaks in three tones, offers the fixes a note carries, and hides a
## reading line it has nothing to put on.
static func _test_strip_component() -> bool:
	var passed: bool = true
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip("Amount", "How much.")
	passed = _check("the heading is upper-cased for the eye",
		strip.heading_label.text, "AMOUNT") and passed
	passed = _check("an empty reading line hides", strip.in_code_row.visible, false) and passed
	strip.set_reading("", "hp -= 1")
	passed = _check("a filled one shows", strip.in_code_row.visible, true) and passed
	passed = _check("and READS AS stays hidden when there is nothing to read",
		strip.reads_as_row.visible, false) and passed
	strip.show_note("Variable - not found", "hpp is not a variable of Player.",
		EventSheetPopupUI.HelpStrip.TONE_ERROR, [{"text": "Use hp", "pressed": Callable()}])
	passed = _check("a complaint speaks in its own tone", strip.tone, "error") and passed
	passed = _check("and offers its fix", strip.fixes_row.get_child_count(), 1) and passed
	passed = _check("the fix says what it will do",
		(strip.fixes_row.get_child(0) as Button).text, "Use hp") and passed
	strip.show_note("Amount", "How much.")
	passed = _check("describing something again clears the tone", strip.tone, "") and passed
	passed = _check("and takes the stale fix away", strip.fixes_row.visible, false) and passed
	strip.free()
	return passed


## An ACEDefinition shaped the way the registry hands one over - a sentence template, a codegen
## template and two parameters with defaults.
static func _definition(ace_id: String, display_name: String, sentence: String, code: String,
		kind: int) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "Core"
	definition.id = ace_id
	definition.display_name = display_name
	definition.ace_type = kind
	definition.metadata = {"display_template": sentence, "codegen_template": code}
	definition.parameters = [
		{"id": "var_name", "display_name": "Variable", "type_name": "String",
			"hint": "variable_reference", "default_value": "score"},
		{"id": "amount", "display_name": "Amount", "type_name": "String",
			"hint": "expression", "default_value": "1"},
		{"id": "op", "display_name": "Comparison", "type_name": "String",
			"hint": "", "default_value": "=="},
		{"id": "value", "display_name": "Value", "type_name": "String",
			"hint": "expression", "default_value": "0"},
	]
	return definition


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] param_dialog_help_test: %s" % label)
		return true
	print("[FAIL] param_dialog_help_test: %s" % label)
	print("  expected: %s" % expected)
	print("  actual:   %s" % actual)
	return false
