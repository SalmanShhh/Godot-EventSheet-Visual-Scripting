# EventForge module - turning nodes on and off, and pausing them
#
# Two different questions that look like one:
#
#   "Is this node RUNNING?"  - process_mode. Setting it to Disabled stops _process, _physics_process
#                              and input for the node AND everything under it, which is what most
#                              people mean by deactivating something. Inherit puts it back.
#   "Is this CALLBACK on?"   - set_process / set_physics_process / set_process_input. Finer grained:
#                              stop the per-frame work but leave input alive, say.
#
# Pausing is the same property wearing a different hat. `get_tree().paused` freezes the tree, and each
# node's process_mode decides what that means FOR IT: Pausable stops (the default), Always keeps
# running (pause menus, music), When Paused runs ONLY while paused. So "pause this node" and "let this
# node run while the game is paused" are both just process_mode, which is why they live together here.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeNodeActivationACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Nodes: Activation"

## The five process modes, inserted as their real constant names so the emitted GDScript reads the way
## a Godot user expects rather than as bare integers.
const PROCESS_MODES: Array = [
	{"key": "Node.PROCESS_MODE_INHERIT", "label": "Inherit (follow the parent)"},
	{"key": "Node.PROCESS_MODE_PAUSABLE", "label": "Pausable (stops when the game pauses)"},
	{"key": "Node.PROCESS_MODE_WHEN_PAUSED", "label": "When Paused (runs ONLY while paused)"},
	{"key": "Node.PROCESS_MODE_ALWAYS", "label": "Always (ignores the game pause)"},
	{"key": "Node.PROCESS_MODE_DISABLED", "label": "Disabled (never runs)"}
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_add_whole_node(descriptors)
	_add_pausing(descriptors)
	_add_callbacks(descriptors)
	return descriptors


# ── Whole-node on/off: the verb most people are looking for. ──
static func _add_whole_node(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "DeactivateNode2D", "Deactivate Node (2D)", ACEDescriptor.ACEType.ACTION, "visible = false\nprocess_mode = Node.PROCESS_MODE_DISABLED", "", [], CAT, "Deactivate node", "CanvasItem")
		.described("Hides a node and stops it running, along with everything under it - the usual \"switch this off\" for a 2D object you want back later. Reversed by Activate Node.").featured())
	descriptors.append(F.make_descriptor("Core", "ActivateNode2D", "Activate Node (2D)", ACEDescriptor.ACEType.ACTION, "visible = true\nprocess_mode = Node.PROCESS_MODE_INHERIT", "", [], CAT, "Activate node", "CanvasItem")
		.described("Shows a node and starts it running again, along with everything under it. The exact undo of Deactivate Node.").featured())
	descriptors.append(F.make_descriptor("Core", "DeactivateNode3D", "Deactivate Node (3D)", ACEDescriptor.ACEType.ACTION, "visible = false\nprocess_mode = Node.PROCESS_MODE_DISABLED", "", [], CAT, "Deactivate node", "Node3D")
		.described("Hides a 3D node and stops it running, along with everything under it. Reversed by Activate Node.").featured())
	descriptors.append(F.make_descriptor("Core", "ActivateNode3D", "Activate Node (3D)", ACEDescriptor.ACEType.ACTION, "visible = true\nprocess_mode = Node.PROCESS_MODE_INHERIT", "", [], CAT, "Activate node", "Node3D")
		.described("Shows a 3D node and starts it running again, along with everything under it.").featured())
	descriptors.append(F.make_descriptor("Core", "NodeIsActive", "Node Is Running", ACEDescriptor.ACEType.CONDITION, "can_process()", "", [], CAT, "Node is running", "Node")
		.described("True when this node is actually running right now - it answers the whole question, taking its process mode AND whether the game is paused into account.").featured())


# ── Pausing: the same property, asked as a question about the game pause. ──
static func _add_pausing(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "NodePause", "Pause Node", ACEDescriptor.ACEType.ACTION, "process_mode = Node.PROCESS_MODE_DISABLED", "", [], CAT, "Pause node", "Node")
		.described("Freezes one node and everything under it, whatever the rest of the game is doing - a cutscene actor, a disabled turret, an off-screen room.").featured())
	descriptors.append(F.make_descriptor("Core", "NodeResume", "Unpause Node", ACEDescriptor.ACEType.ACTION, "process_mode = Node.PROCESS_MODE_INHERIT", "", [], CAT, "Unpause node", "Node")
		.described("Lets a node follow its parent again, undoing Pause Node.").featured())
	descriptors.append(F.make_descriptor("Core", "NodeRunWhilePaused", "Keep Node Running While Paused", ACEDescriptor.ACEType.ACTION, "process_mode = Node.PROCESS_MODE_ALWAYS", "", [], CAT, "Keep node running while paused", "Node")
		.described("Exempts a node from the game pause, so it keeps running while everything else is frozen. This is how a pause menu, its music, and its animations stay alive.").featured())
	descriptors.append(F.make_descriptor("Core", "NodePauseWithGame", "Pause Node With The Game", ACEDescriptor.ACEType.ACTION, "process_mode = Node.PROCESS_MODE_PAUSABLE", "", [], CAT, "Pause node with the game", "Node")
		.described("Makes a node stop when the game pauses, regardless of what its parent does. The normal behaviour, stated explicitly."))
	descriptors.append(F.make_descriptor("Core", "NodeOnlyWhenPaused", "Run Node Only While Paused", ACEDescriptor.ACEType.ACTION, "process_mode = Node.PROCESS_MODE_WHEN_PAUSED", "", [], CAT, "Run node only while paused", "Node")
		.described("Runs a node ONLY while the game is paused and never otherwise - a pause overlay that should not tick during play."))
	descriptors.append(F.make_descriptor("Core", "NodeSetProcessMode", "Set Node Process Mode", ACEDescriptor.ACEType.ACTION, "process_mode = {mode}", "", [F.make_param("mode", "String", "Node.PROCESS_MODE_INHERIT", "Mode", "How this node reacts to the game pause.", "", _mode_options())], CAT, "Set process mode to {mode}", "Node")
		.described("Sets how a node reacts to the game pause, picking any of the five modes directly. The Pause / Unpause / Keep Running verbs are shorthands for the common three."))
	descriptors.append(F.make_descriptor("Core", "NodeGetProcessMode", "Node Process Mode", ACEDescriptor.ACEType.EXPRESSION, "process_mode", "", [], CAT, "process mode", "Node")
		.described("Returns a node's current process mode, as one of the Node.PROCESS_MODE_* values."))
	descriptors.append(F.make_descriptor("Core", "NodeIsPausedByGame", "Node Is Frozen By The Game Pause", ACEDescriptor.ACEType.CONDITION, "(get_tree().paused and not can_process())", "", [], CAT, "Node is frozen by the game pause", "Node")
		.described("True when the game is paused AND this node is one of the things it froze - so a check can tell \"paused\" apart from \"paused but I am exempt\"."))


