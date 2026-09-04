## @ace_version(1.0.0)
class_name FreeSpot
extends RefCounted
## A place to put the next copy that nothing is already standing in - the roll-until-it-fits query the free-spot placement words and the free-spot spawn rows call.

# A place to put the next copy, that nothing is already standing in.
#
# The other placement words are one expression each, because "where" is one measurement: a node's
# own place, a point along a path, a point inside a shape. A FREE spot is not one measurement - it
# is the same roll asked over and over until the answer is somewhere the copy actually fits - so it
# is the one placement word that is a function rather than a line, and this is that function.
#
# WHAT "FREE" MEANS HERE, in the order the three questions are asked:
#   inside      the point is rolled inside a shape somebody drew - the Area2D around the spawn
#               zone, the collision shape on it, or a Control's own rectangle.
#   apart       the point is at least the gap from every other copy of the same scene already in
#               the world, which is what keeps a wave from landing on top of itself.
#   clear of    the copy's OWN collision shape, put at that point, would not overlap anything in
#               the named groups, or anything standing under something in them - a level is put in a
#               group by its ROOT, and the body that answers a physics query is a child of that. That
#               is a real physics query in the same space the game runs in, so a wall is a wall
#               whatever drew it. A group whose members carry no collision
#               shape at all cannot be asked that question, so those members are answered the only
#               way they can be: the point has to be further than the gap from every one of them.
#
# AND IT ANSWERS NOTHING WHEN THERE IS NOTHING TO ANSWER. After the last try it returns null, which
# is a real answer and not a failure: a full arena has no free spot in it, and a spawn row that
# reads null spawns nothing and says so. Rolling for ever instead would be a hang.
#
# THE COST, said plainly. One call instantiates the scene once to read its collision shape and frees
# it again, and walks the running scene once to find the copies already placed. Both are done ONCE
# per call and reused across every try, so the price of raising the try count is the rolls
# themselves. A spawn per frame is fine; a thousand spawns in one frame wants a pool.
#
# PLAIN GDSCRIPT, AND NOT THE PLUGIN'S. Nothing here touches an editor, a sheet or any class the
# plugin declares, and this file is not one of the plugin's files: it ships beside the behaviour
# packs, in the folder that is the project's own, so deleting the editor addon leaves every emitted
# line that names it still parsing and still running. That is the whole reason the rows can call it.

## How many points to roll before answering nothing. The rows offer their own field; this is what a
## call that leaves it out uses.
const DEFAULT_TRIES: int = 24

## The ceiling on one clearance query. A point standing in a crowd is refused by the first hit, so
## this only bounds the pathological case where a query is asked inside a pile.
const MAX_HITS: int = 32


## A point inside `inside` that nothing in `clear_of` is standing in and no other copy of `scene` is
## within `gap` pixels of, or null after `tries` rolls. `inside` is a CollisionShape2D, an Area2D or
## a Control; `clear_of` holds group names.
static func in_2d(inside: Node, scene: PackedScene, clear_of: Array, gap: float,
		tries: int = DEFAULT_TRIES) -> Variant:
	if inside == null or not is_instance_valid(inside) or not inside.is_inside_tree():
		return null
	if scene == null:
		return null
	var region: Dictionary = region_2d(inside)
	if region.is_empty():
		return null
	var world: World2D = inside.get_viewport().find_world_2d() if inside.get_viewport() != null else null
	var space: PhysicsDirectSpaceState2D = world.direct_space_state if world != null else null
	var shape: Shape2D = scene_shape_2d(scene)
	var placed: Array[Node] = _copies_of(inside, scene)
	var watched: Array[Node] = _members_without_shapes(inside, clear_of, "CollisionShape2D")
	return roll_2d(region, tries, func(point: Vector2) -> bool:
		if not _far_enough_2d(point, placed, gap):
			return false
		if not _far_enough_2d(point, watched, gap):
			return false
		return _clear_2d(space, shape, point, clear_of))


## The same question in three dimensions, with the gap measured in metres. `inside` is a
## CollisionShape3D or an Area3D.
static func in_3d(inside: Node, scene: PackedScene, clear_of: Array, gap: float,
		tries: int = DEFAULT_TRIES) -> Variant:
	if inside == null or not is_instance_valid(inside) or not inside.is_inside_tree():
		return null
	if scene == null:
		return null
	var region: Dictionary = region_3d(inside)
	if region.is_empty():
		return null
	var world: World3D = inside.get_viewport().find_world_3d() if inside.get_viewport() != null else null
	var space: PhysicsDirectSpaceState3D = world.direct_space_state if world != null else null
	var shape: Shape3D = scene_shape_3d(scene)
	var placed: Array[Node] = _copies_of(inside, scene)
	var watched: Array[Node] = _members_without_shapes(inside, clear_of, "CollisionShape3D")
	return roll_3d(region, tries, func(point: Vector3) -> bool:
		if not _far_enough_3d(point, placed, gap):
			return false
		if not _far_enough_3d(point, watched, gap):
			return false
		return _clear_3d(space, shape, point, clear_of))
