## @ace_tags(spawning, waves, resource)
## @ace_category("Encounter Timeline")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/encounter_resource/icon.svg")
class_name EncounterResource
extends Resource
## A spawn timeline as a data asset: what appears, how many, in which group, and how many seconds into the encounter. Play it back with the Encounter Timeline behavior's Load Encounter and Start Encounter - the data-driven alternative to a nest of timers.

## One row per beat: seconds in, scene to spawn and how many.
@export_group("Beats")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:at_seconds=float,scene_path=String,count=int,group_name=String,note=String") var entries: Array = []
## Readable name of this encounter, such as Wave 3, shown in the encounter report.
@export_group("Identity")
@export var encounter_name: String = "encounter"
