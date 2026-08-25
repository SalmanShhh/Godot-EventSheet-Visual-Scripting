## @ace_tags(spawning, waves, resource)
## @ace_category("Encounter Timeline")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/encounter_resource/icon.svg")
class_name EncounterResource
extends Resource
## A spawn timeline as a data asset: what appears, how many, in which group, and how many seconds into the encounter. Play it back with the Encounter Timeline behavior's Load Encounter and Start Encounter - the data-driven alternative to a nest of timers.

## A readable name for this encounter ("Wave 3", "Boss: phase two"), shown at the top of the Encounter Report and read back with the Encounter Name expression.
@export_group("Identity")
@export var encounter_name: String = "encounter"
## One row per beat of the encounter. `at_seconds` is how far into the encounter it happens (rows may be typed in any order - the timeline sorts them). `scene_path` is the .tscn to spawn, e.g. res://enemies/slime.tscn - leave it blank for a beat that spawns nothing and only fires the trigger. `count` is how many copies (0 spawns nothing). `group_name` puts every copy in that group so the rest of your game can find them ("enemies"). `note` is a plain-language reminder for you and for the report ("first archer, teaches cover") - the pack never interprets it.
@export_group("Beats")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:at_seconds=float,scene_path=String,count=int,group_name=String,note=String") var entries: Array = []
