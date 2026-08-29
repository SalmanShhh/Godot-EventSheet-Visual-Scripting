# Godot EventSheets - the crowd: copies joined to a group, counted, capped, and missed when they go.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE PERSISTENT FLAG. `add_to_group(name)` is not persistent, and a crowd joined without the
#      second argument vanishes the moment its branch is packed back into a scene - after which
#      every count in the sheet silently answers zero. The flag is pinned as a literal line, because
#      dropping it breaks nothing that any other test can see.
#   2. THE CAP, AND THE POLICY. Two rows, two different files. The make-room row reads the crowd
#      once and removes members before spawning; the skip row declares the name BEFORE its branch,
#      so a following row can still say it. Both are pinned as their exact lines: swap the order in
#      either and the game changes while the descriptors still look right. And the make-room row is
#      RUN as well as read, because the way a cap stops capping - a member freed twice in one frame,
#      because queue_free leaves it in its group until the end of that frame - is invisible to any
#      pin on the text.
#   3. THE COUNT. One expression, the group's own size, pinned as the text it writes.
#   4. THE LAST ONE OUT. The trigger is the scene tree's node_removed signal and the gate is an
#      ORDINARY CONDITION in the sheet, so this pins the connect line, the handler's signature, and
#      the `if` the gate compiles to - the guard being visible is the whole point of the row.
#   5. THE ROUND TRIP. A crowd spawn opens as rows and re-emits byte for byte.
#
# Values are pinned, never counts: a count would go on passing while the wrong line moved.
@tool
class_name CrowdSentenceTest
extends RefCounted

## The crowd module, loaded BY PATH so the test does not wait on the editor class cache having been
## regenerated for a newly added module.
const CROWD_MODULE_PATH: String = "res://addons/eventforge/registration/modules/crowd_aces.gd"

## The scene the fixtures spawn, and the group they spawn into - a load() of a path and a plain
## quoted group name, which is what the rows' own defaults are.
const ENEMY: String = "load(\"res://enemy.tscn\")"
const CROWD: String = "\"enemies\""


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_descriptors_say_what_they_emit() and passed
	passed = _test_the_crowd_spawn_joins_the_group_persistently() and passed
	passed = _test_the_cap_says_its_policy_in_its_own_lines() and passed
	passed = _test_the_cap_holds_when_one_frame_spawns_several() and passed
	passed = _test_the_count_is_the_groups_own_size() and passed
	passed = _test_the_last_one_out_is_a_signal_and_a_visible_gate() and passed
	passed = _test_applying_the_trigger_puts_the_gate_in_the_sheet() and passed
	passed = _test_a_crowd_spawn_re_emits_byte_for_byte() and passed
	passed = _test_the_crowd_copy_is_offered_to_the_rows_after_it() and passed
	return passed


# ── 7. The name a crowd row mints ──


## A crowd row declares its local exactly as the plain spawn row does, so the name it gave the copy
## is a name the rows after it can say - and an expression field offers it for the same reason.
static func _test_the_crowd_copy_is_offered_to_the_rows_after_it() -> bool:
	var passed: bool = true
	for ace_id: String in ["SpawnIntoCrowd", "SpawnIntoCrowdOldestFirst", "SpawnIntoCrowdUnlessFull"]:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.host_class = "Node2D"
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnReady"
		event.actions.append(_action(ace_id, {
			"scene": ENEMY, "name": "new_foe", "crowd": CROWD, "cap": "12",
			"at": "global_position", "parent": "self"
		}))
		sheet.events.append(event)
		EventSheetCompletions.clear_cache()
		var offered: Dictionary = {}
		for entry: Dictionary in EventSheetCompletions.for_field(sheet, "expression", "new_"):
			offered[str(entry.get("text", ""))] = str(entry.get("detail", ""))
		passed = _check("%s offers the name it gave the copy" % ace_id,
			offered.has("new_foe"), true) and passed
		passed = _check("%s says which scene the copy is of" % ace_id,
			str(offered.get("new_foe", "")).contains("enemy.tscn"), true) and passed
		EventSheetCompletions.clear_cache()
	return passed


# ── 1. The descriptors ──


