# EventForge - class names and kinds of a class. A sheet that names itself (class_name Enemy) is an
# object the whole project can pick; a sheet that extends it is a kind of it. This pins the System
# condition "Is a kind of..." (the GDScript `is`), which must write the line a hand-written file
# has, lift back from it, and re-emit it byte for byte.
@tool
class_name ClassKindsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	var is_a: ACEDescriptor = by_id.get("IsAKindOf") as ACEDescriptor
	ok = SUPPORT.check("class_kinds_test", "Is a kind of is registered", is_a != null, true) and ok
	if is_a == null:
		return false
	ok = SUPPORT.pins("class_kinds_test", [
		["the template is the GDScript type test", is_a.codegen_template, "{value} is {kind}"],
		["it is a condition", is_a.ace_type, ACEDescriptor.ACEType.CONDITION],
	]) and ok

	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Area2D"
	authored.custom_class_name = "Hazard"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnBodyEntered"
	var asks: ACECondition = ACECondition.new()
	asks.provider_id = "Core"
	asks.ace_id = "IsAKindOf"
	asks.params = {"value": "body", "kind": "Enemy"}
	event.conditions.append(asks)
	authored.events.append(event)
	var source: String = SUPPORT.compile_output(authored, "user://class_kinds_a.gd")
	ok = SUPPORT.check("class_kinds_test", "the condition writes the type test",
		source.contains("if body is Enemy:"), true) and ok
	var again: String = SUPPORT.reemit(source, "user://class_kinds_a.gd")
	ok = SUPPORT.check("class_kinds_test", "a sheet using it round-trips byte for byte", again == source, true) and ok
	var reopened: EventSheetResource = SUPPORT.reopen(source, true, "user://class_kinds_a.gd")
	var lifted: String = ""
	for row: Variant in reopened.events:
		if row is EventRow and not (row as EventRow).conditions.is_empty():
			lifted = str((row as EventRow).conditions[0].ace_id)
	ok = SUPPORT.check("class_kinds_test", "a reopened file keeps the type test in its own reading, not as this verb", lifted != "IsAKindOf", true) and ok
	ok = SUPPORT.pins("class_kinds_test", [
		["a class said with a vowel takes an", EventSheetSentence.indefinite_article("Enemy"), "an"],
		["an engine class that starts with A takes an", EventSheetSentence.indefinite_article("Area2D"), "an"],
		["a consonant takes a", EventSheetSentence.indefinite_article("Node2D"), "a"],
		["a U said like you takes a", EventSheetSentence.indefinite_article("Unit"), "a"],
		["a U said like uh takes an", EventSheetSentence.indefinite_article("Umbrella"), "an"],
		["a typed test reads with the article of its class", EventSheetSentence.condition("body is Enemy", {}).get("segments", [])[0].get("text", ""), "is an "],
	]) and ok
	var kind_row: ACECondition = ACECondition.new()
	kind_row.provider_id = "Core"
	kind_row.ace_id = "IsAKindOf"
	kind_row.params = {"value": "body", "kind": "Enemy"}
	var shown: Dictionary = ViewportRowBuilder.new().grammar_condition_sentence(kind_row)
	ok = SUPPORT.pins("class_kinds_test", [
		["the authored row reads on the value", shown.get("object", ""), "body"],
		["the authored row says is an", (shown.get("segments", [{}])[0] as Dictionary).get("text", ""), "is an "],
	]) and ok
	ok = run_kinds() and ok
	ok = run_parent_call() and ok
	ok = run_class_window() and ok
	ok = run_inherited() and ok
	ok = run_narrowing() and ok
	ok = SUPPORT.pins("class_kinds_test", [
		["an empty kind-of field is fine", EventSheetNewSheetDialog.kind_problem_text(""), ""],
		["a Godot class is fine", EventSheetNewSheetDialog.kind_problem_text("CharacterBody2D"), ""],
		["a class of the project is fine", EventSheetNewSheetDialog.kind_problem_text("EventSheetResource"), ""],
		["a name that is no class is warned", EventSheetNewSheetDialog.kind_problem_text("Nonsuch"), "No class or node by that name."],
		# The warning waits while the field still completes what is typed: a prefix on its way to a
		# class is not a mistake yet.
		["a prefix of a project class still completes", EventSheetNewSheetDialog.kind_has_completion("EventSheetRes"), true],
		["a prefix of a Godot class still completes, any case", EventSheetNewSheetDialog.kind_has_completion("characterbo"), true],
		["a name nothing begins with completes nothing", EventSheetNewSheetDialog.kind_has_completion("Nonsuchxyz"), false],
		# Only a kind of the project's own class is named as a class; extending a Godot class names nothing.
		["a kind of a project class names the new sheet", EventSheetNewSheetDialog.names_new_class("EventSheetResource"), true],
		["extending a Godot class names nothing", EventSheetNewSheetDialog.names_new_class("CharacterBody2D"), false],
		["an empty field names nothing", EventSheetNewSheetDialog.names_new_class(""), false],
		# The completion list floats in a window that is never a popup and never focused: while a popup
		# window is open the keyboard goes to it, and Backspace and every letter after it were lost.
		["the completion list is not a popup window and takes no focus", _list_window_facts(), [false, true, true]],
		["while the list is open the dialog's Escape is held, and given back when it closes", _escape_facts(), [false, true]],
		["right-clicking a script that names a class offers its kind", EventSheetContextMenu.class_declared_in(
			PackedStringArray(["res://addons/eventforge/resources/event_sheet.gd"])), "EventSheetResource"],
		["two scripts offer none", EventSheetContextMenu.class_declared_in(PackedStringArray(["res://a.gd", "res://b.gd"])), ""],
		["a script naming no class offers none", EventSheetContextMenu.class_declared_in(PackedStringArray(["res://not_a_class_anywhere.gd"])), ""],
		["the menu words in Godot's vocabulary", EventSheetContextMenu.kind_menu_text("Enemy"), "New script extending Enemy…"],
	]) and ok
	return ok


