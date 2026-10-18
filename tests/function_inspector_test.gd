@tool
extends RefCounted
# Godot EventSheets - a selected function edited in Godot's own Inspector, and the New Function window
# on the window kit. Pins the fields the Inspector is handed, that typed text waits until its field is
# left, and that each field writes exactly one change (and nothing when nothing changed); then the
# window's band, code name, title, help strip and IN CODE line.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "function_inspector_test"
const INSPECTOR_PATH := "res://addons/eventsheet/editor/dock/function_inspector.gd"
const PLUGIN_PATH := "res://addons/eventsheet/editor/inspector/function_inspector_plugin.gd"


static func run() -> bool:
	return _test_inspector() and _test_window() and _test_described_fields() and _test_guards() \
		and _test_shared_reads_emitted_code() and _test_defaults_left_to_gdscript() and _test_type_restarts_default() \
		and _test_held_text_stays_on_its_tab()


## A new parameter Type starts its default again from the type's own value, in one step, so a default
## the old type held never sits under a type that cannot hold it; a required parameter stays required.
static func _test_type_restarts_default() -> bool:
	var dock: EventSheetDock = _guarded_dock()
	var inspector: RefCounted = load(INSPECTOR_PATH).new(dock, dock._current_sheet.functions[0])
	inspector.get_property_list()
	inspector.hold("param:1:default", "maybe")
	inspector.apply_param_type(1, "String")
	var critical: ACEParam = inspector.live_function().params[1]
	var ok: bool = SUPPORT.pins(NAME, [
		["bool = false turned to String starts as empty text", [critical.type_name, critical.gdscript_default], ["String", "\"\""]],
		["and the text typed into its default is dropped with it", inspector.get("Parameters/2/Default"), "\"\""],
	])
	inspector.apply_param_type(1, "Color")
	inspector.apply_param_type(0, "float")
	var amount: ACEParam = inspector.live_function().params[0]
	ok = SUPPORT.pins(NAME, [
		["a colour starts visible", inspector.live_function().params[1].gdscript_default, "Color.WHITE"],
		["a required parameter stays required", [amount.type_name, amount.gdscript_default], ["float", ""]],
		["a vector is spelled the way the dropdown spells it", load(INSPECTOR_PATH).starting_value("Vector2"), "Vector2.ZERO"],
		["a function with no name says why it needs one", inspector.warning("name", ""),
			[EventSheetPopupUI.TONE_ERROR, "A function needs a name, so callers can find it. Nothing was changed."]],
	]) and ok
	dock.free()
	return ok


## Text held in a function's field is written to the sheet it was typed on when another tab comes up,
## and the Inspector never answers for a same-named function of the tab that came up.
static func _test_held_text_stays_on_its_tab() -> bool:
	var dock: EventSheetDock = _guarded_dock()
	var other: EventSheetResource = EventSheetResource.new()
	other.host_class = "Node2D"
	var twin: EventFunction = EventFunction.new()
	twin.function_name = "take_damage"
	twin.description = "The other sheet's."
	other.functions.append(twin)
	dock._open_sheet_in_tab(other, "")
	dock._activate_tab(0)
	var view: EventSheetViewport = dock._active_view()
	var bar: EventSheetPropertiesBar = dock._properties_bar
	view.select_resource(dock._current_sheet.functions[0])
	bar.refresh()
	var inspector: RefCounted = bar._function_inspector
	if inspector != null:
		inspector.hold("description", "Typed on the first tab.")
	dock._activate_tab(1)
	var ok: bool = SUPPORT.pins(NAME, [
		["the first tab's function got the text", (dock._open_tabs[0]["sheet"] as EventSheetResource).functions[0].description,
			"Typed on the first tab."],
		["the second tab's same-named function did not", (dock._open_tabs[1]["sheet"] as EventSheetResource).functions[0].description,
			"The other sheet's."],
		["the Inspector let the first tab's function go", bar._function_inspector != inspector, true],
		["and an object made on the first tab answers nothing on the second",
			inspector.live_function() if inspector != null else "no inspector", null],
	])
	dock.free()
	return ok


