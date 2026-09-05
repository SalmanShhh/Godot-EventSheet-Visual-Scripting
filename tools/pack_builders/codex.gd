# Pack builder - codex (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Codex: the set of things the player has found, as the Codex autoload.
##
## A bestiary, a recipe book, an item compendium, a gallery of unlocked art and a list of visited
## rooms are one mechanic wearing five hats: a set of names, the ones that have been met, and the
## pages behind them. Every game writes it again - a Dictionary of booleans in a script, a save key
## per entry, a scene per page - and every game writes it differently.
##
## The set is a FOLDER and an entry is a FILE in it, so `res://codex/enemies/slime.tres` is the
## entry "slime" of the set "enemies". That is the whole data model: adding a page is dropping a
## file in a folder, and there is no list in this pack, no dropdown in the editor and no name of
## anybody's monster anywhere in the plugin.
##
## IT IS A SERVICE, NOT A NODE - what has been found belongs to the game rather than to whichever
## scene noticed it - so this ships as the Codex AUTOLOAD, the way Save System and Music do, and any
## sheet reaches it with no node path.
##
## IT PERSISTS THE WAY EVERY OTHER AUTOLOAD PACK HERE DOES: `save_state` / `load_state`, which Save
## All Addons picks up under this pack's own autoload name with no list to keep in step. Nothing is
## written behind the game's back, and a project that saves nothing keeps its codex for the session.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("codex", "Node", "CodexAddon",
		"The set of things the player has found, as the Codex autoload: discover an entry, ask whether it has been found, count how many of a set are in, and walk the discovered pages to draw the codex screen. A set is a folder and an entry is a file in it, so the pages are CodexEntryResource files you own - the pack ships one empty starter and no list.",
		Lib.manifest().autoload("Codex").category("Codex").tags(["collection", "codex", "progression", "unlocks"]))
	src.note("Codex (autoload): register as the Codex autoload, then discover entries from any sheet. A set is a folder under the Codex Folder and an entry is a CodexEntryResource file in it, so a new page is a new file. What has been found rides the save through Save All Addons, like every other autoload pack here. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.block("block_2")

	src.verb("discover", "Discover",
		"Records that the player has found an entry of a set. The first Discover of an entry fires On First Discovered; every one after it is silent, so the row that fills the codex and the row that celebrates it can be the same row.",
		[["set_name", "String"], ["entry_id", "String"]])
	_default(src.sheet, "set_name", "\"enemies\"")
	_default(src.sheet, "entry_id", "\"slime\"")
	# THE WAY BACK OUT. Without these two the book could only ever grow: a New Game in the same
	# session, a cheat menu that locks a page again and a set of run-only discoveries all had no
	# row, and load_state leaves a codex alone when the save carries none of its own (the same
	# empty-state rule every autoload pack here follows), so nothing but a restart emptied it.
	src.verb("forget_entry", "Forget Entry",
		"Takes one entry back out of the set, so Has Discovered says no again and the page leaves For Each Discovered. The other half of Discover: a cheat menu that locks a page again, a chapter that takes its own notes back, a run-only discovery cleared between runs. An entry that was never found is left alone.",
		[["set_name", "String"], ["entry_id", "String"]])
	_default(src.sheet, "set_name", "\"enemies\"")
	_default(src.sheet, "entry_id", "\"slime\"")
	src.verb("forget_set", "Forget Set",
		"Empties one whole set, so nothing in it counts as found any more and its count reads zero. What a New Game in the same session wants, and what a save that carries no codex of its own deliberately does NOT do by itself.",
		[["set_name", "String"]])
	_default(src.sheet, "set_name", "\"enemies\"")
	src.condition("has_discovered", "Has Discovered",
		"Whether that entry of that set has been found - show the page, unlock the recipe, grey the silhouette out.",
		[["set_name", "String"], ["entry_id", "String"]])
	_default(src.sheet, "set_name", "\"enemies\"")
	_default(src.sheet, "entry_id", "\"slime\"")
	src.expression("discovered_count", "Discovered Count",
		"How many entries of a set have been found - the left-hand number of a 14-out-of-60 line.",
		[["set_name", "String"]], TYPE_INT)
	_default(src.sheet, "set_name", "\"enemies\"")
	src.expression("total_entries", "Total Entries",
		"How many entries a set HOLDS, counted from the files in its folder - the right-hand number of a 14-out-of-60 line. A page added to the folder joins the total with no sheet edit.",
		[["set_name", "String"]], TYPE_INT)
	_default(src.sheet, "set_name", "\"enemies\"")

	Lib.verb_sentences(src.sheet, {
		"discover": "Discover [b]{entry_id}[/b] in [b]{set_name}[/b]",
		"forget_entry": "Forget [b]{entry_id}[/b] in [b]{set_name}[/b]",
		"forget_set": "Forget everything in [b]{set_name}[/b]",
		"has_discovered": "Has discovered [b]{entry_id}[/b] in [b]{set_name}[/b]",
		"discovered_count": "discovered count of [b]{set_name}[/b]",
		"total_entries": "total entries in [b]{set_name}[/b]",
	})
	# The two a new user should meet first: put something in the codex, and ask whether it is in.
	Lib.feature_verbs(src.sheet, ["discover", "has_discovered"])
	if not Lib.publish(src, "res://eventsheet_addons/codex/codex_addon"):
		return false
	# The one empty starter goes out beside the director as the file to duplicate. It is the only
	# page this plugin will ever ship, and it names nothing: a title to type over and a blank body.
	return Lib.ship_files("codex", "res://eventsheet_addons/codex/codex_addon",
		PackedStringArray(["tres"]))


## Pre-fills the last-declared verb's parameter default, so a dropped row opens with a usable value
## instead of an empty field (authoring-time metadata only - defaults never appear in the compiled
## .gd of a game that uses the row).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
