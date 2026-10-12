# Godot EventSheets - the rows new to the vocabulary: Tell Children, First Parent Of Type, Next
# Sibling and Previous Sibling, Reset Variable and Reset Variables, and Distance Travelled.
#
# Each is filed beside the row it is the sibling or the mirror of, so this test asks five things:
#   1. THE ROW. Its id, kind, name, page, fields, template and reading, pinned as text.
#   2. THE ROWS BESIDE IT are unchanged, character for character.
#   3. WHAT THE LINE DOES. The emitted code is run against a real tree, and its answer pinned.
#   4. WHAT COMES BACK. A sheet holding the row is compiled, opened again the way the editor opens a
#      `.gd`, and pinned to re-emit byte for byte - Tell Children reading back as itself, and the two
#      Reset rows reading back as the Set value row their line is.
#   5. THE FAMILIAR NAMES find them, and the dialog says which row wrote a reset line.
@tool
class_name BorrowedNewRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "borrowed_new_rows_test"


static func run() -> bool:
	var ok: bool = _the_rows()
	ok = _the_rows_beside_them() and ok
	ok = _telling_children() and ok
	ok = _the_first_parent() and ok
	ok = _the_siblings() and ok
	ok = _putting_variables_back() and ok
	ok = _the_distance_travelled() and ok
	ok = _the_familiar_names() and ok
	return ok


## Every new row as one line of text: kind|name|page|fields|template|reading.
static func _the_rows() -> bool:
	var rows: Array = []
	var expected: Dictionary = {
		"TellChildren": "action|Tell Children|Groups|method,args,target|{target.}propagate_call({method}{, args})|tell [i]{target}[/i] and everything under it to [b]{method}[/b]",
		"FirstParentOfType": "expression|First Parent Of Type|Nodes: Picking|target,type|__eventsheets_first_parent_of_type({target}, {type})|the first [b]{type}[/b] above [i]{target}[/i]",
		"NextSibling": "expression|Next Sibling|Nodes|target|{target}.get_parent().get_child(({target}.get_index() + 1) % {target}.get_parent().get_child_count())|the sibling after [i]{target}[/i]",
		"PreviousSibling": "expression|Previous Sibling|Nodes|target|{target}.get_parent().get_child(posmod({target}.get_index() - 1, {target}.get_parent().get_child_count()))|the sibling before [i]{target}[/i]",
		"ResetVariable": "action|Reset Variable|Variables|var_name|{var_name} = {starting_value}|Put {var_name} back to its starting value",
		"ResetVariables": "action|Reset Variables|Variables||{every_starting_value}|Put every variable back to its starting value",
		"DistanceTravelled": "expression|Distance Travelled|General Expressions||_travelled|how far this has travelled",
	}
	for ace_id: String in expected:
		rows.append([ace_id, _row_text(ace_id), expected[ace_id]])
	rows.append(["the Reset rows stay out of the reverse index, like Set boolean",
		[EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("ResetVariable"),
			EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("ResetVariables")], [true, true]])
	return SUPPORT.pins(P, rows)


## The rows these stand beside, as they shipped.
static func _the_rows_beside_them() -> bool:
	return SUPPORT.pins(P, [
		["Call Method On Group (with value)", _template("CallGroupWith"), "get_tree().call_group({group}, {method}{, args})"],
		["First Child Of Type", _template("FirstChildOfType"), "{target}.find_children(\"*\", {type}, true, false).pop_front()"],
		["Index In Parent", _template("GetIndexInParent"), "{target}.get_index()"],
		["Set value", _template("SetVar"), "{var_name} = {value}"],
		["Set boolean", _template("SetBool"), "{var_name} = {value}"],
		["Get Velocity", _template("GetVelocity2D"), "{target.}velocity"],
	])


