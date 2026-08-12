# Pack builder - encounter_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## EncounterResource: a spawn/beat timeline - a combat wave, a boss's phases, a tutorial's pacing, the
## ambient traffic of a street - as ONE .tres data asset you fill in the Inspector. This is the
## data-driven half of the Encounter Timeline pack: instead of a nest of timers, a designer edits one
## grid of at_seconds / scene_path / count / group_name / note, saves the .tres, and the Encounter
## Timeline behavior plays it back with Load Encounter + Start Encounter. Difficulty variants are other
## .tres files. A plain Resource (extends Resource), so it works with Godot's own Inspector and file
## system with no plugin at runtime.
##
## Rows may be typed in any order - the timeline sorts them by at_seconds when it loads them.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "EncounterResource"
	sheet.addon_version = "1.0.0"
	sheet.class_description = "A spawn timeline as a data asset: what appears, how many, in which group, and how many seconds into the encounter. Play it back with the Encounter Timeline behavior's Load Encounter and Start Encounter - the data-driven alternative to a nest of timers."
	sheet.addon_category = "Encounter Timeline"
	sheet.addon_tags = PackedStringArray(["spawning", "waves", "resource"])
	sheet.variables = {
		"encounter_name": {"type": "String", "default": "encounter", "exported": true,
			"attributes": {"group": "Identity",
				"tooltip": "A readable name for this encounter (\"Wave 3\", \"Boss: phase two\"), shown at the top of the Encounter Report and read back with the Encounter Name expression."}},
		"entries": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Beats",
				"tooltip": "One row per beat of the encounter. `at_seconds` is how far into the encounter it happens (rows may be typed in any order - the timeline sorts them). `scene_path` is the .tscn to spawn, e.g. res://enemies/slime.tscn - leave it blank for a beat that spawns nothing and only fires the trigger. `count` is how many copies (0 spawns nothing). `group_name` puts every copy in that group so the rest of your game can find them (\"enemies\"). `note` is a plain-language reminder for you and for the report (\"first archer, teaches cover\") - the pack never interprets it.",
				"drawer": "table", "table_columns": [
					{"name": "at_seconds", "type": "float"},
					{"name": "scene_path", "type": "String"},
					{"name": "count", "type": "int"},
					{"name": "group_name", "type": "String"},
					{"name": "note", "type": "String"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/encounter_resource/encounter_resource")
