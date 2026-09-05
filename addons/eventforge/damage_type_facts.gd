# Godot EventSheets - what kinds of damage a project deals, read as TEXT.
#
# Two questions, asked by two readers who must never disagree: which damage types has this project
# actually written down, and which types do its rows deal. The type field of the Health pack's typed
# damage rows completes from the first; the Doctor's damage section compares the two and says when
# a row deals a kind nothing declares, or a node resists a kind nothing deals.
#
# WHY TEXT, AND NOT `load()`. A DamageTypeSet is a resource whose script ships in a pack the reader
# may not have installed, and loading one in the editor would run that script. Both facts wanted here
# are plain property lines in the saved file, so ONE regex over its text answers without touching the
# resource system:
#
#     script_class="DamageTypeSet"
#     type_names = PackedStringArray("physical", "fire")
#
# The consequence is stated rather than hidden: a set saved in the BINARY `.res` format is not read,
# and neither is one built at run time. Both are answered the same way - the completion list is
# shorter and the Doctor says nothing - because a list missing an entry must never become a finding
# claiming the entry does not exist. `has_any_set` is what the Doctor asks first for exactly that
# reason: a project this file can read nothing from is one it has no business reporting on.
#
# NOTHING IS WRITTEN and nothing is stored. The walk is bounded and SORTED - CI runs the suite on a
# filesystem whose own walk order is its business - so two runs over an unchanged project answer with
# the same list in the same order.
@tool
class_name EventForgeDamageTypeFacts
extends RefCounted

## Where the walk stops. A project with more files than this is not read further: the list is a
## convenience, and an editor that stalls opening a dialog is not one.
const FILE_LIMIT: int = 4000

## THE PLUGIN'S OWN COPIES OF THE STARTER SET, which are not the project's answer to anything.
## `has_any_set` is what the Doctor asks before it may call a word a misspelling, so a starter that
## ships with the pack would answer "yes, this project has written its damage types down" in every
## project that merely installed the pack - and then report every kind that starter does not name.
## The two homes are the pack folder the starter ships in and the builder source it is built from;
## a set the AUTHOR wrote, wherever they put it, is what this reader is looking for.
const SHIPPED_FOLDERS: PackedStringArray = [
	"res://eventsheet_addons/damage_type_set_resource",
	"res://tools/pack_builders"
]

## The class line a saved DamageTypeSet carries, and the property holding its names. Spelled as the
## engine writes them, because that is what the file on disk actually holds.
const SET_MARKER := "script_class=\"DamageTypeSet\""
const NAMES_PATTERN := "type_names = PackedStringArray\\(([^)]*)\\)"

## The line a row DEALS a kind of damage with, and the lines a node has an OPINION about a kind with.
## Two patterns rather than one, because the type sits in a different argument in each: the typed
## damage row takes an amount first, while resisting, immunity and weakness lead with the kind. The
## Doctor's two findings are exactly the difference between what these two answer.
##
## THE AMOUNT MAY BE A CALL OF ITS OWN. `take_typed_damage(maxf(a, b), "fire", self)` is ordinary
## authored code, and an amount that stopped at the first comma read nothing from it - so a kind the
## project really did deal went unseen, and the unknown-type finding it should have earned never
## came. One level of brackets is allowed inside the amount now, and the search is LAZY, so the kind
## captured is the second argument rather than the last string on the line - which is Scaled By.
##
## AND A NAME THAT ENDS IN ONE OF THE THREE WORDS IS NOT ONE OF THEM. `armour_resist("cold")` is a
## project's own method, not this pack's Resist row, and with nothing in front of the word it was
## read as an opinion about a kind nothing deals - a finding about a line that is not about damage.
const DEALT_PATTERN := "take_typed_damage\\((?:[^\"()]|\\([^()]*\\))*?, ?\"([^\"]*)\""
const OPINION_PATTERN := "(?<![A-Za-z0-9_])(?:resist|immune_to|weak_to)\\( ?\"([^\"]*)\""


## Every damage type name any set in this project declares, sorted and without repeats.
static func project_type_names() -> PackedStringArray:
	var seen: Dictionary = {}
	for path: String in project_set_files():
		for name_of_type: String in type_names(source_of(path)):
			seen[name_of_type] = true
	var names: Array = seen.keys()
	names.sort()
	return PackedStringArray(names)


## Every damage type the project declares WITH THE FILE that declares it, sorted by name. What a
## completion list shows: the word to insert, and the set it came from, since a project with two sets
## is exactly the project where a reader wants to know which one a word belongs to. A name declared
## by two sets is listed once, under the first file in path order.
static func project_types() -> Array[Dictionary]:
	var seen: Dictionary = {}
	for path: String in project_set_files():
		for name_of_type: String in type_names(source_of(path)):
			if not seen.has(name_of_type):
				seen[name_of_type] = path
	var names: Array = seen.keys()
	names.sort()
	var found: Array[Dictionary] = []
	for name_of_type: String in names:
		found.append({"name": name_of_type, "path": str(seen[name_of_type])})
	return found