const KINDS_PATH := "res://addons/eventsheet/editor/dock/class_kinds.gd"
const ENEMY_SOURCE := "class_name Enemy\nextends CharacterBody2D\n\n@export var health: int = 3\nvar speed := 120.0\nvar touch_damage: int = 1\n\n\nfunc take_damage(amount: int) -> void:\n\thealth -= amount\n\n\nfunc score_for(kind: String, bonus: int = 0) -> int:\n\treturn bonus\n"


## What a class hands down, and what a kind writes: read off a parent's source, replaced with super,
## started at another value, and the whole thing a plain GDScript file that opens and saves untouched.
static func run_kinds() -> bool:
	var kinds: GDScript = load(KINDS_PATH)
	var ok: bool = true
	var members: Dictionary = kinds.inherited("Enemy", _classes())
	var variable_names: Array = []
	for entry: Dictionary in members["variables"]:
		variable_names.append("%s:%s" % [entry["name"], entry["owner"]])
	var function_names: Array = []
	for entry: Dictionary in members["functions"]:
		function_names.append(str(entry["name"]))
	ok = SUPPORT.pins("class_kinds_test", [
		["the variables a parent hands down, with their owner", variable_names, ["health:Enemy", "speed:Enemy", "touch_damage:Enemy"]],
		["the functions a parent hands down", function_names, ["take_damage", "score_for"]],
		["a typed variable keeps its default", (members["variables"][0] as Dictionary)["value"], "3"],
		["an inferred variable keeps its default", (members["variables"][1] as Dictionary)["value"], "120.0"],
		["a parameter keeps its type", ((members["functions"][1] as Dictionary)["params"][0] as Dictionary)["type"], "String"],
		["a default value is not part of the parameter", ((members["functions"][1] as Dictionary)["params"][1] as Dictionary)["name"], "bonus"],
		["the head in Familiar words", kinds.head_reading("Slime", "Enemy", true), "Slime a kind of Enemy"],
		["the head in Godot words", kinds.head_reading("Slime", "Enemy", false), "Slime extends Enemy"],
		["replaces, Familiar", kinds.word("replaces", true), "Replaces"],
		["replaces, Godot", kinds.word("replaces", false), "Overrides"],
		["a class name from a file stem", kinds.class_name_from("big_slime.gd"), "BigSlime"],
		["an engine class name is taken", kinds.name_is_taken("Node2D", "", _classes()), true],
		["another project class's name is taken", kinds.name_is_taken("Enemy", "res://slime.gd", _classes()), true],
		["the class's own file does not take its own name", kinds.name_is_taken("Enemy", "user://class_kinds_enemy.gd", _classes()), false],
	]) and ok

	var slime: EventSheetResource = kinds.new_kind_sheet("Slime", "Enemy")
	var replaced: EventFunction = kinds.replace_function(members["functions"][0])
	slime.functions.append(replaced)
	kinds.start_variable_at(slime, "speed", "60.0")
	var source: String = SUPPORT.compile_output(slime, "user://class_kinds_slime.gd")
	ok = SUPPORT.pins("class_kinds_test", [
		["the kind names itself and extends its parent", source.contains("class_name Slime\nextends Enemy"), true],
		["Replace writes the function with the parent's parameters", source.contains("func take_damage(amount: int) -> void:"), true],
		["and runs the parent's version first", source.contains("\tsuper(amount)"), true],
		["Start it at writes _init", source.contains("func _init() -> void:\n\tspeed = 60.0"), true],
	]) and ok
	kinds.start_variable_at(slime, "speed", "75.0")
	var restarted: String = SUPPORT.compile_output(slime, "user://class_kinds_slime.gd")
	ok = SUPPORT.pins("class_kinds_test", [
		["starting the same variable again replaces, never doubles", restarted.count("speed ="), 1],
		["the new value is the one written", restarted.contains("speed = 75.0"), true],
		["the file opens and saves untouched, byte for byte", SUPPORT.reemit(source, "user://class_kinds_slime.gd") == source, true],
	]) and ok
	var answering: EventFunction = kinds.replace_function(members["functions"][1])
	var answering_sheet: EventSheetResource = kinds.new_kind_sheet("Boss", "Enemy")
	answering_sheet.functions.append(answering)
	var answering_source: String = SUPPORT.compile_output(answering_sheet, "user://class_kinds_boss.gd")
	ok = SUPPORT.check("class_kinds_test", "a replaced function that answers hands the parent's answer on",
		answering_source.contains("return super(kind, bonus)"), true) and ok
	return ok


