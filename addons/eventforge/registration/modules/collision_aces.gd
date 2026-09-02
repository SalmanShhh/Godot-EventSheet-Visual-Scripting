# EventForge module - Collision vocabulary (the "Helper ACEs for collisions").
#
# The collision queries you'd otherwise drop to a raw block for: CharacterBody slide/wall/
# floor results (valid AFTER Move And Slide), Area overlap tests + lists, collision layer/
# mask bits, and enabling/disabling a CollisionShape. Lane-1 wraps of native nodes - every
# template is one direct GDScript line (parity covenant), and each is node-type-scoped so
# the picker files it under its node's section (CharacterBody2D, Area2D, ...).
#
# THREE FILES, ONE SHELF. The edge sentences and the filtered ones were modules of their own, split
# by ASPECT rather than by subject: all three file every row under the one "Collisions" category, a
# reader looking for "on landed" or "on overlap with group" looks here, and the three sat adjacent
# in the sorted module walk, so joining them moves no row and no registry position. Each half keeps
# its own header below, whole, because what it says about the rows is still true of them.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeCollisionACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── CharacterBody2D: slide results (valid after Move And Slide) ──
	# The display words are the sheet's own platform words, which is also what an opened script
	# reads them as - one wording for the row whether it was picked here or typed in a .gd file.
	descriptors.append(F.cond("IsOnWall", "Is By Wall", "{host.}is_on_wall()", "Collisions", "Is by wall", "True when this 2D character is pressing against a wall.", "CharacterBody2D"))
	descriptors.append(F.cond("IsOnCeiling", "Is Touching Ceiling", "{host.}is_on_ceiling()", "Collisions", "Is touching ceiling", "True when this 2D character is touching a ceiling above.", "CharacterBody2D"))
	# The three questions every platformer asks about its own speed. Written as the comparisons they
	# are, so the row and a hand-written line are the same line - and read back as these same words.
	descriptors.append(F.cond("IsJumping", "Is Jumping", "{host.}velocity.y < 0", "Collisions", "Is jumping", "True while this 2D character is moving upward - the rising half of a jump. In 2D, Y grows downward, so going up is a NEGATIVE vertical speed.", "CharacterBody2D"))
	descriptors.append(F.cond("IsFalling", "Is Falling", "{host.}velocity.y > 0", "Collisions", "Is falling", "True while this 2D character is moving downward - the falling half of a jump, or walking off a ledge.", "CharacterBody2D"))
	descriptors.append(F.cond("IsMoving", "Is Moving", "{host.}velocity.x != 0", "Collisions", "Is moving", "True while this 2D character has any sideways speed - the walk-or-idle question an animation state usually asks.", "CharacterBody2D"))
	descriptors.append(F.expr("GetWallNormal", "Wall Normal", "{host.}get_wall_normal()", "Collisions", "wall normal", "Returns the direction the touched wall is facing, for wall-jumps or sliding.", "CharacterBody2D"))
	descriptors.append(F.expr("GetFloorNormal", "Floor Normal", "{host.}get_floor_normal()", "Collisions", "floor normal", "Returns the direction the floor is facing, useful on slopes.", "CharacterBody2D"))
	descriptors.append(F.expr("GetSlideCount", "Slide Collision Count", "get_slide_collision_count()", "Collisions", "slide collision count", "Returns how many things the character hit during its last move.", "CharacterBody2D"))
	descriptors.append(F.expr("GetLastSlideCollider", "Last Slide Collider", "(get_last_slide_collision().get_collider() if get_slide_collision_count() > 0 else null)", "Collisions", "last slide collider", "Returns the node the character bumped into last, or nothing if none.", "CharacterBody2D"))
	descriptors.append(F.expr("GetLastSlideNormal", "Last Slide Normal", "(get_last_slide_collision().get_normal() if get_slide_collision_count() > 0 else Vector2.ZERO)", "Collisions", "last slide normal", "Returns the surface direction from the character's last collision.", "CharacterBody2D"))

	# ── Area2D: overlap tests + lists (the common "am I touching X" queries) ──
	# The overlap questions say what the sheet's own rows say, so a picked row and the hand-written
	# `overlaps_body(x)` beside it read one sentence. The ids and the templates are frozen; only the
	# words a reader sees changed.
	descriptors.append(F.cond("OverlapsBody", "Is Overlapping Body", "overlaps_body({body})", "Collisions", "is overlapping {body}", "True when this Area2D is overlapping the given physics body.", "Area2D").param("body", "get_tree().get_first_node_in_group(\"player\")", "Body", "The body to test against - a group member here (no tree path), or pick a node. `self` never overlaps itself.", "expression"))
	descriptors.append(F.cond("OverlapsArea", "Is Overlapping Area", "overlaps_area({area})", "Collisions", "is overlapping {area}", "True when this Area2D is overlapping the given other area.", "Area2D").param("area", "get_tree().get_first_node_in_group(\"triggers\")", "Area", "The area to test against - a group member here (no tree path), or pick a node. `self` never overlaps itself.", "expression"))
	# The platformer's own question: "is there ground just below me?" is a MOVE that is never
	# made - the body is asked where it would end up one pixel down, and nothing moves either way.
	descriptors.append(F.cond("IsOverlappingAtOffset", "Is Overlapping At Offset", "test_move(transform, {offset})", "Collisions", "is overlapping at offset {offset} (a solid)", "True when this body WOULD hit something solid if it moved by the offset - the ground check every platformer needs, and nothing actually moves.", "PhysicsBody2D").param("offset", "Vector2(0, 1)", "Offset", "How far to look, from where the object is now - (0, 1) is one pixel down, which is the ground check.", "expression").featured())
	descriptors.append(F.cond("HasOverlappingBodies", "Has Overlapping Bodies", "has_overlapping_bodies()", "Collisions", "has overlapping bodies", "True when this Area2D currently overlaps any physics body.", "Area2D"))
	descriptors.append(F.cond("HasOverlappingAreas", "Has Overlapping Areas", "has_overlapping_areas()", "Collisions", "has overlapping areas", "True when this Area2D currently overlaps any other area.", "Area2D"))
	descriptors.append(F.expr("GetOverlappingBodies", "Overlapping Bodies", "get_overlapping_bodies()", "Collisions", "overlapping bodies", "Returns the list of physics bodies currently inside this Area2D.", "Area2D"))
	descriptors.append(F.expr("GetOverlappingAreas", "Overlapping Areas", "get_overlapping_areas()", "Collisions", "overlapping areas", "Returns the list of areas currently overlapping this Area2D.", "Area2D"))

	# ── CollisionObject2D: layers & masks (CharacterBody / Area / Rigid / Static all inherit) ──
	descriptors.append(F.act("SetCollisionLayerBit", "Set Collision Layer Bit", "set_collision_layer_value({layer}, {enabled})", "Collisions", "Set layer {layer} = {enabled}", "Turns a collision layer on or off, controlling what this object sits on.", "CollisionObject2D").param("layer", "1", "Layer", "Layer number (1-32).", "expression").param_choice("enabled", "true", "Enabled", "Sit on this layer?", ["true", "false"]))
	descriptors.append(F.act("SetCollisionMaskBit", "Set Collision Mask Bit", "set_collision_mask_value({mask}, {enabled})", "Collisions", "Set mask {mask} = {enabled}", "Turns a collision mask bit on or off, controlling what this object detects.", "CollisionObject2D").param("mask", "1", "Mask", "Mask number (1-32).", "expression").param_choice("enabled", "true", "Enabled", "Scan this layer?", ["true", "false"]))
	descriptors.append(F.cond("IsOnCollisionLayer", "Is On Collision Layer", "get_collision_layer_value({layer})", "Collisions", "is on layer {layer}", "True when this object occupies the given collision layer.", "CollisionObject2D").param("layer", "1", "Layer", "Layer number (1-32).", "expression"))

	# ── The same three knobs said in the project's own words ──
	#
	# The bit verbs above are the numbers as the engine has them: a layer, a switch, and the reader
	# left to remember which of `1` and `3` is the wall. A project that named its layers already
	# said which - so these five rows take the NAME, and are the ones the picker leads with.
	#
	# WHAT IS EMITTED IS STILL THE NUMBER. `set_collision_mask_value(2, true)` is the engine's own
	# call and it is what the file gets; the name lives in project.godot, where Godot keeps it, and
	# the sentence resolves the number back to it when the row is drawn. So the emitted line carries
	# no comment residue, no name, and nothing that would go stale when the layer is renamed.
	#
	# THE PAIR SHIPS FOR BOTH DIMENSIONS rather than being derived from the host class, because the
	# picker files rows by node class - a CharacterBody3D sheet would never be offered a row filed
	# under CollisionObject2D - and because the two lists of names are genuinely different lists.
	# The parameter's own hint is what says which of them a row reads: a 2D row can only mean a 2D
	# layer, so the hint that opens the picker is the hint the sentence reads back through.
	descriptors.append_array(_named_layer_descriptors("CollisionObject2D", "", "physics_layer_name_2d", "2D"))
	descriptors.append_array(_named_layer_descriptors("CollisionObject3D", "3D", "physics_layer_name_3d", "3D"))

	# ── CollisionShape2D: toggle (deferred so it is safe to call mid-physics) ──
	descriptors.append(F.act("EnableCollisionShape", "Enable Collision Shape", "set_deferred(&\"disabled\", false)", "Collisions", "Enable collision shape", "Switches this collision shape back on so it can collide again.", "CollisionShape2D"))
	descriptors.append(F.act("DisableCollisionShape", "Disable Collision Shape", "set_deferred(&\"disabled\", true)", "Collisions", "Disable collision shape", "Switches this collision shape off, safely, so it stops colliding.", "CollisionShape2D"))

	# ── 3D parity (CharacterBody3D slide + Area3D overlap) ──
	descriptors.append(F.cond("IsOnWall3D", "Is By Wall (3D)", "{host.}is_on_wall()", "Collisions", "Is by wall", "True when this 3D character is pressing against a wall.", "CharacterBody3D"))
	descriptors.append(F.cond("IsOnCeiling3D", "Is Touching Ceiling (3D)", "{host.}is_on_ceiling()", "Collisions", "Is touching ceiling", "True when this 3D character is touching a ceiling above.", "CharacterBody3D"))
	# In 3D, where Y grows UPWARD: the same two questions ask the opposite sign, and the words
	# follow the axis rather than the sign, exactly as the reading of an opened 3D script does.
	descriptors.append(F.cond("IsJumping3D", "Is Jumping (3D)", "{host.}velocity.y > 0", "Collisions", "Is jumping", "True while this 3D character is moving upward. In 3D, Y grows upward, so going up is a POSITIVE vertical speed - the opposite sign from the 2D question.", "CharacterBody3D"))
	descriptors.append(F.cond("IsFalling3D", "Is Falling (3D)", "{host.}velocity.y < 0", "Collisions", "Is falling", "True while this 3D character is moving downward.", "CharacterBody3D"))
	descriptors.append(F.cond("IsMoving3D", "Is Moving (3D)", "{host.}velocity.x != 0", "Collisions", "Is moving", "True while this 3D character has any speed along X - the walk-or-idle question for a side-on 3D mover.", "CharacterBody3D"))
	descriptors.append(F.expr("GetWallNormal3D", "Wall Normal (3D)", "{host.}get_wall_normal()", "Collisions", "wall normal", "Fires with the direction a 3D body just bumped into a wall, useful for wall-jumps or ricochets.", "CharacterBody3D"))
	descriptors.append(F.expr("GetFloorNormal3D", "Floor Normal (3D)", "{host.}get_floor_normal()", "Collisions", "floor normal", "Fires with the slope direction of the floor a 3D body is standing on, handy for slope-aware movement.", "CharacterBody3D"))
	descriptors.append(F.cond("HasOverlappingBodies3D", "Has Overlapping Bodies (3D)", "has_overlapping_bodies()", "Collisions", "has overlapping bodies", "True when this 3D Area is currently overlapping at least one physics body.", "Area3D"))
	descriptors.append(F.expr("GetOverlappingBodies3D", "Overlapping Bodies (3D)", "get_overlapping_bodies()", "Collisions", "overlapping bodies", "Fires with the list of physics bodies currently inside this 3D Area.", "Area3D"))

	# The two halves that used to be modules of their own, appended in the order the sorted module
	# walk used to reach them - collision_edge_aces.gd before collision_filter_aces.gd - because
	# registry order is what breaks a tie in the reverse-lifter.
	descriptors.append_array(_floor_rows("", "CharacterBody2D"))
	descriptors.append_array(_floor_rows("3D", "CharacterBody3D"))
	descriptors.append_array(_area_rows("", "Area2D"))
	descriptors.append_array(_area_rows("3D", "Area3D"))
	descriptors.append_array(_body_triggers("", "RigidBody2D"))
	descriptors.append_array(_body_triggers("3D", "RigidBody3D"))
	descriptors.append_array(_area_triggers("", "Area2D"))
	descriptors.append_array(_area_triggers("3D", "Area3D"))
	descriptors.append(_is_touching("", "Area2D"))
	descriptors.append(_is_touching("3D", "Area3D"))

	return descriptors


