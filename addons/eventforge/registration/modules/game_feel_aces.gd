# EventForge module - the sprite, UI, sound and game-feel rows an opened script already READS as.
#
# Every row here writes the exact shape the reading recognises, so a pattern typed by hand and the
# same pattern dropped from the picker are the same bytes and read the same words:
#
#   Set flipped            flip_v = true
#   Set image              texture = load("res://hero.png")
#   Travel to state        self["parameters/playback"].travel("Hurt")
#   Set progress           value = hp / max_value = max_hp
#   Show dialog            popup_centered()
#   Set master volume      AudioServer.set_bus_volume_db(0, linear_to_db(0.5))
#   Set sound / bus        stream = load(...) / bus = "SFX"
#   Set volume (0 to 1)    volume_db = linear_to_db(0.5)
#   Shake                  offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
#   Hitstop                Engine.time_scale down, a real-time wait, then back to 1
#   Bob                    position.y = base + sin(t * f) * magnitude
#   Flash                  modulate = a colour, a wait, then back to white
#   Ease size back         scale = scale.lerp(Vector2.ONE, rate * delta)
#
# Where a behavior ships for the same effect (Juice, Sine, Flash), attaching it is the first option
# and these free actions are the second. Module contract: see ace_factory.gd - ace_ids/templates are
# API (covenant).
@tool
class_name EventForgeGameFeelACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_add_sprite_descriptors(descriptors)
	_add_ui_descriptors(descriptors)
	_add_sound_descriptors(descriptors)
	_add_juice_descriptors(descriptors)
	return descriptors


## S11 - the sprite and animation rows an opened script reads as its own words.
static func _add_sprite_descriptors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetFlipV", "Set Flipped", ACEDescriptor.ACEType.ACTION,
		"flip_v = {flipped}", "", [
			F.make_param("flipped", "String", "true", "Flipped", "Flip the sprite upside down.", "", ["true", "false"])
		], "Animation", "Set flipped {flipped}", "Sprite2D")
		.described("Turns this sprite upside down, or back the right way up."))
	descriptors.append(F.make_descriptor("Core", "SetSpriteTexture", "Set Image", ACEDescriptor.ACEType.ACTION,
		"texture = load({path})", "", [
			F.make_param("path", "String", "\"res://icon.svg\"", "Image", "Image file to show.", "expression")
		], "Animation", "Set image to {path}", "Sprite2D")
		.described("Shows a different image on this sprite."))
	descriptors.append(F.make_descriptor("Core", "TravelToAnimationState", "Travel To Animation State",
		ACEDescriptor.ACEType.ACTION, "self[\"parameters/playback\"].travel({state})", "", [
			F.make_param("state", "String", "\"Idle\"", "State", "State machine node to travel to.", "expression")
		], "Animation", "Travel to animation state {state}", "AnimationTree")
		.described("Moves this animation tree's state machine to another state, playing the transition."))
	descriptors.append(F.make_descriptor("Core", "AnimationIsPlaying", "Is Playing",
		ACEDescriptor.ACEType.CONDITION, "is_playing()", "", [], "Animation", "Is playing", "AnimationPlayer")
		.described("True while this animation player is running an animation."))


## S12 - focus is shipped (UI module); these are the three UI shapes that still read as raw code.
static func _add_ui_descriptors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetProgress", "Set Progress", ACEDescriptor.ACEType.ACTION,
		"value = {value}\nmax_value = {max}", "", [
			F.make_param("value", "String", "0", "Value", "How full the bar is.", "expression"),
			F.make_param("max", "String", "100", "Of", "The full amount.", "expression")
		], "UI", "Set progress to {value} of {max}", "Range")
		.described("Fills a progress bar to a value out of a maximum, both in one row."))
	descriptors.append(F.make_descriptor("Core", "ShowDialogCentred", "Show Dialog", ACEDescriptor.ACEType.ACTION,
		"popup_centered()", "", [], "UI", "Show dialog (centred)", "Window")
		.described("Opens this dialog in the middle of the screen."))
	descriptors.append(F.make_descriptor("Core", "SetMasterVolume", "Set Master Volume",
		ACEDescriptor.ACEType.ACTION, "AudioServer.set_bus_volume_db(0, linear_to_db({level}))", "", [
			F.make_param("level", "String", "0.5", "Level", "0 = silent, 1 = full - the number a volume slider gives.", "expression")
		], "UI", "Set master volume to {level} (0 to 1)")
		.described("Sets the overall game volume from a 0-to-1 slider value."))


