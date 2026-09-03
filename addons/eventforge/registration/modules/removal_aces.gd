# EventForge module - Destroy (taking a thing out of the world, without leaving a ghost behind)
#
# There is no despawning system here and there is not going to be one. Destroying a node in Godot is
# `queue_free()`, and every row in this module is that call said as a sentence, with the waiting each
# one does written out in plain lines beside it.
#
# WHY THREE VERBS AND NOT ONE. They differ in WHEN the call happens, and that is the whole of what a
# reader needs to know:
#
#     enemy.queue_free()                                                    # now (end of frame)
#     get_tree().create_timer(2.0).timeout.connect(enemy.queue_free)        # in two seconds
#     await enemy.create_tween().tween_property(...).finished               # after the fade
#     if is_instance_valid(enemy):
#         enemy.queue_free()
#
# "Now" is the one people misread, so the row says it: `queue_free()` marks the node and Godot
# deletes it at the END of the frame. Rows after it in the same event still run, and the node is
# still there while they do. That is not a quirk to hide - it is why a sheet can destroy a thing and
# then read its position on the next line without crashing.
#
# THE GHOST. Everything that WAITS - a timer, a tween, an await - hands the line a name that may
# outlive the thing it named. Godot's answer is `is_instance_valid`, and this module's answer is to
# WRITE it where it is needed and show it on the row rather than quietly wrapping lines behind the
# author's back (see removal_guard.gd for the one rule that decides, and for how the row displays
# the line the file holds). The fade row carries its own guard in its template, because an await is
# the one wait a row can be sure about: half a second of game time passed, and anything could have
# happened in it.
#
# WHAT IS NOT HERE. On Destroyed is the shipped On Exit Tree trigger and stays there - a node hearing
# about its own destruction is a lifecycle handler, not a destroy verb. Object Still Exists is the
# shipped condition and stays there too; the question below is its sentence beside it, for a sheet
# that reads in these words.
#
# ── AND BESIDE THE THREE, THE SAME THREE THAT DO NOT THROW THE THING AWAY ───────────────────────
#
# RETIRING is destroying's other answer. A game that pools its bullets does not want them freed - it
# wants them handed back to the pool that made them, to be given out again - and a game that does not
# pool anything wants exactly what Destroy already does. Which of the two a node is, is written ON
# the node: a pool stamps every copy it hands out, so the retire verbs ask the node rather than
# asking the sheet to remember. No pool, or no stamp, and the line frees, which is why Retire is a
# swap for Destroy and never the other way round.
#
# AND WHAT IT TAKES FOR THAT SWAP TO BE SAFE, because it is not free. A pool takes a node back by
# REPARENTING it, and Godot refuses a reparent while the physics server is flushing - which is the
# whole of the collision handler a bullet is retired in. So the runtime file BOOKS the handing back
# for the next idle moment, exactly as `queue_free()` books a deletion for the end of the frame:
# both halves of the verb leave the node in the world for the rest of the event, and neither can
# raise an error from inside a callback. A node that is retired twice goes back once.
#
# The three verbs are the three above, WORD for word, differing only in the call at the end - now,
# after a wait, after a fade - because the thing a reader needs to know is still WHEN it happens.
# Two of them are the same sentence in every dimension, because a node is a node and neither a timer
# nor a pool cares how many axes it has. The fade is the one that cannot be: fading a 2D thing walks
# `modulate:a` down to nothing and fading a 3D one walks `transparency` up to one, which is two
# lines and therefore two rows.
#
# AND THE FADE PUTS THE THING BACK BEFORE IT LETS GO OF IT. A destroyed node's transparency is
# nobody's business, but a POOLED one is handed out again exactly as it was parked - the pool wakes
# a node, it does not rebuild it - so a copy that went back invisible comes out invisible and every
# later spawn of it is a bug with no line to point at. The row therefore writes the restore itself,
# on the line above the retire and in the sheet where a reader can see it, which is this module's
# rule about waits applied to the one property the row moved.
#
# WHY THE POOL IS LOOKED UP AT RUN TIME. It is an autoload, so a template naming it would put an
# identifier into every generated script that only parses in a project which installed the pool
# pack. PooledNodes resolves it by path when the line runs, which is what lets one row work in both
# kinds of project - and it is plain GDScript, so the generated game carries it like any other
# runtime file and needs no plugin to run.
#
# ON RETIRED IS ONE SIGNAL AND NOT TWO. Both retirements pass through the same moment: a pool takes
# a node back by removing it from the tree, and a destroy takes it out of the tree as well, so
# `tree_exiting` is raised exactly once either way. Hanging the trigger off the pool's own despawn
# signal AS WELL would fire the body twice for one retirement, because the pool raises that signal
# after the node has already left - so the trigger is the one signal that is true in both cases.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeRemovalACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The one category these rows group under in the picker.
const CATEGORY: String = "Destroy"

