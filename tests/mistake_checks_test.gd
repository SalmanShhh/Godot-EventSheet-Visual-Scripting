# Godot EventSheets - the nine mistake checks, each pinned to fire when it should and stay quiet when it should.
#
# Every sentence a check says was first checked against a real Godot 4.7 run (what a wrong signal
# value count does, what a missing path does, whole-number and decimal division by zero, a local over
# a parameter), so these pins hold the WORDS to what the engine really does, not to a belief about it.
#
# The scene the node checks are judged against is tests/fixtures/mistake_level.tscn: a Level (Node2D)
# with Score (Label), Sprite (AnimatedSprite2D), Enemy (in the group "enemies"), Player, and a Hud with
# a scene-unique Health. A sheet is judged against it by passing the fixture script's path, which is
# how the editor finds the scene a sheet's file runs in.
@tool
class_name MistakeChecksTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "mistake_checks"

## The script the fixture scene runs, and the folder a path check can look beside.
const LEVEL := "res://tests/fixtures/mistake_level.gd"
const LEVEL_SCENE := "res://tests/fixtures/mistake_level.tscn"

## The warm pass over the biggest pack, with about three times the measured headroom.
const PACK_BUDGET_MS: float = 250.0


static func run() -> bool:
	EventSheetSceneConnections.clear_cache()
	EventSheetSceneLights.clear_cache()
	EventSheetMistakeFindings.clear_cache()
	EventSheetInputMapFacts.clear_cache()
	# The groups are judged against the fixtures alone, so a group the rest of the project has (the
	# README example's "enemy") cannot become the nearest name to the typo the pins use.
	EventSheetMistakeFindings.limit_group_scan_to(PackedStringArray(["res://tests/fixtures/"]))
	var ok: bool = true
	ok = _node_type_pins() and ok
	ok = _path_pins() and ok
	ok = _group_pins() and ok
	ok = _input_pins() and ok
	ok = _node_path_pins() and ok
	ok = _signal_pins() and ok
	ok = _while_pins() and ok
	ok = _shadow_pins() and ok
	ok = _division_pins() and ok
	ok = _memory_pins() and ok
	ok = _shape_pins() and ok
	ok = _budget_pins() and ok
	EventSheetMistakeFindings.limit_group_scan_to(PackedStringArray())
	return ok


## The findings of a sheet reopened from source, as [kind, severity, subject] rows.
static func _rows(source: String, script_path: String = LEVEL) -> Array:
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, script_path)
	var rows: Array = []
	for finding: Dictionary in EventSheetMistakeFindings.findings(sheet, script_path):
		rows.append([finding["kind"], finding["severity"], finding["subject"]])
	return rows


static func _kinds(source: String, script_path: String = LEVEL) -> Array:
	var kinds: Array = []
	for row: Array in _rows(source, script_path):
		kinds.append(row[0])
	return kinds


## A sheet holding one event with one action built by hand - the way a picked row is stored.
static func _sheet_with(provider: String, ace_id: String, params: Dictionary) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event_row: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = provider
	action.ace_id = ace_id
	action.params = params
	event_row.actions = [action]
	sheet.events = [event_row]
	return sheet