## The five named-layer rows for one dimension. Written once and built twice because the sentences
## are the same sentences - only the class they are filed under and the list of names they read
## change, and spelling them out twice would be two places for one wording to drift.
##
## `suffix` is what keeps the two sets of ace_ids apart ("" for the 2D rows, which came first in the
## module's own convention, "3D" for their twins), `hint` is the picker and the reading lens, and
## `dimension_word` is what the descriptions say so a reader in the picker knows which list of
## layer names the row is about before they open it.
static func _named_layer_descriptors(host_class: String, suffix: String, hint: String,
		dimension_word: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var mask_note: String = "The layer to watch for, by the name this project gave it in Project Settings ▸ Layer Names ▸ %s Physics. A layer the project never named shows as its number, and can be named from here." % dimension_word
	var layer_note: String = "The layer to sit on, by the name this project gave it in Project Settings ▸ Layer Names ▸ %s Physics. A layer the project never named shows as its number, and can be named from here." % dimension_word
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.act("CollideWithLayer%s" % suffix, "Collide With Layer%s" % name_suffix, "set_collision_mask_value({layer}, true)", "Collisions", "Collide with {layer}", "Starts noticing one named collision layer, so this object bumps into (and detects) whatever sits on it. The layers this object is ON are a separate question - use Be On Layer for that.", host_class).param_built(F.make_param("layer", "String", "1", "Layer", mask_note, hint).with_lens(hint)).featured())
	descriptors.append(F.act("StopCollidingWithLayer%s" % suffix, "Stop Colliding With Layer%s" % name_suffix, "set_collision_mask_value({layer}, false)", "Collisions", "Stop colliding with {layer}", "Stops noticing one named collision layer, so this object passes straight through whatever sits on it - the drop-through-a-platform move, and the moment a dash turns intangible.", host_class).param_built(F.make_param("layer", "String", "1", "Layer", mask_note, hint).with_lens(hint)))
	descriptors.append(F.act("BeOnLayer%s" % suffix, "Be On Layer%s" % name_suffix, "set_collision_layer_value({layer}, true)", "Collisions", "Be on layer {layer}", "Puts this object on one named collision layer, so everything watching that layer starts noticing it.", host_class).param_built(F.make_param("layer", "String", "1", "Layer", layer_note, hint).with_lens(hint)))
	descriptors.append(F.act("LeaveLayer%s" % suffix, "Leave Layer%s" % name_suffix, "set_collision_layer_value({layer}, false)", "Collisions", "Leave layer {layer}", "Takes this object off one named collision layer, so everything watching that layer stops noticing it - the invulnerable frames after a hit, said as the layer it leaves.", host_class).param_built(F.make_param("layer", "String", "1", "Layer", layer_note, hint).with_lens(hint)))
	descriptors.append(F.cond("IsSetToCollideWithLayer%s" % suffix, "Is Set To Collide With Layer%s" % name_suffix, "get_collision_mask_value({layer})", "Collisions", "is set to collide with {layer}", "True when this object is currently watching one named collision layer. It asks about the SETTING, not about a touch happening now.", host_class).param_built(F.make_param("layer", "String", "1", "Layer", mask_note, hint).with_lens(hint)))
	return descriptors