static func _telling_children() -> bool:
	var rows: Array = []
	rows.append(["blank sends no values", _filled("TellChildren", {"target": "$Door", "method": "\"open\""}), "$Door.propagate_call(\"open\")"])
	rows.append(["blank On node is this node", _filled("TellChildren", {"method": "\"reset\""}), "propagate_call(\"reset\")"])
	rows.append(["values ride as the list", _filled("TellChildren", {"target": "$Door", "method": "\"open\"", "args": "[2]"}),
		"$Door.propagate_call(\"open\", [2])"])
	# Run against a real branch: the door and both of its descendants are told, its sibling is not.
	var listener: GDScript = GDScript.new()
	listener.source_code = "extends Node\n\nvar told: Array = []\n\n\nfunc open(amount: int = 1) -> void:\n\ttold.append(amount)\n"
	listener.reload()
	var level: Node = Node.new()
	var door: Node = _child(level, "Door", listener)
	var handle: Node = _child(door, "Handle", listener)
	var light: Node = _child(handle, "Light", listener)
	_child(door, "Plain", null)
	var window: Node = _child(level, "Window", listener)
	var runner: GDScript = GDScript.new()
	runner.source_code = "extends RefCounted\n\n\nfunc answer(door: Node) -> void:\n\t%s\n" % _filled("TellChildren", {"target": "door", "method": "\"open\"", "args": "[3]"})
	rows.append(["the line parses", runner.reload(), OK])
	if runner.can_instantiate():
		runner.new().call("answer", door)
	rows.append(["the door, its handle and the handle's light are told",
		[door.get("told"), handle.get("told"), light.get("told")], [[3], [3], [3]]])
	rows.append(["the door's sibling is not", window.get("told"), []])
	level.free()
	var source: String = _compiled([_action("TellChildren", {"target": "$Door", "method": "\"open\"", "args": ""})])
	rows.append(["it compiles to the one line", source.contains("\t$Door.propagate_call(\"open\")\n"), true])
	rows.append(["and reads back as itself", _lifted_ids(source).has("TellChildren"), true])
	rows.append(["and re-emits byte for byte", SUPPORT.reemit(source, "user://borrowed_tell_children_roundtrip.gd"), source])
	var typed: String = "extends Node\n\n\nfunc _ready() -> void:\n\t$Door.propagate_call(\"open\", [2])\n"
	rows.append(["the line typed by hand reads as the row", _lifted_ids(typed).has("TellChildren"), true])
	rows.append(["and re-emits byte for byte", SUPPORT.reemit(typed, "user://borrowed_tell_children_typed.gd"), typed])
	return SUPPORT.pins(P, rows)


static func _the_first_parent() -> bool:
	var rows: Array = []
	var asked: String = _filled("FirstParentOfType", {"target": "$Chest", "type": "\"Room\""})
	rows.append(["the row is one call to the walk", asked, "__eventsheets_first_parent_of_type($Chest, \"Room\")"])
	var source: String = _compiled([_action("SetLocalVar", {"name": "room", "value": asked})])
	rows.append(["the walk is written into the file", source.contains("func __eventsheets_first_parent_of_type(from: Node, type: String) -> Node:"), true])
	rows.append(["once, though two rows ask", _compiled([_action("SetLocalVar", {"name": "a", "value": asked}),
		_action("SetLocalVar", {"name": "b", "value": asked})]).count("func __eventsheets_first_parent_of_type("), 1])
	rows.append(["a file that asks nothing gains nothing", _compiled([_action("PrintLog", {"message": "\"hi\""})]).contains("__eventsheets_first_parent"), false])
	rows.append(["the file re-emits byte for byte", SUPPORT.reemit(source, "user://borrowed_first_parent_roundtrip.gd"), source])
	# The walk itself, run against a tree: an engine class, the closest of several, and a class_name
	# found up a script's own chain.
	var walker: GDScript = GDScript.new()
	walker.source_code = "extends RefCounted\n\n%s\n" % _helper_text(source)
	rows.append(["the walk parses", walker.reload(), OK])
	var room_script: GDScript = _script_file("user://borrowed_room.gd", "class_name BorrowedTestRoom\nextends Node\n")
	var side_room_script: GDScript = _script_file("user://borrowed_side_room.gd", "extends \"user://borrowed_room.gd\"\n")
	var level: Node2D = Node2D.new()
	var room: Node = _child(level, "Room", room_script)
	var box: Control = Control.new()
	room.add_child(box)
	var chest: Node = _child(box, "Chest", null)
	var annex: Node = _child(chest, "Annex", side_room_script)
	var key: Node = _child(annex, "Key", null)
	if walker.can_instantiate():
		var walk: Object = walker.new()
		rows.append(["the first Node2D above the chest is the level", walk.call("__eventsheets_first_parent_of_type", chest, "Node2D") == level, true])
		rows.append(["the first Node above is the closest one", walk.call("__eventsheets_first_parent_of_type", chest, "Node") == box, true])
		rows.append(["a class_name is found", walk.call("__eventsheets_first_parent_of_type", chest, "BorrowedTestRoom") == room, true])
		rows.append(["and found up a script's chain too", walk.call("__eventsheets_first_parent_of_type", key, "BorrowedTestRoom") == annex, true])
		rows.append(["a node is never its own ancestor", walk.call("__eventsheets_first_parent_of_type", box, "Control"), null])
		rows.append(["nothing of that type above is null", walk.call("__eventsheets_first_parent_of_type", chest, "Sprite2D"), null])
	level.free()
	return SUPPORT.pins(P, rows)