## A sheet holding one event whose actions are verbatim blocks, in order.
static func _sheet_with_raw(blocks: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event_row: EventRow = EventRow.new()
	for block: Variant in blocks:
		var raw: RawCodeRow = RawCodeRow.new()
		raw.code = str(block)
		event_row.actions.append(raw)
	sheet.events = [event_row]
	return sheet


static func _node_type_pins() -> bool:
	var label: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "PlaySpriteAnimation", {"anim": "\"pop\"", "target": "$Score"}), LEVEL)
	var sprite: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "PlaySpriteAnimation", {"anim": "\"pop\"", "target": "$Sprite"}), LEVEL)
	var on_self: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "PlaySpriteAnimation", {"anim": "\"pop\""}), LEVEL)
	var no_scene: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "PlaySpriteAnimation", {"anim": "\"pop\"", "target": "$Score"}), "")
	var by_variable: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "PlaySpriteAnimation", {"anim": "\"pop\"", "target": "some_node"}), LEVEL)
	var scripted: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "PlaySpriteAnimation", {"anim": "\"pop\"", "target": "$Boss"}), LEVEL)
	var property_bad: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "SetSpriteFrame", {"frame": "2", "target": "$Score"}), LEVEL)
	var property_good: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "SetSpriteFrame", {"frame": "2", "target": "$Sprite"}), LEVEL)
	var shared_member: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with("Core", "SetFlipH", {"flipped": "true", "target": "$Sprite"}), LEVEL)
	var on_self_words: String = String(EventSheetMistakeFindings.findings(
		_sheet_with("Core", "PlaySpriteAnimation", {"anim": "\"pop\""}), LEVEL)[0]["message"])
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a node with a script of its own is never judged: the script may add the member", _brief(scripted), []],
		["a property the node's class lacks is judged the same way", _brief(property_bad), [["wrong-node-type", "error", "Score"]]],
		["and the property on the right class is quiet", _brief(property_good), []],
		["a member the class has (flip_h on an AnimatedSprite2D) is quiet", _brief(shared_member), []],
		["the sentence names the missing member", String(property_bad[0]["message"]).contains("no \"frame\""), true],
		["a row on this node says the script does not load", on_self_words.contains("does not load"), true],
		["an animation row on a Label is an error, named by the node", _brief(label), [["wrong-node-type", "error", "Score"]]],
		["and the strip's door points at the scene's own AnimatedSprite2D", [label[0]["fix"], label[0]["to"]], ["point_at_node", "$Sprite"]],
		["the same row on the AnimatedSprite2D is quiet", _brief(sprite), []],
		["a row on this node judges this node's class (a Node2D has no play)", _brief(on_self), [["wrong-node-type", "error", "this node"]]],
		["a sheet no scene runs is never judged", _brief(no_scene), []],
		["a node held in a variable is never judged", _brief(by_variable), []],
	])
	return SUPPORT.check(TEST_NAME, "the sentence says what Godot does", String(label[0]["message"]).contains("Nonexistent function"), true) and ok


static func _brief(found: Array[Dictionary]) -> Array:
	var brief: Array = []
	for finding: Dictionary in found:
		brief.append([finding["kind"], finding["severity"], finding["subject"]])
	return brief


static func _path_pins() -> bool:
	var missing: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tvar scene = load(\"res://tests/fixtures/mistake_nope.tscn\")\n")
	var present: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tvar scene = load(\"res://tests/fixtures/mistake_level.tscn\")\n")
	var built: Array = _rows("extends Node2D\n\nfunc go(name: String) -> void:\n\tvar scene = load(\"res://tests/fixtures/\" + name + \".tscn\")\n")
	var folder: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tprint(\"res://tests/fixtures/\")\n")
	var as_text: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tprint(\"res://tests/fixtures/mistake_nope.tscn\")\n\tvar table = [\"res://tests/fixtures/mistake_nope.tscn\"]\n")
	var user: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tvar f = FileAccess.open(\"user://nothing_here.json\", FileAccess.READ)\n")
	var const_row: Array = _rows("extends Node2D\n\nconst COIN := preload(\"res://tests/fixtures/mistake_coin.tscn\")\n")
	var sheet: EventSheetResource = SUPPORT.reopen("extends Node2D\n\nfunc go() -> void:\n\tvar scene = load(\"res://tests/fixtures/mistake_levl.tscn\")\n", true, LEVEL)
	var near: Array[Dictionary] = EventSheetMistakeFindings.findings(sheet, LEVEL)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a literal res:// path nobody has is an error", missing, [["path-not-in-project", "error", "res://tests/fixtures/mistake_nope.tscn"]]],
		["a path that is there is quiet", present, []],
		["a path built at run time is never judged", built, []],
		["a folder is never judged", folder, []],
		["a path in a message or a table is data, not a load", as_text, []],
		["a user:// path is never judged", user, []],
		["a const's preload is judged on the block row it sits on", const_row, [["path-not-in-project", "error", "COIN"]]],
		["the closest file in the same folder is offered", near[0]["to"], "res://tests/fixtures/mistake_level.tscn"],
	])
	return ok


