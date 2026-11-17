# Godot EventSheets - the little picture of the split a Chromatic Shake card makes.
#
# A Chromatic Shake card slides the red, the green and the blue of the screen apart along a direction, by an
# amount in pixels. A newcomer cannot tell what 12 pixels or 90 degrees look like, so this draws it: a white
# shape on a dark screen, drawn three times in red, green and blue and added together, the three moved along the
# chosen direction at the chosen amount the way the screen does it. Where all three meet the shape stays white, and
# the fringes are the colours coming apart. A card whose direction wanders draws the same split pointing one way
# and a ring of small dots round it, the places it may point.
#
# This file is path-loaded by the card schema and is not part of the editor's first open.
@tool
extends RefCounted

## The Juice node's own numbers for the row, as a card that stores none of them reads them.
const DEFAULT_AMOUNT: float = 12.0
const DEFAULT_SECONDS: float = 0.3

## How many picture pixels a step is for each pixel of the card's amount: a pixel of the screen is a pixel of the picture.
const PICTURE_SCALE: float = 1.0

## Where each colour of a shape lands, in steps of the amount, as the Juice node reads the screen: red and green a step
## apart, and blue four steps on the red side. The furthest any mark is from the middle of the three is WIDEST steps.
const RED_AT: float = -1.0
const GREEN_AT: float = 1.0
const BLUE_AT: float = -4.0
const WIDEST: float = 8.0 / 3.0

## The way a wandering split is drawn: a quarter of the way round, so the three marks are seen apart.
const WANDER_PICTURE_ANGLE: float = 35.0

## The screen the shape is drawn on, the same in both themes because a screen is dark whichever theme the editor wears.
const SCREEN_COLOUR: Color = Color("#17181c")

## The shape's three channels, which add up to white.
const CHANNELS: PackedColorArray = [Color("#ff2a2a"), Color("#2aff2a"), Color("#2a2aff")]


## The three marks of the picture as offsets from the middle of the group, in picture pixels, for a card drawn within
## `extent` pixels of the middle: {red, green, blue, wander}. They sit where the Juice node puts the three colours of a
## shape: red a step one way, green a step the other, and blue four steps beyond red, a step being the card's amount.
static func marks(card: Dictionary, extent: float) -> Dictionary:
	var amount: float = maxf(float(card.get("amount", DEFAULT_AMOUNT)), 0.0)
	var wander: bool = str(card.get("direction", "wander")) != "angle"
	var angle: float = WANDER_PICTURE_ANGLE if wander else float(card.get("angle", 0.0))
	var step: Vector2 = Vector2.from_angle(deg_to_rad(angle)) * minf(amount * PICTURE_SCALE, maxf(extent, 0.0) / WIDEST)
	var middle: Vector2 = step * (RED_AT + GREEN_AT + BLUE_AT) / 3.0
	return {"red": step * RED_AT - middle, "green": step * GREEN_AT - middle, "blue": step * BLUE_AT - middle, "wander": wander}


## One number as a person writes it: no trailing ".0", and no more than two places.
static func _plain(value: float) -> String:
	var spelled: String = String.num(snappedf(value, 0.01), 2)
	if spelled.contains("."):
		spelled = spelled.rstrip("0").rstrip(".")
	return spelled


## The one grey sentence under the picture: how far the colours part, which way, and when they are back together.
static func says(card: Dictionary) -> String:
	var amount: float = float(card.get("amount", DEFAULT_AMOUNT))
	if amount <= 0.0:
		return EventSheetL10n.translate("Amount is 0, so the colours are never split.")
	var seconds: String = _plain(float(card.get("seconds", DEFAULT_SECONDS)))
	var how: String = _plain(amount)
	var held: bool = str(card.get("mode", "reducing")) == "constant"
	if str(card.get("direction", "wander")) == "angle":
		var degrees: String = _plain(float(card.get("angle", 0.0)))
		if held:
			return EventSheetL10n.translate("The colours stay %s px apart along %s degrees, then snap together after %s s.") % [how, degrees, seconds]
		return EventSheetL10n.translate("The colours part by up to %s px along %s degrees and are back together after %s s.") % [how, degrees, seconds]
	if held:
		return EventSheetL10n.translate("The colours stay %s px apart, turning as they go, then snap together after %s s.") % [how, seconds]
	return EventSheetL10n.translate("The colours part by up to %s px, turning as they go, and are back together after %s s.") % [how, seconds]


## The drawing and the sentence under it. Both follow the card's numbers as they are edited.
static func shape_strip(card: Dictionary, _now: Callable, _edited: Object) -> Control:
	var box: PictureBox = PictureBox.new()
	box.setup(card)
	return box


class PictureBox:
	extends VBoxContainer

	var strip: Strip = null
	var note: Label = null

	func setup(split: Dictionary) -> void:
		strip = Strip.new()
		strip.card = split
		strip.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled(56))
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(strip)
		var words: Script = load("res://addons/eventsheet/editor/inspector/juice_chroma_picture.gd") as Script
		note = Label.new()
		note.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		note.modulate = Color(1.0, 1.0, 1.0, 0.6)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.text = str(words.call("says", split))
		add_child(note)


## The screen and the ring of places a wandering split may point. The three channels are drawn by a child that adds them.
class Strip:
	extends Control

	var card: Dictionary = {}
	var _marks: Marks = null

	func _ready() -> void:
		_marks = Marks.new()
		_marks.card = card
		_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
		_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var added: CanvasItemMaterial = CanvasItemMaterial.new()
		added.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_marks.material = added
		add_child(_marks)

	func _draw() -> void:
		var words: Script = load("res://addons/eventsheet/editor/inspector/juice_chroma_picture.gd") as Script
		draw_rect(Rect2(Vector2.ZERO, size), words.get_script_constant_map()["SCREEN_COLOUR"])
		var shape: float = minf(size.y * 0.5 - 6.0, 18.0)
		var placed: Dictionary = words.call("marks", card, size.x * 0.5 - shape - 6.0)
		if bool(placed["wander"]):
			var ring: float = (placed["blue"] as Vector2).length()
			for dot: int in range(12):
				draw_circle(size * 0.5 + Vector2.from_angle(float(dot) / 12.0 * TAU) * ring, 1.2, Color(1.0, 1.0, 1.0, 0.3))


## The shape three times, in red, green and blue, so that where they overlap the shape is white.
class Marks:
	extends Control

	var card: Dictionary = {}

	func _draw() -> void:
		var words: Script = load("res://addons/eventsheet/editor/inspector/juice_chroma_picture.gd") as Script
		var shape: float = minf(size.y * 0.5 - 6.0, 18.0)
		var placed: Dictionary = words.call("marks", card, size.x * 0.5 - shape - 6.0)
		var channels: PackedColorArray = words.get_script_constant_map()["CHANNELS"]
		var names: PackedStringArray = ["red", "green", "blue"]
		for index: int in range(3):
			var at: Vector2 = size * 0.5 + (placed[names[index]] as Vector2)
			draw_rect(Rect2(at - Vector2(shape, shape * 0.6), Vector2(shape * 2.0, shape * 1.2)), channels[index])
