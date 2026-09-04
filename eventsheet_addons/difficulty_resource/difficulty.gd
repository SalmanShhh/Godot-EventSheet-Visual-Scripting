## @ace_version(1.0.0)
@icon("res://eventsheet_addons/difficulty_resource/icon.svg")
class_name DifficultyResource
extends Resource
## One difficulty as a file: the word a player picks, the line a menu shows under it, and the named factors your rows multiply by. Drop it in a folder and the Settings pack's Difficulty Names lists it, with nothing to register anywhere.

# @inspector_header Difficulty #c8935a
# @inspector_info Nothing in this file changes the game on its own. A factor changes something because a row multiplied by it - Difficulty Factor "damage_taken" where damage is dealt, "enemy_count" where a wave is sized. Keys nothing reads are simply unread.
## The word a player sees ("Hard"). Leave it blank and the file's own name is used.
@export var difficulty_name: String = ""
## The line the menu shows under the word - what this difficulty is for, in the player's terms.
@export var description: String = ""
## Factor name to the number this difficulty gives it. Any keys at all; a key no difficulty writes reads as 1.0. Each key also shows as its own field above.
@export var factors: Dictionary = {}

# Every key of `factors` shows in the Inspector as a field of its own, named and typed by
# what is stored under it - which is what makes a factor invented today an ordinary row in
# every difficulty file tomorrow. Nothing is stored twice: the fields are editor-only views
# onto the one exported dictionary.
func _get_property_list() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for factor_name: String in factors:
		shown.append({"name": "factors/%s" % factor_name, "type": typeof(factors[factor_name]),
			"usage": PROPERTY_USAGE_EDITOR})
	return shown

func _get(property: StringName) -> Variant:
	var field: String = str(property)
	if not field.begins_with("factors/"):
		return null
	return factors.get(field.trim_prefix("factors/"))

func _set(property: StringName, value: Variant) -> bool:
	var field: String = str(property)
	if not field.begins_with("factors/"):
		return false
	factors[field.trim_prefix("factors/")] = value
	return true
