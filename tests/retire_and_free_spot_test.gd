# Godot EventSheets - retiring a node, copying the scene it came from, and finding room for the next
# copy.
#
# What this gate holds, in the order a reader meets it:
#   1. RETIRING. A node a pool handed out goes back to that pool; anything else is destroyed. Both
#      answers are pinned by watching what happens to the node, and the deciding half - "is there a
#      pool, and did this come out of it" - is pinned on its own, because it is the half a running
#      game answers and a test cannot.
#   2. HEARING ABOUT IT. On Retired is ONE connection to `tree_exiting`, and that is the whole
#      claim: both retirements leave the tree, so one signal is raised once either way. The gate
#      asserts the single connect and asserts that nothing hangs off the pool's own signal beside
#      it, which is what firing twice would look like in the emitted file.
#   3. A COPY OF MYSELF. The safe spawn with the node's own scene file where the scene field goes -
#      pinned as the three lines it writes, opened back as the row through the real importer, and
#      re-emitted byte for byte.
#   4. THE DOCTOR. A node built in code has no scene file to copy, which is silent everywhere else;
#      and a copy of this very scene made the moment a copy is created is the loop that hangs.
#   5. A FREE SPOT. The roll-until-it-fits loop, with the questions handed in, so a real value can
#      be pinned: the point it answers is outside the wall and far enough from the copy already
#      placed, and an arena with no room in it answers nothing at all.
#   6. THE SKIP. The spawn row that finds no room raises the sheet's own spawn_skipped signal with
#      the scene it could not place, and On Spawn Skipped is connected to it.
#
# Values are pinned, never counts.
@tool
class_name RetireAndFreeSpotTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SPAWN := preload("res://addons/eventforge/registration/modules/spawn_aces.gd")
const REMOVAL := preload("res://addons/eventforge/registration/modules/removal_aces.gd")

const TEST_NAME: String = "retire_and_free_spot_test"

## A stand-in for the pool autoload: a node that answers `despawn` and remembers what it was handed.
## The real pool is found by path at run time, which is the one thing a suite with no scene tree
## cannot build - so the deciding half is pinned separately and this stands in for the doing half.
const POOL_SOURCE: String = """extends Node


var taken: Array = []


func despawn(node: Node) -> void:
	taken.append(node)
"""


static func run() -> bool:
	var passed: bool = true
	passed = _test_a_pooled_node_goes_back_to_its_pool() and passed
	passed = _test_an_unpooled_node_is_destroyed() and passed
	passed = _test_what_counts_as_pooled() and passed
	passed = _test_on_retired_is_one_connection() and passed
	passed = _test_a_copy_of_myself_is_the_safe_spawn() and passed
	passed = _test_a_copy_of_myself_opens_as_the_row() and passed
	passed = _test_the_doctor_says_when_there_is_no_scene_file() and passed
	passed = _test_the_free_spot_loop_answers_a_real_point() and passed
	passed = _test_the_free_spot_reads_the_shapes_it_is_given() and passed
	passed = _test_a_skipped_spawn_says_so() and passed
	return passed


# ── 1. Retiring ──


static func _test_a_pooled_node_goes_back_to_its_pool() -> bool:
	var passed: bool = true
	var pool: Node = _fixture_pool()
	var node: Node2D = Node2D.new()
	PooledNodes.retire_into(node, pool)
	passed = SUPPORT.check(TEST_NAME, "a pooled node is handed back to the pool that made it",
		(pool.get("taken") as Array).size() == 1 and (pool.get("taken") as Array)[0] == node,
		true) and passed
	passed = SUPPORT.check(TEST_NAME, "and is not destroyed on the way",
		node.is_queued_for_deletion(), false) and passed
	# Once, and only once: a second retire of a node the pool already has does not hand it over
	# again, because the node it is asked about is the one it already took.
	PooledNodes.retire_into(node, pool)
	passed = SUPPORT.check(TEST_NAME, "retiring it a second time hands it over once more, and never twice for one call",
		(pool.get("taken") as Array).size(), 2) and passed
	node.free()
	pool.free()
	return passed


