# EventForge - the ONE reading of an EDGE trigger: the moment a standing state CHANGED.
#
# Four things a game asks that no engine signal answers on its own:
#
#     On landed              the step the character's feet arrived on the floor
#     On left the ground     the step they left it, whether by jumping or by walking off
#     On first overlap       the arrival that took this area from empty to occupied
#     On last overlap ended  the departure that left it empty again
#
# None of the four is a signal. Godot answers "am I on the floor?" and "what is inside me?" as
# STANDING questions; the moment one of them changed is the difference between this step's answer
# and last step's, and something has to remember last step's. That remembering is the whole of what
# these rows add, and it is the single most-typed piece of state in any platformer:
#
#     var was_on_floor: bool = false
#
#     func _physics_process(delta: float) -> void:
#         if is_on_floor() and not was_on_floor:
#             land()
#         was_on_floor = is_on_floor()
#
# THE COMPARISON COMES BEFORE THE UPDATE. That ordering is the pattern - swap the two and the row
# can never be true, because the memory already agrees with the present by the time it is asked.
# The rows below keep that ordering visible: the floor pair carries its memory and the step that
# updates it as a member the compiler declares beside the handler, so an author reading the emitted
# file sees the same three parts they would have typed.
#
# THE AREA PAIR NEEDS NO MEMORY, and saying so is the point of putting all four in one file. An
# area's arrivals and departures ARE signals, and Godot has already updated the overlap list by the
# time it raises one - so "this is the first one in" is the list having exactly one thing in it, and
# "that was the last one out" is the list being empty. A remembered count would answer the same
# question one step later and cost a tick of state to do it, so these two are asked outright.
#
# Every edge trigger is a PLAIN trigger with a GATE CONDITION under it, added when the row is
# applied and visible in the sheet from then on: the trigger says which engine callback the event
# lives in, and the gate says which moment of it the event answers. Nothing about an edge happens
# off the row - the gate can be read, edited, disabled and deleted like any other condition, and it
# is an ordinary condition on disk.
#
# Three readers share this file so they can never disagree: the trigger resolver (which callback an
# edge trigger compiles into, and which handler it shares), the dock's apply step (which gate goes
# under which trigger), and the suite.
@tool
class_name EventForgeCollisionEdges
extends RefCounted

## Every edge trigger id -> what the compiler and the dock need to know about it:
##   trigger  the trigger this one SHARES A HANDLER WITH. An edge is not its own callback: landing
##            is a moment of the physics step, and a first overlap is a moment of body_entered. Two
##            functions of one name do not parse, so the key an edge groups under is this one's.
##   gate     the condition applied under the trigger, which is where the edge itself is said.
## Frozen the way every shipped ace_id is: an edge trigger is deprecated rather than renamed.
const EDGE_TRIGGERS: Dictionary = {
	"OnLanded": {"trigger": "OnPhysicsProcess", "gate": "JustLanded"},
	"OnLanded3D": {"trigger": "OnPhysicsProcess", "gate": "JustLanded3D"},
	"OnLeftTheGround": {"trigger": "OnPhysicsProcess", "gate": "JustLeftTheGround"},
	"OnLeftTheGround3D": {"trigger": "OnPhysicsProcess", "gate": "JustLeftTheGround3D"},
	"OnFirstOverlap": {"trigger": "OnBodyEntered", "gate": "IsTheFirstOneIn"},
	"OnFirstOverlap3D": {"trigger": "OnBodyEntered", "gate": "IsTheFirstOneIn3D"},
	"OnLastOverlapEnded": {"trigger": "OnBodyExited", "gate": "WasTheLastOneOut"},
	"OnLastOverlapEnded3D": {"trigger": "OnBodyExited", "gate": "WasTheLastOneOut3D"}
}


## True when this trigger id is one of the eight.
static func is_edge(trigger_id: String) -> bool:
	return EDGE_TRIGGERS.has(trigger_id)


## The trigger an edge one shares its handler with, or "" for anything else. The resolver reads its
## signature through this, so an edge trigger can never ask for a second function of a name the
## sheet already has.
static func host_trigger_for(trigger_id: String) -> String:
	if not is_edge(trigger_id):
		return ""
	return str((EDGE_TRIGGERS[trigger_id] as Dictionary).get("trigger", ""))


## The gate condition's ace_id for an edge trigger, "" for anything else.
static func gate_for(trigger_id: String) -> String:
	if not is_edge(trigger_id):
		return ""
	return str((EDGE_TRIGGERS[trigger_id] as Dictionary).get("gate", ""))


## The edge trigger a gate condition belongs under, "" when this is not an edge gate. The inverse of
## gate_for, walked rather than kept as a second table so the one table above cannot drift from it.
static func trigger_for_gate(gate_id: String) -> String:
	for trigger_id: String in EDGE_TRIGGERS:
		if str((EDGE_TRIGGERS[trigger_id] as Dictionary).get("gate", "")) == gate_id:
			return trigger_id
	return ""


## The same id filed for the dimension a host class belongs to: the 3D twin for a 3D class, the id
## itself otherwise. The two dimensions' rows say the same thing and compile to the same line - what
## differs is only the class the picker files them under - so a lift that read `is_on_floor()` out of
## a CharacterBody3D script hands back the row a 3D sheet would have offered.
static func for_class(ace_id: String, class_text: String) -> String:
	if ace_id.is_empty() or ace_id.ends_with("3D"):
		return ace_id
	var name_text: String = class_text.strip_edges()
	var is_3d: bool = name_text.ends_with("3D") \
		or (ClassDB.class_exists(name_text) and ClassDB.is_parent_class(name_text, "Node3D"))
	return "%s3D" % ace_id if is_3d else ace_id
