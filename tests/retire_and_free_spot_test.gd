# Godot EventSheets - retiring a node, copying the scene it came from, and finding room for the next
# copy.
#
# What this gate holds, in the order a reader meets it:
#   1. RETIRING. A node a pool handed out goes back to that pool; anything else is destroyed. Both
#      answers are pinned by watching what happens to the node - against the SHIPPED pool, because
#      the reparent it does, the plain array it keeps its free nodes in and the waking rather than
#      rebuilding are facts about that file and not about a stand-in. The handing back is booked for
#      the next idle moment, which is what makes the verb usable inside a collision handler, and no
#      node ever reaches a free list twice. The deciding half - "is there a pool, and did this come
#      out of it" - is pinned on its own, because it is the half a running game answers and a test
#      cannot.
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

## THE REAL POOL, by path. An earlier version of this gate held a stand-in that only remembered what
## it was handed, and a stand-in cannot fail the way the shipped pool fails: the pool takes a node
## back by REPARENTING it, its free list is a plain array that will hold the same node twice, and a
## node handed out again is woken rather than rebuilt. Every one of those is a fact about this file,
## so this file is what the retire verbs are held against.
const POOL_SCRIPT_PATH: String = "res://eventsheet_addons/object_pool/object_pool_addon.gd"

## The pool the fixtures make, and the mark the pool leaves on what it holds.
const POOL_NAME: String = "bullets"


static func run() -> bool:
	var passed: bool = true
	passed = _test_a_pooled_node_goes_back_to_its_pool() and passed
	passed = _test_retiring_into_a_pool_waits_for_the_frame() and passed
	passed = _test_an_unpooled_node_is_destroyed() and passed
	passed = _test_what_counts_as_pooled() and passed
	passed = _test_on_retired_is_one_connection() and passed
	passed = _test_a_copy_of_myself_is_the_safe_spawn() and passed
	passed = _test_a_copy_of_myself_opens_as_the_row() and passed
	passed = _test_the_doctor_says_when_there_is_no_scene_file() and passed
	passed = _test_the_free_spot_loop_answers_a_real_point() and passed
	passed = _test_the_free_spot_reads_the_shapes_it_is_given() and passed
	passed = _test_a_skipped_spawn_says_so() and passed
	passed = _test_a_skip_nobody_declared_is_a_note() and passed
	passed = _test_a_fade_puts_the_thing_back_before_it_lets_go() and passed
	passed = _test_the_two_new_triggers_survive_a_reopen() and passed
	passed = _test_the_3d_twins_read_as_the_3d_rows() and passed
	passed = _test_a_group_on_an_ancestor_still_counts() and passed
	passed = _test_the_free_spot_is_not_an_at_starter() and passed
	return passed


# ── 1. Retiring ──


static func _test_a_pooled_node_goes_back_to_its_pool() -> bool:
	var passed: bool = true
	var pool: Node = _real_pool()
	var world: Node = Node.new()
	var node: Node2D = _pooled_node(world)
	PooledNodes.hand_back(node, pool)
	passed = SUPPORT.check(TEST_NAME, "a pooled node is handed back to the pool that made it",
		int(pool.call("free_count", POOL_NAME)), 1) and passed
	passed = SUPPORT.check(TEST_NAME, "and is parked under the pool rather than destroyed",
		node.get_parent() == pool and not node.is_queued_for_deletion(), true) and passed
	# Once, and only once. A pool's free list is a plain array: a node appended to it twice is handed
	# out to two callers, which is the failure the guard exists for.
	PooledNodes.hand_back(node, pool)
	passed = SUPPORT.check(TEST_NAME, "and a node already parked in its pool is left alone",
		int(pool.call("free_count", POOL_NAME)), 1) and passed
	passed = SUPPORT.check(TEST_NAME, "so the pool never has the same node in its free list twice",
		int(pool.call("pool_size", POOL_NAME)), 1) and passed
	world.free()
	pool.free()
	return passed