static func _the_siblings() -> bool:
	var rows: Array = []
	var shelf: Node = Node.new()
	var first: Node = _child(shelf, "First", null)
	var middle: Node = _child(shelf, "Middle", null)
	var last: Node = _child(shelf, "Last", null)
	var runner: GDScript = GDScript.new()
	runner.source_code = "extends RefCounted\n\n\nfunc after(slot: Node) -> Node:\n\treturn %s\n\n\nfunc before(slot: Node) -> Node:\n\treturn %s\n" % [
		_filled("NextSibling", {"target": "slot"}), _filled("PreviousSibling", {"target": "slot"})]
	rows.append(["both lines parse", runner.reload(), OK])
	if runner.can_instantiate():
		var ask: Object = runner.new()
		rows.append(["after the first is the middle", ask.call("after", first) == middle, true])
		rows.append(["after the last wraps to the first", ask.call("after", last) == first, true])
		rows.append(["before the middle is the first", ask.call("before", middle) == first, true])
		rows.append(["before the first wraps to the last", ask.call("before", first) == last, true])
		var only: Node = Node.new()
		var alone: Node = _child(only, "Alone", null)
		rows.append(["an only child is its own neighbour", [ask.call("after", alone) == alone, ask.call("before", alone) == alone], [true, true]])
		only.free()
	shelf.free()
	var source: String = _compiled([_action("SetLocalVar", {"name": "next_slot", "value": _filled("NextSibling", {"target": "$Slot"})}),
		_action("SetLocalVar", {"name": "last_slot", "value": _filled("PreviousSibling", {"target": "$Slot"})})])
	rows.append(["a file using both re-emits byte for byte", SUPPORT.reemit(source, "user://borrowed_siblings_roundtrip.gd"), source])
	return SUPPORT.pins(P, rows)


static func _putting_variables_back() -> bool:
	var rows: Array = []
	# The declarations a file holds, and the two Reset rows under one event.
	var typed: String = "extends Node\n\n@export var speed: float = 3.0\nvar health: int = 100\nvar label_text := \"ready\"\nvar lives: int\nconst MAX_LIVES: int = 3\n\n\nfunc _ready() -> void:\n\tprint(\"go\")\n"
	var sheet: EventSheetResource = SUPPORT.reopen(typed)
	var starting: Dictionary = SheetCompiler.declared_starting_values(sheet)
	rows.append(["what each declaration starts on", starting, {
		"speed": {"value": "3.0", "every": false},
		"health": {"value": "100", "every": true},
		"label_text": {"value": "\"ready\"", "every": true},
		"lives": {"value": "0", "every": true}}])
	var event: EventRow = _first_event(sheet)
	if event != null:
		event.actions.append(_action("ResetVariable", {"var_name": "health"}))
		event.actions.append(_action("ResetVariable", {"var_name": "speed"}))
		event.actions.append(_action("ResetVariables", {}))
		event.actions.append(_action("ResetVariable", {"var_name": "mana"}))
	sheet.external_source_path = "user://borrowed_reset.gd"
	var result: Dictionary = SheetCompiler.compile(sheet, "user://borrowed_reset.gd")
	var output: String = str(result.get("output", ""))
	rows.append(["each Reset writes the declared value", output,
		"extends Node\n\n@export var speed: float = 3.0\nvar health: int = 100\nvar label_text := \"ready\"\nvar lives: int\nconst MAX_LIVES: int = 3\n\n\nfunc _ready() -> void:\n\tprint(\"go\")\n\thealth = 100\n\tspeed = 3.0\n\thealth = 100\n\tlabel_text = \"ready\"\n\tlives = 0\n"])
	rows.append(["a variable the sheet does not declare writes nothing, and says so",
		(result.get("warnings", []) as Array).has("Reset Variable: mana is not declared on this sheet, so there is no starting value to put back - the row writes nothing."), true])
	rows.append(["the working state is cleared after the compile", ActionCodegen.starting_values, {}])
	var parsed: GDScript = GDScript.new()
	parsed.source_code = output
	rows.append(["the file parses", parsed.reload(), OK])
	# Reopened, the reset lines are the Set value rows they are, and the file comes back unchanged.
	var reopened_ids: PackedStringArray = _lifted_ids(output)
	rows.append(["it reopens as Set value rows, never as Reset", [reopened_ids.count("SetVar") >= 5, reopened_ids.has("ResetVariable"), reopened_ids.has("ResetVariables")], [true, false, false]])
	rows.append(["and re-emits byte for byte", SUPPORT.reemit(output, "user://borrowed_reset_roundtrip.gd"), output])
	# The sheet's own variables, on the generated path.
	var made: EventSheetResource = EventSheetResource.new()
	made.variables = {"score": {"type": "int", "default": 0, "exported": false}, "volume": {"type": "float", "default": 0.5, "exported": true}}
	var round_start: EventRow = EventRow.new()
	round_start.trigger_provider_id = "Core"
	round_start.trigger_id = "OnReady"
	round_start.actions.append(_action("ResetVariables", {}))
	made.events.append(round_start)
	rows.append(["on a sheet's own variables, every one that is not exported",
		SUPPORT.compile_output(made, "user://borrowed_reset_made.gd").contains("func _ready() -> void:\n\tscore = 0\n"), true])
	# The dialog's two readings: the line a Reset row will write, and the note on a Set row that holds it.
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var reset_definition: ACEDefinition = registry.find_definition("Core", "ResetVariable")
	var set_definition: ACEDefinition = registry.find_definition("Core", "SetVar")
	rows.append(["the dialog shows the line the Reset row will write",
		ACEParamsDialog.row_code_line(reset_definition, {"var_name": "health"}, starting), "health = 100"])
	rows.append(["and nothing it cannot know",
		ACEParamsDialog.row_code_line(reset_definition, {"var_name": "mana"}, starting), ""])
	rows.append(["a Set row holding the starting value says the Reset row wrote it",
		ACEParamsDialog.reset_reading(set_definition, {"var_name": "health", "value": "100"}, starting),
		"health back to its starting value - the line Reset Variable writes"])
	rows.append(["any other value says nothing",
		ACEParamsDialog.reset_reading(set_definition, {"var_name": "health", "value": "50"}, starting), ""])
	return SUPPORT.pins(P, rows)


