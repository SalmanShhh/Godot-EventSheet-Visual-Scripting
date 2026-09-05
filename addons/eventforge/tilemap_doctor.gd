# Godot EventSheets - the Doctor's Tilemap section.
#
# Two findings, and both describe a row that runs today, raises nothing, and quietly does nothing:
# a tile question asked under a custom data layer name no tileset in this project declares (the
# answer is null for ever), and a terrain painted into a terrain set the tilesets do not have (the
# engine ignores the call). Neither is an error anywhere - a misspelt data key is a perfectly good
# string, and a terrain set number is a perfectly good integer - which is exactly why they belong
# here rather than in a compiler message.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack shipping tile verbs of its own lands in this same
# section rather than inventing a second report. Registering from the Doctor's own run is what makes
# it show up in all four runners (the panel, the headless CLI, CI and the MCP server) without the
# plugin having to be loaded first.
#
# IT READS EMITTED SCRIPTS, not sheet resources, for the reason every section here does: `.gd` is
# the default sheet format, and a `.tres` walk misses most real projects. The lines it looks for are
# the ones the tile rows compile to, so a hand-written call to the same helper is audited exactly
# like a row - which is right, because it IS the same line.
#
# WHAT IT REFUSES TO SAY. The tilesets are read as text (EventForgeTileSetFacts), which cannot see a
# binary `.res` tileset or one built at run time. So the section says nothing at all in a project it
# found no readable tileset in: a list that may be incomplete must never become a finding claiming
# something does not exist. That is a narrower section on purpose, and the alternative was noise.
#
# NOTHING is written and nothing is stored. A project with no tile rows in it pays one substring
# test per script and reports nothing.
@tool
class_name EventSheetTilemapDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id each finding is filed as. Frozen alongside the
## wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "tilemap"
const CHECK_UNKNOWN_DATA_KEY := "tilemap-unknown-data-key"
const CHECK_MISSING_TERRAIN_SET := "tilemap-missing-terrain-set"

## The cheap first question asked of a script's text. A file saying none of these words cannot hold
## one of these rows, and a project full of ordinary scripts should not pay to be searched properly
## to find that out.
const SHEET_WORDS: PackedStringArray = ["__eventsheets_tile_data_at",
	"__eventsheets_cells_with_data", "set_cells_terrain_connect"]

## The two calls that take a data key, and WHICH argument of each carries it. A tile-data question
## puts it third (the node, the place, the key); a cells-with-data question puts it second (the
## node, the key, the value). Read as a numbered argument rather than as "the quoted string near the
## bracket": every argument in front of it is an expression that may hold commas, brackets and
## quoted strings of its own, and a reading that claimed the first quote it found reported
## `get_node("Ground")` as an undeclared data key - a warning about a row that is entirely correct.
const DATA_KEY_CALLS: Dictionary = {
	"__eventsheets_tile_data_at": 2,
	"__eventsheets_cells_with_data": 1,
}

## The terrain set of a terrain paint: the first of the two plain numbers the call ends with. The
## greedy head runs past the cell list, however many brackets it holds, and stops on the last pair.
const TERRAIN_PATTERN := "set_cells_terrain_connect\\(.*,\\s*(-?[0-9]+)\\s*,\\s*(-?[0-9]+)\\s*\\)"


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetTilemapDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	# THREE QUESTIONS ABOUT THE SAME BYTES. Is there a tileset at all, what data keys do the
	# tilesets declare, how many terrain sets do they go up to - each one of them a walk of the
	# project and a full read of every text resource in it. Held for the length of this run, they
	# are one walk and one read; let go of at the end, so the next run sees the project as it is.
	EventForgeTileSetFacts.remember()
	if not EventForgeTileSetFacts.has_any_tileset():
		EventForgeTileSetFacts.forget()
		return
	var sources: Array[Dictionary] = []
	for script_path: String in EventSheets.project_scripts():
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if _says_any(source, SHEET_WORDS):
			sources.append({"path": script_path, "source": source})
	findings.append_array(report(sources, EventForgeTileSetFacts.project_data_keys(),
		EventForgeTileSetFacts.project_terrain_set_count()))
	EventForgeTileSetFacts.forget()


## The whole section as findings, the summary first. Pure over the texts and the two facts, so a
## test hands it one script and two keys and pins the words without a project around it.
static func report(sources: Array[Dictionary], known_keys: PackedStringArray,
		terrain_sets: int) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if sources.is_empty():
		return findings
	var unknown: int = 0
	for entry: Dictionary in sources:
		var path: String = str(entry.get("path", ""))
		var mine: Array[Dictionary] = script_findings(path, str(entry.get("source", "")),
			known_keys, terrain_sets)
		unknown += mine.size()
		findings.append_array(mine)
	findings.insert(0, _finding("info", CHECK_ID, str(sources[0].get("path", "")),
		"Tilemap: %d sheet(s) ask a level questions, and %d row(s) name something the project's tilesets do not declare." % [
			sources.size(), unknown], ""))
	return findings