static func _test_an_unpooled_node_is_destroyed() -> bool:
	var passed: bool = true
	var pool: Node = _fixture_pool()
	var node: Node2D = Node2D.new()
	PooledNodes.retire_into(node, null)
	passed = SUPPORT.check(TEST_NAME, "a node no pool made is destroyed",
		node.is_queued_for_deletion(), true) and passed
	passed = SUPPORT.check(TEST_NAME, "and nothing is handed to a pool",
		(pool.get("taken") as Array).is_empty(), true) and passed
	# A node already on its way out is left alone, which is what makes the row safe to run twice.
	PooledNodes.retire_into(node, pool)
	passed = SUPPORT.check(TEST_NAME, "and a node already on its way out is not handed anywhere",
		(pool.get("taken") as Array).is_empty(), true) and passed
	pool.free()
	return passed


## The deciding half on its own: what a node has to be for the pool answer to be yes. Every one of
## these is a NO for a different reason, and the reasons are the four branches the lookup has.
static func _test_what_counts_as_pooled() -> bool:
	var passed: bool = true
	var bare: Node2D = Node2D.new()
	passed = SUPPORT.check(TEST_NAME, "a node with no pool mark came out of no pool",
		PooledNodes.pool_of(bare), null) and passed
	passed = SUPPORT.check(TEST_NAME, "and asking about nothing at all answers nothing",
		PooledNodes.pool_of(null), null) and passed
	bare.set_meta(PooledNodes.POOL_META, "bullets")
	passed = SUPPORT.check(TEST_NAME, "a marked node outside the tree still answers nothing, because the pool is found by path",
		PooledNodes.pool_of(bare), null) and passed
	passed = SUPPORT.check(TEST_NAME, "and the mark it reads is the one the pool leaves",
		str(PooledNodes.POOL_META), "__pool__") and passed
	bare.free()
	return passed


# ── 2. Hearing about it ──


static func _test_on_retired_is_one_connection() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnRetired"
	event.actions.append(_action("Retire", {"object": "self"}))
	sheet.events.append(event)
	var output: String = SUPPORT.compile_output(sheet, "user://eventforge_retired_row.gd")
	passed = SUPPORT.check(TEST_NAME, "On Retired hangs off the node's own tree_exiting",
		output.count("tree_exiting.connect(_on_retired)"), 1) and passed
	passed = SUPPORT.check(TEST_NAME, "and writes one handler for it",
		output.count("func _on_retired() -> void:"), 1) and passed
	# The claim the row's words make: one signal, not two. A connection to the pool's own despawn
	# signal beside this one would fire the body a second time for the same retirement.
	passed = SUPPORT.check(TEST_NAME, "and nothing is hung off the pool's own signal beside it",
		output.contains("on_despawned"), false) and passed
	passed = SUPPORT.check(TEST_NAME, "the body retires through the runtime file rather than a bare free",
		output.contains("PooledNodes.retire(self)"), true) and passed
	return passed


# ── 3. A copy of myself ──


static func _test_a_copy_of_myself_is_the_safe_spawn() -> bool:
	var passed: bool = true
	passed = SUPPORT.check(TEST_NAME, "the row is the safe spawn with the node's own scene file in it",
		SPAWN.self_copy_template(),
		"var {name} = load(scene_file_path).instantiate()\n{name}.position = {at}\n"
			+ "{parent}.call_deferred(\"add_child\", {name})") and passed
	passed = SUPPORT.check(TEST_NAME, "and the 3D twin writes the identical three statements",
		_template_of("SpawnCopyOfSelf3D"), _template_of("SpawnCopyOfSelf")) and passed
	passed = SUPPORT.check(TEST_NAME, "filled in, it names nothing but the node's own property",
		_emitted("SpawnCopyOfSelf", {"name": "half", "at": "position", "parent": "get_parent()"}),
		"var half = load(scene_file_path).instantiate()\nhalf.position = position\n"
			+ "get_parent().call_deferred(\"add_child\", half)") and passed
	return passed