## The collision shape a copy of this scene would stand in, or null when it carries none. Read by
## building the scene once and freeing it again, because a packed scene's shape is a property of the
## node inside it and there is no cheaper honest way to ask.
static func scene_shape_2d(scene: PackedScene) -> Shape2D:
	if scene == null or not scene.can_instantiate():
		return null
	var built: Node = scene.instantiate()
	var found: Node = _first_of_class(built, "CollisionShape2D")
	var shape: Shape2D = (found as CollisionShape2D).shape if found is CollisionShape2D else null
	built.free()
	return shape
## The same, in three dimensions.
static func scene_shape_3d(scene: PackedScene) -> Shape3D:
	if scene == null or not scene.can_instantiate():
		return null
	var built: Node = scene.instantiate()
	var found: Node = _first_of_class(built, "CollisionShape3D")
	var shape: Shape3D = (found as CollisionShape3D).shape if found is CollisionShape3D else null
	built.free()
	return shape
# -- the three questions --------------------------------------------------------------------------


## True when the copy's own shape, put at this point, overlaps nothing in the named groups. A scene
## with no collision shape of its own, or a world with no space to ask in, answers true here and
## leans entirely on the distance test beside it.
static func _clear_2d(space: PhysicsDirectSpaceState2D, shape: Shape2D, point: Vector2,
		clear_of: Array) -> bool:
	if space == null or shape == null or clear_of.is_empty():
		return true
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	for hit: Dictionary in space.intersect_shape(query, MAX_HITS):
		if in_any_group(hit.get("collider"), clear_of):
			return false
	return true


## The same query in three dimensions.
static func _clear_3d(space: PhysicsDirectSpaceState3D, shape: Shape3D, point: Vector3,
		clear_of: Array) -> bool:
	if space == null or shape == null or clear_of.is_empty():
		return true
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	for hit: Dictionary in space.intersect_shape(query, MAX_HITS):
		if in_any_group(hit.get("collider"), clear_of):
			return false
	return true
# -- what is already in the world -----------------------------------------------------------------
## Every node already in the running scene that was made from this same scene file. Asked of the
## node's own `scene_file_path`, which Godot fills in for anything instanced from a `.tscn`, so a
## copy counts however it was made.
static func _copies_of(inside: Node, scene: PackedScene) -> Array[Node]:
	var found: Array[Node] = []
	var wanted: String = scene.resource_path
	if wanted.is_empty() or inside.get_tree() == null:
		return found
	var root: Node = inside.get_tree().current_scene
	if root == null:
		root = inside.get_tree().root
	_collect_copies(root, wanted, found)
	return found
## The members of the named groups that carry no collision shape - the ones a physics query cannot
## answer for. They are what the distance test is really for: a marker, a waypoint, a bare Node2D
## somebody dropped to say "not here".
static func _members_without_shapes(inside: Node, groups: Array,
		shape_class: String) -> Array[Node]:
	var found: Array[Node] = []
	if inside.get_tree() == null:
		return found
	for group: Variant in groups:
		for member: Node in inside.get_tree().get_nodes_in_group(StringName(str(group))):
			if _first_of_class(member, shape_class) == null:
				found.append(member)
	return found
