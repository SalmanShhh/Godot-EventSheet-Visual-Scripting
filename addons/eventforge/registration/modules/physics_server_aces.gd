# EventForge module - Physics Server vocabulary (world-level physics from events).
#
# The PhysicsServer2D / PhysicsServer3D controls a game reaches for at the WORLD level:
# changing gravity at runtime (strength and direction - the documented area_set_param
# recipe on the current world's space), pausing a whole physics space, and the profiling
# expressions a perf HUD reads (active bodies, collision pairs, islands). Per-body physics
# stays on the node vocabulary; joints live in the Joints module; the fixed-tick rate is
# Set Physics Rate in Time. Everything compiles to plain server calls with zero plugin
# references, honouring the parity covenant - world-scoped calls target the CURRENT
# viewport's world, the case game events want.
@tool
class_name EventForgePhysicsServerACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Physics Server"

## World-scoped calls target the current viewport's world - one shared prefix per dimension.
const SPACE_2D := "get_viewport().find_world_2d().space"
const SPACE_3D := "get_viewport().find_world_3d().space"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── 2D actions ──
	descriptors.append(F.act("PhysicsSetGravity2D", "Set World Gravity (2D)", "PhysicsServer2D.area_set_param(%s, PhysicsServer2D.AREA_PARAM_GRAVITY, {gravity})" % SPACE_2D, CAT, "set 2D world gravity to {gravity}", "Changes the whole 2D world's gravity strength at runtime - low-gravity power-ups, water levels, moon stages. Every RigidBody2D reacts; CharacterBody2D movement packs keep their own gravity knobs.").param_typed("float", "gravity", "980.0", "Gravity", "Pixels per second squared (the project default is 980).", "expression").featured())
	descriptors.append(F.act("PhysicsSetGravityVector2D", "Set World Gravity Direction (2D)", "PhysicsServer2D.area_set_param(%s, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, {direction})" % SPACE_2D, CAT, "set 2D gravity direction to {direction}", "Points the whole 2D world's gravity in a new direction - gravity-flip mechanics and rotating stages for every rigid body at once.").param("direction", "Vector2.DOWN", "Direction", "A normalized direction (Vector2.DOWN is normal; Vector2.UP flips the world).", "expression"))
	descriptors.append(F.act("PhysicsSetSpaceActive2D", "Set Physics Active (2D)", "PhysicsServer2D.space_set_active(%s, {active})" % SPACE_2D, CAT, "set 2D physics active {active}", "Pauses or resumes the whole 2D physics space - a photo mode or cutscene freeze that leaves rendering and scripts running (unlike pausing the tree).").param_typed("bool", "active", "true", "Active", "false freezes every body in the world's space.", "expression"))

	# ── 3D actions ──
	descriptors.append(F.act("PhysicsSetGravity3D", "Set World Gravity (3D)", "PhysicsServer3D.area_set_param(%s, PhysicsServer3D.AREA_PARAM_GRAVITY, {gravity})" % SPACE_3D, CAT, "set 3D world gravity to {gravity}", "Changes the whole 3D world's gravity strength at runtime - space stations, underwater sections, jump-boost arenas. Every RigidBody3D reacts; CharacterBody3D movement packs keep their own gravity knobs.").param_typed("float", "gravity", "9.8", "Gravity", "Metres per second squared (the project default is 9.8).", "expression").featured())
	descriptors.append(F.act("PhysicsSetGravityVector3D", "Set World Gravity Direction (3D)", "PhysicsServer3D.area_set_param(%s, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, {direction})" % SPACE_3D, CAT, "set 3D gravity direction to {direction}", "Points the whole 3D world's gravity in a new direction - walk-on-walls arenas and gravity puzzles for every rigid body at once.").param("direction", "Vector3.DOWN", "Direction", "A normalized direction (Vector3.DOWN is normal).", "expression"))
	descriptors.append(F.act("PhysicsSetSpaceActive3D", "Set Physics Active (3D)", "PhysicsServer3D.space_set_active(%s, {active})" % SPACE_3D, CAT, "set 3D physics active {active}", "Pauses or resumes the whole 3D physics space - freeze the simulation without pausing the tree.").param_typed("bool", "active", "true", "Active", "false freezes every body in the world's space.", "expression"))

	# ── Expressions (the perf-HUD numbers) ──
	descriptors.append(F.expr("PhysicsActiveObjects2D", "Active Bodies (2D)", "PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_ACTIVE_OBJECTS)", CAT, "active 2D bodies", "How many 2D bodies are awake and simulating - the first number to watch when physics gets slow."))
	descriptors.append(F.expr("PhysicsCollisionPairs2D", "Collision Pairs (2D)", "PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_COLLISION_PAIRS)", CAT, "2D collision pairs", "How many 2D collision pairs are being processed this step."))
	descriptors.append(F.expr("PhysicsIslands2D", "Physics Islands (2D)", "PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_ISLAND_COUNT)", CAT, "2D physics islands", "How many independent groups of touching 2D bodies the solver is working on."))
	descriptors.append(F.expr("PhysicsActiveObjects3D", "Active Bodies (3D)", "PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS)", CAT, "active 3D bodies", "How many 3D bodies are awake and simulating."))
	descriptors.append(F.expr("PhysicsCollisionPairs3D", "Collision Pairs (3D)", "PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS)", CAT, "3D collision pairs", "How many 3D collision pairs are being processed this step."))
	descriptors.append(F.expr("PhysicsIslands3D", "Physics Islands (3D)", "PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ISLAND_COUNT)", CAT, "3D physics islands", "How many independent groups of touching 3D bodies the solver is working on."))
	descriptors.append(F.expr("PhysicsInterpolationFraction", "Physics Interpolation Fraction", "Engine.get_physics_interpolation_fraction()", CAT, "physics interpolation fraction", "How far between physics ticks the current frame is (0..1) - hand-smooth visuals that follow physics bodies."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "World-level physics from events - runtime gravity strength and direction (2D and 3D), pausing a whole physics space, and the profiling numbers (active bodies, collision pairs, islands) a perf HUD reads."}
