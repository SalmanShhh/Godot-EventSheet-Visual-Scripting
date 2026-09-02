# Godot EventSheets - Checkpoint + Home & Leash behavior packs (runtime truth).
#
# Both packs are Node behaviors bound to a Node2D host (the compiled .gd resolves `host` from its
# parent in _enter_tree, which never runs treeless - so these tests bind `host` by hand and drive the
# verbs directly). Pinned here: the checkpoint round-trip and its duck-typed reset() seam, every one
# of the five leash metrics at its boundary, and that Return Home fires On Arrived Home exactly once
# on the step that lands - not on every frame the host then sits at home.
@tool
class_name CheckpointLeashTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const CHECKPOINT_PACK := "res://eventsheet_addons/checkpoint/checkpoint_behavior.gd"
const LEASH_PACK := "res://eventsheet_addons/home_leash/home_leash_behavior.gd"

# A host that defines reset(): the duck-typed seam Respawn At Checkpoint calls when it finds one.
# Built from source at runtime because the pack must not know this class exists - that is the point
# of the seam. (Methods resolve fine from an in-memory script; only `## @ace_*` annotations need a
# file on disk to be seen.)
const RESETTABLE_HOST_SOURCE := """
extends Node2D

var reset_calls: int = 0


func reset() -> void:
	reset_calls += 1
"""


static func run() -> bool:
	var ok: bool = true
	ok = _run_checkpoint() and ok
	ok = _run_leash() and ok
	return ok


static func _run_checkpoint() -> bool:
	var ok: bool = true
	var script: GDScript = load(CHECKPOINT_PACK)
	ok = _check("checkpoint pack loads + parses", script != null, true) and ok
	if script == null:
		return ok

	# --- the round-trip: mark a point, wander off, come back ---
	var host: Node2D = Node2D.new()
	var behavior: Node = script.new()
	behavior.host = host
	var respawns: Array = []
	behavior.respawned.connect(func() -> void: respawns.append(true))

	behavior.set_checkpoint_at(Vector2(10.0, 20.0))
	ok = _check("Checkpoint Position reads back the marked point", behavior.checkpoint_position(), Vector2(10.0, 20.0)) and ok
	host.global_position = Vector2(400.0, 300.0)
	behavior.respawn()
	ok = _check("Respawn puts the host back on the checkpoint", host.global_position, Vector2(10.0, 20.0)) and ok
	ok = _check("Respawn fired On Respawned once", respawns.size(), 1) and ok

	# Set Checkpoint Here marks wherever the host stands now.
	host.global_position = Vector2(-64.0, 128.0)
	behavior.set_checkpoint_here()
	host.global_position = Vector2(0.0, 0.0)
	behavior.respawn()
	ok = _check("Set Checkpoint Here marks the host's own spot", host.global_position, Vector2(-64.0, 128.0)) and ok
	ok = _check("the second respawn fired the trigger again", respawns.size(), 2) and ok
	behavior.free()
	host.free()

	# --- the reset() seam: a host that defines reset() gets it called on every respawn ---
	var reset_script: GDScript = GDScript.new()
	reset_script.source_code = RESETTABLE_HOST_SOURCE
	ok = _check("the resettable test host compiles", reset_script.reload(), OK) and ok
	var reset_host: Node2D = Node2D.new()
	reset_host.set_script(reset_script)
	var reset_behavior: Node = script.new()
	reset_behavior.host = reset_host
	reset_behavior.set_checkpoint_at(Vector2(5.0, 5.0))
	reset_host.global_position = Vector2(900.0, 900.0)
	reset_behavior.respawn()
	ok = _check("respawn calls the host's reset()", int(reset_host.get("reset_calls")), 1) and ok
	reset_behavior.respawn()
	ok = _check("every respawn calls it again", int(reset_host.get("reset_calls")), 2) and ok
	reset_behavior.free()
	reset_host.free()

	# --- the lazy capture: never marked, so the first respawn adopts where the host stands ---
	var fresh_host: Node2D = Node2D.new()
	var fresh: Node = script.new()
	fresh.host = fresh_host
	fresh_host.global_position = Vector2(7.0, 8.0)
	ok = _check("an untouched behavior has no checkpoint yet", bool(fresh.get("_has_checkpoint")), false) and ok
	fresh.respawn()
	ok = _check("the first respawn adopts the host's spot, never the origin", fresh_host.global_position, Vector2(7.0, 8.0)) and ok
	ok = _check("and records it as the checkpoint", fresh.checkpoint_position(), Vector2(7.0, 8.0)) and ok
	fresh.free()
	fresh_host.free()
	return ok


