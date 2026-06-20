# EventForge module — Loop control vocabulary
#
# Early-exit + current-item helpers for the pick/repeat loops the compiler emits
# (see sheet_compiler._emit_pick_filters). Break/Continue are bare keywords that must sit
# inside a loop body — the author's responsibility, same contract as a raw GDScript block.
# CurrentItem reads the default loop iterator ("item"); rename the iterator and you'd type
# its name directly instead. Module contract: see ace_factory.gd — ace_ids/templates are API.
@tool
extends RefCounted
class_name EventForgeLoopACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "LoopBreak", "Break Loop", ACEDescriptor.ACEType.ACTION, "break", "", [], "Loops", "Break out of the loop"))
	descriptors.append(F.make_descriptor("Core", "LoopContinue", "Continue Loop", ACEDescriptor.ACEType.ACTION, "continue", "", [], "Loops", "Skip to the next loop item"))
	descriptors.append(F.make_descriptor("Core", "CurrentItem", "Current Loop Item", ACEDescriptor.ACEType.EXPRESSION, "item", "", [], "Loops", "current loop item"))
	return descriptors