static func _group_pins() -> bool:
	EventSheetMistakeFindings.clear_cache()
	var typo: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tfor node in get_tree().get_nodes_in_group(\"enemys\"):\n\t\tnode.queue_free()\n")
	var in_scene: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tfor node in get_tree().get_nodes_in_group(\"enemies\"):\n\t\tnode.queue_free()\n")
	var in_code: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tfor node in get_tree().get_nodes_in_group(\"mistake_recruits\"):\n\t\tnode.queue_free()\n")
	var own: Array = _rows("extends Node2D\n\nfunc _ready() -> void:\n\tadd_to_group(\"fresh_group\")\n\nfunc go() -> void:\n\tprint(get_tree().get_nodes_in_group(\"fresh_group\"))\n")
	var dynamic: Array = _rows("extends Node2D\n\nfunc go(name: String) -> void:\n\tprint(get_tree().get_nodes_in_group(name))\n")
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(SUPPORT.reopen("extends Node2D\n\nfunc go() -> void:\n\tfor node in get_tree().get_nodes_in_group(\"enemys\"):\n\t\tnode.queue_free()\n", true, LEVEL), LEVEL)
	return SUPPORT.pins(TEST_NAME, [
		["a group nothing is in is a warning", typo, [["group-nothing-is-in", "warning", "enemys"]]],
		["a group a scene has is quiet", in_scene, []],
		["a group a script adds is quiet", in_code, []],
		["a group the sheet adds itself is quiet", own, []],
		["a group named by a variable is never judged", dynamic, []],
		["the near name is offered", found[0]["to"], "enemies"],
		["and the sentence says nothing is printed", String(found[0]["message"]).contains("Godot prints nothing"), true],
	])


static func _input_pins() -> bool:
	var wrong_case: Array = _rows("extends Node2D\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif event.is_action_pressed(\"UI_LEFT\"):\n\t\tpass\n")
	var right: Array = _rows("extends Node2D\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif event.is_action_pressed(\"ui_left\"):\n\t\tpass\n")
	var polled: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tif Input.is_action_pressed(\"mistake_dash\"):\n\t\tpass\n")
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(SUPPORT.reopen("extends Node2D\n\nfunc go() -> void:\n\tif Input.is_action_pressed(\"UI_LEFT\"):\n\t\tpass\n", true, LEVEL), LEVEL)
	var guard: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tif InputMap.has_action(\"mistake_ghost\"):\n\t\tpass\n")
	var made: Array = _rows("extends Node2D\n\nfunc _ready() -> void:\n\tInputMap.add_action(\"mistake_made\")\n\nfunc go() -> void:\n\tif Input.is_action_pressed(\"mistake_made\"):\n\t\tpass\n")
	var beside: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tInput.mouse_mode = Input.MOUSE_MODE_CAPTURED\n\tprint(\"Gamepad %d connected\" % Input.get_connected_joypads().size())\n")
	var axis: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tvar v := Input.get_vector(\"mistake_l\", \"ui_right\", \"ui_up\", \"ui_down\")\n")
	return SUPPORT.pins(TEST_NAME, [
		["an InputMap.has_action guard is not a use", guard, []],
		["an action the sheet adds itself is not missing", made, []],
		["a string beside an Input call is not a control", beside, []],
		["every action of get_vector is read, and only the missing one is said", axis, [["input-action-not-in-map", "warning", "mistake_l"]]],
		["a control the map lacks is a warning on the row", wrong_case.size() > 0 and wrong_case[0][1] == "warning", true],
		["names are case-sensitive and the near one is offered", [found[0]["subject"], found[0]["to"]], ["UI_LEFT", "ui_left"]],
		["a control the map has is quiet", right, []],
		["a polled control is checked the same way", polled, [["input-action-not-in-map", "warning", "mistake_dash"]]],
		["the doors are the Doctor's: use, add, pick", [found[0]["fix"], found[0]["second_fix"], found[0]["third_fix"]], ["use_the_name", "add_input_action", "pick_input_action"]],
		["the sentence says what Godot prints", String(found[0]["message"]).contains("doesn't exist"), true],
	])