static func _test_a_copy_of_myself_opens_as_the_row() -> bool:
	var passed: bool = true
	var values: Dictionary = {"name": "half", "at": "position", "parent": "get_parent()"}
	var source: String = _compiled("SpawnCopyOfSelf", values, "Node2D")
	var lifted: ACEAction = _first_action(SUPPORT.reopen(source))
	passed = SUPPORT.check(TEST_NAME, "a hand-written copy of this node's own scene opens as the row",
		"" if lifted == null else lifted.ace_id, "SpawnCopyOfSelf") and passed
	if lifted != null:
		passed = SUPPORT.check(TEST_NAME, "keeping the author's own name for the copy",
			str(lifted.params.get("name", "")), "half") and passed
		passed = SUPPORT.check(TEST_NAME, "and where they put it",
			str(lifted.params.get("at", "")), "position") and passed
		passed = SUPPORT.check(TEST_NAME, "and what they put it under",
			str(lifted.params.get("parent", "")), "get_parent()") and passed
	passed = SUPPORT.check(TEST_NAME, "and the file re-emits byte for byte",
		SUPPORT.reemit(source, "user://eventforge_self_copy_roundtrip.gd") == source, true) and passed
	# A deferred spawn of some OTHER scene is not this row: the pattern holds the property outright,
	# so nothing but a copy of the node's own scene is claimed.
	var other: String = _compiled("SpawnNewCopyDeferred", {"scene": "load(\"res://enemy.tscn\")",
		"name": "half", "at": "position", "parent": "get_parent()"}, "Node2D")
	var other_row: ACEAction = _first_action(SUPPORT.reopen(other))
	passed = SUPPORT.check(TEST_NAME, "a deferred spawn of another scene keeps the reading it had",
		"SpawnCopyOfSelf" if other_row != null and other_row.ace_id == "SpawnCopyOfSelf" else "",
		"") and passed
	return passed


# ── 4. The Doctor ──


static func _test_the_doctor_says_when_there_is_no_scene_file() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("SpawnCopyOfSelf", {"name": "half", "at": "position",
		"parent": "get_parent()"}))
	sheet.events.append(event)
	passed = SUPPORT.check(TEST_NAME, "a node that came from no scene file has nothing to copy",
		_kinds(EventSheetSpawnFindings.findings(sheet, "")).has(
			EventSheetSpawnFindings.KIND_NO_SCENE_FILE), true) and passed
	passed = SUPPORT.check(TEST_NAME, "and the words say which fact that is",
		_message_for(EventSheetSpawnFindings.findings(sheet, ""),
			EventSheetSpawnFindings.KIND_NO_SCENE_FILE).contains(
			"was not made from a scene file"), true) and passed
	var from_a_scene: Array[Dictionary] = EventSheetSpawnFindings.findings(sheet,
		"res://tests/fixtures/collision_scene_enemy.tscn")
	passed = SUPPORT.check(TEST_NAME, "a node that DID come from a scene file is not told there is nothing to copy",
		_kinds(from_a_scene).has(EventSheetSpawnFindings.KIND_NO_SCENE_FILE), false) and passed
	# The same row is the loop that hangs: a copy made every time a copy is created, with nothing in
	# the way, doubles the count for ever - and it names its own scene by being the row it is.
	passed = SUPPORT.check(TEST_NAME, "but a copy of itself made the moment a copy is created is the loop",
		_kinds(from_a_scene).has(EventSheetSpawnFindings.KIND_SPAWNS_ITSELF), true) and passed
	# And the deferred default survives the parenting rule, which is the whole reason it is deferred.
	var touched: EventSheetResource = EventSheetResource.new()
	touched.host_class = "Node2D"
	var hit: EventRow = EventRow.new()
	hit.trigger_provider_id = "Core"
	hit.trigger_id = "OnBodyEntered"
	hit.actions.append(_action("SpawnCopyOfSelf", {"name": "half", "at": "position",
		"parent": "get_parent()"}))
	touched.events.append(hit)
	passed = SUPPORT.check(TEST_NAME, "a copy of itself inside a touch handler is not the parenting Godot refuses",
		_kinds(EventSheetSpawnFindings.findings(touched,
			"res://tests/fixtures/collision_scene_enemy.tscn")).has(
			EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS), false) and passed
	return passed


# ── 5. A free spot ──


