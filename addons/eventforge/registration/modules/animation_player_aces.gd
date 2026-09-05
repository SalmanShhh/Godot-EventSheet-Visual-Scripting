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
	descriptors.append(F.cond("AnimationStateIs", "Current State Is", "get(\"parameters/playback\").get_current_node() == {state}", CAT, "Current state is {state}", "True while a blend tree's state machine is in the named state - what a landing recovery or an attack window branches on. This is the tree's ROOT state machine: a machine nested inside another one is not reached.", "AnimationTree").param("state", "\"Idle\"", "State", "The name of the state-machine node to ask about. The list is the tree's own states.", "animation_state"))

	_combo_timing(descriptors)
	_animation_events(descriptors)
	_picked_names(descriptors)
	_blend_tree(descriptors)
	_root_motion(descriptors)
	return descriptors


## ── the rest of what a blend tree does ──────────────────────────────────────────────────────────
##
## Two rows above drive an AnimationTree: fire a one-shot, ask which state it is in. A character that
## walks, runs, turns and swings needs the rest of it, and all of the rest is the same thing - a value
## written into, or read out of, a magic string:
##
##   parameters/playback              the state machine's own object: travel, start, where it is now
##   parameters/<space>/blend_position   where a blend space is being sampled (a float, or a Vector2)
##   parameters/<layer>/blend_amount     how much of a Blend2 or an Add2 is mixed in
##   parameters/conditions/<name>        the booleans a transition advances on
##
## Written by hand, every one of those is a string the compiler never checks and the game never
## complains about: `travel(&"Swng")` walks nowhere, and a Vector2 written into a one-dimensional
## space blends by its x alone. As rows, the string is assembled from a field that lists the tree's
## OWN names, and the two mistakes that survive it are said by the Doctor before the game runs.
##
## EVERY SHIPPED TREE ROW IS UNTOUCHED, and there are nine of them rather than the two this file
## holds - Travel To State, Set Blend, Is In State, Current State, Tree Parameter, Is Tree Active and
## Set AnimationTree Active are on the collections shelf, and the travel one writes exactly the line
## a travel row would. So nothing here re-mints any of them: what they were missing was a field that
## knows the tree's own names, and that was added to the rows themselves.
##
## Everything below lands beside them, and each template writes the line a person would have typed,
## so a hand-written blend tree opens as these rows and saves back byte for byte.
static func _blend_tree(descriptors: Array[ACEDescriptor]) -> void:
	# TRAVEL TO STATE IS NOT MINTED HERE, and that is the point: it already ships, with this exact
	# template, and a second row writing the same line would split every travel in every project
	# between the two by registration order alone. What it did not have was a field that knows the
	# tree's states, and that is added to the shipped row rather than beside it.
	descriptors.append(F.act("JumpToState", "Jump To", "get(\"parameters/playback\").start({state})", CAT, "Jump to {state}", "Puts the state machine into a state at once, ignoring every transition between here and there - a respawn, a cutscene cut, a hard reset. Travel To State is the everyday one; this is the cut. This is the tree's ROOT state machine: a machine nested inside another one is not reached.", "AnimationTree").param("state", "\"Idle\"", "State", "The state to start from the beginning, with no transition.", "animation_state"))
	descriptors.append(F.cond("AnimationStateIsAny", "Is In Any State", "get(\"parameters/playback\").get_current_node() in {states}", CAT, "Is in state {states}", "True while the state machine is in ANY of the states listed - the attack that may start from a stand or a run, the interrupt that only some states allow. The single-state question already ships beside it. This is the tree's ROOT state machine: a machine nested inside another one is not reached.", "AnimationTree").param("states", "[\"Idle\", \"Run\"]", "States", "The states this question says yes to, as a list of names.", "expression").featured())
	descriptors.append(F.act("SetBlendPosition", "Set Blend Position", "set(\"parameters/{space}/blend_position\", {value})", CAT, "set {space} blend to {value}", "Moves where a blend space is sampled - the stick's direction into a walk-run-turn space, the aim height into a lean. A one-dimensional space takes a number and a two-dimensional one takes a Vector2; the field lists the spaces the tree really has.", "AnimationTree").param("space", "Locomotion", "Blend space", "The blend space node in the tree, by its own name.", "blend_space").param_typed("Vector2", "value", "Vector2.ZERO", "To", "Where to sample it: a number for a one-dimensional space, a Vector2 for a two-dimensional one.", "expression").featured())
	descriptors.append(F.act("BlendToward", "Blend Toward", "if {target}.has_meta(&\"blend_{space}\"):\n\t({target}.get_meta(&\"blend_{space}\") as Tween).kill()\nvar __blend_{uid}: Tween = {target}.create_tween()\n{target}.set_meta(&\"blend_{space}\", __blend_{uid})\n__blend_{uid}.tween_property({target}, \"parameters/{space}/blend_position\", {value}, {seconds})", CAT, "blend {space} to {value} over {seconds} s", "The same move, taken over time instead of at once - the stick snaps, the blend should not. A tween on the tree's own parameter, so nothing has to be stepped by hand. Asked again while the last one is still walking, it takes the last one off first: an every-tick row leaves one tween moving the blend, not one per frame all pulling at the same number.", "AnimationTree").param("space", "Locomotion", "Blend space", "The blend space node in the tree, by its own name.", "blend_space").param_typed("Vector2", "value", "Vector2.ZERO", "To", "Where the blend ends up.", "expression").param("seconds", "0.2", "Over", "How long the move takes, in seconds.", "expression").param_typed("Node", "target", "self", "On node", "The AnimationTree to blend. Leave it as self when this sheet is the tree.", "scene_node"))
	descriptors.append(F.act("BlendLayer", "Blend Layer", "if {target}.has_meta(&\"blend_{layer}\"):\n\t({target}.get_meta(&\"blend_{layer}\") as Tween).kill()\nvar __blend_{uid}: Tween = {target}.create_tween()\n{target}.set_meta(&\"blend_{layer}\", __blend_{uid})\n__blend_{uid}.tween_property({target}, \"parameters/{layer}/blend_amount\", {amount}, {seconds})", CAT, "blend layer {layer} to {amount} over {seconds} s", "Mixes a layer in or out over time - the aim pose that fades on when a target is locked, the hurt overlay that fades off. The layer is a Blend2 or an Add2 in the tree, and the amount is 0 for none of it and 1 for all of it. Asked again while the last one is still walking, it takes the last one off first, so a row in a tick event leaves one tween moving the layer rather than one per frame.", "AnimationTree").param("layer", "Aim", "Layer", "The Blend2 or Add2 node in the tree, by its own name.", "blend_layer").param("amount", "1.0", "To", "How much of the layer to mix in: 0 for none, 1 for all of it.", "expression").param("seconds", "0.2", "Over", "How long the fade takes, in seconds.", "expression").param_typed("Node", "target", "self", "On node", "The AnimationTree to blend. Leave it as self when this sheet is the tree.", "scene_node").featured())
	descriptors.append(F.act("SetTreeCondition", "Set Condition", "set(\"parameters/conditions/{condition}\", {value})", CAT, "set condition {condition} to {value}", "Writes one of the booleans a state machine's transitions advance on - the tree decides WHEN to move, the sheet only says what is true. Set it from a condition row and the transitions the tree was drawn with do the rest.", "AnimationTree").param("condition", "is_running", "Condition", "The advance condition's name, as the transition spells it.").param_choice("value", "true", "To", "What that condition is now.", ["true", "false"]))
	descriptors.append(F.act("SetTreeTimeScale", "Set Tree Time Scale", "set(\"parameters/{node}/scale\", {scale})", CAT, "set {node} to {scale}x", "Slows down or speeds up everything under one TimeScale node in the tree - a slow-motion finish, a hasted character - without touching the game's own clock.", "AnimationTree").param("node", "TimeScale", "TimeScale node", "The TimeScale node in the tree, by its own name.").param("scale", "1.0", "To", "1 is normal, 0.5 half speed, 2 double.", "expression"))
	descriptors.append(F.expr("AnimationTimeInState", "Time In State", "get(\"parameters/playback\").get_current_play_position()", CAT, "time in state", "How many seconds the state machine has been playing its current state - the number a recovery window, a charge-up or a progress bar is measured against. This is the tree's ROOT state machine: a machine nested inside another one is not reached.", "AnimationTree"))
	# The two moments a state machine has, and they are real signals: the playback object raises
	# `state_started` when it enters a state and `state_finished` when the state it was in ends. The
	# object lives at `parameters/playback`, so the `_ready` line reaches through the tree to it -
	# which is exactly the line a hand-written project writes to hear the same thing.
	descriptors.append(F.trig("OnAnimationStateEntered", "On State Entered", "state_started", CAT, "On state entered", "Runs the moment the state machine enters a state, with the state's name handed to the event. The state machine's own answer to \"the swing has started\" - no polling, no per-frame question. This is the tree's ROOT state machine: a machine nested inside another one is not reached.", "AnimationTree"))
	descriptors.append(F.trig("OnAnimationStateLeft", "On State Left", "state_finished", CAT, "On state left", "Runs the moment the state the machine was in finishes, with its name handed to the event - the recovery that begins when the swing ends. This is the tree's ROOT state machine: a machine nested inside another one is not reached.", "AnimationTree"))
	# And the marker moment, built on the shipped Reached Marker question rather than beside it: the
	# mixer says it has just been stepped, and the row under the trigger says which crossing this
	# event answers.
	descriptors.append(F.trig("OnAnimationReachedMarker", "On Animation Reached Marker", "mixer_updated", CAT, "On {animation} reaching {marker}", "Runs on the one frame a clip's play head crosses a named moment on its timeline - the frame the hit lands on. Applying it adds the crossing as a condition you can see and edit, so the moment is a row rather than a number nobody can find.", "AnimationPlayer").param("animation", "\"attack\"", "Animation", "The clip whose timeline the moment lives on.", "animation_reference").param("marker", "\"impact\"", "Marker", "The named moment on that clip's timeline.", "marker_reference"))
	descriptors.append(F.cond("AnimationJustPastMarker", "Just Reached Marker", "({target.}current_animation == {animation} and {target.}current_animation_position >= {target.}get_animation({animation}).get_marker_time({marker})) and not __marker_{uid}", CAT, "{animation} has just reached {marker}", "True on the ONE frame the play head crosses a named moment, and false on every frame after it - the difference between \"the hit has landed\" and \"the hit landed a while ago\". Reached Marker beside it stays true for the rest of the clip, which is the right question for a window rather than for a moment.", "AnimationPlayer").param("animation", "\"attack\"", "Animation", "The clip whose timeline the moment lives on.", "animation_reference").param("marker", "\"impact\"", "Marker", "The named moment on that clip's timeline.", "marker_reference").param("target", "", "On node", "Ask another AnimationPlayer instead of this one. Leave blank for this node.", "expression").stateful(
		"var __marker_{uid}: bool = false",
		"__marker_{uid} = __marker_{uid} and {target.}current_animation == {animation} and {target.}current_animation_position >= {target.}get_animation({animation}).get_marker_time({marker})",
		"__marker_{uid} = true"))


