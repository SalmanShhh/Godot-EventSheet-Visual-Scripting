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
	descriptors.append(F.act("DeactivateNode2D", "Deactivate Node (2D)", "visible = false\nprocess_mode = Node.PROCESS_MODE_DISABLED", CAT, "Deactivate node", "Hides a node and stops it running, along with everything under it - the usual \"switch this off\" for a 2D object you want back later. Reversed by Activate Node.", "CanvasItem").featured())
	descriptors.append(F.act("ActivateNode2D", "Activate Node (2D)", "visible = true\nprocess_mode = Node.PROCESS_MODE_INHERIT", CAT, "Activate node", "Shows a node and starts it running again, along with everything under it. The exact undo of Deactivate Node.", "CanvasItem").featured())
	descriptors.append(F.act("DeactivateNode3D", "Deactivate Node (3D)", "visible = false\nprocess_mode = Node.PROCESS_MODE_DISABLED", CAT, "Deactivate node", "Hides a 3D node and stops it running, along with everything under it. Reversed by Activate Node.", "Node3D").featured())
	descriptors.append(F.act("ActivateNode3D", "Activate Node (3D)", "visible = true\nprocess_mode = Node.PROCESS_MODE_INHERIT", CAT, "Activate node", "Shows a 3D node and starts it running again, along with everything under it.", "Node3D").featured())
	descriptors.append(F.cond("NodeIsActive", "Node Is Running", "can_process()", CAT, "Node is running", "True when this node is actually running right now - it answers the whole question, taking its process mode AND whether the game is paused into account.", "Node").featured())


# ── Pausing: the same property, asked as a question about the game pause. ──
static func _add_pausing(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("NodePause", "Pause Node", "process_mode = Node.PROCESS_MODE_DISABLED", CAT, "Pause node", "Freezes one node and everything under it, whatever the rest of the game is doing - a cutscene actor, a disabled turret, an off-screen room.", "Node").featured())
	descriptors.append(F.act("NodeResume", "Unpause Node", "process_mode = Node.PROCESS_MODE_INHERIT", CAT, "Unpause node", "Lets a node follow its parent again, undoing Pause Node.", "Node").featured())
	descriptors.append(F.act("NodeRunWhilePaused", "Keep Node Running While Paused", "process_mode = Node.PROCESS_MODE_ALWAYS", CAT, "Keep node running while paused", "Exempts a node from the game pause, so it keeps running while everything else is frozen. This is how a pause menu, its music, and its animations stay alive.", "Node").featured())
	descriptors.append(F.act("NodePauseWithGame", "Pause Node With The Game", "process_mode = Node.PROCESS_MODE_PAUSABLE", CAT, "Pause node with the game", "Makes a node stop when the game pauses, regardless of what its parent does. The normal behaviour, stated explicitly.", "Node"))
	descriptors.append(F.act("NodeOnlyWhenPaused", "Run Node Only While Paused", "process_mode = Node.PROCESS_MODE_WHEN_PAUSED", CAT, "Run node only while paused", "Runs a node ONLY while the game is paused and never otherwise - a pause overlay that should not tick during play.", "Node"))
	descriptors.append(F.act("NodeSetProcessMode", "Set Node Process Mode", "process_mode = {mode}", CAT, "Set process mode to {mode}", "Sets how a node reacts to the game pause, picking any of the five modes directly. The Pause / Unpause / Keep Running actions are shorthands for the common three.", "Node").param_choice("mode", "Node.PROCESS_MODE_INHERIT", "Mode", "How this node reacts to the game pause.", _mode_options()))
	descriptors.append(F.expr("NodeGetProcessMode", "Node Process Mode", "process_mode", CAT, "process mode", "Returns a node's current process mode, as one of the Node.PROCESS_MODE_* values.", "Node"))
	descriptors.append(F.cond("NodeIsPausedByGame", "Node Is Frozen By The Game Pause", "(get_tree().paused and not can_process())", CAT, "Node is frozen by the game pause", "True when the game is paused AND this node is one of the things it froze - so a check can tell \"paused\" apart from \"paused but I am exempt\".", "Node"))


# ── Per-callback control: finer than the whole node. ──
static func _add_callbacks(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("NodeSetProcessing", "Set Node Per-Frame Processing", "set_process({on})", CAT, "Set per-frame processing to {on}", "Turns just the every-frame work on or off, leaving physics and input alone. Cheaper than deactivating when only the per-frame cost is the problem.", "Node").param_choice("on", "true", "Enabled", "false to stop the every-frame work.", ["true", "false"]))
	descriptors.append(F.act("NodeSetPhysicsProcessing", "Set Node Physics Processing", "set_physics_process({on})", CAT, "Set physics processing to {on}", "Turns just the physics-step work on or off. Movement usually lives here, so this stops a body moving without hiding it.", "Node").param_choice("on", "true", "Enabled", "false to stop the physics-step work.", ["true", "false"]))
	descriptors.append(F.act("NodeSetInputProcessing", "Set Node Input Handling", "set_process_input({on})", CAT, "Set input handling to {on}", "Turns a node's input handling on or off, so it stops responding to the player while still running everything else.", "Node").param_choice("on", "true", "Enabled", "false to stop receiving input events.", ["true", "false"]))
	descriptors.append(F.act("NodeSetUnhandledInputProcessing", "Set Node Unhandled Input Handling", "set_process_unhandled_input({on})", CAT, "Set unhandled input handling to {on}", "Turns handling of UNHANDLED input on or off - the events the UI did not consume, which is where gameplay controls usually listen.", "Node").param_choice("on", "true", "Enabled", "false to stop receiving unhandled input.", ["true", "false"]))
	descriptors.append(F.cond("NodeIsProcessing", "Node Is Processing Per Frame", "is_processing()", CAT, "Node is processing per frame", "True when a node's every-frame work is switched on.", "Node"))
	descriptors.append(F.cond("NodeIsPhysicsProcessing", "Node Is Physics Processing", "is_physics_processing()", CAT, "Node is physics processing", "True when a node's physics-step work is switched on.", "Node"))
	descriptors.append(F.cond("NodeIsProcessingInput", "Node Is Handling Input", "is_processing_input()", CAT, "Node is handling input", "True when a node is still receiving input events.", "Node"))
	descriptors.append(F.act("NodeSetProcessPriority", "Set Node Process Order", "process_priority = {priority}", CAT, "Set process order to {priority}", "Decides where a node sits in the per-frame order among its siblings. Lower runs first, so a camera that must move after its target gets a higher number.", "Node").param("priority", "0", "Priority", "Lower numbers run FIRST. Default 0.", "expression"))
	# `process_physics_priority`, NOT `physics_process_priority` - the setter is
	# set_physics_process_priority(), so the property name reads the other way round to the method.
	descriptors.append(F.act("NodeSetPhysicsProcessPriority", "Set Node Physics Order", "process_physics_priority = {priority}", CAT, "Set physics order to {priority}", "The same ordering knob for the physics step, for when one body must resolve before another.", "Node").param("priority", "0", "Priority", "Lower numbers run FIRST. Default 0.", "expression"))
	descriptors.append(F.cond("NodeIsReady", "Node Is Ready", "is_node_ready()", CAT, "Node is ready", "True once a node has finished entering the tree and its _ready has run. Guards code that reaches a freshly spawned node before it has set itself up.", "Node"))


## The mode dropdown: each entry inserts the real constant and reads as plain English in the row.
static func _mode_options() -> Array:
	var options: Array = []
	for mode: Dictionary in PROCESS_MODES:
		options.append({"key": str(mode["key"]), "label": str(mode["label"])})
	return options