static func _node_path_pins() -> bool:
	var typo: Array = _rows("extends Node2D\n\nfunc _physics_process(delta: float) -> void:\n\t$Player.look_at($Enmy.global_position)\n")
	var right: Array = _rows("extends Node2D\n\nfunc _physics_process(delta: float) -> void:\n\t$Player.look_at($Enemy.global_position)\n")
	var deep: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\t$Hud/Health.value = 3\n")
	var unique_ok: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\t%Health.value = 3\n")
	var unique_bad: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\t%Healt.value = 3\n")
	var modulo: Array = _rows("extends Node2D\n\nfunc go(a: int, b: int) -> void:\n\tvar c = a %b\n\tvar d = \"%s\" % b\n")
	var inside: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\t$Hud/Health/Deeper.value = 3\n")
	var wrapped: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tprint(\"hp: %s\\nmore: %d\" % [$Player.name, 1])\n\tprint(\"multi\n%s line\" % $Player.name)\n")
	var named: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tvar n := Node2D.new()\n\tn.name = \"Spawned\"\n\tadd_child(n)\n\t$Spawned.visible = false\n")
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(SUPPORT.reopen("extends Node2D\n\nfunc go() -> void:\n\t$Player.look_at($Enmy.global_position)\n", true, LEVEL), LEVEL)
	var split: Array[Dictionary] = EventSheetMistakeFindings.findings(
		_sheet_with_raw(["print(\"head", "task: %s", "tail %d\" % [$Enmy]"]), LEVEL)
	return SUPPORT.pins(TEST_NAME, [
		["a string that runs over three verbatim blocks is one string: only the real $Enmy after it is said", _brief(split), [["node-path-not-in-scene", "warning", "$Enmy"]]],
		["a $Path the scene lacks is a warning", typo, [["node-path-not-in-scene", "warning", "$Enmy"]]],
		["the scene's own node is quiet", right, []],
		["a path through a parent is quiet", deep, []],
		["a scene-unique name the scene has is quiet", unique_ok, []],
		["a scene-unique name it lacks is a warning", unique_bad, [["node-path-not-in-scene", "warning", "%Healt"]]],
		["modulo and a format string are not node references", modulo, []],
		["a format string that runs over two lines is one string", wrapped, []],
		["a path below a node the scene lacks is a warning too", inside.size(), 1],
		["a name the sheet gives a node itself is made at run time", named, []],
		["the near node is offered", found[0]["to"], "$Enemy"],
		["a run-time door is the second door", [found[0]["fix"], found[0]["second_fix"]], ["use_the_name", "known_at_run_time"]],
		["a sheet no scene runs is never judged", _kinds("extends Node2D\n\nfunc go() -> void:\n\t$Enmy.visible = false\n", ""), []],
	])


