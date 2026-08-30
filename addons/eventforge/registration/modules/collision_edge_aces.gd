# EventForge module - the EDGE sentences: the step a standing state changed.
#
# Four triggers and the four gates that go under them. What an edge is, why the floor pair carries a
# memory and the area pair does not, and why the comparison must come before the update, is all said
# once in collision_edges.gd, which every reader of these rows shares.
#
# WHAT THE FLOOR PAIR EMITS, in full, for a row applied with uid 1:
#
#     var __was_on_floor_1: bool = false
#
#     func __just_landed_1() -> bool:
#         var on_floor: bool = is_on_floor()
#         var landed: bool = on_floor and not __was_on_floor_1
#         __was_on_floor_1 = on_floor
#         return landed
#
#     func _physics_process(delta: float) -> void:
#         if self.__just_landed_1():
#             <the event's own rows>
#
# The memory, the comparison and the update are the three parts of the hand-written pattern, in the
# hand-written order, and the row's echo shows all three. They sit in a function rather than inline
# because the update has to happen on EVERY step, including the ones the event does not run on - a
# line after the `if` would be the only spelling of that inline, and a sheet's conditions are terms
# of the `if`, not statements around it. Reading and updating the memory in one call is how every
# other edge question in this vocabulary is already written.
#
# THE TEMPLATE LEADS WITH `self.` ON PURPOSE. A node-scoped condition normally grows an optional
# "On node" field, so the same question can be asked of another node - but the memory this one reads
# belongs to the script that declared it, and pointing the call at a neighbour would ask that
# neighbour for a function it does not have. Leading with `self.` says whose memory it is, and is
# also what keeps the cross-node field off a row that has no honest answer for it.
#
# THE 2D/3D SPLIT IS DELIBERATE, for the reason every other split in this family is: the picker files
# rows by node class, so a CharacterBody3D sheet would never be offered a row filed under
# CharacterBody2D. The two sets differ in nothing but the class they are filed under - `is_on_floor`
# and `get_overlapping_bodies` are spelled the same in both dimensions - so they are written once and
# built twice rather than spelled out twice and left to drift.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeCollisionEdgeACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CATEGORY: String = "Collisions"

## The payload description both area edge triggers share. Same words the filtered touch triggers use
## for the same chip, because it is the same thing the engine hands the handler.
const ARRIVING_NOTE: String = "The body that arrived. Filled in for you when the trigger fires - use it in the rows underneath."

## The departure's twin.
const LEAVING_NOTE: String = "The body that left. Filled in for you when the trigger fires - use it in the rows underneath."


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append_array(_floor_rows("", "CharacterBody2D"))
	descriptors.append_array(_floor_rows("3D", "CharacterBody3D"))
	descriptors.append_array(_area_rows("", "Area2D"))
	descriptors.append_array(_area_rows("3D", "Area3D"))
	return descriptors