static func _test_the_descriptors_say_what_they_emit() -> bool:
	var passed: bool = true
	var by_id: Dictionary = _descriptors()
	passed = _check("the crowd spawn instances, joins, parents and places - in that order",
		_template(by_id, "SpawnIntoCrowd"),
		"var {name} = {scene}.instantiate()\n{name}.add_to_group({crowd}, true)"
		+ "\n{parent}.add_child({name})\n{name}.global_position = {at}") and passed
	passed = _check("the make-room row reads the staying members, then makes room, then spawns",
		_template(by_id, "SpawnIntoCrowdOldestFirst"),
		"var crowd_{name} = get_tree().get_nodes_in_group({crowd})"
		+ ".filter(func(member: Variant) -> bool: return not member.is_queued_for_deletion())"
		+ "\nwhile crowd_{name}.size() >= maxi({cap}, 1):\n\tcrowd_{name}.pop_front().queue_free()"
		+ "\nvar {name} = {scene}.instantiate()\n{name}.add_to_group({crowd}, true)"
		+ "\n{parent}.add_child({name})\n{name}.global_position = {at}") and passed
	passed = _check("the skip row declares the name before the branch that may not run",
		_template(by_id, "SpawnIntoCrowdUnlessFull"),
		"var crowd_{name} = get_tree().get_nodes_in_group({crowd})"
		+ ".filter(func(member: Variant) -> bool: return not member.is_queued_for_deletion())"
		+ "\nvar {name}: Node = null"
		+ "\nif crowd_{name}.size() < {cap}:"
		+ "\n\t{name} = {scene}.instantiate()\n\t{name}.add_to_group({crowd}, true)"
		+ "\n\t{parent}.add_child({name})\n\t{name}.global_position = {at}") and passed
	passed = _check("how many are alive is the group's own size",
		_template(by_id, "CrowdCount"), "get_tree().get_node_count_in_group({crowd})") and passed
	# The policy is IN THE SENTENCE, not in a setting beside it: a reader of the row knows what
	# happens at the cap without opening anything.
	passed = _check("the make-room row says its policy on the row",
		str(_descriptor(by_id, "SpawnIntoCrowdOldestFirst").display_text).ends_with("the first in the crowd makes room"), true) and passed
	passed = _check("the skip row says its policy on the row",
		str(_descriptor(by_id, "SpawnIntoCrowdUnlessFull").display_text).ends_with("skip spawning when full"), true) and passed
	# The gate is spelled once. The dock bakes the module's own constant onto the condition it adds,
	# so a descriptor that drifted from it would compile a different line than the row shows.
	var module: GDScript = load(CROWD_MODULE_PATH)
	passed = _check("the gate the dock bakes is the gate the descriptor declares",
		_template(by_id, str(module.get("LAST_REMOVED_GATE_ID"))),
		str(module.get("LAST_REMOVED_GATE_TEMPLATE"))) and passed
	return passed


# ── 2. Joining the crowd ──


static func _test_the_crowd_spawn_joins_the_group_persistently() -> bool:
	var output: String = _compiled_with("SpawnIntoCrowd", {
		"scene": ENEMY, "name": "e", "crowd": CROWD, "at": "global_position", "parent": "self"
	}, "user://eventforge_crowd_spawn.gd")
	var passed: bool = true
	passed = _check("the name the row was given is the variable the code declares",
		output.contains("\tvar e = load(\"res://enemy.tscn\").instantiate()"), true) and passed
	# THE line. `true` is what survives PackedScene.pack(); without it the group is gone from a
	# packed branch and every crowd question answers zero, with nothing else failing anywhere.
	passed = _check("the copy joins its crowd with the persistent flag",
		output.contains("\te.add_to_group(\"enemies\", true)"), true) and passed
	passed = _check("the copy is added under the parent the row names",
		output.contains("\tself.add_child(e)"), true) and passed
	passed = _check("the copy is placed after it is in the tree",
		output.contains("\te.global_position = global_position"), true) and passed
	var join_at: int = output.find("\te.add_to_group(\"enemies\", true)")
	var place_at: int = output.find("\te.global_position = global_position")
	passed = _check("the place is set last, once the copy is somewhere",
		join_at >= 0 and join_at < place_at, true) and passed
	return passed


# ── 3. The cap ──