static func _signal_pins() -> bool:
	var head: String = "extends Node2D\n\nsignal hit(damage: int)\n\n"
	var none: Array = _rows(head + "func go() -> void:\n\thit.emit()\n")
	var two: Array = _rows(head + "func go() -> void:\n\thit.emit(1, 2)\n")
	var right: Array = _rows(head + "func go() -> void:\n\thit.emit(3)\n")
	var by_name: Array = _rows(head + "func go() -> void:\n\temit_signal(\"hit\")\n")
	var nested: Array = _rows(head + "func go() -> void:\n\thit.emit(max(1, 2))\n")
	var wired: String = head + "func _ready() -> void:\n\thit.connect(_on_hit)\n\n"
	var handler_two: Array = _rows(wired + "func _on_hit(damage: int, source: Node) -> void:\n\tpass\n")
	var handler_default: Array = _rows(wired + "func _on_hit(damage: int, source: Node = null) -> void:\n\tpass\n")
	var handler_right: Array = _rows(wired + "func _on_hit(damage: int) -> void:\n\tpass\n")
	var handler_none: Array = _rows(wired + "func _on_hit() -> void:\n\tpass\n")
	var unwired: Array = _rows(head + "func _on_hit(damage: int, source: Node) -> void:\n\tpass\n")
	var host: Array = _rows("extends Node2D\n\nfunc go() -> void:\n\tvisibility_changed.emit(1)\n")
	var connected: Array = _rows(head + "func _ready() -> void:\n\thit.connect(on_damage)\n\nfunc on_damage(amount: int, who: Node) -> void:\n\tpass\n")
	return SUPPORT.pins(TEST_NAME, [
		["an emit with none, of one declared, is an error", none, [["signal-emit-value-count", "error", "hit"]]],
		["an emit with two is an error", two, [["signal-emit-value-count", "error", "hit"]]],
		["an emit with the right count is quiet", right, []],
		["emit_signal by name is counted the same way", by_name, [["signal-emit-value-count", "error", "hit"]]],
		["a call inside the value is one value", nested, []],
		["a handler taking two, of one sent, is an error", handler_two, [["signal-handler-value-count", "error", "hit"]]],
		["a handler with a default for the extra value is fine", handler_default, []],
		["a handler taking one is quiet", handler_right, []],
		["a handler taking none, of one sent, is an error", handler_none, [["signal-handler-value-count", "error", "hit"]]],
		["a function nothing connects is not a handler", unwired, []],
		["a signal of the host class is compared with Godot's own", host, [["signal-emit-value-count", "error", "visibility_changed"]]],
		["a handler connected by hand is compared too", connected, [["signal-handler-value-count", "error", "hit"]]],
	])


static func _while_pins() -> bool:
	var head: String = "extends Node2D\n\nvar lives: int = 3\nvar score: int = 0\n\nfunc stop_it() -> void:\n\tpass\n\n"
	var stuck: Array = _rows(head + "func go() -> void:\n\twhile lives > 0:\n\t\tscore += 1\n")
	var moving: Array = _rows(head + "func go() -> void:\n\twhile lives > 0:\n\t\tlives -= 1\n")
	var calling: Array = _rows(head + "func go() -> void:\n\twhile lives > 0:\n\t\tstop_it()\n")
	var broken: Array = _rows(head + "func go() -> void:\n\twhile lives > 0:\n\t\tscore += 1\n\t\tif score > 9:\n\t\t\tbreak\n")
	var waiting: Array = _rows(head + "func go() -> void:\n\twhile lives > 0:\n\t\tawait get_tree().process_frame\n")
	var random: Array = _rows(head + "func go() -> void:\n\twhile randf() > 0.1:\n\t\tscore += 1\n")
	var forever: Array = _rows(head + "func go() -> void:\n\twhile true:\n\t\tscore += 1\n")
	var guarded: Array = _rows(head + "func go() -> void:\n\tvar rounds := 0\n\twhile lives > 0 and rounds < 1000:\n\t\trounds += 1\n")
	var method: Array = _rows(head + "func go(queue: Array) -> void:\n\twhile queue.size() > 0:\n\t\tqueue.pop_front()\n")
	var repeated: Array = _rows(head + "func go() -> void:\n\tfor index in range(3):\n\t\tscore += 1\n")
	return SUPPORT.pins(TEST_NAME, [
		["a While nothing inside changes is a warning", stuck, [["while-never-ends", "warning", "lives > 0"]]],
		["a While that changes what it reads is quiet", moving, []],
		["a While whose body calls a function of the sheet is quiet", calling, []],
		["a While with a break is quiet", broken, []],
		["a While that awaits is quiet", waiting, []],
		["a condition that calls something is quiet", random, []],
		["While true with nothing to stop it is a warning", forever, [["while-never-ends", "warning", "true"]]],
		["the guarded form is quiet", guarded, []],
		["a method call on what the condition reads is quiet", method, []],
		["a counted loop is never judged", repeated, []],
	])