# ── THE EDGE SENTENCES: the step a standing state changed ──
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

const CATEGORY: String = "Collisions"

## The payload description both area edge triggers share. Same words the filtered touch triggers use
## for the same chip, because it is the same thing the engine hands the handler.
const ARRIVING_NOTE: String = "The body that arrived. Filled in for you when the trigger fires - use it in the rows underneath."

## The departure's twin.
const LEAVING_NOTE: String = "The body that left. Filled in for you when the trigger fires - use it in the rows underneath."


## The landing pair for one dimension: the two triggers and the two gates that say which step of the
## physics tick each answers. `suffix` keeps the two dimensions' ace_ids apart ("" for the 2D rows,
## which came first in this family's convention, "3D" for their twins).
static func _floor_rows(suffix: String, host_class: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.trig("OnLanded%s" % suffix, "On Landed%s" % name_suffix, "", CATEGORY, "On landed", "Runs on the step this character's feet arrive on the floor - the landing itself, not the standing that follows it. Landing is where the dust, the thud and the squash go. It is a moment of the physics step rather than a signal, so the question underneath says which step.", host_class).featured())
	descriptors.append(F.trig("OnLeftTheGround%s" % suffix, "On Left The Ground%s" % name_suffix, "", CATEGORY, "On left the ground", "Runs on the step this character's feet leave the floor, whichever way they left it: a jump and a walked-off ledge are the same moment to this row. The half that starts coyote time, and the half a fall animation begins on.", host_class))
	descriptors.append(F.cond("JustLanded%s" % suffix, "Just Landed%s" % name_suffix, "self.__just_landed_{uid}()", CATEGORY, "just landed", "True on the one step the feet arrive on the floor: on the floor now, and not on it last step. It keeps last step's footing in a variable of its own and updates it AFTER asking - a memory updated before the question is asked would always agree with the present, and the row could never be true.", host_class).stateful("var __was_on_floor_{uid}: bool = false\n\nfunc __just_landed_{uid}() -> bool:\n\tvar on_floor: bool = is_on_floor()\n\tvar landed: bool = on_floor and not __was_on_floor_{uid}\n\t__was_on_floor_{uid} = on_floor\n\treturn landed"))
	descriptors.append(F.cond("JustLeftTheGround%s" % suffix, "Just Left The Ground%s" % name_suffix, "self.__just_left_the_ground_{uid}()", CATEGORY, "just left the ground", "True on the one step the feet leave the floor: not on it now, and on it last step. The same memory the landing question keeps, read the other way round.", host_class).stateful("var __was_on_floor_{uid}: bool = false\n\nfunc __just_left_the_ground_{uid}() -> bool:\n\tvar on_floor: bool = is_on_floor()\n\tvar left: bool = __was_on_floor_{uid} and not on_floor\n\t__was_on_floor_{uid} = on_floor\n\treturn left"))
	return descriptors