## With the list open Escape closes the list, not the dialog around the field; closing the list hands
## the dialog its Escape back.
static func _escape_facts() -> Array:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	var popup: EventSheetCompletionPopup = EventSheetCompletionPopup.new()
	popup.hold_dialog_escape(dialog)
	var held: bool = dialog.dialog_close_on_escape
	popup.close()
	var released: bool = dialog.dialog_close_on_escape
	dialog.free()
	return [held, released]


static func _list_window_facts() -> Array:
	var window: Window = EventSheetCompletionPopup.new_list_window()
	var facts: Array = [window is Popup or window.get_flag(Window.FLAG_POPUP), window.get_flag(Window.FLAG_NO_FOCUS), window.transient]
	window.free()
	return facts


static func _classes() -> Dictionary:
	var file: FileAccess = FileAccess.open("user://class_kinds_enemy.gd", FileAccess.WRITE)
	file.store_string(ENEMY_SOURCE)
	file.close()
	return {"Enemy": {"path": "user://class_kinds_enemy.gd", "base": "CharacterBody2D"}}


## The also-run row names the class and the function, and is only offered where it compiles.
static func run_parent_call() -> bool:
	var kinds: GDScript = load(KINDS_PATH)
	var members: Dictionary = kinds.inherited("Enemy", _classes())
	var slime: EventSheetResource = kinds.new_kind_sheet("Slime", "Enemy")
	var replaced: EventFunction = kinds.replace_function(members["functions"][0])
	slime.functions.append(replaced)
	var also: ACEAction = ((replaced.events[0] as EventRow).actions[0]) as ACEAction
	# The same line reopened from a file lifts as a plain call of `super`, and reads the same.
	var lifted: ACEAction = ACEAction.new()
	lifted.provider_id = "Core"
	lifted.ace_id = "CallFunction"
	lifted.params = {"function_name": "super", "args": "amount"}
	(replaced.events[0] as EventRow).actions.append(lifted)
	var outside: EventRow = EventRow.new()
	var stray: ACEAction = ACEAction.new()
	stray.provider_id = "Core"
	stray.ace_id = "CallParentFunction"
	outside.actions.append(stray)
	slime.events.append(outside)
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(slime)
	var godot_text: String = _words_of(view._row_builder.grammar_action_sentence(also))
	view.familiar_words = true
	var familiar_text: String = _words_of(view._row_builder.grammar_action_sentence(also))
	var lifted_text: String = _words_of(view._row_builder.grammar_action_sentence(lifted))
	view.familiar_words = false
	var stray_text: String = _words_of(view._row_builder.grammar_action_sentence(stray))
	view.free()
	var classes: Dictionary = _classes()
	var plain: EventSheetResource = kinds.new_kind_sheet("Rock", "Node2D")
	var plain_function: EventFunction = EventFunction.new()
	plain_function.function_name = "take_damage"
	plain_function.events.append(EventRow.new())
	plain.functions.append(plain_function)
	# Picked from the picker into a function of its own: answered with the function's parameters, and with
	# the return form where the parent's function answers.
	var picked_into: EventFunction = EventFunction.new()
	picked_into.function_name = "take_damage"
	var amount: ACEParam = ACEParam.new()
	amount.id = "amount"
	amount.type_name = "int"
	picked_into.params.append(amount)
	picked_into.events.append(EventRow.new())
	var scoring: EventFunction = EventFunction.new()
	scoring.function_name = "score_for"
	for name: String in ["kind", "bonus"]:
		var param: ACEParam = ACEParam.new()
		param.id = name
		scoring.params.append(param)
	scoring.events.append(EventRow.new())
	var picking: EventSheetResource = kinds.new_kind_sheet("Bat", "Enemy")
	picking.functions.append(picked_into)
	picking.functions.append(scoring)
	var answered: Dictionary = kinds.also_run_action(picking, picked_into.events[0], classes)
	var picked_row: ACEAction = ACEAction.new()
	picked_row.provider_id = "Core"
	picked_row.ace_id = str(answered.get("ace_id", ""))
	picked_row.params = answered.get("params", {})
	(picked_into.events[0] as EventRow).actions.append(picked_row)
	var emitted: String = SUPPORT.compile_output(picking)
	return SUPPORT.pins("class_kinds_test", [
		["picked into take_damage(amount), it runs the parent's with the same argument", answered,
			{"ace_id": "CallParentFunction", "params": {"args": "amount"}}],
		["...and compiles to a super call with that argument", emitted.contains("func take_damage(amount: int) -> void:\n\tsuper(amount)"), true],
		["picked into a function whose parent answers, it hands the answer on",
			kinds.also_run_action(picking, scoring.events[0], classes), {"ace_id": "ReturnValue", "params": {"value": "super(kind, bonus)"}}],
		["nothing is answered outside a function that replaces the parent's", kinds.also_run_action(picking, EventRow.new(), classes), {}],
		["Godot words call super by function", godot_text, "Call super: take_damage"],
		["Familiar words name the class and the function", familiar_text, "Also run Enemy's take_damage"],
		["a reopened super call reads the same", lifted_text, "Also run Enemy's take_damage"],
		["outside a function the row keeps its old words", stray_text, ""],
		["offered inside a function that replaces the parent's", kinds.also_run_offered(slime, replaced.events[0], classes), true],
		["not offered outside every function", kinds.also_run_offered(slime, outside, classes), false],
		["not offered in a function the parent lacks", kinds.also_run_offered(slime, EventRow.new(), classes), false],
		["not offered on a sheet that is no kind of a project class", kinds.also_run_offered(plain, plain_function.events[0], classes), false],
		["the parent's function is found by name", (kinds.parent_function_of(slime, "take_damage", classes) as Dictionary).get("owner", ""), "Enemy"],
	])


