# EventForge module - Follow a Path (PathFollow2D / PathFollow3D)
#
# The five rows a patrol route is made of, in the words an opened script already READS a path walk
# in: move along the path at a speed, ask whether it has reached the end, send it back to the start,
# and the two switches. Every template here writes exactly the line the reading recognises, so a
# picked row and a hand-written one are the same bytes and read the same sentence.
#
# The step is written with `get_process_delta_time()` rather than a bare `delta` so the row stands on
# its own wherever it is dropped - the reading answers to both spellings.
# Module contract: see ace_factory.gd - ace_ids/templates are API (covenant).
@tool
class_name EventForgePathFollowACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CATEGORY := "Follow a Path"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.act("MoveAlongPathAt", "Move Along Path", "progress += {speed} * get_process_delta_time()", CATEGORY, "Move along path at {speed}", "Walks this follower along its route at a steady speed, whatever the frame rate.", "PathFollow2D").param("speed", "80.0", "Speed", "How far along the route it travels each second.", "expression"))
	descriptors.append(F.cond("PathReachedEnd", "Has Reached The End", "progress_ratio >= 1.0", CATEGORY, "Has reached the end", "True once this follower has travelled the whole route.", "PathFollow2D"))
	descriptors.append(F.act("PathGoToStart", "Go To Start", "progress = 0.0", CATEGORY, "Go to start", "Sends this follower back to the beginning of its route.", "PathFollow2D"))
	descriptors.append(F.act("SetPathLooping", "Set Looping", "loop = {looping}", CATEGORY, "Set looping {looping}", "Decides whether a follower that reaches the end starts again at the beginning.", "PathFollow2D").param_choice("looping", "true", "Looping", "Start again at the beginning on reaching the end?", ["true", "false"]))
	descriptors.append(F.act("SetPathRotates", "Set Rotate With Path", "rotates = {rotating}", CATEGORY, "Set rotate with path {rotating}", "Decides whether a follower turns to face the way its route is heading.", "PathFollow2D").param_choice("rotating", "true", "Rotate", "Turn to face the way the route is heading?", ["true", "false"]))

	return descriptors