static func _shadow_pins() -> bool:
	var head: String = "extends Node2D\n\nvar score: int = 0\n\n"
	var hides: Array = _rows(head + "func go() -> void:\n\tvar score: int = 0\n\tscore += 10\n")
	var other: Array = _rows(head + "func go() -> void:\n\tvar total: int = 0\n\ttotal += 10\n")
	var parameter: Array = _rows(head + "func heal(amount: int) -> void:\n\tvar amount: int = 5\n\tprint(amount)\n")
	var separate: Array = _rows(head + "func heal(amount: int) -> void:\n\tvar extra: int = 5\n\tprint(amount + extra)\n")
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(SUPPORT.reopen(head + "func heal(amount: int) -> void:\n\tvar amount: int = 5\n\tprint(amount)\n", true, LEVEL), LEVEL)
	return SUPPORT.pins(TEST_NAME, [
		["a local with a sheet variable's name is a warning", hides, [["local-hides-variable", "warning", "score"]]],
		["a local with its own name is quiet", other, []],
		["a local over a parameter is an error, because Godot refuses the script", parameter, [["local-hides-parameter", "error", "amount"]]],
		["a local beside a parameter is quiet", separate, []],
		["the parameter sentence says the script does not load", String(found[0]["message"]).contains("does not load"), true],
	])


static func _division_pins() -> bool:
	var head: String = "extends Node2D\n\nvar hits: int = 3\nvar ratio: float = 0.5\nvar free = 1\n\n"
	var whole: Array = _rows(head + "func go() -> void:\n\tratio = hits / 0\n")
	var literals: Array = _rows(head + "func go() -> void:\n\tvar a := 1 / 0\n")
	var decimal: Array = _rows(head + "func go() -> void:\n\tratio = ratio / 0.0\n")
	var floated: Array = _rows(head + "func go() -> void:\n\tratio = ratio / 0\n")
	var both_decimal: Array = _rows(head + "func go() -> void:\n\tvar a := 1.0 / 0.0\n")
	var modulo: Array = _rows(head + "func go() -> void:\n\tvar a := hits % 0\n")
	var unknown: Array = _rows(head + "func go(value) -> void:\n\tvar a = value / 0\n")
	var fine: Array = _rows(head + "func go() -> void:\n\tvar a := hits / 2\n\tvar b := hits / hits\n\tvar c := hits / 0.5\n\tvar d := hits / 10\n")
	var inside_string: Array = _rows(head + "func go() -> void:\n\tprint(\"5 / 0 is nothing\")\n")
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(SUPPORT.reopen(head + "func go() -> void:\n\tratio = hits / 0\n", true, LEVEL), LEVEL)
	return SUPPORT.pins(TEST_NAME, [
		["a whole number over a literal zero is an error", whole, [["divide-by-literal-zero", "error", "hits / 0"]]],
		["a literal over a literal is an error, the script does not load", literals, [["divide-by-literal-zero", "error", "1 / 0"]]],
		["a decimal zero is a warning, Godot gives inf", decimal, [["divide-by-literal-zero", "warning", "ratio / 0.0"]]],
		["a float variable over 0 is a warning too", floated, [["divide-by-literal-zero", "warning", "ratio / 0"]]],
		["1.0 / 0.0 is a warning", both_decimal, [["divide-by-literal-zero", "warning", "1.0 / 0.0"]]],
		["a remainder by zero is an error", modulo, [["divide-by-literal-zero", "error", "hits % 0"]]],
		["a variable of no declared type is a warning that says both outcomes", unknown, [["divide-by-literal-zero", "warning", "value / 0"]]],
		["other divisions are quiet", fine, []],
		["words inside a string are not code", inside_string, []],
		["the sentence says what Godot does", String(found[0]["message"]).contains("Division by zero error"), true],
	])


