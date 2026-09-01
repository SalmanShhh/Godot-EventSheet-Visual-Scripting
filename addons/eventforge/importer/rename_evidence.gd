# Godot EventSheets - what one file's last save actually did to the names in it.
#
# A rename that happened OUTSIDE the sheet - in the script editor, in the Scene dock, in somebody
# else's commit - leaves rows calling a name nothing answers to any more. The kind thing would be to
# guess what it became. The honest thing is to say so only when the file itself proves it.
#
# THE EVIDENCE RULE, and it is the whole file: a name is only ever offered as "did you mean" when the
# old name VANISHED and the new one ARRIVED in the SAME FILE in the SAME SAVE. One save is one step
# of that file's identity - `path|mtime|size` moving once - so the two halves of the swap were
# written by one gesture. A near name that was already in the file before the save did not arrive; a
# name that vanished with nothing arriving beside it has no candidate; a save that brought six new
# names has no single answer unless exactly one of them is a near spelling of the old one. Every one
# of those cases answers "" and the row stays plainly amber, with no offer at all.
#
# NEVER GUESSED, NEVER AUTOMATIC. Nothing here writes anything, to any file, ever. It answers a
# question, the answer is drawn in a receipt, and a person decides. A wrong offer costs somebody a
# broken game, so the rule refuses far more than it accepts and says nothing rather than something
# plausible.
#
# IT ONLY EVER KNOWS WHAT IT WATCHED. The witness starts empty every session: the first sight of a
# file records its names and files no save at all, because nothing can be said to have vanished from
# a file this session has never read. So a rename made while the editor was closed - a branch
# checkout, a pull - is exactly the "anything weaker" case, and the rows it broke wear plain amber.
# That is the correct answer, not a gap: the evidence genuinely is not there.
#
# PURE RULE + A SESSION WITNESS. The diff and the offer are static functions over two lists of names,
# so every branch is pinned headless; the witness above them is a dictionary keyed by file identity,
# dropped whole by `clear_cache()`.
@tool
class_name EventSheetRenameEvidence
extends RefCounted

## How far apart two names may be spelled and still be the same name renamed. The plugin's own
## definition of "near", shared with the typo guard rather than spelled a second time here - two
## answers to "is this near" is how the offer and the field that offers it come to disagree.
const MAX_EDIT_DISTANCE: int = EventSheetNameRescue.MAX_EDIT_DISTANCE

## Below this many characters a name is too short for nearness to mean anything: two edits turn a
## three-letter name into most other three-letter names, and an offer built on that is a coin toss
## wearing a receipt's clothes.
const SHORTEST_NEAR_NAME: int = 4

## file path -> {"stamp", "names"}: what this file held the last time anybody looked. The stamp is
## the file's identity, so a file re-read without being saved is recognised as the same file and
## files no save.
static var _seen: Dictionary = {}

## file path -> {"gone", "arrived"}: what that file's LAST save did, both lists sorted. One save, not
## a running total: a name that vanished three saves ago and a name that arrived just now were not
## written by one gesture, and joining them would be the guess this whole file exists to refuse.
static var _saves: Dictionary = {}

## The `func` / `signal` declaration shapes, compiled once for the session. A declaration is where a
## name LIVES, which is what a rename moves; a call is where it is used, which is what breaks.
static var _declaration_re: RegEx = null


## Looks at one file and files what its last save did to the names in it. `names` is the caller's
## reading of the file - the functions and signals a script declares, the nodes a scene holds - so
## one witness serves both without knowing how either is parsed.
##
## The FIRST sight of a file records it and files nothing: a file this session has never read cannot
## have lost anything as far as anybody here knows, and inventing a save for it would be the guess.
static func observe(path: String, names: PackedStringArray) -> void:
	if path.strip_edges().is_empty():
		return
	var stamp: String = EventForgeFileStamp.of(path)
	var held: Variant = _seen.get(path)
	var sorted: PackedStringArray = names.duplicate()
	sorted.sort()
	if held is Dictionary and str((held as Dictionary).get("stamp", "")) != stamp:
		var before: PackedStringArray = (held as Dictionary).get("names", PackedStringArray())
		_saves[path] = {"gone": missing_from(before, sorted), "arrived": missing_from(sorted, before)}
	_seen[path] = {"stamp": stamp, "names": sorted}


## What one file's last save did: {"gone", "arrived"}, both sorted, both empty for a file whose save
## this session did not watch.
static func last_save(path: String) -> Dictionary:
	var held: Variant = _saves.get(path)
	if held is Dictionary:
		return held
	return {"gone": PackedStringArray(), "arrived": PackedStringArray()}


## The one offer, over one file's last save: what `missing` most likely became, or "" when the file
## does not prove it. See the header - this is the rule, and everything else here serves it.
static func evidence_for(path: String, missing: String) -> String:
	var save: Dictionary = last_save(path)
	return did_you_mean(save.get("gone", PackedStringArray()),
		save.get("arrived", PackedStringArray()), missing)