## The property a fade walks, and the value it walks it to. A sub-property path rather than a whole
## Color, so a sprite that is already tinted fades from ITS colour instead of snapping to white on
## the first frame of the tween.
const FADE_PROPERTY: String = "modulate:a"

## The same property as a real write rather than as a tween's path, which is what the restore line
## needs: a tween takes `modulate:a` as text and an assignment takes `modulate.a` as code.
const FADE_RESTORE: String = "modulate.a"

## The same walk in three dimensions. A Node3D has no modulate; what it has is `transparency`, which
## runs the other way - 0 is solid and 1 is gone - so the twin walks UP to one where the 2D row walks
## down to nothing.
const FADE_PROPERTY_3D: String = "transparency"
const FADE_TARGET_3D: String = "1.0"

## The runtime file the retire verbs call, by the name emitted code says. Named here because three
## templates write it and one spelling is what keeps them one idea.
const RETIRE_CALL: String = "PooledNodes.retire"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Now ────────────────────────────────────────────────────────────────────────────
	# The plain call. The frozen Free Node row writes the same line and stays the reading of it;
	# this is the authoring sentence, and the row the guard rule below knows how to protect.
	descriptors.append(F.act("DestroyNow", "Destroy Now", "{object}.queue_free()", CATEGORY, "destroy [i]{object}[/i] now", "Destroys the object, taking it out of the game. Godot deletes it at the END of this frame, not on this line, so the rows after this one in the same event still run and the object is still there while they do. Use it for anything the game is finished with: a collected pickup, a defeated enemy, a spent effect.").param_built(_object_param()).featured())

	# ── In a while ─────────────────────────────────────────────────────────────────────
	# A one-shot SceneTree timer with the node's own queue_free hung off it. Godot drops a signal
	# connection when the object at the far end of it is freed, which is exactly why this spelling
	# needs no bookkeeping: something else destroying the thing first simply takes the connection with
	# it, and the timer fires into nothing.
	descriptors.append(F.act("DestroyAfterSeconds", "Destroy After Seconds", "get_tree().create_timer({seconds}).timeout.connect({object}.queue_free)", CATEGORY, "destroy [i]{object}[/i] after {seconds}s", "Destroys the object a number of seconds from now, and gets on with the event in the meantime. The wait is a scene-tree timer, so nothing about this line blocks. It is safe if something else destroys the object first: Godot drops the timer's connection along with the object, and the wait ends up firing at nothing at all.").param_built(_object_param()).param_built(_after_param()).featured())

	# ── Fade first ─────────────────────────────────────────────────────────────────────
	# Tween, await, destroy - and the guard in the template, because that await is a real gap. The
	# row's own sentence says the wait, and its own lines say the check; nothing about the deferral
	# is hidden behind the row.
	descriptors.append(F.act("FadeOutAndDestroy", "Fade Out Then Destroy", "await {object}.create_tween().tween_property({object}, \"%s\", 0.0, {seconds}).finished\n" % FADE_PROPERTY + "if is_instance_valid({object}):\n\t{object}.queue_free()", CATEGORY, "fade [i]{object}[/i] out over {seconds}s, then destroy it", "Fades the object's transparency to nothing over a number of seconds and then destroys it. The event WAITS here, so the rows after this one run once the fade has finished. Because that wait is a real gap in game time, the row asks whether the object is still there before destroying it, and the line that asks is written into the sheet rather than added quietly.").param_built(_object_param()).param_built(_over_param()))

	# ── The question ───────────────────────────────────────────────────────────────────
	# The sentence beside the frozen Object Still Exists. Same call, same answer; a sheet that reads
	# in these words gets a row that reads in them too.
	descriptors.append(F.cond("IsStillHere", "Is Still Here", "is_instance_valid({object})", CATEGORY, "[i]{object}[/i] is still here", "True while the object has not been destroyed. Ask it before touching anything a sheet held on to across frames: a node stored in a variable, or a copy a spawn row made in an earlier event. A node that wants to hear about its OWN destruction uses the On Exit Tree trigger instead, which fires as it leaves.").param_built(_object_param()))

	# ── The same three, without throwing the thing away ────────────────────────────────
	# One call each, and the call decides for itself: a node a pool stamped goes back to that pool,
	# and everything else is freed exactly as Destroy Now frees it.
	descriptors.append(F.act("Retire", "Retire", "%s({object})" % RETIRE_CALL, CATEGORY, "retire [i]{object}[/i] now", "Retires the object: hands it back to the pool that made it when it came from one, and destroys it when it did not. Which of the two happens is read off the object itself, so a sheet never has to remember where a copy came from - and a game with no pools in it behaves exactly as Destroy Now does. Like Destroy Now, the object is still there for the rest of this event: a destroy lands at the end of the frame and a handing back lands on the next idle moment, which is what makes this row safe inside a collision handler. Safe to run twice - something already on its way out, or already back in its pool, is left alone.").param_built(_retired_object_param()).featured())
	# The timer form. Same one-shot scene-tree timer the destroy twin uses, with the retiring call
	# bound to the object instead of the object's own queue_free hung off it - so it still books
	# nothing, blocks nothing and needs no bookkeeping.
	#
	# AND THE ONE THING THAT IS NOT TRUE OF THE DESTROY TWIN. Godot drops a connection when the
	# object at the far end of it is freed, which is what makes "destroy in two seconds" need no
	# bookkeeping. A POOLED object is never freed, so nothing is dropped: a copy that goes back to
	# its pool early and is handed out again inside the wait is retired by this timer in the middle of
	# its NEXT life. The row's own words say so, because no line here can know which life it is in.
	descriptors.append(F.act("RetireAfterSeconds", "Retire After Seconds", "get_tree().create_timer({seconds}).timeout.connect(%s.bind({object}))" % RETIRE_CALL, CATEGORY, "retire [i]{object}[/i] after {seconds}s", "Retires the object a number of seconds from now, and gets on with the event in the meantime. The wait is a scene-tree timer, so nothing about this line blocks. Whether the object goes back to a pool or is destroyed is decided when the wait ends, which is the moment that knows. One thing to watch on a POOLED object: it is never destroyed, so a copy that goes back to its pool before the wait ends and is spawned again inside it will be retired by this timer in the middle of that second life. Use Retire on its own where a copy can be retired early.").param_built(_retired_object_param()).param_built(_after_param()))
	# Fade, wait, put it back, retire - with the guard the wait needs written into the row, exactly as
	# the destroy twin writes it, and the restore beside it because a pooled object is handed out
	# again wearing whatever this row left on it. Hosted on CanvasItem: the restore is a real property
	# write rather than a tween's string path, so the row belongs where `modulate` does.
	descriptors.append(F.act("FadeOutAndRetire", "Fade Out Then Retire", "await {object}.create_tween().tween_property({object}, \"%s\", 0.0, {seconds}).finished\n" % FADE_PROPERTY + "if is_instance_valid({object}):\n\t{object}.%s = 1.0\n\t%s({object})" % [FADE_RESTORE, RETIRE_CALL], CATEGORY, "fade [i]{object}[/i] out over {seconds}s, then retire it", "Fades the object's transparency to nothing over a number of seconds and then retires it - back to its pool, or destroyed. The event WAITS here, so the rows after this one run once the fade has finished, and because that wait is a real gap the row asks whether the object is still there before touching it. The line above the retire puts the transparency back: a pool hands a copy out again exactly as it was parked, so a copy that went back invisible would come out invisible.", "CanvasItem").param_built(_retired_object_param()).param_built(_over_param()))
	# The 3D twin, which exists because the LINE is different: a Node3D has no modulate, and the
	# property that hides one runs from solid to gone rather than the other way about. Hosted on
	# GeometryInstance3D because that is the class `transparency` is declared on - a CharacterBody3D
	# has no such property, and a tween aimed at one on a body returns nothing and takes the event
	# with it. The thing that fades in three dimensions is the mesh, so the row is offered on the mesh.
	descriptors.append(F.act("FadeOutAndRetire3D", "Fade Out Then Retire (3D)", "await {object}.create_tween().tween_property({object}, \"%s\", %s, {seconds}).finished\n" % [FADE_PROPERTY_3D, FADE_TARGET_3D] + "if is_instance_valid({object}):\n\t{object}.%s = 0.0\n\t%s({object})" % [FADE_PROPERTY_3D, RETIRE_CALL], CATEGORY, "fade [i]{object}[/i] out over {seconds}s, then retire it (3D)", "The same fade and retire on a 3D object. A Node3D has no modulate to walk down, so this walks its transparency up instead - 0 is solid and 1 is gone. That property belongs to what is DRAWN rather than to what moves: point Object at the MeshInstance3D (or another GeometryInstance3D), not at the body it hangs under, or the fade has nothing to walk. The line above the retire puts the transparency back, because a pool hands a copy out again exactly as it was parked.", "GeometryInstance3D").param_built(_retired_object_param()).param_built(_over_param()))

	# ── Hearing about it ───────────────────────────────────────────────────────────────
	# One signal, because both retirements pass through it: a pool takes a node back by removing it
	# from the tree, and a destroy takes it out of the tree too.
	descriptors.append(F.trig("OnRetired", "On Retired", "tree_exiting", CATEGORY, "On retired", "Runs the moment this object is retired - handed back to its pool, or destroyed. Both go the same way out: a pool takes a node back by removing it from the tree, so this one signal is raised exactly once whichever of the two happened. The object is still valid here, which is what makes it the place to let go of what it was holding, drop it from a list, or tell somebody else it is gone.", "Node"))

	return descriptors


