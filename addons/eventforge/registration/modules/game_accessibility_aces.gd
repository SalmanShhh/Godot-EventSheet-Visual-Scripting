# EventForge module - Accessibility for the GAME: the options every project should be one row
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
	descriptors.append(F.act("StartListeningForControl", "Start Listening For", "{listening} = {action}", OPTIONS, "Start listening for {action}", "Marks a control as the one being rebound, so the next input the player gives belongs to it. The first row of a remap screen.").param("listening", "listening_for", "Listening for", "The text variable that remembers which control is being rebound.", "variable_reference").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control the player is rebinding.", "input_action", F.input_action_options())).featured())
	descriptors.append(F.cond("AnyInputReceived", "Any Input Received", "(not {listening}.is_empty() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed())", OPTIONS, "Any input received", "True on the next key, button or click after Start Listening For, used inside an input event - whatever the player pressed is what they want bound.").param("listening", "listening_for", "Listening for", "The text variable that remembers which control is being rebound.", "variable_reference"))
	descriptors.append(F.act("RebindControlTo", "Rebind Control To", "InputMap.action_erase_events({action})\nInputMap.action_add_event({action}, {event})", OPTIONS, "Rebind {action} to {event}", "Takes the old bindings off a control and puts the new one on, in one row - the middle of a remap screen. Save Bindings afterwards to keep it.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to rebind.", "input_action", F.input_action_options())).param("event", "event", "Key or button", "The key or button the player just gave.", "expression").featured())
	descriptors.append(F.act("StopListeningForControl", "Stop Listening", "{listening} = \"\"", OPTIONS, "Stop listening", "Ends the rebind, so ordinary controls work again. Put it right after the Rebind row and on the Cancel button.").param("listening", "listening_for", "Listening for", "The text variable that remembers which control is being rebound.", "variable_reference"))


## Hold-to-do becomes press-to-toggle, which is the single most requested accessibility option in
## any game with an aim button.
static func _holds_and_toggles(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("TreatControlAsToggle", "Treat Control As A Toggle", "if {as_toggle}:\n\tif Input.is_action_just_pressed({action}):\n\t\t{held} = not {held}\nelse:\n\t{held} = Input.is_action_pressed({action})", OPTIONS, "Treat {action} as a toggle", "One row that makes a held control work either way: held down while the setting is off, pressed once on and once off while it is on. Every other row asks the yes-no variable, so nothing else changes.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control that is held (or toggled).", "input_action", F.input_action_options())).param("held", "aiming", "Held", "The yes-no variable every other row asks instead of the control.", "variable_reference").param("as_toggle", "hold_is_toggle", "Toggle setting", "The yes-no setting that switches hold for toggle.", "variable_reference").featured())


## Captions. A sound with words on it is the difference between a game a deaf player can finish and
## one they cannot, and the caption is a plain string the HUD strip shows.
static func _captions(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("PlaySoundWithCaption", "Play Sound With Caption", "\n".join(PackedStringArray([ "var __sfx_{uid} = AudioStreamPlayer.new()", "__sfx_{uid}.stream = load({path})", "if __sfx_{uid}.stream == null:", "\t__sfx_{uid}.queue_free()", "else:", "\t__sfx_{uid}.bus = {bus}", "\t__sfx_{uid}.volume_db = {volume_db}", "\tadd_child(__sfx_{uid})", "\tset_meta(\"__last_sfx\", __sfx_{uid})", "\t__sfx_{uid}.finished.connect(__sfx_{uid}.queue_free)", "\t__sfx_{uid}.play()", "if not str({caption}).is_empty():", "\tget_tree().call_group(%s, \"show_caption\", {caption})" % CAPTION_GROUP ])), OPTIONS, "Play sound {path} with caption {caption}", "Plays a sound and shows its caption on the HUD caption strip. Blank caption means the sound carries no information and needs none.").param("path", "\"res://sound.ogg\"", "Sound", "Audio file to play once.", "audio_path").param("caption", "\"Distant explosion\"", "Caption", "What a player who cannot hear it needs to read. Leave blank for a sound that carries no information.", "expression").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression").param("volume_db", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression").featured())
	descriptors.append(F.act("ShowCaption", "Show Caption", "get_tree().call_group(%s, \"show_caption\", {caption})" % CAPTION_GROUP, OPTIONS, "Show caption {caption}", "Puts one line on the caption strip, for a sound played some other way or for something that makes no sound at all.").param("caption", "\"Door opens\"", "Caption", "What to show on the caption strip.", "expression"))


