# EventForge module - every move says WHOSE SPACE it means, and the three turns.
#
# The first transform bug everybody writes is "move 10 right", and the sprite drifts diagonally
# because it was rotated - or refuses to, when the drift was the point. Godot has both meanings and
# spells them differently, so the row has to say which one it is:
#
#   its own facing     position += transform.x * speed * delta        the way the node is turned
#   the world's        global_position += Vector2.RIGHT * speed * delta   the way the screen is
#
# Forward is derived per dimension and never assumed: a 2D node's own forward is its `transform.x`
# and a 3D node's is `-basis.z`, which are the two conventions that cost everybody an evening. The
# 3D half already ships (Move In Direction, whose dropdown IS the basis expression), so only the two
# 2D rows are minted here.
#
# THE THREE TURNS. Turning in place already ships. What did not was turning AROUND something - the
# orbit everybody hand-rolls with sin and cos, which Godot spells in one line as a rotated offset -
# and turning TOWARD something at a top speed, which is `rotate_toward` and reads as an aim. Both
# take their angles in degrees per the unit rule: the value carries its own conversion, so a reader
# who thinks in radians can write PI and get PI.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeSpaceWordsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker page these rows are filed on - beside the movement verbs they finish.
const CAT := "Movement"

## The four ways the WORLD points, as the dropdown a direction parameter offers: the reader picks the
## word and the file is written the constant it is. Screen order - right, left, then up and down -
## because that is how a reader says them.
const WORLD_DIRECTIONS: Array = [
	{"key": "Vector2.RIGHT", "label": "right"},
	{"key": "Vector2.LEFT", "label": "left"},
	{"key": "Vector2.UP", "label": "up"},
	{"key": "Vector2.DOWN", "label": "down"},
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_append_moves(descriptors)
	_append_turns(descriptors)
	return descriptors


## The two moves whose whole point is which space they are in. Both write the line the reading
## recognises, so a hand-typed `position += transform.x * 240 * delta` opens as the first of them.
static func _append_moves(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("MoveForwardOwnFacing", "Move Forward", "position += transform.x * {speed} * {delta_t}", CAT, "Move [b]forward[/b] [i]{speed}[/i]/s · its own facing", "Moves a 2D node the way it is FACING, whatever way that happens to be - a ship under thrust, a bullet down its own barrel, a car along its bonnet. Turning the node turns the direction with it, which is what tells this apart from moving the world's way.", "Node2D").param("speed", "240.0", "Speed", "Pixels a second.", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression").featured())
	descriptors.append(F.act("MoveTheWorldsWay", "Move (the world's way)", "global_position += {direction} * {speed} * {delta_t}", CAT, "Move [b]{direction}[/b] [i]{speed}[/i]/s · the world's way", "Moves a 2D node the way the SCREEN means, however the node is turned - drifting clouds, falling snow, a platform on rails. Rotating the node changes nothing about where it goes, which is what tells this apart from moving along its own facing.", "Node2D").param_choice("direction", "Vector2.RIGHT", "Direction", "Which way the SCREEN means - it does not turn with the node.", WORLD_DIRECTIONS).param("speed", "20.0", "Speed", "Pixels a second.", "expression").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression").featured())


## Turning around a point, and turning toward one. Both take degrees a second; both write the line a
## reading recognises.
static func _append_turns(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("TurnAroundPoint", "Turn Around", "global_position = {centre} + (global_position - {centre}).rotated(deg_to_rad({degrees_per_second}) * {delta_t})", CAT, "Turn around [i]{centre}[/i] at [b]{degrees_per_second}[/b]°/s", "Carries a 2D node round a point at a steady rate, keeping its distance - a moon round a planet, a door on its hinge, a satellite dish sweeping. The orbit everybody writes with sine and cosine, said as what it is. The node's own angle is not touched: turn it as well if it should face the way it travels.", "Node2D").param("centre", "Vector2.ZERO", "Around", "The place it goes round - a marker, another node's position, a point.", "expression").param("degrees_per_second", "30.0", "Degrees per second", "Degrees a second, turning clockwise on screen; a negative number goes the other way.", "angle").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression").featured())
	descriptors.append(F.act("FaceTargetAtSpeed", "Face", "rotation = rotate_toward(rotation, global_position.angle_to_point({target}), deg_to_rad({degrees_per_second}) * {delta_t})", CAT, "Face [i]{target}[/i], max [b]{degrees_per_second}[/b]°/s", "Turns a 2D node toward a place at a top speed instead of snapping to it - the turret leading its target, the enemy that has to swing round before it can charge. It never overshoots, and it stops when it is looking the right way.", "Node2D").param("target", "Vector2.ZERO", "Face", "The place to turn toward - a node's global position, or a point.", "expression").param("degrees_per_second", "180.0", "Max degrees per second", "The fastest it may turn. Make it huge to snap.", "angle").param("delta_t", "delta", "Delta", "Frame time; defaults to `delta`.", "expression").featured())
	descriptors.append(F.act("SwingOnHinge", "Swing", "create_tween().tween_property(self, \"rotation\", rotation + deg_to_rad({degrees}), {seconds})", CAT, "Swing [b]{degrees}[/b]° over [i]{seconds}[/i] s", "Swings a 2D node round by an amount over a time and leaves it there - a door opening, a lever thrown, a drawbridge. It turns about the node's OWN origin, so where that origin sits is the hinge: move it to the door's edge in the editor and the door swings on its edge.", "Node2D").param("degrees", "90.0", "Degrees", "How far it swings from where it is now.", "angle").param("seconds", "0.4", "Over", "How long the swing takes.", "expression").featured())


static func section_descriptions() -> Dictionary:
	return {CAT: "Moves that say whose space they mean - the node's own facing or the world's - and the turns that go round a point, face a target at a top speed, or swing by an amount over a time."}