## THE RULE. `gone` and `arrived` are one save's two halves; `missing` is the name a row still calls.
##
## It answers only when the save proves the swap. `missing` has to be among the names that vanished -
## a name that was never there is not a rename. Then, of the names that arrived: one and only one is
## an answer. A save that brought exactly one new name is that name, whatever it is spelled like,
## because one name out and one name in IS the swap. A save that brought several is answered only
## when exactly one of them is a near spelling of the old one; two near spellings are two answers,
## which is none.
static func did_you_mean(gone: PackedStringArray, arrived: PackedStringArray,
		missing: String) -> String:
	var name: String = missing.strip_edges()
	if name.is_empty() or not gone.has(name) or arrived.is_empty():
		return ""
	if arrived.size() == 1 and gone.size() == 1:
		return arrived[0]
	var answer: String = ""
	for candidate: String in arrived:
		if not is_near(name, candidate):
			continue
		if not answer.is_empty():
			# Two names that could each be the answer are not an answer. Saying either would be a
			# guess, and this file's whole promise is that it never guesses.
			return ""
		answer = candidate
	return answer


## True when two names are near enough to be one name renamed: within the typo guard's own edit
## distance, and long enough for that distance to mean something.
static func is_near(one: String, other: String) -> bool:
	if one == other:
		return false
	if mini(one.length(), other.length()) < SHORTEST_NEAR_NAME:
		return false
	return EventSheetNameRescue.edit_distance(one.to_lower(), other.to_lower()) <= MAX_EDIT_DISTANCE


## The names in `first` that `second` does not have, sorted - one half of a save's diff.
static func missing_from(first: PackedStringArray, second: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for name: String in first:
		if not second.has(name) and not out.has(name):
			out.append(name)
	out.sort()
	return out


## The names one GDScript file DECLARES: its functions and its signals, sorted. Read off the text
## rather than off a parse, because this runs over files that may not parse at all - a file caught
## mid-rename is exactly the file this is asked about.
static func declared_names(text: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if _declaration_re == null:
		_declaration_re = RegEx.create_from_string(
			"(?m)^[ \\t]*(?:static[ \\t]+)?(?:func|signal)[ \\t]+([A-Za-z_][A-Za-z0-9_]*)")
	for found: RegExMatch in _declaration_re.search_all(text):
		var name: String = found.get_string(1)
		if not names.has(name):
			names.append(name)
	names.sort()
	return names


## The node names one scene holds, sorted. Off the scene reader every other question about a scene
## goes through, so watching a scene costs nothing a sheet was not already paying for.
static func scene_node_names(scene_path: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for node: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		var name: String = str((node as Dictionary).get("name", "")).strip_edges()
		if not name.is_empty() and not names.has(name):
			names.append(name)
	names.sort()
	return names


## Watches one script and one scene in a single call, and hands back what their last saves did:
## {"names_gone", "names_arrived", "nodes_gone", "nodes_arrived", "scene"}. The shape the findings
## walk reads, so a caller with a sheet in front of it does not have to know which reader answers
## which half. Either path may be empty, and an empty one simply contributes nothing.
static func witness_for(script_path: String, scene_path: String = "") -> Dictionary:
	var witness: Dictionary = {
		"names_gone": PackedStringArray(), "names_arrived": PackedStringArray(),
		"nodes_gone": PackedStringArray(), "nodes_arrived": PackedStringArray(),
		"scene": scene_path,
	}
	if not script_path.strip_edges().is_empty():
		# THE FILE IS ONLY READ WHEN IT MOVED. This runs every time a sheet is built, and reading a
		# whole script to work out that it says what it said last time is a cost paid for nothing on
		# every sweep of every sheet. The stamp already answers "did this file change", and it is
		# itself held, so the ordinary case costs one dictionary lookup.
		if not unchanged(script_path):
			observe(script_path, declared_names(FileAccess.get_file_as_string(script_path)))
		var save: Dictionary = last_save(script_path)
		witness["names_gone"] = save.get("gone", PackedStringArray())
		witness["names_arrived"] = save.get("arrived", PackedStringArray())
	if not scene_path.strip_edges().is_empty():
		if not unchanged(scene_path):
			observe(scene_path, scene_node_names(scene_path))
		var scene_save: Dictionary = last_save(scene_path)
		witness["nodes_gone"] = scene_save.get("gone", PackedStringArray())
		witness["nodes_arrived"] = scene_save.get("arrived", PackedStringArray())
	return witness


## True when this file is exactly the file that was watched last - so nothing has to be read to know
## that its last save is still the last save. False for a file nobody has watched yet, which is the
## one case that does have to read it.
static func unchanged(path: String) -> bool:
	var held: Variant = _seen.get(path)
	return held is Dictionary \
		and str((held as Dictionary).get("stamp", "")) == EventForgeFileStamp.of(path)


## Drops everything watched. The editor never calls this - a witness that forgot on every filesystem
## ping would forget exactly the save it exists to remember - so it is for tests, which clear it
## between fixtures the way they clear every other reader here.
static func clear_cache() -> void:
	_seen.clear()
	_saves.clear()


## Every file this session has WATCHED A SAVE OF, in path order. The Renames section's whole corpus,
## and the honest one: a file with no witness behind it cannot earn a finding here whatever is in it,
## so reading a thousand of them would cost a project-wide walk to answer "nothing" a thousand times.
## Sorted, so two machines read the same files in the same order.
static func watched_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for path: Variant in _saves.keys():
		paths.append(str(path))
	paths.sort()
	return paths