## S13 - the sound a player holds, the bus it goes out on, and its volume as a level rather than dB.
static func _add_sound_descriptors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "AudioSetStream", "Set Sound", ACEDescriptor.ACEType.ACTION,
		"stream = load({path})", "", [
			F.make_param("path", "String", "\"res://sound.ogg\"", "Sound", "Audio file this player holds.", "audio_path")
		], "Audio", "Set sound to {path}", "AudioStreamPlayer")
		.described("Puts a sound file into this player, ready to play."))
	descriptors.append(F.make_descriptor("Core", "AudioSetBus", "Set Bus", ACEDescriptor.ACEType.ACTION,
		"bus = {bus}", "", [
			F.make_param("bus", "String", "\"SFX\"", "Bus", "Audio bus this player goes out on.", "expression")
		], "Audio", "Set bus to {bus}", "AudioStreamPlayer")
		.described("Sends this player's sound out on a named bus, like SFX or Music."))
	descriptors.append(F.make_descriptor("Core", "AudioSetVolumeLevel", "Set Volume", ACEDescriptor.ACEType.ACTION,
		"volume_db = linear_to_db({level})", "", [
			F.make_param("level", "String", "0.5", "Level", "0 = silent, 1 = full - the number a volume slider gives.", "expression")
		], "Audio", "Set volume to {level} (0 to 1)", "AudioStreamPlayer")
		.described("Sets how loud this player is from a 0-to-1 level, with the decibel conversion done for you."))


## S14 - the five most copied game-feel snippets. The Juice, Sine and Flash behaviors do all of this
## and more with state of their own; these are the one-line versions for a script that only wants one.
static func _add_juice_descriptors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "CameraShakeOnce", "Shake", ACEDescriptor.ACEType.ACTION,
		"offset = Vector2(randf_range(-{amount}, {amount}), randf_range(-{amount}, {amount}))", "", [
			F.make_param("amount", "String", "4.0", "Amount", "Biggest offset in pixels, this tick.", "expression")
		], "Juice", "Shake by {amount}", "Camera2D")
		.described("Jolts this camera by a random offset for one tick. Run it every tick while a hit lands."))
	descriptors.append(F.make_descriptor("Core", "Hitstop", "Hitstop", ACEDescriptor.ACEType.ACTION,
		"Engine.time_scale = {scale}\nawait get_tree().create_timer({seconds}, true, false, true).timeout\nEngine.time_scale = 1.0",
		"", [
			F.make_param("seconds", "String", "0.05", "Seconds", "How long the freeze lasts, in real time.", "expression"),
			F.make_param("scale", "String", "0.1", "Time scale", "0 = frozen, 1 = normal speed.", "expression")
		], "Juice", "Hitstop for {seconds} seconds")
		.described("Slows the whole game to a crawl for a moment and then restores it - the punch a hit lands with."))
	descriptors.append(F.make_descriptor("Core", "BobY", "Bob", ACEDescriptor.ACEType.ACTION,
		"position.y = {base} + sin({time} * {frequency}) * {magnitude}", "", [
			F.make_param("base", "String", "0.0", "Around", "The height it bobs around.", "expression"),
			F.make_param("time", "String", "Time.get_ticks_msec() / 1000.0", "Time",
				"A number that grows every tick - the clock, or a variable you add delta to.", "expression"),
			F.make_param("frequency", "String", "3.0", "Per second", "How many bobs a second.", "expression"),
			F.make_param("magnitude", "String", "8.0", "Magnitude", "How far it moves, in pixels.", "expression")
		], "Juice", "Bob y", "Node2D")
		.described("Floats this object up and down on a sine wave. Run it every tick."))
	descriptors.append(F.make_descriptor("Core", "FlashColour", "Flash", ACEDescriptor.ACEType.ACTION,
		"modulate = {colour}\nawait get_tree().create_timer({seconds}).timeout\nmodulate = Color.WHITE", "", [
			F.make_param("colour", "String", "Color.RED", "Colour", "The tint to flash.", "color"),
			F.make_param("seconds", "String", "0.1", "Seconds", "How long the flash lasts.", "expression")
		], "Juice", "Flash {colour} for {seconds} seconds", "CanvasItem")
		.described("Tints this object for a moment and then puts it back - the damage flash."))
	descriptors.append(F.make_descriptor("Core", "EaseSizeBack", "Ease Size Back", ACEDescriptor.ACEType.ACTION,
		"scale = scale.lerp(Vector2.ONE, {rate} * delta)", "", [
			F.make_param("rate", "String", "10.0", "Rate", "How fast it recovers, per second.", "expression")
		], "Juice", "Ease size back to normal at {rate}", "Node2D")
		.described("Eases this object's size back to normal, which is how a squash recovers. Run it every tick."))