static func _test_the_cap_says_its_policy_in_its_own_lines() -> bool:
	var passed: bool = true
	var oldest: String = _compiled_with("SpawnIntoCrowdOldestFirst", {
		"scene": ENEMY, "name": "e", "crowd": CROWD, "cap": "12",
		"at": "global_position", "parent": "self"
	}, "user://eventforge_crowd_oldest.gd")
	# THE MEMBERS THAT ARE STAYING, not everything the group still lists. queue_free marks a node and
	# leaves it in its group until the end of the frame, so a read that took them all would count
	# ghosts and would hand the same ghost to the next spawn of the same frame.
	passed = _check("the crowd is read once, into a local named after the copy, skipping the leavers",
		oldest.contains("\tvar crowd_e = get_tree().get_nodes_in_group(\"enemies\")"
			+ ".filter(func(member: Variant) -> bool: return not member.is_queued_for_deletion())"), true) and passed
	# maxi(cap, 1) is what makes pop_front() safe whatever number the author typed: the loop cannot
	# run on an empty crowd, so the emitted line never reaches past the end of the array.
	passed = _check("room is made until it fits, and only from somebody who is staying",
		oldest.contains("\twhile crowd_e.size() >= maxi(12, 1):\n\t\tcrowd_e.pop_front().queue_free()"), true) and passed
	var make_room_at: int = oldest.find("crowd_e.pop_front().queue_free()")
	var spawn_at: int = oldest.find("var e = load(\"res://enemy.tscn\").instantiate()")
	passed = _check("room is made before the new copy arrives, so the cap is never passed",
		make_room_at >= 0 and make_room_at < spawn_at, true) and passed

	var skip: String = _compiled_with("SpawnIntoCrowdUnlessFull", {
		"scene": ENEMY, "name": "e", "crowd": CROWD, "cap": "12",
		"at": "global_position", "parent": "self"
	}, "user://eventforge_crowd_skip.gd")
	# The name outlives the branch on purpose: the rows after this one can still say it, and what it
	# holds when the crowd was full is nothing - which Is Still Here can ask about.
	passed = _check("the name is declared where the rows after it can still say it",
		skip.contains("\tvar e: Node = null"), true) and passed
	passed = _check("the skip row asks the same question about the same members",
		skip.contains("\tvar crowd_e = get_tree().get_nodes_in_group(\"enemies\")"
			+ ".filter(func(member: Variant) -> bool: return not member.is_queued_for_deletion())"), true) and passed
	passed = _check("nothing at all happens when the crowd is full",
		skip.contains("\tif crowd_e.size() < 12:"), true) and passed
	passed = _check("the spawn is the branch's body, not a line beside it",
		skip.contains("\t\te = load(\"res://enemy.tscn\").instantiate()"), true) and passed
	return passed


# ── 3b. The cap, RUN rather than read ──


## The lines a compile-time pin cannot judge. Three spawns in ONE frame is the shape a shotgun, a
## particle burst and a wave spawned in a for-loop all have, and it is the shape the cap has to
## survive: `queue_free()` leaves a member in its group until the end of the frame, so a row that
## read the group straight would hand the SAME member to all three spawns and grow the crowd by two.
##
## The emitted lines are RUN, against a stand-in tree that behaves the way Godot's does about
## queue_free - the member stays listed and answers is_queued_for_deletion() - because that is the
## whole of the bug and no amount of reading the text can see it. `run_tests.gd` has no main loop, so
## a real SceneTree is not available here; what the harness fakes is exactly the two behaviours the
## row depends on, and nothing else.
static func _test_the_cap_holds_when_one_frame_spawns_several() -> bool:
	var passed: bool = true
	var action: ACEAction = _action("SpawnIntoCrowdOldestFirst", {
		"scene": "scene", "name": "made", "crowd": "\"foes\"", "cap": "12",
		"at": "Vector2.ZERO", "parent": "self"
	})
	var emitted: String = ActionCodegen.generate_action(action)
	var host: Object = _running_host(emitted)
	if host == null:
		return _check("the emitted crowd lines can be run at all", false, true)
	for _spawn: int in 3:
		host.call("spawn")
	passed = _check("three spawns in one frame free three different members",
		str(host.get("freed")), str(["m0", "m1", "m2"])) and passed
	host.call("end_of_frame")
	passed = _check("and the crowd settles at its cap rather than above it",
		int(host.call("alive")), 12) and passed
	# The frame after, which is where the unfiltered read climbed a second time.
	for _spawn: int in 3:
		host.call("spawn")
	host.call("end_of_frame")
	passed = _check("a second such frame does not climb either",
		int(host.call("alive")), 12) and passed
	host.call("dispose")
	return passed


