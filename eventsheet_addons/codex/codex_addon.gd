## @ace_tags(collection, codex, progression, unlocks)
## @ace_category("Codex")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/codex/icon.svg")
class_name CodexAddon
extends Node
## The set of things the player has found, as the Codex autoload: discover an entry, ask whether it has been found, count how many of a set are in, and walk the discovered pages to draw the codex screen. A set is a folder and an entry is a file in it, so the pages are CodexEntryResource files you own - the pack ships one empty starter and no list.

## Fires the FIRST time an entry is discovered, and never again for that entry - the toast, the
## page-turn sound, the achievement. A second Discover of the same entry is silent, so the row that
## fills the codex and the row that celebrates it can be the same row.
## @ace_trigger
## @ace_name("On First Discovered")
signal first_discovered(set_name: String, entry_id: String)

## Where the sets live. A SET is a folder under this one and an ENTRY is a file in that folder, so
## `res://codex/enemies/slime.tres` is the entry "slime" of the set "enemies". Adding a page means
## dropping a file in a folder: there is no list anywhere, in this pack or in the editor.
@export_dir var codex_folder: String = "res://codex"
## Warns about a Discover into a set with no folder, a discovered entry with no file behind it, and
## an empty name handed to a row. On while you build, off for release.
@export var debug_mode: bool = false

## What has been found, as {set name: {entry id: true}}. A Dictionary per set rather than an array
## because the only question ever asked of it is whether one entry is in there.
var _found: Dictionary = {}
## One entry's resource, or null when no file answers to that id. Both resource extensions are
## tried, so a binary .res entry works exactly like a text .tres one.
## @ace_hidden
func _entry(set_name: String, entry_id: String) -> Resource:
	for extension: String in [".tres", ".res"]:
		var path: String = _set_folder(set_name).path_join(entry_id + extension)
		if ResourceLoader.exists(path):
			return load(path)
	return null

## Runs this event's actions once per DISCOVERED entry of a set, in name order - the codex
## page itself, as one row. Read the current one as `entry`, then take its `entry_name`, `picture`
## and `text` straight off it. An entry that has been discovered but has no file behind it any more
## is skipped rather than arriving as null.
## @ace_looping(entry)
## @ace_name("For Each Discovered")
## @ace_category("Codex")
func each_discovered(set_name: String) -> Array:
	var ids: Array = (_found.get(set_name, {}) as Dictionary).keys()
	ids.sort()
	var pages: Array = []
	for entry_id: String in ids:
		var page: Resource = _entry(set_name, entry_id)
		if page == null:
			if debug_mode:
				push_warning("Codex: \"%s\" is discovered in the \"%s\" set, but no entry file in %s answers to it." % [entry_id, set_name, _set_folder(set_name)])
			continue
		pages.append(page)
	return pages

## @ace_action
## @ace_featured
## @ace_name("Discover")
## @ace_category("Codex")
## @ace_description("Records that the player has found an entry of a set. The first Discover of an entry fires On First Discovered; every one after it is silent, so the row that fills the codex and the row that celebrates it can be the same row.")
## @ace_display_template("Discover [b]{entry_id}[/b] in [b]{set_name}[/b]")
## @ace_icon("res://eventsheet_addons/codex/icon.svg")
## @ace_codegen_template("Codex.discover({set_name}, {entry_id})")
func discover(set_name: String, entry_id: String) -> void:
	if entry_id.is_empty():
		if debug_mode:
			push_warning("Codex: a Discover row in the \"%s\" set was given no entry name, so nothing was recorded." % set_name)
		return
	var ids: Dictionary = _found.get(set_name, {})
	if ids.has(entry_id):
		return
	ids[entry_id] = true
	_found[set_name] = ids
	if debug_mode and _entry(set_name, entry_id) == null:
		push_warning("Codex: \"%s\" was discovered in the \"%s\" set, but no entry file in %s answers to it - For Each Discovered will skip it." % [entry_id, set_name, _set_folder(set_name)])
	first_discovered.emit(set_name, entry_id)

## @ace_condition
## @ace_featured
## @ace_name("Has Discovered")
## @ace_category("Codex")
## @ace_description("Whether that entry of that set has been found - show the page, unlock the recipe, grey the silhouette out.")
## @ace_display_template("Has discovered [b]{entry_id}[/b] in [b]{set_name}[/b]")
## @ace_icon("res://eventsheet_addons/codex/icon.svg")
## @ace_codegen_template("Codex.has_discovered({set_name}, {entry_id})")
func has_discovered(set_name: String, entry_id: String) -> bool:
	return (_found.get(set_name, {}) as Dictionary).has(entry_id)

## @ace_expression
## @ace_name("Discovered Count")
## @ace_category("Codex")
## @ace_description("How many entries of a set have been found - the left-hand number of a 14-out-of-60 line.")
## @ace_display_template("discovered count of [b]{set_name}[/b]")
## @ace_icon("res://eventsheet_addons/codex/icon.svg")
## @ace_codegen_template("Codex.discovered_count({set_name})")
func discovered_count(set_name: String) -> int:
	return (_found.get(set_name, {}) as Dictionary).size()

## @ace_expression
## @ace_name("Total Entries")
## @ace_category("Codex")
## @ace_description("How many entries a set HOLDS, counted from the files in its folder - the right-hand number of a 14-out-of-60 line. A page added to the folder joins the total with no sheet edit.")
## @ace_display_template("total entries in [b]{set_name}[/b]")
## @ace_icon("res://eventsheet_addons/codex/icon.svg")
## @ace_codegen_template("Codex.total_entries({set_name})")
func total_entries(set_name: String) -> int:
	return _entry_ids(set_name).size()

## The folder one set's entry files live in.
## @ace_hidden
func _set_folder(set_name: String) -> String:
	return codex_folder.path_join(set_name)

## Every entry id a set's folder HOLDS, sorted - the file names with their extension taken off. A
## folder that is not there holds nothing, and says so only in debug mode, because Total Entries is
## the kind of row a menu asks every frame.
## @ace_hidden
func _entry_ids(set_name: String) -> PackedStringArray:
	var folder: String = _set_folder(set_name)
	var ids: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		if debug_mode:
			push_warning("Codex: there is no folder at %s, so the \"%s\" set counts as empty." % [folder, set_name])
		return ids
	for file_name: String in DirAccess.get_files_at(folder):
		var plain: String = String(file_name).trim_suffix(".remap")
		if plain.ends_with(".tres") or plain.ends_with(".res"):
			ids.append(plain.get_basename())
	ids.sort()
	return ids

## The save seam every autoload pack here answers to: Save All Addons snapshots this under the
## autoload's own name, and Load All Addons hands it straight back. Plain data only, and the ids go
## out sorted so two runs that found the same pages write the same bytes.
## @ace_hidden
func save_state() -> Dictionary:
	var out: Dictionary = {}
	var set_names: Array = _found.keys()
	set_names.sort()
	for set_name: String in set_names:
		var ids: Array = (_found[set_name] as Dictionary).keys()
		ids.sort()
		out[set_name] = ids
	return {"discovered": out}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_found = {}
	for set_name: String in (state.get("discovered", {}) as Dictionary):
		var ids: Dictionary = {}
		for entry_id: Variant in state["discovered"][set_name]:
			ids[str(entry_id)] = true
		_found[set_name] = ids

# Codex (autoload): register as the Codex autoload, then discover entries from any sheet. A set is a folder under the Codex Folder and an entry is a CodexEntryResource file in it, so a new page is a new file. What has been found rides the save through Save All Addons, like every other autoload pack here. This pack is an event sheet - extend it by editing it.
