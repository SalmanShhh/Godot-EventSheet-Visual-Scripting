## @ace_version(1.0.0)
@icon("res://eventsheet_addons/ability_set_resource/icon.svg")
class_name AbilitySetResource
extends Resource
## A character's ability loadout as a data asset. Fill the abilities grid in the Inspector, save as a .tres, and drop it on a Simple Abilities behavior's Ability Set slot (or call Load Ability Set) to create the whole set on ready.

## One row per ability: its id, cooldown in seconds, max stacks (charges), temporary duration (0 = permanent), and comma-separated tags.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:id=String,cooldown=float,max_stacks=int,temporary=float,tags=String") var abilities: Array = []
