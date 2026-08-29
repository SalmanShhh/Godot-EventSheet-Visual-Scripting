# EventForge module - Remove (taking a thing out of the world, without leaving a ghost behind)
#
# There is no despawning system here and there is not going to be one. Removing a node in Godot is
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
# still there while they do. That is not a quirk to hide - it is why a sheet can remove a thing and
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
# about its own removal is a lifecycle handler, not a removal verb. Object Still Exists is the
# shipped condition and stays there too; the question below is its sentence beside it, for a sheet
# that reads in these words.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeRemovalACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The one category these rows group under in the picker.
const CATEGORY: String = "Remove"

## The property a fade walks, and the value it walks it to. A sub-property path rather than a whole
## Color, so a sprite that is already tinted fades from ITS colour instead of snapping to white on
## the first frame of the tween.
const FADE_PROPERTY: String = "modulate:a"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Now ────────────────────────────────────────────────────────────────────────────
	# The plain call. The frozen Free Node row writes the same line and stays the reading of it;
	# this is the authoring sentence, and the row the guard rule below knows how to protect.
	descriptors.append(F.make_descriptor("Core", "RemoveNow", "Remove Now", ACEDescriptor.ACEType.ACTION,
		"{object}.queue_free()", "",
		[_object_param()],
		CATEGORY, "remove [i]{object}[/i] now")
		.described("Removes the object from the game. Godot deletes it at the END of this frame, not on this line, so the rows after this one in the same event still run and the object is still there while they do. Use it for anything the game is finished with: a collected pickup, a defeated enemy, a spent effect.")
		.featured())

	# ── In a while ─────────────────────────────────────────────────────────────────────
	# A one-shot SceneTree timer with the node's own queue_free hung off it. Godot drops a signal
	# connection when the object at the far end of it is freed, which is exactly why this spelling
	# needs no bookkeeping: something else removing the thing first simply takes the connection with
	# it, and the timer fires into nothing.
	descriptors.append(F.make_descriptor("Core", "RemoveAfterSeconds", "Remove After Seconds", ACEDescriptor.ACEType.ACTION,
		"get_tree().create_timer({seconds}).timeout.connect({object}.queue_free)", "",
		[_object_param(), _after_param()],
		CATEGORY, "remove [i]{object}[/i] after {seconds}s")
		.described("Removes the object a number of seconds from now, and gets on with the event in the meantime. The wait is a scene-tree timer, so nothing about this line blocks. It is safe if something else removes the object first: Godot drops the timer's connection along with the object, and the wait ends up firing at nothing at all.")
		.featured())

	# ── Fade first ─────────────────────────────────────────────────────────────────────
	# Tween, await, remove - and the guard in the template, because that await is a real gap. The
	# row's own sentence says the wait, and its own lines say the check; nothing about the deferral
	# is hidden behind the row.
	descriptors.append(F.make_descriptor("Core", "FadeOutAndRemove", "Fade Out Then Remove", ACEDescriptor.ACEType.ACTION,
		"await {object}.create_tween().tween_property({object}, \"%s\", 0.0, {seconds}).finished\n" % FADE_PROPERTY\
		+ "if is_instance_valid({object}):\n\t{object}.queue_free()", "",
		[_object_param(), _over_param()],
		CATEGORY, "fade [i]{object}[/i] out over {seconds}s, then remove it")
		.described("Fades the object's transparency to nothing over a number of seconds and then removes it. The event WAITS here, so the rows after this one run once the fade has finished. Because that wait is a real gap in game time, the row asks whether the object is still there before removing it, and the line that asks is written into the sheet rather than added quietly."))

	# ── The question ───────────────────────────────────────────────────────────────────
	# The sentence beside the frozen Object Still Exists. Same call, same answer; a sheet that reads
	# in these words gets a row that reads in them too.
	descriptors.append(F.make_descriptor("Core", "IsStillHere", "Is Still Here", ACEDescriptor.ACEType.CONDITION,
		"is_instance_valid({object})", "",
		[_object_param()],
		CATEGORY, "[i]{object}[/i] is still here")
		.described("True while the object has not been removed. Ask it before touching anything a sheet held on to across frames: a node stored in a variable, or a copy a spawn row made in an earlier event. A node that wants to hear about its OWN removal uses the On Exit Tree trigger instead, which fires as it leaves."))

	return descriptors


## The picker's own words for the section, so selecting the header says what the rows underneath are
## for rather than leaving the reader to infer it from four names.
static func section_descriptions() -> Dictionary:
	return {
		CATEGORY: "Taking a thing out of the world: right now, after a wait, or after a fade. Each row is a plain queue_free, and each says when the call happens."
	}


## The thing being removed, or asked about. An expression on purpose: a sheet says the name a spawn
## row minted (`new_enemy`), a variable it stored a node in, or a node path. The default is `self`,
## which is the commonest answer of all - a pickup removing itself on contact.
static func _object_param() -> ACEParam:
	return F.make_param("object", "String", "self", "Object",
		"The object to remove, as an expression - the name a spawn row gave a copy, a variable holding a node, or a node path. Leave it as self for this node.",
		"expression")


## How long the timer waits.
static func _after_param() -> ACEParam:
	return F.make_param("seconds", "String", "2.0", "After",
		"How many seconds to wait before removing the object. The event carries on immediately; only the removal waits.",
		"expression")


## How long the fade takes.
static func _over_param() -> ACEParam:
	return F.make_param("seconds", "String", "0.5", "Over",
		"How many seconds the fade takes. The event waits for it, so the rows after this one run when the fade is done.",
		"expression")