## A host the emitted lines can run inside: a stand-in tree holding twelve members, a stand-in scene
## that makes more, and the two answers Godot gives about a member that was told to go.
static func _running_host(emitted_lines: String) -> Object:
	var body: String = ""
	for line: String in emitted_lines.split("\n"):
		body += "\t%s\n" % line
	var harness: GDScript = GDScript.new()
	harness.source_code = CROWD_HARNESS_SOURCE + body
	if harness.reload() != OK:
		return null
	return harness.new()


## The stand-in, as source. `queue_free()` records the member and marks it - it does NOT leave the
## group - which is precisely what Godot does until the end of the frame, and `end_of_frame()` is the
## sweep that finally drops them.
const CROWD_HARNESS_SOURCE: String = """extends RefCounted


class CrowdMember extends Node:
	var label: String = ""
	var going: bool = false
	var global_position = null
	var freed: Array = []

	@warning_ignore("native_method_override")
	func is_queued_for_deletion() -> bool:
		return going

	@warning_ignore("native_method_override")
	func queue_free() -> void:
		freed.append(label)
		going = true


class StandInTree extends RefCounted:
	var members: Array = []

	func get_nodes_in_group(_group_name: String) -> Array:
		return members.duplicate()

	func get_node_count_in_group(_group_name: String) -> int:
		return members.size()


class StandInScene extends RefCounted:
	var made: int = 0
	var freed: Array = []

	func instantiate():
		made += 1
		var member = CrowdMember.new()
		member.label = "new%d" % made
		member.freed = freed
		return member


var freed: Array = []
var everyone: Array = []
var tree = StandInTree.new()
var scene = StandInScene.new()


func _init() -> void:
	scene.freed = freed
	for index in 12:
		var member = CrowdMember.new()
		member.label = "m%d" % index
		member.freed = freed
		everyone.append(member)
		tree.members.append(member)


func get_tree():
	return tree


func add_child(node) -> void:
	everyone.append(node)
	tree.members.append(node)


func dispose() -> void:
	for member in everyone:
		member.free()
	everyone.clear()
	tree.members.clear()


func alive() -> int:
	return tree.members.size()


func end_of_frame() -> void:
	var staying: Array = []
	for member in tree.members:
		if not member.is_queued_for_deletion():
			staying.append(member)
	tree.members = staying


func spawn() -> void:
"""


# ── 4. Counting them ──


static func _test_the_count_is_the_groups_own_size() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var printed: ACEAction = ACEAction.new()
	printed.provider_id = "Core"
	printed.ace_id = "Print"
	printed.params = {"value": "get_tree().get_node_count_in_group(\"enemies\")"}
	event.actions.append(printed)
	sheet.events.append(event)
	return _check("the count expression is emitted as written, with nothing counting for it",
		_compile(sheet, "user://eventforge_crowd_count.gd").contains(
			"\tprint(get_tree().get_node_count_in_group(\"enemies\"))"), true)


# ── 5. The last one out ──