## The first node of a class at or under this one, in tree order, or null. Used to find the shape a
## scene stands in and to ask whether a group member has one at all.
static func _first_of_class(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if node.is_class(wanted):
		return node
	for child: Node in node.get_children():
		var found: Node = _first_of_class(child, wanted)
		if found != null:
			return found
	return null

## THE LOOP ITSELF, with the questions handed in. `region` is what the two calls above measured of
## the node somebody drew; `is_free` answers, for one point, whether the copy would fit there. It is
## separated from the world-reading half above for a plain reason: everything about giving up after
## a number of tries is true whatever the questions are, and a loop that can only be exercised with
## a live physics space is a loop nobody can pin a value on.
static func roll_2d(region: Dictionary, tries: int, is_free: Callable) -> Variant:
	if region.is_empty():
		return null
	for _attempt: int in range(maxi(tries, 1)):
		var point: Vector2 = _roll_2d(region)
		if bool(is_free.call(point)):
			return point
	return null

## The same loop in three dimensions.
static func roll_3d(region: Dictionary, tries: int, is_free: Callable) -> Variant:
	if region.is_empty():
		return null
	for _attempt: int in range(maxi(tries, 1)):
		var point: Vector3 = _roll_3d(region)
		if bool(is_free.call(point)):
			return point
	return null

## The region a node stands for, as the two answers this file can roll a point in: a rectangle
## (`centre` and `half`) or a disc (`centre` and `radius`). An empty dictionary for a node that
## draws no region, which is what makes the caller answer null rather than scatter copies over the
## origin.
static func region_2d(inside: Node) -> Dictionary:
	if inside is Area2D:
		var child: Node = _first_of_class(inside, "CollisionShape2D")
		return region_2d(child) if child != null else {}
	if inside is CollisionShape2D:
		var holder: CollisionShape2D = inside as CollisionShape2D
		var shape: Shape2D = holder.shape
		if shape is RectangleShape2D:
			return {"centre": holder.global_position, "half": (shape as RectangleShape2D).size * 0.5}
		if shape is CircleShape2D:
			return {"centre": holder.global_position, "radius": (shape as CircleShape2D).radius}
		return {}
	if inside is Control:
		var box: Control = inside as Control
		return {"centre": box.global_position + box.size * 0.5, "half": box.size * 0.5}
	return {}

## The same in three dimensions: a box (`half` a Vector3) or a sphere (`radius`).
static func region_3d(inside: Node) -> Dictionary:
	# -- where the points are rolled ------------------------------------------------------------------
	if inside is Area3D:
		var child: Node = _first_of_class(inside, "CollisionShape3D")
		return region_3d(child) if child != null else {}
	if inside is CollisionShape3D:
		var holder: CollisionShape3D = inside as CollisionShape3D
		var shape: Shape3D = holder.shape
		if shape is BoxShape3D:
			return {"centre": holder.global_position, "half": (shape as BoxShape3D).size * 0.5}
		if shape is SphereShape3D:
			return {"centre": holder.global_position, "radius": (shape as SphereShape3D).radius}
		return {}
	return {}

## One point inside a 2D region. The disc takes the square root of the roll so points do not bunch
## up in the middle, which is the same correction the shipped scatter expression makes.
static func _roll_2d(region: Dictionary) -> Vector2:
	var centre: Vector2 = region.get("centre", Vector2.ZERO)
	if region.has("radius"):
		var radius: float = float(region["radius"]) * sqrt(randf())
		return centre + Vector2.RIGHT.rotated(randf() * TAU) * radius
	var half: Vector2 = region.get("half", Vector2.ZERO)
	return centre + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))

## One point inside a 3D region. The sphere takes the cube root of the roll for the reason the disc
## takes the square root: an even scatter through a volume needs it.
static func _roll_3d(region: Dictionary) -> Vector3:
	var centre: Vector3 = region.get("centre", Vector3.ZERO)
	if region.has("radius"):
		var radius: float = float(region["radius"]) * pow(randf(), 1.0 / 3.0)
		var direction: Vector3 = Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0))
		if direction.length() <= 0.0:
			direction = Vector3.UP
		return centre + direction.normalized() * radius
	var half: Vector3 = region.get("half", Vector3.ZERO)
	return centre + Vector3(randf_range(-half.x, half.x), randf_range(-half.y, half.y),
		randf_range(-half.z, half.z))

## True when the point is at least `gap` from every node in the list. A gap of nothing asks nothing,
## which is how a caller says it only cares about overlapping.
static func _far_enough_2d(point: Vector2, others: Array[Node], gap: float) -> bool:
	if gap <= 0.0:
		return true
	for other: Node in others:
		if other is Node2D and point.distance_to((other as Node2D).global_position) < gap:
			return false
	return true

## The same, in three dimensions.
static func _far_enough_3d(point: Vector3, others: Array[Node], gap: float) -> bool:
	if gap <= 0.0:
		return true
	for other: Node in others:
		if other is Node3D and point.distance_to((other as Node3D).global_position) < gap:
			return false
	return true

## The walk behind the list above, kept separate so the answer is one recursion with one condition
## in it rather than a filter over the whole tree.
static func _collect_copies(node: Node, wanted: String, into: Array[Node]) -> void:
	if node.scene_file_path == wanted:
		into.append(node)
	for child: Node in node.get_children():
		_collect_copies(child, wanted, into)

## True when the object is a node belonging to any of the named groups, or standing UNDER one that
## does. The walk up is not a nicety: a level is drawn as a scene, and a scene is put in a group by
## its root, so the thing that answers a physics query - the StaticBody2D two levels down with the
## shape on it - is almost never the node the group name was written on. Asking only the collider
## answered "nothing is standing here" inside a wall whose root said otherwise.
##
## Public for the reason the two roll loops above are: the clearance test needs a live physics space
## and this question does not, so this is the half of it that can be held to a value.
static func in_any_group(collider: Variant, groups: Array) -> bool:
	var node: Node = collider as Node
	while node != null:
		for group: Variant in groups:
			if node.is_in_group(StringName(str(group))):
				return true
		node = node.get_parent()
	return false