## The Shared refusal reads only the code the function compiles to: a template's own {speed} hole,
## a parameter or local named like a variable, a string and a comment are not uses, and a constant
## or static variable is shared already. A real read of the variable is still refused.
static func _test_shared_reads_emitted_code() -> bool:
	var dock: EventSheetDock = _guarded_dock()
	var sheet: EventSheetResource = dock._current_sheet
	for spec: Array in [["speed", false, false], ["amount", false, false], ["LIMIT", true, false], ["count", false, true]]:
		var variable: LocalVariable = LocalVariable.new()
		variable.name = spec[0]
		variable.type = TYPE_INT
		variable.type_name = "int"
		variable.default_value = 1
		variable.is_constant = spec[1]
		variable.is_static = spec[2]
		sheet.events.append(variable)
	sheet.variables["lives"] = {"type": "int", "default": 3, "const": true}
	var jump: EventFunction = sheet.functions[1]
	jump.events.clear()
	var body: EventRow = EventRow.new()
	var move: ACEAction = ACEAction.new()
	move.ace_id = "ProbeMove"
	move.codegen_template = "print({speed})"
	move.params = {"speed": "300"}
	body.actions.append(move)
	jump.events.append(body)
	var inspector: RefCounted = load(INSPECTOR_PATH).new(dock, jump)
	var take_damage: EventFunction = sheet.functions[0]
	var reads: RawCodeRow = RawCodeRow.new()
	reads.code = "var count := amount\nprint(\"health\", LIMIT, lives, count)  # health"
	take_damage.events.append(reads)
	var ok: bool = SUPPORT.pins(NAME, [
		["a template's {speed} hole is not the variable speed", inspector.object_variable_used(jump), ""],
		["a parameter, a local, a string, a comment, a constant and a static are not uses",
			inspector.object_variable_used(take_damage), ""],
	])
	reads.code = "print(self.health)"
	ok = SUPPORT.check(NAME, "self.health is a use", inspector.object_variable_used(take_damage), "health") and ok
	move.params = {"speed": "speed * 2"}
	ok = SUPPORT.check(NAME, "a value that reads speed is a use", inspector.object_variable_used(jump), "speed") and ok
	dock.free()
	return ok


## A default whose type takes more spellings than one literal (a Packed array, a NodePath) is
## GDScript's to judge, and an integer vector fills a float one.
static func _test_defaults_left_to_gdscript() -> bool:
	var dock: EventSheetDock = _guarded_dock()
	var event_function: EventFunction = dock._current_sheet.functions[0]
	var inspector: RefCounted = load(INSPECTOR_PATH).new(dock, event_function)
	var answers: Dictionary = {}
	for spec: Array in [["PackedStringArray", "[]"], ["PackedStringArray", "[\"a\"]"], ["PackedInt32Array", "[1, 2]"],
			["NodePath", "\"a/b\""], ["Vector2", "Vector2i(1, 2)"], ["Vector3", "Vector3i(1, 2, 3)"], ["StringName", "\"jump\""]]:
		event_function.params[1].type_name = spec[0]
		answers["%s = %s" % spec] = inspector.default_problem(1, spec[1])
	event_function.params[1].type_name = "StringName"
	answers["StringName = 5"] = inspector.default_problem(1, "5")
	var ok: bool = SUPPORT.check(NAME, "defaults GDScript accepts are not refused", answers, {
		"PackedStringArray = []": ["", ""], "PackedStringArray = [\"a\"]": ["", ""], "PackedInt32Array = [1, 2]": ["", ""],
		"NodePath = \"a/b\"": ["", ""], "Vector2 = Vector2i(1, 2)": ["", ""], "Vector3 = Vector3i(1, 2, 3)": ["", ""],
		"StringName = \"jump\"": ["", ""],
		"StringName = 5": [EventSheetPopupUI.TONE_ERROR, "\"5\" is not text in quotes (like \"Ready\"), so critical (StringName) cannot start as it. Nothing was changed."],
	})
	dock.free()
	return ok


