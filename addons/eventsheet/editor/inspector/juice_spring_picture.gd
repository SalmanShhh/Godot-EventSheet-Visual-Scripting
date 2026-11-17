# Godot EventSheets - the little picture of the bounce a Spring card makes.
#
# A Spring card kicks a value and lets the Spring node bring it back to rest. How it comes back is
# two numbers (how much speed is lost each second, and how many swings a second the spring wants),
# and a newcomer cannot tell what 0.85 and 2.075 look like. This draws it: left is the kick, right is
# the value arriving back at rest, the line through the middle is rest, and a bar above it is the
# value past rest on the kicked side, a bar under it is the value swung past rest the other way.
#
# The bounce is worked out with the same step the Spring node takes every frame (a force toward rest,
# then the speed that is lost each second), so the picture and the game agree. This file is path-loaded
# by the card schema and is not part of the editor's first open.
@tool
extends RefCounted

## How many bars the bounce is drawn with.
const BARS: int = 24

## The family the card is in, for the colour of the bars (Object).
const BAR_COLOUR: Color = Color("#4C8DF0")

## The Spring node's own numbers, as it keeps them: a card that stores neither reads these.
const DEFAULT_DAMPING: float = 0.85
const DEFAULT_FREQUENCY: float = 2.075

## The most speed a second a spring can lose, as the Spring node holds it.
const DAMPING_CEILING: float = 0.999

## The step the bounce is worked out with, a hundred and twentieth of a second.
const STEP: float = 1.0 / 120.0

## The shortest and longest stretch of time the picture covers, in seconds.
const SHORTEST: float = 0.4
const LONGEST: float = 3.0

## What a bar may be, as a share of the kick, before it counts as at rest.
const AT_REST: float = 0.03


## The value of the spring over its whole bounce, one number per bar, in units of the first swing a spring with no
## loss would make (so a loose spring reaches about 1 and a heavy one much less). Bar 0 is just after the kick.
static func samples(damping: float, frequency: float, count: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	if count <= 0:
		return out
	var span: float = span_of(damping, frequency)
	var track: PackedFloat32Array = _track(damping, frequency, span)
	for bar: int in range(count):
		var at: float = (float(bar) + 0.5) / float(count)
		out.append(track[clampi(int(at * float(track.size())), 0, track.size() - 1)])
	return out


## How long the picture covers: until the bounce is a sliver of the kick, never under a short moment and never over
## three seconds.
static func span_of(damping: float, frequency: float) -> float:
	var full: PackedFloat32Array = _track(damping, frequency, LONGEST)
	var last: int = 0
	for index: int in range(full.size()):
		if absf(full[index]) > AT_REST:
			last = index
	return clampf(float(last + 1) * STEP * 1.1, SHORTEST, LONGEST)


## How many times the value passes through rest on its way back.
static func swings(damping: float, frequency: float) -> int:
	var track: PackedFloat32Array = _track(damping, frequency, span_of(damping, frequency))
	var crossed: int = 0
	for index: int in range(1, track.size()):
		if track[index - 1] * track[index] < 0.0:
			crossed += 1
	return crossed


## The kick answered a step at a time, in units of the first swing of a spring with no loss.
static func _track(damping: float, frequency: float, span: float) -> PackedFloat32Array:
	var omega: float = maxf(frequency, 0.01) * TAU
	var stiffness: float = omega * omega
	var decay: float = pow(1.0 - clampf(damping, 0.0, DAMPING_CEILING), STEP)
	var value: float = 0.0
	var speed: float = 1.0
	var out: PackedFloat32Array = PackedFloat32Array()
	for step: int in range(int(span / STEP)):
		speed += (0.0 - value) * stiffness * STEP
		speed *= decay
		value += speed * STEP
		out.append(value * omega)
	if out.is_empty():
		out.append(0.0)
	return out


## The numbers a card holds, or the Spring node's own where it holds none.
static func _damping_of(card: Dictionary) -> float:
	return float(card.get("damping", DEFAULT_DAMPING))


static func _frequency_of(card: Dictionary) -> float:
	return float(card.get("frequency", DEFAULT_FREQUENCY))


## One grey sentence under the picture: how many times it swings past rest and how long it takes to settle.
static func says(card: Dictionary) -> String:
	var damping: float = _damping_of(card)
	var frequency: float = _frequency_of(card)
	var seconds: String = str(snappedf(span_of(damping, frequency) / 1.1, 0.1))
	var crossed: int = swings(damping, frequency)
	if crossed == 0:
		return EventSheetL10n.translate("Comes back to rest without swinging past it, in about %s s.") % seconds
	if crossed == 1:
		return EventSheetL10n.translate("Swings past rest once and settles in about %s s.") % seconds
	return EventSheetL10n.translate("Swings past rest %d times and settles in about %s s.") % [crossed, seconds]


## The drawing and the sentence under it. It follows the card's two numbers as they are edited.
static func shape_strip(card: Dictionary, _now: Callable, _edited: Object) -> Control:
	var box: PictureBox = PictureBox.new()
	box.setup(card)
	return box


class PictureBox:
	extends VBoxContainer

	var strip: Strip = null
	var note: Label = null

	func setup(bounced: Dictionary) -> void:
		strip = Strip.new()
		strip.card = bounced
		strip.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled(40))
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(strip)
		note = Label.new()
		note.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		note.modulate = Color(1.0, 1.0, 1.0, 0.6)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var words: Script = load("res://addons/eventsheet/editor/inspector/juice_spring_picture.gd") as Script
		note.text = str(words.call("says", bounced))
		add_child(note)


## The bars, up from the line of rest for the kicked side and down from it for the swing past.
class Strip:
	extends Control

	var card: Dictionary = {}

	func _draw() -> void:
		var words: Script = load("res://addons/eventsheet/editor/inspector/juice_spring_picture.gd") as Script
		var bars: int = int(words.get_script_constant_map()["BARS"])
		var colour: Color = words.get_script_constant_map()["BAR_COLOUR"]
		var gap: float = 3.0
		var width: float = (size.x - gap * float(bars - 1)) / float(bars)
		if width <= 0.0:
			return
		var heights: PackedFloat32Array = words.call("samples", float(card.get("damping", words.get_script_constant_map()["DEFAULT_DAMPING"])),
			float(card.get("frequency", words.get_script_constant_map()["DEFAULT_FREQUENCY"])), bars)
		var middle: float = size.y * 0.5
		var reach: float = size.y * 0.5 - 1.0
		draw_line(Vector2(0.0, middle), Vector2(size.x, middle), Color(colour.r, colour.g, colour.b, 0.35), 1.0)
		for bar: int in range(bars):
			var level: float = clampf(heights[bar], -1.0, 1.0) * reach
			var top: float = middle - maxf(level, 0.0)
			var height: float = maxf(absf(level), 1.0)
			draw_rect(Rect2(float(bar) * (width + gap), top if level >= 0.0 else middle, width, height), colour)
