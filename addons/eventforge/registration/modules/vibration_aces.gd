# EventForge module - Vibration vocabulary (rumble a gamepad, buzz a phone).
#
# Two halves, and the second is the one a game reaches for.
#
# THE DEVICE'S OWN WORDS come first: stop a gamepad rumble, buzz a handheld for a number of
# milliseconds, read the strength a pad is running at. They compile to plain Godot (Input) with zero
# plugin references, and they are the right rows when the game knows exactly which motor it means.
#
# THE HAND'S WORDS come after. A game does not think in motor strengths; it thinks in shapes - this
# is a tap, this is an alarm, the car is on gravel. A shape is a HapticPatternResource the project
# owns (how hard, how long, how many times, and the air between), and ONE row plays it on whatever
# the player is holding: a pad gets its motors, a phone with no pad gets a buzz as long as the shape,
# and a desktop with neither does nothing at all - quietly, because a machine that cannot rumble is
# not a fault to report every time somebody is hit. A page in a browser is the same silence. Nothing
# ships: there is no house "success" and no house "failure", because how a game feels in the hand is
# the game's.
#
# The work itself is a real file a debugger can step into: `EventForgeHaptics`, at
# `eventsheet_addons/haptics.gd`, plain typed GDScript with no plugin class named anywhere in it,
# exactly like the free-spot and world-look helpers the spawn and environment rows call. It ships in
# the project's OWN folder rather than in the plugin's, because `addons/` is what an uninstall
# deletes and a sheet holding one of these rows has to go on parsing after the editor is gone.
#
# Grouped under "Vibration". Module contract: see ace_factory.gd - ace_ids/templates are API.
@tool
class_name EventForgeVibrationACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Vibration"

## The runtime the shape rows call, named once and frozen with the templates that spell it.
const HAPTICS_CALL: String = "EventForgeHaptics"

## The player's own dial, spelled here exactly as the runtime and the other accessibility dials
## spell it - one number on the Engine, 1 until somebody sets it, 0 for off.
const STRENGTH_META: String = "\"haptic_strength\""


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── The device's own words ──
	descriptors.append(F.act("VibrationStopJoy", "Stop Gamepad Vibration", "Input.stop_joy_vibration({device})", CAT, "stop vibration on gamepad {device}", "Stops a gamepad rumble that is still running.").param_typed("int", "device", "0", "Device", "Gamepad number (0 = the first controller).", "expression"))
	descriptors.append(F.act("VibrationHandheld", "Vibrate Phone", "Input.vibrate_handheld({duration_ms})", CAT, "vibrate phone for {duration_ms}ms", "Buzzes a handheld device (phone / tablet) for a moment. Does nothing on desktop.").param_typed("int", "duration_ms", "200", "Duration (ms)", "How long to buzz, in milliseconds.", "expression"))
	descriptors.append(F.expr("VibrationJoyStrength", "Gamepad Vibration Strength", "Input.get_joy_vibration_strength({device})", CAT, "gamepad {device} vibration strength", "The current rumble strength of a gamepad as a Vector2 (weak, strong motor).").param_typed("int", "device", "0", "Device", "Gamepad number (0 = the first controller).", "expression"))

	# ── The hand's words: a shape, played on whatever the player is holding ──
	descriptors.append(F.act("HapticPlay", "Haptic", "%s.play(self, {pattern})" % HAPTICS_CALL, CAT, "haptic {pattern}", "Plays one haptic shape - a file you own saying how hard, how long, how many times, and the air between the pulses. A pad gets its motors, a phone with no pad gets a buzz as long as the shape, and a machine with neither does nothing at all, quietly. Every amplitude is scaled by the player's own haptic strength first, so a player who cannot bear the rumble turns it off once and keeps the game. Nothing ships: a new haptic pattern opens on a single short tap, and every other shape is made from there.").param("pattern", "\"\"", "Pattern", "The haptic pattern file to play.", "resource_path").featured())
	descriptors.append(F.act("HapticEmphasis", "Haptic Emphasis", "%s.emphasis({strength})" % HAPTICS_CALL, CAT, "haptic emphasis at {strength}", "One short strong knock, with no file behind it - the punctuation mark of the vocabulary: a menu item landing, a lock clicking home, a step of a countdown. The player's haptic strength scales it like everything else.").param_typed("float", "strength", "1.0", "Strength", "How hard the knock is, from 0 to 1.", "expression").featured())
	descriptors.append(F.act("HapticContinuousStart", "Haptic Continuous Start", "%s.continuous_start({amplitude})" % HAPTICS_CALL, CAT, "haptic continuous at {amplitude}", "Starts a rumble that runs until it is stopped - the car on gravel, the drill in the wall, the engine under the seat. Run it again with a different amplitude to change it while it runs; it is ONE call each time, never a call a frame.").param_typed("float", "amplitude", "0.5", "Amplitude", "How hard, from 0 to 1. 0 stops it.", "expression"))
	descriptors.append(F.act("HapticContinuousStop", "Haptic Continuous Stop", "%s.continuous_stop()" % HAPTICS_CALL, CAT, "stop the continuous haptic", "Stops a continuous rumble. Safe to run when nothing is running, which is what lets it sit on the row that ends a state without a condition in front of it."))
	descriptors.append(F.act("SetHapticStrength", "Set Haptic Strength", "Engine.set_meta(%s, clampf({percent} / 100.0, 0.0, 1.0))" % STRENGTH_META, CAT, "set haptic strength to {percent}%", "One dial every haptic row multiplies itself by, as a player setting rather than a designer's guess. 0 is off and the rows go quiet without a branch anywhere in the sheet. No Flashing does not touch it - a rumble is not light.").param("percent", "100", "Strength %", "0 for none, 100 for the shape as it was made.", "expression").featured())
	descriptors.append(F.expr("HapticStrength", "Haptic Strength", "float(Engine.get_meta(%s, 1.0))" % STRENGTH_META, CAT, "haptic strength", "The haptic dial as 0 to 1, 1 when nobody has set it - what the options screen's slider reads to know where to start."))
	descriptors.append(F.cond("HapticIsPlaying", "Haptic Is Playing", "%s.is_playing()" % HAPTICS_CALL, CAT, "a haptic is playing", "True while a pattern's pulses are still arriving, or a continuous rumble is running - the guard that stops a second shape being laid over the first."))
	descriptors.append(F.cond("HapticsCanBeFelt", "Haptics Can Be Felt", "%s.can_be_felt()" % HAPTICS_CALL, CAT, "haptics can be felt", "True when this machine can rumble at all: a pad plugged in, or a phone in a hand. The rows above do nothing quietly where it is false, so this is for the options screen that wants to grey the slider out rather than for guarding every hit."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Rumble a gamepad or buzz a phone, and stop it again - and above those, the haptic shapes a game actually thinks in: a tap, an alarm, a continuous rumble, all scaled by the player's own dial."}
