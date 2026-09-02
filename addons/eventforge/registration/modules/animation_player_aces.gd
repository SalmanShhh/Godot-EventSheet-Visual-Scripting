# EventForge module - Animation control vocabulary (drive an AnimationPlayer from events).
#
# Play / Stop / Is Playing / On Finished already exist; this fills the manipulation gap a game
# actually needs: slow-mo or speed-up the playback, scrub to a time, QUEUE the next clip so it
# plays when the current one ends (combo chains, idle-after-attack), pause/resume without losing
# position, and read the play head + clip length (sync an effect to a frame, drive a progress bar).
# Every ACE is node-scoped to AnimationPlayer, so it also gains an optional "On node" target for
# free. Compiles to plain Godot with zero plugin references.
@tool
class_name EventForgeAnimationPlayerACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Animation"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Actions ──
	descriptors.append(F.act("SetAnimationSpeed", "Set Animation Speed", "speed_scale = {scale}", CAT, "Set animation speed to {scale}", "Scales how fast every animation on this player runs - slow-mo a death, speed up a fast-forward. 0 freezes it in place.", "AnimationPlayer").param_typed("float", "scale", "1.0", "Speed", "1 = normal, 0.5 = half speed, 2 = double, 0 = paused.", "expression"))
	descriptors.append(F.act("SeekAnimation", "Seek Animation", "seek({time}, true)", CAT, "seek animation to {time}s", "Jumps the play head to a time in seconds (and updates the pose immediately) - scrub, restart from a beat, or sync to another clock.", "AnimationPlayer").param_typed("float", "time", "0.0", "Time", "Seconds from the animation's start to jump to.", "expression"))
	descriptors.append(F.act("QueueAnimation", "Queue Animation", "queue({animation})", CAT, "queue animation {animation}", "Lines up an animation to play automatically when the current one ends - combo chains, or dropping back to idle after an attack, without a timer.", "AnimationPlayer").param("animation", "\"idle\"", "Animation", "The clip to play once the current one finishes.", "animation_reference"))
	descriptors.append(F.act("PauseAnimation", "Pause Animation", "pause()", CAT, "pause animation", "Freezes the animation at its current position (Play resumes from here) - a hit-pause on a specific frame, or a photo mode.", "AnimationPlayer"))
	descriptors.append(F.act("SetAnimationTime", "Set Current Animation", "current_animation = {animation}", CAT, "set current animation to {animation}", "Switches which clip is current (assigning it starts it) - a direct set when you don't need Play's blend arguments.", "AnimationPlayer").param("animation", "\"idle\"", "Animation", "The clip to make current (assigning it also plays it).", "animation_reference"))

	# ── Conditions ──
	descriptors.append(F.cond("HasAnimation", "Has Animation", "has_animation({animation})", CAT, "has animation {animation}", "True when this player owns a clip by that name - guard a Play so a missing animation never errors.", "AnimationPlayer").param("animation", "\"attack\"", "Animation", "Clip name to check for.", "animation_reference"))

	# ── Expressions ──
	descriptors.append(F.expr("AnimationPosition", "Animation Position", "current_animation_position", CAT, "animation position", "How many seconds into the current animation the play head is - sync an effect to a frame or drive a progress bar.", "AnimationPlayer"))
	descriptors.append(F.expr("AnimationLength", "Animation Length", "current_animation_length", CAT, "animation length", "The current animation's total length in seconds - pair with Animation Position for a normalized 0-to-1 progress.", "AnimationPlayer"))
	descriptors.append(F.expr("AnimationSpeed", "Animation Speed", "speed_scale", CAT, "animation speed", "The player's current speed scale (1 = normal).", "AnimationPlayer"))

	# The sprite rows an opened script already READS as its own words, so the picker writes the
	# exact shape the reading recognises.
	descriptors.append(F.act("SetFlipV", "Set Flipped", "flip_v = {flipped}", CAT, "Set flipped {flipped}", "Turns this sprite upside down, or back the right way up.", "Sprite2D").param_choice("flipped", "true", "Flipped", "Flip the sprite upside down.", ["true", "false"]))
	descriptors.append(F.act("SetSpriteTexture", "Set Image", "texture = load({path})", CAT, "Set image to {path}", "Shows a different image on this sprite.", "Sprite2D").param("path", "\"res://icon.svg\"", "Image", "Image file to show.", "expression"))
	descriptors.append(F.cond("AnimationIsPlaying", "Is Playing", "is_playing()", CAT, "Is playing", "True while this animation player is running an animation.", "AnimationPlayer"))

	# ── the blend-tree rows the magic parameter strings hide ───────
	#
	# An AnimationTree is driven by writing values into paths like `parameters/Locomotion/blend_position`,
	# which is exactly the kind of string an event sheet exists to hide. Set Blend and Go To State
	# already ship; these are the two the reading found missing. Both templates write the exact shape
	# the reading recognises, so a picked row and a hand-typed line are the same bytes.
	descriptors.append(F.act("PlayOneShotAnimation", "Play One-Shot Animation", "set(\"parameters/{name}/request\", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)", CAT, "Play one-shot animation {name}", "Fires a one-shot animation on a blend tree - a shot, a hit reaction, a wave - over whatever the character is already doing.", "AnimationTree").param("name", "Shoot", "One-shot", "The name of the OneShot node in the blend tree.").featured())
	descriptors.append(F.cond("AnimationStateIs", "Current State Is", "get(\"parameters/playback\").get_current_node() == {state}", CAT, "Current state is {state}", "True while a blend tree's state machine is in the named state - what a landing recovery or an attack window branches on.", "AnimationTree").param("state", "\"Idle\"", "State", "The name of the state-machine node to ask about."))

	_combo_timing(descriptors)
	_animation_events(descriptors)
	_picked_names(descriptors)
	return descriptors


