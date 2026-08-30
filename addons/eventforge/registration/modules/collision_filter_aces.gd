# EventForge module - the filtered collision sentences.
#
# The bare touch triggers beside these say THAT something arrived; a game almost always wants to
# know that the PLAYER arrived, or a bullet, or a pickup. Written by hand that is a handler with an
# early return at the top, and it is the single most-typed line in any collision script. Here it is
# the row's own With field: the group is a PARAMETER, never a clause, and the guard is still the
# visible first line of the emitted handler (see collision_filters.gd, which is where all three
# readers of that guard agree on it).
#
# TWO WORDINGS, ONE SIGNAL. Godot files `body_entered` under two node families that mean different
# things by it. A body BLOCKS what it hits, so its news is a collision; an Area only notices, so its
# news is an overlap. The rows therefore ship twice, filed under the class each wording belongs to,
# and a sheet is only ever offered the one its node can actually raise. The help strip in the dialog
# says the difference in one line, on the row where it matters.
#
# THE 2D/3D SPLIT IS DELIBERATE, for the same reason the named-layer rows split: the picker files by
# node class, so a CharacterBody3D sheet would never be offered a row filed under Area2D. The two
# sets differ in nothing but the class they are filed under, so they are written once and built
# twice rather than spelled out twice and left to drift.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeCollisionFilterACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CATEGORY: String = "Collisions"

## The one description the With field carries. The group is a Godot node group, which is the tag
## machinery every project already has, so the row asks for nothing a project has to invent.
const GROUP_NOTE: String = "Only react when the thing that arrived is in this group. Any node joins a group from the Node dock, and the emitted handler leaves immediately when it is not in it."

## The overlap question's own With field. Same idea, asked of everything inside the area right now
## rather than of one arrival.
const TOUCHING_NOTE: String = "The group to look for among the bodies inside this area right now."

## The payload description both arrival rows share.
const ARRIVING_NOTE: String = "The body that arrived, already known to be in the group. Filled in for you when the trigger fires - use it in the rows underneath."

## The payload description both departure rows share.
const LEAVING_NOTE: String = "The body that left, already known to be in the group. Filled in for you when the trigger fires - use it in the rows underneath."


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append_array(_body_triggers("", "RigidBody2D"))
	descriptors.append_array(_body_triggers("3D", "RigidBody3D"))
	descriptors.append_array(_area_triggers("", "Area2D"))
	descriptors.append_array(_area_triggers("3D", "Area3D"))
	descriptors.append(_is_touching("", "Area2D"))
	descriptors.append(_is_touching("3D", "Area3D"))
	return descriptors


## The blocking side's pair: something hit this body, and something stopped touching it. `suffix` is
## what keeps the two dimensions' ace_ids apart ("" for the 2D rows, "3D" for their twins) and
## `host_class` is the class the picker files them under.
static func _body_triggers(suffix: String, host_class: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.make_descriptor("Core", "OnCollisionWithGroup%s" % suffix,
		"On Collision With Group%s" % name_suffix, ACEDescriptor.ACEType.TRIGGER, "", "body_entered",
		[_group_param(GROUP_NOTE), _payload_param("body", ARRIVING_NOTE)],
		CATEGORY, "On collision with {group}", host_class)
		.described("Runs when something from one group hits this body. The group is the filter: the handler's first line leaves at once for anything else, and what did hit rides into the rows underneath. This body BLOCKS what it hits - it needs Contact Monitor switched on and its Max Contacts Reported above zero before Godot will report the hit at all.").featured())
	descriptors.append(F.make_descriptor("Core", "OnStoppedCollidingWithGroup%s" % suffix,
		"On Stopped Colliding With Group%s" % name_suffix, ACEDescriptor.ACEType.TRIGGER, "", "body_exited",
		[_group_param(GROUP_NOTE), _payload_param("body", LEAVING_NOTE)],
		CATEGORY, "On stopped colliding with {group}", host_class)
		.described("Runs when something from one group stops touching this body - the other half of the collision, for ending a push, a grind or a stand-on. Needs the same Contact Monitor setting the starting half does."))
	return descriptors


## The noticing side's pair, said as an overlap because an Area does not block anything.
static func _area_triggers(suffix: String, host_class: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.make_descriptor("Core", "OnOverlapWithGroup%s" % suffix,
		"On Overlap With Group%s" % name_suffix, ACEDescriptor.ACEType.TRIGGER, "", "body_entered",
		[_group_param(GROUP_NOTE), _payload_param("body", ARRIVING_NOTE)],
		CATEGORY, "On overlap with {group}", host_class)
		.described("Runs when something from one group moves into this area. An area DETECTS and does not block, so the thing keeps going - this is the trigger a checkpoint, a pickup zone or a damage field is written from. What arrived rides into the rows underneath.").featured())
	descriptors.append(F.make_descriptor("Core", "OnOverlapEndedWithGroup%s" % suffix,
		"On Overlap Ended With Group%s" % name_suffix, ACEDescriptor.ACEType.TRIGGER, "", "body_exited",
		[_group_param(GROUP_NOTE), _payload_param("body", LEAVING_NOTE)],
		CATEGORY, "On overlap ended with {group}", host_class)
		.described("Runs when something from one group leaves this area - the moment a player walks out of a safe zone, or the last enemy clears a trap."))
	return descriptors


## The question the pair above answers as news, asked at any moment instead: is anything from this
## group inside the area right now?
##
## Written as the one-line ask a reader would write, so a picked row and a hand-written line are the
## same line, and so the row is a plain condition that the sheet's own NOT reads through - "is not
## touching" needs no second ace_id, it is this one asked the other way.
static func _is_touching(suffix: String, host_class: String) -> ACEDescriptor:
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	return F.make_descriptor("Core", "IsTouchingGroup%s" % suffix,
		"Is Touching Group%s" % name_suffix, ACEDescriptor.ACEType.CONDITION,
		"get_overlapping_bodies().any(func(__body: Node) -> bool: return __body.is_in_group({group}))",
		"", [_group_param(TOUCHING_NOTE)], CATEGORY, "is touching {group}", host_class)\
		.described("True while at least one body from this group is inside this area. The standing question beside the two arrival triggers - ask it when what matters is the state now, not the moment it changed.").featured()


## The With field: a live picker over the project's own node groups, which is the same field the
## rest of the group vocabulary uses.
static func _group_param(note: String) -> ACEParam:
	return F.make_param("group", "String", "\"enemies\"", "With", note, "group_reference")


## One payload parameter - the thing the signal hands the handler. It has no label because there is
## nothing to fill in: it is filled in by the engine, and the row shows it as a chip.
static func _payload_param(param_id: String, note: String) -> ACEParam:
	return F.make_param(param_id, "Node", "", "", note)