# ── Per-callback control: finer than the whole node. ──
static func _add_callbacks(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "NodeSetProcessing", "Set Node Per-Frame Processing", ACEDescriptor.ACEType.ACTION, "set_process({on})", "", [F.make_param("on", "String", "true", "Enabled", "false to stop the every-frame work.", "", ["true", "false"])], CAT, "Set per-frame processing to {on}", "Node")
		.described("Turns just the every-frame work on or off, leaving physics and input alone. Cheaper than deactivating when only the per-frame cost is the problem."))
	descriptors.append(F.make_descriptor("Core", "NodeSetPhysicsProcessing", "Set Node Physics Processing", ACEDescriptor.ACEType.ACTION, "set_physics_process({on})", "", [F.make_param("on", "String", "true", "Enabled", "false to stop the physics-step work.", "", ["true", "false"])], CAT, "Set physics processing to {on}", "Node")
		.described("Turns just the physics-step work on or off. Movement usually lives here, so this stops a body moving without hiding it."))
	descriptors.append(F.make_descriptor("Core", "NodeSetInputProcessing", "Set Node Input Handling", ACEDescriptor.ACEType.ACTION, "set_process_input({on})", "", [F.make_param("on", "String", "true", "Enabled", "false to stop receiving input events.", "", ["true", "false"])], CAT, "Set input handling to {on}", "Node")
		.described("Turns a node's input handling on or off, so it stops responding to the player while still running everything else."))
	descriptors.append(F.make_descriptor("Core", "NodeSetUnhandledInputProcessing", "Set Node Unhandled Input Handling", ACEDescriptor.ACEType.ACTION, "set_process_unhandled_input({on})", "", [F.make_param("on", "String", "true", "Enabled", "false to stop receiving unhandled input.", "", ["true", "false"])], CAT, "Set unhandled input handling to {on}", "Node")
		.described("Turns handling of UNHANDLED input on or off - the events the UI did not consume, which is where gameplay controls usually listen."))
	descriptors.append(F.make_descriptor("Core", "NodeIsProcessing", "Node Is Processing Per Frame", ACEDescriptor.ACEType.CONDITION, "is_processing()", "", [], CAT, "Node is processing per frame", "Node")
		.described("True when a node's every-frame work is switched on."))
	descriptors.append(F.make_descriptor("Core", "NodeIsPhysicsProcessing", "Node Is Physics Processing", ACEDescriptor.ACEType.CONDITION, "is_physics_processing()", "", [], CAT, "Node is physics processing", "Node")
		.described("True when a node's physics-step work is switched on."))
	descriptors.append(F.make_descriptor("Core", "NodeIsProcessingInput", "Node Is Handling Input", ACEDescriptor.ACEType.CONDITION, "is_processing_input()", "", [], CAT, "Node is handling input", "Node")
		.described("True when a node is still receiving input events."))
	descriptors.append(F.make_descriptor("Core", "NodeSetProcessPriority", "Set Node Process Order", ACEDescriptor.ACEType.ACTION, "process_priority = {priority}", "", [F.make_param("priority", "String", "0", "Priority", "Lower numbers run FIRST. Default 0.", "expression")], CAT, "Set process order to {priority}", "Node")
		.described("Decides where a node sits in the per-frame order among its siblings. Lower runs first, so a camera that must move after its target gets a higher number."))
	# `process_physics_priority`, NOT `physics_process_priority` - the setter is
	# set_physics_process_priority(), so the property name reads the other way round to the method.
	descriptors.append(F.make_descriptor("Core", "NodeSetPhysicsProcessPriority", "Set Node Physics Order", ACEDescriptor.ACEType.ACTION, "process_physics_priority = {priority}", "", [F.make_param("priority", "String", "0", "Priority", "Lower numbers run FIRST. Default 0.", "expression")], CAT, "Set physics order to {priority}", "Node")
		.described("The same ordering knob for the physics step, for when one body must resolve before another."))
	descriptors.append(F.make_descriptor("Core", "NodeIsReady", "Node Is Ready", ACEDescriptor.ACEType.CONDITION, "is_node_ready()", "", [], CAT, "Node is ready", "Node")
		.described("True once a node has finished entering the tree and its _ready has run. Guards code that reaches a freshly spawned node before it has set itself up."))


## The mode dropdown: each entry inserts the real constant and reads as plain English in the row.
static func _mode_options() -> Array:
	var options: Array = []
	for mode: Dictionary in PROCESS_MODES:
		options.append({"key": str(mode["key"]), "label": str(mode["label"])})
	return options
