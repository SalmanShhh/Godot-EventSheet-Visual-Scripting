## @ace_version(1.0.0)
@icon("res://eventsheet_addons/color_palette_resource/icon.svg")
class_name ColorPaletteResource
extends Resource
## Several colour sets in one data asset - one set per kind of colour vision, each filling the same roles in the same order. Load it with the Use Palette action; the palette parameter draws every set side by side.

# @inspector_header Colour Palette #7bc96f
# @inspector_info One entry in Set Names per set, one entry in Set Colors per set, and every set holds one colour per entry in Role Names, in that order.
## A label for your own reference (nothing reads it).
@export var palette_name: String = "palette"
## What each position in a set means ("Danger", "Safe", "Neutral"). Every set fills these roles in this order.
@export var role_names: PackedStringArray = []
## One name per colour set ("Default", "Deuteranopia", "Protanopia"). This is the name the player picks.
@export var set_names: PackedStringArray = []
## One colour array per set, in the same order as Set Names. Inside an array the colours follow Role Names.
@export var set_colors: Array[PackedColorArray] = []