## Effect strength and flashing. The packs that shake and flash multiply the first in; the second
## substitutes a fade, because a strobe is a medical problem and not a taste.
static func _effects(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("SetEffectStrength", "Set Effect Strength", "Engine.set_meta(\"effect_strength\", clampf({percent} / 100.0, 0.0, 1.0))", OPTIONS, "Set effect strength to {percent}%", "One dial every shake, kick and flash multiplies itself by. A player who gets motion sick turns it to 0 and keeps the game.").param("percent", "100", "Strength %", "0 for none, 100 for the full effect.", "expression").featured())
	descriptors.append(F.expr("EffectStrength", "Effect Strength", "float(Engine.get_meta(\"effect_strength\", 1.0))", OPTIONS, "effect strength", "The effect dial as 0 to 1, 1 when nobody has set it - multiply a shake or a kick by it.").featured())
	descriptors.append(F.act("SetNoFlashing", "Set No Flashing", "Engine.set_meta(\"no_flashing\", {on})", OPTIONS, "Set no flashing to {on}", "Turns every flash into a fade for players with photosensitive epilepsy. Ask it before a flash row and fade instead.").param_choice("on", "true", "No flashing", "true to replace every flash with a fade.", ["true", "false"]).featured())
	descriptors.append(F.cond("NoFlashing", "No Flashing", "bool(Engine.get_meta(\"no_flashing\", false))", OPTIONS, "No flashing", "True while the player has asked for no flashing - guard a strobe with it and fade in the other branch.").featured())


## Readability: text that scales, and colours a colour-blind player can tell apart.
static func _readability(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("SetTextSizeScale", "Set Text Size Scale", "Engine.set_meta(\"text_size_scale\", maxf({scale}, 0.1))", OPTIONS, "Set text size scale to {scale}", "One number every text size multiplies by, so a whole game's text grows together instead of one label at a time.").param("scale", "1.0", "Scale", "1 is the size you designed, 1.5 is half again as big.", "expression").featured())
	descriptors.append(F.expr("TextSizeScale", "Text Size Scale", "float(Engine.get_meta(\"text_size_scale\", 1.0))", OPTIONS, "text size scale", "The text dial, 1 when nobody has set it - multiply a Set Font Size by it.").featured())
	descriptors.append(F.act("UsePalette", "Use Palette", "{palette} = load({path})", OPTIONS, "Use palette {path}", "Swaps the colour set the game draws with, so a colour-blind player can pick one they can tell apart. Keep each palette as a data asset and show the swatches beside the name.").param("palette", "palette", "Palette", "The variable holding the palette in use.", "variable_reference").param("path", "\"res://palettes/default.tres\"", "Palette asset", "The palette data asset to swap in.", "palette"))


## Assists: the aim help that turns a twitch test into a game somebody with a tremor can play.
static func _assists(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("SetAimAssistRadius", "Set Aim Assist Radius", "Engine.set_meta(\"aim_assist_radius\", maxf({radius}, 0.0))", OPTIONS, "Set aim assist radius to {radius}", "How generous the aim is, as a player setting rather than a designer's guess - the pick radius a shot searches within.").param("radius", "0.0", "Radius", "How far from dead centre a target still counts. 0 is no help.", "expression").featured())
	descriptors.append(F.expr("AimAssistRadius", "Aim Assist Radius", "float(Engine.get_meta(\"aim_assist_radius\", 0.0))", OPTIONS, "aim assist radius", "The aim-help dial, 0 when nobody has set it - hand it to the row that picks the nearest target."))


## Spoken text, for a player who cannot read the screen. Godot speaks through the operating system,
## so there is nothing to ship and nothing to license.
static func _spoken(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("SpeakText", "Speak", "var __voices_{uid} = DisplayServer.tts_get_voices_for_language(OS.get_locale_language())\nif not __voices_{uid}.is_empty():\n\tDisplayServer.tts_speak({text}, __voices_{uid}[0])", OPTIONS, "Speak {text}", "Reads a line out loud in the player's own language, using the voices their system already has. Does nothing where there is no voice, so it is safe to leave in.").param("text", "\"Health low\"", "Text", "What to say out loud.", "expression").featured())
	descriptors.append(F.act("StopSpeaking", "Stop Speaking", "DisplayServer.tts_stop()", OPTIONS, "Stop speaking", "Cuts off whatever is being spoken - put it before the next Speak so two lines never talk over each other."))


static func section_descriptions() -> Dictionary:
	return {
		OPTIONS: "The options screen a player needs: remapping, toggles instead of holds, captions, weaker effects, bigger text, aim help and spoken text.",
	}