static func _test_the_free_spot_loop_answers_a_real_point() -> bool:
	var passed: bool = true
	# An arena two hundred pixels across with a wall down the left half of it, and one copy already
	# standing at the right-hand edge. The answer has to miss both.
	var arena: Dictionary = {"centre": Vector2(0, 0), "half": Vector2(100, 100)}
	var wall: Rect2 = Rect2(Vector2(-100, -100), Vector2(100, 200))
	var placed: Vector2 = Vector2(90, 0)
	var gap: float = 32.0
	var found: Variant = FreeSpot.roll_2d(arena, 200, func(point: Vector2) -> bool:
		return not wall.has_point(point) and point.distance_to(placed) >= gap)
	passed = SUPPORT.check(TEST_NAME, "a free spot is found in an arena that has room in it",
		found is Vector2, true) and passed
	if found is Vector2:
		var spot: Vector2 = found
		passed = SUPPORT.check(TEST_NAME, "the spot is not inside the wall",
			wall.has_point(spot), false) and passed
		passed = SUPPORT.check(TEST_NAME, "the spot is at least the gap from the copy already placed",
			spot.distance_to(placed) >= gap, true) and passed
		passed = SUPPORT.check(TEST_NAME, "and the spot is inside the arena that was drawn",
			Rect2(Vector2(-100, -100), Vector2(200, 200)).has_point(spot), true) and passed
	# A full arena. Nothing fits, so nothing is answered - and the loop stops rather than rolling
	# for ever, which is the whole reason the try count exists.
	passed = SUPPORT.check(TEST_NAME, "a full arena answers nothing at all",
		FreeSpot.roll_2d(arena, 8, func(_point: Vector2) -> bool: return false), null) and passed
	passed = SUPPORT.check(TEST_NAME, "and a node that draws no region answers nothing either",
		FreeSpot.roll_2d({}, 8, func(_point: Vector2) -> bool: return true), null) and passed
	# The same loop in three dimensions, over a box.
	var room: Dictionary = {"centre": Vector3(0, 0, 0), "half": Vector3(5, 1, 5)}
	var in_3d: Variant = FreeSpot.roll_3d(room, 32, func(point: Vector3) -> bool:
		return point.x > 0.0)
	passed = SUPPORT.check(TEST_NAME, "the 3D loop answers a point that passed the question asked of it",
		in_3d is Vector3 and (in_3d as Vector3).x > 0.0, true) and passed
	passed = SUPPORT.check(TEST_NAME, "and a full room answers nothing",
		FreeSpot.roll_3d(room, 8, func(_point: Vector3) -> bool: return false), null) and passed
	return passed


static func _test_the_free_spot_reads_the_shapes_it_is_given() -> bool:
	var passed: bool = true
	var zone: Area2D = Area2D.new()
	var holder: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(200, 120)
	holder.shape = box
	holder.position = Vector2(40, 0)
	zone.add_child(holder)
	var region: Dictionary = FreeSpot.region_2d(zone)
	passed = SUPPORT.check(TEST_NAME, "an Area2D is measured through the collision shape on it",
		region.get("half", Vector2.ZERO), Vector2(100, 60)) and passed
	passed = SUPPORT.check(TEST_NAME, "and around the place that shape really sits",
		region.get("centre", Vector2.ONE), Vector2(40, 0)) and passed
	var disc: CircleShape2D = CircleShape2D.new()
	disc.radius = 64.0
	holder.shape = disc
	passed = SUPPORT.check(TEST_NAME, "a circle is measured as a disc rather than as a box",
		FreeSpot.region_2d(zone).get("radius", 0.0), 64.0) and passed
	holder.shape = null
	passed = SUPPORT.check(TEST_NAME, "and a shape this file cannot roll a point inside draws no region at all",
		FreeSpot.region_2d(zone).is_empty(), true) and passed
	zone.free()
	# The shape a copy would stand in, read off a packed scene the way a spawn really reads it.
	var scene: PackedScene = _packed_body()
	var shape: Shape2D = FreeSpot.scene_shape_2d(scene)
	passed = SUPPORT.check(TEST_NAME, "a scene's own collision shape is what the clear test uses",
		shape is RectangleShape2D and (shape as RectangleShape2D).size == Vector2(16, 16),
		true) and passed
	return passed


# ── 6. The skip ──