static func _words_of(sentence: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in sentence.get("segments", []):
		text += str((segment as Dictionary).get("text", ""))
	return text


const WINDOW_PATH := "res://addons/eventsheet/editor/dock/class_window.gd"


## The Class window's questions, asked without a window: what is wrong with each field, which lines a
## set of answers writes, and which members a rebase would leave dangling.
static func run_class_window() -> bool:
	var window: GDScript = load(WINDOW_PATH)
	var current: Dictionary = {"name": "Enemy", "extends": "CharacterBody2D", "icon": "", "description": "Hurts."}
	var used: String = "health -= amount\nvelocity = Vector2.ZERO\nspeed = 3"
	return SUPPORT.pins("class_kinds_test", [
		["a free name is fine", window.name_problem("Foe", "Enemy", PackedStringArray()), ""],
		["a name that is no identifier is refused", window.name_problem("2 foes", "Enemy", PackedStringArray()), "\"2 foes\" cannot be a class name."],
		["a Godot class takes the name", window.name_problem("Node2D", "Enemy", PackedStringArray()), "\"Node2D\" is already the name of another class."],
		["the name it has is no clash", window.name_problem("Enemy", "Enemy", PackedStringArray()), ""],
		["a Godot class is a fine base", window.base_problem("Node2D"), ""],
		["a base nothing completes is warned", window.base_problem("Nonsuchxyz"), "No class or node by that name."],
		["a picture of nowhere is warned", window.icon_problem("res://nowhere.svg"), "No picture there."],
		["no icon is fine", window.icon_problem(""), ""],
		["an unchanged window writes nothing", window.changes(current, current).size(), 0],
		["a new name is one line", window.changes(current, {"name": "Foe"}), {"name": "Foe"}],
		["an emptied base never removes extends", window.changes(current, {"extends": ""}).size(), 0],
		["an emptied description removes its line", window.changes(current, {"description": ""}), {"description": ""}],
		["two changes are two lines in file order", window.changes(current, {"name": "Foe", "extends": "Area2D"}).keys(), ["name", "extends"]],
		["a rebase loses what only the old base has", window.lost_members(used, "CharacterBody2D", "Node"), PackedStringArray(["velocity"])],
		["the same base loses nothing", window.lost_members(used, "Node2D", "Node2D").size(), 0],
	])


## What a kind reads under its head: the parent's variables and functions as rows, what the kind starts
## them at, the replacement it has written, and the words of the menu on its tab.
static func run_inherited() -> bool:
	var kinds: GDScript = load(KINDS_PATH)
	var classes: Dictionary = _classes()
	var slime: EventSheetResource = kinds.new_kind_sheet("Slime", "Enemy")
	kinds.start_variable_at(slime, "speed", "60.0")
	var have: Dictionary = kinds.inherited_for(slime, classes)
	var starts: Dictionary = {}
	for variable: Dictionary in have["variables"]:
		starts[variable["name"]] = variable["starts"]
	var replaced: EventFunction = kinds.replace_function((have["functions"] as Array)[0])
	slime.functions.append(replaced)
	var view: EventSheetViewport = EventSheetViewport.new()
	var starts_folded: bool = view.inherited_folded
	view.inherited_folded = false
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(slime)
	view.familiar_words = true
	var builder: ViewportRowBuilder = view._row_builder
	builder.kinds_table_override = classes
	var rows: Array[EventRowData] = builder._build_inherited_rows(slime)
	var words: Array = []
	for row_data: EventRowData in rows:
		var line: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			line.append(span.text)
		words.append(" ".join(line))
	view.familiar_words = false
	var godot_bar: String = (builder._build_inherited_rows(slime)[0].spans[1] as SemanticSpan).text
	view.inherited_folded = true
	var folded_rows: Array[EventRowData] = builder._build_inherited_rows(slime)
	view.free()
	var plain: EventSheetResource = kinds.new_kind_sheet("Rock", "Node2D")
	return SUPPORT.pins("class_kinds_test", [
		["what the kind starts a variable at is read from _init", kinds.starts_at(slime), {"speed": "60.0"}],
		["the inherited variables carry what the kind starts them at", starts, {"health": "", "speed": "60.0", "touch_damage": ""}],
		["a sheet that is no kind of a project class inherits nothing", kinds.inherited_for(plain, classes), {}],
		["the group is a bar, three variables and two functions", words.size(), 6],
		["the bar names the parent and where it is changed", words[0], "▼ From Enemy read here, changed on Enemy's sheet"],
		["a started variable says what the kind starts it at", words[2], "float speed = 120.0 Slime starts it at 60.0"],
		["a variable left alone says nothing more", words[1], "int health = 3"],
		["a replaced function says so", words[4], "ƒ take_damage(amount: int) Replaces Slime"],
		["Godot words say inherited", godot_bar, "Inherited from"],
		["a sheet opens with the inherited group folded to its bar", starts_folded, true],
		["a folded group is the one bar", folded_rows.size(), 1],
		["the fold's bar counts what it holds", (folded_rows[0].spans[3] as SemanticSpan).text, "3 variables · 2 functions"],
		["a variable row carries its own double-click", str((rows[2].spans[1] as SemanticSpan).metadata.get("double_head_action", "")), "inherited_start:speed"],
		["a function row carries its own menu", str((rows[4].spans[1] as SemanticSpan).metadata.get("context_action", "")), "inherited_function:take_damage"],
		["a value says what type it is", [kinds.type_of_value("120.0"), kinds.type_of_value("3"), kinds.type_of_value("\"hi\""), kinds.type_of_value("true"), kinds.type_of_value("Foo.new()")], ["float", "int", "String", "bool", ""]],
		["a class is described by the lines above its name", kinds.description_of("## Hurts the player.\n@icon(\"x.svg\")\nclass_name Enemy\nextends Node\n"), "Hurts the player."],
		["a class with no description has none", kinds.description_of("class_name Enemy\n"), ""],
		["the tab menu reads in Familiar words", EventSheetHeadActions.new_kind_text("Enemy", true), "New kind of Enemy…"],
		["the tab menu reads in Godot words", EventSheetHeadActions.new_kind_text("Enemy", false), "New script extending Enemy…"],
		["a sheet that names itself is the class of its tab", EventSheetHeadActions.class_of_sheet(kinds.new_kind_sheet("Slime", "Enemy")), "Slime"],
		["a sheet that names nothing has no tab menu", EventSheetHeadActions.class_of_sheet(EventSheetResource.new()), ""],
	])


## An event that asked the type of a value offers that class's own members on it.
static func run_narrowing() -> bool:
	var kinds: GDScript = load(KINDS_PATH)
	var event: EventRow = EventRow.new()
	var asks: ACECondition = ACECondition.new()
	asks.provider_id = "Core"
	asks.ace_id = "IsAKindOf"
	asks.params = {"value": "body", "kind": "Enemy"}
	event.conditions.append(asks)
	var typed: ACECondition = ACECondition.new()
	typed.provider_id = "Core"
	typed.ace_id = "ExpressionIsTrue"
	typed.params = {"expr": "other is Hazard"}
	event.conditions.append(typed)
	var offered: Array[ACEDefinition] = ACEPickerDialog.unique_node_definitions("body", "Node2D", true)
	var aimed: Array = []
	for definition: ACEDefinition in offered:
		for parameter: Dictionary in definition.parameters:
			if str(parameter.get("id", "")) == "target":
				aimed.append(str(parameter.get("default_value", "")))
	var first_aim: String = str(aimed[0]) if not aimed.is_empty() else "(none offered)"
	return SUPPORT.pins("class_kinds_test", [
		["the type test is read from the picker's condition", kinds.narrowings(event)[0], {"value": "body", "kind": "Enemy"}],
		["and from the same test typed as an expression", kinds.narrowings(event)[1], {"value": "other", "kind": "Hazard"}],
		["an event that asks nothing narrows nothing", kinds.narrowings(EventRow.new()).size(), 0],
		["a narrowed value is written by its own name, not as a node of the scene", first_aim, "body"],
	])