static func _test_the_last_one_out_is_a_signal_and_a_visible_gate() -> bool:
	var module: GDScript = load(CROWD_MODULE_PATH)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = str(module.get("LAST_REMOVED_TRIGGER_ID"))
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = str(module.get("LAST_REMOVED_GATE_ID"))
	gate.codegen_template = str(module.get("LAST_REMOVED_GATE_TEMPLATE"))
	gate.params = {"crowd": CROWD, "node": "node"}
	event.conditions.append(gate)
	var printed: ACEAction = ACEAction.new()
	printed.provider_id = "Core"
	printed.ace_id = "Print"
	printed.params = {"value": "\"wave cleared\""}
	event.actions.append(printed)
	sheet.events.append(event)
	var output: String = _compile(sheet, "user://eventforge_crowd_last.gd")
	var passed: bool = true
	passed = _check("the trigger is the scene tree's own node-removed signal",
		output.contains("\tget_tree().node_removed.connect(_on_node_removed)"), true) and passed
	passed = _check("the handler is handed the node that is leaving",
		output.contains("func _on_node_removed(node: Node) -> void:"), true) and passed
	# The guard is a CONDITION, so it is an `if` in the file and a row in the sheet - not a wrapper
	# the compiler adds around a body nobody can see.
	passed = _check("the gate is an ordinary if in the emitted handler",
		output.contains("\tif node.is_in_group(\"enemies\") and get_tree().get_nodes_in_group(\"enemies\") == [node]:"), true) and passed
	passed = _check("the body runs under the gate",
		output.contains("\t\tprint(\"wave cleared\")"), true) and passed
	return passed


## The gate arrives in the SHEET, not in the compiler. Picking the trigger puts a condition row
## under it - which is what makes it visible, editable and deletable - and the crowd the author
## typed on the trigger rides across rather than being asked for a second time.
static func _test_applying_the_trigger_puts_the_gate_in_the_sheet() -> bool:
	var module: GDScript = load(CROWD_MODULE_PATH)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var definition: ACEDefinition = dock._ace_registry.find_definition("Core", str(module.get("LAST_REMOVED_TRIGGER_ID")))
	var passed: bool = _check("the trigger is registered", definition != null, true)
	if definition == null:
		dock.free()
		return false
	var event: EventRow = EventRow.new()
	var trigger: ACECondition = ACECondition.new()
	trigger.provider_id = "Core"
	trigger.ace_id = str(module.get("LAST_REMOVED_TRIGGER_ID"))
	trigger.params = {"crowd": "\"bats\""}
	event.trigger = trigger
	dock._ace_apply._bake_trigger_signature(event, definition)
	passed = _check("applying the trigger adds one condition row, not a hidden wrapper",
		event.conditions.size(), 1) and passed
	if event.conditions.size() == 1:
		var gate: ACECondition = event.conditions[0]
		passed = _check("the row added is the crowd gate", gate.ace_id, str(module.get("LAST_REMOVED_GATE_ID"))) and passed
		passed = _check("the crowd the author typed rides across from the trigger",
			str(gate.params.get("crowd", "")), "\"bats\"") and passed
		passed = _check("the gate reads the node the handler was handed",
			str(gate.params.get("node", "")), str(module.get("REMOVED_NODE_ARGUMENT"))) and passed
	dock.free()
	return passed


# ── 6. The round trip ──


static func _test_a_crowd_spawn_re_emits_byte_for_byte() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("SpawnIntoCrowd", {
		"scene": ENEMY, "name": "e", "crowd": CROWD, "at": "global_position", "parent": "self"
	}))
	sheet.events.append(event)
	var source: String = _compile(sheet, "user://eventforge_crowd_trip.gd")
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://eventforge_crowd_trip_back.gd"
	return _check("opened crowd code re-emits byte for byte",
		_compile(imported, "user://eventforge_crowd_trip_back.gd") == source, true)


# ── Harness ──


## The Crowd module's descriptors by id.
static func _descriptors() -> Dictionary:
	var module: GDScript = load(CROWD_MODULE_PATH)
	var by_id: Dictionary = {}
	for descriptor: Variant in module.call("get_descriptors"):
		if descriptor is ACEDescriptor:
			by_id[str((descriptor as ACEDescriptor).ace_id)] = descriptor
	return by_id


static func _descriptor(by_id: Dictionary, ace_id: String) -> ACEDescriptor:
	return by_id.get(ace_id, ACEDescriptor.new())


static func _template(by_id: Dictionary, ace_id: String) -> String:
	return str(_descriptor(by_id, ace_id).codegen_template)


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action


## One row of the given kind, compiled in a ready handler on a Node2D - the smallest sheet that can
## hold a crowd spawn.
static func _compiled_with(ace_id: String, params: Dictionary, path: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action(ace_id, params))
	sheet.events.append(event)
	return _compile(sheet, path)


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] crowd_sentence_test: %s -> expected %s, got %s" % [label, expected, got])
	return false