static func _the_distance_travelled() -> bool:
	var rows: Array = []
	var read: ACEAction = _action("PrintLog", {"message": "_travelled"})
	var character: String = _compiled([read], "CharacterBody2D", "OnProcess")
	rows.append(["a character keeps the total from its real velocity", character,
		"extends CharacterBody2D\n\nvar _travelled: float = 0.0\n\nfunc _process(delta: float) -> void:\n\tprint(_travelled)\n\nfunc _physics_process(delta: float) -> void:\n\t_travelled += get_real_velocity().length() * delta\n"])
	var parsed: GDScript = GDScript.new()
	parsed.source_code = character
	rows.append(["the file parses", parsed.reload(), OK])
	rows.append(["and re-emits byte for byte", SUPPORT.reemit(character, "user://borrowed_travelled_roundtrip.gd"), character])
	var rigid: String = _compiled([read], "RigidBody3D", "OnProcess")
	rows.append(["a rigid body adds up its linear velocity", rigid.contains("\t_travelled += linear_velocity.length() * delta\n"), true])
	var physics: String = _compiled([read], "CharacterBody3D", "OnPhysicsProcess")
	rows.append(["a physics function the file has gets the line first",
		physics.contains("func _physics_process(delta: float) -> void:\n\t_travelled += get_real_velocity().length() * delta\n\tprint(_travelled)\n"), true])
	rows.append(["and only one physics function", physics.count("func _physics_process("), 1])
	rows.append(["that file re-emits byte for byte too", SUPPORT.reemit(physics, "user://borrowed_travelled_physics_roundtrip.gd"), physics])
	var unread: String = _compiled([_action("PrintLog", {"message": "distance_travelled"})], "CharacterBody2D", "OnProcess")
	rows.append(["a longer name is not a read of it", unread.contains("var _travelled"), false])
	var plain: EventSheetResource = _sheet([read], "Node2D", "OnProcess")
	var plain_result: Dictionary = SheetCompiler.compile(plain, "user://borrowed_travelled_plain.gd", true)
	rows.append(["a host with no velocity is told so",
		(plain_result.get("warnings", []) as Array).has("Distance Travelled: a Node2D has no velocity of its own, so the total stays at 0 - put this sheet on a CharacterBody or a RigidBody."), true])
	rows.append(["and its file still parses", str(plain_result.get("output", "")).contains("var _travelled: float = 0.0"), true])
	return SUPPORT.pins(P, rows)


