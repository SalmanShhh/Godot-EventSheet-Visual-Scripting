## @ace_tags(damage, health, resource)
## @ace_category("Health")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/damage_type_set_resource/icon.svg")
class_name DamageTypeSet
extends Resource
## The kinds of damage your game deals, as a file you own: the names and the colour each one is drawn in. The Health pack's typed-damage rows suggest these names, the HUD Kit takes a floating number's colour from them, and nothing here is required - a game with no set still deals typed damage.

# @inspector_header Damage Types #e0793f
# @inspector_info One entry in Type Names per kind of damage, and the colour in the same position in Type Colors. A name with no colour yet is drawn white.
## A label for your own reference (nothing reads it). Leave it blank and the file's own name is the set's name.
@export var set_name: String = ""
## The kinds of damage this game deals ("fire", "ice", "bleed"). These are the words the typed-damage rows offer while you author.
@export var type_names: PackedStringArray = []
## One colour per name, in the same order as Type Names. A floating damage number takes its colour from here.
@export var type_colors: PackedColorArray = []

func colour_of(type_name: String) -> Color:
	# The two lists are read IN STEP - the third name's colour is the third colour - so a set
	# stays one thing to edit rather than a dictionary whose keys drift out of the order they
	# are shown in. Both answers are total: a name this set has never heard of is white and
	# false rather than an error, because a set being written is half-filled most of the time.
	var at: int = Array(type_names).find(type_name)
	if at < 0 or at >= type_colors.size():
		return Color.WHITE
	return type_colors[at]

func has_type(type_name: String) -> bool:
	return Array(type_names).has(type_name)