## The starter set the plugin ships, read the same way and kept apart from the project's own answer.
##
## THE COMPLETION AND THE DOCTOR WANT DIFFERENT ANSWERS, and this is the seam between them. The
## Doctor must never count the starter, or every project that merely installed the pack would be
## told it had written its damage types down and then told off for every kind the starter does not
## name. A completion list has the opposite duty: a field that suggests nothing on the first day is
## a field that teaches nobody the word it wants, and the starter is exactly the four words a new
## project is about to use. So the starter is offered until the project writes a set of its own, at
## which point the project's own list is the only one worth reading.
static func starter_types() -> Array[Dictionary]:
	var seen: Dictionary = {}
	for path: String in _resource_files():
		if not _is_shipped(path) or not source_of(path).contains(SET_MARKER):
			continue
		for name_of_type: String in type_names(source_of(path)):
			if not seen.has(name_of_type):
				seen[name_of_type] = path
	var names: Array = seen.keys()
	names.sort()
	var found: Array[Dictionary] = []
	for name_of_type: String in names:
		found.append({"name": name_of_type, "path": str(seen[name_of_type])})
	return found


## What a type field should offer: this project's own kinds, and the shipped starter's while the
## project has written none of its own down.
static func types_to_suggest() -> Array[Dictionary]:
	var mine: Array[Dictionary] = project_types()
	return mine if not mine.is_empty() else starter_types()


## True when this project holds a text-format DamageTypeSet at all. The Doctor asks this before it
## says anything about an unknown type: a project that has written no set down has not disagreed with
## anything, and silence is the only honest report.
static func has_any_set() -> bool:
	return not project_set_files().is_empty()


## Every project file whose text is a saved DamageTypeSet, in sorted path order. The starter the pack
## ships is not one of them: it is the plugin's own file, not something this project decided.
static func project_set_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path: String in _resource_files():
		if _is_shipped(path):
			continue
		if source_of(path).contains(SET_MARKER):
			found.append(path)
	return found


## Whether a path is one of the plugin's own copies of the starter rather than a set the author
## wrote. Kept as one question so the completion list and the Doctor can never disagree about which
## files count as this project having written its damage types down.
static func _is_shipped(path: String) -> bool:
	for folder: String in SHIPPED_FOLDERS:
		if path.begins_with(folder + "/"):
			return true
	return false


## The type names one file's text declares, in the order the file declares them and without repeats.
## Pure over a string, so a test hands it a set it wrote itself.
static func type_names(source: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var matcher: RegEx = RegEx.create_from_string(NAMES_PATTERN)
	var found: RegExMatch = matcher.search(source)
	if found == null:
		return names
	for piece: String in found.get_string(1).split(","):
		var word: String = piece.strip_edges().trim_prefix("\"").trim_suffix("\"")
		if not word.is_empty() and not names.has(word):
			names.append(word)
	return names


## Every damage type one script DEALS, from the type argument of each typed-damage call. Sorted and
## without repeats, and pure over a string so the Doctor's tests need no files.
static func types_dealt(source: String) -> PackedStringArray:
	return _quoted_matches(source, DEALT_PATTERN)


## Every damage type one script has an OPINION about - resisted, immune to, weak to. The other half
## of the Doctor's comparison, read the same way from the lines that lead with the kind.
static func types_opined(source: String) -> PackedStringArray:
	return _quoted_matches(source, OPINION_PATTERN)


## One file's text, or "" when it cannot be opened. Never throws and never warns: a file that has
## gone since the walk listed it is simply one this reader says nothing about.
static func source_of(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


## Every first capture of one pattern over a text, sorted and without repeats. A call whose type is
## not a literal - a variable, an expression - contributes nothing, which is the honest answer: the
## reader cannot know what a variable held, so it says nothing about it rather than guessing.
static func _quoted_matches(source: String, pattern: String) -> PackedStringArray:
	var seen: Dictionary = {}
	var matcher: RegEx = RegEx.create_from_string(pattern)
	for hit: RegExMatch in matcher.search_all(source):
		var word: String = hit.get_string(1)
		if not word.is_empty():
			seen[word] = true
	var names: Array = seen.keys()
	names.sort()
	return PackedStringArray(names)


## Every text-format resource in the project, sorted, bounded, and skipping this plugin's own folder.
static func _resource_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: Array[String] = ["res://"]
	while not pending.is_empty() and found.size() < FILE_LIMIT:
		var directory: String = pending.pop_front()
		var handle: DirAccess = DirAccess.open(directory)
		if handle == null:
			continue
		var directories: PackedStringArray = handle.get_directories()
		directories.sort()
		for sub_directory: String in directories:
			if sub_directory.begins_with(".") or sub_directory == "addons":
				continue
			pending.append(directory.path_join(sub_directory))
		var files: PackedStringArray = handle.get_files()
		files.sort()
		for file_name: String in files:
			if file_name.get_extension().to_lower() != "tres":
				continue
			found.append(directory.path_join(file_name))
			if found.size() >= FILE_LIMIT:
				break
	found.sort()
	return found