## The landing pair for one dimension: the two triggers and the two gates that say which step of the
## physics tick each answers. `suffix` keeps the two dimensions' ace_ids apart ("" for the 2D rows,
## which came first in this family's convention, "3D" for their twins).
static func _floor_rows(suffix: String, host_class: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.make_descriptor("Core", "OnLanded%s" % suffix,
		"On Landed%s" % name_suffix, ACEDescriptor.ACEType.TRIGGER, "", "", [],
		CATEGORY, "On landed", host_class)
		.described("Runs on the step this character's feet arrive on the floor - the landing itself, not the standing that follows it. Landing is where the dust, the thud and the squash go. It is a moment of the physics step rather than a signal, so the question underneath says which step.").featured())
	descriptors.append(F.make_descriptor("Core", "OnLeftTheGround%s" % suffix,
		"On Left The Ground%s" % name_suffix, ACEDescriptor.ACEType.TRIGGER, "", "", [],
		CATEGORY, "On left the ground", host_class)
		.described("Runs on the step this character's feet leave the floor, whichever way they left it: a jump and a walked-off ledge are the same moment to this row. The half that starts coyote time, and the half a fall animation begins on."))
	descriptors.append(F.make_descriptor("Core", "JustLanded%s" % suffix,
		"Just Landed%s" % name_suffix, ACEDescriptor.ACEType.CONDITION,
		"self.__just_landed_{uid}()", "", [], CATEGORY, "just landed", host_class)
		.described("True on the one step the feet arrive on the floor: on the floor now, and not on it last step. It keeps last step's footing in a variable of its own and updates it AFTER asking - a memory updated before the question is asked would always agree with the present, and the row could never be true.")
		.stateful("var __was_on_floor_{uid}: bool = false\n\nfunc __just_landed_{uid}() -> bool:\n\tvar on_floor: bool = is_on_floor()\n\tvar landed: bool = on_floor and not __was_on_floor_{uid}\n\t__was_on_floor_{uid} = on_floor\n\treturn landed"))
	descriptors.append(F.make_descriptor("Core", "JustLeftTheGround%s" % suffix,
		"Just Left The Ground%s" % name_suffix, ACEDescriptor.ACEType.CONDITION,
		"self.__just_left_the_ground_{uid}()", "", [], CATEGORY, "just left the ground", host_class)
		.described("True on the one step the feet leave the floor: not on it now, and on it last step. The same memory the landing question keeps, read the other way round.")
		.stateful("var __was_on_floor_{uid}: bool = false\n\nfunc __just_left_the_ground_{uid}() -> bool:\n\tvar on_floor: bool = is_on_floor()\n\tvar left: bool = __was_on_floor_{uid} and not on_floor\n\t__was_on_floor_{uid} = on_floor\n\treturn left"))
	return descriptors


## The overlap pair for one dimension. No memory: Godot has already updated the overlap list by the
## time it raises the arrival, so the first-in and last-out questions are asked of the list itself.
static func _area_rows(suffix: String, host_class: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.make_descriptor("Core", "OnFirstOverlap%s" % suffix,
		"On First Overlap%s" % name_suffix, ACEDescriptor.ACEType.TRIGGER, "", "body_entered",
		[_payload_param("body", ARRIVING_NOTE)],
		CATEGORY, "On first overlap", host_class)
		.described("Runs when something moves into this area and the area was empty until then - the pressure plate going down, the room waking up. Later arrivals do not run it again; the question underneath is what says so, and it is an ordinary condition you can read and edit.").featured())
	descriptors.append(F.make_descriptor("Core", "OnLastOverlapEnded%s" % suffix,
		"On Last Overlap Ended%s" % name_suffix, ACEDescriptor.ACEType.TRIGGER, "", "body_exited",
		[_payload_param("body", LEAVING_NOTE)],
		CATEGORY, "On last overlap ended", host_class)
		.described("Runs when something leaves this area and nothing is left inside - the plate coming back up, the room going quiet. The other half of the first arrival, and the pair a door or a lift is written from."))
	descriptors.append(F.make_descriptor("Core", "IsTheFirstOneIn%s" % suffix,
		"Is The First One In%s" % name_suffix, ACEDescriptor.ACEType.CONDITION,
		"get_overlapping_bodies().size() == 1", "", [], CATEGORY, "is the first one in", host_class)
		.described("True when exactly one body is inside this area. Asked in an arrival, that is the arrival which filled an empty area: what just came in is already listed by then, so a list of one held nothing a moment ago."))
	descriptors.append(F.make_descriptor("Core", "WasTheLastOneOut%s" % suffix,
		"Was The Last One Out%s" % name_suffix, ACEDescriptor.ACEType.CONDITION,
		"get_overlapping_bodies().is_empty()", "", [], CATEGORY, "was the last one out", host_class)
		.described("True when nothing is inside this area. Asked in a departure, that is the departure which emptied it: what just left is already off the list by then, so an empty list means it was the last one."))
	return descriptors


## One payload parameter - the thing the signal hands the handler. It has no label because there is
## nothing to fill in: it is filled in by the engine, and the row shows it as a chip.
static func _payload_param(param_id: String, note: String) -> ACEParam:
	return F.make_param(param_id, "Node", "", "", note)
