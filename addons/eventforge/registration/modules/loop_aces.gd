# EventForge module - Loop control vocabulary
#
# Early-exit + current-item helpers for the pick/repeat loops the compiler emits
# (see sheet_compiler._emit_pick_filters). Break/Continue are bare keywords that must sit
# inside a loop body - the author's responsibility, same contract as a raw GDScript block.
# CurrentItem reads the default loop iterator ("item"); rename the iterator and you'd type
# its name directly instead. Module contract: see ace_factory.gd - ace_ids/templates are API.
@tool
class_name EventForgeLoopACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "LoopBreak", "Break Loop", ACEDescriptor.ACEType.ACTION, "break", "", [], "Loops", "Break out of the loop")
		.described("Stops the current loop early and skips any remaining items."))
	descriptors.append(F.make_descriptor("Core", "LoopContinue", "Continue Loop", ACEDescriptor.ACEType.ACTION, "continue", "", [], "Loops", "Skip to the next loop item")
		.described("Skips to the next item in the loop, ignoring the rest of this pass."))
	descriptors.append(F.make_descriptor("Core", "CurrentItem", "Current Loop Item", ACEDescriptor.ACEType.EXPRESSION, "item", "", [], "Loops", "current loop item")
		.described("Gives you the item the loop is currently working on inside a For Each."))
	# Construct-style loopindex. The counter itself is opt-in per loop (name it in the loop's
	# "Loop index" field; the convention default is loop_index) - these expressions then read
	# it as a plain local, zero runtime. LoopIndex reads the conventional name; LoopIndexNamed
	# is C3's loopindex("name") for reaching an OUTER named loop from inside a nested one.
	descriptors.append(F.make_descriptor("Core", "LoopIndex", "Loop Index", ACEDescriptor.ACEType.EXPRESSION, "loop_index", "", [], "Loops", "loop index (0, 1, 2…)")
		.described("Counts 0, 1, 2… for the current loop pass, like Construct's loopindex. Name the loop's index \"loop_index\" (the Loop index field on For Each / Repeat / While) and read it here."))
	descriptors.append(F.make_descriptor("Core", "LoopIndexNamed", "Loop Index Of", ACEDescriptor.ACEType.EXPRESSION, "{name}", "", [F.make_param("name", "String", "loop_index", "Index name", "The loop-index name you gave that loop (its Loop index field).", "expression")], "Loops", "loop index named {name}")
		.described("Reads a NAMED loop's counter - Construct's loopindex(\"name\") for nested loops: give the outer loop a distinct index name and read it from inside the inner one."))
	return descriptors