## The sheet the described fields and the guards are read against: take_damage(amount: int,
## critical: bool = false) -> int with an empty body, beside a jump function, a health variable and a
## died signal; jump calls take_damage once.
static func _guarded_dock() -> EventSheetDock:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var health: LocalVariable = LocalVariable.new()
	health.name = "health"
	health.type = TYPE_INT
	health.type_name = "int"
	health.default_value = 3
	sheet.events.append(health)
	var died: SignalRow = SignalRow.new()
	died.signal_name = "died"
	sheet.events.append(died)
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "take_damage"
	event_function.return_type = TYPE_INT
	for spec: Array in [["amount", "int", ""], ["critical", "bool", "false"]]:
		var param: ACEParam = ACEParam.new()
		param.id = spec[0]
		param.type_name = spec[1]
		param.gdscript_default = spec[2]
		event_function.params.append(param)
	sheet.functions.append(event_function)
	var jump: EventFunction = EventFunction.new()
	jump.function_name = "jump"
	var call: RawCodeRow = RawCodeRow.new()
	call.code = "take_damage(1)"
	jump.events.append(call)
	sheet.functions.append(jump)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	return dock


## Every dropdown describes each choice, the chosen one's sentence follows the pick, and the Inspector
## plugin that draws them claims the function proxy and nothing else.
static func _test_described_fields() -> bool:
	var dock: EventSheetDock = _guarded_dock()
	var inspector: RefCounted = load(INSPECTOR_PATH).new(dock, dock._current_sheet.functions[0])
	inspector.get_property_list()
	var plugin: Script = load(PLUGIN_PATH)
	var dropdown: OptionButton = OptionButton.new()
	plugin.FunctionField.fill_choices(dropdown, inspector.choices("waits"), 1)
	var undescribed: Array = []
	for key: String in ["returns", "in_add_action", "category", "waits", "shared", "param:0:type"]:
		for pair: Array in inspector.choices(key):
			if str(pair[1]).is_empty():
				undescribed.append("%s/%s" % [key, pair[0]])
	var ok: bool = SUPPORT.pins(NAME, [
		["the plugin claims the function proxy", plugin.handles(inspector), true],
		["and no other object", [plugin.handles(Resource.new()), plugin.handles(RefCounted.new()), plugin.handles(null)],
			[false, false, false]],
		["every Inspector property maps to its field", inspector.field_of("Parameters/1/Type"), "param:0:type"],
		["Returns, Category, the Types and the settings are drawn as described dropdowns",
			[plugin.shape_of("returns"), plugin.shape_of("category"), plugin.shape_of("param:0:type"),
				plugin.shape_of("waits"), plugin.shape_of("name"), plugin.shape_of("add_param")],
			["choice", "suggested", "choice", "choice", "text", ""]],
		["no choice of any dropdown goes undescribed", undescribed, []],
		["Returns says what Nothing means, and the line it writes", inspector.choices("returns")[0],
			["Nothing", "Hands nothing back. Use it as an action.", "-> void"]],
		["a parameter Type says what int means, and the parameter it makes", inspector.choices("param:0:type")[1],
			["int", "A whole number: counts, health, coins.", "amount: int = 0"]],
		["Shared says what each choice means, and how it is called", inspector.choices("shared"),
			[["One per object", "Each object runs its own copy and can use its own variables, like health.",
				"node_2d.take_damage(amount, critical)"],
			["One for the script", "Called without picking an object. It cannot read one object's variables, so it suits helpers like maths.",
				"static func take_damage(amount, critical)"]]],
		["Waits shows the call and the await", [inspector.choices("waits")[0][2], inspector.choices("waits")[1][2]],
			["take_damage(amount, critical)", "await take_damage(amount, critical)"]],
		["In Add Action shows the annotation its return type gets", [inspector.choices("in_add_action")[0][2],
			inspector.choices("in_add_action")[1][2]], ["## @ace_hidden", "## @ace_expression"]],
		["a Category shows its annotation", inspector.choices("category")[0][2], "## @ace_category(\"Functions\")"],
		["a category with none is under the default heading", inspector.note("category", ""),
			"The default heading for your own functions."],
		["each item of the drawn dropdown carries its sentence, then its code", dropdown.get_item_tooltip(0),
			"Runs start to end in one frame. Callers carry on straight after.\ntake_damage(amount, critical)"],
		["the sentence alone is what the note under the field keeps", dropdown.get_item_metadata(1),
			"May pause on a Wait (timer, signal, tween). Callers can wait for it to finish before carrying on."],
		["and the chosen one's sentence stays on the field", dropdown.tooltip_text,
			"May pause on a Wait (timer, signal, tween). Callers can wait for it to finish before carrying on.\nawait take_damage(amount, critical)"],
		["each label says what its field is for", inspector.purpose("category"), "The heading it is listed under in Add Action."],
		["a parameter's Type label too", inspector.purpose("param:1:type"), "The kind of value a call passes in for this input."],
	])
	dropdown.free()
	dock.free()
	return ok