## The picker's own words for the section, so selecting the header says what the rows underneath are
## for rather than leaving the reader to infer it from four names.
static func section_descriptions() -> Dictionary:
	return {
		CATEGORY: "Taking a thing out of the world: right now, after a wait, or after a fade. Each row says when the call happens. The destroy verbs free the thing; the retire verbs beside them hand it back to the pool that made it when it came from one, and free it when it did not."
	}


## The thing being destroyed, or asked about. An expression on purpose: a sheet says the name a spawn
## row minted (`new_enemy`), a variable it stored a node in, or a node path. The default is `self`,
## which is the commonest answer of all - a pickup destroying itself on contact.
static func _object_param() -> ACEParam:
	return F.make_param("object", "String", "self", "Object",
		"The object to destroy, as an expression - the name a spawn row gave a copy, a variable holding a node, or a node path. Leave it as self for this node.",
		"expression")


## The thing being retired. The same field as the one above, with the one sentence that differs said
## where a reader meets it: retiring reads the object to decide what happens to it.
static func _retired_object_param() -> ACEParam:
	return F.make_param("object", "String", "self", "Object",
		"The object to retire, as an expression - the name a spawn row gave a copy, a variable holding a node, or a node path. Leave it as self for this node. A copy an object pool handed out goes back to that pool; anything else is destroyed.",
		"expression")


## How long the timer waits.
static func _after_param() -> ACEParam:
	return F.make_param("seconds", "String", "2.0", "After",
		"How many seconds to wait before destroying the object. The event carries on immediately; only the destroying waits.",
		"expression")


## How long the fade takes.
static func _over_param() -> ACEParam:
	return F.make_param("seconds", "String", "0.5", "Over",
		"How many seconds the fade takes. The event waits for it, so the rows after this one run when the fade is done.",
		"expression")
