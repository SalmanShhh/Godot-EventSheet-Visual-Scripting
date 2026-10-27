## @ace_version(1.0.0)
@icon("res://eventsheet_addons/quality_preset_resource/icon.svg")
class_name QualityPreset
extends Resource
## One graphics quality word as a file - the values it stands for, over settings that already exist. Drop it in res://settings/quality/ and it joins the Apply Quality dropdown, the options menu and the quality label without being registered anywhere.

# @inspector_header Quality Preset #7bc96f
# @inspector_info Settings holds the values; this file just says which values one word stands for. Every key of Values is a setting declared somewhere in your game.
## The word a player sees ("Medium"). Leave it blank and the file's own name is used.
@export var preset_name: String = ""
## How heavy this preset is - 0 lightest. "One step lower" walks this order, so give low/medium/high 0/1/2.
@export var rank: int = 0
## Setting name to the value this preset gives it. Each key also shows as its own field above.
@export var values: Dictionary = {}

# Every key of `values` shows in the Inspector as a field of its own, named and typed by what
# is stored under it. That is what makes a graphics option declared today an ordinary row in
# every preset file tomorrow: the plugin adds the key, and the field is there. Nothing is
# stored twice - the fields are editor-only views onto the one exported dictionary.
func _get_property_list() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for setting_name: String in values:
		shown.append({"name": "settings/%s" % setting_name, "type": typeof(values[setting_name]),
			"usage": PROPERTY_USAGE_EDITOR})
	return shown

func _get(property: StringName) -> Variant:
	var field: String = str(property)
	if not field.begins_with("settings/"):
		return null
	return values.get(field.trim_prefix("settings/"))

func _set(property: StringName, value: Variant) -> bool:
	var field: String = str(property)
	if not field.begins_with("settings/"):
		return false
	values[field.trim_prefix("settings/")] = value
	return true