## ── the rows that name an animation the scene really has ────────────────────────────────────────
##
## An animation name is a string, and `play("atack")` plays nothing and says nothing. Both rows here
## take their names from the scene's own list, which is what makes the misspelling impossible to
## reach the game unnoticed.
##
## PLAY THEN is the chain everybody writes by hand: play this, and when it ends play that. Godot
## spells it `play()` followed by `queue()`, and the row owns both lines so the waiting is not a
## timer somebody has to guess the length of.
##
## PAST A MARKER is the keyframed answer to "which frame is the hit on". A skeletal swing has no
## frame 3 to click; it has named moments on a timeline, and the moment moves when the animator
## retimes it - so the row asks the animation where its marker is rather than storing a number.
static func _picked_names(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("PlayThenQueue", "Play Then", "play(&{animation})\nqueue(&{next})", CAT, "Play {animation} then {next}", "Plays one animation and lines the next one up behind it - attack then idle, jump then fall. The waiting is the engine's own: the second starts the moment the first finishes, with no timer to keep in step. An animation that LOOPS never finishes, so a chain behind one never comes.", "AnimationPlayer").param("animation", "\"attack\"", "Animation", "The clip to play now.", "animation_reference").param("next", "\"idle\"", "Then", "The clip that plays the moment the first one ends.", "animation_reference").featured())
	descriptors.append(F.cond("AnimationPastMarker", "Reached Marker", "{target.}current_animation == {animation} and {target.}current_animation_position >= {target.}get_animation({animation}).get_marker_time({marker})", CAT, "{animation} has reached {marker}", "True once a clip's play head has passed a named moment on its timeline - the frame the hit lands on, in the only form a keyframed animation has. Retiming the moment in the Animation panel moves it; the row does not change.", "AnimationPlayer").param("animation", "\"attack\"", "Animation", "The clip whose timeline the moment lives on.", "animation_reference").param("marker", "\"impact\"", "Marker", "The named moment on that clip's timeline.", "marker_reference").param("target", "", "On node", "Ask another AnimationPlayer instead of this one. Leave blank for this node.", "expression").featured())


