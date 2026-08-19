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

	descriptors.append(F.make_descriptor("Core", "MoveAlongPathAt", "Move Along Path", ACEDescriptor.ACEType.ACTION, "progress += {speed} * get_process_delta_time()", "", [F.make_param("speed", "String", "80.0", "Speed", "How far along the route it travels each second.", "expression")], CATEGORY, "Move along path at {speed}", "PathFollow2D")
		.described("Walks this follower along its route at a steady speed, whatever the frame rate."))
	descriptors.append(F.make_descriptor("Core", "PathReachedEnd", "Has Reached The End", ACEDescriptor.ACEType.CONDITION, "progress_ratio >= 1.0", "", [], CATEGORY, "Has reached the end", "PathFollow2D")
		.described("True once this follower has travelled the whole route."))
	descriptors.append(F.make_descriptor("Core", "PathGoToStart", "Go To Start", ACEDescriptor.ACEType.ACTION, "progress = 0.0", "", [], CATEGORY, "Go to start", "PathFollow2D")
		.described("Sends this follower back to the beginning of its route."))
	descriptors.append(F.make_descriptor("Core", "SetPathLooping", "Set Looping", ACEDescriptor.ACEType.ACTION, "loop = {looping}", "", [F.make_param("looping", "String", "true", "Looping", "Start again at the beginning on reaching the end?", "", ["true", "false"])], CATEGORY, "Set looping {looping}", "PathFollow2D")
		.described("Decides whether a follower that reaches the end starts again at the beginning."))
	descriptors.append(F.make_descriptor("Core", "SetPathRotates", "Set Rotate With Path", ACEDescriptor.ACEType.ACTION, "rotates = {rotating}", "", [F.make_param("rotating", "String", "true", "Rotate", "Turn to face the way the route is heading?", "", ["true", "false"])], CATEGORY, "Set rotate with path {rotating}", "PathFollow2D")
		.described("Decides whether a follower turns to face the way its route is heading."))

	return descriptors
