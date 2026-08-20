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
	descriptors.append(F.make_descriptor("Core", "SetAnimationSpeed", "Set Animation Speed", ACEDescriptor.ACEType.ACTION, "speed_scale = {scale}", "", [F.make_param("scale", "float", "1.0", "Speed", "1 = normal, 0.5 = half speed, 2 = double, 0 = paused.", "expression")], CAT, "Set animation speed to {scale}", "AnimationPlayer")
		.described("Scales how fast every animation on this player runs - slow-mo a death, speed up a fast-forward. 0 freezes it in place."))
	descriptors.append(F.make_descriptor("Core", "SeekAnimation", "Seek Animation", ACEDescriptor.ACEType.ACTION, "seek({time}, true)", "", [F.make_param("time", "float", "0.0", "Time", "Seconds from the animation's start to jump to.", "expression")], CAT, "seek animation to {time}s", "AnimationPlayer")
		.described("Jumps the play head to a time in seconds (and updates the pose immediately) - scrub, restart from a beat, or sync to another clock."))
	descriptors.append(F.make_descriptor("Core", "QueueAnimation", "Queue Animation", ACEDescriptor.ACEType.ACTION, "queue({animation})", "", [F.make_param("animation", "String", "\"idle\"", "Animation", "The clip to play once the current one finishes.", "expression")], CAT, "queue animation {animation}", "AnimationPlayer")
		.described("Lines up an animation to play automatically when the current one ends - combo chains, or dropping back to idle after an attack, without a timer."))
	descriptors.append(F.make_descriptor("Core", "PauseAnimation", "Pause Animation", ACEDescriptor.ACEType.ACTION, "pause()", "", [], CAT, "pause animation", "AnimationPlayer")
		.described("Freezes the animation at its current position (Play resumes from here) - a hit-pause on a specific frame, or a photo mode."))
	descriptors.append(F.make_descriptor("Core", "SetAnimationTime", "Set Current Animation", ACEDescriptor.ACEType.ACTION, "current_animation = {animation}", "", [F.make_param("animation", "String", "\"idle\"", "Animation", "The clip to make current (assigning it also plays it).", "expression")], CAT, "set current animation to {animation}", "AnimationPlayer")
		.described("Switches which clip is current (assigning it starts it) - a direct set when you don't need Play's blend arguments."))

	# ── Conditions ──
	descriptors.append(F.make_descriptor("Core", "HasAnimation", "Has Animation", ACEDescriptor.ACEType.CONDITION, "has_animation({animation})", "", [F.make_param("animation", "String", "\"attack\"", "Animation", "Clip name to check for.", "expression")], CAT, "has animation {animation}", "AnimationPlayer")
		.described("True when this player owns a clip by that name - guard a Play so a missing animation never errors."))

	# ── Expressions ──
	descriptors.append(F.make_descriptor("Core", "AnimationPosition", "Animation Position", ACEDescriptor.ACEType.EXPRESSION, "current_animation_position", "", [], CAT, "animation position", "AnimationPlayer")
		.described("How many seconds into the current animation the play head is - sync an effect to a frame or drive a progress bar."))
	descriptors.append(F.make_descriptor("Core", "AnimationLength", "Animation Length", ACEDescriptor.ACEType.EXPRESSION, "current_animation_length", "", [], CAT, "animation length", "AnimationPlayer")
		.described("The current animation's total length in seconds - pair with Animation Position for a normalized 0-to-1 progress."))
	descriptors.append(F.make_descriptor("Core", "AnimationSpeed", "Animation Speed", ACEDescriptor.ACEType.EXPRESSION, "speed_scale", "", [], CAT, "animation speed", "AnimationPlayer")
		.described("The player's current speed scale (1 = normal)."))

	# S11 - the sprite rows an opened script already READS as its own words, so the picker writes the
	# exact shape the reading recognises.
	descriptors.append(F.make_descriptor("Core", "SetFlipV", "Set Flipped", ACEDescriptor.ACEType.ACTION, "flip_v = {flipped}", "", [F.make_param("flipped", "String", "true", "Flipped", "Flip the sprite upside down.", "", ["true", "false"])], CAT, "Set flipped {flipped}", "Sprite2D")
		.described("Turns this sprite upside down, or back the right way up."))
	descriptors.append(F.make_descriptor("Core", "SetSpriteTexture", "Set Image", ACEDescriptor.ACEType.ACTION, "texture = load({path})", "", [F.make_param("path", "String", "\"res://icon.svg\"", "Image", "Image file to show.", "expression")], CAT, "Set image to {path}", "Sprite2D")
		.described("Shows a different image on this sprite."))
	descriptors.append(F.make_descriptor("Core", "AnimationIsPlaying", "Is Playing", ACEDescriptor.ACEType.CONDITION, "is_playing()", "", [], CAT, "Is playing", "AnimationPlayer")
		.described("True while this animation player is running an animation."))

	# ── X7 - the blend-tree rows the magic parameter strings hide ──
	#
	# An AnimationTree is driven by writing values into paths like `parameters/Locomotion/blend_position`,
	# which is exactly the kind of string an event sheet exists to hide. Set Blend and Go To State
	# already ship; these are the two the reading found missing. Both templates write the exact shape
	# the reading recognises, so a picked row and a hand-typed line are the same bytes.
	descriptors.append(F.make_descriptor("Core", "PlayOneShotAnimation", "Play One-Shot Animation", ACEDescriptor.ACEType.ACTION,
		"set(\"parameters/{name}/request\", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)", "",
		[F.make_param("name", "String", "Shoot", "One-shot", "The name of the OneShot node in the blend tree.")],
		CAT, "Play one-shot animation {name}", "AnimationTree")
		.described("Fires a one-shot animation on a blend tree - a shot, a hit reaction, a wave - over whatever the character is already doing.").featured())
	descriptors.append(F.make_descriptor("Core", "AnimationStateIs", "Current State Is", ACEDescriptor.ACEType.CONDITION,
		"get(\"parameters/playback\").get_current_node() == {state}", "",
		[F.make_param("state", "String", "\"Idle\"", "State", "The name of the state-machine node to ask about.")],
		CAT, "Current state is {state}", "AnimationTree")
		.described("True while a blend tree's state machine is in the named state - what a landing recovery or an attack window branches on."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Drive an AnimationPlayer from events - speed / seek / queue / pause / set the current clip, check it exists, and read the play head, length, and speed. Node-scoped to AnimationPlayer with an optional On node target."}