static func _run_leash() -> bool:
	var ok: bool = true
	var script: GDScript = load(LEASH_PACK)
	ok = _check("home_leash pack loads + parses", script != null, true) and ok
	if script == null:
		return ok

	var host: Node2D = Node2D.new()
	var behavior: Node = script.new()
	behavior.host = host
	behavior.set_home_at(Vector2(0.0, 0.0))
	host.global_position = Vector2(100.0, 5.0)

	# --- the five metrics, each pinned at its own value ---
	# Compared in thousandths as an INTEGER: a float equality on a hypotenuse is a coin flip.
	ok = _check("metric 0 (straight line) measures the hypotenuse", int(round(behavior.distance_from_home(0) * 1000.0)), 100125) and ok
	ok = _check("metric 1 (horizontal only) measures dx", behavior.distance_from_home(1), 100.0) and ok
	ok = _check("metric 2 (vertical only) measures dy", behavior.distance_from_home(2), 5.0) and ok
	ok = _check("metric 3 (grid steps) measures dx + dy", behavior.distance_from_home(3), 105.0) and ok
	ok = _check("metric 4 (king moves) measures the larger of the two", behavior.distance_from_home(4), 100.0) and ok

	# --- Is Beyond Home reads each metric, and each boundary is exclusive ---
	ok = _check("beyond 50 in a straight line", behavior.is_beyond_home(50.0, 0), true) and ok
	ok = _check("NOT beyond 50 vertically (the drift is only 5)", behavior.is_beyond_home(50.0, 2), false) and ok
	ok = _check("beyond 104 in grid steps", behavior.is_beyond_home(104.0, 3), true) and ok
	ok = _check("exactly 105 grid steps is not BEYOND 105", behavior.is_beyond_home(105.0, 3), false) and ok
	ok = _check("beyond 99 in king moves", behavior.is_beyond_home(99.0, 4), true) and ok
	ok = _check("exactly 100 king moves is not BEYOND 100", behavior.is_beyond_home(100.0, 4), false) and ok

	# --- Return Home: one step per call, arriving exactly once ---
	# Placed a round 100px out so the step count is exact: 100 px/s * 0.1 s = 10 px per call.
	host.global_position = Vector2(100.0, 0.0)
	var arrivals: Array = []
	behavior.arrived_home.connect(func() -> void: arrivals.append(true))
	var steps: int = 0
	while steps < 200 and arrivals.is_empty():
		behavior.return_home(100.0, 0.1)
		steps += 1
	ok = _check("Return Home walks 10px per step and lands in 10", steps, 10) and ok
	ok = _check("landing fires On Arrived Home", arrivals.size(), 1) and ok
	ok = _check("and it lands ON home", host.global_position, Vector2(0.0, 0.0)) and ok
	for _extra: int in 5:
		behavior.return_home(100.0, 0.1)
	ok = _check("sitting at home does not re-fire the trigger", arrivals.size(), 1) and ok

	# Wandering off and coming back arms the trigger again.
	host.global_position = Vector2(0.0, 30.0)
	var return_steps: int = 0
	while return_steps < 200 and arrivals.size() < 2:
		behavior.return_home(100.0, 0.1)
		return_steps += 1
	ok = _check("a second trip home fires the trigger a second time", arrivals.size(), 2) and ok

	behavior.free()
	host.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("checkpoint_leash_test", label, actual, expected)
