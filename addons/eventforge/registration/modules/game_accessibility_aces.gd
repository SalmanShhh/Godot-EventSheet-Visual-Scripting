# EventForge module - Accessibility for the GAME (X29): the options every project should be one row
# from offering.
#
# The editor's own accessibility already ships. This is the player-facing half, and every ingredient
# for it existed somewhere already - the live Input Map, saved bindings, the juice packs, the caption
# strip, spoken text - with nothing composing them. These rows are that composition, each one small
# enough to drop on a slider or a checkbox in an options screen.
#
# The four settings (effect strength, no flashing, text size scale, aim assist radius) are kept as
# metadata on Engine, which is plain Godot with no autoload to add and no plugin to depend on: any
# script, any behaviour pack and any shader driver can read them with one line, and a project that
# never sets one gets the default the reader asks for. Ticking Remember Between Runs on the sheet
# variables the sliders write is what makes them survive a restart.
#
# Captions ride a SIBLING of Play Sound rather than Play Sound itself: that row's emitted bytes are a
# compatibility promise, so adding a caption to it would rewrite every project's audio. Play Sound
# With Caption is the row that carries one, and Show Caption is the row for a sound played some other
# way.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeGameAccessibilityACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const OPTIONS := "Accessibility"

## The group a caption strip listens on. A plain group name so a HUD built any way at all can take
## part: add the strip to it, give the strip a `show_caption` method, done.
const CAPTION_GROUP := "\"caption_strip\""


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_remapping(descriptors)
	_holds_and_toggles(descriptors)
	_captions(descriptors)
	_effects(descriptors)
	_readability(descriptors)
	_assists(descriptors)
	_spoken(descriptors)
	return descriptors