## The overlap pair for one dimension. No memory: Godot has already updated the overlap list by the
## time it raises the arrival, so the first-in and last-out questions are asked of the list itself.
static func _area_rows(suffix: String, host_class: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.trig("OnFirstOverlap%s" % suffix, "On First Overlap%s" % name_suffix, "body_entered", CATEGORY, "On first overlap", "Runs when something moves into this area and the area was empty until then - the pressure plate going down, the room waking up. Later arrivals do not run it again; the question underneath is what says so, and it is an ordinary condition you can read and edit.", host_class).param_built(_payload_param("body", ARRIVING_NOTE)).featured())
	descriptors.append(F.trig("OnLastOverlapEnded%s" % suffix, "On Last Overlap Ended%s" % name_suffix, "body_exited", CATEGORY, "On last overlap ended", "Runs when something leaves this area and nothing is left inside - the plate coming back up, the room going quiet. The other half of the first arrival, and the pair a door or a lift is written from.", host_class).param_built(_payload_param("body", LEAVING_NOTE)))
	descriptors.append(F.cond("IsTheFirstOneIn%s" % suffix, "Is The First One In%s" % name_suffix, "get_overlapping_bodies().size() == 1", CATEGORY, "is the first one in", "True when exactly one body is inside this area. Asked in an arrival, that is the arrival which filled an empty area: what just came in is already listed by then, so a list of one held nothing a moment ago.", host_class))
	descriptors.append(F.cond("WasTheLastOneOut%s" % suffix, "Was The Last One Out%s" % name_suffix, "get_overlapping_bodies().is_empty()", CATEGORY, "was the last one out", "True when nothing is inside this area. Asked in a departure, that is the departure which emptied it: what just left is already off the list by then, so an empty list means it was the last one.", host_class))
	return descriptors


