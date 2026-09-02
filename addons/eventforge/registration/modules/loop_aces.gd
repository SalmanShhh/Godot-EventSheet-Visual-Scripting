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
	descriptors.append(F.act("LoopBreak", "Break Loop", "break", "Loops", "Stop loop", "Stops the current loop early and skips any remaining items."))
	descriptors.append(F.act("LoopContinue", "Continue Loop", "continue", "Loops", "Next", "Skips to the next item in the loop, ignoring the rest of this pass."))
	descriptors.append(F.expr("CurrentItem", "Current Loop Item", "item", "Loops", "current loop item", "Gives you the item the loop is currently working on inside a For Each."))
	# The loop index counter. The counter itself is opt-in per loop (name it in the loop's
	# "Loop index" field; the convention default is loop_index) - these expressions then read
	# it as a plain local, zero runtime. LoopIndex reads the conventional name; LoopIndexNamed
	# reaches an OUTER named loop by its index name from inside a nested one.
	descriptors.append(F.expr("LoopIndex", "Loop Index", "loop_index", "Loops", "loop index (0, 1, 2…)", "Counts 0, 1, 2… for the current loop pass. Name the loop's index \"loop_index\" (the Loop index field on For Each / Repeat / While) and read it here."))
	descriptors.append(F.expr("LoopIndexNamed", "Loop Index Of", "{name}", "Loops", "loop index named {name}", "Reads a NAMED loop's counter, for nested loops: give the outer loop a distinct index name and read it from inside the inner one.").param("name", "loop_index", "Index name", "The loop-index name you gave that loop (its Loop index field).", "expression"))
	return descriptors
