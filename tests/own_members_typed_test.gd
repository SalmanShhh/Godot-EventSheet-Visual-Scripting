@tool
class_name OwnMembersTypedTest
extends RefCounted

## Behaviours that read their own members, or those of another copy of the same script, by text now name
## them: Platformer Pathfinding reads the other agents through its own class, Flock reads a neighbour's
## velocity through its own class, Post Kit sets an effect's fields through the effect scripts, and the
## three small ones name the method they hand to a Callable. These pins drive the behaviour that
## changed with the answers it gave before.

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "own_members_typed_test"
const PATHFINDING_PATH: String = "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
const FLOCK_PATH: String = "res://eventsheet_addons/flock/flock_behavior.gd"
const FLOCK_3D_PATH: String = "res://eventsheet_addons/flock_3d/flock_3d_behavior.gd"
const POST_KIT_PATH: String = "res://eventsheet_addons/post_kit/post_kit_behavior.gd"
const SETTINGS_PATH: String = "res://eventsheet_addons/game_settings/game_settings_addon.gd"
const HEALTH_PATH: String = "res://eventsheet_addons/health/health_behavior.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _pathfinding_agents() and passed
	passed = _flock_neighbour() and passed
	passed = _text_is_gone() and passed
	return passed


## Two agents that know each other through the shared list: the queue counts the pending one, and a goal
## claim made by one reads as another's to the second.
static func _pathfinding_agents() -> bool:
	var script: GDScript = load(PATHFINDING_PATH) as GDScript
	var first: Node = script.new() as Node
	var second: Node = script.new() as Node
	first.call("_register_agent")
	second.call("_register_agent")
	var idle_queue: int = int(second.call("path_queue_size"))
	first.set("_path_pending", true)
	var one_waiting: int = int(second.call("path_queue_size"))
	second.set("_path_pending", true)
	var two_waiting: int = int(second.call("path_queue_size"))
	var cell: Vector2i = Vector2i(3, 4)
	var key: String = "%s|%s" % [first.call("_map_key"), str(cell)]
	var claims: Dictionary = first.get("_goal_claims")
	claims[key] = first.get_instance_id()
	first.set("_claimed_key", key)
	var seen_by_second: bool = bool(second.call("_claimed_by_other", cell))
	var seen_by_owner: bool = bool(first.call("_claimed_by_other", cell))
	first.set("_claimed_key", "")
	var dropped: bool = bool(second.call("_claimed_by_other", cell))
	var left_over: bool = claims.has(key)
	var registry: Dictionary = first.get("_agent_ids")
	registry.erase(first.get_instance_id())
	registry.erase(second.get_instance_id())
	first.free()
	second.free()
	return SUPPORT.pins(NAME, [
		["no agent is waiting at first", idle_queue, 0],
		["one waiting agent is counted by the other", one_waiting, 1],
		["two waiting agents are both counted", two_waiting, 2],
		["a claim made by the first reads as another's to the second", seen_by_second, true],
		["and never as another's to its owner", seen_by_owner, false],
		["a claim its owner no longer holds is dropped", dropped, false],
		["and removed from the table", left_over, false],
	])


## A neighbour carrying the same flock behaviour answers with its own velocity, 2D and 3D.
static func _flock_neighbour() -> bool:
	var rows: Array = []
	var flock: GDScript = load(FLOCK_PATH) as GDScript
	var mine: Node = flock.new() as Node
	var neighbour: Node2D = Node2D.new()
	var theirs: Node = flock.new() as Node
	neighbour.add_child(theirs)
	theirs.set("flock_velocity", Vector2(3.0, -4.0))
	rows.append(["a neighbour with the same behaviour answers with its flock velocity", mine.call("_velocity_of", neighbour), Vector2(3.0, -4.0)])
	rows.append(["a neighbour with no behaviour is standing still", mine.call("_velocity_of", Node2D.new()), Vector2.ZERO])
	var flock_3d: GDScript = load(FLOCK_3D_PATH) as GDScript
	var mine_3d: Node = flock_3d.new() as Node
	var neighbour_3d: Node3D = Node3D.new()
	var theirs_3d: Node = flock_3d.new() as Node
	neighbour_3d.add_child(theirs_3d)
	theirs_3d.set("flock_velocity", Vector3(1.0, 2.0, 3.0))
	rows.append(["the 3D neighbour answers with its flock velocity", mine_3d.call("_velocity_of", neighbour_3d), Vector3(1.0, 2.0, 3.0)])
	var passed: bool = SUPPORT.pins(NAME, rows)
	neighbour.free()
	mine.free()
	neighbour_3d.free()
	mine_3d.free()
	return passed


## The text lookups this change removed stay removed.
static func _text_is_gone() -> bool:
	var pathfinding: String = FileAccess.get_file_as_string(PATHFINDING_PATH)
	var flock: String = FileAccess.get_file_as_string(FLOCK_PATH)
	var post_kit: String = FileAccess.get_file_as_string(POST_KIT_PATH)
	var settings: String = FileAccess.get_file_as_string(SETTINGS_PATH)
	var health: String = FileAccess.get_file_as_string(HEALTH_PATH)
	return SUPPORT.pins(NAME, [
		["pathfinding reads no other agent's member by text", pathfinding.contains("agent.get(\""), false],
		["pathfinding reads no claim owner's key by text", pathfinding.contains("instance_from_id(owner_id).get("), false],
		["flock reads no neighbour member by text", flock.contains("child.get(\"flock_velocity\")"), false],
		["post kit sets no effect field by text from its own rows", post_kit.contains("made.set(\"strength\""), false],
		["post kit sets the outline fields through the outline script", post_kit.contains("outline.ink = colour"), true],
		["game settings names its two handlers", settings.contains("Callable(self, \"_control_wrote\")") or settings.contains("Callable(self, \"_show_bindings\")"), false],
		["health frees its host through the method itself", health.contains("host.queue_free.call_deferred()"), true],
	])
