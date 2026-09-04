## @ace_tags(mods, resource, files)
## @ace_category("Mods")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/behavior.svg")
class_name ModManifest
extends Resource
## What a mod says about itself, as a file: its name, its version, its author, what it replaces, and whether it carries code. Save one as mod.tres beside a mod's files, or write the same five fields as a mod.json - the Mods pack reads both into the same record.

# @inspector_header Mod #5f9ea0
# @inspector_info These five fields are the whole manifest. A modder outside Godot writes the same five into a mod.json instead.
## The name the mod is shown and addressed by - what a mod list prints and what Mod Is Loaded, Enable Mod and Unload Mod are given. Leave it blank and the folder's own name is used.
@export var mod_name: String = ""
## The mod's own version, in whatever spelling its author uses. Shown beside the name in a mod list; nothing here compares two of them.
@export var version: String = "1.0"
## Who made it - the credit line a mod list shows.
@export var author: String = ""
## What this mod replaces, in the author's own words ("the sword icons", "res://data/items/sword.tres"). Nothing reads it: it is the sentence a player reads before switching two mods on together.
@export var replaces: String = ""
## Tick this when the mod carries code. A data-only load refuses it, and a load that allows code says so in the row. Leaving it false does not hide code: the loader reads the mod's actual files as well.
@export var scripts: bool = false

func to_json_text() -> String:
	# The JSON spelling of the same five fields, so a manifest filled in the Inspector can be
	# written out as the mod.json a modder outside Godot edits. The keys are the ones the Mods
	# pack reads, written here once so the two spellings cannot drift apart.
	return JSON.stringify({
		"name": mod_name,
		"version": version,
		"author": author,
		"replaces": replaces,
		"scripts": scripts,
	}, "\t")