## ── the animator's own movement, taken into the body ────────────────────────────────────────────
##
## ROOT MOTION is the animation moving the character rather than a number in the sheet moving it: the
## swing steps forward because the animator made it step forward, and the code's job is only to hand
## that step to the body. Godot spells it as two questions on the tree - how far the root moved this
## frame, and how far it turned - and the whole of the work is dividing the first by the frame time,
## because a velocity is a distance per second and root motion is a distance per frame.
##
## The 3D form turns the animator's step by the body's own basis first, because the animation was
## authored facing forward and the character is facing wherever it is facing. The 2D twin has no
## basis to turn by: the tree still answers in three dimensions, so the row takes the x and the y of
## its answer and leaves the z alone.
##
## Both own their `{target.}` slot rather than taking the automatic "On node" one, because each names
## the body more than once and the automatic prefix reaches only the first line lead.
##
## A FRAME OF NO TIME IS NO MOVEMENT. Dividing by the frame time is right until the frame time is
## zero, which is what a hit stop is - `Engine.time_scale = 0` is the ordinary way to freeze a game -
## and a distance divided by zero is an infinity written straight into velocity, which throws the body
## out of the level on the next Move And Slide. So both rows ask first: no time, no step.
static func _root_motion(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("ApplyRootMotion", "Apply Root Motion", "var __root_{uid}: Vector3 = {tree}.get_root_motion_position()\n{target.}velocity = (Vector2(__root_{uid}.x, __root_{uid}.y) / delta * {scale}) if delta > 0.0 else Vector2.ZERO\n{target.}rotation += {tree}.get_root_motion_rotation().get_euler().z", CAT, "Apply root motion", "Moves and turns this body by whatever the animation's root moved this frame, so an animator's step really steps. Put it in a physics tick, before Move And Slide. The scale is there for the day the animation was authored at the wrong size.", "CharacterBody2D").param("tree", "$AnimationTree", "Tree", "The AnimationTree the root motion is read from.", "scene_node").param("scale", "1.0", "Scale", "Multiplies the movement - 1 keeps the animator's own distance.", "expression").param("target", "", "On node", "Move another body instead of this one. Leave blank for this node.", "expression").featured())
	descriptors.append(F.act("ApplyRootMotion3D", "Apply Root Motion", "{target.}velocity = (({target.}basis * {tree}.get_root_motion_position()) / delta * {scale}) if delta > 0.0 else Vector3.ZERO\n{target.}quaternion *= {tree}.get_root_motion_rotation()", CAT, "Apply root motion", "Moves and turns this body by whatever the animation's root moved this frame, turned by the way the body is already facing, so an animator's step really steps. Put it in a physics tick, before Move And Slide. The scale is there for the day the animation was authored at the wrong size.", "CharacterBody3D").param("tree", "$AnimationTree", "Tree", "The AnimationTree the root motion is read from.", "scene_node").param("scale", "1.0", "Scale", "Multiplies the movement - 1 keeps the animator's own distance.", "expression").param("target", "", "On node", "Move another body instead of this one. Leave blank for this node.", "expression").featured())


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