## One payload parameter - the thing the signal hands the handler. It has no label because there is
## nothing to fill in: it is filled in by the engine, and the row shows it as a chip.
static func _payload_param(param_id: String, note: String) -> ACEParam:
	return F.make_param(param_id, "Node", "", "", note)


# ── THE FILTERED SENTENCES: the touch said with a group on it ──
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

## The one description the With field carries. The group is a Godot node group, which is the tag
## machinery every project already has, so the row asks for nothing a project has to invent.
const GROUP_NOTE: String = "Only react when the thing that arrived is in this group. Any node joins a group from the Node dock, and the emitted handler leaves immediately when it is not in it."

## The overlap question's own With field. Same idea, asked of everything inside the area right now
## rather than of one arrival.
const TOUCHING_NOTE: String = "The group to look for among the bodies inside this area right now."

## The payload description both arrival rows share.
const FILTERED_ARRIVING_NOTE: String = "The body that arrived, already known to be in the group. Filled in for you when the trigger fires - use it in the rows underneath."

## The payload description both departure rows share.
const FILTERED_LEAVING_NOTE: String = "The body that left, already known to be in the group. Filled in for you when the trigger fires - use it in the rows underneath."


## The blocking side's pair: something hit this body, and something stopped touching it. `suffix` is
## what keeps the two dimensions' ace_ids apart ("" for the 2D rows, "3D" for their twins) and
## `host_class` is the class the picker files them under.
static func _body_triggers(suffix: String, host_class: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.trig("OnCollisionWithGroup%s" % suffix, "On Collision With Group%s" % name_suffix, "body_entered", CATEGORY, "On collision with {group}", "Runs when something from one group hits this body. The group is the filter: the handler's first line leaves at once for anything else, and what did hit rides into the rows underneath. This body BLOCKS what it hits - it needs Contact Monitor switched on and its Max Contacts Reported above zero before Godot will report the hit at all.", host_class).param_built(_group_param(GROUP_NOTE)).param_built(_payload_param("body", FILTERED_ARRIVING_NOTE)).featured())
	descriptors.append(F.trig("OnStoppedCollidingWithGroup%s" % suffix, "On Stopped Colliding With Group%s" % name_suffix, "body_exited", CATEGORY, "On stopped colliding with {group}", "Runs when something from one group stops touching this body - the other half of the collision, for ending a push, a grind or a stand-on. Needs the same Contact Monitor setting the starting half does.", host_class).param_built(_group_param(GROUP_NOTE)).param_built(_payload_param("body", FILTERED_LEAVING_NOTE)))
	return descriptors


