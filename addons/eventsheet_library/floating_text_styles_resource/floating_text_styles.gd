## @ace_tags(text, damage, hud, resource)
## @ace_category("UI")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/floating_text_styles_resource/icon.svg")
class_name FloatingTextStyles
extends Resource
## The ways a number pops out of a thing you hit, as a file you own: the name of each manner and the size, colour, rise, shake and lifetime it is drawn with. A style may take its colour from the damage instead, so a fire number is orange without a colour being typed into the row.

# @inspector_header Floating Text Styles #e0793f
# @inspector_info One entry in Style Names per manner, and its size, colour, rise, shake and lifetime in the same position in the five lists below. A name with no entry yet is drawn plain.
## A label for your own reference (nothing reads it). Leave it blank and the file's own name is the set's name.
@export var set_name: String = ""
## What the manners are called ("normal", "crit", "heal"). These are the words a pop row names.
@export var style_names: PackedStringArray = []
## How much bigger than the ordinary label each manner is drawn. 1 is the size you designed, 1.6 is a critical.
@export var sizes: PackedFloat32Array = []
## The colour each manner is drawn in. Ignored for a style listed in Colour From Damage Type, which takes the hit's colour instead.
@export var colors: PackedColorArray = []
## How far the number floats upward before it goes, in pixels.
@export var rises: PackedFloat32Array = []
## How hard the number shakes on its way up, in pixels. 0 is a clean rise.
@export var shakes: PackedFloat32Array = []
## How long each manner stays on screen, in seconds.
@export var lifetimes: PackedFloat32Array = []
## The style names whose colour comes from the DAMAGE rather than from this file - the door a typed-damage game opens so a fire number is orange and an ice one blue. Leave it empty and every style keeps its own colour.
@export var colour_from_damage_type: PackedStringArray = []

func has_style(style_name: String) -> bool:
	# The lists are read IN STEP - the third name's size is the third size - so a set stays one
	# thing to edit rather than a dictionary whose keys drift out of the order they are shown in.
	# Every answer is total: a name this set has never heard of reads as the plain default rather
	# than an error, because a set being written is half-filled most of the time.
	return Array(style_names).has(style_name)

func size_of(style_name: String) -> float:
	return _number(sizes, style_name, 1.0)

func rise_of(style_name: String) -> float:
	return _number(rises, style_name, 24.0)

func shake_of(style_name: String) -> float:
	return _number(shakes, style_name, 0.0)

func lifetime_of(style_name: String) -> float:
	return _number(lifetimes, style_name, 0.7)

func colour_of(style_name: String, damage_colour: Color = Color.WHITE) -> Color:
	# The second door: a style listed in colour_from_damage_type prefers the colour it was HANDED
	# over the one written here, so one file can hold the manners while the damage types hold the
	# palette. A caller with no damage colour passes nothing and gets this file's own answer.
	if Array(colour_from_damage_type).has(style_name):
		return damage_colour
	var at: int = Array(style_names).find(style_name)
	if at < 0 or at >= colors.size():
		return Color.WHITE
	return colors[at]

func _number(list: PackedFloat32Array, style_name: String, fallback: float) -> float:
	# One reader for the five number lists, so a list that has not been filled in yet answers with
	# the default that list means rather than with a zero nobody chose.
	var at: int = Array(style_names).find(style_name)
	if at < 0 or at >= list.size():
		return fallback
	return list[at]