static func _memory_pins() -> bool:
	var saved: Variant = ProjectSettings.get_setting(EventSheetMistakeFindings.REMEMBER_SETTING, {})
	ProjectSettings.set_setting(EventSheetMistakeFindings.REMEMBER_SETTING, {})
	var source: String = "extends Node2D\n\nfunc go() -> void:\n\t$Enmy.visible = false\n\tfor node in get_tree().get_nodes_in_group(\"enemys\"):\n\t\tnode.queue_free()\n"
	var before: Array = _kinds(source)
	var wrote_node: bool = EventSheetMistakeFindings.remember(LEVEL, EventSheetMistakeFindings.KIND_MISSING_NODE, "$Enmy")
	var wrote_again: bool = EventSheetMistakeFindings.remember(LEVEL, EventSheetMistakeFindings.KIND_MISSING_NODE, "$Enmy")
	EventSheetMistakeFindings.remember(LEVEL, EventSheetMistakeFindings.KIND_EMPTY_GROUP, "enemys")
	var after: Array = _kinds(source)
	var elsewhere: Array = _kinds(source, "res://tests/fixtures/mistake_other.gd")
	var held: PackedStringArray = EventSheetMistakeFindings.remembered_for(LEVEL)
	ProjectSettings.set_setting(EventSheetMistakeFindings.REMEMBER_SETTING, saved)
	return SUPPORT.pins(TEST_NAME, [
		["before it is remembered, both are said", before, ["group-nothing-is-in", "node-path-not-in-scene"]],
		["remembering a fact says it changed once", [wrote_node, wrote_again], [true, false]],
		["remembered facts are quiet", after, []],
		["and are kept per project setting, filed by sheet, never in the sheet", held, PackedStringArray(["group-nothing-is-in|enemys", "node-path-not-in-scene|$Enmy"])],
		["another sheet is not affected", elsewhere.size() <= before.size(), true],
	])


## The row states are recomputed when a sheet opens and after each edit, so the whole pass over the
## biggest pack has a budget: about three times what it measured warm on the reference machine.
static func _budget_pins() -> bool:
	var pack: String = "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(pack)
	if sheet == null:
		return SUPPORT.check(TEST_NAME, "the pathfinding pack opens", false, true)
	EventSheetMistakeFindings.findings(sheet, pack)
	var started: int = Time.get_ticks_usec()
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(sheet, pack)
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	print("[measure] mistake findings on the pathfinding pack, warm: %.1f ms" % elapsed_ms)
	return SUPPORT.pins(TEST_NAME, [
		["the shipped pack earns no mistake finding", found.size(), 0],
		["a warm pass over the biggest pack stays inside its budget (250 ms)", elapsed_ms < PACK_BUDGET_MS, true],
	])


## Every finding speaks the shape the amber state, the strip and the Doctor all read.
static func _shape_pins() -> bool:
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(SUPPORT.reopen(
		"extends Node2D\n\nfunc go() -> void:\n\tvar a := hits / 0\n", true, LEVEL), LEVEL)
	var keys: Array = []
	if not found.is_empty():
		keys = (found[0] as Dictionary).keys()
		keys.sort()
	return SUPPORT.pins(TEST_NAME, [
		["a finding carries every key its readers address", keys.has("kind") and keys.has("severity") and keys.has("anchor") and keys.has("event") and keys.has("subject") and keys.has("message") and keys.has("fix") and keys.has("fix_label") and keys.has("lane") and keys.has("index") and keys.has("red"), true],
		["an error is red, a warning is not", [EventSheetMistakeFindings._finding("k", "error", null, "", "", "", "", {}, {})["red"], EventSheetMistakeFindings._finding("k", "warning", null, "", "", "", "", {}, {})["red"]], [true, false]],
	])