## The noticing side's pair, said as an overlap because an Area does not block anything.
static func _area_triggers(suffix: String, host_class: String) -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	descriptors.append(F.trig("OnOverlapWithGroup%s" % suffix, "On Overlap With Group%s" % name_suffix, "body_entered", CATEGORY, "On overlap with {group}", "Runs when something from one group moves into this area. An area DETECTS and does not block, so the thing keeps going - this is the trigger a checkpoint, a pickup zone or a damage field is written from. What arrived rides into the rows underneath.", host_class).param_built(_group_param(GROUP_NOTE)).param_built(_payload_param("body", FILTERED_ARRIVING_NOTE)).featured())
	descriptors.append(F.trig("OnOverlapEndedWithGroup%s" % suffix, "On Overlap Ended With Group%s" % name_suffix, "body_exited", CATEGORY, "On overlap ended with {group}", "Runs when something from one group leaves this area - the moment a player walks out of a safe zone, or the last enemy clears a trap.", host_class).param_built(_group_param(GROUP_NOTE)).param_built(_payload_param("body", FILTERED_LEAVING_NOTE)))
	return descriptors


## The question the pair above answers as news, asked at any moment instead: is anything from this
## group inside the area right now?
##
## Written as the one-line ask a reader would write, so a picked row and a hand-written line are the
## same line, and so the row is a plain condition that the sheet's own NOT reads through - "is not
## touching" needs no second ace_id, it is this one asked the other way.
static func _is_touching(suffix: String, host_class: String) -> ACEDescriptor:
	var name_suffix: String = "" if suffix.is_empty() else " (%s)" % suffix
	return F.cond("IsTouchingGroup%s" % suffix, "Is Touching Group%s" % name_suffix, "get_overlapping_bodies().any(func(__body: Node) -> bool: return __body.is_in_group({group}))", CATEGORY, "is touching {group}", "True while at least one body from this group is inside this area. The standing question beside the two arrival triggers - ask it when what matters is the state now, not the moment it changed.", host_class).param_built(_group_param(TOUCHING_NOTE)).featured()


## The With field: a live picker over the project's own node groups, which is the same field the
## rest of the group vocabulary uses.
static func _group_param(note: String) -> ACEParam:
	return F.make_param("group", "String", "\"enemies\"", "With", note, "group_reference")