static func _the_familiar_names() -> bool:
	return SUPPORT.pins(P, [
		["BroadcastMessage", ACEPickerDialog.foreign_query_matches("BroadcastMessage"), {"TellChildren": "BroadcastMessage"}],
		["Pick children", ACEPickerDialog.foreign_query_matches("pick children"), {"TellChildren": "Pick children"}],
		["GetComponentInParent", ACEPickerDialog.foreign_query_matches("GetComponentInParent"), {"FirstParentOfType": "GetComponentInParent"}],
		["Pick parent", ACEPickerDialog.foreign_query_matches("pick parent"), {"FirstParentOfType": "Pick parent"}],
		["Get Next Sibling", ACEPickerDialog.foreign_query_matches("get next sibling"), {"NextSibling": "Get Next Sibling"}],
		["Reset global variable", ACEPickerDialog.foreign_query_matches("reset global variable"), {"ResetVariable": "Reset global variable"}],
		["Reset global variables", ACEPickerDialog.foreign_query_matches("reset global variables"),
			{"ResetVariable": "Reset global variable", "ResetVariables": "Reset global variables"}],
		["Odometer", ACEPickerDialog.foreign_query_matches("odometer"), {"DistanceTravelled": "Odometer"}],
	])


# ── helpers ──────────────────────────────────────────────────────────────────────────────────


static func _row_text(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return "missing"
	var fields: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		fields.append(str(parameter.id))
	var kind: String = "expression"
	if descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
		kind = "condition"
	elif descriptor.ace_type == ACEDescriptor.ACEType.ACTION:
		kind = "action"
	return "%s|%s|%s|%s|%s|%s" % [kind, descriptor.display_name, descriptor.category, ",".join(fields),
		descriptor.codegen_template, descriptor.display_text]


static func _template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return "" if descriptor == null else str(descriptor.codegen_template)


## A template with the given values and every other field on its default.
static func _filled(ace_id: String, values: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var filled: Dictionary = {}
	for parameter: ACEParam in descriptor.params:
		filled[str(parameter.id)] = str(parameter.default_value)
	filled.merge(values, true)
	return ActionCodegen._apply_template(descriptor.codegen_template, filled)


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var filled: Dictionary = {}
	if descriptor != null:
		for parameter: ACEParam in descriptor.params:
			filled[str(parameter.id)] = str(parameter.default_value)
		action.codegen_template = descriptor.codegen_template
	filled.merge(params, true)
	action.params = filled
	return action


static func _sheet(actions: Array, host_class: String = "Node", trigger_id: String = "OnReady") -> EventSheetResource:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = host_class
	sheet.events.append(event)
	return sheet


## One sheet holding the actions under a trigger, compiled without the generated banner - the file a
## reader saves as their own `.gd`, which is the one that is opened again.
static func _compiled(actions: Array, host_class: String = "Node", trigger_id: String = "OnReady") -> String:
	var result: Dictionary = SheetCompiler.compile(_sheet(actions, host_class, trigger_id), "user://borrowed_new_rows.gd", true)
	return str(result.get("output", ""))


static func _child(parent: Node, child_name: String, script: Script) -> Node:
	var child: Node = Node.new()
	child.name = child_name
	if script != null:
		child.set_script(script)
	parent.add_child(child)
	return child


## A script written to a real file and loaded from it, so its class_name and its base are read the
## way the engine reads any script's.
static func _script_file(path: String, source: String) -> GDScript:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(source)
		file.close()
	return ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE) as GDScript


## The walk's own definition out of a compiled file: its head and the indented lines under it.
static func _helper_text(source: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	var inside: bool = false
	for line: String in source.split("\n"):
		if line.begins_with("func __eventsheets_first_parent_of_type("):
			inside = true
		elif inside and not line.begins_with("\t"):
			break
		if inside:
			kept.append(line)
	return "\n".join(kept)


static func _first_event(sheet: EventSheetResource) -> EventRow:
	if sheet == null:
		return null
	for item: Variant in sheet.events:
		if item is EventRow:
			return item as EventRow
	return null


## The ace_ids every action and condition of a reopened source lifted to, walking sub-events too.
static func _lifted_ids(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	if reopened != null:
		for item: Variant in reopened.events:
			_collect_ids(item, found)
	return found


static func _collect_ids(item: Variant, found: PackedStringArray) -> void:
	if item is EventGroup:
		for inner: Variant in (item as EventGroup).events:
			_collect_ids(inner, found)
		return
	if not (item is EventRow):
		return
	var row: EventRow = item as EventRow
	for condition: Variant in row.conditions:
		if condition is ACECondition:
			found.append(str((condition as ACECondition).ace_id))
	for action: Variant in row.actions:
		if action is ACEAction:
			found.append(str((action as ACEAction).ace_id))
	for sub: Variant in row.sub_events:
		_collect_ids(sub, found)