## The line under each field: each guard fires on the bad value, in its strength, and is silent (or
## confirms) on a good one; a refused Name or Default writes nothing while its field keeps the typed
## text, and a refused Waits or Shared pick leaves the setting as it was.
static func _test_guards() -> bool:
	var dock: EventSheetDock = _guarded_dock()
	var inspector: RefCounted = load(INSPECTOR_PATH).new(dock, dock._current_sheet.functions[0])
	inspector.get_property_list()
	var refused: String = EventSheetPopupUI.TONE_ERROR
	var hint: String = "hint"
	var ok: bool = SUPPORT.pins(NAME, [
		["a free name says what leaving the field does", inspector.warning("name", "hurt"),
			[EventSheetPopupUI.TONE_OK, "When you leave the field: renames take_damage to hurt, and its 1 calls with it. Ctrl+Z undoes it."]],
		["the function's own name says nothing", inspector.warning("name", "take_damage"), ["", ""]],
		["a name that is not an identifier", inspector.warning("name", "2x"),
			[refused, "\"2x\" cannot be a name: use letters, numbers and _, and do not start with a number. Try _2x. Nothing was changed."]],
		["a name with letters outside a to z", inspector.warning("name", "größe"),
			[refused, "\"größe\" has letters outside a to z. GDScript takes them, but the sheet would open take_damage as code from then on. Try gr__e. Nothing was changed."]],
		["which is why: such a function reopens as code",
			SUPPORT.reopen("extends Node\n\n\nfunc größe() -> void:\n\tpass\n").functions.size(), 0],
		["a GDScript keyword", inspector.warning("name", "func"),
			[refused, "\"func\" is a word GDScript keeps for itself. Try func_2. Nothing was changed."]],
		["another function's name", inspector.warning("name", "jump"),
			[refused, "There is already a function jump on this sheet, so calls could not tell them apart. Try jump_2. Nothing was changed."]],
		["a variable's name", inspector.warning("name", "health"),
			[refused, "\"health\" is already the variable health on this sheet, and two things with one name break the script. Try health_2. Nothing was changed."]],
		["a signal's name", inspector.warning("name", "died"),
			[refused, "\"died\" is already the signal died on this sheet, and two things with one name break the script. Try died_2. Nothing was changed."]],
		["a suggestion is lowercase with _ for the rest", inspector.free_name("Take Damage!"), "take_damage_"],
		["and skips every name already taken", inspector.free_name("Jump"), "jump_2"],
		["a default its type holds passes", inspector.warning("param:1:default", "true"), ["", ""]],
		["a default its type cannot hold", inspector.warning("param:0:default", "abc"),
			[refused, "\"abc\" is not a whole number (like 1), so amount (int) cannot start as it. Nothing was changed."]],
		["a fraction for a whole number", inspector.default_problem(0, "1.5"),
			[refused, "\"1.5\" is not a whole number (like 1), so amount (int) cannot start as it. Nothing was changed."]],
		["a bare word for a bool", inspector.default_problem(1, "yes"),
			[refused, "\"yes\" is not true or false, so critical (bool) cannot start as it. Nothing was changed."]],
		["a whole number for a whole number", inspector.default_problem(0, "1"), ["", ""]],
		["a constant-style word is left to GDScript", inspector.default_problem(1, "DEFAULT_CRIT"), ["", ""]],
		["an expression is left to GDScript", inspector.default_problem(1, "Vector2.ZERO.x > 0"), ["", ""]],
		["a variable of the sheet may be named", inspector.default_problem(0, "health"), ["", ""]],
		["an empty default says the parameter is required", inspector.warning("param:0:default", ""),
			[hint, "Required: every call to take_damage must give amount."]],
	])
	# The order guard reads the parameters around the one typed into.
	var target: EventFunction = dock._current_sheet.functions[0]
	target.params[1].gdscript_default = ""
	ok = SUPPORT.check(NAME, "a default before a required parameter is refused", inspector.warning("param:0:default", "1"),
		[refused, "GDScript needs parameters without a default first, and critical after it has none. Give critical a default too, or move amount down. Nothing was changed."]) and ok
	target.params[0].gdscript_default = "1"
	ok = SUPPORT.check(NAME, "a required parameter after a defaulted one is refused", inspector.warning("param:1:default", ""),
		[refused, "GDScript needs parameters without a default first, and amount before it has one. Give critical a default, or move it up. Nothing was changed."]) and ok
	target.params[0].gdscript_default = ""
	target.params[1].gdscript_default = "false"
	# Returns and Waits are hints about the body.
	ok = SUPPORT.check(NAME, "Returns with no Return in the body", inspector.warning("returns", ""),
		[hint, "take_damage hands back int, but no event in it says Return yet. Add a Return action as its last step, or callers get 0."]) and ok
	var body: EventRow = EventRow.new()
	var give_back: ACEAction = ACEAction.new()
	give_back.ace_id = "ReturnValue"
	body.actions.append(give_back)
	target.events.append(body)
	ok = SUPPORT.check(NAME, "and silent once the body returns", inspector.warning("returns", ""), ["", ""]) and ok
	target.is_async = true
	ok = SUPPORT.check(NAME, "Waits with nothing that waits", inspector.warning("waits", ""),
		[hint, "Nothing in take_damage waits yet, so Can wait only makes callers write await. Add a Wait, or pick Finishes at once."]) and ok
	var pause: RawCodeRow = RawCodeRow.new()
	pause.code = "await get_tree().process_frame\nhealth -= amount"
	body.sub_events.append(pause)
	ok = SUPPORT.check(NAME, "and silent once something in it waits", inspector.warning("waits", ""), ["", ""]) and ok
	# Two picks the body rules out are refused: the setting stays, and the line says why.
	inspector.set("Waits (async)", false)
	inspector.set("Shared (static)", true)
	ok = SUPPORT.pins(NAME, [
		["a function with a Wait inside stays Can wait", target.is_async, true],
		["and says why", inspector.warning("waits", ""),
			[refused, "take_damage has a Wait inside, so it always pauses part way. It stays Can wait; remove the Wait first to change this."]],
		["a function using an object's variable stays One per object", target.is_static, false],
		["and says which variable", inspector.warning("shared", ""),
			[refused, "take_damage uses health, which each object has its own copy of. A shared function cannot reach it, so this stays One per object."]],
		["a parameter Type note reads the type, then its sentence", inspector.note("param:0:type", "int"),
			"int: A whole number: counts, health, coins."],
	]) and ok
	body.sub_events.clear()
	target.is_async = false
	# A refused name or default writes nothing: the sheet compiles to the same bytes, and the field
	# keeps what was typed.
	var before: String = SUPPORT.compile_output(dock._current_sheet)
	inspector.set("Name", "health")
	inspector.set("Parameters/2/Default", "abc")
	ok = SUPPORT.pins(NAME, [
		["a refused name and default write nothing", SUPPORT.compile_output(dock._current_sheet) == before, true],
		["the Name field keeps the typed text", inspector.get("Name"), "health"],
		["the Default field keeps the typed text", inspector.get("Parameters/2/Default"), "abc"],
		["the function keeps its name", (dock._current_sheet.functions[0] as EventFunction).function_name, "take_damage"],
	]) and ok
	inspector.set("Name", "hurt")
	ok = SUPPORT.check(NAME, "a free name typed over a refused one is written",
		(dock._current_sheet.functions[0] as EventFunction).function_name, "hurt") and ok
	dock.free()
	return ok