## What one script contributes. Pure over its text, so the wording is pinned without a walk.
static func script_findings(path: String, source: String, known_keys: PackedStringArray,
		terrain_sets: int) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for key: String in data_keys_asked(source):
		if known_keys.has(key):
			continue
		findings.append(_finding("warning", CHECK_UNKNOWN_DATA_KEY, path,
			"%s asks tiles for \"%s\", which no tileset in this project declares as a custom data layer - the answer will always be nothing." % [
				path.get_file(), key], key))
	for terrain_set: int in terrain_sets_painted(source):
		if terrain_set < terrain_sets:
			continue
		# A project whose readable tilesets declare no terrain set at all has no highest one, and
		# "go up to -1" is a number nobody can act on.
		if terrain_sets <= 0:
			findings.append(_finding("warning", CHECK_MISSING_TERRAIN_SET, path,
				"%s paints terrain set %d, and no tileset in this project declares a terrain set at all - the paint call does nothing." % [
					path.get_file(), terrain_set], str(terrain_set)))
			continue
		findings.append(_finding("warning", CHECK_MISSING_TERRAIN_SET, path,
			"%s paints terrain set %d, and this project's tilesets go up to %d - the paint call does nothing." % [
				path.get_file(), terrain_set, terrain_sets - 1], str(terrain_set)))
	return findings


## Every custom data layer name this text asks a tile for, in the order it asks and without repeats.
## Only a key written as a quoted LITERAL: a key held in a variable is one nothing here can name,
## and a finding about it would be a guess.
static func data_keys_asked(source: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for call_name: String in DATA_KEY_CALLS.keys():
		for arguments: PackedStringArray in _calls_of(source, call_name):
			var at: int = int(DATA_KEY_CALLS[call_name])
			if at >= arguments.size():
				continue
			var key: String = _literal_of(arguments[at])
			if not key.is_empty() and not keys.has(key):
				keys.append(key)
	return keys


## Every call of one function in a blob of text, as its own arguments, split on the commas that are
## not inside a bracket or a string. The name only counts where nothing runs into it from the left,
## so somebody's own method ending in the same letters is not read as this one.
static func _calls_of(source: String, call_name: String) -> Array:
	var calls: Array = []
	var mark: String = call_name + "("
	var at: int = source.find(mark)
	while at >= 0:
		var before: String = source.substr(at - 1, 1) if at > 0 else ""
		if not _is_word_glyph(before):
			calls.append(_arguments_of(source, at + mark.length()))
		at = source.find(mark, at + mark.length())
	return calls


## One argument list, from just after its opening bracket to the bracket that closes it. Depth is
## counted so a call or a list inside an argument does not end it early, and a quoted string is
## stepped over whole so a comma or a bracket written inside one is a character rather than a mark.
static func _arguments_of(source: String, from: int) -> PackedStringArray:
	var arguments: PackedStringArray = PackedStringArray()
	var depth: int = 1
	var began: int = from
	var index: int = from
	while index < source.length():
		var glyph: String = source[index]
		if glyph == "\"" or glyph == "\'":
			var closed_at: int = source.find(glyph, index + 1)
			index = source.length() if closed_at < 0 else closed_at + 1
			continue
		if glyph == "\n":
			break
		if glyph == "(" or glyph == "[" or glyph == "{":
			depth += 1
		elif glyph == ")" or glyph == "]" or glyph == "}":
			depth -= 1
			if depth == 0:
				arguments.append(source.substr(began, index - began).strip_edges())
				return arguments
		elif glyph == "," and depth == 1:
			arguments.append(source.substr(began, index - began).strip_edges())
			began = index + 1
		index += 1
	return PackedStringArray()


## What a quoted literal says, or "" for an expression that is not one. The quotes are read off the
## text because that is what makes the answer provable: a key built out of pieces may well name a
## data layer, and nothing here can say which one.
static func _literal_of(expression: String) -> String:
	var written: String = expression.strip_edges()
	if written.length() < 2:
		return ""
	var quote: String = written[0]
	if (quote != "\"" and quote != "\'") or not written.ends_with(quote):
		return ""
	var inside: String = written.substr(1, written.length() - 2)
	return "" if inside.contains(quote) else inside


## True for a glyph a name may be spelled with, so a call is only claimed where its own name starts.
static func _is_word_glyph(glyph: String) -> bool:
	if glyph.is_empty():
		return false
	return glyph == "_" or glyph.is_valid_int() or glyph.to_lower() != glyph.to_upper()


## Every terrain SET number this text paints into, in the order it paints and without repeats. A
## negative set is left out: -1 is how the engine's own call says "no terrain set", and saying
## nothing about it is what keeps the section quiet about a deliberate erase.
static func terrain_sets_painted(source: String) -> Array[int]:
	var sets: Array[int] = []
	var matcher: RegEx = RegEx.create_from_string(TERRAIN_PATTERN)
	for found: RegExMatch in matcher.search_all(source):
		var terrain_set: int = int(found.get_string(1))
		if terrain_set >= 0 and not sets.has(terrain_set):
			sets.append(terrain_set)
	return sets