## The reparent a pool does is the one thing Godot refuses inside a physics callback, so the pool
## half of the verb is BOOKED rather than done on the line. This is that claim, read the only way a
## suite with no message queue can read it: nothing has moved by the time the line returns.
static func _test_retiring_into_a_pool_waits_for_the_frame() -> bool:
	var passed: bool = true
	var pool: Node = _real_pool()
	var world: Node = Node.new()
	var node: Node2D = _pooled_node(world)
	PooledNodes.retire_into(node, pool)
	passed = SUPPORT.check(TEST_NAME, "retiring into a pool hands nothing over on the line itself",
		int(pool.call("free_count", POOL_NAME)), 0) and passed
	passed = SUPPORT.check(TEST_NAME, "so the node is still where it was for the rest of the event",
		node.get_parent() == world, true) and passed
	# Twice in one frame books one handing back, not two - the other half of never being in a free
	# list twice, and the half a parked-under-the-pool question cannot answer yet.
	PooledNodes.retire_into(node, pool)
	PooledNodes.hand_back_by_id(node.get_instance_id(), pool.get_instance_id())
	passed = SUPPORT.check(TEST_NAME, "and two retires in one frame put it back exactly once",
		int(pool.call("free_count", POOL_NAME)), 1) and passed
	world.free()
	pool.free()
	return passed