static func _test_inspector() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "take_damage"
	event_function.description = "Removes health."
	event_function.ace_category = "Player"
	event_function.expose_as_ace = true
	for spec: Array in [["amount", "int", ""], ["critical", "bool", "false"]]:
		var param: ACEParam = ACEParam.new()
		param.id = spec[0]
		param.type_name = spec[1]
		param.gdscript_default = spec[2]
		event_function.params.append(param)
	sheet.functions.append(event_function)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var inspector: RefCounted = load(INSPECTOR_PATH).new(dock, event_function)
	var shown: PackedStringArray = PackedStringArray()
	for property: Dictionary in inspector.get_property_list():
		if int(property.get("usage", 0)) & (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CATEGORY):
			shown.append(str(property.get("name", "")))
	var ok: bool = SUPPORT.pins(NAME, [
		["the Inspector's fields, in the design's order", shown.slice(shown.find("Function take_damage")),
			PackedStringArray(["Function take_damage", "Name", "Description", "Returns", "In Add Action", "Category",
				"Waits (async)", "Shared (static)", "Parameters/1/Name", "Parameters/1/Type", "Parameters/1/Default",
				"Parameters/2/Name", "Parameters/2/Type", "Parameters/2/Default", "Parameters/2/Move Up",
				"Parameters/Add Parameter"])],
		["the Inspector's own undo step is handed back to the funnel", inspector._dont_undo_redo(), true],
		["a parameter shows its name exactly as written", inspector.get("Parameters/1/Name"), "amount"],
		["Returns reads Nothing", inspector.get("Returns"), 0],
		["In Add Action reads the flag", inspector.get("In Add Action"), true],
		["a void function returns Nothing", load(INSPECTOR_PATH).return_word(event_function), "Nothing"],
		["a builtin return word is stored as its type", load(INSPECTOR_PATH).return_fields("float"), [TYPE_FLOAT, ""]],
		["Node rides in the type name", load(INSPECTOR_PATH).return_fields("Node"), [TYPE_MAX, "Node"]],
		["a project class is kept as written", load(INSPECTOR_PATH).return_fields("HealthPool"), [TYPE_MAX, "HealthPool"]],
		["a project class is offered as itself", load(INSPECTOR_PATH).type_words("HealthPool", false)[-1], "HealthPool"],
	])
	# Typed text is held until its field is left, then written once.
	inspector.hold("description", "Hurts a lot.")
	ok = SUPPORT.check(NAME, "a held description is not written yet", inspector.live_function().description, "Removes health.") and ok
	ok = SUPPORT.check(NAME, "but the field shows what was typed", inspector.get("Description"), "Hurts a lot.") and ok
	inspector.commit_pending()
	ok = SUPPORT.check(NAME, "leaving the field writes it", inspector.live_function().description, "Hurts a lot.") and ok
	inspector.set("Returns", 3)
	ok = SUPPORT.check(NAME, "the Returns field writes", CompilerSpellingsProbe.return_name(inspector.live_function()), "float") and ok
	inspector.set("Waits (async)", true)
	ok = SUPPORT.check(NAME, "the Waits field writes is_async", inspector.live_function().is_async, true) and ok
	inspector.set("Parameters/2/Type", 2)
	ok = SUPPORT.check(NAME, "a parameter's Type field writes", inspector.live_function().params[1].type_name, "float") and ok
	inspector.set("Returns", 0)
	inspector.set("Waits (async)", false)
	ok = SUPPORT.check(NAME, "the same return writes nothing", inspector.apply_returns("Nothing"), false) and ok
	ok = SUPPORT.check(NAME, "a new return writes", inspector.apply_returns("float"), true) and ok
	ok = SUPPORT.check(NAME, "the function now returns a float",
		CompilerSpellingsProbe.return_name(inspector.live_function()), "float") and ok
	ok = SUPPORT.check(NAME, "Waits writes is_async", inspector.apply_flag("waits", true), true) and ok
	ok = SUPPORT.check(NAME, "and the function waits", inspector.live_function().is_async, true) and ok
	ok = SUPPORT.check(NAME, "Shared writes is_static", inspector.apply_flag("shared", true), true) and ok
	ok = SUPPORT.check(NAME, "In Add Action off writes", inspector.apply_flag("in_add_action", false), true) and ok
	ok = SUPPORT.check(NAME, "and it is no longer listed", inspector.live_function().expose_as_ace, false) and ok
	ok = SUPPORT.check(NAME, "the same flag again writes nothing", inspector.apply_flag("shared", true), false) and ok
	ok = SUPPORT.check(NAME, "the description field writes", inspector.apply_field("description", "Hurts."), true) and ok
	ok = SUPPORT.check(NAME, "and is stored", inspector.live_function().description, "Hurts.") and ok
	ok = SUPPORT.check(NAME, "a required parameter cannot move behind a defaulted one",
		inspector.move_param(0, 1), false) and ok
	inspector.apply_param_default(0, "2")
	ok = SUPPORT.check(NAME, "a parameter default writes", inspector.live_function().params[0].gdscript_default, "2") and ok
	ok = SUPPORT.check(NAME, "now the parameters may swap", inspector.move_param(1, 0), true) and ok
	ok = SUPPORT.check(NAME, "and they did", [inspector.live_function().params[0].id, inspector.live_function().params[1].id],
		["critical", "amount"]) and ok
	inspector.apply_param_type(1, "float")
	ok = SUPPORT.check(NAME, "a parameter type writes", inspector.live_function().params[1].type_name, "float") and ok
	ok = SUPPORT.check(NAME, "a rename writes", inspector.apply_name("hurt"), true) and ok
	ok = SUPPORT.check(NAME, "and the fields follow the function by its new name", inspector.live_function() != null
		and inspector.live_function().function_name == "hurt", true) and ok
	ok = _test_follow(dock) and ok
	dock.free()
	return ok