## The remap flow, one action per row: say which control is being rebound, notice the next input,
## put it on. Saving and loading the result is the shipped Save Bindings / Load Bindings pair.
static func _remapping(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "StartListeningForControl", "Start Listening For", ACEDescriptor.ACEType.ACTION, "{listening} = {action}", "", [F.make_param("listening", "String", "listening_for", "Listening for", "The text variable that remembers which control is being rebound.", "variable_reference"), F.make_param("action", "String", F.default_input_action(), "Control", "The control the player is rebinding.", "input_action", F.input_action_options())], OPTIONS, "Start listening for {action}")
		.described("Marks a control as the one being rebound, so the next input the player gives belongs to it. The first row of a remap screen.").featured())
	descriptors.append(F.make_descriptor("Core", "AnyInputReceived", "Any Input Received", ACEDescriptor.ACEType.CONDITION, "(not {listening}.is_empty() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed())", "", [F.make_param("listening", "String", "listening_for", "Listening for", "The text variable that remembers which control is being rebound.", "variable_reference")], OPTIONS, "Any input received")
		.described("True on the next key, button or click after Start Listening For, used inside an input event - whatever the player pressed is what they want bound."))
	descriptors.append(F.make_descriptor("Core", "RebindControlTo", "Rebind Control To", ACEDescriptor.ACEType.ACTION, "InputMap.action_erase_events({action})\nInputMap.action_add_event({action}, {event})", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to rebind.", "input_action", F.input_action_options()), F.make_param("event", "String", "event", "Key or button", "The key or button the player just gave.", "expression")], OPTIONS, "Rebind {action} to {event}")
		.described("Takes the old bindings off a control and puts the new one on, in one row - the middle of a remap screen. Save Bindings afterwards to keep it.").featured())
	descriptors.append(F.make_descriptor("Core", "StopListeningForControl", "Stop Listening", ACEDescriptor.ACEType.ACTION, "{listening} = \"\"", "", [F.make_param("listening", "String", "listening_for", "Listening for", "The text variable that remembers which control is being rebound.", "variable_reference")], OPTIONS, "Stop listening")
		.described("Ends the rebind, so ordinary controls work again. Put it right after the Rebind row and on the Cancel button."))


## Hold-to-do becomes press-to-toggle, which is the single most requested accessibility option in
## any game with an aim button.
static func _holds_and_toggles(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "TreatControlAsToggle", "Treat Control As A Toggle", ACEDescriptor.ACEType.ACTION, "if {as_toggle}:\n\tif Input.is_action_just_pressed({action}):\n\t\t{held} = not {held}\nelse:\n\t{held} = Input.is_action_pressed({action})", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control that is held (or toggled).", "input_action", F.input_action_options()), F.make_param("held", "String", "aiming", "Held", "The yes-no variable every other row asks instead of the control.", "variable_reference"), F.make_param("as_toggle", "String", "hold_is_toggle", "Toggle setting", "The yes-no setting that switches hold for toggle.", "variable_reference")], OPTIONS, "Treat {action} as a toggle")
		.described("One row that makes a held control work either way: held down while the setting is off, pressed once on and once off while it is on. Every other row asks the yes-no variable, so nothing else changes.").featured())


## Captions. A sound with words on it is the difference between a game a deaf player can finish and
## one they cannot, and the caption is a plain string the HUD strip shows.
static func _captions(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "PlaySoundWithCaption", "Play Sound With Caption", ACEDescriptor.ACEType.ACTION, "\n".join(PackedStringArray([
		"var __sfx_{uid} = AudioStreamPlayer.new()",
		"__sfx_{uid}.stream = load({path})",
		"if __sfx_{uid}.stream == null:",
		"\t__sfx_{uid}.queue_free()",
		"else:",
		"\t__sfx_{uid}.bus = {bus}",
		"\t__sfx_{uid}.volume_db = {volume_db}",
		"\tadd_child(__sfx_{uid})",
		"\tset_meta(\"__last_sfx\", __sfx_{uid})",
		"\t__sfx_{uid}.finished.connect(__sfx_{uid}.queue_free)",
		"\t__sfx_{uid}.play()",
		"if not str({caption}).is_empty():",
		"\tget_tree().call_group(%s, \"show_caption\", {caption})" % CAPTION_GROUP
	])), "", [
		F.make_param("path", "String", "\"res://sound.ogg\"", "Sound", "Audio file to play once.", "audio_path"),
		F.make_param("caption", "String", "\"Distant explosion\"", "Caption", "What a player who cannot hear it needs to read. Leave blank for a sound that carries no information.", "expression"),
		F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression"),
		F.make_param("volume_db", "String", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression")
	], OPTIONS, "Play sound {path} with caption {caption}")
		.described("Plays a sound and shows its caption on the HUD caption strip. Blank caption means the sound carries no information and needs none.").featured())
	descriptors.append(F.make_descriptor("Core", "ShowCaption", "Show Caption", ACEDescriptor.ACEType.ACTION, "get_tree().call_group(%s, \"show_caption\", {caption})" % CAPTION_GROUP, "", [F.make_param("caption", "String", "\"Door opens\"", "Caption", "What to show on the caption strip.", "expression")], OPTIONS, "Show caption {caption}")
		.described("Puts one line on the caption strip, for a sound played some other way or for something that makes no sound at all."))


## Effect strength and flashing. The packs that shake and flash multiply the first in; the second
## substitutes a fade, because a strobe is a medical problem and not a taste.
static func _effects(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetEffectStrength", "Set Effect Strength", ACEDescriptor.ACEType.ACTION, "Engine.set_meta(\"effect_strength\", clampf({percent} / 100.0, 0.0, 1.0))", "", [F.make_param("percent", "String", "100", "Strength %", "0 for none, 100 for the full effect.", "expression")], OPTIONS, "Set effect strength to {percent}%")
		.described("One dial every shake, kick and flash multiplies itself by. A player who gets motion sick turns it to 0 and keeps the game.").featured())
	descriptors.append(F.make_descriptor("Core", "EffectStrength", "Effect Strength", ACEDescriptor.ACEType.EXPRESSION, "float(Engine.get_meta(\"effect_strength\", 1.0))", "", [], OPTIONS, "effect strength")
		.described("The effect dial as 0 to 1, 1 when nobody has set it - multiply a shake or a kick by it.").featured())
	descriptors.append(F.make_descriptor("Core", "SetNoFlashing", "Set No Flashing", ACEDescriptor.ACEType.ACTION, "Engine.set_meta(\"no_flashing\", {on})", "", [F.make_param("on", "String", "true", "No flashing", "true to replace every flash with a fade.", "", ["true", "false"])], OPTIONS, "Set no flashing to {on}")
		.described("Turns every flash into a fade for players with photosensitive epilepsy. Ask it before a flash row and fade instead.").featured())
	descriptors.append(F.make_descriptor("Core", "NoFlashing", "No Flashing", ACEDescriptor.ACEType.CONDITION, "bool(Engine.get_meta(\"no_flashing\", false))", "", [], OPTIONS, "No flashing")
		.described("True while the player has asked for no flashing - guard a strobe with it and fade in the other branch.").featured())


## Readability: text that scales, and colours a colour-blind player can tell apart.
static func _readability(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetTextSizeScale", "Set Text Size Scale", ACEDescriptor.ACEType.ACTION, "Engine.set_meta(\"text_size_scale\", maxf({scale}, 0.1))", "", [F.make_param("scale", "String", "1.0", "Scale", "1 is the size you designed, 1.5 is half again as big.", "expression")], OPTIONS, "Set text size scale to {scale}")
		.described("One number every text size multiplies by, so a whole game's text grows together instead of one label at a time.").featured())
	descriptors.append(F.make_descriptor("Core", "TextSizeScale", "Text Size Scale", ACEDescriptor.ACEType.EXPRESSION, "float(Engine.get_meta(\"text_size_scale\", 1.0))", "", [], OPTIONS, "text size scale")
		.described("The text dial, 1 when nobody has set it - multiply a Set Font Size by it.").featured())
	descriptors.append(F.make_descriptor("Core", "UsePalette", "Use Palette", ACEDescriptor.ACEType.ACTION, "{palette} = load({path})", "", [F.make_param("palette", "String", "palette", "Palette", "The variable holding the palette in use.", "variable_reference"), F.make_param("path", "String", "\"res://palettes/default.tres\"", "Palette asset", "The palette data asset to swap in.", "resource_path")], OPTIONS, "Use palette {path}")
		.described("Swaps the colour set the game draws with, so a colour-blind player can pick one they can tell apart. Keep each palette as a data asset and show the swatches beside the name."))


## Assists: the aim help that turns a twitch test into a game somebody with a tremor can play.
static func _assists(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SetAimAssistRadius", "Set Aim Assist Radius", ACEDescriptor.ACEType.ACTION, "Engine.set_meta(\"aim_assist_radius\", maxf({radius}, 0.0))", "", [F.make_param("radius", "String", "0.0", "Radius", "How far from dead centre a target still counts. 0 is no help.", "expression")], OPTIONS, "Set aim assist radius to {radius}")
		.described("How generous the aim is, as a player setting rather than a designer's guess - the pick radius a shot searches within.").featured())
	descriptors.append(F.make_descriptor("Core", "AimAssistRadius", "Aim Assist Radius", ACEDescriptor.ACEType.EXPRESSION, "float(Engine.get_meta(\"aim_assist_radius\", 0.0))", "", [], OPTIONS, "aim assist radius")
		.described("The aim-help dial, 0 when nobody has set it - hand it to the row that picks the nearest target."))


## Spoken text, for a player who cannot read the screen. Godot speaks through the operating system,
## so there is nothing to ship and nothing to license.
static func _spoken(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SpeakText", "Speak", ACEDescriptor.ACEType.ACTION, "var __voices_{uid} = DisplayServer.tts_get_voices_for_language(OS.get_locale_language())\nif not __voices_{uid}.is_empty():\n\tDisplayServer.tts_speak({text}, __voices_{uid}[0])", "", [F.make_param("text", "String", "\"Health low\"", "Text", "What to say out loud.", "expression")], OPTIONS, "Speak {text}")
		.described("Reads a line out loud in the player's own language, using the voices their system already has. Does nothing where there is no voice, so it is safe to leave in.").featured())
	descriptors.append(F.make_descriptor("Core", "StopSpeaking", "Stop Speaking", ACEDescriptor.ACEType.ACTION, "DisplayServer.tts_stop()", "", [], OPTIONS, "Stop speaking")
		.described("Cuts off whatever is being spoken - put it before the next Speak so two lines never talk over each other."))


static func section_descriptions() -> Dictionary:
	return {
		OPTIONS: "The options screen a player needs: remapping, toggles instead of holds, captions, weaker effects, bigger text, aim help and spoken text.",
	}