static func _test_an_unpooled_node_is_destroyed() -> bool:
	var passed: bool = true
	var pool: Node = _real_pool()
	var node: Node2D = Node2D.new()
	PooledNodes.retire_into(node, null)
	passed = SUPPORT.check(TEST_NAME, "a node no pool made is destroyed",
		node.is_queued_for_deletion(), true) and passed
	passed = SUPPORT.check(TEST_NAME, "and nothing is handed to a pool",
		int(pool.call("free_count", POOL_NAME)), 0) and passed
	# A node already on its way out is left alone, which is what makes the row safe to run twice.
	PooledNodes.retire_into(node, pool)
	PooledNodes.hand_back(node, pool)
	passed = SUPPORT.check(TEST_NAME, "and a node already on its way out is not handed anywhere",
		int(pool.call("free_count", POOL_NAME)), 0) and passed
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
		"var {name} = load(scene_file_path).instantiate()\n"
			+ "{parent}.call_deferred(\"add_child\", {name})\n"
			+ "{name}.set_deferred(\"global_position\", {at})") and passed
	passed = SUPPORT.check(TEST_NAME, "and the 3D twin writes the identical three statements",
		_template_of("SpawnCopyOfSelf3D"), _template_of("SpawnCopyOfSelf")) and passed
	# The place is BOOKED rather than written on the line, and that is the whole of what the row
	# does differently from the safe spawn it is written from: the At field opens on
	# global_position, so a place written before the copy had a parent would be read as a place
	# relative to that parent and land the copy at twice the spawner's offset.
	passed = SUPPORT.check(TEST_NAME, "filled in, it names nothing but the node's own property",
		_emitted("SpawnCopyOfSelf", {"name": "half", "at": "global_position",
			"parent": "get_parent()"}),
		"var half = load(scene_file_path).instantiate()\n"
			+ "get_parent().call_deferred(\"add_child\", half)\n"
			+ "half.set_deferred(\"global_position\", global_position)") and passed
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
	# The script this sheet IS. Without it "no scene" cannot be told apart from "nobody asked the
	# scene index", and a sheet held as a resource rather than opened from a file is always the
	# second - which is what put this note under every self-copy row in every such sheet.
	sheet.external_source_path = "res://tests/fixtures/spawn_self_copy_probe.gd"
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
	# And the case an empty scene path really is: nobody looked. A sheet that is not a file on disk
	# is never told there is no file, because nothing asked.
	var unfiled: EventSheetResource = EventSheetResource.new()
	unfiled.host_class = "Node2D"
	var made: EventRow = EventRow.new()
	made.trigger_provider_id = "Core"
	made.trigger_id = "OnReady"
	made.actions.append(_action("SpawnCopyOfSelf", {"name": "half", "at": "position",
		"parent": "get_parent()"}))
	unfiled.events.append(made)
	passed = SUPPORT.check(TEST_NAME, "a sheet nobody asked the scene index about is told nothing at all",
		_kinds(EventSheetSpawnFindings.findings(unfiled, "")).has(
			EventSheetSpawnFindings.KIND_NO_SCENE_FILE), false) and passed
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
	passed = SUPPORT.check(TEST_NAME, "the scene is read once, on the line above the question",
		emitted.contains("var new_enemy_scene = load(\"res://enemy.tscn\")"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "the row asks the free-spot query for a place",
		emitted.contains("var new_enemy_spot = FreeSpot.in_2d($SpawnZone, new_enemy_scene, [\"walls\"], 32.0, 24)"),
		true) and passed
	passed = SUPPORT.check(TEST_NAME, "the copy's name exists whether or not there was room, so the rows below can say it",
		emitted.contains("var new_enemy = null"), true) and passed
	passed = SUPPORT.check(TEST_NAME, "no room means nothing is spawned and the sheet's own signal is raised",
		emitted.contains("emit_signal(&\"spawn_skipped\", new_enemy_scene)"),
		true) and passed
	# One copy is one read of the Scene field. Spelled three times the row ran the field's own
	# starter - a load() - three times over, and a field with anything else in it three times too.
	passed = SUPPORT.check(TEST_NAME, "and the Scene field is written into the run exactly once",
		emitted.count("load(\"res://enemy.tscn\")"), 1) and passed
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


# ── 7. The skip nobody declared ──


## The one way the skip can be half wired, and the only surface that can say so. The handler is
## written whatever happens; the connect line can only be written for a signal the sheet has - so
## an event with no signal block above it looks finished and never runs once.
static func _test_a_skip_nobody_declared_is_a_note() -> bool:
	var passed: bool = true
	var bare: EventSheetResource = _sheet_listening_for_a_skip(false)
	var found: Array[Dictionary] = EventSheetSpawnFindings.findings(bare)
	passed = SUPPORT.check(TEST_NAME, "an event listening for a signal the sheet never declares is a note",
		_kinds(found).has(EventSheetSpawnFindings.KIND_SKIP_NOT_DECLARED), true) and passed
	passed = SUPPORT.check(TEST_NAME, "and the words say what to add",
		_message_for(found, EventSheetSpawnFindings.KIND_SKIP_NOT_DECLARED).contains(
			"Add a signal block"), true) and passed
	# The compiler is the reason it is silent: no signal, no connect line, and a handler nothing
	# reaches. Pinned here so the note and the reason it exists stay one fact.
	var output: String = SUPPORT.compile_output(bare, "user://eventforge_skip_undeclared.gd")
	passed = SUPPORT.check(TEST_NAME, "the file it compiles to really connects nothing",
		output.contains("spawn_skipped.connect("), false) and passed
	passed = SUPPORT.check(TEST_NAME, "and a sheet that declares the signal earns no note at all",
		_kinds(EventSheetSpawnFindings.findings(_sheet_listening_for_a_skip(true))).has(
			EventSheetSpawnFindings.KIND_SKIP_NOT_DECLARED), false) and passed
	return passed


# ── 8. The fade that hands a thing back ──


## A pool WAKES a node, it does not rebuild it, so whatever the fade left on it is what the next
## spawn of it wears. The row therefore restores the property it moved, on the line above the
## retire and in the sheet where a reader can see it.
static func _test_a_fade_puts_the_thing_back_before_it_lets_go() -> bool:
	var passed: bool = true
	var faded: String = _emitted("FadeOutAndRetire", {"object": "$Ghost", "seconds": "0.5"})
	passed = SUPPORT.check(TEST_NAME, "the 2D fade walks the alpha down and puts it back solid",
		faded,
		"await $Ghost.create_tween().tween_property($Ghost, \"modulate:a\", 0.0, 0.5).finished\n"
			+ "if is_instance_valid($Ghost):\n\t$Ghost.modulate.a = 1.0\n\t"
			+ "PooledNodes.retire($Ghost)") and passed
	passed = SUPPORT.check(TEST_NAME, "the 3D twin walks transparency up and puts it back at nothing",
		_emitted("FadeOutAndRetire3D", {"object": "$Mesh", "seconds": "0.5"}),
		"await $Mesh.create_tween().tween_property($Mesh, \"transparency\", 1.0, 0.5).finished\n"
			+ "if is_instance_valid($Mesh):\n\t$Mesh.transparency = 0.0\n\t"
			+ "PooledNodes.retire($Mesh)") and passed
	# And WHERE the 3D row is offered, which is the other half of the same fact: `transparency` is
	# declared on what is drawn, not on what moves, so a tween aimed at a body finds no such
	# property, returns nothing, and takes the event down with it.
	passed = SUPPORT.check(TEST_NAME, "and the 3D fade is offered on the thing that is drawn",
		_host_of("FadeOutAndRetire3D"), "GeometryInstance3D") and passed
	passed = SUPPORT.check(TEST_NAME, "as its 2D twin is offered on the thing that has a modulate",
		_host_of("FadeOutAndRetire"), "CanvasItem") and passed
	return passed


# ── 9. Both new triggers, through a save and an open ──


## `.gd` is the sheet format, so a trigger that does not survive a reopen is a trigger a reader
## sees exactly once. Both of these are ordinary connects whose SIGNAL is spoken for elsewhere -
## `tree_exiting` by On Tree Exiting, `spawn_skipped` by any project that declares it - so the
## handler's own name is what says which reading a file's connect line is.
static func _test_the_two_new_triggers_survive_a_reopen() -> bool:
	var passed: bool = true
	var retired: EventSheetResource = EventSheetResource.new()
	retired.host_class = "Node2D"
	var leaving: EventRow = EventRow.new()
	leaving.trigger_provider_id = "Core"
	leaving.trigger_id = "OnRetired"
	leaving.actions.append(_action("Retire", {"object": "self"}))
	retired.events.append(leaving)
	var retired_source: String = SUPPORT.compile_output(retired,
		"user://eventforge_retired_reopen.gd")
	passed = SUPPORT.check(TEST_NAME, "a saved On Retired opens as On Retired",
		_first_trigger(SUPPORT.reopen(retired_source)), "OnRetired") and passed
	passed = SUPPORT.check(TEST_NAME, "and the file re-emits byte for byte",
		SUPPORT.reemit(retired_source, "user://eventforge_retired_roundtrip.gd") == retired_source,
		true) and passed
	# The frozen row that shares the signal keeps its own reading, which is the whole point of
	# asking the handler name rather than the signal.
	var exiting: EventSheetResource = EventSheetResource.new()
	exiting.host_class = "Node2D"
	var bare: EventRow = EventRow.new()
	bare.trigger_provider_id = "Core"
	bare.trigger_id = "OnTreeExiting"
	bare.actions.append(_action("QueueFree", {}))
	exiting.events.append(bare)
	passed = SUPPORT.check(TEST_NAME, "and On Tree Exiting still opens as On Tree Exiting",
		_first_trigger(SUPPORT.reopen(SUPPORT.compile_output(exiting,
			"user://eventforge_tree_exiting_reopen.gd"))), "OnTreeExiting") and passed
	var skipped: EventSheetResource = _sheet_listening_for_a_skip(true)
	var skipped_source: String = SUPPORT.compile_output(skipped,
		"user://eventforge_skipped_reopen.gd")
	passed = SUPPORT.check(TEST_NAME, "a saved On Spawn Skipped opens as On Spawn Skipped",
		_first_trigger(SUPPORT.reopen(skipped_source)), "OnSpawnSkipped") and passed
	passed = SUPPORT.check(TEST_NAME, "and that file re-emits byte for byte too",
		SUPPORT.reemit(skipped_source, "user://eventforge_skipped_roundtrip.gd") == skipped_source,
		true) and passed
	return passed


# ── 10. The two runs that are the same characters in both dimensions ──


## A line formation and a copy of the node's own scene write identical statements in 2D and in 3D,
## so the run table holds one entry for each and the class the file extends says which row a
## reader is shown. Read as the 2D row, a 3D file arrived carrying a size in pixels, a 2D
## collision shape and four branches that write Vector2 into a Node3D.
static func _test_the_3d_twins_read_as_the_3d_rows() -> bool:
	var passed: bool = true
	var line: Dictionary = {"scene": "Enemy", "name": "wave", "formation": SPAWN.FORMATION_LINE,
		"count": "4", "around": "global_position", "to": "global_position + Vector3(10, 0, 0)",
		"crowd": "\"enemies\"", "parent": "self", "when": SPAWN.WHEN_NOW}
	var in_3d: ACEAction = _first_action(SUPPORT.reopen(_compiled("SpawnFormation3D", line,
		"Node3D")))
	passed = SUPPORT.check(TEST_NAME, "a line formation in a 3D file opens as the 3D row",
		"" if in_3d == null else in_3d.ace_id, "SpawnFormation3D") and passed
	if in_3d != null:
		passed = SUPPORT.check(TEST_NAME, "carrying the 3D row's own size rather than a count of pixels",
			str(in_3d.params.get("size", "")), "5.0") and passed
		passed = SUPPORT.check(TEST_NAME, "and the 3D shape to scatter in rather than a 2D one",
			str(in_3d.params.get("inside", "")), "$SpawnBox") and passed
		passed = SUPPORT.check(TEST_NAME, "while what the line itself said is read from the line",
			str(in_3d.params.get("to", "")), "global_position + Vector3(10, 0, 0)") and passed
	var in_2d: ACEAction = _first_action(SUPPORT.reopen(_compiled("SpawnFormation", {
		"scene": "Enemy", "name": "wave", "formation": SPAWN.FORMATION_LINE, "count": "4",
		"around": "global_position", "to": "global_position + Vector2(200, 0)",
		"crowd": "\"enemies\"", "parent": "self", "when": SPAWN.WHEN_NOW}, "Node2D")))
	passed = SUPPORT.check(TEST_NAME, "and the same shape in a 2D file still opens as the 2D row",
		"" if in_2d == null else in_2d.ace_id, "SpawnFormation") and passed
	var copy_values: Dictionary = {"name": "half", "at": "global_position",
		"parent": "get_parent()"}
	var self_3d: ACEAction = _first_action(SUPPORT.reopen(_compiled("SpawnCopyOfSelf3D",
		copy_values, "Node3D")))
	passed = SUPPORT.check(TEST_NAME, "a copy of the node's own scene in a 3D file opens as the 3D row",
		"" if self_3d == null else self_3d.ace_id, "SpawnCopyOfSelf3D") and passed
	var self_2d: ACEAction = _first_action(SUPPORT.reopen(_compiled("SpawnCopyOfSelf",
		copy_values, "Node2D")))
	passed = SUPPORT.check(TEST_NAME, "and in a 2D file it opens as the 2D row, as it always did",
		"" if self_2d == null else self_2d.ace_id, "SpawnCopyOfSelf") and passed
	return passed


# ── 11. What the clearance test really asks ──


## A level is drawn as a scene and a scene is put in a group by its ROOT, so the body that answers
## a physics query is almost never the node the group name was written on. Asking only the collider
## answered "nothing is standing here" inside a wall whose root said otherwise.
static func _test_a_group_on_an_ancestor_still_counts() -> bool:
	var passed: bool = true
	var level: Node2D = Node2D.new()
	level.add_to_group(&"walls", true)
	var body: StaticBody2D = StaticBody2D.new()
	level.add_child(body)
	passed = SUPPORT.check(TEST_NAME, "a body under a node in the group is in the group for this question",
		FreeSpot.in_any_group(body, ["walls"]), true) and passed
	passed = SUPPORT.check(TEST_NAME, "the node that carries the name answers too",
		FreeSpot.in_any_group(level, ["walls"]), true) and passed
	var elsewhere: StaticBody2D = StaticBody2D.new()
	passed = SUPPORT.check(TEST_NAME, "and a body under nothing in the group is still clear",
		FreeSpot.in_any_group(elsewhere, ["walls"]), false) and passed
	elsewhere.free()
	passed = SUPPORT.check(TEST_NAME, "as is anything that is not a node at all",
		FreeSpot.in_any_group(null, ["walls"]), false) and passed
	level.free()
	return passed


## The free-spot question is the one placement word that can answer NOTHING, and every row that
## reads the At starters writes its answer straight into a position - so a full arena would put
## null where a Vector2 belongs, on a line that has shipped. It belongs to the row that knows what
## to do about an answer of nothing, and to no other.
static func _test_the_free_spot_is_not_an_at_starter() -> bool:
	var passed: bool = true
	passed = SUPPORT.check(TEST_NAME, "the At field offers the places, and not the question",
		" | ".join(SPAWN.PLACEMENT_STARTERS),
		"global_position | $SpawnPoint.global_position | Vector2(0, 0)") and passed
	passed = SUPPORT.check(TEST_NAME, "and the same in three dimensions",
		" | ".join(SPAWN.PLACEMENT_STARTERS_3D),
		"global_position | $SpawnPoint.global_position | Vector3(0, 0, 0)") and passed
	return passed


# ── Harness ──


## The shipped pool, driven directly rather than through the autoload path a running game resolves.
## An empty pool, because what is being watched is what happens to a node handed BACK, and a pool
## with a scene in it would answer that question with a copy nobody asked for.
static func _real_pool() -> Node:
	var pool: Node = Node.new()
	pool.set_script(load(POOL_SCRIPT_PATH))
	pool.call("create_empty_pool", POOL_NAME)
	return pool


## A node standing in the world wearing the mark a pool leaves on everything it hands out. The mark
## is what the retire decision reads, and `world` is what the node is parked under until it goes
## back - so "did it move" is a question the test can ask of the tree.
static func _pooled_node(world: Node) -> Node2D:
	var node: Node2D = Node2D.new()
	node.set_meta(PooledNodes.POOL_META, POOL_NAME)
	world.add_child(node)
	return node


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


## A sheet with an On Spawn Skipped event in it, with or without the signal block that makes it
## reachable. Both halves are ordinary Godot, which is exactly why one of them can be missing.
static func _sheet_listening_for_a_skip(declared: bool) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	if declared:
		var row: SignalRow = SignalRow.new()
		row.signal_name = "spawn_skipped"
		row.params = PackedStringArray(["scene: PackedScene"])
		sheet.events.append(row)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnSpawnSkipped"
	event.actions.append(_action("QueueFree", {}))
	sheet.events.append(event)
	return sheet


## The host class a row is offered on, which is where a row belongs as much as its category is.
static func _host_of(ace_id: String) -> String:
	for descriptor: ACEDescriptor in REMOVAL.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor.node_type
	return ""


## The trigger the first event of a reopened sheet holds - the whole of what a reopen has to keep
## for a trigger row to survive being saved.
static func _first_trigger(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	for row: Variant in sheet.events:
		if row is EventRow and not str((row as EventRow).trigger_id).is_empty():
			return str((row as EventRow).trigger_id)
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