static func _test_a_skipped_spawn_says_so() -> bool:
	var passed: bool = true
	var emitted: String = _emitted("SpawnInFreeSpot", {"scene": "load(\"res://enemy.tscn\")",
		"name": "new_enemy", "inside": "$SpawnZone", "clear_of": "[\"walls\"]", "gap": "32.0",
		"tries": "24", "parent": "self"})
	passed = SUPPORT.check(TEST_NAME, "the row asks the free-spot query for a place",
		emitted.contains("var new_enemy_spot = FreeSpot.in_2d($SpawnZone, load(\"res://enemy.tscn\"), [\"walls\"], 32.0, 24)"),
		true) and passed
	passed = SUPPORT.check(TEST_NAME, "the copy's name exists whether or not there was room, so the rows below can say it",
		emitted.contains("var new_enemy = null"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "no room means nothing is spawned and the sheet's own signal is raised",
		emitted.contains("emit_signal(&\"spawn_skipped\", load(\"res://enemy.tscn\"))"),
		true) and passed
	passed = SUPPORT.check(TEST_NAME, "and the signal is only raised when the sheet declares it",
		emitted.contains("if has_signal(&\"spawn_skipped\"):"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "room means the copy is added on the next idle moment",
		emitted.contains("self.call_deferred(\"add_child\", new_enemy)"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "the 3D twin asks the 3D query",
		_emitted("SpawnInFreeSpot3D", {"scene": "load(\"res://enemy.tscn\")", "name": "new_enemy",
			"inside": "$SpawnBox", "clear_of": "[\"walls\"]", "gap": "1.0", "tries": "24",
			"parent": "self"}).contains("FreeSpot.in_3d($SpawnBox"), true) and passed

	# And the listening half: a sheet that declares the signal gets the connection and the handler.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var declared: SignalRow = SignalRow.new()
	declared.signal_name = "spawn_skipped"
	declared.params = PackedStringArray(["scene: PackedScene"])
	sheet.events.append(declared)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnSpawnSkipped"
	event.actions.append(_action("QueueFree", {}))
	sheet.events.append(event)
	var output: String = SUPPORT.compile_output(sheet, "user://eventforge_spawn_skipped.gd")
	passed = SUPPORT.check(TEST_NAME, "the sheet declares the signal as an ordinary signal line",
		output.contains("signal spawn_skipped(scene: PackedScene)"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "On Spawn Skipped connects to it once",
		output.count("spawn_skipped.connect(_on_spawn_skipped)"), 1) and passed
	passed = SUPPORT.check(TEST_NAME, "and the handler is handed the scene that could not be placed",
		output.contains("func _on_spawn_skipped(scene: PackedScene) -> void:"), true) and passed
	return passed


# ── Harness ──


## A node that answers `despawn` and remembers what it was handed - the pool half of the retire
## decision, built here because the real one is an autoload only a running game has.
static func _fixture_pool() -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = POOL_SOURCE
	script.reload()
	var pool: Node = Node.new()
	pool.set_script(script)
	return pool


## A scene a copy would really be made of: one body with a sixteen-pixel box on it.
static func _packed_body() -> PackedScene:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.name = "Walker"
	var holder: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(16, 16)
	holder.shape = box
	body.add_child(holder)
	holder.owner = body
	var packed: PackedScene = PackedScene.new()
	packed.pack(body)
	body.free()
	return packed


static func _kinds(found: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		kinds.append(str(finding.get("kind", "")))
	return kinds


static func _message_for(found: Array[Dictionary], kind: String) -> String:
	for finding: Dictionary in found:
		if str(finding.get("kind", "")) == kind:
			return str(finding.get("message", ""))
	return ""


static func _template_of(ace_id: String) -> String:
	for descriptor: ACEDescriptor in SPAWN.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor.codegen_template
	for descriptor: ACEDescriptor in REMOVAL.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor.codegen_template
	return ""


static func _emitted(ace_id: String, values: Dictionary) -> String:
	return ActionCodegen.generate_action(_action(ace_id, values))


static func _compiled(ace_id: String, values: Dictionary, host: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = host
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action(ace_id, values))
	sheet.events.append(event)
	return SUPPORT.compile_output(sheet, "user://eventforge_retire_row.gd")


static func _action(ace_id: String, values: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = values.duplicate()
	return action


static func _first_action(sheet: EventSheetResource) -> ACEAction:
	if sheet == null:
		return null
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		for entry: Variant in (row as EventRow).actions:
			if entry is ACEAction:
				return entry as ACEAction
	return null