## The Properties bar hands the selected function to the Inspector and lets it go once another row is
## selected, writing any text still held on the way out.
static func _test_follow(dock: EventSheetDock) -> bool:
	var view: EventSheetViewport = dock._active_view()
	var bar: EventSheetPropertiesBar = dock._properties_bar
	view.select_resource(dock._current_sheet.functions[0])
	bar.refresh()
	var followed: String = bar._function_inspector._function_name if bar._function_inspector != null else ""
	if bar._function_inspector != null:
		bar._function_inspector.hold("description", "Typed, not yet left.")
	view.clear_selection()
	bar.refresh()
	return SUPPORT.pins(NAME, [
		["selecting the function hands it to the Inspector", followed, "hurt"],
		["selecting nothing lets it go", bar._function_inspector, null],
		["and the text still held is written", (dock._current_sheet.functions[0] as EventFunction).description, "Typed, not yet left."],
	])


static func _test_window() -> bool:
	var parent: Node = Node.new()
	var dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	dialog.init_dialog(parent)
	dialog._name_edit.text = "Take Damage"
	dialog._refresh_studio()
	var probe: Dictionary = EventSheetPopupUI.probe_help_dialog(dialog._dialog)
	var undescribed: int = 0
	for index: int in dialog._usable_option.item_count:
		if dialog._usable_option.get_item_tooltip(index).is_empty():
			undescribed += 1
	var ok: bool = SUPPORT.pins(NAME, [
		["the band shows the row the sheet will draw", dialog._band_label.text, "ƒ  Function  On take_damage → nothing"],
		["the code name sits beside Name", dialog._code_name_label.text, "→ take_damage"],
		["the title carries the live name", dialog._dialog.title, "Create function take_damage"],
		["the kind is ONE dropdown", dialog._usable_option.item_count, 3],
		["every kind is described", undescribed, 0],
		["the window has one help strip", int(probe.get("strips", 0)), 1],
		["IN CODE is the line it writes", str(probe.get("in_code", "")), "func take_damage() -> void"],
	])
	dialog._usable_option.select(2)
	dialog._select_usable(2)
	ok = SUPPORT.check(NAME, "an Expression returns its value type in the band", dialog._band_label.text,
		"ƒ  Function  On take_damage → float") and ok
	parent.free()
	return ok


## The compiler's spelling of a function's return, without naming the preload in a test.
class CompilerSpellingsProbe:
	static func return_name(event_function: EventFunction) -> String:
		return SheetCompiler._function_return_type_name(event_function) if event_function != null else ""
