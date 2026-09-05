## @ace_version(1.0.0)
class_name EventForgeHaptics
extends RefCounted
## What a hit feels like in the hand - the pattern, the emphasis and the continuous rumble the Haptic, Haptic Emphasis and Haptic Continuous rows call.

# WHAT A HIT FEELS LIKE IN THE HAND.
#
# The vibration rows beside these are the device's own two calls said out loud: buzz the phone for
# this many milliseconds, rumble the pad's two motors at these two strengths. That is the machine's
# vocabulary, not a game's. A game's is "this is a tap", "this is an alarm", "the car is on gravel" -
# a SHAPE, played on whatever the player is holding, at the strength they asked for.
#
# ONE ROW, EITHER DEVICE. A pad gets its motors; a phone with no pad gets a buzz as long as the
# shape; a desktop with neither does nothing at all, quietly, because a machine that cannot rumble is
# not a fault to report every time somebody is hit. THE WEB is the same silence for a different
# reason - a page has no motors to reach - and neither of them warns, ever. The Doctor says it once,
# on the way to shipping, which is where a sentence about the whole project belongs.
#
# THE PLAYER'S OWN DIAL. Every amplitude is multiplied by the haptic strength setting before it
# reaches a device, and 0 means off - one number, read the same way the flashing and effect-strength
# dials are read, so a player who cannot bear the rumble turns it off once and keeps the game. No
# Flashing does not touch it: a rumble is not light.
#
# THE SHAPE IS A FILE the project owns (HapticPatternResource): how hard, how long, how many times,
# and the air between. Nothing ships - there is no house "success" and no house "failure", because
# how a game feels in the hand is the game's.
#
# PLAIN GDSCRIPT, AND NOT THE PLUGIN'S. Nothing here touches an editor, a sheet or any class the
# plugin declares, and this file ships in the project's OWN folder, so a sheet holding one of these
# rows goes on parsing and running after the editor is gone.
#
# THE COST. A pattern is one Tween of callbacks - one call per pulse, never per frame - which the
# engine parks and frees the moment the last pulse lands. A continuous rumble is ONE call at the
# start and one at the stop, not a call a frame. At rest the whole file costs nothing.

## The player's own dial, spelled the same way the other accessibility dials are: a number on the
## Engine, 1 until somebody sets it, 0 for off.
const STRENGTH_META: StringName = &"haptic_strength"

## What is in the hand right now - the moment the last pulse of a pattern ends, and whether a
## continuous rumble is running. Both on the Engine, because the answer outlives the scene that
## started it.
const UNTIL_META: StringName = &"eventforge_haptics_until"
const CONTINUOUS_META: StringName = &"eventforge_haptics_continuous"

## How long an emphasis is: the shortest pulse a hand reads as a single knock rather than a buzz.
## A fact about hands rather than a taste, which is why it is a number here and not a field.
const EMPHASIS_SECONDS: float = 0.05

## The platforms with nothing to rumble. A page has no motors, and reaching for them there is a
## silence rather than a failure.
const SILENT_PLATFORMS: PackedStringArray = ["Web"]


## Plays one pattern on whatever the player is holding. A pattern of several pulses is played as one
## call per pulse, scheduled on `host`; with no host to schedule on, the first pulse is played and
## the rest are not, which is the honest answer rather than a promise nothing would keep.
static func play(host: Node, pattern: Variant) -> void:
	var shape_of: HapticPatternResource = pattern_of(pattern)
	if shape_of == null or is_silent():
		return
	var amount: float = scaled(shape_of.amplitude)
	if amount <= 0.0:
		return
	var shape: Array[Dictionary] = phases(shape_of)
	if shape.is_empty():
		return
	_felt_until(Time.get_ticks_msec() + int(shape_of.length() * 1000.0))
	_pulse(amount, float(shape[0]["seconds"]))
	if shape.size() == 1 or host == null or not host.is_inside_tree():
		return
	var tween: Tween = host.create_tween()
	tween.set_parallel(true)
	for index: int in range(1, shape.size()):
		var phase: Dictionary = shape[index]
		var seconds: float = float(phase["seconds"])
		tween.tween_callback(func() -> void: _pulse(amount, seconds)).set_delay(float(phase["at"]))