## ── the two timing tricks every combo game writes ───────────────────────────────────────────────
##
## A CANCEL WINDOW is a slice of one animation's clock: between 0.3 s and 0.6 s of "uppercut" the
## next move may interrupt this one. Written by hand it is two comparisons on
## `current_animation_position` with the clip name beside them, which reads as raw property maths and
## names nothing; as a row it is one question with a name.
##
## HIT-STOP freezes the whole game for a few frames on a connecting blow - that row already ships as
## Juice ▸ Hitstop, so nothing is minted for it here. What is missing is the PER-OBJECT twin: pausing
## one animation player while everything else keeps running, which is the version a fighter uses when
## only the two characters should feel the blow.
##
## Both templates carry their own `{target.}` slots rather than taking the automatic "On node" one,
## because each mentions the player TWICE and the automatic prefix reaches only the first line lead.
static func _combo_timing(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("AnimationIsBetween", "Is Between", "{target.}current_animation == {animation} and {target.}current_animation_position > {from_time} and {target.}current_animation_position < {to_time}", CAT, "Is between {from_time} s and {to_time} s of {animation}", "True while the play head is inside a slice of one clip - the cancel window a follow-up move is allowed in, the active frames a hit counts on.", "AnimationPlayer").param("animation", "\"attack\"", "Animation", "The clip whose clock the window lives on.", "animation_reference").param("from_time", "0.3", "From", "Seconds into the clip the window opens.", "expression").param("to_time", "0.6", "To", "Seconds into the clip the window shuts.", "expression").param("target", "", "On node", "Ask another AnimationPlayer instead of this one. Leave blank for this node.", "expression").featured())
	descriptors.append(F.act("PauseAnimationFor", "Pause For", "{target.}pause()\nawait get_tree().create_timer({seconds}, true, false, true).timeout\n{target.}play()", CAT, "Pause for {seconds} s", "Holds THIS animation still for a moment and then lets it run on - the per-object hit-stop, for when only the two characters trading blows should feel it. The wait ignores the game's time scale, so it un-pauses even during a slow-motion.", "AnimationPlayer").param("seconds", "0.08", "Seconds", "How long the animation holds still, in real time.", "expression").param("target", "", "On node", "Pause another AnimationPlayer instead of this one. Leave blank for this node.", "expression").featured())


## ── animation-driven events ─────────────────────────────────────────────────────────────────────
##
## Half of game feel is the animation telling the game when: the hit lands on frame 3, the footstep
## plays on frame 6, the projectile leaves the hand at 0.4 s. Godot spells that two ways, and both
## of them read as plumbing rather than as an event:
##
##   2D   `frame_changed` on an AnimatedSprite2D, plus a test of which clip and which frame it is.
##   Any  an AnimationPlayer METHOD TRACK, whose key calls a function on the script by name.
##
## The first is a signal with its guard folded into the head; the second is a plain function the
## engine calls, exactly like the noise-heard hook, so it compiles to a named function and nothing
## else. Both are the shape the reading recognises, so a hand-typed hit frame and a picked row are
## the same bytes.
static func _animation_events(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.trig("OnAnimationFrame", "On Animation Frame", "frame_changed", CAT, "On animation {animation} frame {frame}", "Runs the moment a sprite animation reaches one frame of one clip - the hit frame, the footstep, the frame a shell drops on. Applying it adds the clip-and-frame question as a condition you can see and edit.", "AnimatedSprite2D").param("animation", "\"attack\"", "Animation", "The clip the frame belongs to.", "animation_reference").param("frame", "3", "Frame", "Which frame of that clip to answer.", "animation_frame"))
	descriptors.append(F.cond("SpriteAnimationFrameIs", "Is Animation Frame", "{target.}animation == {animation} and {target.}frame == {frame}", CAT, "animation is {animation} frame {frame}", "True when a sprite is showing one particular frame of one particular clip - the question under On Animation Frame, on its own for a per-tick check.", "AnimatedSprite2D").param("animation", "\"attack\"", "Animation", "The clip to ask about.", "animation_reference").param("frame", "3", "Frame", "The frame index to ask about.", "animation_frame").param("target", "", "On node", "Ask another AnimatedSprite2D instead of this one. Leave blank for this node.", "expression"))
	descriptors.append(F.trig("OnAnimationEvent", "On Animation Event", "", CAT, "On animation event {event_name}", "Runs when an animation's method track reaches its key. The track calls a function by name and this event IS that function, so the animation and the sheet meet without a signal in between - name the event here and call the same name from the track.").param("event_name", "hit", "Event", "The name the animation's method track calls, in plain words (\"hit frame\" becomes the function _on_hit_frame)."))


static func section_descriptions() -> Dictionary:
	return {CAT: "Drive an AnimationPlayer from events - speed / seek / queue / pause / set the current clip, check it exists, and read the play head, length, and speed. Node-scoped to AnimationPlayer with an optional On node target."}
