## @ace_tags(mods, resource, files)
## @ace_category("Mods")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/mod_manifest_resource/icon.svg")
class_name ModManifest
extends Resource
## What a mod says about itself, as a file: its name, its version, its author, what it replaces, and whether it carries code. Save one as mod.tres beside a mod's files, or write the same five fields as a mod.json - the Mods pack reads both into the same record.

# @inspector_header Mod #5f9ea0
# @inspector_info These five fields are the whole manifest. A modder outside Godot writes the same five into a mod.json instead.
## Name the mod is shown and addressed by; blank uses the folder name.
@export var mod_name: String = ""
## The mod's own version, in whatever spelling its author uses. Shown beside the name in a mod list; nothing here compares two of them.
@export var version: String = "1.0"
## Who made it - the credit line a mod list shows.
@export var author: String = ""
## Plain-words note of what this mod replaces, shown to players; nothing reads it.
@export var replaces: String = ""
## Tick when the mod carries code; a data-only load refuses it.
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
