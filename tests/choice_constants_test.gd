@tool
class_name ChoiceConstantsTest
extends RefCounted

## A pack's exported choice keeps its stored words and its @export_enum line, and the pack's code names
## each word through a constant. This pins the two together: every constant of a choice carries a word the
## export line offers, and the line offers no word without its constant, so a word added to one and
## forgotten in the other fails here instead of reading as a silent miss in a game.

const SUPPORT := preload("res://tests/support.gd")

## [pack script, exported variable, constant prefix]
const CHOICES: Array = [
	["res://eventsheet_addons/bound_to/bound_to_behavior.gd", "bound_space", "BOUND_SPACE_"],
	["res://eventsheet_addons/pin/pin_behavior.gd", "pin_mode", "PIN_MODE_"],
	["res://eventsheet_addons/pin/pin_behavior.gd", "pin_axes", "PIN_AXES_"],
	["res://eventsheet_addons/pin_3d/pin_3d_behavior.gd", "pin_mode", "PIN_MODE_"],
	["res://eventsheet_addons/pin_3d/pin_3d_behavior.gd", "pin_axes", "PIN_AXES_"],
	["res://eventsheet_addons/rotate/rotate_behavior.gd", "rotation_type", "ROTATION_TYPE_"],
	["res://eventsheet_addons/follow_path/path_follow_behavior.gd", "loop_mode", "LOOP_MODE_"],
	["res://eventsheet_addons/stat_forge/stat_forge_behavior.gd", "overflow_mode", "OVERFLOW_MODE_"],
	["res://eventsheet_addons/utility_ai/utility_ai_addon.gd", "selection_mode", "SELECTION_MODE_"],
	["res://eventsheet_addons/anchor/anchor_behavior.gd", "anchored_to", "ANCHORED_TO_"],
	["res://eventsheet_addons/wrap/wrap_behavior.gd", "wrap_space", "WRAP_SPACE_"],
	["res://eventsheet_addons/wrap/wrap_behavior.gd", "wrap_shape", "WRAP_SHAPE_"],
	["res://eventsheet_addons/camera_rail/camera_rail_behavior.gd", "shot_ease", "SHOT_EASE_"],
	["res://eventsheet_addons/camera_rail_3d/camera_rail_3d_behavior.gd", "shot_ease", "SHOT_EASE_"],
]


static func run() -> bool:
	var rows: Array = []
	for choice: Array in CHOICES:
		var script: GDScript = load(str(choice[0])) as GDScript
		var offered: PackedStringArray = PackedStringArray()
		var named: PackedStringArray = PackedStringArray()
		if script != null:
			for property: Dictionary in script.get_script_property_list():
				if str(property.name) == str(choice[1]):
					offered = PackedStringArray(str(property.hint_string).split(",", false))
			var constants: Dictionary = script.get_script_constant_map()
			for constant_name: Variant in constants:
				if str(constant_name).begins_with(str(choice[2])) and constants[constant_name] is String:
					named.append(str(constants[constant_name]))
		offered.sort()
		named.sort()
		rows.append(["%s: every %s word has a constant and no constant is extra" % [str(choice[0]).get_file(), choice[1]], named, offered])
	return SUPPORT.pins("choice_constants_test", rows)