## One short strong knock, with no file behind it - the punctuation mark of the vocabulary: a menu
## item landing, a lock clicking home, a step of a countdown.
static func emphasis(strength: float = 1.0) -> void:
	if is_silent():
		return
	var amount: float = scaled(strength)
	if amount <= 0.0:
		return
	_felt_until(Time.get_ticks_msec() + int(EMPHASIS_SECONDS * 1000.0))
	_pulse(amount, EMPHASIS_SECONDS)


## Starts a rumble that runs until it is stopped, at an amplitude that can be written again to change
## it - the car on gravel, the drill in the wall, the engine under the seat. ONE call at the start,
## not one a frame.
static func continuous_start(amplitude: float) -> void:
	if is_silent():
		return
	var amount: float = scaled(amplitude)
	if amount <= 0.0:
		continuous_stop()
		return
	Engine.set_meta(CONTINUOUS_META, true)
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, amount, amount, 0.0)


## And stops it. Safe to run when nothing is running, which is what lets it sit on the row that ends
## a state without a condition in front of it.
static func continuous_stop() -> void:
	Engine.set_meta(CONTINUOUS_META, false)
	for device: int in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)


## True while a pattern's pulses are still arriving, or a continuous rumble is running.
static func is_playing() -> bool:
	if bool(Engine.get_meta(CONTINUOUS_META, false)):
		return true
	return Time.get_ticks_msec() < int(Engine.get_meta(UNTIL_META, 0))


## True when this machine can be felt at all: a pad plugged in, or a phone in a hand. A desktop with
## no pad answers false, and every row above it does nothing quietly rather than warning per hit.
static func can_be_felt() -> bool:
	if is_silent():
		return false
	return not Input.get_connected_joypads().is_empty() or OS.has_feature("mobile")


## Whether this platform has nothing to rumble at all.
static func is_silent() -> bool:
	return silent_on(OS.get_name())


## The same question of a NAMED platform, so it can be asked without being on one.
static func silent_on(os_name: String) -> bool:
	return SILENT_PLATFORMS.has(os_name)


## What one amplitude really becomes: the player's dial applied, and never outside 0 to 1. ONE
## function, so no row can be the one that forgot.
static func scaled(amplitude: float) -> float:
	return clampf(amplitude * maxf(float(Engine.get_meta(STRENGTH_META, 1.0)), 0.0), 0.0, 1.0)


## A pattern as the pulses it really is: when each one starts, measured from the start of the shape,
## and how long it lasts. Pure arithmetic, which is what lets the shape be pinned without a device, a
## tree or a frame.
static func phases(pattern: HapticPatternResource) -> Array[Dictionary]:
	var shape: Array[Dictionary] = []
	if pattern == null:
		return shape
	var seconds: float = maxf(pattern.seconds, 0.0)
	var gap: float = maxf(pattern.gap_seconds, 0.0)
	for index: int in maxi(pattern.repeats, 1):
		shape.append({"at": index * (seconds + gap), "seconds": seconds})
	return shape


## The pattern a row means, from either of the two things a row can hand over: the file itself, as a
## step or a piece of code passes it, or the path to it, as a row picked in the editor writes it. A
## path to something that is not a haptic pattern answers nothing rather than guessing.
static func pattern_of(pattern: Variant) -> HapticPatternResource:
	if pattern is HapticPatternResource:
		return pattern as HapticPatternResource
	var path: String = str(pattern).strip_edges()
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as HapticPatternResource


## One pulse, on whatever is there: every pad that is plugged in, and the phone when there is no pad.
static func _pulse(amount: float, seconds: float) -> void:
	var pads: Array[int] = Input.get_connected_joypads()
	for device: int in pads:
		Input.start_joy_vibration(device, amount, amount, seconds)
	if pads.is_empty():
		Input.vibrate_handheld(int(maxf(seconds, 0.0) * 1000.0), amount)


## Writes down when the hand stops being busy, keeping the later of what is already written and what
## this play asks for - two patterns at once end when the longer one does.
static func _felt_until(at_msec: int) -> void:
	Engine.set_meta(UNTIL_META, maxi(int(Engine.get_meta(UNTIL_META, 0)), at_msec))
